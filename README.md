# SplitFast ⚡️
Item-level expense splitting with assisted bill parsing.
**Core Philosophy:** Compress the time from "bill arrives" to "everyone pays" to under 45 seconds using on-device ML, Gemini Flash, and native UPI deep links.

## 🚀 How to Run the App

Since this app relies on the Native Camera, Google ML Kit, and UPI intents, **it must be run on a physical mobile device**, not a web browser or desktop emulator.

### 1. Setup API Keys
Create a `.env` file in the root directory and add your Gemini API key:
```env
GEMINI_API_KEY=your_api_key_here
```

### 2. Install Dependencies
```bash
flutter clean
flutter pub get
```

### 3. Run on Physical Device

Plug in your phone (iOS or Android) and run:

```bash
flutter run
```

## ⚠️ Important Testing Notes for UPI

If you test the "Generate Links" feature, do not click the UPI link on the same phone/bank account that the UPI ID belongs to.
UPI apps (GPay, PhonePe) will throw a "COULD NOT LOAD BANKING NAME" or "Invalid Payee" error if you try to pay yourself via a deep link.

To test: Send the WhatsApp message to a friend and have them click the link, or use a secondary device.
