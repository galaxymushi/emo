# Emo

**An on-device Android assistant that actually does things.** Talk or type — Emo controls your phone's settings, opens apps, starts calls and messages, and runs saved routines. Commands are parsed and executed on the phone; an optional cloud brain adds free-form understanding with your own provider key. Emo never fabricates a result.

Flutter + Kotlin · min Android 8.0 (API 26) · glassmorphism UI · light theme

## Screens

| Home | Assistant | Automations |
| :---: | :---: | :---: |
| ![Home](screenshots/home.png) | ![Assistant](screenshots/assistant.png) | ![Automations](screenshots/automations.png) |

| Control Center | Activity | Settings |
| :---: | :---: | :---: |
| ![Control Center](screenshots/control-center.png) | ![Activity](screenshots/activity.png) | ![Settings](screenshots/settings.png) |

| Voice picker |
| :---: |
| ![Voice picker](screenshots/voice.png) |

## What it can do

- **Voice & text commands** — built-in Android speech recognition (with live partial results) and TTS replies.
- **Pro voice picker** — Emo auto-selects the best natural US English voice your phone's TTS engine exposes, with numbered voices, preview playback and a saved choice. Natural voices stream over the internet; standard voices work offline.
- **Optional cloud brain** — when the offline parser doesn't recognize a request, Emo can ask a cloud model to translate it into one of its real device actions, or answer a general question. Gemini, OpenAI, OpenRouter, Groq and any OpenAI-compatible endpoint are supported with your own API key. The model only returns a structured intent; the phone still performs and reports the action.
- **System control** — torch, media volume, screen brightness, Do Not Disturb, battery/charging, Wi-Fi and Bluetooth state.
- **Apps & communication** — open any installed app, search contacts and start a call, compose an SMS or WhatsApp message.
- **Routines** — daily schedules via `AlarmManager` (DND, volume, torch, brightness), persisted across restarts and runnable even when the app is closed.
- **Reply and update alerts** — if an answer arrives while Emo is in the background, a notification shows it. Emo also checks GitHub every 6 hours for a newer release and notifies you; tapping the update alert opens the release APK download. Both alert types have switches in Settings, and Settings has a manual "Check" row.
- **Live feedback** — every command renders its execution steps; success, failure and permission needs are shown honestly. An activity timeline records the last 90 actions.
- **Control Center** — glass tile grid for connectivity, display, sound and focus controls, plus sliders for brightness and volume.

## Honest Android limits

Android blocks some actions for third-party apps. Emo opens the right system surface instead of pretending it succeeded:

| Action | Behavior |
| --- | --- |
| Torch, volume, brightness, DND | Directly controlled (brightness/DND need access grants) |
| Wi-Fi / Bluetooth toggles | Opens the system panel on Android 10+ — Android forbids silent toggles |
| Calls & messages | Opens the dialer / composer pre-filled; you confirm the send |
| Lock screen, screenshots | Available only with Accessibility service enabled |
| App launch | Standard intent; no root or Shizuku required |

## Offline first, cloud optional

Known commands never leave the phone. A deterministic on-device parser matches 25 command intents instantly, asks about state instead of toggling it ("is Wi-Fi on?"), and executes through real Android APIs.

When **Cloud brain** is enabled and the parser doesn't recognize a message, Emo sends that message, the last few chat turns and basic device state (battery, brightness, volume, Wi-Fi/Bluetooth/DND, routine names) to the provider you chose. The model must reply with a JSON action from Emo's fixed list; Emo validates it, executes it locally, and reports the real result. Questions that aren't phone actions get a short conversational answer. With Cloud brain off — the default — nothing is uploaded. The API key is kept in the Android keystore.

## Permissions

| Permission | Why |
| --- | --- |
| Microphone | Voice commands (only requested when you tap the mic) |
| Camera | Torch control |
| Contacts | "Call Alex" / "Message Alex" |
| Bluetooth connect | Read adapter state on Android 12+ |
| Notification permission | Reply alerts and update alerts |
| Notification access | Read pending notification count |
| DND access | Toggle Do Not Disturb |
| Modify system settings | Set screen brightness |
| Accessibility | Lock screen and global actions (optional) |

Emo asks at the moment a capability is first used, and Settings shows the current grant state for each one.

## Architecture

```
lib/
  main.dart                 app shell + ambient glass background
  app_state.dart            ChangeNotifier state, persistence, routines/activity
  models.dart               DeviceState, ChatMessage, ActivityEvent, routines
  services/
    command_engine.dart     deterministic intent parser
    cloud_brain.dart        optional OpenAI-compatible NLU + chat client
    update_service.dart     GitHub release check + version comparison
    device_bridge.dart      MethodChannel bridge to Kotlin
    voice_service.dart      speech_to_text + flutter_tts
  screens/                  home, assistant, automations, control center,
                            activity, settings, shell (floating nav)
  widgets/                  glass surfaces, orb, icons, feedback sheets
android/app/src/main/kotlin/.../MainActivity.kt
                            device snapshot, torch, DND, brightness, volume,
                            intents, contacts, alarms, accessibility service
```

State lives in a single `AppState` (`ChangeNotifier`); persistence uses `shared_preferences`. Routines are scheduled with `AlarmManager` and restored on boot.

## Build

```bash
flutter pub get
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

Install on a device with developer options enabled:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Requires Flutter 3.35+ and JDK 17. No backend services. The cloud brain is optional and uses your own provider API key, added in **Settings → Intelligence**.

## Install from release

Download the latest `app-release.apk` from [Releases](https://github.com/galaxymushi/emo/releases), allow installation from your file manager, then grant permissions from **Settings → Access** inside the app.

## Verified

Tested on an Android 14 emulator: cold launch without permission prompts, all six screens, command parsing and media-volume execution (`set volume to 30`), routine scheduling and activity logging. Voice selection was verified end to end — the chosen natural voice (`en-us-x-iom-network`) is what Google TTS synthesizes replies with, and it survives an app restart. The cloud path is covered by unit tests for request construction, fenced-JSON parsing, intent mapping, missing-routine clarification and auth errors; the on-device flow without a key was verified to fail honestly. A live provider call needs your own API key. Hardware-dependent surfaces (torch, calls, Wi-Fi panel) use standard Android APIs and intents but were not exercised on the emulator.

---

Built by [galaxymushi](https://github.com/galaxymushi).
