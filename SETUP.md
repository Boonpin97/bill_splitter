# Setup Guide

Use this guide to set up `receipt_bill_split` on a new machine after cloning.
It covers the fastest local mock setup, the full Firebase backend setup, and
deployment checks.

## 1. Install Prerequisites

Install these tools before opening the project:

| Tool | Required version | Notes |
| --- | --- | --- |
| Flutter SDK | `>= 3.11` | Includes Dart. Run `flutter doctor` after install. |
| Dart SDK | `^3.11.5` | Managed by Flutter for normal app work. |
| Node.js | `>= 18` | Cloud Functions currently declares Node `22` in `functions/package.json`. |
| Firebase CLI | latest | Install with `npm install -g firebase-tools`. |
| Git | latest | Required to clone the repo. |

Optional, only if regenerating local Firebase client config:

```bash
dart pub global activate flutterfire_cli
```

## 2. Clone and Enter the Repo

```bash
git clone <REPO_URL>
cd receipt_bill_split
```

Replace `<REPO_URL>` with the actual Git remote URL.

## 3. Install Dependencies

Install Flutter packages:

```bash
flutter pub get
```

Install Firebase Functions packages:

```bash
cd functions
npm install
cd ..
```

## 4. Verify the Local Mock App

Mock mode is enabled by default and does not need Firebase, API keys, or a
backend.

```bash
flutter run -d chrome
```

Upload or pick any image. The app should return mock receipt data and allow you
to test payer assignment, split calculation, and settlement summaries.

## 5. Configure Firebase Project Access

Log in and select the Firebase project:

```bash
firebase login
firebase use bill-splitt
```

For a different project:

```bash
firebase use --add
```

The checked-in `.firebaserc` points `default` and `staging` at `bill-splitt`,
but each machine can choose its own active project.

## 6. Local Firebase Client Config

The repo intentionally does not track `lib/firebase_options.dart`.

Most current app paths do not require Firebase client initialization, but if a
future change or local workflow needs it, generate it locally:

```bash
flutterfire configure
```

Use `lib/firebase_options.example.dart` as a reference for the expected shape.
The generated `lib/firebase_options.dart` is gitignored.

## 7. Configure Receipt Analysis Provider

The backend supports Gemini by default and SiliconFlow as an alternate provider.
Secrets must stay on the backend. Do not put API keys in Flutter code or
`--dart-define` values.

### Gemini, Default Provider

Create a Gemini API key at:

```text
https://aistudio.google.com/app/apikey
```

Restrict the key to the Generative Language API, then store it as a Firebase
Functions secret:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

The function currently calls `gemini-2.5-flash`.

### SiliconFlow, Optional Provider

To use SiliconFlow instead of Gemini, store the SiliconFlow key:

```bash
firebase functions:secrets:set SILICONFLOW_API_KEY
```

Then configure runtime environment variables for the function, for example in
`functions/.env` for local emulator work:

```env
RECEIPT_PROVIDER=siliconflow
SILICONFLOW_MODEL=Qwen/Qwen3-VL-8B-Instruct
SILICONFLOW_BASE_URL=https://api.siliconflow.com/v1
```

If `RECEIPT_PROVIDER` is not set to `siliconflow`, the function uses Gemini.

See `docs/gemini-setup.md` and `docs/siliconflow-setup.md` for detailed
provider setup.

## 8. Optional Document AI OCR

Document AI OCR is optional. When configured, the function extracts OCR text
first and sends both the OCR text and original image to the model. If OCR is
missing or fails, the function falls back to image-only analysis.

To enable it:

1. Enable the Cloud Document AI API in the same Google Cloud project.
2. Create an Enterprise Document OCR processor.
3. Grant the function runtime service account the `Document AI API User` role.
4. Add the processor resource name to `functions/.env`:

```env
DOCUMENT_AI_PROCESSOR_NAME=projects/PROJECT_ID/locations/asia-southeast1/processors/PROCESSOR_ID
```

See `docs/document-ai-ocr.md` for the full walkthrough.

## 9. Build and Deploy the Backend

Validate the TypeScript function:

```bash
cd functions
npm run build
cd ..
```

Deploy the function:

```bash
firebase deploy --only functions
```

The deployed function is `analyzeReceipt` in region `asia-southeast1`.
Firebase Hosting rewrites `/api/analyzeReceipt` to that function.

## 10. Run the App Against the Backend

Against the same-origin hosted backend, or when using the default Firebase
Hosting rewrite:

```bash
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false
```

Against a specific backend URL:

```bash
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false --dart-define=API_BASE=https://bill-splitt.web.app
```

Against the local Functions emulator:

```bash
cd functions
npm run serve
```

In a second terminal:

```bash
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false --dart-define=API_BASE=http://localhost:5001/bill-splitt/asia-southeast1
```

## 11. Build and Deploy the Web App

Build the production web bundle with the live analyzer enabled:

```bash
flutter build web --release --dart-define=USE_MOCK_ANALYZER=false
```

Deploy hosting:

```bash
firebase deploy --only hosting
```

Deploy functions and hosting together:

```bash
firebase deploy
```

Important: `USE_MOCK_ANALYZER=false` must be passed at build time. Without it,
the production bundle uses mock receipt data.

## 12. Validation Commands

For Flutter app, UI, state, and split math changes:

```bash
flutter analyze
flutter test
```

For Cloud Function changes:

```bash
cd functions
npm run build
cd ..
```

For backend logs:

```bash
firebase functions:log --only analyzeReceipt
```

## 13. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| App returns mock data after deploy | Built without `USE_MOCK_ANALYZER=false` | Rebuild with the live analyzer dart define and redeploy hosting. |
| `403 PERMISSION_DENIED` from Gemini | API key restriction is wrong | Allow Generative Language API or temporarily remove restrictions to verify. |
| `429 RESOURCE_EXHAUSTED` | Provider rate limit | Wait and retry, or move to a paid/higher quota tier. |
| Document AI `PERMISSION_DENIED` | Function service account lacks OCR role | Grant `Document AI API User`. |
| Document AI `NOT_FOUND` | Wrong processor resource name or region | Check `projects/.../locations/.../processors/...` in `functions/.env`. |
| Emulator app cannot reach backend | Wrong `API_BASE` | Use `http://localhost:5001/<PROJECT_ID>/asia-southeast1`. |

## 14. Files That Should Stay Local

Do not commit secrets or machine-specific generated files:

- `functions/.env`
- `.env` and `.env.*`
- `lib/firebase_options.dart`
- service account JSON files
- `functions/lib/`
- `node_modules/`
- `build/`
