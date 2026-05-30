# CLAUDE.md

Use this file as the project-specific operating guide for work in this repository.

## Repository Context

This is a Flutter web receipt-splitting app backed by a Firebase HTTPS function.

- App code: `lib/`
- Tests: `test/`
- Backend: `functions/src/index.ts`
- Setup docs: `README.md`, `docs/gemini-setup.md`, `docs/document-ai-ocr.md`

## What Matters Most

- Maintain correct receipt math.
- Keep mock mode usable for local UI work.
- Keep live analysis routed through the backend, never from the client directly.
- Avoid accidental changes to Firebase or Gemini configuration unless the task requires it.

## Code Map

### Frontend

- `lib/main.dart`
  Selects `MockReceiptAnalyzer` or `FirebaseReceiptAnalyzer`.

- `lib/state/bill_state.dart`
  Main mutable app state. Receipt edits, payer assignment, and paid amounts flow through here.

- `lib/services/split_math.dart`
  Core billing logic. Changes here need test coverage.

- `lib/services/debt_simplifier.dart`
  Computes settlement transfers from payer balances.

- `lib/screens/`
  Three-screen flow: home, review, summary.

### Backend

- `functions/src/index.ts`
  Receipt analysis entrypoint. Handles warmup, OCR fallback, Gemini retries, and structured JSON parsing.

## Safe Workflow

1. Read the relevant files before editing.
2. Keep changes scoped to the user request.
3. Update tests when changing split or settlement behavior.
4. Update docs when changing setup, env vars, or deploy behavior.
5. Validate with the smallest useful command set before finishing.

## Commands

Repo root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false
flutter run -d chrome --dart-define=USE_MOCK_ANALYZER=false --dart-define=API_BASE=http://localhost:5001/bill-splitt/asia-southeast1
flutter build web --release --dart-define=USE_MOCK_ANALYZER=false
```

Functions:

```bash
cd functions
npm install
npm run build
npm run serve
```

Deploy:

```bash
firebase deploy --only functions
firebase deploy --only hosting
firebase deploy
```

## Testing Guidance

- Run `flutter test` for any logic change.
- Run `flutter analyze` for any Dart change.
- Run `npm run build` in `functions/` for backend edits.
- If behavior depends on `USE_MOCK_ANALYZER` or `API_BASE`, verify the intended path explicitly.

## Constraints

- Do not embed secrets in Flutter code.
- Do not break the default mock flow.
- Do not assume `receipt.total` is authoritative during editing; the app derives totals from items plus exclusive charges.
- Be careful with charge mode semantics:
  - `exclusive` charges are added or subtracted during computation
  - `inclusive` charges should not be double-counted

## Useful Context

- Gemini model currently configured: `gemini-2.5-flash`
- Function region: `asia-southeast1`
- Optional OCR uses Document AI via `DOCUMENT_AI_PROCESSOR_NAME`
- Rate-limit retry handling already exists in the function; preserve it unless intentionally redesigning request handling

## Definition Of Done

A change is not complete until the touched layer still builds cleanly, relevant tests pass or are updated, and the docs are consistent with the new behavior.
