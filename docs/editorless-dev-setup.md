# エディタレス開発環境セットアップ

エディタをほぼ開かず、Claude Code + ターミナルツールだけで開発を完結させる環境構築ガイド。

## ツール構成

| ツール | 用途 | インストール |
|--------|------|------------|
| [mo](https://github.com/k1LoW/mo) | Markdown ビューア（ブラウザ表示） | `brew install k1LoW/tap/mo` |
| [difit](https://github.com/yoshiko-pg/difit) | Git diff の GitHub 風ビューア | `npm install -g difit` |
| `o` (自作) | スマートオープナー（ファイルタイプで自動振り分け） | 後述 |
| `oo` (自作) | クリップボードの内容を `o` で開く | 後述 |

## 1. ツールインストール

```bash
brew install k1LoW/tap/mo
npm install -g difit
```

## 2. スマートオープナー `o` の作成

`~/bin/o` に配置（`~/bin` が PATH に含まれていること）。

```bash
#!/usr/bin/env bash
set -euo pipefail

# Smart opener: ファイルタイプで自動振り分け
#   .md/.markdown → mo（Markdownビューア）
#   引数なし（gitリポ内）→ difit（GitHub風diffビューア）
#   gitリポ内 + rev指定 → difit <rev>
#   その他 → macOS open

if [[ $# -eq 0 ]]; then
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    exec difit
  else
    echo "Usage: o <file|git-rev>"
    echo "  o spec.md        → mo (Markdownビューア)"
    echo "  o                 → difit (git diff)"
    echo "  o HEAD~1          → difit HEAD~1"
    echo "  o --all           → difit --all"
    echo "  o image.png       → open (macOS default)"
    exit 1
  fi
fi

ARG="$1"

# difit オプション (--all, --staged, --cached) はそのまま渡す
if [[ "$ARG" == --* ]]; then
  exec difit "$@"
fi

# git rev っぽい引数 (HEAD~N, commit hash, branch名) → difit
if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  if git rev-parse --verify "$ARG" &>/dev/null 2>&1; then
    if [[ ! -f "$ARG" ]]; then
      exec difit "$@"
    fi
  fi
fi

# ファイルパスの場合: 拡張子で振り分け
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

# ファイルが存在しない場合もopen（URLなど）
exec open "$@"
```

```bash
chmod +x ~/bin/o
```

## 3. クリップボードオープナー `oo` の作成

`~/bin/oo` に配置。Claude Code 内で `! oo` として使用。

```bash
#!/usr/bin/env bash
set -euo pipefail

# クリップボードの内容を o で開く
# 使い方: パスを選択 → Cmd+C → `! oo`

CLIP="$(pbpaste | tr -d '`' | xargs)"

if [[ -z "$CLIP" ]]; then
  echo "クリップボードが空"
  exit 1
fi

exec o "$CLIP"
```

```bash
chmod +x ~/bin/oo
```

## 4. Mo.app（macOS デフォルトアプリ登録）

`mo` は CLI ツールのため、macOS のファイル関連付けには `.app` ラッパーが必要。

### 作成

```bash
# AppleScript で .app を作成
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

### Info.plist に BundleIdentifier と拡張子を追加

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

### デフォルトアプリに設定

```bash
brew install duti

# Launch Services に登録
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f ~/Applications/Mo.app

# .md / .markdown のデフォルトに設定
duti -s com.local.mo-viewer .md viewer
duti -s com.local.mo-viewer .markdown viewer
```

確認:

```bash
duti -x md
# → Mo /Users/<user>/Applications/Mo.app com.local.mo-viewer
```

## 5. iTerm2 設定

Preferences → Profiles → Advanced → Semantic History を **「Open with default app」** に設定。

これにより Claude Code 出力内の `.md` ファイルパスを **Cmd+クリック** で mo が起動する。

## 使い方まとめ

### Claude Code 内

| 操作 | 動作 |
|------|------|
| `.md` パスを Cmd+クリック | Mo.app → mo → ブラウザ表示 |
| `! o` | difit で現在の git diff 表示 |
| `! o HEAD~1` | difit で前コミットとの差分 |
| `! o --all` | difit で全変更（unstaged 含む） |
| `! oo` | クリップボードのパスを o で開く |

### ターミナル（通常シェル）

```bash
o spec.md           # mo で Markdown 表示
o                   # difit で git diff
o HEAD~1            # difit で差分
o image.png         # macOS プレビュー
open spec.md        # Mo.app 経由で mo 起動
```
