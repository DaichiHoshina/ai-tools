# Editorless Development Environment Setup

Guide for setting up a development environment that works entirely with Claude Code + terminal tools, rarely opening an editor.

## Tool composition

| Tool | Purpose | Install |
|--------|------|------------|
| [mo](https://github.com/k1LoW/mo) | Markdown viewer (browser display) | `brew install k1LoW/tap/mo` |
| [difit](https://github.com/yoshiko-pg/difit) | GitHub-style git diff viewer | `npm install -g difit` |
| `o` (custom) | Smart opener (auto-dispatches by file type) | See below |
| `oo` (custom) | Opens clipboard content with `o` | See below |

## 1. Tool installation

```bash
brew install k1LoW/tap/mo
npm install -g difit
```

## 2. Create smart opener `o`

Place at `~/bin/o` (`~/bin` must be in PATH).

```bash
#!/usr/bin/env bash
set -euo pipefail

# Smart opener: dispatch by file type
#   .md/.markdown → mo (Markdown viewer)
#   no args (inside git repo) → difit (GitHub-style diff viewer)
#   inside git repo + rev specified → difit <rev>
#   other → macOS open

if [[ $# -eq 0 ]]; then
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    exec difit
  else
    echo "Usage: o <file|git-rev>"
    echo "  o spec.md        → mo (Markdown viewer)"
    echo "  o                 → difit (git diff)"
    echo "  o HEAD~1          → difit HEAD~1"
    echo "  o --all           → difit --all"
    echo "  o image.png       → open (macOS default)"
    exit 1
  fi
fi

ARG="$1"

# difit options (--all, --staged, --cached) pass through directly
if [[ "$ARG" == --* ]]; then
  exec difit "$@"
fi

# git rev-like arg (HEAD~N, commit hash, branch name) → difit
if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  if git rev-parse --verify "$ARG" &>/dev/null 2>&1; then
    if [[ ! -f "$ARG" ]]; then
      exec difit "$@"
    fi
  fi
fi

# File path: dispatch by extension
if [[ -f "$ARG" ]]; then
  case "${ARG##*.}" in
    md|markdown|mdx)
      exec mo "$ARG"
      ;;
    *)
      exec open "$ARG"
      ;;
  esac
fi

# File does not exist: open anyway (URLs etc.)
exec open "$@"
```

```bash
chmod +x ~/bin/o
```

## 3. Create clipboard opener `oo`

Place at `~/bin/oo`. Use as `! oo` inside Claude Code.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Open clipboard contents with o
# Usage: select path → Cmd+C → `! oo`

CLIP="$(pbpaste | tr -d '`' | xargs)"

if [[ -z "$CLIP" ]]; then
  echo "Clipboard is empty"
  exit 1
fi

exec o "$CLIP"
```

```bash
chmod +x ~/bin/oo
```

## 4. Mo.app (register as macOS default app)

`mo` is a CLI tool, so a `.app` wrapper is needed for macOS file association.

### Create

```bash
# Create .app with AppleScript
osacompile -o ~/Applications/Mo.app -e '
on open these_items
    set file_list to ""
    repeat with this_item in these_items
        set file_path to POSIX path of this_item
        if file_list is "" then
            set file_list to quoted form of file_path
        else
            set file_list to file_list & " " & quoted form of file_path
        end if
    end repeat
    do shell script "export PATH=/opt/homebrew/bin:$PATH; mo --open " & file_list & " &"
end open
'
```

### Add BundleIdentifier and extensions to Info.plist

```bash
/usr/libexec/PlistBuddy -c "Add CFBundleIdentifier string com.local.mo-viewer" \
  ~/Applications/Mo.app/Contents/Info.plist

/usr/libexec/PlistBuddy -c "Set CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 md" \
  ~/Applications/Mo.app/Contents/Info.plist

/usr/libexec/PlistBuddy -c "Add CFBundleDocumentTypes:0:CFBundleTypeExtensions:1 string markdown" \
  ~/Applications/Mo.app/Contents/Info.plist

/usr/libexec/PlistBuddy -c "Add CFBundleDocumentTypes:0:CFBundleTypeExtensions:2 string mdx" \
  ~/Applications/Mo.app/Contents/Info.plist
```

### Set as default app

```bash
brew install duti

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f ~/Applications/Mo.app

# Set as default for .md / .markdown
duti -s com.local.mo-viewer .md viewer
duti -s com.local.mo-viewer .markdown viewer
```

Verify:

```bash
duti -x md
# → Mo /Users/<user>/Applications/Mo.app com.local.mo-viewer
```

## 5. iTerm2 settings

Preferences → Profiles → Advanced → Semantic History → set to **"Open with default app"**.

This enables **Cmd+click** on `.md` file paths in Claude Code output to launch mo.

## Usage summary

### Inside Claude Code

| Action | Result |
|------|------|
| Cmd+click `.md` path | Mo.app → mo → browser display |
| `! o` | Show current git diff with difit |
| `! o HEAD~1` | Show diff with previous commit |
| `! o --all` | Show all changes (including unstaged) |
| `! oo` | Open clipboard path with o |

### Terminal (normal shell)

```bash
o spec.md           # display Markdown with mo
o                   # git diff with difit
o HEAD~1            # diff with difit
o image.png         # macOS preview
open spec.md        # launch mo via Mo.app
```
