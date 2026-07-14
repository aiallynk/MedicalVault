# MedicalVault → Firebase App Distribution Release Pipeline

One command builds, versions, checksums, archives, and uploads a signed
release APK to Firebase App Distribution, then records the release forever
in an append-only history file.

This pipeline is independent from `Backend-MedicalVault/scripts/
release-app-update.mjs`, which manages the separate self-hosted in-app
update feed (`app-update.json`, APK served from the backend for the
in-app "update available" banner). Use **this** pipeline to hand a build to
testers via Firebase; use the other one to publish the build your existing
users' phones auto-detect. They share no files and can be run in either
order.

## Quick start

```bash
# macOS / Linux
cd MedicalVault/release
./release.sh
```

That's it — a single run will clean, build, checksum, archive, and upload.

## One-time setup

1. **Install the Flutter SDK** and confirm `flutter` is on `PATH`
   (`flutter --version`).
2. **Install the Firebase CLI**: `npm install -g firebase-tools`.
3. **Authenticate**: `firebase login`. The pipeline detects an expired or
   missing login and tells you to re-run this.
4. **Confirm the Android signing config exists** — `MedicalVault/android/
   key.properties` and the keystore it points at. Without it, `flutter
   build apk --release` falls back to debug signing, which Firebase App
   Distribution will still accept but which is not a Play-ready artifact.
5. **Review `firebase-distribution.config.json`** in this folder. The
   Android app ID is already filled in from the project's existing
   `firebase.json`/`firebase_options.dart`. Add your real tester groups —
   groups must already exist in the Firebase console
   (Release & Monitor → App Distribution → Testers & Groups).
6. **Optional — real tester emails**: don't edit the committed config for
   this. Instead create `firebase-distribution.local.json` next to it
   (already gitignored) with just the fields you want to override, e.g.:

   ```json
   {
     "testers": {
       "emails": ["alice@example.com", "bob@example.com"]
     }
   }
   ```

   It is shallow-merged on top of the committed config at run time, so you
   only need to include the keys you're changing.

## What a release run does

1. Reads `version: X.Y.Z+N` from `MedicalVault/pubspec.yaml`.
2. Validates `version: X.Y.Z+N`: semantic version cannot go backwards,
   build `N` must be greater than every recorded release build, and the exact
   version/build pair cannot already exist. This permits a safe same-version
   higher-build hotfix such as `1.0.24+24` → `1.0.24+25`.
3. Runs `flutter clean && flutter pub get && flutter build apk --release`.
4. Copies the built APK into `releases/` as
   `MedicalVault-v<version>+<build>.apk` (e.g.
   `MedicalVault-v1.0.24+25.apk` — never `app-release.apk`).
5. Computes SHA-256 and MD5 checksums of the archived APK.
6. Collects the current git commit hash, branch, and dirty-working-tree
   flag (best-effort — a missing `git` binary does not fail the release).
