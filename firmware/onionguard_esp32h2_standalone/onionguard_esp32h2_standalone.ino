/**
 * ONIONGUARD - ESP32-H2 DevKit 4
 * Firmware Version 1.2.0 (Full Standalone Production)
 *
 * Board Settings in Arduino IDE:
 * - Board: "ESP32H2 Dev Module"
 * - USB CDC On Boot: "Enabled" (CRITICAL for Type-C communication)
 * - Flash Frequency: 64MHz
 * - Upload Speed: 921600
 */

#include <Arduino.h>
#include <Wire.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define FIRMWARE_VERSION "1.2.0"
#define DEVICE_ID "ONIONGUARD_ESP32H2"

// ==================== PIN DEFINITIONS ====================
#define PIN_MQ3_ANALOG 1
#define PIN_DHT11_DATA 2
#define PIN_I2C_SDA 4
#define PIN_I2C_SCL 5
#define PIN_ARDUINO_FAN_SIGNAL 22
#define PIN_ACTUATOR_HUM 10
#define PIN_BUZZER 11

#define HUM_ACTIVE_LEVEL HIGH
#define HUM_INACTIVE_LEVEL LOW

// ==================== BLE CONFIGURATION ====================
#define ENABLE_BLE 1
#define BLE_DEVICE_NAME "OnionGuard-ESP32H2"

#define SERVICE_UUID "0000A001-0000-1000-8000-00805F9B34FB"
#define CHAR_SENSOR_DATA_UUID "0000A002-0000-1000-8000-00805F9B34FB"
#define CHAR_DEVICE_STATUS_UUID "0000A003-0000-1000-8000-00805F9B34FB"
#define CHAR_ACTUATOR_COMMAND_UUID "0000A004-0000-1000-8000-00805F9B34FB"
#define CHAR_CONFIG_UUID "0000A005-0000-1000-8000-00805F9B34FB"
#define CHAR_EVENT_NOTIFY_UUID "0000A006-0000-1000-8000-00805F9B34FB"

// ==================== DEFAULT THRESHOLDS ====================
#define DEFAULT_TRIGGER_TEMP 35.0f
#define DEFAULT_RESET_TEMP 32.0f
#define DEFAULT_MAX_HUMIDITY_SAFETY 75.0f
#define DEFAULT_MQ3_BASELINE 850
#define DEFAULT_MQ3_TRIGGER_DELTA 25.0f

#define DHT_READ_INTERVAL_MS 2000
#define MQ3_READ_INTERVAL_MS 700
#define LCD_UPDATE_INTERVAL_MS 700
#define TELEMETRY_INTERVAL_MS 1000
#define LCD_CYCLE_INTERVAL_MS 4000
#define MAX_CONSECUTIVE_ERRORS 3

#define LCD_I2C_ADDRESS 0x27
#define LCD_COLUMNS 16
#define LCD_ROWS 2

// ==================== LCD DISPLAY CLASS ====================
class LcdDisplay {
private:
  LiquidCrystal_I2C _lcd;
  bool _isAvailable;
  unsigned long _lastCycleTime;
  int _currentScreen;

public:
  LcdDisplay()
    : _lcd(LCD_I2C_ADDRESS, LCD_COLUMNS, LCD_ROWS),
      _isAvailable(false),
      _lastCycleTime(0),
      _currentScreen(0) {}

  void begin() {
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    Wire.setTimeOut(100); // 100ms timeout prevents freezing if LCD is missing or wiring loose

    Wire.beginTransmission(LCD_I2C_ADDRESS);
    byte error = Wire.endTransmission();

    if (error == 0) {
      _isAvailable = true;
      _lcd.init();
      _lcd.backlight();
      _lcd.clear();

      _lcd.setCursor(0, 0);
      _lcd.print("  ONIONGUARD  ");
      _lcd.setCursor(0, 1);
      _lcd.print(" ESP32-H2 ONLINE");
      delay(800);
      _lcd.clear();
    } else {
      _isAvailable = false;
      Serial.println("[WARN] LCD 1602 not detected on I2C bus (0x27)");
    }
  }

