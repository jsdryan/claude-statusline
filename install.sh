#!/bin/sh
# 把這個 repo 的 statusline.sh 設成 Claude Code 的 statusline。
# macOS / Linux / WSL 直接跑；原生 Windows 請在 Git Bash 裡跑。
# 設定直接指向 repo 內的檔案，所以之後 git pull 就會生效，不用重跑。
# 可重複執行。
set -eu

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$REPO_DIR/statusline.sh"

# ── 家目錄：原生 Windows 上 Claude Code 讀的是 %USERPROFILE%\.claude ──
# Git Bash 的 $HOME 不一定等於 USERPROFILE，所以 Windows 上以 USERPROFILE 為準
if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
  HOME_DIR=$(cygpath -u "$USERPROFILE")
else
  HOME_DIR="$HOME"
fi
CLAUDE_DIR="$HOME_DIR/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "需要 jq：" >&2
  echo "  macOS        brew install jq" >&2
  echo "  Windows      winget install jqlang.jq（裝完重開終端機）" >&2
  echo "  Debian/WSL   sudo apt install jq" >&2
  exit 1
fi
[ -f "$SRC" ] || { echo "找不到 $SRC" >&2; exit 1; }

chmod +x "$SRC" 2>/dev/null || true
mkdir -p "$CLAUDE_DIR"

# ── settings.json 裡要寫的 command 字串 ──
# Git Bash 會把未跳脫的反斜線吃掉，所以一律用正斜線；在家目錄底下就縮成 ~
if command -v cygpath >/dev/null 2>&1; then
  CMD_PATH=$(cygpath -m "$SRC")            # C:/Users/xxx/... （斜線版）
  HOME_PREFIX=$(cygpath -m "$HOME_DIR")
else
  CMD_PATH="$SRC"
  HOME_PREFIX="$HOME_DIR"
fi
case "$CMD_PATH" in
  "$HOME_PREFIX"/*) CMD_PATH="~${CMD_PATH#"$HOME_PREFIX"}" ;;
esac

# ── 舊版安裝方式留下的 symlink（~/.claude/statusline.sh → repo）清掉 ──
OLD_LINK="$CLAUDE_DIR/statusline.sh"
if [ -L "$OLD_LINK" ] && [ "$(readlink "$OLD_LINK")" = "$SRC" ]; then
  rm -f "$OLD_LINK"
  echo "• 移除舊的 symlink ${OLD_LINK}（現在直接指向 repo）"
fi

# ── 寫入 settings.json ──
[ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "$SETTINGS 不是合法 JSON，先修好再跑一次。設定沒有被更動。" >&2
  exit 1
fi

if [ "$(jq -r '.statusLine.command // ""' "$SETTINGS")" = "$CMD_PATH" ]; then
  echo "✓ settings.json 已指向 $CMD_PATH"
else
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  tmp="$SETTINGS.tmp.$$"
  jq --arg cmd "$CMD_PATH" \
     '.statusLine = {"type":"command","command":$cmd}' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "✓ 已寫入 settings.json：${CMD_PATH}（原檔已備份）"
fi

# ── 試跑一次，確認不會炸 ──
echo
echo "預覽："
printf '{"cwd":"%s","model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":78},"rate_limits":{"five_hour":{"used_percentage":12},"seven_day":{"used_percentage":40}},"cost":{"total_cost_usd":1.23}}' "$REPO_DIR" \
  | sh "$SRC" || echo "(試跑失敗，檢查上面的錯誤訊息)"
echo
echo
echo "完成。重開 Claude Code session 後生效。"