7. Writes release notes to `MedicalVault-<version>-release-notes.txt`
   (your `--notes`/`--notes-file`, or an auto-generated default using the
   version and today's date).
8. Writes `MedicalVault-<version>.json` with full metadata (see below).
9. Optionally builds an AAB alongside the APK (`--aab`).
10. Zips the APK + metadata + release notes into
    `MedicalVault-<version>.zip`.
11. Uploads the APK to Firebase App Distribution via the Firebase CLI,
    targeting the configured tester groups/emails (unless `--skip-upload`).
12. Appends one entry to `releases/release-history.json` — this file is
    read, appended to, and rewritten in full each time, but existing
    entries are never dropped or edited.
13. Prints a release summary table.

## Output layout

```
MedicalVault/
  releases/                                   ← gitignored, grows forever
    MedicalVault-v1.0.24+24.apk
    MedicalVault-v1.0.24+24.json
    MedicalVault-v1.0.24+24-release-notes.txt
    MedicalVault-v1.0.24+24.zip
    MedicalVault-v1.0.24+25.apk
    MedicalVault-v1.0.24+25.json
    ...
    release-history.json                      ← one growing array, append-only
```

### `MedicalVault-<version>.json` fields

| Field | Meaning |
| --- | --- |
| `appName` | Always `MedicalVault`. |
| `version` / `buildNumber` | From `pubspec.yaml`. |
| `releaseDate` | `YYYY-MM-DD HH:mm:ss`, local time. |
| `artifact` | The APK filename. |
| `aab` | AAB filename if `--aab` was used, else `null`. |
| `checksums.sha256` / `checksums.md5` | Of the archived APK. |
| `git.commit` / `git.branch` / `git.dirty` | Best-effort; `null` if git is unavailable. |
| `buildDurationSeconds` | Wall-clock time for the whole pipeline run. |
| `uploadedToFirebase` | `true` only if the Firebase CLI call succeeded. |
| `firebaseReleaseId` | Parsed from CLI output when available. |
| `testerGroups` / `testerEmails` | What this release was actually distributed to. |
| `releaseNotesFile` | The paired `.txt` file name. |

### `release-history.json` entries

Each entry is a compact summary (version, build, date, APK name, upload
status/release ID, sha256, git commit/branch, build duration, recorded-at
timestamp) — enough to audit "what shipped when" without opening every
per-release JSON file.

## Command reference

```
release.sh [options]

  --notes "<text>"        Inline release notes (overrides the template).
  --notes-file <path>     Read release notes from a file.
  --groups a,b,c          Comma-separated tester groups (overrides config).
  --testers a@x.com,...   Comma-separated tester emails (overrides config).
  --aab                   Also build an Android App Bundle.
  --skip-upload           Build and package locally; skip the Firebase step.
  --skip-clean            Skip `flutter clean` (faster iterative testing).
  --dry-run               Validate the version and config only — no build,
                          no upload, nothing written to releases/.
  --config <path>         Use an alternate config file.
  --build-name <X.Y.Z>    Override the build name passed to flutter build
                          (rarely needed — normally read from pubspec.yaml).
  --build-number <N>      Override the build number passed to flutter build.
```

Examples:

```bash
./release.sh --notes "Version 1.0.4\n• Fixed SOS location accuracy"
./release.sh --groups qa-team,beta-testers
./release.sh --aab --skip-upload      # local-only build, review before shipping
./release.sh --dry-run                # just check the version is releasable
```

## Error handling

The engine fails fast with a labeled error code and an actionable hint —
nothing partially completes silently:

| Code | Cause |
| --- | --- |
| `FLUTTER_MISSING` | `flutter` not found on `PATH`. |
| `FIREBASE_CLI_MISSING` | `firebase` not found on `PATH`. |
| `FIREBASE_LOGIN_EXPIRED` | Firebase CLI session expired or never logged in. |
| `FIREBASE_APP_ID_INVALID` | Configured Android app ID was rejected by Firebase. |
| `FIREBASE_UPLOAD_FAILED` | Any other Firebase CLI upload failure (message included). |
| `BUILD_FAILED` | `flutter build apk --release` returned a non-zero exit code. |
| `APK_MISSING` | Build reported success but the expected output APK was not found. |
| `PUBSPEC_MISSING` / `PUBSPEC_VERSION_MISSING` / `PUBSPEC_VERSION_INVALID` | `pubspec.yaml` missing, has no `version:` line, or it isn't `X.Y.Z+N`. |
| `DUPLICATE_VERSION` | An artifact or history entry already exists for this version. |
| `VERSION_NOT_GREATER` | New version is not strictly greater than the last released version. |
| `CONFIG_MISSING` / `CONFIG_INVALID` | Distribution config file missing or malformed. |
| `HISTORY_INVALID` | `release-history.json` exists but is not valid JSON. |
| `NOTES_FILE_MISSING` | `--notes-file` path does not exist. |

Firebase upload is retried automatically up to three times for transient
failures. Authentication, permission, and invalid-app errors fail fast. If
all attempts fail, metadata with the error is preserved but the failed
artifact is not appended to release history, so the same release can be
retried after the underlying issue is fixed.

## Design notes

- **One macOS entry point.** `release.sh` contains no pipeline logic — it
  only locates Node and delegates to `release.mjs`. The release pipeline uses
  `zsh`/`bash`-compatible tooling and macOS paths only.
- **Append-only history is enforced in code**, not just by convention: the
  history file is always read, validated, appended to, and rewritten in
  full — no code path truncates or replaces it wholesale.
- **No secrets in scripts.** The Firebase app ID, tester groups/emails, and
  release-notes template all live in `firebase-distribution.config.json`
  (committed) and the optional `firebase-distribution.local.json`
  (gitignored, for real tester PII).