  void update(float temp, float humidity, int mq3Adc, bool fanOn, bool humOn, bool sensorError, float highTempThreshold) {
    if (!_isAvailable) return;

    if (sensorError) {
      displayError("DHT11 FAULT", "Sensors Offline");
      return;
    }

    if (fanOn && temp >= highTempThreshold) {
      displayHighTemp(temp);
      return;
    }

    if (humOn) {
      displayGasTrigger(mq3Adc);
      return;
    }

    if (millis() - _lastCycleTime >= LCD_CYCLE_INTERVAL_MS) {
      _lastCycleTime = millis();
      _currentScreen = (_currentScreen + 1) % 2;
    }

    if (_currentScreen == 0) {
      _lcd.setCursor(0, 0);
      _lcd.print("T:");
      _lcd.print(temp, 1);
      _lcd.print((char)223);
      _lcd.print("C H:");
      _lcd.print(humidity, 1);
      _lcd.print("%  ");

      _lcd.setCursor(0, 1);
      _lcd.print("FAN:");
      _lcd.print(fanOn ? "ON " : "OFF");
      _lcd.print(" HUM:");
      _lcd.print(humOn ? "ON " : "OFF");
    } else {
      _lcd.setCursor(0, 0);
      _lcd.print("MQ-3 ADC: ");
      _lcd.print(mq3Adc);
      _lcd.print("    ");

      _lcd.setCursor(0, 1);
      _lcd.print("BLE: ON | USB: OK");
    }
  }

  void displayHighTemp(float temp) {
    if (!_isAvailable) return;
    _lcd.setCursor(0, 0);
    _lcd.print("HIGH TEMP! ");
    _lcd.print(temp, 1);
    _lcd.print((char)223);
    _lcd.print("C");
    _lcd.setCursor(0, 1);
    _lcd.print("EXHAUST VENT: ON");
  }

  void displayGasTrigger(int adc) {
    if (!_isAvailable) return;
    _lcd.setCursor(0, 0);
    _lcd.print("GAS DETECTED!   ");
    _lcd.setCursor(0, 1);
    _lcd.print("ADC:");
    _lcd.print(adc);
    _lcd.print(" FILT:ON ");
  }

  void displayError(const char* line1, const char* line2) {
    if (!_isAvailable) return;
    _lcd.setCursor(0, 0);
    _lcd.print(line1);
    _lcd.print("        ");
    _lcd.setCursor(0, 1);
    _lcd.print(line2);
    _lcd.print("        ");
  }
};

// ==================== BLE COMMUNICATION ====================
class CommandHandler {
public:
  virtual void onCommandReceived(const String& cmd) = 0;
};

class ServerCallbacks : public BLEServerCallbacks {
private:
  bool& _deviceConnected;
public:
  ServerCallbacks(bool& connected) : _deviceConnected(connected) {}
  void onConnect(BLEServer* pServer) override {
    _deviceConnected = true;
    Serial.println("[BLE] Client phone connected");
  }
  void onDisconnect(BLEServer* pServer) override {
    _deviceConnected = false;
    Serial.println("[BLE] Client disconnected, restarting advertising...");
    pServer->startAdvertising();
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
private:
  CommandHandler* _handler;
public:
  CommandCallbacks(CommandHandler* handler) : _handler(handler) {}
  void onWrite(BLECharacteristic* pCharacteristic) override {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0 && _handler != nullptr) {
      _handler->onCommandReceived(value);
    }
  }
};

class BleServerManager {
private:
  BLEServer* _pServer;
  BLEService* _pService;
  BLECharacteristic* _pSensorDataChar;
  BLECharacteristic* _pStatusChar;
  BLECharacteristic* _pCommandChar;
  BLECharacteristic* _pConfigChar;
  BLECharacteristic* _pEventChar;
  bool _deviceConnected;
  CommandHandler* _commandHandler;

public:
  BleServerManager(CommandHandler* handler)
    : _pServer(nullptr),
      _pService(nullptr),
      _pSensorDataChar(nullptr),
      _pStatusChar(nullptr),
      _pCommandChar(nullptr),
      _pConfigChar(nullptr),
      _pEventChar(nullptr),
      _deviceConnected(false),
      _commandHandler(handler) {}

