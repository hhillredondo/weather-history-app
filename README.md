# Weather history

A Flutter app for looking up weather that has already happened. Search for a
place, save the ones you care about, and browse daily history around any date:
temperature, wind, precipitation, and the rest. Units are configurable and your
places and preferences are kept on the device.

There is also an optional AWS backend. Sign in and your saved locations sync
across devices, and you get a chat panel that can answer questions about the
history it fetches. Without it the app still works, just local to the one device.

Historical data comes from the
[Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api),
which is free for non-commercial use and licensed CC-BY 4.0. The app shows the
attribution.

## Running it locally

You need the Flutter SDK on your PATH. If you do not have it, follow
[Flutter's install guide](https://docs.flutter.dev/get-started/install) and then
check it over with `flutter doctor`.

The app lives in `app/`, not the repository root:

```bash
cd app
flutter pub get
flutter run -d chrome
```

That is everything for local use. Searching for places and browsing history both
hit Open-Meteo directly and need no credentials.

To run against a deployed backend instead, pass the stack outputs in at build
time:

```bash
flutter run -d chrome \
  --dart-define=COGNITO_REGION=eu-central-1 \
  --dart-define=COGNITO_USER_POOL_ID=eu-central-1_xxxxxxxxx \
  --dart-define=COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx \
  --dart-define=API_BASE_URL=https://your-api-id.execute-api.eu-central-1.amazonaws.com
```

Leave those out and the app stays local-only. On Linux desktop, token storage
goes through `libsecret`, so install your distribution's `libsecret` package if
signing in fails there.

## Tests

```bash
cd app && flutter test
```
