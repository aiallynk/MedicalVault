import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:hello/api_service.dart';
import '../Notifications/notification_manager.dart';
import 'package:hello/localization/app_localizations.dart';
import '../screens/appointments_page.dart';
import '../screens/doctor_sessions_screen.dart';
import '../screens/direct_chat_screen.dart';
import '../screens/chat_threads_screen.dart';

DateTime _parseDateOrNow(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is Map && value['\$date'] != null) {
    final raw = value['\$date'];
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
  }
  return DateTime.now();
}

// Session Request Model
class SessionRequest {
  final String id;
  final Doctor doctor;
  final String requestMessage;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;

  SessionRequest({
    required this.id,
    required this.doctor,
    required this.requestMessage,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  factory SessionRequest.fromJson(Map<String, dynamic> json) {
    final doctorJson = json['doctor'];
    return SessionRequest(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      doctor: Doctor.fromJson(
        doctorJson is Map<String, dynamic> ? doctorJson : <String, dynamic>{},
      ),
      requestMessage: (json['requestMessage'] ?? '').toString(),
      createdAt: _parseDateOrNow(json['createdAt']),
      expiresAt: _parseDateOrNow(json['expiresAt']),
      status: (json['status'] ?? 'pending').toString(),
    );
  }

  SessionRequest copyWith({
    Doctor? doctor,
    String? requestMessage,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? status,
  }) {
    return SessionRequest(
      id: id,
      doctor: doctor ?? this.doctor,
      requestMessage: requestMessage ?? this.requestMessage,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'doctor': doctor.toJson(),
      'requestMessage': requestMessage,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'status': status,
    };
  }
}

class SessionExtensionRequest {
  final String sessionId;
  final Doctor doctor;
  final int minutes;
  final DateTime requestedAt;
  final DateTime currentExpiresAt;

  SessionExtensionRequest({
    required this.sessionId,
    required this.doctor,
    required this.minutes,
    required this.requestedAt,
    required this.currentExpiresAt,
  });

  factory SessionExtensionRequest.fromJson(Map<String, dynamic> json) {
    final doctorJson = json['doctor'];
    final parsedMinutes =
        int.tryParse((json['minutes'] ?? '20').toString()) ?? 20;
    return SessionExtensionRequest(
      sessionId: (json['sessionId'] ?? json['_id'] ?? '').toString(),
      doctor: Doctor.fromJson(
        doctorJson is Map<String, dynamic> ? doctorJson : <String, dynamic>{},
      ),
      minutes: parsedMinutes,
      requestedAt: _parseDateOrNow(json['requestedAt']),
      currentExpiresAt: _parseDateOrNow(json['currentExpiresAt']),
    );
  }
}

// Doctor Model
class Doctor {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePicture;
  final String? experience;
  final String? specialization;
  final String? chatUrl;
  final DateTime? memberSince;

  Doctor({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePicture,
    this.experience,
    this.specialization,
    this.chatUrl,
    this.memberSince,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Doctor').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['mobile'] ?? json['phone'])?.toString(),
      profilePicture: (json['profilePictureUrl'] ??
              json['profilePicture'] ??
              json['avatarUrl'] ??
              json['avatar'])
          ?.toString(),
      experience: json['experience']?.toString(),
      specialization: (json['specialization'] ?? json['specialty'])?.toString(),
      chatUrl:
          (json['chatUrl'] ?? json['doctorChatUrl'] ?? json['chatDeepLink'])
              ?.toString(),
      memberSince: json['memberSince'] != null
          ? _parseDateOrNow(json['memberSince'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profilePicture': profilePicture,
      'experience': experience,
      'specialization': specialization,
      'chatUrl': chatUrl,
      'memberSince': memberSince?.toIso8601String(),
    };
  }
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<SessionRequest> sessionRequests = [];
  List<SessionExtensionRequest> extensionRequests = [];
  bool isLoading = true;
  String? errorMessage;
  Timer? _timer;
  final NotificationManager _notificationManager = NotificationManager();
  Set<String> _notifiedSessions = {}; // Track which sessions have been notified

  static const String baseUrl = ApiService.baseUrl;
  static const String _acceptedCacheKey =
      'patient.accepted_session_requests.v1';

  @override
  void initState() {
    super.initState();
    _loadSessionRequests();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final removedExpired = _removeExpiredSessionsInMemory();
        _removeExpiredExtensionRequestsInMemory();
        if (removedExpired) {
          _persistAcceptedRequests();
        }

        setState(() {});

        // Check for session expiring notifications
        _checkSessionExpiringNotifications();
      }
    });
  }

  bool _removeExpiredSessionsInMemory() {
    final now = DateTime.now();
    final before = sessionRequests.length;

    sessionRequests = sessionRequests.where((request) {
      if (request.expiresAt.isAfter(now)) return true;
      _notifiedSessions.remove(request.id);
      return false;
    }).toList();

    return before != sessionRequests.length;
  }

  bool _removeExpiredExtensionRequestsInMemory() {
    final now = DateTime.now();
    final before = extensionRequests.length;
    extensionRequests = extensionRequests
        .where((request) => request.currentExpiresAt.isAfter(now))
        .toList(growable: false);
    return before != extensionRequests.length;
  }

  void _checkSessionExpiringNotifications() {
    for (final request in sessionRequests) {
      if (request.status.toLowerCase() != 'accepted') continue;
      final timeLeft = request.expiresAt.difference(DateTime.now());
      final sessionId = request.id;

      // Check if session is expiring in 30 seconds and hasn't been notified yet
      if (timeLeft.inSeconds <= 30 &&
          timeLeft.inSeconds > 0 &&
          !_notifiedSessions.contains(sessionId)) {
        // Mark as notified to prevent duplicate notifications
        _notifiedSessions.add(sessionId);

        // Show notification
        _notificationManager.showSessionExpiringNotificationWithDoctor(
            context, request.doctor.name);

        if (kDebugMode) {
          print(
              'Session expiring notification sent for Dr. ${request.doctor.name}');
        }
      }
    }
  }

  Future<List<SessionRequest>> _loadAcceptedRequestsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_acceptedCacheKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final now = DateTime.now();
      return decoded
          .whereType<Map>()
          .map((item) => SessionRequest.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((request) =>
              request.status.toLowerCase() == 'accepted' &&
              request.expiresAt.isAfter(now))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistAcceptedRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final accepted = sessionRequests
        .where((request) =>
            request.status.toLowerCase() == 'accepted' &&
            request.expiresAt.isAfter(now))
        .map((request) => request.toJson())
        .toList();

    if (accepted.isEmpty) {
      await prefs.remove(_acceptedCacheKey);
      return;
    }

    await prefs.setString(_acceptedCacheKey, jsonEncode(accepted));
  }

  List<SessionRequest> _mergeRequests(
    List<SessionRequest> serverPending,
    List<SessionRequest> cachedAccepted,
  ) {
    final merged = <String, SessionRequest>{};
    for (final request in serverPending) {
      merged[request.id] = request;
    }
    for (final request in cachedAccepted) {
      merged[request.id] = request;
    }

    final result = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  // Get auth token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Fetch session requests from API
  Future<void> _loadSessionRequests() async {
    final l10n = context.l10n;
    if (!mounted) return;
    final cachedAccepted = await _loadAcceptedRequestsFromCache();

    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await _getToken();
      if (token == null) {
        throw Exception(l10n.t('common.noToken'));
      }

      final response = await http.get(
        Uri.parse('$baseUrl/sessions/requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List<dynamic> requestsJson = data['requests'] as List<dynamic>;
          final serverPending = requestsJson
              .whereType<Map>()
              .map((json) =>
                  SessionRequest.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          final merged = _mergeRequests(serverPending, cachedAccepted);
          List<SessionExtensionRequest> extensionPending = [];

          try {
            final extensionResponse = await http.get(
              Uri.parse('$baseUrl/sessions/extension-requests'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
            if (extensionResponse.statusCode == 200) {
              final extensionData = jsonDecode(extensionResponse.body);
              if (extensionData['success'] == true &&
                  extensionData['requests'] is List) {
                extensionPending = (extensionData['requests'] as List)
                    .whereType<Map>()
                    .map((json) => SessionExtensionRequest.fromJson(
                        Map<String, dynamic>.from(json)))
                    .toList(growable: false);
              }
            }
          } catch (extensionError) {
            print('Error loading extension requests: $extensionError');
          }

          if (!mounted) return;
          setState(() {
            sessionRequests = merged;
            extensionRequests = extensionPending;
            isLoading = false;
            _notifiedSessions.removeWhere(
              (id) => !sessionRequests.any((request) => request.id == id),
            );
          });
          await _persistAcceptedRequests();
        } else {
          throw Exception(
              data['message']?.toString() ?? l10n.t('requests.errorTitle'));
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (!mounted) return;
      if (cachedAccepted.isNotEmpty) {
        setState(() {
          sessionRequests = cachedAccepted;
          extensionRequests = [];
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
      print('Error loading session requests: $e');
    }
  }

  // Respond to session request (accept/decline)
  Future<void> _respondToRequest(String sessionId, String status) async {
    final l10n = context.l10n;
    final existingIndex =
        sessionRequests.indexWhere((request) => request.id == sessionId);

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception(l10n.t('common.noToken'));
      }

      final response = await http.post(
        Uri.parse('$baseUrl/sessions/$sessionId/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (status == 'accepted' && existingIndex >= 0) {
            final current = sessionRequests[existingIndex];
            final responseSession =
                data['session'] is Map ? data['session'] as Map : null;
            final expiresAt = responseSession != null
                ? _parseDateOrNow(responseSession['expiresAt'])
                : current.expiresAt;

            setState(() {
              sessionRequests[existingIndex] = current.copyWith(
                status: 'accepted',
                expiresAt: expiresAt,
              );
            });
          } else if (status == 'declined') {
            setState(() {
              sessionRequests.removeWhere((request) => request.id == sessionId);
            });
          } else {
            await _loadSessionRequests();
          }

          await _persistAcceptedRequests();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  status == 'accepted'
                      ? l10n.t('requests.acceptedSuccess')
                      : l10n.t('requests.declinedSuccess'),
                ),
                backgroundColor: status == 'accepted'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            );
          }
        } else {
          throw Exception(
              data['message']?.toString() ?? l10n.t('requests.respondFailed'));
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.format('common.errorWithMessage', {'message': e.toString()}),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      print('Error responding to request: $e');
    }
  }

  Future<void> _respondToExtensionRequest(
      SessionExtensionRequest request, String status) async {
    final l10n = context.l10n;
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception(l10n.t('common.noToken'));
      }

      final response = await http.post(
        Uri.parse('$baseUrl/sessions/extend/${request.sessionId}/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (!mounted) return;
        setState(() {
          extensionRequests
              .removeWhere((item) => item.sessionId == request.sessionId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  (status == 'accepted'
                      ? 'Session extension approved'
                      : 'Session extension declined'),
            ),
            backgroundColor: status == 'accepted'
                ? Colors.green
                : Theme.of(context).colorScheme.error,
          ),
        );
        await _loadSessionRequests();
        return;
      }

      throw Exception(
          data['message']?.toString() ?? 'Failed to respond to extension');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(l10n.format('common.errorWithMessage', {'message': '$e'})),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _openPreviousSessions(SessionRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorSessionsScreen(
          doctorId: request.doctor.id,
          doctorName: request.doctor.name,
        ),
      ),
    );
  }

  void _chatWithDoctor(SessionRequest request) {
    if (request.doctor.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor chat is unavailable right now.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          counterpartId: request.doctor.id,
          counterpartName: "Dr. ${request.doctor.name}",
          counterpartRole: "doctor",
          sessionId: request.id,
        ),
      ),
    );
  }

  void _openOldSessionsOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AppointmentsPage(initialTab: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.t('requests.title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: Navigator.canPop(context),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatThreadsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'View old sessions',
            onPressed: _openOldSessionsOverview,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessionRequests,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (isLoading) {
      return Center(
        child: Lottie.asset(
          'assets/twodotloading.json',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('requests.errorTitle'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessionRequests,
              child: Text(l10n.t('common.retry')),
            ),
          ],
        ),
      );
    }

    if (sessionRequests.isEmpty && extensionRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('requests.noRequestsTitle'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('requests.noRequestsSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessionRequests,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ...extensionRequests.map(_buildExtensionRequestCard),
          ...sessionRequests.map(_buildRequestCard),
        ],
      ),
    );
  }

  Widget _buildExtensionRequestCard(SessionExtensionRequest request) {
    final doctor = request.doctor;
    final isExpired = request.currentExpiresAt.isBefore(DateTime.now());

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: doctor.profilePicture != null
                      ? NetworkImage(doctor.profilePicture!)
                      : null,
                  child: doctor.profilePicture == null
                      ? const Icon(Icons.access_time_rounded)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dr. ${doctor.name}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Requested +${request.minutes} minutes",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Pending",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isExpired
                  ? "The current session has already expired."
                  : "Approve to extend the active session before it expires.",
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isExpired
                        ? null
                        : () => _respondToExtensionRequest(request, 'accepted'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isExpired
                        ? null
                        : () => _respondToExtensionRequest(request, 'declined'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text("Decline"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(SessionRequest request) {
    final l10n = context.l10n;
    final doctor = request.doctor;
    final status = request.status.toLowerCase();
    final isAccepted = status == 'accepted';
    final isPending = status == 'pending';
    final timeLeft = request.expiresAt.difference(DateTime.now());
    final isExpired = timeLeft.inSeconds <= 0;

    // Format time as MM:SS
    String formatTime(Duration duration) {
      if (duration.isNegative) return "00:00";
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }

    final statusColor = isExpired
        ? Theme.of(context).colorScheme.error
        : (isAccepted ? Colors.green : Theme.of(context).colorScheme.primary);
    final statusText = isExpired
        ? l10n.t('requests.expired')
        : isAccepted
            ? "Active session - ${formatTime(timeLeft)} left"
            : l10n.format(
                'requests.timeRemaining', {'time': formatTime(timeLeft)});

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Info Row
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: doctor.profilePicture != null
                      ? NetworkImage(doctor.profilePicture!)
                      : null,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  onBackgroundImageError: doctor.profilePicture != null
                      ? (exception, stackTrace) {
                          // Silently handle error - fallback icon will show
                        }
                      : null,
                  child: doctor.profilePicture == null
                      ? Icon(Icons.person,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (doctor.specialization != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialization!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Time indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.schedule,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Experience info
            if (doctor.experience != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.work_outline,
                      size: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                  const SizedBox(width: 8),
                  Text(
                    l10n.format('requests.doctorExperience',
                        {'experience': doctor.experience!}),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ],
              ),
            ],

            // Request message
            if (request.requestMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3)),
                ),
                child: Text(
                  request.requestMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (isPending && !isExpired) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          _respondToRequest(request.id, 'accepted'),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.t('requests.accept')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          _respondToRequest(request.id, 'declined'),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(l10n.t('requests.decline')),
                    ),
                  ),
                ],
              ),
            ] else if (isAccepted && !isExpired) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                ),
                child: const Text(
                  "Access accepted. This card stays here until the session expires.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _chatWithDoctor(request),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Chat with doctor'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPreviousSessions(request),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('View old sessions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
