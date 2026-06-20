# Using SiliconFlow for receipt analysis

The `analyzeReceipt` Cloud Function can route receipt parsing through either
**Google Gemini** (default) or a **SiliconFlow**-hosted vision model such as
`Qwen/Qwen3-VL-8B-Instruct`. This guide covers switching to SiliconFlow.

SiliconFlow exposes an **OpenAI-compatible** API, so the function talks to its
`/v1/chat/completions` endpoint with the receipt image sent as a base64 `data:`
URL and the same receipt-parsing system prompt used for Gemini.

> **Two platforms, non-interchangeable keys.** SiliconFlow runs
> `api.siliconflow.com` (international, the function's default) and
> `api.siliconflow.cn` (China). A key from one returns `401 "Api key is invalid"`
> on the other. Override the base URL with the `SILICONFLOW_BASE_URL` env var
> (e.g. `https://api.siliconflow.cn/v1`) if your key belongs to the `.cn` platform.

---

## 1. Get a SiliconFlow API key

1. Sign in at <https://siliconflow.cn> (or <https://siliconflow.com>) and open the
   API keys page.
2. Create a key (it looks like `sk-…`).
3. Make sure your account has access to the vision model you intend to use, e.g.
   `Qwen/Qwen3-VL-8B-Instruct`.

> Treat the key like a password. It stays on the server as a Firebase secret —
> never put it in the Flutter bundle or commit it to git.

## 2. Configure the provider env vars

Set these on the function — either as Cloud Run environment variables or in
`functions/.env`:

```env
RECEIPT_PROVIDER=siliconflow                 # "siliconflow" or "gemini" (default)
SILICONFLOW_MODEL=Qwen/Qwen3-VL-8B-Instruct  # any SiliconFlow vision model id
```

- `RECEIPT_PROVIDER` selects the backend. Any value other than `siliconflow`
  (including unset) falls back to Gemini.
- `SILICONFLOW_MODEL` defaults to `Qwen/Qwen3-VL-8B-Instruct` if omitted.

## 3. Store the API key as a Firebase secret

```bash
firebase functions:secrets:set SILICONFLOW_API_KEY
# Paste the sk-… value at the prompt
```

The function declares both `GEMINI_API_KEY` and `SILICONFLOW_API_KEY` as secrets.
Both must exist in Secret Manager for deploy to succeed — set whichever you don't
use to any placeholder value if needed.

## 4. Deploy and verify

```bash
cd functions && npm install && npm run build && cd ..
firebase deploy --only functions
```

Then run the app against the real function:

```bash
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false
```

Upload a receipt photo. If the call fails, check the logs with
`firebase functions:log`:

- **`SiliconFlow call failed: 401`** — bad or missing `SILICONFLOW_API_KEY`.
- **`SiliconFlow call failed: 429`** — rate limited. The function waits and
  retries once if it fits inside the 60 s timeout (same logic as Gemini).
- **`SiliconFlow call failed: 400`** — usually a bad `SILICONFLOW_MODEL` id or a
  model that does not accept image input. Confirm the model supports vision.
- **`SiliconFlow returned non-JSON`** — the model returned malformed output; try a
  clearer photo or a stronger model.

## 5. Switching back to Gemini

Set `RECEIPT_PROVIDER=gemini` (or remove it) and redeploy. See
[`gemini-setup.md`](gemini-setup.md) for the Gemini key setup.

---

## Reference

- SiliconFlow docs: <https://docs.siliconflow.cn>
- Chat completions (OpenAI-compatible): `POST /v1/chat/completions`
- Firebase Functions secrets: <https://firebase.google.com/docs/functions/config-env#secret-manager>
