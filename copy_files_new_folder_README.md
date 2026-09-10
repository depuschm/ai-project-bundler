# copy_files_new_folder.sh

Recursively copies all files from a folder into a new folder created in the current directory, **preserving the original subfolder structure**.

---

## Usage

```bash
# 1. Make the script executable (one-time setup)
chmod +x copy_files_new_folder.sh

# 2. Run it
./copy_files_new_folder.sh [source_folder] [new_folder_name]
```

Both arguments are optional:

| Argument | Default | Description |
|---|---|---|
| `source_folder` | current directory | The folder whose files you want to copy |
| `new_folder_name` | `copied_files_<source_folder>` | Name of the new folder that will be created |

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

## Notes

- Files are copied **recursively**, and the source folder's directory layout is **preserved** in the copy. This matters: a project will often have several files with the same name in different folders (`components/ui/switch.tsx`, `shared/switch.tsx`, `features/auth/Switch.tsx`). Flattening them into one folder would silently drop all but one.
- Preserved paths also mean `bundle_files.sh` writes the real relative path as each file's heading (`## components/ui/switch.tsx`), which is far more useful context for an AI assistant than a bare filename.
- On a **case-insensitive filesystem** (macOS, Windows), two files in the *same* folder differing only by case still collide. The script prints a `[COLLISION]` line to stderr and a summary warning rather than losing the file silently.
- The new folder is always created in the **current directory** (where you run the script from), not inside the source folder.
- The script will **not** overwrite an existing folder. If the target folder already exists, it exits with an error.
