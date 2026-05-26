#!/usr/bin/env bash
set -e

RAW_URL="https://raw.githubusercontent.com/nerv0641/Unraid-Info-Display/main/pcinfo_sender"
APP_NAME="pcinfo_sender"
APP_DIR="/tmp/pcinfo_sender_run"
APP_BIN="$APP_DIR/$APP_NAME"
TMP_DIR="/tmp/pcinfo_tmp"

echo "[pcinfo] Start Unraid deployment..."

# 1. 載入 USB 序列埠驅動
modprobe ch341 || true
modprobe cp210x || true
modprobe pl2303 || true

# 2. 準備目錄
mkdir -p "$APP_DIR"
mkdir -p "$TMP_DIR"
chmod 1777 "$TMP_DIR" || true

# 3. 下載執行檔
if [ ! -f "$APP_BIN" ]; then
  echo "[pcinfo] Downloading binary..."
  curl -L -A "Mozilla/5.0" --retry 3 -o "$APP_BIN" "$RAW_URL"
  chmod 755 "$APP_BIN"
  chmod +x "$APP_BIN"
fi

# 4. 🛠️ 核心修正：解鎖系統底層狀態的讀取權限 🛠️
# 賦予程式可以直接讀取硬體監控（hwmon）與網路介面的權限
chmod 4755 "$APP_BIN" || true

# 5. 重啟背景行程（確保帶入最正確的環境變數）
pkill -f "$APP_NAME" 2>/dev/null || true

LOG_FILE="/var/log/pcinfo_sender.log"
# 確保以 root 權限與正確的 PATH 執行，讓 psutil 能抓到完整的 CPU 與記憶體狀態
START_CMD="PATH=\$PATH:/usr/sbin:/usr/bin:/sbin:/bin TMPDIR=$TMP_DIR PYINSTALLER_RUNTIME_TMPDIR=$TMP_DIR nohup $APP_BIN >> $LOG_FILE 2>&1 &"

echo "[pcinfo] Starting application..."
eval "$START_CMD"

echo "[pcinfo] Done."