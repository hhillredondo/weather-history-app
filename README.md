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

- **Home**: **15 days** of **daily** summaries ending **yesterday**; uses your **favourite** saved place or default **London**.
- **Calendar**: pick any past day — shows **15 days** (**±7** around that day).
- **Locations**: search ([Open-Meteo geocoding](https://open-meteo.com/en/docs/geocoding-api)), save places, tap a row to set **favourite** (star).
- **Settings**: **°C/°F**, wind (**km/h**, **mph**, **m/s**), precipitation (**mm** / **in**). Preferences persist locally (`shared_preferences`).
- **AWS**: CloudFormation at `[infrastructure/cloudformation/template.yaml](infrastructure/cloudformation/template.yaml)` creates **Cognito** (email + password), **DynamoDB**, **HTTP API** → **Lambda**. After the first deploy, upload the real API bundle (see below). **Settings → Account** uses **dart-define** for region, user pool, client id, and API URL; if those are unset, the app stays **local-only** (Open-Meteo still works).

### Deploy / update the Lambda API bundle

From the repo root:

```bash
chmod +x infrastructure/lambda/build.sh
./infrastructure/lambda/build.sh
aws lambda update-function-code \
  --function-name "$(aws cloudformation describe-stacks --stack-name weather-history-dev --query 'Stacks[0].Outputs[?OutputKey==`ApiLambdaName`].OutputValue' --output text)" \
  --zip-file fileb://infrastructure/lambda/api/function.zip
```

Re-deploy the stack if you change IAM or environment variables:

```bash
aws cloudformation deploy --template-file infrastructure/cloudformation/template.yaml \
  --stack-name weather-history-dev --parameter-overrides Environment=dev \
  --capabilities CAPABILITY_IAM
```

### Run Flutter against your stack (optional)

Pass outputs from CloudFormation (pool id, client id, API URL without path suffix):

```bash
cd app
flutter run -d chrome \
  --dart-define=COGNITO_REGION=eu-west-1 \
  --dart-define=COGNITO_USER_POOL_ID=eu-west-1_xxxxx \
  --dart-define=COGNITO_CLIENT_ID=xxxxxxxx \
  --dart-define=API_BASE_URL=https://xxxx.execute-api.eu-west-1.amazonaws.com
```

Use **Settings → Sign up** (confirm the email code), then **Sign in**, then **Pull from cloud** / **Push to cloud** as needed.

**Linux desktop:** `flutter_secure_storage` may need `libsecret`; install your distro’s `libsecret` / `libsecret-1-0` package if token storage fails.

- **No in-app rate limiting** for Open-Meteo — monitor usage; see [Pricing](https://open-meteo.com/en/pricing) if you need commercial or higher limits.

## Licence

Weather data is subject to **CC-BY 4.0** (see Open-Meteo [licence](https://open-meteo.com/en/licence)); the app shows a short attribution string.