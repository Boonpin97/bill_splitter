import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { DocumentProcessorServiceClient } from "@google-cloud/documentai";

setGlobalOptions({ region: "asia-southeast1", maxInstances: 5 });

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const MODEL = "gemini-2.5-flash";
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
    percent?: number;          // 0.09 for 9% if known
    amount?: number;           // explicit currency amount if percent unknown
    label?: string;            // verbatim label from receipt, optional
  }>;
  subtotal: number;            // pre-tax/service if shown, else best guess
  total: number;               // grand total as printed
}

Rules:
- Output JSON only, no code fences.
- Combine duplicate-line items only when the receipt itself shows a quantity column.
- Mark a charge "inclusive" only if the receipt explicitly says the prices include it (e.g. "GST inclusive"). Otherwise default to "exclusive".
- Use percent OR amount, prefer percent when stated.
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

async function callGemini(
  imageBase64: string,
  mimeType: string,
  ocrText?: string
): Promise<Response> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY.value()}`;
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

class GeminiRateLimitError extends Error {
  readonly retryAfterMs: number;
  constructor(detail: string, retryAfterMs: number) {
    super(JSON.stringify({ error: "Gemini call failed: 429", detail }));
    this.name = "GeminiRateLimitError";
    this.retryAfterMs = retryAfterMs;
  }
}

function parseRetryAfterMs(errText: string): number {
  const match = errText.match(/retry in ([0-9.]+)s/i);
  return match ? Math.ceil(parseFloat(match[1]) * 1000) : 30_000;
}

async function parseGeminiReceipt(geminiRes: Response): Promise<unknown> {
  if (!geminiRes.ok) {
    const errText = await geminiRes.text();
    if (geminiRes.status === 429) {
      throw new GeminiRateLimitError(errText.slice(0, 500), parseRetryAfterMs(errText));
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

  try {
    return JSON.parse(text);
  } catch {
    throw new Error(
      JSON.stringify({
        error: "Gemini returned non-JSON",
        sample: text.slice(0, 200),
      })
    );
  }
}

export const analyzeReceipt = onRequest(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 60, memory: "512MiB" },
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
    // Cloud Function timeout is 60 s; keep 10 s buffer for the actual Gemini call.
    const maxWaitMs = 50_000;
    let ocrText: string | undefined;

    try {
      if (analysisMode !== "ocr") {
        try {
          const parsed = await parseGeminiReceipt(
            await callGemini(imageBase64, imageMimeType)
          );
          res.status(200).json(parsed);
          return;
        } catch (e) {
          if (e instanceof GeminiRateLimitError) {
            const elapsed = Date.now() - startMs;
            const wait = e.retryAfterMs;
            if (elapsed + wait < maxWaitMs) {
              console.info(`Gemini rate-limited; waiting ${wait}ms then retrying.`);
              await new Promise((r) => setTimeout(r, wait));
            } else {
              throw e;
            }
          } else {
            console.warn("Gemini image-only analysis failed; retrying with OCR", e);
          }
        }
      }

      try {
        ocrText = await extractOcrText(imageBase64, imageMimeType);
      } catch (e) {
        console.warn("Document AI OCR failed; continuing with image-only Gemini", e);
      }

      const parsed = await parseGeminiReceipt(
        await callGemini(imageBase64, imageMimeType, ocrText)
      );
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