  void begin() {
    BLEDevice::init(BLE_DEVICE_NAME);
    _pServer = BLEDevice::createServer();
    _pServer->setCallbacks(new ServerCallbacks(_deviceConnected));

    _pService = _pServer->createService(SERVICE_UUID);

    _pSensorDataChar = _pService->createCharacteristic(
      CHAR_SENSOR_DATA_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _pSensorDataChar->addDescriptor(new BLE2902());

    _pStatusChar = _pService->createCharacteristic(
      CHAR_DEVICE_STATUS_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _pStatusChar->addDescriptor(new BLE2902());

    _pCommandChar = _pService->createCharacteristic(
      CHAR_ACTUATOR_COMMAND_UUID,
      BLECharacteristic::PROPERTY_WRITE
    );
    _pCommandChar->setCallbacks(new CommandCallbacks(_commandHandler));

    _pEventChar = _pService->createCharacteristic(
      CHAR_EVENT_NOTIFY_UUID,
      BLECharacteristic::PROPERTY_NOTIFY
    );
    _pEventChar->addDescriptor(new BLE2902());

    _pService->start();

    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);

    BLEDevice::startAdvertising();
    Serial.println("[BLE] Advertising started as: " BLE_DEVICE_NAME);
  }

  bool isConnected() const {
    return _deviceConnected;
  }

  void notifySensorData(const String& jsonPayload) {
    if (_deviceConnected && _pSensorDataChar != nullptr) {
      _pSensorDataChar->setValue(jsonPayload.c_str());
      _pSensorDataChar->notify();
    }
  }

  void notifyEvent(const String& eventJson) {
    if (_deviceConnected && _pEventChar != nullptr) {
      _pEventChar->setValue(eventJson.c_str());
      _pEventChar->notify();
    }
  }
};

// ==================== GLOBAL STATE ====================
DHT dht(PIN_DHT11_DATA, DHT11);
LcdDisplay lcd;

float currentTemperature = 0.0f;
float currentHumidity = 0.0f;
int mq3RawAdc = 0;
float mq3SmoothedAdc = 0.0f;
int mq3BaselineAdc = DEFAULT_MQ3_BASELINE;
float mq3DeltaPercent = 0.0f;

bool fanState = false;
String fanMode = "AUTO";

bool humidifierState = false;
String humidifierMode = "AUTO";
bool safetyInterlockActive = false;

float triggerTemp = DEFAULT_TRIGGER_TEMP;
float resetTemp = DEFAULT_RESET_TEMP;
float maxHumiditySafety = DEFAULT_MAX_HUMIDITY_SAFETY;
float mq3TriggerDelta = DEFAULT_MQ3_TRIGGER_DELTA;

unsigned long lastDhtReadTime = 0;
unsigned long lastMq3ReadTime = 0;
unsigned long lastLcdUpdateTime = 0;
unsigned long lastTelemetryTime = 0;
unsigned long lastHeartbeatTime = 0;
unsigned long lastUsbRxTime = 0;
unsigned long packetSequence = 0;

int consecutiveErrorCount = 0;
bool sensorFault = false;
bool hasValidReading = false;

// ==================== FORWARD DECLARATIONS ====================
void readDhtSensor();
void readMq3Sensor();
void evaluateActuationLogic();
void updateWarningBuzzer();
void setFanPhysicalState(bool state, const char* reason);
void setHumidifierPhysicalState(bool state, const char* reason);
void executeFailsafeShutdown();
void calibrateMq3Baseline();
void updateLcdDisplay();
void broadcastTelemetry();
void sendHeartbeat();
void processIncomingJsonCommand(const String& jsonStr, const char* sourceInterface);

class SystemCommandHandler : public CommandHandler {
public:
  void onCommandReceived(const String& cmd) override {
    processIncomingJsonCommand(cmd, "BLE");
  }
};

SystemCommandHandler cmdHandler;
BleServerManager bleManager(&cmdHandler);

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("========================================");
  Serial.println("   ONIONGUARD - ESP32-H2 DevKit 4       ");
  Serial.println("   Firmware: " FIRMWARE_VERSION);
  Serial.println("========================================");
  Serial.println("[BOOT] USB Serial ready");

  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  pinMode(PIN_ARDUINO_FAN_SIGNAL, OUTPUT);
  digitalWrite(PIN_ARDUINO_FAN_SIGNAL, LOW);
  Serial.println("[BOOT] Fan relay pin 22 initialized (OFF)");

