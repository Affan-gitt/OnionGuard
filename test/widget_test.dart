import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onionguard/app/app.dart';
import 'package:onionguard/app/providers.dart';
import 'package:onionguard/core/services/storage_service.dart';

void main() {
  testWidgets('OnionGuard smoke test - app launches and renders home dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const OnionGuardApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OnionGuard'), findsOneWidget);
    expect(find.text('1. Live Room Sensors'), findsOneWidget);
    expect(find.text('4. Onion Storage Shelves'), findsOneWidget);
  });
}
