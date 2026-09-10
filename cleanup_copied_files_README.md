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
    "patterns": [],
    "keep": []
  },
  "backend": {
    "extensions": [],
    "patterns": ["^[0-9]{14}_.*", "^launchSettings\\.json$"],
    "keep": []
  }
}
```

- `extensions` — files matching `*.ext` are deleted, **case-insensitively**, so `png` also removes `Logo.PNG`.
- `patterns` — filenames (not full paths) matched against these as extended regular expressions are deleted.
- `keep` — exceptions. Any filename matching one of these survives, even when an `extensions` or `patterns` rule also matches it.

All three keys are optional and can be omitted rather than left as empty arrays. A mode needs at least one of `extensions` or `patterns` to delete anything; if it has neither, the script says so and deletes nothing:

```json
{ "assets_only": { "extensions": ["png", "jpg"] } }
```

The config file itself is required. If it is missing the script stops with an error rather than falling back to built-in rules — what gets deleted should always be something you can read in a file you control.

### Keep rules

Delete rules can't express "all of these except that one" on their own, because bash regular expressions have no negative lookahead. `keep` covers that case:

```json
{
  "web": {
    "extensions": ["html"],
    "patterns": [],
    "keep": ["^index\\.html$"]
  }
}
```

Every `.html` file is removed except `index.html` — at any depth, since matching is on the filename, not the path.

Kept files are logged so the exception is visible rather than implied:

```
  [KEPT]    index.html  (matched a keep rule)
  [DELETED] about.html  (extension: .html)
```

**A keep rule that matches nothing is reported.** This key fails in the dangerous direction: a typo in a delete rule means a file survives, but a typo here means a file you believed was protected is deleted silently. So the script tells you when a rule spared nothing:

```
⚠️  keep rule '^index\.htm$' matched no files — check it for typos,
    or the file you meant to protect may already be gone.
```

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
