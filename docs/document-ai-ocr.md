# Setting Up Google Document AI OCR

This project can use Google Document AI OCR to support Gemini receipt parsing.
The browser still sends the receipt image to the Firebase function once.

Default analysis uses OCR first when Document AI is configured:

1. The function tries Document AI OCR.
2. The function sends Gemini both the OCR text and the original image.
3. If Gemini is rate-limited, the function waits once when time allows, then
   retries Gemini with the same OCR text and image.
4. On the review screen, the user can tap **Reanalyze with OCR** to run the same
   Document AI-assisted path again if the first result looks inaccurate.

If Document AI is not configured, or if OCR fails, the function falls back to
Gemini image-only analysis.

## Prerequisites

- A Firebase project connected to this app.
- Billing enabled on the same Google Cloud project.
- The Gemini API key already stored as the `GEMINI_API_KEY` Firebase secret.
- Firebase CLI installed and logged in.

Check your active Firebase project from the repo root:

```bash
firebase projects:list
firebase use
```

## 1. Enable Document AI API

1. Open Google Cloud Console.
2. Select the same project used by Firebase.
3. Go to **APIs & Services** > **Library**.
4. Search for **Cloud Document AI API**.
5. Click **Enable**.

Direct page:

```text
https://console.cloud.google.com/apis/library/documentai.googleapis.com
```

## 2. Create an OCR Processor

Document AI requires a processor resource. This is not a local file path. It is
the Google Cloud resource name that identifies which OCR processor to use.

1. In Google Cloud Console, open **Document AI**.
2. Click **Create Processor**.
3. Choose **Enterprise Document OCR**.
4. Pick a region.
   - For this app, `asia-southeast1` is a sensible choice because the Firebase
     function is also deployed in `asia-southeast1`.
   - You can use another region, but the function must call that same region.
5. Give it a clear name, for example:

```text
receipt-ocr
```

6. Create the processor.
7. Open the new processor and copy its full resource name.

It should look like this:

```text
projects/PROJECT_ID/locations/asia-southeast1/processors/PROCESSOR_ID
```

You need the full value, including `projects/...`, `locations/...`, and
`processors/...`.

## 3. Grant Function Permissions

The Firebase function runs as a Google Cloud service account. That service
account needs permission to call Document AI.

1. Open **IAM & Admin** > **IAM** in Google Cloud Console.
2. Find the Cloud Functions / Compute runtime service account.
   Common names include:

```text
PROJECT_ID@appspot.gserviceaccount.com
PROJECT_NUMBER-compute@developer.gserviceaccount.com
```

3. Grant this role:

```text
Document AI API User
```

If you are unsure which service account is used, deploy once and check the
Cloud Run service details for `analyzeReceipt`; the **Security** section shows
the runtime service account.

## 4. Configure the Function

Create this file:

```text
functions/.env
```

Add your processor resource name:

```env
DOCUMENT_AI_PROCESSOR_NAME=projects/PROJECT_ID/locations/asia-southeast1/processors/PROCESSOR_ID
```

`functions/.env` is ignored by git, so it will not be committed.

The function reads this value at startup:

```ts
process.env.DOCUMENT_AI_PROCESSOR_NAME
```

If the value is missing, OCR is skipped and Gemini receives only the image.

## 5. Deploy

From the repo root:

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

After deployment, open the app normally and analyze a receipt.

## 6. Verify OCR Is Being Used

The function does not currently print OCR text to logs because receipt contents
can be sensitive. To verify configuration without exposing data:

1. Upload a receipt in the app.
2. If the request succeeds, check Firebase function logs:

```bash
firebase functions:log --only analyzeReceipt
```

3. If Document AI fails, the function logs:

```text
Document AI OCR failed; continuing with image-only Gemini
```

No such warning usually means Document AI was reached successfully before the
Gemini request.

## 7. Common Errors

### `PERMISSION_DENIED`

The runtime service account probably does not have Document AI permission.
Grant **Document AI API User** to the function's runtime service account.

### `NOT_FOUND`

The processor resource name is wrong, or the processor is in a different
project/region than the value in `DOCUMENT_AI_PROCESSOR_NAME`.

Confirm the value looks like:

```text
projects/PROJECT_ID/locations/LOCATION/processors/PROCESSOR_ID
```

### `INVALID_ARGUMENT`

The image MIME type or image data may be invalid. The app normally sends
`image/jpeg` or `image/png`; very large or unusual files may fail.

### Gemini Still Returns `503`

Document AI OCR improves text extraction, but it does not reserve Gemini model
capacity. A Gemini `503 UNAVAILABLE` still needs retry and fallback handling.

## Cost Estimate

Enterprise Document OCR is priced per page. A normal receipt image is usually
one page.

At `$1.50 per 1,000 pages`, OCR costs about:

```text
$0.0015 per receipt
$0.15 per 100 receipts
$1.50 per 1,000 receipts
```

Gemini parsing cost is separate.

## Disable OCR

Remove `DOCUMENT_AI_PROCESSOR_NAME` from `functions/.env` and redeploy:

```bash
firebase deploy --only functions
```

The function will return to Gemini image-only analysis.
