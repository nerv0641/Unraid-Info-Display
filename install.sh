#!/usr/bin/env bash
set -e

# 直接指向你 GitHub 儲存庫裡的實體執行檔
RAW_URL="https://raw.githubusercontent.com/nerv0641/Unraid-Info-Display/main/pcinfo_sender"

APP_NAME="pcinfo_sender"
APP_DIR="/boot/config/plugins/pcinfo_sender"
APP_BIN="$APP_DIR/$APP_NAME"
TMP_DIR="/tmp/pcinfo_tmp"

echo "[pcinfo] Start Unraid deployment..."

if [ "$(id -u)" -ne 0 ]; then
  echo "[error] Please run with sudo/root."
  exit 1
fi

# 1. 載入 USB 驅動
echo "[pcinfo] Loading USB serial drivers..."
modprobe ch341 || true
modprobe cp210x || true
modprobe pl2303 || true

# 2. 準備隨身碟與記憶體目錄
echo "[pcinfo] Prepare dirs in RamFS..."
mkdir -p "$APP_DIR"
mkdir -p "$TMP_DIR"
chmod 1777 "$TMP_DIR" || true

# 3. 如果隨身碟裡沒有主程式，直接從你的 GitHub 下載
if [ ! -f "$APP_BIN" ]; then
  echo "[pcinfo] Downloading binary directly from your GitHub..."
  curl -L -A "Mozilla/5.0" --retry 3 -o "$APP_BIN" "$RAW_URL"
  chmod +x "$APP_BIN"
  echo "[pcinfo] Binary deployed successfully to Flash drive."
fi

# 4. 終止舊行程並在背景啟動新行程
echo "[pcinfo] Terminating old process if running..."
pkill -f "$APP_BIN" 2>/dev/null || true

LOG_FILE="/var/log/pcinfo_sender.log"
START_CMD="TMPDIR=$TMP_DIR PYINSTALLER_RUNTIME_TMPDIR=$TMP_DIR nohup $APP_BIN >> $LOG_FILE 2>&1 &"

echo "[pcinfo] Starting application and linking to USB display..."
eval "$START_CMD"

echo "[pcinfo] Done."
echo "[pcinfo] View log: tail -f $LOG_FILE"