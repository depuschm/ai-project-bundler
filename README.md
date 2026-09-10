# 🧩 ai-project-bundler

**Turn your codebase into clean, AI-ready Markdown — in one command.**

Keeping an AI assistant's project knowledge in sync with a real codebase is tedious: you don't want binary assets, secrets, dependencies, or noisy migration files clogging up the context, and manually copy-pasting files gets old fast. `ai-project-bundler` walks your source tree once, skipping everything a ruleset tells it to ignore, and writes what's left as Markdown.

---

## ✨ Why you'd want this

- **Zero manual curation.** Point it at a folder, get back tidy Markdown ready to upload as project knowledge to Claude, ChatGPT, Gemini, or any other AI assistant.
- **Config-driven rules.** What to ignore (directories, extensions, filename patterns) lives in a `rules.json` file, not hardcoded in the script — add a new project type by editing config, not code.
- **Skips dependencies properly.** `node_modules`, `.git`, `bin`, `obj` and friends are pruned during the walk, so they're never read rather than read and discarded.
- **Single file or split by extension.** Bundle everything into one `.md`, or organize output into `tsx.md`, `css.md`, `json.md`, etc.
- **Handles large codebases gracefully.** Auto-splits output into numbered parts when it exceeds a size limit you set.
- **Your project is never modified.** No working copy, no deletions — the only thing written is the bundle, and it won't overwrite an existing output folder.
- **Never silently incomplete.** A file it can't read is reported, counted on its own line, and makes the run exit non-zero, so a missing source file can't slip past unnoticed.
- **No dependencies.** Just bash and coreutils. Nothing to install.

---

## 🚀 Quick start

```bash
chmod +x *.sh

# Run the full pipeline for your frontend
./main_frontend.sh

# ...and for your backend
./main_backend.sh
```

That's it — you'll end up with `App_Frontend_bundled/App_Frontend.md` (and the backend equivalent), ready to drag straight into your AI assistant's project knowledge.

---

## 🔧 How it works

One command does the whole job:

```bash
./bundle_files.sh ./App_Backend --mode backend
```

[`bundle_files.sh`](bundle_files_README.md) walks the source tree once. Directories listed in `exclude_dirs` are pruned — `find` never descends into them — and files matching an `extensions` or `patterns` rule are skipped as it goes. Everything else is written to Markdown with its relative path as a heading. Rules are read from [`rules.json`](rules.json) via [`rules_lib.sh`](rules_lib.sh), shared by every script that needs them.

Files skipped by a rule are reported, so nothing disappears quietly:

```
  [IGNORED]  assets/Logo.PNG  (extension: .png)
  [BUNDLED]  src/App.tsx → App_Backend.md
```

Point it at a working copy instead of your source if you prefer, but there's no need to.

[`bundle_files.sh`](bundle_files_README.md) has its own README with full usage details and examples.

### 🧹 What gets left out

Rules are named modes in [`rules.json`](rules.json), selected with `--mode`. A mode may define any of four keys, all optional:

| Key | Matches on | Effect |
|---|---|---|
| `exclude_dirs` | directory name | The directory is pruned — nothing beneath it is read at all |
| `extensions` | file extension, case-insensitive | The file is skipped |
| `patterns` | filename, as an extended regex | The file is skipped |
| `keep` | filename, as an extended regex | Exception: the file survives even if a rule above matches it |

`exclude_dirs` is the one that matters most for speed, and it's the only key that can express a *location*. Extensions and patterns see the filename alone, so neither can say "skip `node_modules`" — a dependency folder is full of the same `.js` and `.json` files as your own source.

`keep` exists because the other keys can't express an exception. Bash regular expressions have no negative lookahead, so "every `.html` except `index.html`" is not writable as a pattern.

It's also the one key that fails in the dangerous direction. A mistake in an ignore rule leaves an extra file in the bundle; a mistake in a `keep` rule quietly removes one you believed was protected. So a rule matching no file at all is reported:

```
⚠️  keep rule '^index\.htm$' matches no file — check it for typos.
    Anything it was meant to protect has been left out.
```

A rule that matches files no ignore rule would have touched is merely redundant and stays quiet.

The two built-in modes:

**`frontend`** — for a **React** app:
prunes `node_modules` `.git` `dist` `build` `coverage` `.next`; skips `.png` `.jpg/.jpeg` `.svg` `.ico` `.woff2` `.ttf` `.wav` `.mp3` `.pdf`

**`backend`** — for an **ASP.NET Core** app:
prunes `.git` `bin` `obj` `packages`; skips dated EF Core migrations (e.g. `20260308022512_InitialCreate.cs`) and `launchSettings.json`, which often holds secrets

Using a different stack? Add a key to `rules.json` and pass `--mode <that key>` — no script changes needed.

### 📦 Bundling options

```bash
# Single Markdown file
./bundle_files.sh ./App_Frontend --mode frontend

# One .md per file extension
./bundle_files.sh ./App_Frontend --mode frontend --by-extension

# Add a suffix to output filenames
./bundle_files.sh ./App_Frontend --mode frontend --suffix v2

# Split output once it exceeds 500KB
./bundle_files.sh ./App_Frontend --mode frontend --max-size 500

# A different ruleset file
./bundle_files.sh ./App_Mobile --mode mobile --rules my_rules.json

# No --mode at all: bundle every file, no filtering
./bundle_files.sh ./some_folder

# Fail before writing anything if any file can't be read
./bundle_files.sh ./App_Frontend --mode frontend --strict
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success — everything was bundled, or `--help` was asked for |
| `1` | A file couldn't be read and is missing from the bundle, or the run failed outright (bad arguments, missing folder, output folder already exists) |

A `1` from an unreadable file still leaves a usable bundle behind — it's a signal that the bundle is incomplete, not that nothing was produced. `--strict` turns the same situation into a hard failure with no output folder created.

Every file gets a heading with its relative path directly above a fenced, language-tagged code block — clean and easy for an LLM (or a human) to skim.

---

## ⚡ One-liner wrappers

Prefer not to think about it at all? Use the pre-wired entry points:

| Script | Behavior |
|---|---|
| `main_frontend.sh` | `frontend` rules → single bundled `.md` |
| `main_backend.sh` | `backend` rules → single bundled `.md` |
| `main_frontend_by_extension.sh` | `frontend` rules → bundled by extension, 800KB cap |
| `main_backend_by_extension.sh` | `backend` rules → bundled by extension, 800KB cap |

Each is one line — edit `PROJECT` at the top to point at your own folder. They won't overwrite an existing output folder, so remove it before re-running.

---

## 📁 Example output structure

```
App_Frontend_bundled/
├── App_Frontend.md                   # everything in one file
# or, with --by-extension:
App_Backend_bundled/
├── cs.md
├── json.md
├── md.md
└── ...
```

---

## 🗺️ Full workflow at a glance

```
App_Frontend/ ──┐
                ├─ walk once, pruning excluded dirs ─► 📄 Markdown
App_Backend/  ──┘        and skipping ignored files       ready to upload
```

---

## 📄 License

MIT — see [LICENSE](LICENSE). Do whatever you'd like with it.
