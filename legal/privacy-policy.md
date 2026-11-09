# Cue Studio Privacy Policy

_Draft for the launch build. Effective date: [DATE OF PUBLICATION]. Replace every [BRACKETED] item before publishing._

Cue Studio ("Cue", "we") is an iPhone and iPad app for writing, recording, editing and sharing short videos. It is made by
[DEVELOPER OR COMPANY NAME, as on the App Store], who is responsible for your data. Contact: [SUPPORT EMAIL].

We built Cue so that what you make stays on your device. This policy explains the few things that leave it, who receives them, why, and
how to stop them.

## 1. What stays on your device

Your scripts, ideas (Logbook), recordings, edits, captions, My Cue Voice answers and writing samples, brand kits, imported fonts and
media, and your profile (name, username, photo) are stored only on your device. We do not have an account system and we cannot see them.

They are included in your device's iCloud or computer backup if you have backups turned on; that backup is handled by Apple under Apple's
privacy policy, not by us.

Processing that happens on your device and never reaches us:

- **Speech recognition** for Voice Following, captions and editing by text (Apple's on-device speech recognition).
- **Apple Intelligence** writing, ideas and editing tools. Some requests may run on **Apple's Private Cloud Compute**, which Apple designed
  so that your data is not stored or made accessible to Apple; we never receive it.
- **Video and image processing**: background removal, skin smoothing, face tracking, blur areas, stabilization and exports.
- **Translations** of captions (Apple's Translation framework).
- **Notifications and reminders** are scheduled on your device. No push notification server is used.
- **Remote control** between your own devices uses a direct, encrypted connection on your local network, with no server in between.

## 2. What leaves your device, and why

### Ultra AI (only when you choose it)

Ultra AI is an optional script writer. It never runs unless you allow it on the permission screen and pick it for a script.

- **What is sent:** your idea as you typed it (or your answers to the format), the language, platform, format and length, your My Cue
  Voice preferences, any inspiration or sponsor details you added to that request, and the draft between the writing steps. For "Fit to
  time" on an Ultra AI script, the script with your edits. The exact text can be seen in the app (Settings › Privacy & AI data › What
  Ultra AI sends › See the requests, word for word).
- **What is never sent:** your name or username, your other scripts, writing samples, imported excerpts, videos, audio or photos.
- **Who receives it:** the request goes through Cue's server (Google Cloud Functions, operated by us) to **Anthropic, PBC**, which runs the
  AI model and returns the text. Our server does not store the text. Under Anthropic's commercial terms, Anthropic does not use it to train
  its models and may keep it for up to 30 days to detect abuse
  ([Anthropic's commercial terms](https://www.anthropic.com/legal/commercial-terms)).
- **Counting your scripts:** to give you your free scripts and Cue Pro's monthly scripts, the app sends our server a **random identifier
  created for this installation** (not linked to your name, Apple ID or contact details), an identifier for each script being written,
  and, if you subscribe to Cue Pro, the **signed purchase record from the App Store** so we can confirm the subscription. Our server keeps
  only counts (how many scripts were used, when), with no text. These counts are deleted automatically about **13 months after their last
  use**.
- **Checking that a request comes from Cue:** each request carries a token from **Firebase App Check** (Google), which uses Apple's App
  Attest to confirm it comes from the genuine app.
- **How to stop:** turn off Ultra AI in Settings › Privacy & AI data. Nothing more is sent. Scripts it already wrote stay on your device.

### Invites (only when you use them)

If you ask for your invite code or enter a friend's code, the app sends our server the same random installation identifier, the code,
and, for an invited installation, the fact that its first video was exported. The server keeps the code, which installation it belongs
to, who joined with it and the rewards earned, so each friend is counted once. No names, contacts or messages are sent: you share the
invite message yourself through the iOS share sheet.

### Help improve Cue (optional, off by default)

If you turn on **Help improve Cue** (Settings › Privacy & AI data), the app sends **usage data and crash reports** to **Google Firebase**
(Firebase Analytics and Crashlytics): screens and features used, crashes, freezes and performance measurements, failures of on-device AI
or exports (with the device model, iOS version and conditions such as free memory), and Firebase's own installation identifier. It never
includes your scripts, ideas, recordings, names or any text you wrote. Cue does not use the advertising identifier and does not track you
across apps or websites. Turn it off at any time; reports not yet sent are deleted.

### Purchases

Subscriptions are handled by Apple. We do not receive your payment details. Apple shares with the app the record of your purchase, which
the app uses to unlock Cue Pro and, for Ultra AI, sends to our server as described above.

### Content you share

When you post a video, the app hands it to the iOS share sheet or to the app you choose (for example TikTok or Instagram). What happens
next is governed by that app's privacy policy. Saving to Photos asks iOS only for permission to add videos.

## 3. Permissions

Cue asks for the camera and microphone to record, speech recognition for Voice Following and captions, Photos (add only) to save your
videos, notifications for the reminders you set, and the local network for the remote control. Each can be changed in iOS Settings.

## 4. Legal bases (EU, UK and Brazil)

- **Performing the service you ask for:** Ultra AI requests and their counting, invites, purchases.
- **Legitimate interest:** keeping the free scripts and invite rewards from being used more than once (the random identifier and counts).
- **Consent:** Help improve Cue (usage data and crash reports) and the Ultra AI permission; you can withdraw either at any time in the app.

These bases apply under the GDPR, the UK GDPR and Brazil's LGPD (Lei Geral de Proteção de Dados).

## 5. Where data is processed

Our server runs on Google Cloud in the United States (us-central1). Anthropic and Google process data in the United States and other
countries, under their standard contractual safeguards.

## 6. How long data is kept

- On your device: until you delete it or delete the app.
- Ultra AI counts on our server: deleted about 13 months after their last use.
- Ultra AI request text: not stored by our server; kept by Anthropic for up to 30 days for abuse detection.
- Invite records: kept while the invite program runs; deleted on request (see below).
- Usage data and crash reports (if you turned them on): kept by Google Firebase according to Firebase's retention settings
  ([Analytics: 14 months; Crashlytics: 90 days]).

## 7. Deleting your data and your rights

- **In the app:** Settings › Privacy & AI data › **Delete my Cue data** erases everything Cue keeps on your device (scripts, ideas,
  recordings, edits, My Cue Voice, settings) and withdraws the Ultra AI permission, so Cue asks again before Ultra AI writes another script.
- **What it cannot recall:** Ultra AI requests already sent stay with Anthropic for up to 30 days, as above. Our server's counts are
  stored under a random identifier with no content and expire on their own.
- **On our server:** to delete your invite records sooner, email [SUPPORT EMAIL] with your invite code (shown in the app under Invite
  friends). Because we have no account and no name, the code is how we find them.
- You may ask to access, correct, delete or port your data, or object to its processing, by writing to [SUPPORT EMAIL]. You may also
  complain to your data protection authority (in Brazil, the ANPD).

## 8. Children

Cue is not directed to children under 13 (or the minimum age in your country), and we do not knowingly collect their data.

## 9. Changes

If this policy changes, we will update the date above and, for important changes, tell you in the app.

## 10. Contact

[DEVELOPER OR COMPANY NAME] · [SUPPORT EMAIL] · [POSTAL ADDRESS, if you have one to publish]
