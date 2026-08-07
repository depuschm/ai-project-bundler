# cleanup_copied_files.sh

Deletes frontend or backend specific files from a folder. Run this after `copy_files_new_folder.sh`.

The script auto-detects whether to apply frontend or backend rules based on the folder name.

---

## Usage

```bash
# 1. Make the script executable (one-time setup)
chmod +x cleanup_copied_files.sh

# 2. Run it after copy_files_new_folder.sh
./cleanup_copied_files.sh <folder>
```

---

## Examples

```bash
# Cleans up frontend assets from the copied folder
./cleanup_copied_files.sh copied_files_App_Frontend

# Cleans up backend specific files from the copied folder
./cleanup_copied_files.sh copied_files_App_Backend
```

---

## What gets deleted

**Frontend** (folder name contains `Frontend` or `frontend`):
- Images: `.png`, `.jpg`, `.jpeg`, `.svg`, `.ico`
- Fonts: `.woff2`, `.ttf`
- Audio: `.wav`, `.mp3`
- Documents: `.pdf`

**Backend** (folder name contains `Backend` or `backend`):
- Migration files (files starting with a date e.g. `20260308022512_...`)
- `launchSettings.json` (contains secrets)

---

## Typical workflow

```bash
./copy_files_new_folder.sh App_Frontend
./cleanup_copied_files.sh copied_files_App_Frontend

./copy_files_new_folder.sh App_Backend
./cleanup_copied_files.sh copied_files_App_Backend
```
