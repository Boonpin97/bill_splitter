import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { DocumentProcessorServiceClient } from "@google-cloud/documentai";

setGlobalOptions({ region: "asia-southeast1", maxInstances: 5 });

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const SILICONFLOW_API_KEY = defineSecret("SILICONFLOW_API_KEY");

type ReceiptProvider = "gemini" | "siliconflow";
const RECEIPT_PROVIDER: ReceiptProvider =
  (process.env.RECEIPT_PROVIDER ?? "gemini").toLowerCase() === "siliconflow"
    ? "siliconflow"
    : "gemini";

const GEMINI_MODEL = "gemini-2.5-flash";
const SILICONFLOW_MODEL =
  process.env.SILICONFLOW_MODEL ?? "Qwen/Qwen3-VL-8B-Instruct";
// SiliconFlow runs two separate platforms with non-interchangeable keys:
// api.siliconflow.com (international, default) and api.siliconflow.cn (China).
const SILICONFLOW_BASE_URL =
  process.env.SILICONFLOW_BASE_URL ?? "https://api.siliconflow.com/v1";
const SILICONFLOW_URL = `${SILICONFLOW_BASE_URL}/chat/completions`;
const DOCUMENT_AI_PROCESSOR_NAME = process.env.DOCUMENT_AI_PROCESSOR_NAME ?? "";
const DOCUMENT_AI_LOCATION =
  DOCUMENT_AI_PROCESSOR_NAME.match(/\/locations\/([^/]+)\//)?.[1] ?? "us";
const documentAiClient = DOCUMENT_AI_PROCESSOR_NAME
  ? new DocumentProcessorServiceClient({
      apiEndpoint: `${DOCUMENT_AI_LOCATION}-documentai.googleapis.com`,
    })
  : undefined;

const SYSTEM_PROMPT = `You are a receipt-parsing assistant. Given an image of a receipt,
return STRICT JSON conforming to this TypeScript shape (no markdown, no commentary):

interface Receipt {
  currency: string;            // ISO 4217, best guess (e.g. "SGD", "USD")
  items: Array<{
    name: string;
    unitPrice: number;         // per-unit price, NOT line total
    quantity: number;          // integer quantity as shown
  }>;
  charges: Array<{
    kind: "gst" | "service" | "discount" | "other";
    mode: "inclusive" | "exclusive"; // inclusive means already in unitPrice
    percent?: number;          // 0.09 for 9% if printed
    amount?: number;           // printed currency amount for this charge, if shown
    label?: string;            // verbatim label from receipt, optional
  }>;
  subtotal: number;            // after discounts, before tax/service
  total: number;               // grand total as printed
}

Rules:
- Output JSON only, no code fences.
- Combine duplicate-line items only when the receipt itself shows a quantity column.
- Mark a charge "inclusive" only if the receipt explicitly says the prices include it (e.g. "GST inclusive"). Otherwise default to "exclusive".
- Return discounts as charges with kind "discount" so the app can subtract them before service/GST/tax. Do not include discounts in the tax/service total.
- Subtotal should be item total minus discounts, before service/GST/tax.
- For tax/service charges, include both percent and amount when the receipt prints both. The app will calculate from percent and compare it to the printed amount.
- If only one is shown, include only that field.
- If a value is unknown, omit the field rather than guessing wildly.`;

function promptWithOcrText(ocrText?: string): string {
  if (!ocrText?.trim()) {
    return SYSTEM_PROMPT;
  }
  return `${SYSTEM_PROMPT}

OCR text extracted by Google Document AI is included below. Use it as the primary
source for exact item names, prices, subtotals, taxes, service charges, discounts,
and totals. Use the receipt image to resolve layout, columns, quantities, and any
OCR ambiguity.

Document AI OCR text:
${ocrText}`;
}

async function extractOcrText(
  imageBase64: string,
  mimeType: string
): Promise<string | undefined> {
  if (!documentAiClient || !DOCUMENT_AI_PROCESSOR_NAME) {
    return undefined;
  }

  const [result] = await documentAiClient.processDocument({
    name: DOCUMENT_AI_PROCESSOR_NAME,
    rawDocument: {
      content: Buffer.from(imageBase64, "base64"),
      mimeType,
    },
  });

  const text = result.document?.text?.trim();
  return text ? text.slice(0, 20000) : undefined;
}

interface AnalyzeRequest {
  imageBase64?: string;
  mimeType?: string;
  analysisMode?: "auto" | "ocr";
}

class RateLimitError extends Error {
  readonly retryAfterMs: number;
  constructor(provider: string, detail: string, retryAfterMs: number) {
    super(JSON.stringify({ error: `${provider} call failed: 429`, detail }));
    this.name = "RateLimitError";
    this.retryAfterMs = retryAfterMs;
  }
}

// Tolerant JSON parse: models occasionally wrap output in ```json fences even
// when asked for raw JSON, so strip them before parsing.
function parseModelJson(text: string, provider: string): unknown {
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  try {
    return JSON.parse(cleaned);
  } catch {
    throw new Error(
      JSON.stringify({
        error: `${provider} returned non-JSON`,
        sample: text.slice(0, 200),
      })
    );
  }
}

async function callGemini(
  imageBase64: string,
  mimeType: string,
  ocrText?: string
): Promise<Response> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY.value()}`;
  const geminiBody = {
    contents: [
      {
        role: "user",
        parts: [
          { text: promptWithOcrText(ocrText) },
          {
            inline_data: {
              mime_type: mimeType,
              data: imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      temperature: 0.1,
    },
  };

  return fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(geminiBody),
  });
}

function parseGeminiRetryAfterMs(errText: string): number {
  const match = errText.match(/retry in ([0-9.]+)s/i);
  return match ? Math.ceil(parseFloat(match[1]) * 1000) : 30_000;
}

async function parseGeminiReceipt(geminiRes: Response): Promise<unknown> {
  if (!geminiRes.ok) {
    const errText = await geminiRes.text();
    if (geminiRes.status === 429) {
      throw new RateLimitError(
        "Gemini",
        errText.slice(0, 500),
        parseGeminiRetryAfterMs(errText)
      );
    }
    throw new Error(
      JSON.stringify({
        error: `Gemini call failed: ${geminiRes.status}`,
        detail: errText.slice(0, 500),
      })
    );
  }

  const json = (await geminiRes.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error(JSON.stringify({ error: "Gemini returned no text" }));
  }
  return parseModelJson(text, "Gemini");
}

async function callSiliconFlow(
  imageBase64: string,
  mimeType: string,
  ocrText?: string
): Promise<Response> {
  const body = {
    model: SILICONFLOW_MODEL,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: promptWithOcrText(ocrText) },
          {
            type: "image_url",
            image_url: { url: `data:${mimeType};base64,${imageBase64}` },
          },
        ],
      },
    ],
    temperature: 0.1,
    response_format: { type: "json_object" },
  };

  return fetch(SILICONFLOW_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${SILICONFLOW_API_KEY.value()}`,
    },
    body: JSON.stringify(body),
  });
}

