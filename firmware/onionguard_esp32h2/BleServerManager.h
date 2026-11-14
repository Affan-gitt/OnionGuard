/**
 * OnionGuard ESP32-H2 BLE GATT Server Manager
 */

#ifndef BLE_SERVER_MANAGER_H
#define BLE_SERVER_MANAGER_H

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "Config.h"

class BleServerManager;

// Callback interface for commands received from Android app
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
    Serial.println("[BLE] Central client connected.");
  }

  void onDisconnect(BLEServer* pServer) override {
    _deviceConnected = false;
    Serial.println("[BLE] Central client disconnected. Restarting advertising...");
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
      Serial.print("[BLE] Command received: ");
      Serial.println(value);
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
    Serial.println("[BLE] Initializing OnionGuard BLE GATT Server...");
    BLEDevice::init(BLE_DEVICE_NAME);

    _pServer = BLEDevice::createServer();
    _pServer->setCallbacks(new ServerCallbacks(_deviceConnected));

    _pService = _pServer->createService(SERVICE_UUID);

    // 1. Sensor Data Characteristic (Notify / Read)
    _pSensorDataChar = _pService->createCharacteristic(
        CHAR_SENSOR_DATA_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _pSensorDataChar->addDescriptor(new BLE2902());

    // 2. Status Characteristic (Notify / Read)
    _pStatusChar = _pService->createCharacteristic(
        CHAR_DEVICE_STATUS_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _pStatusChar->addDescriptor(new BLE2902());

    // 3. Command Characteristic (Write)
    _pCommandChar = _pService->createCharacteristic(
        CHAR_ACTUATOR_COMMAND_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    _pCommandChar->setCallbacks(new CommandCallbacks(_commandHandler));

    // 4. Config Characteristic (Read / Write)
    _pConfigChar = _pService->createCharacteristic(
        CHAR_CONFIG_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
    );

    // 5. Event Notification Characteristic (Notify)
    _pEventChar = _pService->createCharacteristic(
        CHAR_EVENT_NOTIFY_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    _pEventChar->addDescriptor(new BLE2902());

    _pService->start();

    // Setup Advertising
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06); // functions that help with iPhone connections issue
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("[BLE] Advertising started. Device discoverable as " BLE_DEVICE_NAME);
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

#endif // BLE_SERVER_MANAGER_H
