# copy_files_new_folder.sh

Recursively copies all files from a folder into a new folder created in the current directory, **preserving the original subfolder structure**.

---

## Usage

```bash
# 1. Make the script executable (one-time setup)
chmod +x copy_files_new_folder.sh

# 2. Run it
./copy_files_new_folder.sh [source_folder] [new_folder_name] [--mode <name>] [--rules <file>]
```

Both arguments are optional:

| Argument | Default | Description |
|---|---|---|
| `source_folder` | current directory | The folder whose files you want to copy |
| `new_folder_name` | `copied_files_<source_folder>` | Name of the new folder that will be created |
| `--mode <name>` | none | Apply a ruleset's `exclude_dirs` while copying, so dependency folders are never copied |
| `--rules <file>` | `cleanup_rules.json` next to the script | Path to the ruleset config |

---

## Examples

```bash
# Copies all files from App_Frontend into ./copied_files_App_Frontend/
./copy_files_new_folder.sh App_Frontend

# Copies all files from App_Backend into ./copied_files_App_Backend/
./copy_files_new_folder.sh App_Backend

# No source folder specified → creates ./copied_files/
./copy_files_new_folder.sh

# Override the folder name manually
./copy_files_new_folder.sh App_Frontend my_custom_name
```

---

## Skipping dependencies with `--mode`

```bash
./copy_files_new_folder.sh ./App_Frontend --mode frontend
```

Without this, `node_modules` and `.git` are copied in full and then deleted by the cleanup step — thousands of files of pure waste. With it, `find` prunes those directories and never descends into them.

If you don't need an intermediate folder at all, skip this script: `bundle_files.sh --mode` reads the source directly and copies nothing.

---

## Notes

- Files are copied **recursively**, and the source folder's directory layout is **preserved** in the copy. This matters because most projects reuse filenames across directories — `index.ts`, `types.ts`, `utils.ts`, `Button.tsx` — and flattening them into a single folder would silently drop all but one.
- Preserved paths also mean `bundle_files.sh` uses the real relative path as each file's heading (`## src/components/Button.tsx`), which is far more useful context for an AI assistant than a bare filename.
- On a **case-insensitive filesystem** (macOS, Windows), two files in the *same* directory whose names differ only in case resolve to one path and still collide. The script prints a `[COLLISION]` line to stderr plus a summary warning, rather than losing the file silently.
- The new folder is always created in the **current directory** (where you run the script from), not inside the source folder.
- The script will **not** overwrite an existing folder. If the target folder already exists, it exits with an error.
