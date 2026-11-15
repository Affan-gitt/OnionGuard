/**
 * ============================================================================
 * ONIONGUARD - ESP32 Wi-Fi + BT SoC Firmware
 * Firmware Version: 2.0.0 (Wi-Fi REST Edition)
 * Target Board    : "ESP32 Dev Module" (ESP32-WROOM-32 / DevKit V1 / ESP32-S3)
 * ============================================================================
 * 
 * LIBRARIES REQUIRED (Install via Arduino IDE Library Manager):
 * 1. "DHT sensor library" by Adafruit
 * 2. "LiquidCrystal I2C" by Frank de Brabander or Marco Schwartz
 * 3. "ArduinoJson" by Benoit Blanchon (Supports both v6 and v7 automatically)
 * 
 * HARDWARE CONNECTIONS:
 * ----------------------------------------------------------------------------
 * 1. MQ-3 Gas Sensor (Volatile Spoilage Gas / Alcohol Proxy):
 *    - VCC  -> 5V (or VIN)
 *    - GND  -> GND
 *    - A0   -> GPIO 34 (ADC1_CH6 - MUST use ADC1; ADC2 is disabled during Wi-Fi!)
 * 
 * 2. DHT11 Temperature & Humidity Sensor:
 *    - VCC  -> 3.3V or 5V
 *    - GND  -> GND
 *    - DATA -> GPIO 4 (10k pull-up resistor to VCC recommended)
 * 
 * 3. 16x2 I2C LCD Display (PCF8574):
 *    - VCC  -> 5V
 *    - GND  -> GND
 *    - SDA  -> GPIO 21
 *    - SCL  -> GPIO 22
 * 
 * 4. Relays & Actuators:
 *    - Exhaust Ventilation Fan Relay -> GPIO 18
 *    - Humidifier / Demonstration Relay -> GPIO 19
 *    - Warning Piezo Buzzer -> GPIO 15
 *    - Onboard Status LED -> GPIO 2 (DevKit Blue LED)
 * ----------------------------------------------------------------------------
 */

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <ArduinoJson.h>

#define FIRMWARE_VERSION "2.0.0-WIFI"
#define DEVICE_ID "ONIONGUARD_ESP32_WIFI"

// ============================================================================
// PIN DEFINITIONS (Optimized for ESP32 Wi-Fi SoC)
// ============================================================================
#define PIN_MQ3_ANALOG        34   // ADC1_CH6 (Safe with Wi-Fi, input-only pin)
#define PIN_DHT11_DATA        4    // DHT11 Sensor Data
#define PIN_I2C_SDA           21   // Default I2C SDA
#define PIN_I2C_SCL           22   // Default I2C SCL
#define PIN_RELAY_FAN         18   // Exhaust Fan Relay
#define PIN_RELAY_HUM         19   // Humidifier / Gas Demonstration Relay
#define PIN_BUZZER            15   // Piezo Warning Buzzer
#define PIN_STATUS_LED        2    // Onboard Blue Status LED

// Actuator Active Logic Levels (Adjust based on relay module: HIGH or LOW)
#define RELAY_ACTIVE_LEVEL    HIGH
#define RELAY_INACTIVE_LEVEL  LOW

// ============================================================================
// WI-FI CONFIGURATION
// ============================================================================
// SoftAP Mode (Standalone Hotspot - Default Gateway: 192.168.4.1)
const char* AP_SSID = "OnionGuard-WiFi";
const char* AP_PASS = "onionguard123";

// Optional Station Mode (Connect to existing farm/home router if desired)
const char* STA_SSID = "";     // Set your Wi-Fi SSID here if connecting to router
const char* STA_PASS = "";     // Set your Wi-Fi password here

// WebServer on standard HTTP port 80
WebServer server(80);

// ============================================================================
// THRESHOLD DEFAULTS
// ============================================================================
#define DEFAULT_TRIGGER_TEMP         35.0f // Fan turns ON at or above this temp
#define DEFAULT_RESET_TEMP           32.0f // Fan turns OFF at or below this temp
#define DEFAULT_MAX_HUMIDITY_SAFETY  75.0f // Humidifier safety interlock limit
#define DEFAULT_MQ3_BASELINE         300   // Clean air baseline ADC
#define DEFAULT_MQ3_TRIGGER_DELTA    25.0f // Percentage rise above baseline to trigger

#define DHT_READ_INTERVAL_MS         2000
#define MQ3_READ_INTERVAL_MS         700
#define LCD_CYCLE_INTERVAL_MS        3500

