import '../../data/models/onion_item.dart';
import '../../data/models/activity_event.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/gas_test_session.dart';

class CsvExporter {
  static String exportOnionsToCsv(List<OnionItem> onions) {
    final buffer = StringBuffer();
    buffer.writeln('Onion ID,Rack,Shelf,Spot,Variety,Date Added,Last Inspection,Condition,Weight (g),Demo Data,Notes');
    for (final o in onions) {
      final safeNotes = o.inspectionNotes.replaceAll('"', '""');
      buffer.writeln(
        '"${o.id}","${o.rack}",${o.shelf},${o.spot},"${o.variety}","${o.dateAdded.toIso8601String()}","${o.lastInspection.toIso8601String()}","${o.condition.displayName}",${o.weightGrams ?? ""},${o.isDemo ? "YES" : "NO"},"$safeNotes"'
      );
    }
    return buffer.toString();
  }

  static String exportEventsToCsv(List<ActivityEvent> events) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Category,Severity,Title,Description,Source,Mode,Temperature (C),Humidity (%),Gas ADC');
    for (final e in events) {
      final safeTitle = e.title.replaceAll('"', '""');
      final safeDesc = e.description.replaceAll('"', '""');
      buffer.writeln(
        '"${e.timestamp.toIso8601String()}","${e.category.displayName}","${e.severity.displayName}","$safeTitle","$safeDesc","${e.triggerSource}","${e.operatingMode}",${e.temperature ?? ""},${e.humidity ?? ""},${e.gasAdc ?? ""}'
      );
    }
    return buffer.toString();
  }

  static String exportSensorReadingsToCsv(List<SensorReading> readings) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Temperature (C),Humidity (%),MQ-3 ADC,Baseline ADC,Delta (%),Fan State,Humidifier State,Status,Simulated');
    for (final r in readings) {
      buffer.writeln(
        '"${r.timestamp.toIso8601String()}",${r.temperature},${r.humidity},${r.mq3RawAdc},${r.mq3Baseline},${r.mq3DeltaPercent},${r.fanActive ? 1 : 0},${r.humidifierActive ? 1 : 0},"${r.sensorStatus}",${r.isSimulated ? 1 : 0}'
      );
    }
    return buffer.toString();
  }

  static String exportGasTestToCsv(GasTestSession session) {
    final buffer = StringBuffer();
    buffer.writeln('Second,MQ-3 ADC,Delta (%)');
    for (final p in session.samples) {
      buffer.writeln('${p.second},${p.adc},${p.deltaPercent}');
    }
    return buffer.toString();
  }
}
