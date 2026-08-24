import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/widgets/privacy_guard_overlay.dart';

void main() {
  testWidgets(
    'PrivacyGuardOverlay covers content when backgrounded and uncovers on resume',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyGuardOverlay(
            child: Text('sensitive medical content'),
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_outlined), findsNothing);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
    },
  );
}
