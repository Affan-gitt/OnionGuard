import '../../core/services/storage_service.dart';
import '../../core/utilities/csv_exporter.dart';
import '../models/onion_item.dart';

class OnionRepository {
  final StorageService _storageService;

  OnionRepository(this._storageService);

  List<OnionItem> getAllOnions() {
    return _storageService.getOnions().where((o) => !o.isRemoved).toList();
  }

  OnionItem? getOnionById(String id) {
    try {
      return getAllOnions().firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  List<OnionItem> getOnionsByRackAndShelf(String rack, int shelf) {
    return getAllOnions().where((o) => o.rack == rack && o.shelf == shelf).toList();
  }

  Future<void> saveOnion(OnionItem onion) async {
    final all = _storageService.getOnions();
    final index = all.indexWhere((o) => o.id == onion.id);
    if (index >= 0) {
      all[index] = onion;
    } else {
      all.add(onion);
    }
    await _storageService.saveOnions(all);
  }

  Future<void> updateCondition({
    required String id,
    required OnionCondition newCondition,
    required String note,
    double? newWeight,
  }) async {
    final all = _storageService.getOnions();
    final index = all.indexWhere((o) => o.id == id);
    if (index >= 0) {
      final old = all[index];
      final history = List<ConditionLog>.from(old.conditionHistory);
      history.insert(
        0,
        ConditionLog(
          timestamp: DateTime.now(),
          condition: newCondition,
          note: note,
        ),
      );
      final updated = old.copyWith(
        condition: newCondition,
        lastInspection: DateTime.now(),
        weightGrams: newWeight ?? old.weightGrams,
        inspectionNotes: note.isNotEmpty ? note : old.inspectionNotes,
        conditionHistory: history,
      );
      all[index] = updated;
      await _storageService.saveOnions(all);
    }
  }

  Future<void> removeOnion(String id) async {
    final all = _storageService.getOnions();
    final index = all.indexWhere((o) => o.id == id);
    if (index >= 0) {
      all[index] = all[index].copyWith(isRemoved: true);
      await _storageService.saveOnions(all);
    }
  }

  Future<void> moveOnion({
    required String id,
    required String newRack,
    required int newShelf,
    required int newSpot,
  }) async {
    final all = _storageService.getOnions();
    final index = all.indexWhere((o) => o.id == id);
    if (index >= 0) {
      all[index] = all[index].copyWith(
        rack: newRack,
        shelf: newShelf,
        spot: newSpot,
      );
      await _storageService.saveOnions(all);
    }
  }

  String exportToCsv() {
    return CsvExporter.exportOnionsToCsv(getAllOnions());
  }
}
