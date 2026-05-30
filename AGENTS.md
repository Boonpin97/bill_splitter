# AGENTS.md

This repository is a Flutter web app with a Firebase Cloud Function backend for receipt OCR and bill splitting.

## Project Summary

- Frontend: Flutter web app under `lib/`
- Backend: Firebase Functions TypeScript service under `functions/`
- Docs: setup and OCR notes under `docs/`
- Tests: Dart unit tests under `test/`

The app flow is:

1. User uploads a receipt image.
2. `ReceiptAnalyzer` parses it with either mock data or the deployed backend.
3. Users assign ordered items to payers.
4. Split math computes each payer's total with compounded charges.
5. Debt simplification reduces transfers to a minimal settlement list.

## Architecture Notes

### Flutter app

- `lib/main.dart`: chooses mock vs live analyzer using `USE_MOCK_ANALYZER` and optional `API_BASE`
- `lib/app.dart`: app root
- `lib/state/bill_state.dart`: central `ChangeNotifier` for receipt data, assignments, paid amounts, and editable charges
- `lib/services/split_math.dart`: authoritative split calculation
- `lib/services/debt_simplifier.dart`: settlement minimization
- `lib/services/receipt_api.dart`: mock and Firebase-backed receipt analyzers
- `lib/screens/`: `home_screen.dart`, `review_screen.dart`, `summary_screen.dart`
- `lib/widgets/`: receipt review and payer assignment UI pieces

### Cloud Function

- `functions/src/index.ts`: `analyzeReceipt` HTTP function
- Uses `gemini-2.5-flash`
- Can optionally run Document AI OCR first when `DOCUMENT_AI_PROCESSOR_NAME` is configured
- Retries Gemini on 429 when time budget allows

## Working Rules

- Prefer focused changes over broad refactors.
- Preserve the split math behavior around compounded exclusive charges.
- Do not move secrets into Flutter code or commit API keys.
- Keep mock mode working unless the task explicitly changes local-development behavior.
- Treat `BillState.derivedTotal` as the computed source of truth for the current receipt session.

## Common Commands

From repo root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false
flutter build web --release --dart-define=USE_MOCK_ANALYZER=false
```

For Cloud Functions:

```bash
cd functions
npm install
npm run build
npm run serve
```

Deployment:

```bash
firebase deploy --only functions
firebase deploy --only hosting
firebase deploy
```

## Validation Expectations

- For Dart/UI/state changes: run `flutter analyze` and `flutter test`
- For function changes: run `npm run build` in `functions/`
- If a change affects the mock/live analyzer boundary, verify the relevant `--dart-define` path

## Environment Details

- Flutter SDK: `>= 3.11`
- Dart SDK: `^3.11.5`
- Node.js: `>= 18`
- Firebase CLI required for deploy/emulator flows

## Known Behaviors

- Mock analyzer is enabled by default unless `USE_MOCK_ANALYZER=false` is passed at build/run time.
- The hosted app should usually call `/api/analyzeReceipt` on same origin when `API_BASE` is empty.
- Document AI is optional and should degrade gracefully when not configured.

## When Editing Docs

- Keep `README.md`, `docs/gemini-setup.md`, and `docs/document-ai-ocr.md` aligned with runtime behavior.
- If setup steps, env vars, model names, or deploy commands change, update the docs in the same task.