async function parseSiliconFlowReceipt(res: Response): Promise<unknown> {
  if (!res.ok) {
    const errText = await res.text();
    if (res.status === 429) {
      const retryAfter = res.headers.get("retry-after");
      const retryAfterMs = retryAfter
        ? Math.ceil(parseFloat(retryAfter) * 1000)
        : 30_000;
      throw new RateLimitError("SiliconFlow", errText.slice(0, 500), retryAfterMs);
    }
    throw new Error(
      JSON.stringify({
        error: `SiliconFlow call failed: ${res.status}`,
        detail: errText.slice(0, 500),
      })
    );
  }

  const json = (await res.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const text = json.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error(JSON.stringify({ error: "SiliconFlow returned no text" }));
  }
  return parseModelJson(text, "SiliconFlow");
}

// Dispatches to the configured provider and returns the parsed receipt JSON.
async function analyzeWithProvider(
  imageBase64: string,
  mimeType: string,
  ocrText?: string
): Promise<unknown> {
  if (RECEIPT_PROVIDER === "siliconflow") {
    return parseSiliconFlowReceipt(
      await callSiliconFlow(imageBase64, mimeType, ocrText)
    );
  }
  return parseGeminiReceipt(await callGemini(imageBase64, mimeType, ocrText));
}

export const analyzeReceipt = onRequest(
  {
    secrets: [GEMINI_API_KEY, SILICONFLOW_API_KEY],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (req, res) => {
    // Lightweight warmup probe: the client pings this on page load so the
    // Cloud Run container is hot by the time the user uploads an image.
    if (req.method === "GET" || req.method === "HEAD") {
      res.status(204).end();
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }
    const body = (req.body ?? {}) as AnalyzeRequest;
    const { imageBase64, mimeType, analysisMode } = body;
    if (!imageBase64) {
      res.status(400).json({ error: "imageBase64 is required" });
      return;
    }

    const imageMimeType = mimeType ?? "image/jpeg";
    const startMs = Date.now();
    // Cloud Function timeout is 60 s; keep 10 s buffer for the actual model call.
    const maxWaitMs = 50_000;
    let ocrText: string | undefined;

    try {
      try {
        ocrText = await extractOcrText(imageBase64, imageMimeType);
      } catch (e) {
        console.warn("Document AI OCR failed; continuing with image-only analysis", e);
      }

      let parsed: unknown;
      try {
        parsed = await analyzeWithProvider(imageBase64, imageMimeType, ocrText);
      } catch (e) {
        if (e instanceof RateLimitError && analysisMode !== "ocr") {
          const elapsed = Date.now() - startMs;
          const wait = e.retryAfterMs;
          if (elapsed + wait < maxWaitMs) {
            console.info(`${RECEIPT_PROVIDER} rate-limited; waiting ${wait}ms then retrying.`);
            await new Promise((r) => setTimeout(r, wait));
            parsed = await analyzeWithProvider(imageBase64, imageMimeType, ocrText);
          } else {
            throw e;
          }
        } else {
          throw e;
        }
      }
      res.status(200).json(parsed);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      try {
        res.status(502).json(JSON.parse(message));
      } catch {
        res.status(502).json({ error: message });
      }
    }
  }
);
