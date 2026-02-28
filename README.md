# 👛 Fine Pocket

A smart, AI-driven personal finance and budget tracker built with Flutter, Firebase, and the Google Gemini API. 

## 🚀 The Hand-Off Status (Current State)
The UI is built, the cloud backend is live, and **the v1.0 Release APK has been successfully compiled.** **What is already built and working:**
* **Frontend UI:** Complete interface with smooth animations and multi-screen navigation.
* **Authentication:** Full Firebase Auth loop integrated (Google Sign-In is 100% stable). 
* **AI Wingman (FinBot):** The Next.js serverless backend is deployed on Vercel and successfully communicates with the `gemini-1.5-flash` model. 

---

## 🛑 The Hit-List (What Needs Fixing)
There are two specific bugs/features left to resolve:

### 1. The Guest Login Navigation Loop
Currently, the custom Guest Onboarding flow has a routing bug in the stack. 
* **The Bug:** When a user clicks "Continue as Guest", the app asks for their Name/Photo, and then routes to the Baseline screen. After saving the Baseline, instead of routing to the `HomeScreen`, it loops back to the "Give Name" window.
* **The Fix:** The `AuthGate` and `SharedPreferences` keys need to be synchronized, and the `BaselineScreen` needs a hard route (`pushAndRemoveUntil`) directly to the Home screen to break the loop.

### 2. The AI Math & Prompt Tuning
The Vercel backend and Gemini API connection are working perfectly, but FinBot needs a prompt adjustment.
* **The Bug:** The AI struggles to correctly calculate budget deductions or adhere strictly to the system prompt's math rules.
* **The Fix:** Update the core system prompt in the Next.js API route to enforce stricter calculation steps before the AI responds to the user.

### 3. Firestore Data Sync (Optional but Recommended)
* Currently, user baseline data is not syncing across devices. Wire up `cloud_firestore` to save and fetch the user's budget data based on their Firebase `uid`.

---

## 🛠 Tech Stack
* **App Framework:** Flutter / Dart
* **Authentication:** Firebase Auth
* **Backend:** Next.js Serverless API (Hosted on Vercel)
* **AI Model:** Google Gemini `1.5-flash`

---

## 💻 Local Setup Instructions

### 1. Clone & Install
```bash
git clone [https://github.com/Soham-5/FinePocket.git](https://github.com/Soham-5/FinePocket.git)
cd fine_pocket_mobile
flutter pub get
flutter run
