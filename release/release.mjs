#!/usr/bin/env node
/**
 * MedicalVault Firebase App Distribution release engine.
 *
 * Canonical macOS/Linux implementation of the full release pipeline.
 * `release.sh` is a thin wrapper that locates Node and delegates here, so all
 * real release logic lives in one place.
 *
 * This is a DISTINCT pipeline from `Backend-MedicalVault/scripts/
 * release-app-update.mjs`, which manages the self-hosted in-app update
 * feed (`app-update.json`). This script targets Firebase App Distribution
 * (tester delivery). They do not share output files or state, and either
 * can be run independently.
 *
 * Pipeline stages (in order):
 *   1. Read + validate version from pubspec.yaml (must be greater than the
 *      highest version already present in release-history.json).
 *   2. flutter clean && flutter pub get && flutter build apk --release
 *      (and optionally --build-name/--build-number override).
 *   3. Locate the built APK and rename it to MedicalVault-v<version>+<build>.apk.
 *   4. Refuse to overwrite an existing artifact for the same version.
 *   5. Compute SHA-256 + MD5 checksums.
 *   6. Collect git commit hash + branch (best-effort; not fatal if absent).
 *   7. Write per-release metadata JSON + release-notes.txt.
 *   8. Optionally build an AAB alongside the APK (--aab).
 *   9. Zip the APK + metadata + release notes into one archive.
 *  10. Upload the APK to Firebase App Distribution via the Firebase CLI,
 *      unless --skip-upload was passed.
 *  11. Append an entry to release-history.json (append-only, never
 *      overwritten or truncated).
 *  12. Print a human-readable release summary.
 *
 * Usage:
 *   node release/release.mjs [options]
 *
 * Options:
 *   --notes "<text>"       Inline release notes (overrides the template).
 *   --notes-file <path>    Read release notes from a file.
 *   --groups a,b,c         Comma-separated tester groups (overrides config).
 *   --testers a@x.com,...  Comma-separated tester emails (overrides config).
 *   --aab                  Also build an Android App Bundle.
 *   --skip-upload          Build and package locally; do not call Firebase.
 *   --skip-clean           Skip `flutter clean` (faster iterative testing).
 *   --dry-run              Do everything except the actual Firebase upload
 *                          and the actual `flutter build` — validates
 *                          version/config and prints the plan only.
 *   --config <path>        Use an alternate config file instead of the
 *                          default firebase-distribution.config.json.
 *
 * Exit codes: 0 success, 1 any failure (see the printed error for cause).
 */

import { execFileSync, execFile } from "node:child_process";
import { promisify } from "node:util";
import { createHash } from "node:crypto";
import { createReadStream, existsSync, readFileSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const APP_DIR = path.resolve(__dirname, ".."); // MedicalVault/
const RELEASE_DIR = __dirname; // MedicalVault/release/

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

const COLOR = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  gray: "\x1b[90m",
};

function paint(color, text) {
  if (process.env.NO_COLOR) return text;
  return `${COLOR[color]}${text}${COLOR.reset}`;
}

function logStep(message) {
  console.log(paint("cyan", `\n▶ ${message}`));
}

function logInfo(message) {
  console.log(`  ${message}`);
}

function logSuccess(message) {
  console.log(paint("green", `  ✔ ${message}`));
}

function logWarn(message) {
  console.warn(paint("yellow", `  ⚠ ${message}`));
}

class ReleaseError extends Error {
  constructor(code, message, hint) {
    super(message);
    this.code = code;
    this.hint = hint;
  }
}

function fail(code, message, hint) {
  throw new ReleaseError(code, message, hint);
}

function nowIso() {
  return new Date().toISOString();
}

