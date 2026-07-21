import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/widgets/dashboard_fab_popover.dart';

void main() {
  Widget buildPopover({
    required VoidCallback onMessages,
    required VoidCallback onAiAssistant,
    required VoidCallback onNearbyHealthcare,
    required VoidCallback onProducts,
    required VoidCallback onAppointments,
    required VoidCallback onFamilyCare,
    int unreadMessageCount = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            DashboardFabPopover(
              isOpen: true,
              animation: const AlwaysStoppedAnimation<double>(1),
              onMessages: onMessages,
              onAiAssistant: onAiAssistant,
              onNearbyHealthcare: onNearbyHealthcare,
              onProducts: onProducts,
              onAppointments: onAppointments,
              onFamilyCare: onFamilyCare,
              unreadMessageCount: unreadMessageCount,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('renders the six compact action rows and reuses callbacks',
      (tester) async {
    var messagesTaps = 0;
    var aiTaps = 0;
    var nearbyTaps = 0;
    var productTaps = 0;
    var appointmentTaps = 0;
    var familyCareTaps = 0;

    await tester.pumpWidget(buildPopover(
      onMessages: () => messagesTaps += 1,
      onAiAssistant: () => aiTaps += 1,
      onNearbyHealthcare: () => nearbyTaps += 1,
      onProducts: () => productTaps += 1,
      onAppointments: () => appointmentTaps += 1,
      onFamilyCare: () => familyCareTaps += 1,
    ));

    for (final label in const [
      'Messages',
      'AI Assistant',
      'Nearby Healthcare',
      'Products',
      'Appointments',
      'Family Care',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Quick Actions'), findsNothing);

    await tester.tap(find.text('Messages'));
    await tester.tap(find.text('AI Assistant'));
    await tester.tap(find.text('Nearby Healthcare'));
    await tester.tap(find.text('Products'));
    await tester.tap(find.text('Appointments'));
    await tester.tap(find.text('Family Care'));

    expect(messagesTaps, 1);
    expect(aiTaps, 1);
    expect(nearbyTaps, 1);
    expect(productTaps, 1);
    expect(appointmentTaps, 1);
    expect(familyCareTaps, 1);
  });

  testWidgets('shows an unread badge on Messages when unreadMessageCount > 0',
      (tester) async {
    await tester.pumpWidget(buildPopover(
      onMessages: () {},
      onAiAssistant: () {},
      onNearbyHealthcare: () {},
      onProducts: () {},
      onAppointments: () {},
      onFamilyCare: () {},
      unreadMessageCount: 7,
    ));

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('caps the unread badge at 99+', (tester) async {
    await tester.pumpWidget(buildPopover(
      onMessages: () {},
      onAiAssistant: () {},
      onNearbyHealthcare: () {},
      onProducts: () {},
      onAppointments: () {},
      onFamilyCare: () {},
      unreadMessageCount: 150,
    ));

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('shows no badge when unreadMessageCount is 0', (tester) async {
    await tester.pumpWidget(buildPopover(
      onMessages: () {},
      onAiAssistant: () {},
      onNearbyHealthcare: () {},
      onProducts: () {},
      onAppointments: () {},
      onFamilyCare: () {},
    ));

    expect(find.text('0'), findsNothing);
  });
}
