Run scripts in following order:
1. ./copy_files_new_folder.sh ./App_Backend
2. ./cleanup_copied_files.sh ./copied_files_App_Backend
3. ./bundle_files.sh ./copied_files_App_Backend
(3.) ./bundle_files.sh copied_files_App_Frontend --by-extension (alternative to bundle by extension)

---

cleanup_copied_files:

Frontend files to delete after copying:
- .png files
(- .html files (except of index.html))
– .jpg files
– .jpeg files
- .svg files
- .woff2 files
- .ttf files
- .wav files
- .mp3 files
- .ico files
- .pdf files

Backend files to delete after copying:
- Migration files (these are files that start with a date like "20260308022512_")
- launchSettings.json (contains secrets)
