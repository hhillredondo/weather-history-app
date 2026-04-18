# Weather history app

Flutter client that loads **past** weather from [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api) (free non-commercial tier for now).

## Install Flutter on Ubuntu

`flutter: command not found` means the SDK is not on your `PATH`. Pick one:

### Option A — Use the SDK inside this repo (quickest)

From the **repository root** (`weather-history-app/`, not `app/`):

```bash
export PATH="$PWD/.flutter-sdk/bin:$PATH"
cd app && flutter pub get && flutter run -d chrome
```

If you are already in `app/`, point `PATH` at the parent folder:

```bash
export PATH="$(dirname "$PWD")/.flutter-sdk/bin:$PATH"
```

If `.flutter-sdk` is missing (it is gitignored and not cloned by default), create it once from the repo root:

```bash
git clone https://github.com/flutter/flutter.git -b stable .flutter-sdk
export PATH="$PWD/.flutter-sdk/bin:$PATH"
flutter doctor
```

To make this permanent, add the `export PATH=...` line to `~/.bashrc` (adjust the path to your clone).

### Option B — Install Flutter for your whole system

Ubuntu options (official docs: [Linux install](https://docs.flutter.dev/get-started/install/linux)):

- **Snap:** `sudo snap install flutter --classic` (then run `flutter doctor`).
- **Manual:** download the Linux bundle from [flutter.dev](https://docs.flutter.dev/get-started/install/linux#install-the-flutter-sdk), unpack e.g. to `~/development/flutter`, then `export PATH="$HOME/development/flutter/bin:$PATH"`.

After any install, run `flutter doctor` and install anything it asks for (Chrome for web, Android Studio/SDK for Android, `clang` for Linux desktop, etc.).

## Current behaviour

- **15 days** of **daily** summaries ending **yesterday** (today is excluded), default **London** coordinates.
- **No in-app rate limiting** — we assume you will monitor Open-Meteo usage. If you outgrow the free tier, Open-Meteo’s paid plans add commercial use and higher limits; the cheaper tier may not include historical endpoints, so upgrading for **archive/historical** data can jump to a higher price band (check [Pricing](https://open-meteo.com/en/pricing) for current details).

## Licence

Weather data is subject to **CC-BY 4.0** (see Open-Meteo [licence](https://open-meteo.com/en/licence)); the app shows a short attribution string.
