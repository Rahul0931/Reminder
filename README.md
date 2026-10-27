# Sticky Memo

A sticky-notes and reminders app for Android, built with Flutter.

**Features:** colored sticky notes, checklists, labels (Personal, Work, College, Shopping, Memory), pin to top, search, sorting, archive, trash with 30-day restore, dark mode, and reminders that ring as real phone notifications even when the app is closed. Reminders can repeat (daily, weekly, monthly), and you can snooze them or mark them done right from the notification. Type "call mom tomorrow 6pm" in the top box and the reminder is set for you.

---

## Option A: Get the APK without installing anything (GitHub, free)

1. Sign in at https://github.com (create a free account if needed).
2. Click **+ → New repository**, name it `sticky-memo`, choose **Public**, and click **Create repository**.
3. On the new repo page, click **uploading an existing file**. Drag in **everything inside** the `sticky_memo` folder (`lib`, `test`, `tool`, `pubspec.yaml`, `README.md`). Click **Commit changes**.
4. The `.github` folder is hidden on most computers, so add the build file by hand:
   - Click **Add file → Create new file**.
   - In the name box, type exactly: `.github/workflows/build-apk.yml`
   - Open `build-apk.yml` from this project in Notepad, copy everything, and paste it in.
   - Click **Commit changes**.
5. Open the **Actions** tab. A run called **Build APK** starts by itself and takes about 6–8 minutes. Wait for the green tick.
6. Click the finished run. Under **Artifacts**, download **sticky-memo-apk**. It's a .zip containing `app-release.apk`.
7. Send the APK to your phone (WhatsApp to yourself, Google Drive, or USB cable), open it, and allow **Install unknown apps** when Android asks.

Every time you change the code on GitHub, a new APK is built automatically.

## Option B: Build on your own laptop

1. Install Flutter: https://docs.flutter.dev/get-started/install (choose Android). Also install Android Studio, which the guide walks you through.
2. Check the setup with `flutter doctor`.
3. In a terminal, open this folder and run:

```
flutter create --platforms=android --org com.stickymemo --project-name sticky_memo .
flutter pub get
dart run tool/setup_android.dart
flutter run            # runs on a phone connected by USB (turn on USB debugging)
flutter build apk      # makes build/app/outputs/flutter-apk/app-release.apk
```

## First launch on the phone

- Allow notifications when asked. This happens the first time you set a reminder.
- On some phones (Xiaomi, Oppo, Vivo, Realme, Samsung), go to **Settings → Apps → Sticky Memo → Battery** and choose **No restrictions / Don't optimize**. Otherwise the phone may block reminders when the app is closed.
- For the **half-screen reminder** to pop up when the phone is locked, open **Settings → Apps → Sticky Memo** and allow **Full-screen notifications** (Android 14+). On Xiaomi also allow **Show on lock screen** and **Display pop-up windows**.

## How the half-screen reminder works

When a reminder is due, a big panel slides up over half the screen. It shows the title and the message (or the unticked checklist items), a large **Done** button, and **Snooze 10 min / 1 hour / Tomorrow**.

- **App open:** the panel appears right on time.
- **Phone locked or screen off:** the screen turns on and the panel appears over the lock screen.
- **Using another app:** Android shows a notification banner at the top. Tap it and the panel opens. (Android doesn't let normal apps cover other apps without a special "draw over apps" permission.)

## Project layout

| File | What it does |
|---|---|
| `lib/main.dart` | Starts the app and sets the light/dark theme |
| `lib/ui/home.dart` | Main board: quick add, label filters, overdue list, tabs |
| `lib/ui/editor.dart` | Note editor: text/checklist, color, label, reminder |
| `lib/ui/note_card.dart` | The sticky-note card and two-column board |
| `lib/store.dart` | Saves notes on the phone and handles all actions |
| `lib/reminders.dart` | Schedules Android notifications |
| `lib/quick_parse.dart` | Understands "tomorrow 6pm", "in 2 hours", "friday 5pm", "kal" |
| `tool/setup_android.dart` | Adds notification permissions to the Android project |

## Ideas for version 2

Home-screen widget · cloud backup (Firebase) · voice notes · photo notes · lock notes with fingerprint · share a note to WhatsApp.
