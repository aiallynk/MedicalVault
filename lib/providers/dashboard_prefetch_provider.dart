import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../api_service.dart';

class DashboardPrefetchData {
  const DashboardPrefetchData({
    required this.userData,
    required this.documentCounts,
    required this.linkedProfiles,
    required this.topDoctors,
    required this.dashboardAds,
    required this.dashboardCards,
    required this.dashboardAlerts,
    required this.notifications,
    required this.recentActivity,
    required this.qrData,
    required this.fetchedAt,
    required this.partial,
  });

  final Map<String, dynamic> userData;
  final Map<String, int> documentCounts;
  final List<Map<String, dynamic>> linkedProfiles;
  final List<Map<String, dynamic>> topDoctors;
  final List<Map<String, dynamic>> dashboardAds;
  final List<Map<String, dynamic>> dashboardCards;
  final List<Map<String, dynamic>> dashboardAlerts;
  final List<dynamic> notifications;
  final List<dynamic> recentActivity;
  final String? qrData;
  final DateTime fetchedAt;
  final bool partial;

  String get userId =>
      (userData['id']?.toString() ?? userData['_id']?.toString() ?? '').trim();
}

class DashboardPrefetchProvider extends ChangeNotifier {
  DashboardPrefetchData? _cachedData;
  bool _isPrefetching = false;
  bool _notifyQueued = false;
  bool _isDisposed = false;

  DashboardPrefetchData? get cachedData => _cachedData;
  bool get isPrefetching => _isPrefetching;

