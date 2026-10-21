#!/bin/sh
input=$(cat)

# ── Nerd Fonts 圖示 ──
# 沒裝 Nerd Fonts 的話，可以把圖示改成一般文字或 emoji
# 例如 ICON_DIR="📁"、ICON_GIT="🔀"、ICON_CTX="ctx"、ICON_CLOCK="⏰"、ICON_COST="$"
ICON_DIR=$(printf '\357\201\273')     # 資料夾圖示
ICON_GIT=$(printf '\356\234\245')     # Git 分支圖示
ICON_CTX=$(printf '\357\213\233')     # 晶片圖示（Context）
ICON_CLOCK=$(printf '\357\200\227')   # 時鐘圖示（Rate Limit）
ICON_COST=$(printf '\357\205\225')    # 美元圖示（花費）

# ── 讀取資料 ──
model=$(printf '%s' "$input" | jq -r '.model.display_name // ""')
ctx_remain=$(printf '%s' "$input" | jq -r '.context_window.remaining_percentage // empty')
five_h_used=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d_used=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_h_resets=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_resets=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
# rate_limits 整包在 API key / Bedrock session 會是 null；
# 而某個視窗剛重置、還沒送出請求時，該視窗會是 null（此時視為 0%，避免欄位忽隱忽現）
rl_present=$(printf '%s' "$input" | jq -r 'if (.rate_limits|type) == "object" then "1" else "" end')
[ -n "$rl_present" ] && [ -z "$five_h_used" ] && five_h_used=0
[ -n "$rl_present" ] && [ -z "$seven_d_used" ] && seven_d_used=0

# ── date 方言偵測 ──
# GNU date（Linux / Git Bash）用 -d @epoch，BSD date（macOS）用 -r epoch
if date -d @0 +%Y >/dev/null 2>&1; then
  DATE_STYLE=gnu
else
  DATE_STYLE=bsd
fi

# epoch 秒數 → 指定格式
epoch_fmt() {
  if [ "$DATE_STYLE" = gnu ]; then
    date -d "@$1" +"$2" 2>/dev/null
  else
    date -r "$1" +"$2" 2>/dev/null
  fi
}

# 明天的 YYYYMMDD
tomorrow_ymd() {
  if [ "$DATE_STYLE" = gnu ]; then
    date -d "+1 day" +%Y%m%d 2>/dev/null
  else
    date -v+1d +%Y%m%d 2>/dev/null
  fi
}

# ── 顏色函式：依剩餘百分比決定顏色 ──
# 綠色 ≥50% │ 黃色 21-49% │ 紅色 ≤20%
color_by_remain() {
  local val=$1
  if [ "$val" -le 20 ]; then
    printf '\033[31m'   # 紅色
  elif [ "$val" -le 49 ]; then
    printf '\033[33m'   # 黃色
  else
    printf '\033[32m'   # 綠色
  fi
}

