#!/bin/sh
# 把這個 repo 的 statusline.sh 掛到 ~/.claude/，並在 settings.json 補上 statusLine 設定。
# 可重複執行。
set -eu

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$REPO_DIR/statusline.sh"
CLAUDE_DIR="$HOME/.claude"
DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

command -v jq >/dev/null 2>&1 || { echo "需要 jq：brew install jq" >&2; exit 1; }
[ -f "$SRC" ] || { echo "找不到 $SRC" >&2; exit 1; }

mkdir -p "$CLAUDE_DIR"
chmod +x "$SRC"

# ── 1. 連結 statusline.sh ──
if [ -L "$DEST" ] && [ "$(readlink "$DEST")" = "$SRC" ]; then
  echo "✓ $DEST 已指向 repo"
else
  if [ -e "$DEST" ] || [ -L "$DEST" ]; then
    bak="$DEST.bak.$(date +%Y%m%d%H%M%S)"
    mv "$DEST" "$bak"
    echo "• 舊檔備份到 $bak"
  fi
  ln -s "$SRC" "$DEST"
  echo "✓ 連結 $DEST → $SRC"
fi

# ── 2. 補上 settings.json 的 statusLine ──
[ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "$SETTINGS 不是合法 JSON，先修好再跑一次。設定沒有被更動。" >&2
  exit 1
fi

if [ "$(jq -r '.statusLine.command // ""' "$SETTINGS")" = "~/.claude/statusline.sh" ]; then
  echo "✓ settings.json 的 statusLine 已設定"
else
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  tmp=$(mktemp)
  jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh"}' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "✓ 已寫入 settings.json 的 statusLine（原檔已備份）"
fi

echo
echo "完成。重開 Claude Code session 後生效。"
