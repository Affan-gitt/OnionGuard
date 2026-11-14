/**
 * ============================================================================
 * ONIONGUARD - ESP32-H2 DevKit 4 FIRMWARE (STANDALONE ALL-IN-ONE SKETCH)
 * Smart Onion Storage, Monitoring and Environmental Management System
 * ============================================================================
 * Microcontroller: ESP32-H2-WROOM-1 (32-bit RISC-V @ 96MHz)
 * Primary Interface: USB-C CDC-ACM Serial (115200 Baud, Newline-Delimited JSON)
 * Secondary Interface: Bluetooth Low Energy 5.0 (BLE) GATT Architecture
 * Sensors: DHT11 (Temp/Humidity), MQ-3 (Alcohol Vapour Decomposition Proxy)
 * Actuators: 12V Exhaust Fan (Relay 1), Demonstration Actuator (GPIO 9)
 * Display: I2C LCD 1602 (PCF8574 Backpack @ 0x27)
 * ============================================================================
 * 
 * REQUIRED ARDUINO LIBRARIES:
 * 1. "DHT sensor library" by Adafruit
 * 2. "Adafruit Unified Sensor" by Adafruit
 * 3. "LiquidCrystal_I2C" by Frank de Brabander (or Marco Schwartz)
 * 4. "ArduinoJson" by Benoit Blanchon (supports v6 and v7)
 * 
 * ARDUINO IDE BOARD CONFIGURATION:
 * - Board: "ESP32H2 Dev Module"
 * - CPU Frequency: 96MHz
 * - Flash Size: 4MB
 * - Partition Scheme: Default 4MB with spiffs
 * - USB CDC On Boot: Enabled (Important: enables USB CDC-ACM serial on USB-C!)
 * ============================================================================
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
#define DEVICE_ID        "ONIONGUARD_ESP32H2"

// ============================================================================
// 1. PIN DEFINITIONS (ESP32-H2 DevKit 4)
// ============================================================================
#define PIN_MQ3_ANALOG          1   // ADC1_CH1 (Connect via 10k/20k voltage divider)
#define PIN_DHT11_DATA          2   // Digital 1-Wire Data bus with 10k pull-up to 3.3V
#define PIN_I2C_SDA             4   // I2C SDA for LCD display
#define PIN_I2C_SCL             5   // I2C SCL for LCD display
#define PIN_RELAY_FAN           8   // Relay control for exhaust fan (Active LOW)
#define PIN_ACTUATOR_HUM        9   // Demonstration actuator driver (Humidifier proxy)
#define PIN_STATUS_LED          10  // Onboard system heartbeat LED

// Actuator Active Logic Levels
#define RELAY_ACTIVE_LEVEL      LOW   // Standard opto-isolated relay modules are active LOW
#define RELAY_INACTIVE_LEVEL    HIGH
#define HUM_ACTIVE_LEVEL        HIGH
#define HUM_INACTIVE_LEVEL      LOW

// ============================================================================
// 2. BLE & TIMING CONFIGURATION
// ============================================================================
#define BLE_DEVICE_NAME             "OnionGuard-ESP32H2"
#define SERVICE_UUID                "0000A001-0000-1000-8000-00805F9B34FB"
#define CHAR_SENSOR_DATA_UUID       "0000A002-0000-1000-8000-00805F9B34FB"
#define CHAR_DEVICE_STATUS_UUID     "0000A003-0000-1000-8000-00805F9B34FB"
#define CHAR_ACTUATOR_COMMAND_UUID  "0000A004-0000-1000-8000-00805F9B34FB"
#define CHAR_CONFIG_UUID            "0000A005-0000-1000-8000-00805F9B34FB"
#define CHAR_EVENT_NOTIFY_UUID      "0000A006-0000-1000-8000-00805F9B34FB"

#define DEFAULT_TRIGGER_TEMP        26.0f // Fan turns ON at or above 26.0°C
#define DEFAULT_RESET_TEMP          24.0f // Fan turns OFF at or below 24.0°C (2.0°C hysteresis)
#define DEFAULT_MAX_HUMIDITY_SAFETY 75.0f // Humidifier safety interlock limit (Max 75% RH)
#define DEFAULT_MQ3_BASELINE        850   // Ambient raw ADC baseline
#define DEFAULT_MQ3_TRIGGER_DELTA   25.0f // +25% above baseline triggers demonstration actuator

#define SENSOR_READ_INTERVAL_MS     2000  // Acquire DHT11 & MQ-3 every 2 seconds
#define LCD_CYCLE_INTERVAL_MS       4000  // Rotate LCD screens every 4 seconds
#define MIN_FAN_CYCLE_TIME_MS       15000 // Anti-chattering: minimum 15s before toggling relay again
#define MAX_CONSECUTIVE_ERRORS      3     // Enter failsafe mode after 3 consecutive sensor read failures

#define LCD_I2C_ADDRESS             0x27  // Change to 0x3F if your PCF8574 backpack is addressed 0x3F
#define LCD_COLUMNS                 16
#define LCD_ROWS                    2

// ============================================================================
// 3. LCD DISPLAY DRIVER
// ============================================================================
class LcdDisplay {
private:
  LiquidCrystal_I2C _lcd;
  bool _isAvailable;
  unsigned long _lastCycleTime;
  int _currentScreen;

public:
  LcdDisplay() : _lcd(LCD_I2C_ADDRESS, LCD_COLUMNS, LCD_ROWS), _isAvailable(false), _lastCycleTime(0), _currentScreen(0) {}

  void begin() {
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
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
      _lcd.print("USB CDC + SENS");
      delay(1200);
      _lcd.clear();
    } else {
      _isAvailable = false;
    }
  }

  void update(float temp, float humidity, int mq3Adc, bool fanOn, bool humOn, bool bleConnected, bool sensorError, bool usbActive = false) {
    if (!_isAvailable) return;

    if (sensorError) {
      displayError("DHT11 FAULT", "Sensors Offline");
      return;
    }

    if (fanOn && temp >= DEFAULT_TRIGGER_TEMP) {
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
      _lcd.print("F:");
      _lcd.print(fanOn ? "ON " : "-- ");
      _lcd.print("USB:");
      _lcd.print(usbActive ? "OK " : "-- ");
      _lcd.print(bleConnected ? "BLE" : "   ");
    } else {
      _lcd.setCursor(0, 0);
      _lcd.print("STORAGE NORMAL ");
      _lcd.setCursor(0, 1);
      _lcd.print("MQ-3 ADC: ");
      _lcd.print(mq3Adc);
      _lcd.print("   ");
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

// ============================================================================
// 4. BLE SERVER & COMMUNICATION MANAGER
// ============================================================================
class CommandHandler {
public:
  virtual void onCommandReceived(const String& cmd) = 0;
};

class ServerCallbacks : public BLEServerCallbacks {
private:
  bool& _deviceConnected;
public:
  ServerCallbacks(bool& connected) : _deviceConnected(connected) {}
  void onConnect(BLEServer* pServer) override { _deviceConnected = true; }
  void onDisconnect(BLEServer* pServer) override {
    _deviceConnected = false;
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
      : _pServer(nullptr), _pService(nullptr), _pSensorDataChar(nullptr),
        _pStatusChar(nullptr), _pCommandChar(nullptr), _pConfigChar(nullptr),
        _pEventChar(nullptr), _deviceConnected(false), _commandHandler(handler) {}

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
    BLEDevice::startAdvertising();
  }

  bool isConnected() const { return _deviceConnected; }

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

// ============================================================================
// 5. GLOBAL STATE & FORWARD DECLARATIONS
// ============================================================================
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
unsigned long fanLastToggledTime = 0;

bool humidifierState = false;
String humidifierMode = "AUTO";
bool safetyInterlockActive = false;

float triggerTemp = DEFAULT_TRIGGER_TEMP;
float resetTemp = DEFAULT_RESET_TEMP;
float maxHumiditySafety = DEFAULT_MAX_HUMIDITY_SAFETY;
float mq3TriggerDelta = DEFAULT_MQ3_TRIGGER_DELTA;

unsigned long lastSensorReadTime = 0;
unsigned long lastHeartbeatTime = 0;
unsigned long lastUsbRxTime = 0;
unsigned long packetSequence = 0;
int consecutiveErrorCount = 0;
bool sensorFault = false;
bool hasValidReading = false;

void readPhysicalSensors();
void evaluateActuationLogic();
void setFanPhysicalState(bool state, const char* reason);
void setHumidifierPhysicalState(bool state, const char* reason);
void executeFailsafeShutdown();
void calibrateMq3Baseline();
void updateLcdDisplay();
void broadcastTelemetry();
void sendHeartbeat();
void toggleHeartbeatLed();
void processIncomingJsonCommand(const String& jsonStr, const char* sourceInterface);

class SystemCommandHandler : public CommandHandler {
public:
  void onCommandReceived(const String& cmd) override {
    processIncomingJsonCommand(cmd, "BLE");
  }
};

SystemCommandHandler cmdHandler;
BleServerManager bleManager(&cmdHandler);

// ============================================================================
// 6. SETUP & MAIN LOOP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1200);

  pinMode(PIN_RELAY_FAN, OUTPUT);
  digitalWrite(PIN_RELAY_FAN, RELAY_INACTIVE_LEVEL);

  pinMode(PIN_ACTUATOR_HUM, OUTPUT);
  digitalWrite(PIN_ACTUATOR_HUM, HUM_INACTIVE_LEVEL);

  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  dht.begin();
  lcd.begin();
  bleManager.begin();
  calibrateMq3Baseline();

  #if defined(ARDUINOJSON_VERSION_MAJOR) && (ARDUINOJSON_VERSION_MAJOR >= 7)
  JsonDocument bootDoc;
  #else
  StaticJsonDocument<256> bootDoc;
  #endif
  bootDoc["type"] = "boot";
  bootDoc["device_id"] = DEVICE_ID;
  bootDoc["fw"] = FIRMWARE_VERSION;
  bootDoc["status"] = "READY";
  bootDoc["protocol"] = "NDJSON";

  String bootMsg;
  serializeJson(bootDoc, bootMsg);
  Serial.println(bootMsg);
}

void loop() {
  unsigned long now = millis();

  // 1. Process USB CDC Serial incoming JSON
  while (Serial.available() > 0) {
    String inputLine = Serial.readStringUntil('\n');
    inputLine.trim();
    if (inputLine.length() > 0) {
      lastUsbRxTime = now;
      processIncomingJsonCommand(inputLine, "USB");
    }
  }

  // 2. Periodic Sensor Telemetry Acquisition (every 2s)
  if (now - lastSensorReadTime >= SENSOR_READ_INTERVAL_MS) {
    lastSensorReadTime = now;
    readPhysicalSensors();
    evaluateActuationLogic();
    updateLcdDisplay();
    broadcastTelemetry();
    toggleHeartbeatLed();
  }

  // 3. Periodic Heartbeat (every 5s)
  if (now - lastHeartbeatTime >= 5000) {
    lastHeartbeatTime = now;
    sendHeartbeat();
  }
}

// ============================================================================
// 7. SENSOR SAMPLING & FILTERING
// ============================================================================
void readPhysicalSensors() {
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

void evaluateActuationLogic() {
  if (sensorFault || !hasValidReading) return;

  unsigned long now = millis();

  // Fan Hysteresis
  if (fanMode == "AUTO") {
    if (now - fanLastToggledTime >= MIN_FAN_CYCLE_TIME_MS) {
      if (!fanState && currentTemperature >= triggerTemp) {
        setFanPhysicalState(true, "AUTO_TEMP_TRIGGER");
      } else if (fanState && currentTemperature <= resetTemp) {
        setFanPhysicalState(false, "AUTO_TEMP_RESET");
      }
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

void setFanPhysicalState(bool state, const char* reason) {
  fanState = state;
  fanLastToggledTime = millis();
  digitalWrite(PIN_RELAY_FAN, fanState ? RELAY_ACTIVE_LEVEL : RELAY_INACTIVE_LEVEL);
}

void setHumidifierPhysicalState(bool state, const char* reason) {
  humidifierState = state;
  digitalWrite(PIN_ACTUATOR_HUM, humidifierState ? HUM_ACTIVE_LEVEL : HUM_INACTIVE_LEVEL);
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
  bool usbActive = (millis() - lastUsbRxTime < 10000) && (lastUsbRxTime > 0);
  lcd.update(
    currentTemperature,
    currentHumidity,
    mq3RawAdc,
    fanState,
    humidifierState,
    bleManager.isConnected(),
    sensorFault,
    usbActive
  );
}

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
  bleManager.notifySensorData(payload);
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

void toggleHeartbeatLed() {
  static bool ledState = false;
  ledState = !ledState;
  digitalWrite(PIN_STATUS_LED, ledState ? HIGH : LOW);
}

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

  if (bleManager.isConnected()) {
    bleManager.notifyEvent(ackResponse);
  }
}
