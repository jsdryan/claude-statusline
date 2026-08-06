# claude-statusline

Claude Code 的自訂 statusline，顯示：

```
 ~/Repo/claude-statusline │  main │ Opus 5 │  ━━━━━━━┄┄┄ 78% │  5h 已用 12%（下午 12:20 重置） │  7d 已用 40% │  $1.23
```

由左到右：工作目錄、git 分支、模型、context 剩餘（進度條）、5 小時額度、7 天額度、本次 session 花費。

百分比配色：綠 ≥50%、黃 21–49%、紅 ≤20%（context 看剩餘，rate limit 看剩餘 = 100 − 已用）。
Rate limit 的重置時間以本地時間 12 小時制顯示，跨日會加上「明天」或 `M/D`。

支援 macOS、Linux／WSL，以及原生 Windows（透過 Git Bash）。

## 需求

- `jq`
- [Nerd Font](https://www.nerdfonts.com/)（我用 MesloLGS Nerd Font）。沒裝的話圖示會變成豆腐字，
  可以直接編輯 `statusline.sh` 開頭的 `ICON_*` 換成 emoji 或純文字。

## 安裝（新電腦）

```sh
git clone git@github.com:jsdryan/claude-statusline.git ~/Repo/claude-statusline
~/Repo/claude-statusline/install.sh
```

`install.sh` 會把 `~/.claude/settings.json` 的 `statusLine` 指向 **repo 裡的** `statusline.sh`
（其他設定原封不動、原檔先備份），最後試跑一次給你看效果。

因為是直接指向 repo，之後 `git pull` 就生效，不用重跑安裝。設定要重開 Claude Code session 才會套用。

## Windows 11

Claude Code 在 Windows 上會**優先用 Git Bash 跑 statusline 指令**，沒有 Git Bash 才退回 PowerShell。
所以只要裝了 [Git for Windows](https://git-scm.com/downloads/win)（反正要 clone 也需要 git），
這支 bash 腳本就能直接用，跟 macOS 同一份。

1. 裝 Git for Windows 和 jq：

   ```powershell
   winget install Git.Git
   winget install jqlang.jq
   ```

   裝完重開終端機，讓 PATH 生效。

2. **開 Git Bash**（不是 PowerShell）執行 clone 和安裝：

   ```sh
   git clone git@github.com:jsdryan/claude-statusline.git ~/Repo/claude-statusline
   ~/Repo/claude-statusline/install.sh
   ```

3. Windows Terminal 的字型設定成 Nerd Font（設定 → 對應的設定檔 → 外觀 → 字型），
   否則圖示會是豆腐字。字型可以用 `winget install DEVCOM.MesloLGNerdFont` 裝。

幾個 Windows 專屬的細節，腳本和安裝程式都已經處理掉了：

- `settings.json` 裡的路徑一律用**正斜線**或 `~`。Git Bash 會把沒跳脫的反斜線當跳脫字元吃掉，
  寫 `C:\Users\...` 會整條指令失效而且不會報錯。
- Claude Code 傳進來的 `cwd` 是 `C:\Users\...`，而 Git Bash 的 `$HOME` 是 `/c/Users/...`，
  兩種前綴都會比對，家目錄底下一樣縮成 `~`。
- Git Bash 是 GNU `date`（`-d @epoch`），macOS 是 BSD `date`（`-r epoch`），腳本會自己偵測。
- 設定檔位置以 `%USERPROFILE%\.claude` 為準（Git Bash 的 `$HOME` 不一定等於它）。

如果那台機器**不裝 Git for Windows**，Claude Code 會改用 PowerShell 跑指令，這支腳本就不能用，
得另外寫一份 `.ps1`。這個 repo 目前沒有 PowerShell 版本。

WSL 就是一般 Linux，照上面的通用安裝步驟做即可（要在 WSL 裡面裝 Claude Code 和跑 `claude`）。

## 手動安裝

在 `~/.claude/settings.json` 加上，路徑換成你 clone 的位置（正斜線）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/Repo/claude-statusline/statusline.sh"
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