#define LCD_I2C_ADDRESS              0x27
#define LCD_COLUMNS                  16
#define LCD_ROWS                     2

// ============================================================================
// SENSORS & DISPLAY OBJECTS
// ============================================================================
DHT dht(PIN_DHT11_DATA, DHT11);
LiquidCrystal_I2C lcd(LCD_I2C_ADDRESS, LCD_COLUMNS, LCD_ROWS);
bool lcdAvailable = false;

// ============================================================================
// RUNTIME STATE
// ============================================================================
float currentTemperature = 24.0f;
float currentHumidity = 60.0f;
int mq3RawAdc = 320;
float mq3SmoothedAdc = 320.0f;
int mq3BaselineAdc = DEFAULT_MQ3_BASELINE;
float mq3DeltaPercent = 0.0f;

bool fanState = false;
String fanMode = "AUTO"; // "AUTO" or "MANUAL"

bool humidifierState = false;
String humidifierMode = "AUTO"; // "AUTO" or "MANUAL"

bool safetyInterlockActive = false;
bool sensorFault = false;

unsigned long lastDhtReadTime = 0;
unsigned long lastMq3ReadTime = 0;
unsigned long lastLcdCycleTime = 0;
int lcdScreenIndex = 0;

// ============================================================================
// ACTUATOR PHYSICAL CONTROL
// ============================================================================
void setFanPhysical(bool state, const char* reason) {
  fanState = state;
  digitalWrite(PIN_RELAY_FAN, state ? RELAY_ACTIVE_LEVEL : RELAY_INACTIVE_LEVEL);
  Serial.printf("[ACTUATOR] Fan set to %s (Reason: %s)\n", state ? "ON" : "OFF", reason);
}

void setHumidifierPhysical(bool state, const char* reason) {
  if (state && safetyInterlockActive) {
    Serial.println("[SAFETY] Humidifier activation BLOCKED by humidity safety interlock!");
    humidifierState = false;
    digitalWrite(PIN_RELAY_HUM, RELAY_INACTIVE_LEVEL);
    return;
  }
  humidifierState = state;
  digitalWrite(PIN_RELAY_HUM, state ? RELAY_ACTIVE_LEVEL : RELAY_INACTIVE_LEVEL);
  Serial.printf("[ACTUATOR] Humidifier set to %s (Reason: %s)\n", state ? "ON" : "OFF", reason);
}

// ============================================================================
// SENSOR ACQUISITION & LOGIC
// ============================================================================
void readDhtSensor() {
  if (millis() - lastDhtReadTime < DHT_READ_INTERVAL_MS) return;
  lastDhtReadTime = millis();

  float t = dht.readTemperature();
  float h = dht.readHumidity();

  if (isnan(t) || isnan(h) || t < -40.0f || t > 80.0f || h < 0.0f || h > 100.0f) {
    sensorFault = true;
    Serial.println("[SENSOR] Warning: DHT11 read fault!");
  } else {
    sensorFault = false;
    currentTemperature = t;
    currentHumidity = h;
  }
}

void readMq3Sensor() {
  if (millis() - lastMq3ReadTime < MQ3_READ_INTERVAL_MS) return;
  lastMq3ReadTime = millis();

  int raw = analogRead(PIN_MQ3_ANALOG);
  mq3RawAdc = raw;

  // Exponential moving average filter
  mq3SmoothedAdc = (0.25f * raw) + (0.75f * mq3SmoothedAdc);

  if (mq3BaselineAdc > 0) {
    mq3DeltaPercent = ((mq3SmoothedAdc - mq3BaselineAdc) / (float)mq3BaselineAdc) * 100.0f;
  } else {
    mq3DeltaPercent = 0.0f;
  }
}

void evaluateAutomatedLogic() {
  // 1. Humidity Safety Interlock
  if (currentHumidity >= DEFAULT_MAX_HUMIDITY_SAFETY) {
    if (!safetyInterlockActive) {
      safetyInterlockActive = true;
      Serial.println("[SAFETY INTERLOCK] High humidity limit reached! Disabling humidifier.");
      setHumidifierPhysical(false, "Humidity Safety Interlock");
    }
  } else {
    safetyInterlockActive = false;
  }

  // 2. Automated Fan Control (when mode is AUTO)
  if (fanMode == "AUTO" && !sensorFault) {
    if (!fanState && currentTemperature >= DEFAULT_TRIGGER_TEMP) {
      setFanPhysical(true, "Auto Temp Trigger >= 35C");
    } else if (fanState && currentTemperature <= DEFAULT_RESET_TEMP) {
      setFanPhysical(false, "Auto Temp Reset <= 32C");
    }
  }

  // 3. Automated Gas Actuator Control (when mode is AUTO)
  if (humidifierMode == "AUTO" && !sensorFault) {
    if (!humidifierState && mq3DeltaPercent >= DEFAULT_MQ3_TRIGGER_DELTA && !safetyInterlockActive) {
      setHumidifierPhysical(true, "Auto Gas Spike Trigger");
    } else if (humidifierState && mq3DeltaPercent < (DEFAULT_MQ3_TRIGGER_DELTA / 2.0f)) {
      setHumidifierPhysical(false, "Auto Gas Normalized");
    }
  }
}