/** Formats a Date as "YYYY-MM-DD HH:mm:ss" in the local timezone. */
function formatTimestamp(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

function parseArgs(argv) {
  const args = {
    notes: null,
    notesFile: null,
    groups: null,
    testers: null,
    aab: false,
    skipUpload: false,
    skipClean: false,
    dryRun: false,
    configPath: null,
    buildName: null,
    buildNumber: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case "--notes":
        args.notes = argv[++i];
        break;
      case "--notes-file":
        args.notesFile = argv[++i];
        break;
      case "--groups":
        args.groups = argv[++i].split(",").map((s) => s.trim()).filter(Boolean);
        break;
      case "--testers":
        args.testers = argv[++i].split(",").map((s) => s.trim()).filter(Boolean);
        break;
      case "--aab":
        args.aab = true;
        break;
      case "--skip-upload":
        args.skipUpload = true;
        break;
      case "--skip-clean":
        args.skipClean = true;
        break;
      case "--dry-run":
        args.dryRun = true;
        break;
      case "--config":
        args.configPath = argv[++i];
        break;
      case "--build-name":
        args.buildName = argv[++i];
        break;
      case "--build-number":
        args.buildNumber = argv[++i];
        break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
        break;
      default:
        fail("UNKNOWN_ARG", `Unknown argument: ${arg}`, "Run with --help for usage.");
    }
  }
  return args;
}

function printHelp() {
  const header = readFileSync(__filename, "utf8").split("\n").slice(0, 60);
  console.log(
    header
      .filter((l) => l.startsWith(" *"))
      .map((l) => l.replace(/^ \*\/?\s?/, ""))
      .join("\n"),
  );
}

// ---------------------------------------------------------------------------
// Config loading (committed template + optional gitignored local override)
// ---------------------------------------------------------------------------

function loadConfig(explicitPath) {
  const templatePath = explicitPath
    ? path.resolve(process.cwd(), explicitPath)
    : path.join(RELEASE_DIR, "firebase-distribution.config.json");
  if (!existsSync(templatePath)) {
    fail(
      "CONFIG_MISSING",
      `Firebase distribution config not found at ${templatePath}`,
      "Restore release/firebase-distribution.config.json or pass --config <path>.",
    );
  }

  let base;
  try {
    base = JSON.parse(readFileSync(templatePath, "utf8"));
  } catch (error) {
    fail("CONFIG_INVALID", `Failed to parse ${templatePath}: ${error.message}`);
  }

  const localPath = path.join(RELEASE_DIR, "firebase-distribution.local.json");
  if (existsSync(localPath)) {
    try {
      const local = JSON.parse(readFileSync(localPath, "utf8"));
      base = deepMerge(base, local);
      base.__localOverrideApplied = true;
    } catch (error) {
      fail("CONFIG_INVALID", `Failed to parse ${localPath}: ${error.message}`);
    }
  }

  if (!base.firebase?.androidAppId) {
    fail(
      "CONFIG_INVALID",
      "firebase.androidAppId is missing from the distribution config.",
      "Set it in firebase-distribution.config.json or firebase-distribution.local.json.",
    );
  }

  return base;
}

function deepMerge(target, source) {
  const output = { ...target };
  for (const [key, value] of Object.entries(source)) {
    if (
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      target[key] &&
      typeof target[key] === "object" &&
      !Array.isArray(target[key])
    ) {
      output[key] = deepMerge(target[key], value);
    } else {
      output[key] = value;
    }
  }
  return output;
}

// ---------------------------------------------------------------------------
// Version handling
// ---------------------------------------------------------------------------

