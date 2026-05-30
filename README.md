# Receipt Bill Split

A Flutter web app that photographs a receipt, extracts items / prices / GST / service charges with Gemini Vision, and splits the bill across any number of people with a simplified debt-transfer summary.

**Live app:** https://bill-splitt.web.app

---

## How it works

1. Take or upload a photo of a receipt.
2. Gemini AI parses it into items, quantities, and charges.
3. Tap each person's avatar next to the items they ordered (long-press for a shared quantity).
4. The app calculates each person's share — charges are compounded in receipt order (service charge first, then GST on the new total).
5. The Summary screen shows a per-person breakdown and the minimum transfers needed to settle the bill.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.11 |
| Dart SDK | ≥ 3.11.5 |
| Node.js | ≥ 18 |
| Firebase CLI | latest (`npm i -g firebase-tools`) |

---

## Quick start — mock data (no Firebase needed)

```bash
flutter pub get
flutter run -d chrome
```

Pick any image. A sample hawker-stall receipt is returned so you can explore the full UI without any API keys.

---

## Full setup — real Gemini analysis

### 1. Install Flutter dependencies

```bash
flutter pub get
```

### 2. Install Cloud Functions dependencies

```bash
cd functions
npm install
cd ..
```

### 3. Log in to Firebase and select the project

```bash
firebase login
firebase use bill-splitt        # or: firebase use --add  to pick/create a project
```

### 4. Get a Gemini API key

1. Go to https://aistudio.google.com/app/apikey and sign in.
2. Click **Create API key** → choose an existing Cloud project or create a new one.
3. Copy the `AIza…` key.
4. Restrict the key to **Generative Language API** under *API restrictions* — Google requires this from **2026-06-19**.

> The key lives only on the server (Cloud Function). Never put it in the Flutter bundle or commit it to git.

Full walkthrough: [`docs/gemini-setup.md`](docs/gemini-setup.md)

### 5. Store the key as a Firebase secret

```bash
firebase functions:secrets:set GEMINI_API_KEY
# Paste the AIza… value at the prompt
```

### 6. (Optional) Enable Document AI OCR

Document AI extracts raw receipt text before Gemini sees the image, which improves accuracy on blurry or low-contrast receipts. It requires billing to be enabled on the Cloud project.

1. Enable **Cloud Document AI API** in Google Cloud Console:
   ```
   https://console.cloud.google.com/apis/library/documentai.googleapis.com
   ```
2. Create an **Enterprise Document OCR** processor in region `asia-southeast1`.
3. Grant the function's runtime service account the **Document AI API User** role.
4. Add the processor name to `functions/.env`:
   ```env
   DOCUMENT_AI_PROCESSOR_NAME=projects/PROJECT_ID/locations/asia-southeast1/processors/PROCESSOR_ID
   ```

Full walkthrough: [`docs/document-ai-ocr.md`](docs/document-ai-ocr.md)

Cost: ~$0.0015 per receipt (one page at $1.50 / 1 000 pages). If `DOCUMENT_AI_PROCESSOR_NAME` is not set, the function uses Gemini image analysis only.

### 7. Deploy the Cloud Function

```bash
firebase deploy --only functions
```

### 8. Run against the deployed function

```bash
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false
```

To point at a different backend during development:

```bash
flutter run -d chrome \
  --dart-define=USE_MOCK_ANALYZER=false \
  --dart-define=API_BASE=https://bill-splitt.web.app
```

---

## Build & deploy the web app

```bash
flutter build web --release --dart-define=USE_MOCK_ANALYZER=false
firebase deploy --only hosting
```

> **Important:** `USE_MOCK_ANALYZER=false` must be passed at build time. Without it, the mock analyzer is compiled in and no real API calls are made.

To deploy everything in one step:

```bash
flutter build web --release --dart-define=USE_MOCK_ANALYZER=false && firebase deploy
```

---

## Local emulator

Run the Cloud Function locally against the deployed Firebase project:

```bash
cd functions
npm run serve
```

Then in a second terminal:

```bash
flutter run -d chrome \
  --dart-define=USE_MOCK_ANALYZER=false \
  --dart-define=API_BASE=http://localhost:5001/bill-splitt/asia-southeast1
```

---

## Tests

```bash
flutter test
```

Covers split math (compounded exclusive charges, discounts, rounding residual) and the debt-simplification algorithm (2 / 3 / 4-payer cases).

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `429 RESOURCE_EXHAUSTED` | Free-tier Gemini rate limit (20 req / min) | Wait ~30 s; the function retries automatically if within the 60 s timeout. Upgrade to paid tier for higher throughput. |
| `403 PERMISSION_DENIED` | Gemini key restriction too tight | Confirm **Generative Language API** is allowed in key settings, or temporarily set restrictions to *None*. |
| `502` with `Gemini returned non-JSON` | Malformed Gemini response | Use a clearer photo, or tap **Reanalyze** to run Document AI OCR before Gemini. |
| Document AI `PERMISSION_DENIED` | Runtime service account missing role | Grant **Document AI API User** to the function's service account in IAM. |
| Document AI `NOT_FOUND` | Wrong processor resource name | Confirm the full `projects/…/locations/…/processors/…` value in `functions/.env`. |
| App shows hardcoded mock receipt after deploy | `USE_MOCK_ANALYZER=false` not passed at build time | Rebuild with `--dart-define=USE_MOCK_ANALYZER=false`. |

Check Cloud Function logs at any time:

```bash
firebase functions:log --only analyzeReceipt
```

---

## Project structure

```
lib/
  models/         Receipt, LineItem, Charge, Payer, SplitResult
  services/
    split_math.dart         per-payer total calculation (compounded charges)
    debt_simplifier.dart    greedy creditor/debtor matching
    receipt_api.dart        FirebaseReceiptAnalyzer + MockReceiptAnalyzer
  state/
    bill_state.dart         ChangeNotifier — receipt, payers, quantity grid, paid amounts
  screens/        Home → Review → Summary
  widgets/        PeopleSection, ItemCard, ChargesPanel, ReceiptImage, PayerAvatar
functions/
  src/index.ts    analyzeReceipt Cloud Function (Gemini Vision + optional Document AI OCR)
docs/
  gemini-setup.md           Gemini API key setup walkthrough
  document-ai-ocr.md        Document AI OCR setup walkthrough
```