  pinMode(PIN_ACTUATOR_HUM, OUTPUT);
  digitalWrite(PIN_ACTUATOR_HUM, HUM_INACTIVE_LEVEL);
  Serial.println("[BOOT] Humidifier pin 10 initialized (OFF)");

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  Serial.println("[BOOT] 12-bit ADC configured");

  dht.begin();
  Serial.println("[BOOT] DHT11 bus initialized on GPIO 2");

  lcd.begin();

#if ENABLE_BLE
  Serial.println("[BOOT] Initializing Bluetooth Low Energy 5.0...");
  bleManager.begin();
#endif

  calibrateMq3Baseline();
  Serial.print("[BOOT] Calibrated MQ-3 Baseline ADC: ");
  Serial.println(mq3BaselineAdc);

  Serial.println("ONIONGUARD READY");
  Serial.println("[INFO] Auto Ventilation: ON >= 35 C, OFF <= 32 C");
}

// ==================== MAIN LOOP ====================
void loop() {
  unsigned long now = millis();

  // 1. Process USB CDC Serial Commands
  while (Serial.available() > 0) {
    String inputLine = Serial.readStringUntil('\n');
    inputLine.trim();
    if (inputLine.length() > 0) {
      lastUsbRxTime = now;
      processIncomingJsonCommand(inputLine, "USB");
    }
  }

  // 2. Sample DHT11 Temperature & Humidity
  if (now - lastDhtReadTime >= DHT_READ_INTERVAL_MS) {
    lastDhtReadTime = now;
    readDhtSensor();
  }

  // 3. Sample MQ-3 Gas Sensor
  if (now - lastMq3ReadTime >= MQ3_READ_INTERVAL_MS) {
    lastMq3ReadTime = now;
    readMq3Sensor();
  }

  // 4. Actuation Decision Engine
  evaluateActuationLogic();
  updateWarningBuzzer();

  // 5. Update Local I2C LCD Display
  if (now - lastLcdUpdateTime >= LCD_UPDATE_INTERVAL_MS) {
    lastLcdUpdateTime = now;
    updateLcdDisplay();
  }

  // 6. Broadcast Real-time Telemetry (USB + BLE)
  if (now - lastTelemetryTime >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryTime = now;
    broadcastTelemetry();
  }

  // 7. Periodic Connection Heartbeat
  if (now - lastHeartbeatTime >= 5000) {
    lastHeartbeatTime = now;
    sendHeartbeat();
  }
}

// ==================== SENSOR SAMPLING ====================
void readDhtSensor() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  if (isnan(h) || isnan(t) || h <= 0.0f || t <= 0.0f) {
    consecutiveErrorCount++;
    if (consecutiveErrorCount >= MAX_CONSECUTIVE_ERRORS) {
      sensorFault = true;
      hasValidReading = false;
      executeFailsafeShutdown();
    }
    return;
  }

  consecutiveErrorCount = 0;
  sensorFault = false;
  hasValidReading = true;
  currentTemperature = t;
  currentHumidity = h;
}

void readMq3Sensor() {
  long adcSum = 0;
  for (int i = 0; i < 5; i++) {
    adcSum += analogRead(PIN_MQ3_ANALOG);
    delay(2);
  }

  mq3RawAdc = adcSum / 5;
  mq3SmoothedAdc = (0.2f * (float)mq3RawAdc) + (0.8f * mq3SmoothedAdc);

  if (mq3BaselineAdc > 0) {
    mq3DeltaPercent = (((float)mq3RawAdc - (float)mq3BaselineAdc) / (float)mq3BaselineAdc) * 100.0f;
  } else {
    mq3DeltaPercent = 0.0f;
  }
}

// ==================== ACTUATION DECISION LOGIC ====================
void evaluateActuationLogic() {
  if (sensorFault || !hasValidReading) return;

  // Thermal Automatic Exhaust Control with Hysteresis
  if (fanMode == "AUTO") {
    if (fanState && currentTemperature <= resetTemp) {
      setFanPhysicalState(false, "AUTO_TEMP_RESET");
    } else if (!fanState && currentTemperature >= triggerTemp) {
      setFanPhysicalState(true, "AUTO_TEMP_TRIGGER");
    }
  }

  // Humidifier Safety Interlock
  if (currentHumidity >= maxHumiditySafety) {
    if (humidifierState) {
      setHumidifierPhysicalState(false, "SAFETY_INTERLOCK_EXCEEDED");
    }
    safetyInterlockActive = true;
  } else {
    safetyInterlockActive = false;
    if (humidifierMode == "AUTO") {
      if (mq3DeltaPercent >= mq3TriggerDelta) {
        if (!humidifierState) {
          setHumidifierPhysicalState(true, "AUTO_GAS_TRIGGER");
        }
      } else {
        if (humidifierState) {
          setHumidifierPhysicalState(false, "AUTO_GAS_RESET");
        }
      }
    }
  }
}

