import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hello/api_service.dart';
import 'package:hello/AppFooter.dart';
import 'package:hello/CategoryVaultPage.dart';
import 'package:hello/core/theme/theme.dart';
import 'MyVault.dart';
import 'QR.dart';
import 'Requests.dart';
import 'Settings.dart';
import 'package:hello/ProfileSwitcherModal.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/doctor_card.dart';
import 'package:hello/screens/appointments_page.dart';
import 'package:hello/screens/doctor_detail_screen.dart';
import 'package:hello/screens/chat_screen.dart';
import 'package:hello/screens/chat_threads_screen.dart';
import 'package:hello/screens/sos_page.dart';
import 'package:hello/screens/medical_store_page.dart';
import 'package:hello/screens/nearby_services_page.dart';
import 'package:hello/Notifications/global_notification_handler.dart';
import 'package:hello/SettingPages/ProfilePageSetting.dart';
import 'package:hello/localization/app_localizations.dart';
import '../features/lost_found/my_lost_reports_page.dart';
import '../features/lost_found/lost_found_report_page.dart';
import '../features/lost_found/search_lost_persons_page.dart';
import '../features/khoj/khoj_ai_page.dart';
import '../providers/dashboard_prefetch_provider.dart';
import '../providers/timezone_provider.dart';
import '../utils/timezone_utils.dart';
import '../widgets/ai_floating_button.dart';

class Dashboard1 extends StatefulWidget {
  final Map<String, dynamic> userData;
  final DashboardPrefetchData? prefetchedData;

  const Dashboard1({
    super.key,
    required this.userData,
    this.prefetchedData,
  });

  @override
  State<Dashboard1> createState() => _Dashboard1State();
}

