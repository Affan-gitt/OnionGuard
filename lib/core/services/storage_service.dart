import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/onion_item.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/activity_event.dart';
import '../../data/models/hygiene_entry.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/actuator_state.dart';
import '../../data/models/sms_alert_queue_item.dart';

class StorageService {
  static const String _keyOnions = 'onionguard_onions_v1';
  static const String _keyEvents = 'onionguard_events_v1';
  static const String _keyReadings = 'onionguard_readings_v1';
  static const String _keyHygiene = 'onionguard_hygiene_v1';
  static const String _keySettings = 'onionguard_settings_v1';
  static const String _keyActuator = 'onionguard_actuator_v1';
  static const String _keySmsQueue = 'onionguard_sms_queue_v1';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._seedInitialDataIfEmpty();
    return service;
  }

  Future<void> _seedInitialDataIfEmpty() async {
    if (!_prefs.containsKey(_keyOnions)) {
      final now = DateTime.now();
      final demoOnions = [
        // Rack A - Shelf 1
        OnionItem(
          id: 'ONG-A1-01',
          rack: 'Rack A',
          shelf: 1,
          spot: 1,
          variety: 'Yellow Granex',
          dateAdded: now.subtract(const Duration(days: 14)),
          lastInspection: now.subtract(const Duration(hours: 18)),
          condition: OnionCondition.healthy,
          weightGrams: 145.2,
          inspectionNotes: 'Firm outer dry scale, zero neck softening observed.',
          isDemo: true,
          conditionHistory: [
            ConditionLog(timestamp: now.subtract(const Duration(days: 14)), condition: OnionCondition.healthy, note: 'Harvest intake inspection passed.'),
          ],
        ),
        OnionItem(
          id: 'ONG-A1-02',
          rack: 'Rack A',
          shelf: 1,
          spot: 2,
          variety: 'Yellow Granex',
          dateAdded: now.subtract(const Duration(days: 14)),
          lastInspection: now.subtract(const Duration(hours: 18)),
          condition: OnionCondition.healthy,
          weightGrams: 152.0,
          inspectionNotes: 'Solid bulb, dry cured neck, good dormancy.',
          isDemo: true,
          conditionHistory: [
            ConditionLog(timestamp: now.subtract(const Duration(days: 14)), condition: OnionCondition.healthy, note: 'Intake batch A.'),
          ],
        ),
        OnionItem(
          id: 'ONG-A1-03',
          rack: 'Rack A',
          shelf: 1,
          spot: 3,
          variety: 'Red Creole',
          dateAdded: now.subtract(const Duration(days: 12)),
          lastInspection: now.subtract(const Duration(hours: 4)),
          condition: OnionCondition.softening,
          weightGrams: 138.5,
          inspectionNotes: 'Slight give around upper shoulder neck tissue. Recommended re-inspection in 24h.',
          isDemo: true,
          conditionHistory: [
            ConditionLog(timestamp: now.subtract(const Duration(days: 12)), condition: OnionCondition.healthy, note: 'Stored in Shelf 1.'),
            ConditionLog(timestamp: now.subtract(const Duration(hours: 4)), condition: OnionCondition.softening, note: 'Early softening detected near stem collar.'),
          ],
        ),
        OnionItem(
          id: 'ONG-A1-04',
          rack: 'Rack A',
          shelf: 1,
          spot: 4,
          variety: 'Red Creole',
          dateAdded: now.subtract(const Duration(days: 12)),
          lastInspection: now.subtract(const Duration(hours: 22)),
          condition: OnionCondition.healthy,
          weightGrams: 160.1,
          inspectionNotes: 'Deep red pigmentation, skin intact, excellent condition.',
          isDemo: true,
        ),

        // Rack A - Shelf 2
        OnionItem(
          id: 'ONG-A2-01',
          rack: 'Rack A',
          shelf: 2,
          spot: 1,
          variety: 'White Sweet Spanish',
          dateAdded: now.subtract(const Duration(days: 10)),
          lastInspection: now.subtract(const Duration(hours: 6)),
          condition: OnionCondition.suspectedDeterioration,
          weightGrams: 142.3,
          inspectionNotes: 'Pungent aroma proximity, minor translucency on lower scales. High spoilage risk.',
          isDemo: true,
          conditionHistory: [
            ConditionLog(timestamp: now.subtract(const Duration(days: 10)), condition: OnionCondition.healthy, note: 'Intake inspection.'),
            ConditionLog(timestamp: now.subtract(const Duration(hours: 6)), condition: OnionCondition.suspectedDeterioration, note: 'Translucency observed.'),
          ],
        ),
        OnionItem(
          id: 'ONG-A2-02',
          rack: 'Rack A',
          shelf: 2,
          spot: 2,
          variety: 'White Sweet Spanish',
          dateAdded: now.subtract(const Duration(days: 10)),
          lastInspection: now.subtract(const Duration(hours: 2)),
          condition: OnionCondition.visibleRot,
          weightGrams: 130.4,
          inspectionNotes: 'Bacterial soft rot evident at basal plate. Quarantine and disposal recommended.',
          isDemo: true,
          conditionHistory: [
            ConditionLog(timestamp: now.subtract(const Duration(days: 10)), condition: OnionCondition.healthy, note: 'Intake batch B.'),
            ConditionLog(timestamp: now.subtract(const Duration(hours: 2)), condition: OnionCondition.visibleRot, note: 'Soft decay observed on basal roots.'),
          ],
        ),
        OnionItem(
          id: 'ONG-A2-03',
          rack: 'Rack A',
          shelf: 2,
          spot: 3,
          variety: 'Yellow Granex',
          dateAdded: now.subtract(const Duration(days: 9)),
          lastInspection: now.subtract(const Duration(hours: 20)),
          condition: OnionCondition.healthy,
          weightGrams: 155.8,
          inspectionNotes: 'Dry golden tunic, well cured.',
          isDemo: true,
        ),
        OnionItem(
          id: 'ONG-A2-04',
          rack: 'Rack A',
          shelf: 2,
          spot: 4,
          variety: 'Yellow Granex',
          dateAdded: now.subtract(const Duration(days: 9)),
          lastInspection: now.subtract(const Duration(hours: 1)),
          condition: OnionCondition.mouldObserved,
          weightGrams: 125.0,
          inspectionNotes: 'Black Aspergillus mould spores on outer sheath. Segregated to prevent spore dispersion.',
          isDemo: true,
          conditionHistory: [
            ConditionLog(timestamp: now.subtract(const Duration(days: 9)), condition: OnionCondition.healthy, note: 'Intake pass.'),
            ConditionLog(timestamp: now.subtract(const Duration(hours: 1)), condition: OnionCondition.mouldObserved, note: 'Black mould colonization detected on dry skin.'),
          ],
        ),

        // Rack B - Shelf 1
        OnionItem(
          id: 'ONG-B1-01',
          rack: 'Rack B',
          shelf: 1,
          spot: 1,
          variety: 'Red Creole',
          dateAdded: now.subtract(const Duration(days: 7)),
          lastInspection: now.subtract(const Duration(hours: 12)),
          condition: OnionCondition.healthy,
          weightGrams: 149.0,
          inspectionNotes: 'Clean, solid bulb.',
          isDemo: true,
        ),
        OnionItem(
          id: 'ONG-B1-02',
          rack: 'Rack B',
          shelf: 1,
          spot: 2,
          variety: 'Red Creole',
          dateAdded: now.subtract(const Duration(days: 7)),
          lastInspection: now.subtract(const Duration(hours: 12)),
          condition: OnionCondition.healthy,
          weightGrams: 158.4,
          inspectionNotes: 'Normal firmness, no sprouting.',
          isDemo: true,
        ),
        OnionItem(
          id: 'ONG-B1-03',
          rack: 'Rack B',
          shelf: 1,
          spot: 3,
          variety: 'White Sweet Spanish',
          dateAdded: now.subtract(const Duration(days: 6)),
          lastInspection: now.subtract(const Duration(hours: 5)),
          condition: OnionCondition.damaged,
          weightGrams: 136.2,
          inspectionNotes: 'Superficial skin laceration from harvesting crate. No fungal infection yet.',
          isDemo: true,
        ),
        OnionItem(
          id: 'ONG-B1-04',
          rack: 'Rack B',
          shelf: 1,
          spot: 4,
          variety: 'White Sweet Spanish',
          dateAdded: now.subtract(const Duration(days: 5)),
          lastInspection: now.subtract(const Duration(days: 5)),
          condition: OnionCondition.notInspected,
          weightGrams: 144.0,
          inspectionNotes: 'Scheduled for detailed initial inspection.',
          isDemo: true,
        ),
      ];
      await saveOnions(demoOnions);
    }

    if (!_prefs.containsKey(_keyEvents)) {
      final now = DateTime.now();
      final demoEvents = [
        ActivityEvent(
          id: 'EVT-001',
          timestamp: now.subtract(const Duration(hours: 3)),
          category: EventCategory.system,
          severity: EventSeverity.info,
          title: 'System Boot & BLE Initialized',
          description: 'OnionGuard service started. ESP32-H2 DevKit 4 BLE GATT listener ready.',
          triggerSource: 'System Core',
        ),
        ActivityEvent(
          id: 'EVT-002',
          timestamp: now.subtract(const Duration(hours: 2, minutes: 15)),
          category: EventCategory.actuation,
          severity: EventSeverity.warning,
          title: 'Exhaust Fan Activated',
          description: 'Storage temperature crossed threshold (26.4°C > 26.0°C). Automated ventilation started.',
          triggerSource: 'Automatic Control',
          temperature: 26.4,
          humidity: 68.2,
          gasAdc: 890,
        ),
        ActivityEvent(
          id: 'EVT-003',
          timestamp: now.subtract(const Duration(hours: 1, minutes: 50)),
          category: EventCategory.actuation,
          severity: EventSeverity.info,
          title: 'Exhaust Fan Deactivated',
          description: 'Storage temperature fell below reset threshold (23.8°C < 24.0°C). Ventilation stopped.',
          triggerSource: 'Automatic Control',
          temperature: 23.8,
          humidity: 64.5,
          gasAdc: 865,
        ),
        ActivityEvent(
          id: 'EVT-004',
          timestamp: now.subtract(const Duration(hours: 1)),
          category: EventCategory.inventory,
          severity: EventSeverity.critical,
          title: 'Mould Observed on Shelf 2',
          description: 'Onion ONG-A2-04 identified with visible fungal spores. Condition updated to Mould Observed.',
          triggerSource: 'Manual Inspection',
        ),
      ];
      await saveEvents(demoEvents);
    }

    if (!_prefs.containsKey(_keySettings)) {
      await saveSettings(AppSettings());
    }

    if (!_prefs.containsKey(_keyActuator)) {
      await saveActuatorState(ActuatorState());
    }
  }

  // Onions
  List<OnionItem> getOnions() {
    final raw = _prefs.getString(_keyOnions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => OnionItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOnions(List<OnionItem> onions) async {
    final raw = jsonEncode(onions.map((o) => o.toJson()).toList());
    await _prefs.setString(_keyOnions, raw);
  }

  // Events
  List<ActivityEvent> getEvents() {
    final raw = _prefs.getString(_keyEvents);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEvents(List<ActivityEvent> events) async {
    // Keep last 300 events to prevent uncontrolled growth
    final capped = events.length > 300 ? events.sublist(0, 300) : events;
    final raw = jsonEncode(capped.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyEvents, raw);
  }

  Future<void> addEvent(ActivityEvent event) async {
    final current = getEvents();
    current.insert(0, event);
    await saveEvents(current);
  }

  // Sensor Readings (Recent buffer)
  List<SensorReading> getRecentReadings() {
    final raw = _prefs.getString(_keyReadings);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => SensorReading.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentReadings(List<SensorReading> readings) async {
    // Keep last 150 points for charts
    final capped = readings.length > 150 ? readings.sublist(readings.length - 150) : readings;
    final raw = jsonEncode(capped.map((r) => r.toJson()).toList());
    await _prefs.setString(_keyReadings, raw);
  }

  // Hygiene
  List<HygieneEntry> getHygieneEntries() {
    final raw = _prefs.getString(_keyHygiene);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => HygieneEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHygieneEntries(List<HygieneEntry> entries) async {
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyHygiene, raw);
  }

  // Settings
  AppSettings getSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  // Actuator State
  ActuatorState getActuatorState() {
    final raw = _prefs.getString(_keyActuator);
    if (raw == null) return ActuatorState();
    try {
      return ActuatorState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ActuatorState();
    }
  }

  Future<void> saveActuatorState(ActuatorState state) async {
    await _prefs.setString(_keyActuator, jsonEncode(state.toJson()));
  }

  // Persistent SMS Alert Queue (Phase 3)
  List<SmsAlertQueueItem> getSmsAlertQueue() {
    final raw = _prefs.getString(_keySmsQueue);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => SmsAlertQueueItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSmsAlertQueue(List<SmsAlertQueueItem> queue) async {
    // Keep last 100 alerts to manage storage while retaining persistent history
    final capped = queue.length > 100 ? queue.sublist(queue.length - 100) : queue;
    final raw = jsonEncode(capped.map((q) => q.toJson()).toList());
    await _prefs.setString(_keySmsQueue, raw);
  }

  Future<void> addSmsAlertQueueItem(SmsAlertQueueItem item) async {
    final queue = getSmsAlertQueue();
    queue.insert(0, item);
    await saveSmsAlertQueue(queue);
  }

  Future<void> updateSmsAlertQueueItem(SmsAlertQueueItem updatedItem) async {
    final queue = getSmsAlertQueue();
    final idx = queue.indexWhere((q) => q.id == updatedItem.id);
    if (idx != -1) {
      queue[idx] = updatedItem;
    } else {
      queue.insert(0, updatedItem);
    }
    await saveSmsAlertQueue(queue);
  }
}