// ==================== PHYSICAL RELAYS & ACTUATORS ====================
void setFanPhysicalState(bool state, const char* reason) {
  fanState = state;
  digitalWrite(PIN_ARDUINO_FAN_SIGNAL, state ? HIGH : LOW);
  Serial.print("[FAN] ");
  Serial.print(state ? "ON" : "OFF");
  Serial.print(" | Reason: ");
  Serial.println(reason);
}

void setHumidifierPhysicalState(bool state, const char* reason) {
  humidifierState = state;
  digitalWrite(PIN_ACTUATOR_HUM, humidifierState ? HUM_ACTIVE_LEVEL : HUM_INACTIVE_LEVEL);
  Serial.print("[HUMIDIFIER] ");
  Serial.print(humidifierState ? "ON" : "OFF");
  Serial.print(" | Reason: ");
  Serial.println(reason);
}

void executeFailsafeShutdown() {
  setFanPhysicalState(false, "FAILSAFE_SHUTDOWN");
  setHumidifierPhysicalState(false, "FAILSAFE_SHUTDOWN");
  lcd.displayError("HARDWARE FAULT", "Actuators OFF");
}

void calibrateMq3Baseline() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PIN_MQ3_ANALOG);
    delay(50);
  }
  mq3BaselineAdc = sum / 10;
  mq3SmoothedAdc = (float)mq3BaselineAdc;
}

void updateLcdDisplay() {
  lcd.update(
    currentTemperature,
    currentHumidity,
    mq3RawAdc,
    fanState,
    humidifierState,
    sensorFault,
    triggerTemp
  );
}

// ==================== TELEMETRY BROADCAST ====================
void broadcastTelemetry() {
  packetSequence++;

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
#else
  StaticJsonDocument<384> doc;
#endif

  doc["type"] = "sensor";
  doc["dev"] = DEVICE_ID;
  doc["fw"] = FIRMWARE_VERSION;
  doc["seq"] = packetSequence;
  doc["uptime"] = millis() / 1000;

  if (hasValidReading && !sensorFault) {
    doc["temperature"] = serialized(String(currentTemperature, 1));
    doc["humidity"] = serialized(String(currentHumidity, 1));
    doc["mq3_raw"] = mq3RawAdc;
    doc["mq3_delta"] = serialized(String(mq3DeltaPercent, 1));
    doc["sensor_status"] = safetyInterlockActive ? "INTERLOCK" : "OK";
  } else {
    doc["temperature"] = nullptr;
    doc["humidity"] = nullptr;
    doc["mq3_raw"] = nullptr;
    doc["mq3_delta"] = nullptr;
    doc["sensor_status"] = "WAITING FOR SENSOR DATA";
  }

  doc["fan"] = fanState;
  doc["humidifier"] = humidifierState;
  doc["fan_mode"] = fanMode;
  doc["humidifier_mode"] = humidifierMode;
  doc["safety_lock"] = safetyInterlockActive;

  String payload;
  serializeJson(doc, payload);
  Serial.println(payload);

#if ENABLE_BLE
  bleManager.notifySensorData(payload);
#endif
}

void sendHeartbeat() {
  packetSequence++;

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument doc;
#else
  StaticJsonDocument<256> doc;
#endif

  doc["type"] = "heartbeat";
  doc["dev"] = DEVICE_ID;
  doc["fw"] = FIRMWARE_VERSION;
  doc["seq"] = packetSequence;
  doc["uptime"] = millis() / 1000;
  doc["status"] = sensorFault ? "SENSOR_FAULT" : "OK";
  doc["fan"] = fanState;
  doc["humidifier"] = humidifierState;

  String payload;
  serializeJson(doc, payload);
  Serial.println(payload);
}

