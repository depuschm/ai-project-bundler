# cleanup_copied_files.sh

Deletes files from a copied folder according to a named ruleset — which extensions and filename patterns to delete are defined in a config file (`cleanup_rules.json`), not hardcoded in the script. The built-in `frontend` and `backend` modes are tuned for a **React** frontend and an **ASP.NET Core** backend respectively; add your own mode for a different stack. Run this after `copy_files_new_folder.sh`.

---

## Usage

```bash
# 1. Make the script executable (one-time setup)
chmod +x cleanup_copied_files.sh

# 2. Run it, telling it which ruleset to apply
./cleanup_copied_files.sh <folder> --mode <name> [--config <file>] [--dry-run]
```

| Argument | Default | Description |
|---|---|---|
| `folder` | required | The folder to clean up |
| `--mode <name>` | *(guessed from folder name if omitted — see below)* | Which ruleset to apply. Must match a top-level key in the config file, e.g. `frontend` or `backend` |
| `--config <file>` | `cleanup_rules.json` next to the script | Path to the rules config to use |
| `--dry-run` | off | List what *would* be deleted and exit without deleting anything |
| `-h`, `--help` | — | Show usage and exit |

---

## Examples

```bash
# Preview first — recommended before deleting anything
./cleanup_copied_files.sh copied_files_App_Frontend --mode frontend --dry-run

# Explicit mode (recommended)
./cleanup_copied_files.sh copied_files_App_Frontend --mode frontend
./cleanup_copied_files.sh copied_files_App_Backend --mode backend

# Custom config, e.g. for a mobile project
./cleanup_copied_files.sh copied_files_App_Mobile --mode mobile --config my_rules.json
```

---

## Rulesets live in `cleanup_rules.json`

```json
{
  "frontend": {
    "extensions": ["png", "jpg", "jpeg", "svg", "woff2", "ttf", "wav", "mp3", "ico", "pdf"],
    "patterns": []
  },
  "backend": {
    "extensions": [],
    "patterns": ["^[0-9]{14}_.*", "^launchSettings\\.json$"]
  }
}
```

- `extensions` — files matching `*.ext` are deleted, **case-insensitively**, so `png` also removes `Logo.PNG`.
- `patterns` — filenames (not full paths) matched against these as extended regular expressions are deleted.

**Adding a new project type doesn't require touching the script** — just add a new top-level key to the config and pass `--mode <that key>`.

---

## About the folder-name fallback

If you don't pass `--mode`, the script falls back to guessing from the folder name (looking for `Frontend`/`frontend` or `Backend`/`backend`) — same as before. But it now:

- **Always prints a warning** when it guesses, so you never get a silent wrong decision.
- **Never guesses ambiguous names.** A folder like `Backend_Frontend_Tools` will still match on the first check it hits — which is exactly why passing `--mode` explicitly is recommended for anything other than quick, obviously-named folders.

```
⚠️  No --mode given — guessed mode 'frontend' from the folder name.
    Pass --mode explicitly to avoid relying on this guess.
```

---

## What gets deleted (default config)

**`frontend`** — optimized for a **React** app:
- Images: `.png`, `.jpg`/`.jpeg`, `.svg`, `.ico`
- Fonts: `.woff2`, `.ttf`
- Audio: `.wav`, `.mp3`
- Documents: `.pdf`

**`backend`** — optimized for an **ASP.NET Core** app:
- EF Core migration files (files starting with a date, e.g. `20260308022512_...`)
- `launchSettings.json` (contains secrets)

Building something else — Vue, Django, Rails? Copy one of these blocks in `cleanup_rules.json`, rename the key, and adjust the extensions/patterns to fit that stack's conventions.

---

## Previewing with `--dry-run`

Deletion is immediate and irreversible — files are removed with `rm`, not moved to a trash folder. The script's only guardrail is the folder you name, so a mistyped path deletes from wherever you pointed it.

`--dry-run` does all the matching and prints the result without touching anything:

```
DRY RUN — nothing will be deleted.

Files matching mode 'frontend':
───────────────────────────────────
  [WOULD DELETE] a.png  (extension: .png)
  [WOULD DELETE] logo.PNG  (extension: .png)
───────────────────────────────────
Dry run. Would delete: 2 file(s) from /path/to/copied_files_App_Frontend
Nothing was changed. Re-run without --dry-run to apply.
```

It is opt-in: without the flag the script deletes straight away.

---

## Typical workflow

```bash
./copy_files_new_folder.sh App_Frontend
./cleanup_copied_files.sh copied_files_App_Frontend --mode frontend

./copy_files_new_folder.sh App_Backend
./cleanup_copied_files.sh copied_files_App_Backend --mode backend
```
