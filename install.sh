#!/usr/bin/env bash
set -e

# 直接指向你 GitHub 儲存庫裡的實體執行檔
RAW_URL="https://raw.githubusercontent.com/nerv0641/Unraid-Info-Display/main/pcinfo_sender"

APP_NAME="pcinfo_sender"
# 🎯 關鍵修改：將執行路徑改到記憶體暫存區，繞過隨身碟的 noexec 限制
APP_DIR="/tmp/pcinfo_sender_run"
APP_BIN="$APP_DIR/$APP_NAME"
TMP_DIR="/tmp/pcinfo_tmp"

echo "[pcinfo] Start Unraid deployment..."

if [ "$(id -u)" -ne 0 ]; then
  echo "[error] Please run with sudo/root."
  exit 1
fi

# 1. 載入 USB 序列埠驅動
echo "[pcinfo] Loading USB serial drivers..."
modprobe ch341 || true
modprobe cp210x || true
modprobe pl2303 || true

# 2. 準備記憶體執行目錄
echo "[pcinfo] Prepare dirs in RamFS..."
mkdir -p "$APP_DIR"
mkdir -p "$TMP_DIR"
chmod 1777 "$TMP_DIR" || true

# 3. 從你的 GitHub 下載執行檔到記憶體暫存區
echo "[pcinfo] Downloading binary directly from your GitHub to RamFS..."
curl -L -A "Mozilla/5.0" --retry 3 -o "$APP_BIN" "$RAW_URL"

# 4. 在記憶體中強制賦予最高執行權限 (這次絕對會成功)
chmod 755 "$APP_BIN"
chmod +x "$APP_BIN"

# 5. 終止舊行程並在背景啟動新行程
echo "[pcinfo] Terminating old process if running..."
pkill -f "$APP_NAME" 2>/dev/null || true

LOG_FILE="/var/log/pcinfo_sender.log"
START_CMD="TMPDIR=$TMP_DIR PYINSTALLER_RUNTIME_TMPDIR=$TMP_DIR nohup $APP_BIN >> $LOG_FILE 2>&1 &"

echo "[pcinfo] Starting application and linking to USB display..."
eval "$START_CMD"

echo "[pcinfo] Done."
echo "[pcinfo] View log: tail -f $LOG_FILE"