void updateWarningBuzzer() {
  static unsigned long lastBeepTime = 0;
  static bool buzzerState = false;

  bool tempWarning = !sensorFault && (currentTemperature >= DEFAULT_TRIGGER_TEMP);
  bool gasWarning = (mq3DeltaPercent >= DEFAULT_MQ3_TRIGGER_DELTA);
  bool warning = tempWarning || gasWarning;

  if (!warning) {
    digitalWrite(PIN_BUZZER, LOW);
    buzzerState = false;
    return;
  }

  unsigned long interval = gasWarning ? 150 : 350;
  if (millis() - lastBeepTime >= interval) {
    lastBeepTime = millis();
    buzzerState = !buzzerState;
    digitalWrite(PIN_BUZZER, buzzerState ? HIGH : LOW);
  }
}

// ============================================================================
// LCD DISPLAY ROTATION
// ============================================================================
void initLcd() {
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.beginTransmission(LCD_I2C_ADDRESS);
  byte error = Wire.endTransmission();

  if (error == 0) {
    lcdAvailable = true;
    lcd.init();
    lcd.backlight();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("  ONIONGUARD  ");
    lcd.setCursor(0, 1);
    lcd.print(" Wi-Fi Edition  ");
    delay(1200);
    lcd.clear();
  } else {
    lcdAvailable = false;
    Serial.println("[LCD] I2C LCD not detected at 0x27, continuing without display.");
  }
}

void updateLcd() {
  if (!lcdAvailable) return;

  if (millis() - lastLcdCycleTime >= LCD_CYCLE_INTERVAL_MS) {
    lastLcdCycleTime = millis();
    lcdScreenIndex = (lcdScreenIndex + 1) % 3;
    lcd.clear();
  }

  if (lcdScreenIndex == 0) {
    // Screen 1: Temp & Humidity
    lcd.setCursor(0, 0);
    lcd.print("T:");
    lcd.print(currentTemperature, 1);
    lcd.print((char)223);
    lcd.print("C H:");
    lcd.print(currentHumidity, 1);
    lcd.print("% ");

    lcd.setCursor(0, 1);
    lcd.print("Fan:");
    lcd.print(fanState ? "ON " : "OFF");
    lcd.print(" Act:");
    lcd.print(humidifierState ? "ON " : "OFF");
  } else if (lcdScreenIndex == 1) {
    // Screen 2: Gas Sensor ADC & Delta
    lcd.setCursor(0, 0);
    lcd.print("MQ3 ADC: ");
    lcd.print(mq3RawAdc);
    lcd.print("    ");

    lcd.setCursor(0, 1);
    lcd.print("Delta: ");
    if (mq3DeltaPercent > 0) lcd.print("+");
    lcd.print(mq3DeltaPercent, 1);
    lcd.print("%     ");
  } else {
    // Screen 3: Wi-Fi IP Address
    lcd.setCursor(0, 0);
    lcd.print("Wi-Fi: OnionGuard");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.softAPIP().toString());
    lcd.print("   ");
  }
}

// ============================================================================
// HTTP REST API HANDLERS
// ============================================================================
void sendCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleOptions() {
  sendCorsHeaders();
  server.send(204);
}

// GET /api/sensors
void handleGetSensors() {
  sendCorsHeaders();

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
#else
  StaticJsonDocument<512> doc;
#endif

  doc["device_id"] = DEVICE_ID;
  doc["version"] = FIRMWARE_VERSION;
  doc["temperature"] = currentTemperature;
  doc["humidity"] = currentHumidity;
  doc["mq3_raw"] = mq3RawAdc;
  doc["mq3_baseline"] = mq3BaselineAdc;
  doc["mq3_delta_pct"] = mq3DeltaPercent;
  doc["fan"] = fanState;
  doc["fan_mode"] = fanMode;
  doc["humidifier"] = humidifierState;
  doc["humidifier_mode"] = humidifierMode;
  doc["interlock"] = safetyInterlockActive;
  doc["sensor_status"] = sensorFault ? "DHT_FAULT" : "OK";
  doc["uptime_s"] = millis() / 1000;

  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

// POST /api/command
void handlePostCommand() {
  sendCorsHeaders();

  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"success\":false,\"error\":\"No JSON payload provided\"}");
    return;
  }

  String body = server.arg("plain");

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
#else
  StaticJsonDocument<256> doc;
