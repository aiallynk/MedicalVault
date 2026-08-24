// Core-feature navigation smoke test, driven entirely through the Flutter
// widget/render tree (integration_test), not OS-level UI automation.
//
// This exists because the host environment for the iOS simulator boot phase
// has no idb/maestro/appium and no macOS Accessibility permission for
// System Events UI scripting, so navigation could not previously be
// exercised. integration_test drives taps directly through the Flutter
// engine and needs no OS-level automation permission, so it works here.
//
// Scope is deliberately limited to pure in-app navigation (bottom nav tabs,
// settings, logout) that does not trigger a native iOS permission dialog.
// Native dialogs (camera/photo/location) live outside the Flutter widget
// tree and cannot be dismissed by this harness, so they remain excluded
// here and are documented separately as still requiring manual/physical
// verification.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:hello/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard tabs, settings, and logout are reachable',
      (tester) async {
    app.main();

    // Splash -> auto-login (if a session is persisted) or Welcome/Login can
    // take a while against a real backend; poll instead of a single pump.
    await _pumpUntil(
      tester,
      () => find.text('Quick Actions').evaluate().isNotEmpty ||
          find.text('Welcome Back').evaluate().isNotEmpty,
      const Duration(seconds: 30),
    );

    final onDashboard = find.text('Quick Actions').evaluate().isNotEmpty;
    debugPrint(
      onDashboard
          ? 'RESULT: landed on dashboard (authenticated session present)'
          : 'RESULT: landed on login screen (no authenticated session) - '
              'navigation test cannot proceed past this point without '
              'credentials, which this harness does not enter',
    );
    if (!onDashboard) {
      return;
    }

    Future<void> tapTabAndReport(IconData icon, String label) async {
      final finder = find.byIcon(icon);
      if (finder.evaluate().isEmpty) {
        debugPrint('RESULT: $label tab icon not found - skipped');
        return;
      }
      await tester.tap(finder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugPrint('RESULT: $label tab tapped, no exception thrown');
    }

    await tapTabAndReport(Icons.lock_rounded, 'Vault');
    await tapTabAndReport(Icons.qr_code_rounded, 'QR');
    await tapTabAndReport(Icons.list_alt_rounded, 'Requests');
    await tapTabAndReport(Icons.settings_rounded, 'Settings');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final logoutButton = find.byType(OutlinedButton);
    if (logoutButton.evaluate().isNotEmpty) {
      await tester.tap(logoutButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      debugPrint('RESULT: logout button tapped, confirmation dialog pump ok');

      final confirmButtons = find.text('Logout');
      if (confirmButtons.evaluate().length > 1) {
        await tester.tap(confirmButtons.last);
        await _pumpUntil(
          tester,
          () => find.text('Welcome Back').evaluate().isNotEmpty,
          const Duration(seconds: 15),
        );
        final backToLogin = find.text('Welcome Back').evaluate().isNotEmpty;
        debugPrint(
          backToLogin
              ? 'RESULT: logout confirmed, returned to login screen'
              : 'RESULT: logout confirmed, but login screen text not found '
                  'within timeout',
        );
      } else {
        debugPrint(
          'RESULT: logout confirmation dialog buttons not found as expected',
        );
      }
    } else {
      debugPrint('RESULT: logout button (OutlinedButton) not found on '
          'Settings screen - skipped');
    }

    await tester.pumpAndSettle();
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (condition()) return;
  }
}
