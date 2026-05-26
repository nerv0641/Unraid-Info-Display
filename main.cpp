#include <Arduino.h>
#include <Adafruit_GFX.h>    // 核心繪圖庫
#include <Adafruit_ST7789.h> // ST7789 專屬驅動庫
#include <SPI.h>
#include <ArduinoJson.h>

// 🎯 定義 ESP8266 與 ST7789 的控制腳位
#define TFT_ST7789_RST  2   // 對應板子上的 D4 (GPIO2)
#define TFT_ST7789_DC   0   // 對應板子上的 D3 (GPIO0)
#define TFT_ST7789_CS  -1   // 若螢幕無 CS 腳位設為 -1 即可

// 🎯 初始化 ST7789 (標準硬體 SPI：SCL 接 D5/GPIO14, SDA 接 D7/GPIO13)
Adafruit_ST7789 tft = Adafruit_ST7789(TFT_ST7789_CS, TFT_ST7789_DC, TFT_ST7789_RST);

void setup() {
    // 1. 初始化序列埠（與 Unraid 的 115200 匹配）
    Serial.begin(115200);

    // 2. 🎯 精準初始化 240x320 規格的 ST7789
    tft.init(240, 320); 
    
    // 3. 設定旋轉方向：1 為橫向模式 (長邊在上下，短邊在左右，解析度變為 320x240)
    tft.setRotation(1); 
    
    tft.fillScreen(ST77XX_BLACK);
    
    tft.setCursor(10, 10);
    tft.setTextColor(ST77XX_WHITE);
    tft.setTextSize(2);
    tft.println("Waiting for Unraid...");
}

void loop() {
    // 🎯 流式機制：當序列埠有資料，且開頭是 JSON 的 '{' 時才開始解析
    if (Serial.available() > 0 && Serial.peek() == '{') {
        
        // 宣告 2048 位元組的 JSON 緩衝區，足以安全吞下 Unraid 的 10 顆硬碟數據
        DynamicJsonDocument doc(2048);
        
        // 直接從 Serial 串流中一邊接收一邊解析，防止 ESP8266 記憶體爆炸
        DeserializationError error = deserializeJson(doc, Serial);
        
        if (!error) {
            // 解析成功，清空畫面準備刷新
            tft.fillScreen(ST77XX_BLACK);
            
            // 🎯 1. 讀取 Unraid 傳過來的縮寫欄位數據
            int cpu_usage = doc["cpu"];       // CPU 使用率
            int ram_usage = doc["ram"];       // RAM 使用率
            float cpu_temp = doc["ct"];       // CPU 溫度
            const char* hostname = doc["host"]; // 主機名稱
            
            // 🎯 多讀取幾顆硬碟溫度，完美利用 320 寬度的螢幕空間
            float disk1_temp = doc["dtp"];    // Disk 1 溫度
            float disk2_temp = doc["dtp2"];   // Disk 2 溫度
            float disk3_temp = doc["dtp3"];   // Disk 3 溫度
            float disk4_temp = doc["dtp4"];   // Disk 4 溫度

            // 🎯 2. 繪製標題列
            tft.setCursor(10, 10);
            tft.setTextColor(ST77XX_GREEN);
            tft.setTextSize(2);
            tft.print("--- "); 
            tft.print(hostname ? hostname : "Unraid"); 
            tft.println(" Monitor ---");
            tft.println(""); // 換行留空
            
            // 🎯 3. 繪製左側：核心系統狀態
            tft.setTextColor(ST77XX_WHITE);
            tft.printf(" CPU:   %d %%\n", cpu_usage);
            tft.printf(" RAM:   %d %%\n", ram_usage);
            tft.printf(" C-Tmp: %.1f C\n", cpu_temp);
            tft.println(""); // 換行留空
            
            // 🎯 4. 繪製下半部/右側：多硬碟溫度監控陣列
            tft.setTextColor(ST77XX_CYAN);
            tft.println(" [Hard Drives Temp]");
            tft.setTextSize(2);
            tft.printf("  D1: %.0f C   D2: %.0f C\n", disk1_temp, disk2_temp);
            tft.printf("  D3: %.0f C   D4: %.0f C\n", disk3_temp, disk4_temp);
            
        } else {
            // 如果這一次的 JSON 封包毀損，清除序列埠快取垃圾，等待下一次的正確封包
            while(Serial.available() > 0) { Serial.read(); }
        }
    } else if (Serial.available() > 0) {
        // 如果進來的不是 '{' 開頭的非 JSON 數據，直接濾掉丟棄
        Serial.read();
    }
}