import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/core/responsive/responsive.dart';
import 'package:hello/widgets/custom_bottom_nav_bar.dart';
import 'package:hello/widgets/dashboard_fab_popover.dart';

/// Representative viewport sizes named in the responsive-audit requirements:
/// small/standard/large phones, foldables, tablets, and a landscape case.
const _viewports = <String, Size>{
  '320x568 (small phone)': Size(320, 568),
  '360x640 (standard phone)': Size(360, 640),
  '375x812 (iPhone-class)': Size(375, 812),
  '390x844 (iPhone-class)': Size(390, 844),
  '412x915 (large Android)': Size(412, 915),
  '430x932 (Pro Max-class)': Size(430, 932),
  '600x960 (small tablet / foldable unfolded)': Size(600, 960),
  '768x1024 (tablet portrait)': Size(768, 1024),
  '800x1280 (tablet portrait, large)': Size(800, 1280),
  '915x412 (landscape phone)': Size(915, 412),
  '1024x768 (landscape tablet)': Size(1024, 768),
};

void main() {
  group('AppBreakpoints.classify', () {
    test('classifies compact/medium/expanded per Material window-size guidance', () {
      expect(AppBreakpoints.classify(320), WindowSizeClass.compact);
      expect(AppBreakpoints.classify(599), WindowSizeClass.compact);
      expect(AppBreakpoints.classify(600), WindowSizeClass.medium);
      expect(AppBreakpoints.classify(839), WindowSizeClass.medium);
      expect(AppBreakpoints.classify(840), WindowSizeClass.expanded);
      expect(AppBreakpoints.classify(1200), WindowSizeClass.expanded);
    });
  });

  group('AppWindowSize', () {
    testWidgets('resolves size class and orientation from MediaQuery', (tester) async {
      late AppWindowSize resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Builder(
            builder: (context) {
              resolved = AppWindowSize.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.isCompact, isTrue);
      expect(resolved.isPortrait, isTrue);
    });

    testWidgets('classifies a tablet-width MediaQuery as at-least-medium', (tester) async {
      late AppWindowSize resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(900, 700)),
          child: Builder(
            builder: (context) {
              resolved = AppWindowSize.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.isAtLeastMedium, isTrue);
      expect(resolved.isExpanded, isTrue);
      expect(resolved.isLandscape, isTrue);
    });
  });

  group('responsiveValue', () {
    testWidgets('falls back to compact/medium when a wider variant is omitted', (tester) async {
      String? resolvedCompact;
      String? resolvedExpandedFallsBackToMedium;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(320, 640)),
          child: Builder(
            builder: (context) {
              resolvedCompact = responsiveValue(context, compact: 'a', medium: 'b');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolvedCompact, 'a');

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1000, 800)),
          child: Builder(
            builder: (context) {
              resolvedExpandedFallsBackToMedium =
                  responsiveValue(context, compact: 'a', medium: 'b');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolvedExpandedFallsBackToMedium, 'b');
    });
  });

  group('ResponsivePageBody + ResponsiveContentBounds', () {
    for (final entry in _viewports.entries) {
      testWidgets('renders without overflow at ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsivePageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'A' * 400, // pathological long content, must wrap not overflow
                    ),
                    const ResponsiveSection(
                      child: Text('Section content'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('clamps content to maxPageWidth on very wide screens', (tester) async {
      tester.view.physicalSize = const Size(2000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsivePageBody(
              child: Container(key: const Key('content'), height: 40),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderBox =
          tester.renderObject(find.byKey(const Key('content'))) as RenderBox;
      expect(renderBox.size.width, lessThanOrEqualTo(AppResponsive.maxPageWidth));
    });
  });

  group('CustomBottomNavBar at representative viewport sizes', () {
    for (final entry in _viewports.entries) {
      // Landscape phones have very little height; the bar itself only
      // depends on width, so this still exercises the width-driven layout
      // algorithm without asserting on unrelated vertical space.
      testWidgets('lays out 5 items without overflow at ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: CustomBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                reduceMotion: true,
                items: const [
                  BottomNavItemData(icon: Icons.home, label: 'Home'),
                  BottomNavItemData(icon: Icons.folder, label: 'Vault'),
                  BottomNavItemData(icon: Icons.qr_code, label: 'QR'),
                  BottomNavItemData(icon: Icons.inbox, label: 'Requests'),
                  BottomNavItemData(icon: Icons.settings, label: 'Settings'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Home'), findsOneWidget);
      });
    }
  });

  group('DashboardFabPopover at representative viewport sizes', () {
    for (final entry in _viewports.entries) {
      testWidgets('renders its action list without overflow at ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DashboardFabPopover(
                    isOpen: true,
                    animation: const AlwaysStoppedAnimation<double>(1),
                    onMessages: () {},
                    onAiAssistant: () {},
                    onNearbyHealthcare: () {},
                    onProducts: () {},
                    onAppointments: () {},
                    onFamilyCare: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Large text scale (accessibility)', () {
    testWidgets('CustomBottomNavBar survives 2.0x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              reduceMotion: true,
              items: const [
                BottomNavItemData(icon: Icons.home, label: 'Home'),
                BottomNavItemData(icon: Icons.folder, label: 'Vault'),
                BottomNavItemData(icon: Icons.qr_code, label: 'QR'),
                BottomNavItemData(icon: Icons.inbox, label: 'Requests'),
                BottomNavItemData(icon: Icons.settings, label: 'Settings'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ResponsivePageBody survives 3.0x text scale (max accessibility) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(3.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ResponsivePageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Regular label text that must wrap safely'),
                  Row(
                    children: [
                      const Icon(Icons.info),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'A long inline label demonstrating Flexible-wrapped '
                          'text at maximum accessibility text scale',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
