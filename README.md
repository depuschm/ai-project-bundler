# 🧩 ai-project-bundler

**Turn your codebase into clean, AI-ready Markdown — in three commands.**

Keeping an AI assistant's project knowledge in sync with a real codebase is tedious: you don't want binary assets, secrets, or noisy migration files clogging up the context, and manually copy-pasting files gets old fast. `ai-project-bundler` automates the whole thing with a simple, composable pipeline of bash scripts.

Copy → Clean → Bundle. That's it.

---

## ✨ Why you'd want this

- **Zero manual curation.** Point it at a folder, get back tidy Markdown ready to upload as project knowledge to Claude, ChatGPT, Gemini, or any other AI assistant.
- **Frontend & backend aware.** Automatically strips the right files depending on what you're bundling — images/fonts/audio for frontend, migrations/secrets for backend.
- **Single file or split by extension.** Bundle everything into one `.md`, or organize output into `tsx.md`, `css.md`, `json.md`, etc.
- **Handles large codebases gracefully.** Auto-splits output into numbered parts when it exceeds a size limit you set.
- **Safe by default.** Never overwrites existing files or folders — no accidental data loss.
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

That's it — you'll end up with `copied_files_App_Frontend_bundled/copied_files_App_Frontend.md` (and the backend equivalent), ready to drag straight into your AI assistant's project knowledge.

---

## 🔧 How it works

The pipeline is three independent, chainable scripts:

| Step | Script | What it does |
|---|---|---|
| 1️⃣ | [`copy_files_new_folder.sh`](copy_files_new_folder_README.md) | Recursively copies every file from a source folder into a flat working copy |
| 2️⃣ | [`cleanup_copied_files.sh`](cleanup_copied_files_README.md) | Auto-detects frontend/backend and deletes files you don't want (assets, secrets, migrations) |
| 3️⃣ | [`bundle_files.sh`](bundle_files_README.md) | Bundles what's left into clean, syntax-highlighted Markdown |

```bash
./copy_files_new_folder.sh ./App_Backend
./cleanup_copied_files.sh ./copied_files_App_Backend
./bundle_files.sh ./copied_files_App_Backend
```

Each script also has its own README with full usage details and examples.

### 🧹 What gets cleaned up

**Frontend** — images, fonts, audio, and PDFs (large, non-code binary assets):
`.png` `.jpg/.jpeg` `.svg` `.ico` `.woff2` `.ttf` `.wav` `.mp3` `.pdf`

**Backend** — dated migration files (e.g. `20260308022512_InitialCreate.cs`) and `launchSettings.json` (which often contains secrets)

### 📦 Bundling options

```bash
# Single Markdown file
./bundle_files.sh copied_files_App_Frontend

# One .md per file extension
./bundle_files.sh copied_files_App_Frontend --by-extension

# Add a suffix to output filenames
./bundle_files.sh copied_files_App_Frontend --suffix v2

# Split output once it exceeds 500KB
./bundle_files.sh copied_files_App_Frontend --max-size 500
```

Every file gets a heading with its relative path directly above a fenced, language-tagged code block — clean and easy for an LLM (or a human) to skim.

---

## ⚡ One-liner wrappers

Prefer not to think about it at all? Use the pre-wired entry points:

| Script | Behavior |
|---|---|
| `main_frontend.sh` | Full pipeline → single bundled `.md` |
| `main_backend.sh` | Full pipeline → single bundled `.md` |
| `main_frontend_by_extension.sh` | Full pipeline → bundled by extension, 800KB cap |
| `main_backend_by_extension.sh` | Full pipeline → bundled by extension, 800KB cap |

---

## 📁 Example output structure

```
copied_files_App_Frontend_bundled/
├── copied_files_App_Frontend.md      # everything in one file
# or, with --by-extension:
copied_files_App_Backend_bundled/
├── cs.md
├── json.md
├── md.md
└── ...
```

---

## 🗺️ Full workflow at a glance

```
App_Frontend/  ──┐
                  ├─ copy ─► copied_files_App_Frontend  ──┐
App_Backend/   ──┘                                        ├─ clean ─► ──┐
                                                                          ├─ bundle ─► 📄 Markdown
                                                                          │             ready to upload
```

---

## 📄 License

MIT — do whatever you'd like with it.
