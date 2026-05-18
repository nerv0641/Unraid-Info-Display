#!/usr/bin/env bash
set -e

# =====================================================================
# 🛠️ UNRAID 專用優化版 PCINFO_SENDER 安裝與啟動腳本
# =====================================================================

# 請在此處填入你實際存放 pcinfo_sender 二進位壓縮檔的網址
ARCHIVE_URL="https://gitee.com/chiweizao/a_pcinfo_sender/repository/archive/master.zip"

APP_NAME="pcinfo_sender"
APP_DIR="/boot/config/plugins/pcinfo_sender"
APP_BIN="$APP_DIR/$APP_NAME"
DOWNLOAD_TMP="/tmp/pcinfo_sender_download.zip"
TMP_DIR="/tmp/pcinfo_tmp"

echo "[pcinfo] Start Unraid deployment..."

# 1. 確保在 Unraid 系統中是以 root 身份執行（Unraid 預設皆為 root）
if [ "$(id -u)" -ne 0 ]; then
  echo "[error] Please run with sudo/root."
  exit 1
fi

# 2. 自動載入 Unraid 常見的 USB 序列埠驅動（確保能抓到 /dev/ttyUSB0）
echo "[pcinfo] Loading USB serial drivers..."
modprobe ch341 || true
modprobe cp210x || true
modprobe pl2303 || true

# 3. 定義下載函式（保留原程式碼的 curl/wget 雙重相容與重試機制）
download_file() {
  url="$1"
  out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -L \
      -A "Mozilla/5.0" \
      --retry 3 \
      --connect-timeout 10 \
      -o "$out" \
      "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget \
      --user-agent="Mozilla/5.0" \
      -O "$out" \
      "$url"
  else
    echo "[error] curl/wget not found."
    exit 1
  fi
}

echo "[pcinfo] Prepare dirs in RamFS..."
mkdir -p "$APP_DIR"
mkdir -p "$TMP_DIR"
chmod 1777 "$TMP_DIR" || true

# 4. 檢查主程式是否存在，若不存在才進行下載與解壓部署
if [ ! -f "$APP_BIN" ]; then
  echo "[pcinfo] Downloading application package..."
  download_file "$ARCHIVE_URL" "$DOWNLOAD_TMP"

  if [ ! -s "$DOWNLOAD_TMP" ]; then
    echo "[error] Download failed: empty archive."
    exit 1
  fi

  echo "[pcinfo] Extracting package..."
  mkdir -p /tmp/pcinfo_extracted
  
  # 判斷下載格式並解壓（相容 ZIP 與 TAR.GZ）
  if [[ "$ARCHIVE_URL" == *.zip ]]; then
    unzip -o "$DOWNLOAD_TMP" -d /tmp/pcinfo_extracted >/dev/null 2>&1
  else
    tar -xzf "$DOWNLOAD_TMP" -C /tmp/pcinfo_extracted >/dev/null 2>&1
  fi

  # 在解壓目錄中尋找主程式並搬移到 Unraid 隨身碟
  BINARY_PATH=$(find /tmp/pcinfo_extracted -name "$APP_NAME" -type f | head -n 1)

  if [ -f "$BINARY_PATH" ]; then
    rm -f "$APP_BIN"
    cp "$BINARY_PATH" "$APP_DIR/"
    chmod +x "$APP_BIN"
    echo "[pcinfo] Binary deployed successfully to Flash drive."
  else
    echo "[error] $APP_NAME not found after extract."
    exit 1
  fi

  # 清理下載暫存檔
  rm -f "$DOWNLOAD_TMP"
  rm -rf /tmp/pcinfo_extracted
fi

# 5. 帶入環境變數並在背景啟動程式（捨棄 systemd，改用 Unraid 標準背景執行）
echo "[pcinfo] Terminating old process if running..."
pkill -f "$APP_BIN" 2>/dev/null || true

LOG_FILE="/var/log/pcinfo_sender.log"
START_CMD="TMPDIR=$TMP_DIR PYINSTALLER_RUNTIME_TMPDIR=$TMP_DIR nohup $APP_BIN >> $LOG_FILE 2>&1 &"

echo "[pcinfo] Starting application and linking to USB display..."
eval "$START_CMD"

echo "[pcinfo] Done."
echo "[pcinfo] View log: tail -f $LOG_FILE"