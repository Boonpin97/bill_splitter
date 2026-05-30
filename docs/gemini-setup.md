# Setting up a Gemini Vision API key

This guide walks through getting a Gemini API key, restricting it for safety, and plugging it into the `analyzeReceipt` Cloud Function this project ships with.

> Estimated time: **5 minutes**. You need a Google account and a credit card is **not** required for the free tier.

---

## 1. Sign in to Google AI Studio

1. Open **https://aistudio.google.com/app/apikey** in a browser.
2. Sign in with the Google account you want to own the key. If it's your first visit, accept the Gemini API Terms of Service when prompted.

Google AI Studio is the consumer-friendly front-end to the Gemini API. It will silently create a default Google Cloud project for you the first time — you do **not** need to set up Google Cloud manually for the free tier.

## 2. Create the API key

1. On the API keys page, click **Create API key**.
2. When the dialog asks which Google Cloud project to use:
   - For a brand-new account, pick **Create API key in new project** (recommended for this app).
   - If you already have a Cloud project you want to bill against, choose **Search Google Cloud projects** and pick it.
3. Copy the key that appears (it starts with `AIza…`). Keep this tab open — you'll paste it in step 4.

> Treat the key like a password. Do **not** commit it to git, paste it in chat, or ship it inside the Flutter web bundle. Our `analyzeReceipt` Cloud Function exists so the key stays on the server.

## 3. Restrict the key (required from 2026-06-19)

Google is disabling unrestricted Gemini keys on **June 19, 2026**. Restrict the key now so it keeps working.

1. From the AI Studio API keys page click the **⋯** menu next to your new key → **Edit API key in Google Cloud**. This opens the Cloud Console "API key" editor in a new tab.
2. Under **API restrictions** choose **Restrict key**, then in the dropdown select **Generative Language API** (this is the public name for the Gemini REST endpoint at `generativelanguage.googleapis.com`).
3. (Optional but recommended) Under **Application restrictions** pick **IP addresses** and add the egress IP of your Cloud Function — or leave it as **None** if you want flexibility while developing. The function still keeps the key off the client either way.
4. Click **Save**.

## 4. (Optional) Free tier vs. paid tier

- **Free tier**: works immediately on every new key. Models like `gemini-2.0-flash` and `gemini-2.5-flash` are included with daily request limits that are more than enough for personal use of this app. No billing setup needed.
- **Paid tier**: only required if you outgrow the free limits or want higher throughput. From the AI Studio key list, click **Set up Billing** next to the project and follow the prompts. Pricing details: <https://ai.google.dev/gemini-api/docs/pricing>.

This project's `analyzeReceipt` function currently calls `gemini-2.5-flash`, which is free-tier eligible.

## 5. Store the key as a Firebase secret

Don't put the key in a `.env` file in the repo or a `--dart-define` flag. Use Firebase Functions secrets:

```bash
# from the repo root
firebase login                          # once, opens a browser
firebase use --add                      # pick or create the Firebase project
firebase functions:secrets:set GEMINI_API_KEY
# Paste the AIza… value at the prompt
```

The `analyzeReceipt` function in `functions/src/index.ts` already declares `GEMINI_API_KEY` as a secret, so no code change is needed.

## 6. Deploy and verify

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

Then run the app against the real function:

```bash
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false
```

Upload a receipt photo. If the call fails:

- **403 / PERMISSION_DENIED**: the key restriction in step 3 is wrong. Confirm Generative Language API is allowed, or temporarily set restrictions to "None" to confirm the key itself works.
- **429**: you hit the free-tier rate limit. Wait a minute or upgrade to the paid tier.
- **Gemini returned non-JSON**: the prompt got a malformed response — try a clearer photo or check Cloud Functions logs with `firebase functions:log`.

## 7. Rotating the key

If a key leaks or you want to rotate periodically:

1. AI Studio → API keys → ⋯ next to the key → **Delete**.
2. Create a fresh one (step 2 above).
3. Re-run `firebase functions:secrets:set GEMINI_API_KEY` and re-deploy. The function picks up the new secret on the next cold start.

---

## Reference

- Get an API key: <https://ai.google.dev/gemini-api/docs/api-key>
- Gemini pricing & rate limits: <https://ai.google.dev/gemini-api/docs/pricing>
- Available models: <https://ai.google.dev/gemini-api/docs/models>
- Firebase Functions secrets: <https://firebase.google.com/docs/functions/config-env#secret-manager>
