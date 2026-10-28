# Phase 2 — Learning engine and Legal English

## Implemented in this phase branch

- Local bundled A1 English and Legal English lesson content.
- Lesson list and lesson reader with vocabulary, explanations, and multiple-choice quizzes.
- Active recall: the learner attempts to remember a word before revealing its meaning.
- Self-rated vocabulary recall ("remembered" / "did not remember").
- Local word progress stored with SharedPreferences.
- A simple spaced-review schedule: correct recalls increase the interval (1, 3, 7 days, then doubling up to 90 days); missed words return in about four hours.
- Review center showing due words, intervals, and correct/incorrect counts.
- Legal English track covering contract, agreement, party, obligation, clause, court, judge, claim, evidence, and appeal.
- Legal vocabulary notes that warn terminology depends on context and that lessons are language education, not legal advice.
- Content validator support and tests for optional pronunciation hints.

## Scope and limitations

- This is an initial local learning engine, not a claim of parity with Duolingo.
- Pronunciation hints are text aids; speech audio, speech recognition, and pronunciation scoring are not connected.
- The AI tutor, user accounts, cloud sync, and remote API are not implemented by this phase.
- The spaced-review schedule is a simple baseline and should be evaluated with retention tests before being treated as pedagogically optimal.
- The lesson assets are bundled for offline use; future content changes must keep the bundled lesson assets aligned with the canonical `content/` files.

## Verification

GitHub Actions is configured to run content validation, Flutter analysis, tests, and an Android App Bundle build on the pull request. The actual result must be checked in the workflow run; creating this branch alone does not prove the build succeeded.
