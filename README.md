# claude-statusline

Claude Code 的自訂 statusline，顯示：

```
 ~/Repo/claude-statusline │  main │ Opus 5 │  ━━━━━━━┄┄┄ 78% │  5h 已用 12%（下午 12:20 重置） │  7d 已用 40% │  $1.23
```

由左到右：工作目錄、git 分支、模型、context 剩餘（進度條）、5 小時額度、7 天額度、本次 session 花費。

百分比配色：綠 ≥50%、黃 21–49%、紅 ≤20%（context 看剩餘，rate limit 看剩餘 = 100 − 已用）。
Rate limit 的重置時間以本地時間 12 小時制顯示，跨日會加上「明天」或 `M/D`。

## 需求

- `jq`（`brew install jq`）
- [Nerd Font](https://www.nerdfonts.com/)（我的終端機用 MesloLGS Nerd Font）。沒裝的話圖示會變成豆腐字，
  可以直接編輯 `statusline.sh` 開頭的 `ICON_*` 換成 emoji 或純文字。

## 安裝（新電腦）

```sh
git clone git@github.com:jsdryan/claude-statusline.git ~/Repo/claude-statusline
~/Repo/claude-statusline/install.sh
```

`install.sh` 會：

1. 把 `~/.claude/statusline.sh` 連結（symlink）到這個 repo 裡的版本，舊檔案先備份成 `statusline.sh.bak.<timestamp>`
2. 在 `~/.claude/settings.json` 補上 `statusLine` 設定，其他設定原封不動

之後 `git pull` 就會同步到，不用重跑安裝。設定生效需要重開 Claude Code session。

## 手動安裝

複製 `statusline.sh` 到 `~/.claude/statusline.sh`，然後在 `~/.claude/settings.json` 加上：

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

## 本機測試

不用開 Claude Code 也能看輸出長怎樣：

```sh
echo '{"cwd":"'"$PWD"'","model":{"display_name":"Opus 5"},
       "context_window":{"remaining_percentage":78},
       "rate_limits":{"five_hour":{"used_percentage":12},"seven_day":{"used_percentage":40}},
       "cost":{"total_cost_usd":1.23}}' | ./statusline.sh; echo
```

輸入 JSON 的欄位由 Claude Code 從 stdin 餵進來；缺欄位的區段會自動略過。
