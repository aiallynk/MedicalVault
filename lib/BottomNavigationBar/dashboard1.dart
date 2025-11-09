import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello/api_service.dart';
import 'package:hello/AppFooter.dart';
import 'package:hello/CategoryVaultPage.dart';
import 'MyVault.dart';
import 'QR.dart';
import 'Requests.dart';
import 'Settings.dart';
import 'package:hello/ProfileSwitcherModal.dart';
import 'package:hello/main.dart';
import '../widgets/ai_floating_button.dart';
import 'package:hello/screens/sos_page.dart';
import 'package:hello/Notifications/global_notification_handler.dart';
import 'package:hello/localization/app_localizations.dart';
import '../features/lost_found/report_lost_page.dart';
import '../features/lost_found/report_found_page.dart';
import '../features/lost_found/my_lost_reports_page.dart';

class Dashboard1 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Dashboard1({super.key, required this.userData});

  @override
  State<Dashboard1> createState() => _Dashboard1State();
}

class _Dashboard1State extends State<Dashboard1> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late PageController _promoPageController;
  Timer? _promoTimer;
  late int _promoInitialPage;
  late AnimationController _alertController;

  Map<String, int> _documentCounts = {};
  bool _isLoadingCounts = true;
  List<Map<String, dynamic>> _linkedProfiles = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _promoInitialPage = _promoItems.length * 1000;
    _promoPageController = PageController(
      initialPage: _promoInitialPage,
      viewportFraction: 0.9,
    );
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _loadDocumentCounts();
    _loadLinkedProfiles();

    // Set status bar style and global context for notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusBarHelper.setStatusBarStyle(context);
      // Update global context for notifications
      GlobalNotificationHandler.setGlobalContext(context);
    });

    // Auto-scroll promo cards
    _promoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_promoPageController.hasClients) return;
      final int current =
          _promoPageController.page?.round() ?? _promoInitialPage;
      final int next = current + 1;
      try {
        _promoPageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        // Ignore transient errors if page view not ready
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _promoTimer?.cancel();
    _promoPageController.dispose();
    _alertController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedProfiles() async {
    try {
      final profiles = await ApiService.getLinkedProfiles();
      setState(() {
        _linkedProfiles = profiles;
      });
    } catch (e) {
      print("Error loading linked profiles: $e");
    }
  }

  Future<void> _loadDocumentCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId") ?? "";

      if (userId.isNotEmpty) {
        final grouped = await ApiService.fetchGroupedDocs(userId);

        if (grouped != null) {
          final counts = grouped["counts"] as Map<String, dynamic>;

          setState(() {
            _documentCounts = {
              "Reports": counts["reports"] ?? 0,
              "Prescription": counts["prescriptions"] ?? 0,
              "Bill": counts["bills"] ?? 0,
              "Insurance": counts["insurance"] ?? 0,
            };
            _isLoadingCounts = false;
          });
        }
      }
    } catch (e) {
      print("Error loading document counts: $e");
      setState(() {
        _isLoadingCounts = false;
      });
    }
  }

  Future<String?> _getStoredName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("name");
  }

  final List<Map<String, String>> _promoItems = const [
    {
      'titleKey': 'dashboard.promo.stayHydratedTitle',
      'subtitleKey': 'dashboard.promo.stayHydratedSubtitle',
    },
    {
      'titleKey': 'dashboard.promo.secureBackupTitle',
      'subtitleKey': 'dashboard.promo.secureBackupSubtitle',
    },
    {
      'titleKey': 'dashboard.promo.newFeatureTitle',
      'subtitleKey': 'dashboard.promo.newFeatureSubtitle',
    },
  ];

  Widget _buildPromoCarousel(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 120,
      child: PageView.builder(
        controller: _promoPageController,
        // infinite carousel, so no need to track index here
        itemBuilder: (context, index) {
          final item = _promoItems[index % _promoItems.length];
          final title = item['titleKey'] != null
              ? l10n.t(item['titleKey']!)
              : '';
          final subtitle = item['subtitleKey'] != null
              ? l10n.t(item['subtitleKey']!)
              : '';
          return AnimatedBuilder(
            animation: _promoPageController,
            builder: (context, child) {
              double value = 1.0;
              if (_promoPageController.position.haveDimensions) {
                final currentPage = _promoPageController.page ??
                    _promoPageController.initialPage.toDouble();
                value = (currentPage - index.toDouble());
                value = ((1 - (value.abs() * 0.1)).clamp(0.9, 1.0)).toDouble();
              }
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2E2E2E), const Color(0xFF1E1E1E)]
                        : [const Color(0xFFEEF6FF), const Color(0xFFE3F2FD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.blue.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      Icons.campaign,
                      color: isDark ? Colors.lightBlueAccent : Colors.blue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure status bar is configured
    StatusBarHelper.setStatusBarStyle(context);

    final l10n = context.l10n;
    final passedName = (widget.userData['name'] ?? "").toString();

    return FutureBuilder<String?>(
      future: _getStoredName(),
      builder: (context, snapshot) {
        final defaultName = l10n.auto('Patient');
        final userName = passedName.isNotEmpty
            ? passedName
            : (snapshot.data ?? defaultName);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            // Show confirmation dialog when back button is pressed on dashboard
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.t('dashboard.exitDialog.title')),
                content: Text(l10n.t('dashboard.exitDialog.message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.auto('Cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.t('dashboard.exitDialog.confirm')),
                  ),
                ],
              ),
            );
            if (shouldExit ?? false) {
              Navigator.of(context).pop();
            }
          },
          child: SafeArea(
            child: Scaffold(
              body: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: [
                      // 🏠 Dashboard tab
                      RefreshIndicator(
                        onRefresh: _loadDocumentCounts,
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 20.0),
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _showProfileSwitcher(context),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    child: widget.userData['profilePicture'] !=
                                            null
                                        ? ClipOval(
                                            child: Image.network(
                                              widget.userData['profilePicture'],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 20,
                                                );
                                              },
                                            ),
                                          )
                                        : Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.format('dashboard.greeting',
                                            {'name': userName}),
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (_linkedProfiles.isNotEmpty)
                                        Text(
                                          l10n.format(
                                              'dashboard.profileCount', {
                                            'count':
                                                '${_linkedProfiles.length + 1}'
                                          }),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showProfileSwitcher(context),
                                  icon: Icon(
                                    Icons.swap_horiz,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                  tooltip: l10n.t('dashboard.switchProfileTooltip'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildAlertTicker(context),
                            const SizedBox(height: 16),
                            // Sliding promo/notification cards
                            _buildPromoCarousel(context),
                            const SizedBox(height: 20),
                            Text(
                              l10n.t('dashboard.quickActions'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionCard(
                                    context,
                                    icon: Icons.qr_code,
                                    title: l10n
                                        .t('dashboard.action.generateShareQR'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => QRPage()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionCard(
                                    context,
                                    icon: Icons.person_add_alt_1,
                                    title: l10n
                                        .t('dashboard.action.accessRequests'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                RequestsPage()),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionCard(
                                    context,
                                    icon: Icons.emergency,
                                    title:
                                        l10n.t('dashboard.action.emergencySOS'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SosPage(
                                            userData: widget.userData,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionCard(
                                    context,
                                    icon: Icons.report,
                                    title: l10n.t(
                                        'dashboard.action.reportLostPerson'),
                                    onTap: () async {
                                      await _openReportLost(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionCard(
                                    context,
                                    icon: Icons.handshake,
                                    title: l10n.t(
                                        'dashboard.action.reportFoundPerson'),
                                    onTap: () async {
                                      await _openReportFound(context);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionCard(
                                    context,
                                    icon: Icons.list,
                                    title: l10n
                                        .t('dashboard.action.myLostReports'),
                                    onTap: () async {
                                      await _openMyLostReports(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.t('dashboard.documentsTitle'),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                if (!_isLoadingCounts)
                                  Text(
                                    l10n.format('dashboard.documentsTotal', {
                                      'count':
                                          '${_documentCounts.values.fold(0, (sum, count) => sum + count)}'
                                    }),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 4,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final categories = [
                                    {
                                      "title":
                                          l10n.t('documents.category.reports'),
                                      "image": "assets/Reports.png",
                                      "category": "Reports",
                                      "count": _documentCounts["Reports"] ?? 0
                                    },
                                    {
                                      "title": l10n
                                          .t('documents.category.prescriptions'),
                                      "image": "assets/Prescription.png",
                                      "category": "Prescription",
                                      "count":
                                          _documentCounts["Prescription"] ?? 0
                                    },
                                    {
                                      "title": l10n
                                          .t('documents.category.bills'),
                                      "image": "assets/2851468.png",
                                      "category": "Bill",
                                      "count": _documentCounts["Bill"] ?? 0
                                    },
                                    {
                                      "title": l10n
                                          .t('documents.category.insurance'),
                                      "image": "assets/Insurance12.png",
                                      "category": "Insurance",
                                      "count": _documentCounts["Insurance"] ?? 0
                                    },
                                  ];

                                  final item = categories[index];
                                  return _buildCategoryCard(
                                    context,
                                    title: item["title"] as String,
                                    imagePath: item["image"] as String,
                                    category: item["category"] as String,
                                    count: item["count"] as int,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),

                      // 🔐 Vault tab
                      MyVault(
                        userId: (widget.userData["id"] ?? "").toString(),
                      ),

                      QRPage(),
                      RequestsPage(),
                      SettingsPage(userData: widget.userData),
                    ],
                  ),
                  // Fixed AI Assistant button above footer
                  Positioned(
                    right: -2,
                    bottom: kBottomNavigationBarHeight - 50,
                    child: const AIFloatingButton(),
                  ),
                ],
              ),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: kBottomNavigationBarHeight,
                    child: Stack(
                      children: [
                        // Bottom Navigation Bar
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: BottomNavigationBar(
                            type: BottomNavigationBarType.fixed,
                            currentIndex: _currentIndex,
                            onTap: (index) {
                              setState(() {
                                _currentIndex = index;
                              });
                              _pageController.animateToPage(index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            },
                            items: [
                              BottomNavigationBarItem(
                                  icon: const Icon(Icons.home),
                                  label: l10n.t('dashboard.nav.home')),
                              BottomNavigationBarItem(
                                  icon: const Icon(Icons.lock),
                                  label: l10n.t('dashboard.nav.vault')),
                              BottomNavigationBarItem(
                                  icon: const Icon(Icons.qr_code),
                                  label: l10n.t('dashboard.nav.qr')),
                              BottomNavigationBarItem(
                                  icon: const Icon(Icons.list_alt),
                                  label: l10n.t('dashboard.nav.requests')),
                              BottomNavigationBarItem(
                                  icon: const Icon(Icons.settings),
                                  label: l10n.t('dashboard.nav.settings')),
                            ],
                            selectedItemColor: Theme.of(context)
                                .bottomNavigationBarTheme
                                .selectedItemColor,
                            unselectedItemColor: Theme.of(context)
                                .bottomNavigationBarTheme
                                .unselectedItemColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(BuildContext context,
      {required String title,
      required String imagePath,
      required String category,
      required int count}) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryVaultPage(
              category: category,
              userId: (widget.userData["id"] ?? "").toString(),
            ),
          ),
        );
        _loadDocumentCounts();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 80,
              width: double.infinity,
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count ${count == 1 ? l10n.t('dashboard.documentSingular') : l10n.t('dashboard.documentPlural')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.white12 : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileSwitcherModal(
        currentUser: widget.userData,
        linkedProfiles: _linkedProfiles,
      ),
    ).then((_) {
      // Refresh profiles when modal is closed
      _loadLinkedProfiles();
    });
  }

  Future<void> _openReportLost(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportLostPage(
          currentUser: Map<String, dynamic>.from(widget.userData),
          linkedProfiles: _linkedProfiles,
        ),
      ),
    );
  }

  Future<void> _openReportFound(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportFoundPage(),
      ),
    );
  }

  Future<void> _openMyLostReports(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyLostReportsPage(),
      ),
    );
  }

  List<String> _localizedAlertHeadlines(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.t('dashboard.alert.massSOS'),
      l10n.t('dashboard.alert.waterQuality'),
      l10n.t('dashboard.alert.unusualActivity'),
    ];
  }

  Widget _buildAlertTicker(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final alerts = _localizedAlertHeadlines(context);
    final alertText = alerts.join('   •   ');
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF7A0C0C),
        ) ??
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF7A0C0C),
        );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A1B1B) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.redAccent.withOpacity(0.25)
              : Colors.redAccent.withOpacity(0.4),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withOpacity(0.18),
            ),
            child: Icon(
              Icons.campaign_outlined,
              color: isDark ? Colors.orangeAccent : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final painter = TextPainter(
                    text: TextSpan(text: alertText, style: textStyle),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                  )..layout();

                  final contentWidth =
                      painter.width <= 0 ? constraints.maxWidth : painter.width;
                  final tickerWidth = contentWidth < constraints.maxWidth
                      ? constraints.maxWidth + 48
                      : contentWidth + 48;

                  return ClipRect(
                    child: AnimatedBuilder(
                      animation: _alertController,
                      builder: (context, child) {
                        final offset =
                            (_alertController.value * tickerWidth) % tickerWidth;
                        return Transform.translate(
                          offset: Offset(-offset, 0),
                          child: child,
                        );
                      },
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: tickerWidth * 2,
                          child: Row(
                            children: [
                              SizedBox(
                                width: tickerWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    alertText,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    style: textStyle,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: tickerWidth,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    alertText,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    style: textStyle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