#endif

  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    server.send(400, "application/json", "{\"success\":false,\"error\":\"Invalid JSON\"}");
    return;
  }

  String device = doc["device"] | "";
  bool targetState = doc["state"] | false;
  String mode = doc["mode"] | "MANUAL";

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument response;
#else
  StaticJsonDocument<256> response;
#endif

  response["device"] = device;
  response["requested_state"] = targetState;

  if (device == "fan") {
    fanMode = mode;
    setFanPhysical(targetState, "HTTP REST Command");
    response["success"] = true;
    response["actual_state"] = fanState;
    response["state"] = fanState;
    response["mode"] = fanMode;
  } else if (device == "humidifier") {
    humidifierMode = mode;
    if (targetState && safetyInterlockActive) {
      response["success"] = false;
      response["actual_state"] = false;
      response["state"] = false;
      response["error"] = "High humidity safety interlock active";
    } else {
      setHumidifierPhysical(targetState, "HTTP REST Command");
      response["success"] = true;
      response["actual_state"] = humidifierState;
      response["state"] = humidifierState;
      response["mode"] = humidifierMode;
    }
  } else if (device == "calibrate") {
    mq3BaselineAdc = mq3RawAdc;
    response["success"] = true;
    response["actual_state"] = true;
    response["state"] = true;
    response["new_baseline"] = mq3BaselineAdc;
    Serial.printf("[CALIBRATION] MQ-3 baseline updated to %d\n", mq3BaselineAdc);
  } else {
    response["success"] = false;
    response["error"] = "Unknown device (supported: 'fan', 'humidifier', 'calibrate')";
  }

  String resStr;
  serializeJson(response, resStr);
  server.send(200, "application/json", resStr);
}

