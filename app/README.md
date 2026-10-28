# English Learning Academy — Flutter app

Flutter/Dart Android application source for **أكاديمية الإنجليزية**.

## Current phase

Phase 1 provides the Flutter entry point, Arabic RTL dashboard, learning-track navigation placeholders, API configuration, an HTTPS API client scaffold, a lesson model, and a widget smoke test. Lesson screens, remote content, accounts, cloud sync, and AI tutoring are not connected services yet.

## Run locally

Install the Flutter SDK and Android toolchain, then run:

```sh
cd app
flutter create --platforms=android --project-name english_learning_legal_academy .
flutter pub get
flutter analyze
flutter test
flutter run
```

If Android platform files already exist, review local changes before regenerating them.

Set the public API base URL only after deploying a real HTTPS API:

```sh
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

Do not place provider API keys, database credentials, or GitHub tokens in Flutter source or build-time defines. Mobile configuration is not a secure place for secrets.

## Online architecture

- **GitHub:** version-controlled source code and reviewed lesson/content files.
- **HTTPS API:** serves published content to the app.
- **Cloud database:** stores private user accounts and learning progress.
- **AI provider:** accessed only through the backend.

These services must be deployed and configured separately before the app can use them. The API client reports a configuration error when no API URL is supplied; it does not pretend a backend is connected.