/** Reads and parses `version: X.Y.Z+N` from pubspec.yaml. */
function readPubspecVersion(pubspecPath) {
  if (!existsSync(pubspecPath)) {
    fail("PUBSPEC_MISSING", `pubspec.yaml not found at ${pubspecPath}`);
  }
  const content = readFileSync(pubspecPath, "utf8");
  const match = content.match(/^version:\s*(\S+)\s*$/m);
  if (!match) {
    fail(
      "PUBSPEC_VERSION_MISSING",
      `No "version:" line found in ${pubspecPath}`,
      'Add a line like "version: 1.0.3+14" to pubspec.yaml.',
    );
  }
  const raw = match[1];
  const [versionName, buildNumberRaw] = raw.split("+");
  if (!versionName || !buildNumberRaw || !/^\d+$/.test(buildNumberRaw)) {
    fail(
      "PUBSPEC_VERSION_INVALID",
      `pubspec.yaml version "${raw}" is not in the expected "X.Y.Z+N" form.`,
    );
  }
  if (!/^\d+\.\d+\.\d+$/.test(versionName)) {
    fail(
      "PUBSPEC_VERSION_INVALID",
      `pubspec.yaml version name "${versionName}" is not in the expected "X.Y.Z" form.`,
    );
  }
  return { versionName, buildNumber: buildNumberRaw, raw };
}

/** Compares two "X.Y.Z" semantic version strings. Returns -1, 0, or 1. */
function compareVersions(a, b) {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < 3; i += 1) {
    if (pa[i] !== pb[i]) return pa[i] > pb[i] ? 1 : -1;
  }
  return 0;
}

/** Reads the highest previously-released version from release-history.json. */
async function highestReleasedVersion(historyPath) {
  if (!existsSync(historyPath)) return null;
  const raw = await fs.readFile(historyPath, "utf8");
  let history;
  try {
    history = JSON.parse(raw);
  } catch (error) {
    fail("HISTORY_INVALID", `release-history.json is not valid JSON: ${error.message}`);
  }
  if (!Array.isArray(history) || history.length === 0) return null;
  return history.reduce((highest, entry) => {
    if (!highest) return entry.version;
    return compareVersions(entry.version, highest) > 0 ? entry.version : highest;
  }, null);
}

function releaseExistsInHistory(history, versionName, buildNumber) {
  return history.some((entry) => entry.version === versionName && Number(entry.buildNumber) === Number(buildNumber));
}

function highestReleasedBuild(history) {
  const builds = history.map((entry) => Number(entry.buildNumber)).filter((value) => Number.isInteger(value) && value > 0);
  return builds.length ? Math.max(...builds) : null;
}

// ---------------------------------------------------------------------------
// Shell / tool helpers
// ---------------------------------------------------------------------------

