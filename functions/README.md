# Cloud Functions

This directory hosts the `analyzeReceipt` callable function which proxies the
image to a vision model and returns parsed `Receipt` JSON. The provider is
selected by the `RECEIPT_PROVIDER` env var: `gemini` (default) or `siliconflow`
(uses `SILICONFLOW_MODEL`, default `Qwen/Qwen3-VL-8B-Instruct`). See
[`../docs/siliconflow-setup.md`](../docs/siliconflow-setup.md).

## One-time setup

```bash
cd functions
npm install
# Project-level setup from the Flutter project root:
cd ..
firebase login
firebase use --add                    # pick or create a Firebase project
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set SILICONFLOW_API_KEY   # required even if unused
```

## Deploy

```bash
firebase deploy --only functions
```

## Local emulator

```bash
cd functions
npm run serve
```
