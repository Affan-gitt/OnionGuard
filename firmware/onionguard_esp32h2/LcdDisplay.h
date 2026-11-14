/**
 * OnionGuard ESP32-H2 LCD Display Engine
 * Supports standard I2C 1602 and 2004 LCDs via PCF8574 I2C adapter.
 */

#ifndef LCD_DISPLAY_H
#define LCD_DISPLAY_H

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "Config.h"

enum LcdScreenMode {
  LCD_SCREEN_NORMAL,
  LCD_SCREEN_HIGH_TEMP,
  LCD_SCREEN_GAS_TRIGGER,
  LCD_SCREEN_ERROR,
};

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
      _lcd.print("ESP32-H2 DevKit");
      delay(1500);
      _lcd.clear();
    } else {
      _isAvailable = false;
      Serial.println("[LCD] No physical I2C LCD detected at 0x27. Operating in serial-only display mode.");
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

    // Normal multi-screen cycling
    if (millis() - _lastCycleTime >= LCD_CYCLE_INTERVAL_MS) {
      _lastCycleTime = millis();
      _currentScreen = (_currentScreen + 1) % 2;
    }

    if (_currentScreen == 0) {
      // Screen 1: Temp & Humidity
      _lcd.setCursor(0, 0);
      _lcd.print("T:");
      _lcd.print(temp, 1);
      _lcd.print((char)223); // degree symbol
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
      // Screen 2: Gas Proxy & Status
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

#endif // LCD_DISPLAY_H
