# Cloud Functions

This directory hosts the `analyzeReceipt` callable function which proxies the
image to the Gemini Vision API and returns parsed `Receipt` JSON.

## One-time setup

```bash
cd functions
npm install
# Project-level setup from the Flutter project root:
cd ..
firebase login
firebase use --add                    # pick or create a Firebase project
firebase functions:secrets:set GEMINI_API_KEY
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
