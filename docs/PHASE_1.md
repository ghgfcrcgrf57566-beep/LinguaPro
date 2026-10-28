# Phase 1 — Flutter foundation

## Repository

The existing repository `ghgfcrcgrf57566-beep/LinguaPro` is retained. No new repository was created. The existing root-level web prototype remains in place; Flutter source is in `app/`.

## Added in this phase

- Flutter package manifest and Dart entry point.
- Material app theme with Arabic RTL direction.
- Responsive dashboard with English learning and Legal English track cards.
- HTTPS API client scaffold configured through a public base URL.
- Typed lesson model and widget smoke test.
- Dart lint configuration and ignore rules.
- GitHub Actions workflow for Flutter analysis, tests, and an Android App Bundle build attempt.
- Setup and architecture documentation.

## Architecture boundaries

GitHub manages source code and reviewed content versions; it is not a live user database. The app should fetch published educational content through an HTTPS API. Accounts, progress, favorites, and conversation history require a configured backend and database with access controls. Provider secrets must remain on the server.

## Verification status

Files have been saved to the repository. This chat environment did not run Flutter, Android build tools, or the GitHub Actions workflow. Therefore no successful `flutter analyze`, `flutter test`, or AAB build is claimed. CI is configured to attempt these checks when it runs.