function commandExists(command) {
  try {
    execFileSync("which", [command], {
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

function run(command, args, options = {}) {
  logInfo(paint("gray", `$ ${command} ${args.join(" ")}`));
  return execFileSync(command, args, {
    cwd: APP_DIR,
    stdio: "inherit",
    ...options,
  });
}

function runCapture(command, args, options = {}) {
  try {
    return execFileSync(command, args, {
      cwd: APP_DIR,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      ...options,
    }).trim();
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Checksums
// ---------------------------------------------------------------------------

function hashFile(filePath, algorithm) {
  return new Promise((resolve, reject) => {
    const hash = createHash(algorithm);
    const stream = createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
    stream.on("error", reject);
  });
}

// ---------------------------------------------------------------------------
// Git metadata (best-effort; missing git is not fatal)
// ---------------------------------------------------------------------------

function collectGitMetadata() {
  if (!commandExists("git")) return { commit: null, branch: null, dirty: null };
  const commit = runCapture("git", ["rev-parse", "--short", "HEAD"]);
  const branch = runCapture("git", ["rev-parse", "--abbrev-ref", "HEAD"]);
  const status = runCapture("git", ["status", "--porcelain"]);
  return {
    commit,
    branch,
    dirty: status === null ? null : status.length > 0,
  };
}

// ---------------------------------------------------------------------------
// Firebase CLI
// ---------------------------------------------------------------------------

function assertFirebaseCliAvailable() {
  if (!commandExists("firebase")) {
    fail(
      "FIREBASE_CLI_MISSING",
      "Firebase CLI ('firebase') was not found on PATH.",
      "Install it with: npm install -g firebase-tools",
    );
  }
}

async function uploadToFirebase({ appId, apkPath, releaseNotesPath, groups, emails }) {
  assertFirebaseCliAvailable();

  const args = [
    "appdistribution:distribute",
    apkPath,
    "--app",
    appId,
    "--release-notes-file",
    releaseNotesPath,
  ];
  if (groups && groups.length > 0) {
    args.push("--groups", groups.join(","));
  }
  if (emails && emails.length > 0) {
    args.push("--testers", emails.join(","));
  }

  logInfo(paint("gray", `$ firebase ${args.join(" ")}`));
  let stdout = "";
  let stderr = "";
  let lastError = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const result = await execFileAsync("firebase", args, { cwd: APP_DIR });
      stdout = result.stdout;
      stderr = result.stderr;
      lastError = null;
      break;
    } catch (error) {
      lastError = error;
      stdout = error.stdout || "";
      stderr = error.stderr || error.message || "";
      const terminal = /authentication error|not logged in|login|app.*not found|no app with id|permission/i.test(stderr);
      if (!terminal && attempt < 3) {
        logWarn(`Firebase upload attempt ${attempt}/3 failed; retrying in ${attempt * 2}s.`);
        await new Promise((resolve) => setTimeout(resolve, attempt * 2000));
      } else {
        break;
      }
    }
  }
  if (lastError) {
    if (/authentication error|not logged in|login/i.test(stderr)) {
      fail("FIREBASE_LOGIN_EXPIRED", "Firebase CLI is not authenticated (login expired or never logged in).", "Run: firebase login");
    }
    if (/app.*not found|no app with id|400|permission/i.test(stderr)) {
      fail("FIREBASE_APP_ID_INVALID", `Firebase rejected app ID "${appId}". It may be wrong or you may lack access.`, "Verify firebase.androidAppId in the distribution config against the Firebase console.");
    }
    fail("FIREBASE_UPLOAD_FAILED", `Firebase App Distribution upload failed after 3 attempts: ${stderr || lastError.message}`);
  }

  const combined = `${stdout}\n${stderr}`;
  const releaseIdMatch = combined.match(/releases?\/([A-Za-z0-9_-]+)/i);
  const firebaseReleaseId = releaseIdMatch ? releaseIdMatch[1] : null;

  return { firebaseReleaseId, rawOutput: combined.trim() };
}

// ---------------------------------------------------------------------------
// macOS ships `zip`; no Windows-only shell fallback is used.
// ---------------------------------------------------------------------------

async function createZipArchive(zipPath, files) {
  if (commandExists("zip")) {
    const args = ["-j", zipPath, ...files];
    execFileSync("zip", args, { stdio: "ignore" });
    return;
  }
  fail("ZIP_MISSING", "macOS 'zip' command was not found.", "Install the Command Line Tools with: xcode-select --install");
}

// ---------------------------------------------------------------------------
// Main pipeline
// ---------------------------------------------------------------------------

async function main() {
  const startedAt = Date.now();
  const args = parseArgs(process.argv.slice(2));

  console.log(paint("bold", "\n=== MedicalVault → Firebase App Distribution Release ===\n"));

  const config = loadConfig(args.configPath);
  const pubspecPath = path.resolve(RELEASE_DIR, config.pubspecPath || "../pubspec.yaml");
  const artifactDir = path.resolve(RELEASE_DIR, config.artifactDirectory || "../releases");
  const historyPath = path.join(artifactDir, "release-history.json");

  // 1. Version read + validation ------------------------------------------
  logStep("Reading version from pubspec.yaml");
  const { versionName, buildNumber } = readPubspecVersion(pubspecPath);
  logInfo(`Version Name  : ${versionName}`);
  logInfo(`Build Number  : ${buildNumber}`);

  await fs.mkdir(artifactDir, { recursive: true });

  // The build is part of the filename: same-version hotfix builds are valid
  // and must never overwrite an earlier APK.
  const apkName = `MedicalVault-v${versionName}+${buildNumber}.apk`;
  const apkOutPath = path.join(artifactDir, apkName);
  const releaseStem = `MedicalVault-v${versionName}+${buildNumber}`;
  const metadataPath = path.join(artifactDir, `${releaseStem}.json`);
  const releaseNotesPath = path.join(artifactDir, `${releaseStem}-release-notes.txt`);
  const zipPath = path.join(artifactDir, `${releaseStem}.zip`);

  if (existsSync(apkOutPath)) {
    fail(
      "DUPLICATE_VERSION",
      `An artifact for version ${versionName} already exists: ${apkOutPath}`,
      "Bump the version in pubspec.yaml before releasing again. Existing releases are never overwritten.",
    );
  }

  let history = [];
  if (existsSync(historyPath)) {
    try {
      history = JSON.parse(await fs.readFile(historyPath, "utf8"));
    } catch (error) {
      fail("HISTORY_INVALID", `release-history.json is not valid JSON: ${error.message}`);
    }
  }
  if (releaseExistsInHistory(history, versionName, buildNumber)) {
    fail(
      "DUPLICATE_VERSION",
      `Version ${versionName}+${buildNumber} already appears in release-history.json.`,
      "Bump the build number in pubspec.yaml before releasing again.",
    );
  }

  const previousVersion = await highestReleasedVersion(historyPath);
  if (previousVersion && compareVersions(versionName, previousVersion) < 0) {
    fail(
      "VERSION_NOT_GREATER",
      `New version ${versionName} is lower than the last released version ${previousVersion}.`,
      "Use a semantic version not lower than the latest release and retry.",
    );
  }
  const previousBuild = highestReleasedBuild(history);
  if (previousBuild !== null && Number(buildNumber) <= previousBuild) {
    fail(
      "BUILD_NUMBER_NOT_GREATER",
      `New build number ${buildNumber} must be greater than the latest released build ${previousBuild}.`,
      "Increment the number after '+' in pubspec.yaml before releasing.",
    );
  }
  if (previousVersion) {
    logInfo(`Previous release: ${previousVersion}+${previousBuild} (new release is valid: ${versionName}+${buildNumber})`);
  } else {
    logInfo("No previous release found in history — this will be the first tracked release.");
  }

  if (args.dryRun) {
    logWarn("--dry-run: stopping after validation. No build, no upload, nothing written.");
    console.log(paint("green", "\nDry run OK — version is valid and ready to release.\n"));
    return;
  }

  // 2. Flutter toolchain checks ---------------------------------------------
  logStep("Checking Flutter SDK");
  if (!commandExists("flutter")) {
    fail(
      "FLUTTER_MISSING",
      "Flutter SDK ('flutter') was not found on PATH.",
      "Install Flutter and ensure it is on PATH: https://docs.flutter.dev/get-started/install",
    );
  }
  logSuccess("Flutter SDK found.");

  // 3. Build -----------------------------------------------------------------
  if (!args.skipClean) {
    logStep("flutter clean");
    run("flutter", ["clean"]);
  } else {
    logWarn("--skip-clean: skipping flutter clean.");
  }

  logStep("flutter pub get");
  run("flutter", ["pub", "get"]);

  logStep("Building release APK");
  const buildArgs = ["build", "apk", "--release"];
  if (args.buildName) buildArgs.push("--build-name", args.buildName);
  if (args.buildNumber) buildArgs.push("--build-number", args.buildNumber);
  try {
    run("flutter", buildArgs);
  } catch (error) {
    fail("BUILD_FAILED", `flutter build apk --release failed: ${error.message}`);
  }

  const builtApkPath = path.join(APP_DIR, "build", "app", "outputs", "flutter-apk", "app-release.apk");
  if (!existsSync(builtApkPath)) {
    fail(
      "APK_MISSING",
      `Expected built APK not found at ${builtApkPath}`,
      "Check the flutter build output above for errors.",
    );
  }
  logSuccess(`Built APK: ${builtApkPath}`);

  let aabOutPath = null;
  if (args.aab) {
    logStep("Building Android App Bundle (AAB)");
    const aabArgs = ["build", "appbundle", "--release"];
    if (args.buildName) aabArgs.push("--build-name", args.buildName);
    if (args.buildNumber) aabArgs.push("--build-number", args.buildNumber);
    run("flutter", aabArgs);
    const builtAabPath = path.join(APP_DIR, "build", "app", "outputs", "bundle", "release", "app-release.aab");
    if (existsSync(builtAabPath)) {
      aabOutPath = path.join(artifactDir, `MedicalVault-v${versionName}+${buildNumber}.aab`);
      await fs.copyFile(builtAabPath, aabOutPath);
      logSuccess(`AAB copied to ${aabOutPath}`);
    } else {
      logWarn(`AAB build reported success but file not found at ${builtAabPath}`);
    }
  }

  // 4. Rename / move into releases/ -------------------------------------------
  logStep("Archiving APK into releases/");
  await fs.copyFile(builtApkPath, apkOutPath);
  logSuccess(`${apkName} written to ${artifactDir}`);

  // 5. Checksums ----------------------------------------------------------------
  logStep("Computing checksums");
  const sha256 = await hashFile(apkOutPath, "sha256");
  const md5 = await hashFile(apkOutPath, "md5");
  logInfo(`SHA-256: ${sha256}`);
  logInfo(`MD5    : ${md5}`);

  // 6. Git metadata ---------------------------------------------------------------
  const git = collectGitMetadata();

  // 7. Release notes ----------------------------------------------------------------
  logStep("Generating release notes");
  let releaseNotes;
  if (args.notes) {
    releaseNotes = args.notes;
  } else if (args.notesFile) {
    if (!existsSync(args.notesFile)) {
      fail("NOTES_FILE_MISSING", `--notes-file path does not exist: ${args.notesFile}`);
    }
    releaseNotes = await fs.readFile(args.notesFile, "utf8");
  } else {
    const template = config.releaseNotes?.template || "Version {version}\n• Release {version}";
    releaseNotes = template
      .replaceAll("{version}", versionName)
      .replaceAll("{buildNumber}", buildNumber)
      .replaceAll("{date}", formatTimestamp(new Date()));
  }
  await fs.writeFile(releaseNotesPath, releaseNotes.trimEnd() + "\n", "utf8");
  logSuccess(`release-notes written: ${releaseNotesPath}`);

  // 8. Per-release metadata JSON --------------------------------------------------
  logStep("Writing release metadata");
  const releaseDate = formatTimestamp(new Date());
  const groups = args.groups || config.testers?.groups || [];
  const emails = args.testers || config.testers?.emails || [];

  const metadata = {
    appName: config.appName || "MedicalVault",
    version: versionName,
    buildNumber,
    releaseDate,
    artifact: apkName,
    aab: aabOutPath ? path.basename(aabOutPath) : null,
    checksums: { sha256, md5 },
    git,
    buildDurationSeconds: null, // filled in below once known
    uploadedToFirebase: false,
    firebaseReleaseId: null,
    testerGroups: groups,
    testerEmails: emails,
    releaseNotesFile: path.basename(releaseNotesPath),
  };

  // 9. Firebase App Distribution upload --------------------------------------------
  if (!args.skipUpload) {
    logStep("Uploading to Firebase App Distribution");
    try {
      const uploadResult = await uploadToFirebase({
        appId: config.firebase.androidAppId,
        apkPath: apkOutPath,
        releaseNotesPath,
        groups,
        emails,
      });
      metadata.uploadedToFirebase = true;
      metadata.firebaseReleaseId = uploadResult.firebaseReleaseId;
      logSuccess("Upload succeeded.");
      if (uploadResult.firebaseReleaseId) {
        logInfo(`Firebase Release ID: ${uploadResult.firebaseReleaseId}`);
      } else {
        logWarn("Upload succeeded but a release ID could not be parsed from CLI output.");
      }
    } catch (error) {
      // Preserve metadata for diagnosis; a failed upload is not a released
      // artifact and is intentionally not appended to release history.
      metadata.uploadedToFirebase = false;
      metadata.uploadError = error.message;
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2) + "\n", "utf8");
      throw error;
    }
  } else {
    logWarn("--skip-upload: artifact built and archived locally, Firebase upload skipped.");
  }

  metadata.buildDurationSeconds = Math.round((Date.now() - startedAt) / 1000);
  await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2) + "\n", "utf8");
  logSuccess(`metadata written: ${metadataPath}`);

  // 10. ZIP archive -----------------------------------------------------------------
  logStep("Creating ZIP archive");
  await createZipArchive(zipPath, [apkOutPath, metadataPath, releaseNotesPath]);
  if (existsSync(zipPath)) {
    logSuccess(`archive written: ${zipPath}`);
  }

  // 11. Append-only history ----------------------------------------------------------
  logStep("Updating release-history.json");
  await appendHistory(historyPath, buildHistoryEntry(metadata, startedAt));
  logSuccess(`history updated: ${historyPath}`);

  // 12. Summary -------------------------------------------------------------------------
  printSummary({ config, versionName, buildNumber, apkName, artifactDir, metadata });
}

