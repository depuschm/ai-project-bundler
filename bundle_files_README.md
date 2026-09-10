# bundle_files.sh

Bundles files from a folder into a `.md` file ready to upload as project knowledge to an AI assistant (Claude, ChatGPT, Gemini, etc.).

Point it straight at your source tree with `--mode` and it filters as it walks — excluded directories are pruned, rule-matched files are skipped, and nothing is copied or deleted. Without `--mode` it bundles every file it finds, which is what you want for a folder you've already curated by hand.

- Use `--by-extension` to create one `.md` per file extension.
- Use `--suffix <name>` to add a suffix to all output filenames.
- Use `--max-size <kb>` to split output into numbered files if a size limit is exceeded.

---

## Usage

```bash
# 1. Make the script executable (one-time setup)
chmod +x bundle_files.sh

# 2. Run it
./bundle_files.sh <folder> [output_file.md] [--mode <name>] [--rules <file>] [--by-extension] [--suffix <name>] [--max-size <kb>]
```

| Argument | Default | Description |
|---|---|---|
| `folder` | required | The folder to bundle (e.g. `./App_Frontend`) |
| `output_file.md` | `<folder_name>.md` | Name of the output file (single mode only) |
| `--by-extension` | off | Creates one `.md` per file extension in a new folder |
| `--max-size <kb>` | no limit | Splits output into numbered files if size exceeds this limit |
| `--suffix <name>` | none | Adds a suffix to all output filenames |
| `--mode <name>` | none | Apply a ruleset while walking. Without it, every file is bundled |
| `--rules <file>` | `rules.json` next to the script | Path to the ruleset config |
| `-h`, `--help` | — | Show usage and exit |

---

## Filtering with `--mode`

```bash
./bundle_files.sh ./App_Frontend --mode frontend
```

Reads the `frontend` ruleset from `rules.json`. Directories in `exclude_dirs` are pruned at the `find` level, so a `node_modules` is never descended into rather than being read and discarded. Files matching `extensions` or `patterns` are skipped unless a `keep` rule spares them.

Skipped files are reported so nothing vanishes silently:

```
  [IGNORED]  assets/Logo.PNG  (extension: .png)
  [BUNDLED]  src/App.tsx → App_Frontend.md
Done. Bundled: 4  |  Skipped: 0 binary file(s)
Ignored by mode 'frontend': 1 file(s)
```

Rules are loaded by [`rules_lib.sh`](rules_lib.sh). See the [main README](README.md#-what-gets-left-out) for the ruleset format.

---

## Examples

**Single file (default)**
```bash
# Bundles everything into App_Frontend_bundled/App_Frontend.md
./bundle_files.sh ./App_Frontend --mode frontend

# Custom output filename
./bundle_files.sh App_Frontend frontend.md

# With suffix
./bundle_files.sh App_Frontend --suffix v2

# Split if any file exceeds 500KB
./bundle_files.sh App_Frontend --max-size 500
```

Output structure (single mode):
```
App_Frontend_bundled/
    App_Frontend.md
    # or if split:
    App_Frontend_1.md
    App_Frontend_2.md
```

**By extension**
```bash
# Creates App_Frontend_bundled/ with tsx.md, css.md, json.md ...
./bundle_files.sh App_Frontend --by-extension

# With suffix
./bundle_files.sh App_Frontend --by-extension --suffix v2

# By extension with max size — splits into tsx_1.md, tsx_2.md etc. if needed
./bundle_files.sh App_Frontend --by-extension --max-size 500
```

**With suffix**
```bash
# Single mode with suffix
./bundle_files.sh App_Frontend --suffix v2
# → App_Frontend_bundled/App_Frontend_v2.md

# With suffix and split
./bundle_files.sh App_Frontend --max-size 500 --suffix v2
# → App_Frontend_bundled/App_Frontend_v2_1.md
#   App_Frontend_bundled/App_Frontend_v2_2.md

# By extension with suffix
./bundle_files.sh App_Frontend --by-extension --suffix v2
# → App_Frontend_bundled/tsx_v2.md
#   App_Frontend_bundled/css_v2.md
```

Output structure with `--by-extension`:
```
App_Frontend_bundled/
    tsx.md
    css.md
    json.md
    ...
```

Output structure with `--by-extension --max-size 500`:
```
App_Frontend_bundled/
    tsx_1.md
    tsx_2.md
    css.md
    json.md
    ...
```

---

## Full workflow

```bash
# 1. Bundle each project, filtering as it walks
./bundle_files.sh ./App_Frontend --mode frontend --by-extension --max-size 500
./bundle_files.sh ./App_Backend  --mode backend  --by-extension --max-size 500

# 2. Upload the .md file(s) to your AI assistant's project knowledge
```

---

## Notes

- Each file gets a `##` heading with its full relative path, directly above its code block.
- Binary files (images, fonts, etc.) are automatically skipped.
- The correct code language tag is auto-detected from the file extension.
- The script will **not** overwrite an existing output file or folder.
- Unknown options, missing values and stray extra arguments are rejected with a usage message, so a typo like `--by-extention` fails loudly instead of being silently treated as an output filename.
- `--mode` filters only; it never modifies your source tree.