class _Dashboard1State extends State<Dashboard1>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _promoPageSeed = 10000;
  int _currentIndex = 0;
  int _promoPageIndex = 0;
  final Set<int> _loadedTabs = {0};
  final Map<int, Uint8List?> _decodedDataUriBytes = {};
  late PageController _promoPageController;
  Timer? _promoTimer;
  Timer? _uiRefreshTimer;
  Timer? _alertExpiryTimer;
  Timer? _publicConfigReconnectTimer;
  StreamSubscription<dynamic>? _connectivitySubscription;
  late AnimationController _alertController;
  WebSocketChannel? _publicConfigChannel;
  StreamSubscription<dynamic>? _publicConfigSubscription;
  late Map<String, dynamic> _userData;
  String? _storedName;
  bool _wasConnected = true;

  Map<String, int> _documentCounts = {};
  bool _isLoadingCounts = true;
  List<Map<String, dynamic>> _linkedProfiles = [];
  List<Map<String, dynamic>> _topDoctors = [];
  bool _loadingTopDoctors = true;
  List<Map<String, dynamic>> _dashboardAds = [];
  List<Map<String, dynamic>> _dashboardCards = [];
  List<Map<String, dynamic>> _dashboardAlerts = [];
  bool _lowPerformanceMode = false;
  int _jankyFrameScore = 0;
  bool _hydratedFromPrefetch = false;
  bool _prefetchWasPartial = false;
  late final AnimationController _fabMenuController;
  bool _fabMenuOpen = false;

  String get _activeUserId =>
      (_userData['id']?.toString() ?? _userData['_id']?.toString() ?? '')
          .trim();

  bool get _reduceMotion =>
      _lowPerformanceMode ||
      WidgetsBinding
          .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  bool get _bottomNavReduceMotion => WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userData = Map<String, dynamic>.from(widget.userData);
    _promoPageController = PageController(
      initialPage: _promoPageSeed,
      viewportFraction: 0.9,
    );
    _fabMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _tryHydrateFromPrefetch();
    if (!_hydratedFromPrefetch) {
      _loadDocumentCounts();
      _loadLinkedProfiles();
      _loadTopDoctors();
      _loadDashboardAds();
      _loadDashboardUiConfig();
    } else {
      _isLoadingCounts = _documentCounts.isEmpty;
      _loadingTopDoctors = _topDoctors.isEmpty;
      // Refresh in background so cached/prefetched data quickly converges online.
      unawaited(_loadDocumentCounts());
      if (_prefetchWasPartial) {
        unawaited(_loadLinkedProfiles());
        unawaited(_loadTopDoctors(forceRefresh: true));
        unawaited(_loadDashboardAds(forceRefresh: true));
        unawaited(_loadDashboardUiConfig(forceRefresh: true));
      }
    }
    _loadStoredName();
    _startUiRefreshTimer();
    _startAlertExpiryTimer();
    _initializeConnectivityObserver();
    _connectPublicConfigSocket();
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    _syncTickerAnimation();

    // Set global context for notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Update global context for notifications
      GlobalNotificationHandler.setGlobalContext(context);
      _refreshUserData(forceRemote: true);
    });

    // Auto-scroll promo cards
    _promoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_promoPageController.hasClients) return;
      if (_reduceMotion) return;
      if (_dashboardAds.length <= 1) return;
      final int currentPage =
          _promoPageController.page?.round() ?? _promoPageSeed;
      final int next = currentPage + 1;
      try {
        _promoPageController
            .animateToPage(
              next,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            )
            .timeout(const Duration(seconds: 2), onTimeout: () {})
            .catchError((_) {});
      } catch (_) {
        // Ignore transient errors if page view not ready
      }
    });
  }

  void _tryHydrateFromPrefetch() {
    final explicit = widget.prefetchedData;
    final userId =
        (_userData['id']?.toString() ?? _userData['_id']?.toString() ?? '')
            .trim();

    final providerCached =
        context.read<DashboardPrefetchProvider>().takeCachedForUser(userId);
    final source = explicit ?? providerCached;
    if (source == null) return;
    _applyPrefetchedData(source);
  }

  void _applyPrefetchedData(DashboardPrefetchData data) {
    _hydratedFromPrefetch = true;
    _prefetchWasPartial = data.partial;
    _userData = Map<String, dynamic>.from(data.userData);
    _documentCounts = Map<String, int>.from(data.documentCounts);
    _linkedProfiles = data.linkedProfiles
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _topDoctors = data.topDoctors
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _dashboardAds = data.dashboardAds
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _dashboardCards = data.dashboardCards
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _dashboardAlerts = _activeDashboardAlerts(
      _nowInSelectedZone(),
      source: data.dashboardAlerts
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
    );

    _promoPageIndex = 0;
    if (_dashboardAds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_promoPageController.hasClients) return;
        _promoPageController.jumpToPage(_promoPageSeed);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    _promoTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _alertExpiryTimer?.cancel();
    _publicConfigReconnectTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _publicConfigSubscription?.cancel();
    _publicConfigSubscription = null;
    _publicConfigChannel?.sink.close();
    _publicConfigChannel = null;
    _promoPageController.dispose();
    _fabMenuController.dispose();
    AIAssistantOverlayController.setVisible(true);
    _alertController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshUserData(forceRemote: true));
      unawaited(_loadDocumentCounts());
    }
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!mounted || _lowPerformanceMode) return;
    var score = _jankyFrameScore;

    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMilliseconds;
      final rasterMs = timing.rasterDuration.inMilliseconds;
      final isJanky = buildMs > 18 || rasterMs > 24;
      if (isJanky) {
        score += 1;
      } else if (score > 0) {
        score -= 1;
      }

      if (score >= 6) {
        setState(() {
          _lowPerformanceMode = true;
          _jankyFrameScore = score;
        });
        _syncTickerAnimation();
        return;
      }
    }

    _jankyFrameScore = score;
  }

  Uint8List? _tryDecodeImageDataUri(String imageSource) {
    final source = imageSource.trim();
    if (!source.startsWith('data:image/')) return null;
    final commaIndex = source.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= source.length - 1) return null;
    final metadata = source.substring(0, commaIndex).toLowerCase();
    if (!metadata.contains(';base64')) return null;
    final base64Part = source.substring(commaIndex + 1).trim();
    if (base64Part.isEmpty) return null;
    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decodeImageDataUriCached(String imageSource) {
    final source = imageSource.trim();
    if (!source.startsWith('data:image/')) return null;
    // Very large inline payloads can block the UI thread during decode.
    if (source.length > 350000) return null;
    final cacheKey = source.hashCode;
    if (_decodedDataUriBytes.containsKey(cacheKey)) {
      return _decodedDataUriBytes[cacheKey];
    }
    final decoded = _tryDecodeImageDataUri(source);
    _decodedDataUriBytes[cacheKey] = decoded;
    return decoded;
  }

  Widget _buildRemoteOrEmbeddedImage({
    required String imageSource,
    required BoxFit fit,
    required Widget fallback,
    double? width,
    double? height,
  }) {
    final source = imageSource.trim();
    if (source.isEmpty) return fallback;
    final embeddedBytes = _decodeImageDataUriCached(source);
    if (embeddedBytes != null) {
      return Image.memory(
        embeddedBytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (source.startsWith('data:image/')) {
      return fallback;
    }
    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  void _syncTickerAnimation() {
    if (_reduceMotion) {
      if (_alertController.isAnimating) {
        _alertController.stop();
      }
      return;
    }
    if (!_alertController.isAnimating) {
      _alertController.repeat();
    }
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (!mounted) return;
      _loadDocumentCounts();
      _loadDashboardUiConfig(forceRefresh: true);
    });
  }

  void _startAlertExpiryTimer() {
    _alertExpiryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final now = _nowInSelectedZone();
      final active = _activeDashboardAlerts(now);
      if (active.length != _dashboardAlerts.length) {
        setState(() {
          _dashboardAlerts = active;
        });
      }
    });
  }

  Future<void> _connectPublicConfigSocket() async {
    _publicConfigReconnectTimer?.cancel();
    _publicConfigReconnectTimer = null;
    await _publicConfigSubscription?.cancel();
    _publicConfigSubscription = null;
    await _publicConfigChannel?.sink.close();
    _publicConfigChannel = null;

    try {
      final uri = ApiService.publicConfigWebSocketUri(
        platform: "APP",
        surface: "APP_DASHBOARD",
      );
      final channel = WebSocketChannel.connect(uri);
      try {
        await channel.ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        await channel.sink.close();
        _schedulePublicConfigReconnect();
        return;
      }
      if (!mounted) {
        await channel.sink.close();
        return;
      }
      _publicConfigChannel = channel;
      _publicConfigSubscription = channel.stream.listen(
        _handlePublicConfigSocketMessage,
        onDone: _schedulePublicConfigReconnect,
        onError: (_) => _schedulePublicConfigReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _schedulePublicConfigReconnect();
    }
  }

  void _schedulePublicConfigReconnect() {
    if (!mounted) return;
    if (_publicConfigReconnectTimer?.isActive == true) return;
    _publicConfigReconnectTimer = Timer(
      const Duration(seconds: 5),
      _connectPublicConfigSocket,
    );
  }

  void _initializeConnectivityObserver() {
    final connectivity = Connectivity();
    unawaited(() async {
      try {
        final initialResult = await connectivity.checkConnectivity();
        _wasConnected = _hasNetworkConnection(initialResult);
      } catch (_) {
        _wasConnected = true;
      }
    }());

    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen((dynamic result) {
      final isConnected = _hasNetworkConnection(result);
      final justReconnected = isConnected && !_wasConnected;
      _wasConnected = isConnected;
      if (!justReconnected) return;

      unawaited(_refreshUserData(forceRemote: true));
      unawaited(_loadDocumentCounts());
      unawaited(_loadLinkedProfiles());
      unawaited(_loadTopDoctors(forceRefresh: true));
      unawaited(_loadDashboardAds(forceRefresh: true));
      unawaited(_loadDashboardUiConfig(forceRefresh: true));
    });
  }

  bool _hasNetworkConnection(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }
    if (result is Iterable) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }
    return true;
  }

  void _handlePublicConfigSocketMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is! Map) return;
      final message = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final type = message['type']?.toString().trim().toLowerCase() ?? '';
      if (type.isEmpty || type == 'connected' || type == 'heartbeat') return;

      final surfaces = _normalizeTargetValues(message['surfaces']);
      final platforms = _normalizeTargetValues(message['platforms']);
      final targetsDashboard =
          surfaces.isEmpty || surfaces.contains('APP_DASHBOARD');
      final targetsApp = platforms.isEmpty || platforms.contains('APP');
      if (!targetsDashboard || !targetsApp) return;

      ApiService.invalidatePublicConfigCache();
      if (type == 'ads.updated' || type == 'ui-config.updated') {
        _loadDashboardAds(forceRefresh: true);
      }
      if (type == 'alerts.updated' || type == 'ui-config.updated') {
        _loadDashboardUiConfig(forceRefresh: true);
      }
    } catch (_) {
      // Ignore malformed websocket events
    }
  }

  Set<String> _normalizeTargetValues(dynamic raw) {
    if (raw is! List) return <String>{};
    return raw
        .map((entry) => entry?.toString().trim().toUpperCase() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toSet();
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
    if (_documentCounts.isEmpty && mounted) {
      setState(() {
        _isLoadingCounts = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _activeUserId.isNotEmpty
          ? _activeUserId
          : ((prefs.getString("activeProfileId") ?? "").trim().isNotEmpty
              ? (prefs.getString("activeProfileId") ?? "").trim()
              : (prefs.getString("userId") ?? "").trim());

      if (userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoadingCounts = false;
        });
        return;
      }

      // Immediately hydrate from local cache so offline mode keeps last values.
      final cachedGrouped = await ApiService.getCachedGroupedDocs(userId);
      if (cachedGrouped != null) {
        final counts = cachedGrouped["counts"] is Map
            ? Map<String, dynamic>.from(cachedGrouped["counts"])
            : <String, dynamic>{};
        if (mounted) {
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

      final grouped = await ApiService.fetchGroupedDocs(userId);
      if (grouped != null) {
        final counts = grouped["counts"] is Map
            ? Map<String, dynamic>.from(grouped["counts"])
            : <String, dynamic>{};
        if (mounted) {
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
      } else if (_documentCounts.isEmpty) {
        // If startup used stale local identity, recover from latest authenticated profile.
        final refreshedUser = await ApiService.me();
        final refreshedUserId = (refreshedUser?['id']?.toString() ??
                refreshedUser?['_id']?.toString() ??
                '')
            .trim();
        if (refreshedUserId.isNotEmpty && refreshedUserId != userId) {
          await prefs.setString("userId", refreshedUserId);
          if (refreshedUser != null && refreshedUser.isNotEmpty) {
            await prefs.setString("userData", jsonEncode(refreshedUser));
          }

          final retriedGrouped = await ApiService.fetchGroupedDocs(
            refreshedUserId,
          );
          if (retriedGrouped != null && mounted) {
            final counts = retriedGrouped["counts"] is Map
                ? Map<String, dynamic>.from(retriedGrouped["counts"])
                : <String, dynamic>{};
            setState(() {
              _userData = refreshedUser ?? _userData;
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
      }
    } catch (e) {
      debugPrint("Error loading document counts: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingCounts = false;
      });
    }
  }

  Future<void> _loadTopDoctors({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loadingTopDoctors = true;
      });
    }

    try {
      final past =
          await ApiService.fetchPastAppointments(forceRefresh: forceRefresh);
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final raw in past) {
        if (raw is! Map<String, dynamic>) continue;
        final doctorData = raw['doctorId'];
        final doctorName =
            (doctorData is Map ? doctorData['name'] : raw['doctorName'])
                    ?.toString()
                    .trim() ??
                '';
        if (doctorName.isEmpty) continue;

        final key = (doctorData is Map ? doctorData['_id'] : raw['doctorId'])
                ?.toString() ??
            doctorName;
        final specialization = (doctorData is Map
                    ? doctorData['specialty'] ?? doctorData['specialization']
                    : raw['doctorSpecialization'])
                ?.toString() ??
            '';
        final image = (doctorData is Map
                ? doctorData['profilePictureUrl'] ??
                    doctorData['profilePicture'] ??
                    doctorData['avatarUrl'] ??
                    doctorData['avatar']
                : raw['doctorProfilePicture'])
            ?.toString();

        final current = grouped.putIfAbsent(
          key,
          () => {
            'id': key,
            'name': doctorName,
            'specialization': specialization,
            'imageUrl': image,
            'appointments': <Map<String, dynamic>>[],
            'count': 0,
            'rating': _estimateRatingFromName(doctorName),
          },
        );

        (current['appointments'] as List<Map<String, dynamic>>).add(raw);
        current['count'] = (current['count'] as int) + 1;

        if ((current['specialization'] as String).isEmpty &&
            specialization.isNotEmpty) {
          current['specialization'] = specialization;
        }
      }

      final doctors = grouped.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (!mounted) return;
      setState(() {
        _topDoctors = doctors.take(8).toList();
        _loadingTopDoctors = false;
      });
    } catch (e) {
      debugPrint('Error loading top doctors: $e');
      if (!mounted) return;
      setState(() {
        _topDoctors = [];
        _loadingTopDoctors = false;
      });
    }
  }

  Future<void> _loadDashboardAds({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        ApiService.invalidatePublicConfigCache(ads: true, uiConfig: false);
      }
      final ads = await ApiService.fetchAdvertisements(
        placement: 'APP_DASHBOARD',
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final previousIndex = _promoPageIndex;
      final maxIndex = ads.isEmpty ? 0 : ads.length - 1;
      final nextIndex = previousIndex.clamp(0, maxIndex).toInt();
      setState(() {
        _dashboardAds = ads;
        _promoPageIndex = nextIndex;
      });
      if (ads.isNotEmpty && previousIndex != nextIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_promoPageController.hasClients) return;
          _promoPageController.jumpToPage(_promoPageSeed + nextIndex);
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard ads: $e');
    }
  }

  Future<void> _loadDashboardUiConfig({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        ApiService.invalidatePublicConfigCache(ads: false, uiConfig: true);
      }
      final config = await ApiService.fetchUiConfig(forceRefresh: forceRefresh);
      final cardsRaw = config?['dashboardCards'];
      final cards = cardsRaw is List
          ? cardsRaw
              .whereType<Map>()
              .map((item) => item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      final alertsRaw = config?['dashboardAlerts'];
      final alerts = alertsRaw is List
          ? alertsRaw
              .whereType<Map>()
              .map((item) => item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      final now = _nowInSelectedZone();
      final activeAlerts = _activeDashboardAlerts(now, source: alerts);

      if (!mounted) return;
      setState(() {
        _dashboardCards = cards;
        _dashboardAlerts = activeAlerts;
      });
    } catch (e) {
      debugPrint('Error loading dashboard UI config: $e');
    }
  }

  List<Map<String, dynamic>> _activeDashboardAlerts(
    DateTime now, {
    List<Map<String, dynamic>>? source,
  }) {
    final input = source ?? _dashboardAlerts;
    final currentRole =
        (_userData['role']?.toString().trim().toUpperCase() ?? 'PATIENT');
    return input.where((alert) {
      final isActive = alert['isActive'];
      if (isActive is bool && !isActive) return false;

      final platforms = _normalizeAlertPlatforms(alert);
      if (platforms.isNotEmpty && !platforms.contains('APP')) {
        return false;
      }

      final audience = alert['audience']?.toString().trim().toUpperCase() ?? '';
      if (audience.isNotEmpty && audience != 'ALL' && audience != currentRole) {
        return false;
      }

      final startAt = _parseAlertDate(alert['startAt']);
      if (startAt != null && startAt.isAfter(now)) return false;

      final endAt = _parseAlertDate(alert['endAt']);
      if (endAt != null && endAt.isBefore(now)) return false;

      final message = alert['message']?.toString().trim() ?? '';
      return message.isNotEmpty;
    }).toList(growable: false);
  }

  Set<String> _normalizeAlertPlatforms(Map<String, dynamic> alert) {
    final fromList = alert['platforms'];
    if (fromList is List) {
      final values = fromList
          .map((entry) => entry?.toString().trim().toUpperCase() ?? '')
          .where((entry) => entry.isNotEmpty && entry != 'ALL')
          .toSet();
      if (values.isNotEmpty) return values;
    }

    final legacy = alert['platform']?.toString().trim().toUpperCase() ?? '';
    if (legacy.isEmpty || legacy == 'ALL') {
      return {'APP', 'WEB'};
    }
    if (legacy.contains(',')) {
      return legacy
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toSet();
    }
    return {legacy};
  }

  DateTime _nowInSelectedZone() {
    final timezoneId = context.read<TimezoneProvider>().timeZoneId;
    return nowInTimeZone(timezoneId);
  }

  DateTime? _parseAlertDate(dynamic raw) {
    final timezoneId = context.read<TimezoneProvider>().timeZoneId;
    return convertToSelectedTimeZone(raw, timezoneId);
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auto('Unable to open the link'))),
      );
    }
  }

  Future<void> _openTrackedAd(
    Map<String, dynamic> ad, {
    required String placement,
  }) async {
    final fallbackUrl = ad['redirectUrl']?.toString().trim() ?? '';
    if (fallbackUrl.isEmpty) return;

    String finalUrl = fallbackUrl;
    final adId =
        ad['_id']?.toString().trim() ?? ad['id']?.toString().trim() ?? '';
    if (adId.isNotEmpty) {
      final trackedUrl = await ApiService.fetchTrackedAdvertisementUrl(
        adId: adId,
        placement: placement,
      );
      if (trackedUrl != null && trackedUrl.isNotEmpty) {
        finalUrl = trackedUrl;
      }
    }

    if (!mounted) return;
    await _openExternalUrl(finalUrl);
  }

  double _estimateRatingFromName(String name) {
    final hash = name.codeUnits.fold<int>(0, (sum, c) => sum + c);
    final offset = (hash % 8) / 10;
    return 4.1 + offset;
  }

  void _onNavTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
    if (_fabMenuOpen) {
      unawaited(_closeFabMenu());
    }
    if (index == 0) {
      _refreshUserData();
    }
  }

  Future<void> _refreshUserData({bool forceRemote = false}) async {
    final previousUserId = _activeUserId;
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? nextUserData;

      if (forceRemote) {
        final remoteUser = await ApiService.me();
        if (remoteUser != null && remoteUser.isNotEmpty) {
          nextUserData = Map<String, dynamic>.from(remoteUser);
          await prefs.setString('userData', jsonEncode(nextUserData));
          final remoteUserId = (nextUserData['id']?.toString() ??
                  nextUserData['_id']?.toString() ??
                  '')
              .trim();
          if (remoteUserId.isNotEmpty) {
            await prefs.setString('userId', remoteUserId);
          }
        }
      }

      if (nextUserData == null) {
        final stored = prefs.getString("userData");
        if (stored != null && stored.trim().isNotEmpty) {
          final decoded = jsonDecode(stored);
          if (decoded is Map) {
            nextUserData = decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
        }
      }

      if (nextUserData == null || nextUserData.isEmpty) {
        return;
      }

      final nextUserId = (nextUserData['id']?.toString() ??
              nextUserData['_id']?.toString() ??
              '')
          .trim();
      if (!mounted) return;
      setState(() {
        _userData = Map<String, dynamic>.from(nextUserData!);
      });

      if (nextUserId.isNotEmpty &&
          (nextUserId != previousUserId || forceRemote)) {
        unawaited(_loadDocumentCounts());
      }
    } catch (e) {
      print("Error refreshing user data: $e");
    }
  }

  Future<void> _loadStoredName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _storedName = prefs.getString("name");
    });
  }

  Widget _buildPromoCarousel(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (_dashboardAds.isEmpty) return const SizedBox.shrink();
    final promoGradient = [
      Color.lerp(
        scheme.primary,
        Colors.white,
        isDark ? 0.08 : 0.24,
      )!,
      Color.lerp(
        scheme.secondary,
        scheme.primary,
        isDark ? 0.14 : 0.32,
      )!,
    ];

    Widget buildPromoItem(Map<String, dynamic> item) {
      final title = (item['title']?.toString().trim().isNotEmpty ?? false)
          ? item['title'].toString().trim()
          : l10n.auto('Medical Vault');
      final redirectUrl = item['redirectUrl']?.toString().trim() ?? '';
      final subtitle = redirectUrl.isNotEmpty
          ? l10n.auto('Tap to learn more')
          : l10n.auto('Medical Vault update');
      final imageUrl = item['imageUrl']?.toString().trim() ?? '';

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: redirectUrl.isEmpty
            ? null
            : () => _openTrackedAd(
                  item,
                  placement: 'APP_DASHBOARD',
                ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildRemoteOrEmbeddedImage(
                imageSource: imageUrl,
                fit: BoxFit.cover,
                fallback: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: promoGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            variant: AppTextVariant.body,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            variant: AppTextVariant.caption,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ],
                      ),
                    ),
                    if (redirectUrl.isNotEmpty)
                      Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_dashboardAds.length == 1) {
      return RepaintBoundary(
        child: SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: buildPromoItem(_dashboardAds.first),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        height: 120,
        child: PageView.builder(
          controller: _promoPageController,
          onPageChanged: (index) {
            _promoPageIndex = index % _dashboardAds.length;
          },
          itemBuilder: (context, index) {
            final item = _dashboardAds[index % _dashboardAds.length];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: buildPromoItem(item),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncTickerAnimation();
    final l10n = context.l10n;
    final passedName = (_userData['name'] ?? "").toString();

    final defaultName = l10n.auto('Patient');
    final userName =
        passedName.isNotEmpty ? passedName : (_storedName ?? defaultName);
    final categories = [
      {
        'title': l10n.t('documents.category.reports'),
        'image': 'assets/Reports.png',
        'category': 'Reports',
        'count': _documentCounts['Reports'] ?? 0
      },
      {
        'title': l10n.t('documents.category.prescriptions'),
        'image': 'assets/Prescription.png',
        'category': 'Prescription',
        'count': _documentCounts['Prescription'] ?? 0
      },
      {
        'title': l10n.t('documents.category.bills'),
        'image': 'assets/2851468.png',
        'category': 'Bill',
        'count': _documentCounts['Bill'] ?? 0
      },
      {
        'title': l10n.t('documents.category.insurance'),
        'image': 'assets/Insurance12.png',
        'category': 'Insurance',
        'count': _documentCounts['Insurance'] ?? 0
      },
    ];
    final activeDashboardCards = _dashboardCards
        .where((card) => card['isActive'] == null || card['isActive'] == true)
        .toList(growable: false);
    final hasActiveAlerts = _localizedAlertHeadlines(context).isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_fabMenuOpen) {
          await _closeFabMenu();
          return;
        }
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
        if (!context.mounted) return;
        if (shouldExit ?? false) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: IndexedStack(
              index: _currentIndex,
              children: [
                // Home tab
                TickerMode(
                  enabled: _currentIndex == 0,
                  child: SafeArea(
                    bottom: false,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await _loadDocumentCounts();
                        await _loadTopDoctors(forceRefresh: true);
                        await _loadDashboardAds(forceRefresh: true);
                        await _loadDashboardUiConfig(forceRefresh: true);
                        await _refreshUserData();
                      },
                      child: ListView(
                        key: const PageStorageKey<String>(
                            'dashboard-home-scroll'),
                        cacheExtent: 1600,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        children: [
                          _buildGreetingSection(context, userName),
                          const SizedBox(height: AppSpacing.medium),
                          if (hasActiveAlerts) ...[
                            RepaintBoundary(
                              child: _buildAlertTicker(context),
                            ),
                            const SizedBox(height: AppSpacing.medium),
                          ],
                          if (_dashboardAds.isNotEmpty) ...[
                            _buildPromoCarousel(context),
                            const SizedBox(height: AppSpacing.large),
                          ],
                          if (_loadingTopDoctors || _topDoctors.isNotEmpty) ...[
                            _buildTopDoctorsSection(context),
                            const SizedBox(height: AppSpacing.large),
                          ],
                          AppText(
                            l10n.t('dashboard.quickActions'),
                            variant: AppTextVariant.subtitle,
                            fontWeight: FontWeight.w700,
                          ),
                          const SizedBox(height: AppSpacing.medium),
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
                                        builder: (context) => QRPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context,
                                  icon: Icons.person_add_alt_1,
                                  title:
                                      l10n.t('dashboard.action.accessRequests'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RequestsPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                                        builder: (context) =>
                                            SosPage(userData: _userData),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context,
                                  icon: Icons.manage_search_rounded,
                                  title: l10n.auto('Lost & Found'),
                                  onTap: () async {
                                    await _openLostFound(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  context,
                                  icon: Icons.person_search_rounded,
                                  title: l10n.auto('Search Lost Persons'),
                                  onTap: () async {
                                    await _openSearchLostPersons(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context,
                                  icon: Icons.list,
                                  title:
                                      l10n.t('dashboard.action.myLostReports'),
                                  onTap: () async {
                                    await _openMyLostReports(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (activeDashboardCards.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.large),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppText(
                                l10n.auto('Featured'),
                                variant: AppTextVariant.subtitle,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.medium),
                            SizedBox(
                              height: 124,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: activeDashboardCards.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final card = activeDashboardCards[index];
                                  final title =
                                      card['title']?.toString().trim();
                                  if (title == null || title.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final subtitle =
                                      card['subtitle']?.toString().trim() ?? '';
                                  final redirectUrl =
                                      card['redirectUrl']?.toString().trim() ??
                                          '';
                                  return SizedBox(
                                    width: 220,
                                    child: CustomCard(
                                      onTap: redirectUrl.isEmpty
                                          ? null
                                          : () => _openExternalUrl(redirectUrl),
                                      radius: AppRadii.medium,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AppText(
                                            title,
                                            variant: AppTextVariant.body,
                                            fontWeight: FontWeight.w700,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            AppText(
                                              subtitle,
                                              variant: AppTextVariant.caption,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (redirectUrl.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.open_in_new_rounded,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                AppText(
                                                  l10n.auto('Open'),
                                                  variant:
                                                      AppTextVariant.caption,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.large),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText(
                                l10n.t('dashboard.documentsTitle'),
                                variant: AppTextVariant.subtitle,
                                fontWeight: FontWeight.w700,
                              ),
                              if (!_isLoadingCounts)
                                AppText(
                                  l10n.format('dashboard.documentsTotal', {
                                    'count':
                                        '${_documentCounts.values.fold(0, (sum, count) => sum + count)}'
                                  }),
                                  variant: AppTextVariant.caption,
                                  fontWeight: FontWeight.w600,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categories.length,
                            addRepaintBoundaries: true,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.98,
                            ),
                            itemBuilder: (context, index) {
                              final item = categories[index];
                              return _buildCategoryCard(
                                context,
                                title: item['title'] as String,
                                imagePath: item['image'] as String,
                                category: item['category'] as String,
                                count: item['count'] as int,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Center(child: AppFooter()),
                        ],
                      ),
                    ),
                  ),
                ),

                // 🔐 Vault tab
                _loadedTabs.contains(1)
                    ? TickerMode(
                        enabled: _currentIndex == 1,
                        child: MyVault(
                          userId: _activeUserId,
                        ),
                      )
                    : const SizedBox.shrink(),
                _loadedTabs.contains(2)
                    ? TickerMode(
                        enabled: _currentIndex == 2,
                        child: QRPage(),
                      )
                    : const SizedBox.shrink(),
                _loadedTabs.contains(3)
                    ? TickerMode(
                        enabled: _currentIndex == 3,
                        child: RequestsPage(),
                      )
                    : const SizedBox.shrink(),
                _loadedTabs.contains(4)
                    ? TickerMode(
                        enabled: _currentIndex == 4,
                        child: SettingsPage(userData: _userData),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTapped,
              reduceMotion: _bottomNavReduceMotion,
              items: [
                BottomNavItemData(
                  icon: Icons.home_rounded,
                  label: l10n.t('dashboard.nav.home'),
                ),
                BottomNavItemData(
                  icon: Icons.lock_rounded,
                  label: l10n.t('dashboard.nav.vault'),
                ),
                BottomNavItemData(
                  icon: Icons.qr_code_rounded,
                  label: l10n.t('dashboard.nav.qr'),
                ),
                BottomNavItemData(
                  icon: Icons.list_alt_rounded,
                  label: l10n.t('dashboard.nav.requests'),
                ),
                BottomNavItemData(
                  icon: Icons.settings_rounded,
                  label: l10n.t('dashboard.nav.settings'),
                ),
              ],
            ),
          ),
          if (_fabMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  unawaited(_closeFabMenu());
                },
                child: AnimatedBuilder(
                  animation: _fabMenuController,
                  builder: (context, _) {
                    final opacity = Curves.easeOut.transform(
                      _fabMenuController.value,
                    );
                    return Container(
                      color: Colors.black.withValues(alpha: 0.18 * opacity),
                    );
                  },
                ),
              ),
            ),
          _buildDashboardQuickActionsFab(context),
        ],
      ),
    );
  }

  Widget _buildGreetingSection(BuildContext context, String userName) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final photoUrl =
        (_userData['profilePictureUrl'] ?? _userData['profilePicture'] ?? '')
            .toString();

    return CustomCard(
      radius: AppRadii.large,
      gradient: [
        theme.colorScheme.primary.withValues(alpha: 0.95),
        theme.colorScheme.secondary.withValues(alpha: 0.94),
      ],
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openProfileSettings(context),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              child: photoUrl.isNotEmpty
                  ? ClipOval(
                      child: _buildRemoteOrEmbeddedImage(
                        imageSource: photoUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        fallback: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  l10n.auto('Good to see you'),
                  variant: AppTextVariant.caption,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 2),
                AppText(
                  l10n.format('dashboard.greeting', {'name': userName}),
                  variant: AppTextVariant.subtitle,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_linkedProfiles.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  AppText(
                    l10n.format('dashboard.profileCount', {
                      'count': '${_linkedProfiles.length + 1}',
                    }),
                    variant: AppTextVariant.caption,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _openMessagesHub(context),
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                ),
                tooltip: l10n.auto('Messages'),
              ),
              IconButton(
                onPressed: () => _showProfileSwitcher(context),
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                tooltip: l10n.t('dashboard.switchProfileTooltip'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopDoctorsSection(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppText(
              l10n.auto('Top Doctors'),
              variant: AppTextVariant.subtitle,
              fontWeight: FontWeight.w700,
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  _buildFadeSlideRoute(const AppointmentsPage(initialTab: 0)),
                );
              },
              child: const AppText(
                'See all',
                variant: AppTextVariant.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingTopDoctors)
          const SizedBox(
            height: 188,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_topDoctors.isEmpty)
          CustomCard(
            glass: true,
            child: AppText(l10n.auto('No doctor insights available yet.'),
                variant: AppTextVariant.caption),
          )
        else
          SizedBox(
            height: 192,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topDoctors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final doctor = _topDoctors[index];
                return SizedBox(
                  width: 208,
                  child: DoctorCard(
                    name: doctor['name']?.toString() ?? 'Doctor',
                    specialization: doctor['specialization']?.toString() ?? '',
                    rating: (doctor['rating'] as num?)?.toDouble() ?? 4.5,
                    imageUrl: doctor['imageUrl']?.toString(),
                    highlighted: index == 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        _buildFadeSlideRoute(
                          DoctorDetailScreen(
                            doctor: doctor,
                            appointments: List<Map<String, dynamic>>.from(
                              doctor['appointments'] as List? ?? const [],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context,
      {required String title,
      required String imagePath,
      required String category,
      required int count}) {
    final l10n = context.l10n;
    return CustomCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryVaultPage(
              category: category,
              userId: _activeUserId,
            ),
          ),
        );
        _loadDocumentCounts();
      },
      glass: false,
      softShadow: false,
      radius: AppRadii.large,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                height: 74,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            title,
            variant: AppTextVariant.body,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AppText(
              '$count ${count == 1 ? l10n.t('dashboard.documentSingular') : l10n.t('dashboard.documentPlural')}',
              variant: AppTextVariant.caption,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Route _buildFadeSlideRoute(Widget page) {
    final transitionDuration =
        _reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final reverseTransitionDuration =
        _reduceMotion ? Duration.zero : const Duration(milliseconds: 160);
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: reverseTransitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (_reduceMotion) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _toggleFabMenu() async {
    if (_fabMenuController.isAnimating) return;
    if (_fabMenuOpen) {
      await _closeFabMenu();
      return;
    }

    if (!mounted) return;
    setState(() {
      _fabMenuOpen = true;
    });
    AIAssistantOverlayController.setVisible(false);
    await _fabMenuController.forward(from: 0);
  }

  Future<void> _closeFabMenu() async {
    if (!_fabMenuOpen) return;
    if (_fabMenuController.isAnimating) {
      _fabMenuController.stop();
    }
    await _fabMenuController.reverse();
    if (!mounted) return;
    setState(() {
      _fabMenuOpen = false;
    });
    AIAssistantOverlayController.setVisible(true);
  }

  Future<void> _handleFabAction(Future<void> Function() action) async {
    await _closeFabMenu();
    if (!mounted) return;
    await action();
  }

  Future<void> _openNearbyFromFab() async {
    await Navigator.push(
      context,
      _buildFadeSlideRoute(const NearbyServicesPage()),
    );
  }

  Future<void> _openStoreFromFab() async {
    await Navigator.push(
      context,
      _buildFadeSlideRoute(const MedicalStorePage()),
    );
  }

  Future<void> _openAppointmentsFromFab() async {
    await Navigator.push(
      context,
      _buildFadeSlideRoute(const AppointmentsPage(initialTab: 0)),
    );
  }

  Future<void> _openAiAssistantFromFab() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.l10n.auto('AI Assistant'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildAssistantChoiceTile(
                sheetContext,
                icon: Icons.health_and_safety_rounded,
                title: sheetContext.l10n.auto('Medical AI Assistant'),
                subtitle: sheetContext.l10n.auto('Medical vault documents'),
                accentColor: scheme.primary,
                onTap: () => Navigator.pop(sheetContext, 'medical'),
              ),
              const SizedBox(height: 10),
              _buildAssistantChoiceTile(
                sheetContext,
                icon: Icons.person_search_rounded,
                title: sheetContext.l10n.auto('KHOJ AI'),
                subtitle: sheetContext.l10n.auto('Lost and found reports'),
                accentColor: scheme.tertiary,
                onTap: () => Navigator.pop(sheetContext, 'khoj'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    final page = selected == 'khoj' ? const KhojAiPage() : const ChatScreen();
    await Navigator.push(context, _buildFadeSlideRoute(page));
  }

  Widget _buildAssistantChoiceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: accentColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardQuickActionsFab(BuildContext context) {
    const mainFabSize = 58.0;
    const spacing = 10.0;
    const bottomNavOffset = 112.0;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final availableWidth = media.size.width - 32;
    final showLabels = availableWidth >= 300;
    final menuWidth = showLabels
        ? availableWidth.clamp(252.0, 324.0).toDouble()
        : mainFabSize;
    final bottomPadding = media.padding.bottom;
    final actions = <Map<String, dynamic>>[
      {
        'icon': Icons.smart_toy_rounded,
        'label': context.l10n.auto('AI Assistant'),
        'onTap': _openAiAssistantFromFab,
      },
      {
        'icon': Icons.local_hospital_rounded,
        'label': context.l10n.auto('Nearby Healthcare'),
        'onTap': _openNearbyFromFab,
      },
      {
        'icon': Icons.shopping_bag_rounded,
        'label': context.l10n.auto('Products'),
        'onTap': _openStoreFromFab,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'label': context.l10n.auto('Appointments'),
        'onTap': _openAppointmentsFromFab,
      },
    ];

    return Positioned(
      right: media.size.width >= 600 ? 24 : 16,
      bottom: bottomNavOffset + bottomPadding,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _fabMenuController,
          builder: (context, _) {
            final menuProgress = Curves.easeOutCubic.transform(
              _fabMenuController.value,
            );

            return SizedBox(
              width: menuWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IgnorePointer(
                    ignoring: !_fabMenuOpen || menuProgress < 0.04,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          _buildDashboardFabAction(
                            context,
                            icon: actions[i]['icon'] as IconData,
                            label: actions[i]['label'] as String,
                            showLabel: showLabels,
                            index: i,
                            rawProgress: _fabMenuController.value,
                            onTap: () {
                              unawaited(_handleFabAction(
                                actions[i]['onTap'] as Future<void> Function(),
                              ));
                            },
                          ),
                          if (i != actions.length - 1)
                            const SizedBox(height: spacing),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: showLabels ? 14 : 12),
                  Tooltip(
                    message: _fabMenuOpen
                        ? context.l10n.auto('Close quick actions')
                        : context.l10n.auto('Open quick actions'),
                    child: Semantics(
                      button: true,
                      toggled: _fabMenuOpen,
                      label: context.l10n.auto('Dashboard quick actions'),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          elevation: 10,
                          shadowColor: scheme.primary.withValues(alpha: 0.32),
                          child: Ink(
                            width: mainFabSize,
                            height: mainFabSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary,
                                  Color.lerp(
                                    scheme.primary,
                                    scheme.secondary,
                                    0.52,
                                  )!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                unawaited(_toggleFabMenu());
                              },
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeOutCubic,
                                  transitionBuilder: (child, animation) {
                                    return RotationTransition(
                                      turns: Tween<double>(begin: 0.88, end: 1)
                                          .animate(animation),
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    _fabMenuOpen
                                        ? Icons.close_rounded
                                        : Icons.support_agent_rounded,
                                    key: ValueKey<bool>(_fabMenuOpen),
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardFabAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool showLabel,
    required int index,
    required double rawProgress,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final delay = (index * 0.08).clamp(0.0, 0.24);
    final intervalProgress =
        ((rawProgress - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble();
    final progress = Curves.easeOutCubic.transform(intervalProgress);

    Widget buttonChild;
    if (showLabel) {
      buttonChild = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 21, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      buttonChild = SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Icon(icon, size: 22, color: scheme.primary),
        ),
      );
    }

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * 14),
        child: Transform.scale(
          alignment: Alignment.centerRight,
          scale: 0.92 + (0.08 * progress),
          child: Tooltip(
            message: label,
            child: Semantics(
              button: true,
              label: label,
              child: Material(
                color: theme.cardColor,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(showLabel ? 28 : 26),
                ),
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.18),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(showLabel ? 28 : 26),
                  child: buttonChild,
                ),
              ),
            ),
          ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return CustomCard(
      onTap: onTap,
      glass: false,
      softShadow: false,
      radius: AppRadii.medium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              title,
              variant: AppTextVariant.caption,
              fontWeight: FontWeight.w700,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            size: 18,
          ),
        ],
      ),
    );
  }

  Future<void> _openProfileSettings(BuildContext context) async {
    final initialUser = Map<String, dynamic>.from(_userData);
    final result = await Navigator.push(
      context,
      _buildFadeSlideRoute(ProfileName(userData: initialUser)),
    );
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      setState(() {
        _userData = Map<String, dynamic>.from(result);
      });
    } else {
      await _refreshUserData();
    }
    await _loadLinkedProfiles();
  }

  Future<void> _openMessagesHub(BuildContext context) async {
    await Navigator.push(
      context,
      _buildFadeSlideRoute(const ChatThreadsScreen()),
    );
  }

  void _showProfileSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileSwitcherModal(
        currentUser: _userData,
        linkedProfiles: _linkedProfiles,
      ),
    ).then((_) {
      // Refresh profiles when modal is closed
      _loadLinkedProfiles();
    });
  }

  Future<void> _openLostFound(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LostFoundReportPage(
          currentUser: Map<String, dynamic>.from(_userData),
          linkedProfiles: _linkedProfiles,
        ),
      ),
    );
  }

  Future<void> _openSearchLostPersons(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchLostPersonsPage(
          currentUser: Map<String, dynamic>.from(_userData),
          linkedProfiles: _linkedProfiles,
        ),
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
    return _activeDashboardAlerts(_nowInSelectedZone())
        .map((alert) => alert['message']?.toString().trim() ?? '')
        .where((message) => message.isNotEmpty)
        .toList(growable: false);
  }

  Widget _buildAlertTicker(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final alertAccent = scheme.error;
    final alertBackground = Color.alphaBlend(
      alertAccent.withValues(alpha: isDark ? 0.16 : 0.09),
      theme.cardColor,
    );
    final alerts = _localizedAlertHeadlines(context);
    if (alerts.isEmpty) return const SizedBox.shrink();
    final alertText = alerts.join('   |   ');
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: alertAccent,
        ) ??
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: alertAccent,
        );

    return Container(
      decoration: BoxDecoration(
        color: alertBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertAccent.withValues(alpha: isDark ? 0.3 : 0.42),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: alertAccent.withValues(alpha: 0.16),
            ),
            child: Icon(
              Icons.campaign_outlined,
              color: alertAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 20,
              child: _reduceMotion
                  ? Text(
                      alertText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final painter = TextPainter(
                          text: TextSpan(text: alertText, style: textStyle),
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                        )..layout();

                        final contentWidth = painter.width <= 0
                            ? constraints.maxWidth
                            : painter.width;
                        final tickerWidth = contentWidth < constraints.maxWidth
                            ? constraints.maxWidth + 48
                            : contentWidth + 48;

                        return ClipRect(
                          child: AnimatedBuilder(
                            animation: _alertController,
                            builder: (context, child) {
                              final offset =
                                  (_alertController.value * tickerWidth) %
                                      tickerWidth;
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
                                          overflow: TextOverflow.clip,
                                          softWrap: false,
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
                                          overflow: TextOverflow.clip,
                                          softWrap: false,
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