// GET /api/status
void handleGetStatus() {
  sendCorsHeaders();

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
#else
  StaticJsonDocument<384> doc;
#endif

  doc["device_id"] = DEVICE_ID;
  doc["firmware"] = FIRMWARE_VERSION;
  doc["ap_ip"] = WiFi.softAPIP().toString();
  doc["sta_ip"] = WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : "Not Connected";
  doc["free_heap"] = ESP.getFreeHeap();
  doc["uptime_s"] = millis() / 1000;
  doc["stations_connected"] = WiFi.softAPgetStationNum();

  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

// GET / (Visual Web Control Panel for any Browser)
void handleRoot() {
  sendCorsHeaders();

  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<title>OnionGuard ESP32 Controller</title>";
  html += "<style>";
  html += "body{font-family:sans-serif;background:#0f172a;color:#f8fafc;padding:20px;margin:0;}";
  html += ".card{background:#1e293b;border-radius:12px;padding:16px;margin-bottom:14px;box-shadow:0 4px 6px -1px rgba(0,0,0,0.3);}";
  html += "h1{color:#4ade80;font-size:22px;margin-top:0;}";
  html += ".grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;}";
  html += ".metric{background:#334155;padding:12px;border-radius:8px;text-align:center;}";
  html += ".val{font-size:24px;font-weight:bold;color:#38bdf8;}";
  html += ".btn{display:inline-block;padding:10px 18px;border-radius:6px;border:none;font-weight:bold;cursor:pointer;margin:4px;}";
  html += ".btn-on{background:#22c55e;color:#fff;} .btn-off{background:#ef4444;color:#fff;}";
  html += "</style></head><body>";
  html += "<h1>🧅 OnionGuard ESP32 Wi-Fi Controller</h1>";
  html += "<div class='card'>";
  html += "<h3>Live Storage Environment</h3>";
  html += "<div class='grid'>";
  html += "<div class='metric'><div>Temperature</div><div class='val'>" + String(currentTemperature, 1) + " °C</div></div>";
  html += "<div class='metric'><div>Humidity</div><div class='val'>" + String(currentHumidity, 1) + " %</div></div>";
  html += "<div class='metric'><div>MQ-3 Gas ADC</div><div class='val'>" + String(mq3RawAdc) + "</div></div>";
  html += "<div class='metric'><div>Gas Delta</div><div class='val'>" + (mq3DeltaPercent > 0 ? "+" : "") + String(mq3DeltaPercent, 1) + " %</div></div>";
  html += "</div></div>";

  html += "<div class='card'>";
  html += "<h3>Physical Relay Control</h3>";
  html += "<p>Exhaust Fan: <b>" + String(fanState ? "RUNNING (ON)" : "IDLE (OFF)") + "</b></p>";
  html += "<button class='btn btn-on' onclick=\"cmd('fan',true)\">Fan ON</button>";
  html += "<button class='btn btn-off' onclick=\"cmd('fan',false)\">Fan OFF</button>";
  html += "<hr style='border-color:#334155;margin:12px 0;'>";
  html += "<p>Demonstration Actuator: <b>" + String(humidifierState ? "ACTIVE (ON)" : "IDLE (OFF)") + "</b></p>";
  html += "<button class='btn btn-on' onclick=\"cmd('humidifier',true)\">Actuator ON</button>";
  html += "<button class='btn btn-off' onclick=\"cmd('humidifier',false)\">Actuator OFF</button>";
  html += "</div>";

  html += "<script>";
  html += "function cmd(dev,st){";
  html += "fetch('/api/command',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({device:dev,state:st})})";
  html += ".then(r=>r.json()).then(d=>{alert(dev+' state set to: '+d.actual_state);location.reload();});";
  html += "}";
  html += "</script></body></html>";

  server.send(200, "text/html", html);
}

// ============================================================================
// SETUP & INITIALIZATION
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("==================================================");
  Serial.println("       ONIONGUARD ESP32 WI-FI SOC INITIALIZING     ");
  Serial.println("==================================================");

  // Initialize GPIO pins
  pinMode(PIN_STATUS_LED, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_RELAY_FAN, OUTPUT);
  pinMode(PIN_RELAY_HUM, OUTPUT);

  digitalWrite(PIN_STATUS_LED, LOW);
  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_RELAY_FAN, RELAY_INACTIVE_LEVEL);
  digitalWrite(PIN_RELAY_HUM, RELAY_INACTIVE_LEVEL);

  // Configure analog ADC
  analogReadResolution(12); // 12-bit ADC (0 - 4095)
  pinMode(PIN_MQ3_ANALOG, INPUT);

  // Initialize DHT11
  dht.begin();
  Serial.println("[BOOT] DHT11 sensor initialized on GPIO 4");

  // Initialize LCD
  initLcd();

  // Setup Wi-Fi SoftAP Mode
  WiFi.mode(WIFI_AP_STA);
  bool apSuccess = WiFi.softAP(AP_SSID, AP_PASS);

  if (apSuccess) {
    Serial.println("[WIFI] SoftAP Access Point started successfully!");
    Serial.print("[WIFI] SSID: ");
    Serial.println(AP_SSID);
    Serial.print("[WIFI] Password: ");
    Serial.println(AP_PASS);
    Serial.print("[WIFI] Access Point IP: ");
    Serial.println(WiFi.softAPIP());
  } else {
    Serial.println("[WIFI] Error: Failed to start SoftAP!");
  }

  // Attempt Station Mode if credentials provided
  if (strlen(STA_SSID) > 0) {
    Serial.print("[WIFI] Connecting to local network: ");
    Serial.println(STA_SSID);
    WiFi.begin(STA_SSID, STA_PASS);
  }

  // Configure WebServer Endpoints
  server.on("/", HTTP_GET, handleRoot);
  server.on("/api/sensors", HTTP_GET, handleGetSensors);
  server.on("/api/sensors", HTTP_OPTIONS, handleOptions);
  server.on("/api/command", HTTP_POST, handlePostCommand);
  server.on("/api/command", HTTP_OPTIONS, handleOptions);
  server.on("/api/status", HTTP_GET, handleGetStatus);
  server.on("/api/status", HTTP_OPTIONS, handleOptions);

  server.begin();
  Serial.println("[BOOT] HTTP REST Server active on port 80");
  Serial.println("[BOOT] Ready for connections.");

  // Audible boot chirp
  digitalWrite(PIN_BUZZER, HIGH);
  delay(80);
  digitalWrite(PIN_BUZZER, LOW);
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  server.handleClient();
  readDhtSensor();
  readMq3Sensor();
  evaluateAutomatedLogic();
  updateWarningBuzzer();
  updateLcd();
  digitalWrite(PIN_STATUS_LED, (millis() % 1000) < 100 ? HIGH : LOW);
}
