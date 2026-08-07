# bundle_files.sh

Bundles all files from a folder into a `.md` file ready to upload as project knowledge to an AI assistant (Claude, ChatGPT, Gemini, etc.). Run this after `cleanup_copied_files.sh`.

- Use `--by-extension` to create one `.md` per file extension.
- Use `--suffix <name>` to add a suffix to all output filenames.
- Use `--max-size <kb>` to split output into numbered files if a size limit is exceeded.

---

## Usage

```bash
# 1. Make the script executable (one-time setup)
chmod +x bundle_files.sh

# 2. Run it
./bundle_files.sh <folder> [output_file.md] [--by-extension] [--max-size <kb>]
```

| Argument | Default | Description |
|---|---|---|
| `folder` | required | The folder to bundle (e.g. `copied_files_App_Frontend`) |
| `output_file.md` | `<folder_name>.md` | Name of the output file (single mode only) |
| `--by-extension` | off | Creates one `.md` per file extension in a new folder |
| `--max-size <kb>` | no limit | Splits output into numbered files if size exceeds this limit |
| `--suffix <name>` | none | Adds a suffix to all output filenames |

---

## Examples

**Single file (default)**
```bash
# Bundles everything into copied_files_App_Frontend_bundled/copied_files_App_Frontend.md
./bundle_files.sh copied_files_App_Frontend

# Custom output filename
./bundle_files.sh copied_files_App_Frontend frontend.md

# With suffix
./bundle_files.sh copied_files_App_Frontend --suffix v2

# Split if any file exceeds 500KB
./bundle_files.sh copied_files_App_Frontend --max-size 500
```

Output structure (single mode):
```
copied_files_App_Frontend_bundled/
    copied_files_App_Frontend.md
    # or if split:
    copied_files_App_Frontend_1.md
    copied_files_App_Frontend_2.md
```

**By extension**
```bash
# Creates copied_files_App_Frontend_bundled/ with tsx.md, css.md, json.md ...
./bundle_files.sh copied_files_App_Frontend --by-extension

# With suffix
./bundle_files.sh copied_files_App_Frontend --by-extension --suffix v2

# By extension with max size — splits into tsx_1.md, tsx_2.md etc. if needed
./bundle_files.sh copied_files_App_Frontend --by-extension --max-size 500
```

**With suffix**
```bash
# Single mode with suffix
./bundle_files.sh copied_files_App_Frontend --suffix v2
# → copied_files_App_Frontend_bundled/copied_files_App_Frontend_v2.md

# With suffix and split
./bundle_files.sh copied_files_App_Frontend --max-size 500 --suffix v2
# → copied_files_App_Frontend_bundled/copied_files_App_Frontend_v2_1.md
#   copied_files_App_Frontend_bundled/copied_files_App_Frontend_v2_2.md

# By extension with suffix
./bundle_files.sh copied_files_App_Frontend --by-extension --suffix v2
# → copied_files_App_Frontend_bundled/tsx_v2.md
#   copied_files_App_Frontend_bundled/css_v2.md
```

Output structure with `--by-extension`:
```
copied_files_App_Frontend_bundled/
    tsx.md
    css.md
    json.md
    ...
```

Output structure with `--by-extension --max-size 500`:
```
copied_files_App_Frontend_bundled/
    tsx_1.md
    tsx_2.md
    css.md
    json.md
    ...
```

---

## Full workflow

```bash
# 1. Copy all files
./copy_files_new_folder.sh App_Frontend
./copy_files_new_folder.sh App_Backend

# 2. Delete unwanted files
./cleanup_copied_files.sh copied_files_App_Frontend
./cleanup_copied_files.sh copied_files_App_Backend

# 3. Bundle into .md for your AI assistant
./bundle_files.sh copied_files_App_Frontend --by-extension --max-size 500
./bundle_files.sh copied_files_App_Backend --by-extension --max-size 500

# 4. Upload the .md file(s) to your AI assistant's project knowledge
```

---

## Notes

- Each file gets a `##` heading with its full relative path, directly above its code block.
- Binary files (images, fonts, etc.) are automatically skipped.
- The correct code language tag is auto-detected from the file extension.
- The script will **not** overwrite an existing output file or folder.