function buildHistoryEntry(metadata, startedAt) {
  return {
    version: metadata.version,
    buildNumber: metadata.buildNumber,
    date: metadata.releaseDate,
    apkName: metadata.artifact,
    firebaseUploaded: metadata.uploadedToFirebase,
    firebaseReleaseId: metadata.firebaseReleaseId,
    sha256: metadata.checksums.sha256,
    gitCommit: metadata.git?.commit || null,
    gitBranch: metadata.git?.branch || null,
    buildDurationSeconds: metadata.buildDurationSeconds ?? Math.round((Date.now() - startedAt) / 1000),
    recordedAt: nowIso(),
  };
}

async function appendHistory(historyPath, entry) {
  let history = [];
  if (existsSync(historyPath)) {
    try {
      history = JSON.parse(await fs.readFile(historyPath, "utf8"));
      if (!Array.isArray(history)) history = [];
    } catch {
      history = [];
    }
  }
  history.push(entry);
  await fs.writeFile(historyPath, JSON.stringify(history, null, 2) + "\n", "utf8");
}

function printSummary({ versionName, buildNumber, apkName, artifactDir, metadata }) {
  const rows = [
    ["Application Name", metadata.appName],
    ["Version", versionName],
    ["Build Number", buildNumber],
    ["APK Name", apkName],
    ["Release Folder", artifactDir],
    ["Firebase Upload", metadata.uploadedToFirebase ? "Successful" : "Skipped / Failed"],
    ["Firebase Release ID", metadata.firebaseReleaseId || "—"],
    ["SHA-256", metadata.checksums.sha256],
    ["Build Duration", `${metadata.buildDurationSeconds}s`],
  ];
  console.log(paint("bold", "\n=== Release Summary ===\n"));
  const labelWidth = Math.max(...rows.map(([label]) => label.length));
  for (const [label, value] of rows) {
    console.log(`  ${label.padEnd(labelWidth)} : ${value}`);
  }
  console.log(paint("green", "\nCompleted Successfully\n"));
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

main().catch((error) => {
  if (error instanceof ReleaseError) {
    console.error(paint("red", `\n✘ [${error.code}] ${error.message}`));
    if (error.hint) console.error(paint("yellow", `  Hint: ${error.hint}`));
  } else {
    console.error(paint("red", `\n✘ Unexpected error: ${error.stack || error.message}`));
  }
  process.exit(1);
});
