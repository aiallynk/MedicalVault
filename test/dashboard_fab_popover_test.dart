import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/widgets/dashboard_fab_popover.dart';

void main() {
  Widget buildPopover({
    required VoidCallback onAiAssistant,
    required VoidCallback onNearbyHealthcare,
    required VoidCallback onProducts,
    required VoidCallback onAppointments,
    required VoidCallback onFamilyCare,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            DashboardFabPopover(
              isOpen: true,
              animation: const AlwaysStoppedAnimation<double>(1),
              onAiAssistant: onAiAssistant,
              onNearbyHealthcare: onNearbyHealthcare,
              onProducts: onProducts,
              onAppointments: onAppointments,
              onFamilyCare: onFamilyCare,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('renders the five compact action rows and reuses callbacks',
      (tester) async {
    var aiTaps = 0;
    var nearbyTaps = 0;
    var productTaps = 0;
    var appointmentTaps = 0;
    var familyCareTaps = 0;

    await tester.pumpWidget(buildPopover(
      onAiAssistant: () => aiTaps += 1,
      onNearbyHealthcare: () => nearbyTaps += 1,
      onProducts: () => productTaps += 1,
      onAppointments: () => appointmentTaps += 1,
      onFamilyCare: () => familyCareTaps += 1,
    ));

    for (final label in const [
      'AI Assistant',
      'Nearby Healthcare',
      'Products',
      'Appointments',
      'Family Care',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Quick Actions'), findsNothing);

    await tester.tap(find.text('AI Assistant'));
    await tester.tap(find.text('Nearby Healthcare'));
    await tester.tap(find.text('Products'));
    await tester.tap(find.text('Appointments'));
    await tester.tap(find.text('Family Care'));

    expect(aiTaps, 1);
    expect(nearbyTaps, 1);
    expect(productTaps, 1);
    expect(appointmentTaps, 1);
    expect(familyCareTaps, 1);
  });
}
