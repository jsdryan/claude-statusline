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
model=$(echo "$input" | jq -r '.model.display_name // ""')
ctx_remain=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
five_h_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_h_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

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
  hour=$(date -r "$epoch" +%H 2>/dev/null)
  min=$(date -r "$epoch" +%M 2>/dev/null)
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
  rday=$(date -r "$epoch" +%Y%m%d 2>/dev/null)
  tomorrow=$(date -v+1d +%Y%m%d 2>/dev/null)
  prefix=""
  if [ "$rday" != "$today" ]; then
    if [ "$rday" = "$tomorrow" ]; then
      prefix="明天 "
    else
      mon=$(date -r "$epoch" +%m 2>/dev/null); mon=${mon#0}
      day=$(date -r "$epoch" +%d 2>/dev/null); day=${day#0}
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
cwd=$(echo "$input" | jq -r '.cwd // ""')
short_dir=$(echo "$cwd" | sed "s|^$HOME|~|")
parts=$(printf '\033[36m%s %s\033[0m' "$ICON_DIR" "$short_dir")

# ── Git 分支（綠色）──
git_branch=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null)
fi
if [ -n "$git_branch" ]; then
  parts="$parts$SEP$(printf '\033[32m%s %s\033[0m' "$ICON_GIT" "$git_branch")"
fi

# ── Model（紫色粗體）──
if [ -n "$model" ]; then
  parts="$parts$SEP$(printf '\033[1;35m%s\033[0m' "$model")"
fi

# ── Context 剩餘（進度條 + 百分比）──
if [ -n "$ctx_remain" ]; then
  val=$(printf '%.0f' "$ctx_remain")
  color=$(color_by_remain "$val")
  bar=$(mini_bar "$val")
  parts="$parts$SEP$(printf '%s%s %s %s%%\033[0m' "$color" "$ICON_CTX" "$bar" "$val")"
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
  parts="$parts$SEP$(printf '%s%s 5h %s\033[0m' "$color" "$ICON_CLOCK" "$display")"
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
  parts="$parts$SEP$(printf '%s%s 7d %s\033[0m' "$color" "$ICON_CLOCK" "$display")"
fi

# ── Session 花費（灰色，四捨五入到小數點兩位）──
if [ -n "$cost" ] && [ "$cost" != "0" ] && [ "$cost" != "null" ]; then
  parts="$parts$SEP$(printf '\033[2m%s $%.2f\033[0m' "$ICON_COST" "$cost")"
fi

printf '%s' "$parts"