void updateWarningBuzzer() {
  static unsigned long lastBeepTime = 0;
  static bool buzzerOn = false;

  bool tempWarning = hasValidReading && !sensorFault && (currentTemperature >= triggerTemp);
  bool gasWarning = (mq3DeltaPercent >= mq3TriggerDelta);
  bool warning = tempWarning || gasWarning;

  if (!warning) {
    digitalWrite(PIN_BUZZER, LOW);
    buzzerOn = false;
    return;
  }

  if (millis() - lastBeepTime >= (buzzerOn ? 150 : 850)) {
    buzzerOn = !buzzerOn;
    lastBeepTime = millis();
    digitalWrite(PIN_BUZZER, buzzerOn ? HIGH : LOW);
  }
}

// ==================== INCOMING JSON COMMANDS ====================
void processIncomingJsonCommand(const String& jsonStr, const char* sourceInterface) {
#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument cmdDoc;
#else
  StaticJsonDocument<384> cmdDoc;
#endif

  DeserializationError err = deserializeJson(cmdDoc, jsonStr);
  if (err) {
    Serial.println("{\"type\":\"error\",\"message\":\"INVALID_JSON\"}");
    return;
  }

  long cmdSeq = cmdDoc["seq"] | 0;
  const char* type = cmdDoc["type"] | "";

#if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument ackDoc;
#else
  StaticJsonDocument<256> ackDoc;
#endif

  ackDoc["type"] = "ack";
  ackDoc["seq"] = cmdSeq;
  ackDoc["source"] = sourceInterface;

  if (strcmp(type, "command") == 0) {
    if (cmdDoc.containsKey("device")) {
      const char* device = cmdDoc["device"] | "";
      bool reqState = cmdDoc["state"] | false;

      if (strcmp(device, "fan") == 0) {
        fanMode = "MANUAL";
        setFanPhysicalState(reqState, "MANUAL_COMMAND");
        ackDoc["device"] = "fan";
        ackDoc["state"] = reqState;
        ackDoc["actual_state"] = fanState;
        ackDoc["success"] = (fanState == reqState);
      } else if (strcmp(device, "humidifier") == 0) {
        if (reqState && (currentHumidity >= maxHumiditySafety || safetyInterlockActive)) {
          ackDoc["device"] = "humidifier";
          ackDoc["state"] = false;
          ackDoc["actual_state"] = false;
          ackDoc["success"] = false;
          ackDoc["error"] = "HUMIDITY_SAFETY_LIMIT_EXCEEDED";
        } else {
          humidifierMode = "MANUAL";
          setHumidifierPhysicalState(reqState, "MANUAL_COMMAND");
          ackDoc["device"] = "humidifier";
          ackDoc["state"] = reqState;
          ackDoc["actual_state"] = humidifierState;
          ackDoc["success"] = (humidifierState == reqState);
        }
      } else {
        ackDoc["success"] = false;
        ackDoc["error"] = "UNKNOWN_DEVICE";
      }
    } else if (cmdDoc.containsKey("action")) {
      const char* action = cmdDoc["action"] | "";
      if (strcmp(action, "calibrate_baseline") == 0) {
        calibrateMq3Baseline();
        ackDoc["action"] = "calibrate_baseline";
        ackDoc["success"] = true;
        ackDoc["baseline"] = mq3BaselineAdc;
      } else if (strcmp(action, "auto_mode") == 0) {
        fanMode = "AUTO";
        humidifierMode = "AUTO";
        ackDoc["action"] = "auto_mode";
        ackDoc["success"] = true;
      } else if (strcmp(action, "ping") == 0) {
        ackDoc["action"] = "ping";
        ackDoc["success"] = true;
        ackDoc["uptime"] = millis() / 1000;
      } else {
        ackDoc["success"] = false;
        ackDoc["error"] = "UNKNOWN_ACTION";
      }
    }
  } else {
    ackDoc["success"] = false;
    ackDoc["error"] = "UNRECOGNIZED_PACKET_TYPE";
  }

  String ackResponse;
  serializeJson(ackDoc, ackResponse);
  Serial.println(ackResponse);

#if ENABLE_BLE
  if (bleManager.isConnected()) {
    bleManager.notifyEvent(ackResponse);
  }
#endif
}