  void _notifyListenersSafely() {
    if (_isDisposed || !hasListeners) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final safeToNotifyNow = phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;

    if (safeToNotifyNow) {
      notifyListeners();
      return;
    }

    if (_notifyQueued) return;
    _notifyQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyQueued = false;
      if (_isDisposed || !hasListeners) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  DashboardPrefetchData? takeCachedForUser(
    String userId, {
    Duration maxAge = const Duration(minutes: 8),
  }) {
    final cached = _cachedData;
    if (cached == null) return null;

    if (DateTime.now().difference(cached.fetchedAt) > maxAge) {
      _cachedData = null;
      return null;
    }

    if (userId.trim().isEmpty) {
      return cached;
    }

    return cached.userId == userId.trim() ? cached : null;
  }

  Future<DashboardPrefetchData> prefetchDashboardData({
    required Map<String, dynamic> userData,
    bool forceRefresh = true,
  }) async {
    _isPrefetching = true;
    _notifyListenersSafely();

    try {
      final normalizedUser = Map<String, dynamic>.from(userData);
      final userId = (normalizedUser['id']?.toString() ??
              normalizedUser['_id']?.toString() ??
              '')
          .trim();

      final profileFuture = _withRetry<Map<String, dynamic>?>(
        task: () => ApiService.me(),
        fallback: null,
      );

      final docsFuture = userId.isEmpty
          ? Future.value(null)
          : _withRetry<Map<String, dynamic>?>(
              task: () => ApiService.fetchGroupedDocs(userId),
              fallback: null,
            );

      final linkedProfilesFuture = _withRetry<List<Map<String, dynamic>>>(
        task: () => ApiService.getLinkedProfiles(),
        fallback: const <Map<String, dynamic>>[],
      );

      final appointmentsFuture = _withRetry<List<dynamic>>(
        task: () =>
            ApiService.fetchPastAppointments(forceRefresh: forceRefresh),
        fallback: const <dynamic>[],
      );

      final adsFuture = _withRetry<List<Map<String, dynamic>>>(
        task: () => ApiService.fetchAdvertisements(
          placement: 'APP_DASHBOARD',
          forceRefresh: forceRefresh,
        ),
        fallback: const <Map<String, dynamic>>[],
      );

      final uiConfigFuture = _withRetry<Map<String, dynamic>?>(
        task: () => ApiService.fetchUiConfig(forceRefresh: forceRefresh),
        fallback: null,
      );

      final notificationsFuture = _withRetry<List<dynamic>>(
        task: () => ApiService.fetchNotificationHistory(),
        fallback: const <dynamic>[],
      );

      final qrDataFuture = _withRetry<String?>(
        task: () => ApiService.generateQrToken(),
        fallback: null,
      );

      final results = await Future.wait<dynamic>([
        profileFuture,
        docsFuture,
        linkedProfilesFuture,
        appointmentsFuture,
        adsFuture,
        uiConfigFuture,
        notificationsFuture,
        qrDataFuture,
      ], eagerError: false);

      final profile = results[0] as Map<String, dynamic>?;
      final groupedDocs = results[1] as Map<String, dynamic>?;
      final linkedProfiles = (results[2] as List<Map<String, dynamic>>)
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      final appointments = List<dynamic>.from(results[3] as List<dynamic>);
      final ads = (results[4] as List<Map<String, dynamic>>)
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      final uiConfig = results[5] as Map<String, dynamic>?;
      final notifications = List<dynamic>.from(results[6] as List<dynamic>);
      final qrData = results[7] as String?;

      if (profile != null && profile.isNotEmpty) {
        normalizedUser.addAll(profile);
      }

      final countsRaw = groupedDocs?['counts'];
      final documentCounts = <String, int>{
        'Reports': _toInt(countsRaw is Map ? countsRaw['reports'] : null),
        'Prescription':
            _toInt(countsRaw is Map ? countsRaw['prescriptions'] : null),
        'Bill': _toInt(countsRaw is Map ? countsRaw['bills'] : null),
        'Insurance': _toInt(countsRaw is Map ? countsRaw['insurance'] : null),
      };

      final dashboardCards = _readMapList(uiConfig?['dashboardCards']);
      final dashboardAlerts = _readMapList(uiConfig?['dashboardAlerts']);
      final recentActivity = appointments.take(12).toList(growable: false);

      List<Map<String, dynamic>> topDoctors = const [];
      try {
        topDoctors = await compute(
          _buildTopDoctorsInIsolate,
          appointments,
        );
      } catch (_) {
        topDoctors = _buildTopDoctorsInIsolate(appointments);
      }

      final partial = profile == null ||
          (userId.isNotEmpty && groupedDocs == null) ||
          ads.isEmpty ||
          uiConfig == null;

      final prefetched = DashboardPrefetchData(
        userData: normalizedUser,
        documentCounts: documentCounts,
        linkedProfiles: linkedProfiles,
        topDoctors: topDoctors,
        dashboardAds: ads,
        dashboardCards: dashboardCards,
        dashboardAlerts: dashboardAlerts,
        notifications: notifications,
        recentActivity: recentActivity,
        qrData: qrData,
        fetchedAt: DateTime.now(),
        partial: partial,
      );

      _cachedData = prefetched;
      return prefetched;
    } finally {
      _isPrefetching = false;
      _notifyListenersSafely();
    }
  }

  Future<T> _withRetry<T>({
    required Future<T> Function() task,
    required T fallback,
  }) async {
    try {
      return await task();
    } catch (_) {
      try {
        return await task();
      } catch (_) {
        return fallback;
      }
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _readMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }
}

List<Map<String, dynamic>> _buildTopDoctorsInIsolate(List<dynamic> past) {
  final grouped = <String, Map<String, dynamic>>{};

  for (final raw in past) {
    if (raw is! Map) continue;
    final map = raw.map((key, value) => MapEntry(key.toString(), value));

    final doctorData = map['doctorId'];
    final doctorDataMap = doctorData is Map
        ? doctorData.map((key, value) => MapEntry(key.toString(), value))
        : null;

    final doctorName = (doctorDataMap?['name']?.toString().trim() ??
        map['doctorName']?.toString().trim() ??
        '');
    if (doctorName.isEmpty) continue;

    final key = (doctorDataMap?['_id']?.toString() ??
            map['doctorId']?.toString() ??
            doctorName)
        .trim();

    final specialization =
        (doctorDataMap?['specialty']?.toString().trim().isNotEmpty == true)
            ? doctorDataMap!['specialty'].toString().trim()
            : (doctorDataMap?['specialization']?.toString().trim() ??
                map['doctorSpecialization']?.toString().trim() ??
                '');

    final imageUrl = doctorDataMap?['profilePictureUrl']?.toString() ??
        doctorDataMap?['profilePicture']?.toString() ??
        doctorDataMap?['avatarUrl']?.toString() ??
        doctorDataMap?['avatar']?.toString() ??
        map['doctorProfilePicture']?.toString();

    final current = grouped.putIfAbsent(
      key,
      () => <String, dynamic>{
        'id': key,
        'name': doctorName,
        'specialization': specialization,
        'imageUrl': imageUrl,
        'appointments': <Map<String, dynamic>>[],
        'count': 0,
        'rating': _estimateRatingFromName(doctorName),
      },
    );

    (current['appointments'] as List<Map<String, dynamic>>).add(map);
    current['count'] = (current['count'] as int) + 1;

    if ((current['specialization'] as String).isEmpty &&
        specialization.isNotEmpty) {
      current['specialization'] = specialization;
    }
  }

  final doctors = grouped.values.toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

  return doctors.take(8).map((doctor) {
    return {
      'id': doctor['id'],
      'name': doctor['name'],
      'specialization': doctor['specialization'],
      'imageUrl': doctor['imageUrl'],
      'appointments': List<Map<String, dynamic>>.from(
        doctor['appointments'] as List<Map<String, dynamic>>,
      ),
      'count': doctor['count'],
      'rating': doctor['rating'],
    };
  }).toList(growable: false);
}

double _estimateRatingFromName(String name) {
  final hash = name.codeUnits.fold<int>(0, (sum, c) => sum + c);
  final offset = (hash % 8) / 10;
  return 4.1 + offset;
}