# ── 重置時刻：rate limit 幾點重置（本地時間、12 小時制）──
# Claude Code 給的 resets_at 是 Unix epoch 秒數
# 輸出格式："下午 1:10"、"明天 上午 9:30"、"週四 上午 6:00"
reset_at_time() {
  local epoch hour min period h12 today rday tomorrow mon day prefix
  epoch=$(printf '%.0f' "$1" 2>/dev/null)
  if [ -z "$epoch" ]; then
    printf '?'
    return
  fi
  hour=$(epoch_fmt "$epoch" %H)
  min=$(epoch_fmt "$epoch" %M)
  if [ -z "$hour" ]; then
    printf '?'
    return
  fi
  hour=${hour#0}; [ -z "$hour" ] && hour=0
  min=${min#0};   [ -z "$min" ] && min=0

  # 時段（上午 / 下午 / 晚上）
  if [ "$hour" -lt 12 ]; then
    period="上午"
  elif [ "$hour" -lt 18 ]; then
    period="下午"
  else
    period="晚上"
  fi

  # 24 小時 → 12 小時
  if [ "$hour" -eq 0 ]; then
    h12=12
  elif [ "$hour" -le 12 ]; then
    h12=$hour
  else
    h12=$((hour - 12))
  fi

  # 日期前綴：今天不加、明天加「明天」、更遠加星期
  today=$(date +%Y%m%d)
  rday=$(epoch_fmt "$epoch" %Y%m%d)
  tomorrow=$(tomorrow_ymd)
  prefix=""
  if [ "$rday" != "$today" ]; then
    if [ "$rday" = "$tomorrow" ]; then
      prefix="明天 "
    else
      mon=$(epoch_fmt "$epoch" %m); mon=${mon#0}
      day=$(epoch_fmt "$epoch" %d); day=${day#0}
      prefix="${mon}/${day} "
    fi
  fi

  printf '%s%s %d:%02d' "$prefix" "$period" "$h12" "$min"
}

# ── 進度條：10 格寬度 ──
mini_bar() {
  local percent=$1
  local width=10
  local filled=$((percent * width / 100))
  local empty=$((width - filled))
  local i=0
  while [ $i -lt $filled ]; do printf '━'; i=$((i + 1)); done
  while [ $i -lt $width ]; do printf '┄'; i=$((i + 1)); done
}

# ── 分隔符號 ──
SEP=$(printf '\033[2m │ \033[0m')

# ── 工作目錄（青色）──
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

# 顯示用路徑：反斜線換成斜線（Windows 會給 C:\Users\...），家目錄縮成 ~
# Git Bash 的 $HOME 是 /c/Users/xxx，但 cwd 是 C:\Users\xxx，兩種前綴都要比對
disp=$(printf '%s' "$cwd" | tr '\\' '/')
home_win=""
if command -v cygpath >/dev/null 2>&1; then
  home_win=$(cygpath -m "$HOME" 2>/dev/null)
fi
short_dir="$disp"
for h in "$home_win" "$HOME"; do
  [ -n "$h" ] || continue
  case "$disp" in
    "$h")   short_dir="~";            break ;;
    "$h"/*) short_dir="~${disp#"$h"}"; break ;;
  esac
done
parts=$(printf '\033[36m%s %s\033[0m' "$ICON_DIR" "$short_dir")

# ── Git 分支（綠色）──
git_branch=""
# cwd 為空時 git -C "" 會退回目前目錄，顯示不相干的分支，所以先擋掉
if [ -n "$cwd" ] && { [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; }; then
  git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null)
fi
if [ -n "$git_branch" ]; then
  parts="$parts$SEP$(printf '\033[32m%s %s\033[0m' "$ICON_GIT" "$git_branch")"
fi

# ── 第二行從 Model 開始 ──
parts2=""
append2() {
  if [ -n "$parts2" ]; then
    parts2="$parts2$SEP$1"
  else
    parts2="$1"
  fi
}

# ── Model（紫色粗體）──
if [ -n "$model" ]; then
  append2 "$(printf '\033[1;35m%s\033[0m' "$model")"
fi

# ── Context 剩餘（進度條 + 百分比）──
if [ -n "$ctx_remain" ]; then
  val=$(printf '%.0f' "$ctx_remain")
  color=$(color_by_remain "$val")
  bar=$(mini_bar "$val")
  append2 "$(printf '%s%s %s %s%%\033[0m' "$color" "$ICON_CTX" "$bar" "$val")"
fi

# ── 5 小時 Rate Limit（已用 % + 距離重置倒數；沒有 resets_at 就只顯示 %）──
if [ -n "$five_h_used" ]; then
  used=$(printf '%.0f' "$five_h_used")
  remain=$((100 - used))
  color=$(color_by_remain "$remain")
  if [ -n "$five_h_resets" ]; then
    display="已用 ${used}%（$(reset_at_time "$five_h_resets") 重置）"
  else
    display="已用 ${used}%"
  fi
  append2 "$(printf '%s%s 5h %s\033[0m' "$color" "$ICON_CLOCK" "$display")"
fi

# ── 7 天 Rate Limit（已用 % + 距離重置倒數；沒有 resets_at 就只顯示 %）──
if [ -n "$seven_d_used" ]; then
  used=$(printf '%.0f' "$seven_d_used")
  remain=$((100 - used))
  color=$(color_by_remain "$remain")
  if [ -n "$seven_d_resets" ]; then
    display="已用 ${used}%（$(reset_at_time "$seven_d_resets") 重置）"
  else
    display="已用 ${used}%"
  fi
  append2 "$(printf '%s%s 7d %s\033[0m' "$color" "$ICON_CLOCK" "$display")"
fi

# ── Session 花費（灰色，四捨五入到小數點兩位）──
if [ -n "$cost" ] && [ "$cost" != "0" ] && [ "$cost" != "null" ]; then
  append2 "$(printf '\033[2m%s $%.2f\033[0m' "$ICON_COST" "$cost")"
fi

# ── 輸出：第一行 目錄/分支，第二行 模型/用量 ──
if [ -n "$parts2" ]; then
  printf '%s\n%s' "$parts" "$parts2"
else
  printf '%s' "$parts"
fi
