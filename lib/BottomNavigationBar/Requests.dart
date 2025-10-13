import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:hello/main.dart';

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
    return SessionRequest(
      id: json['_id'],
      doctor: Doctor.fromJson(json['doctor']),
      requestMessage: json['requestMessage'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      status: json['status'],
    );
  }
}

// Doctor Model
class Doctor {
  final String id;
  final String name;
  final String email;
  final String? profilePicture;
  final String? experience;
  final String? specialization;
  final DateTime? memberSince;

  Doctor({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicture,
    this.experience,
    this.specialization,
    this.memberSince,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      profilePicture: json['profilePicture'],
      experience: json['experience'],
      specialization: json['specialization'],
      memberSince: json['memberSince'] != null
          ? DateTime.parse(json['memberSince'])
          : null,
    );
  }
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<SessionRequest> sessionRequests = [];
  bool isLoading = true;
  String? errorMessage;

  static const String baseUrl = "https://backend-medicalvault.onrender.com/api";

  @override
  void initState() {
    super.initState();
    _loadSessionRequests();
  }

  // Get auth token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Fetch session requests from API
  Future<void> _loadSessionRequests() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
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
          final List<dynamic> requestsJson = data['requests'];
          setState(() {
            sessionRequests = requestsJson
                .map((json) => SessionRequest.fromJson(json))
                .toList();
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load requests');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      print('Error loading session requests: $e');
    }
  }

  // Respond to session request (accept/decline)
  Future<void> _respondToRequest(String sessionId, String status) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
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
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Request ${status} successfully'),
                backgroundColor:
                    status == 'accepted' ? Colors.green : Colors.red,
              ),
            );

            // Reload requests to update the list
            _loadSessionRequests();
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to respond to request');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error responding to request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure status bar is configured
    StatusBarHelper.setStatusBarStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Doctor Requests",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to previous screen
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessionRequests,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
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
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessionRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (sessionRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any doctor access requests at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessionRequests,
      child: ListView.builder(
        itemCount: sessionRequests.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final request = sessionRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(SessionRequest request) {
    final doctor = request.doctor;
    final timeLeft = request.expiresAt.difference(DateTime.now());
    final isExpired = timeLeft.isNegative;

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
                  backgroundColor: Colors.blue[100],
                  child: doctor.profilePicture == null
                      ? const Icon(Icons.person, color: Colors.blue)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                      if (doctor.specialization != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialization!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
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
                      isExpired ? Icons.schedule : Icons.schedule,
                      color: isExpired ? Colors.red : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpired ? 'Expired' : '${timeLeft.inMinutes}m left',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? Colors.red : Colors.orange,
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
                  const Icon(Icons.work_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Experience: ${doctor.experience}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  request.requestMessage,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    onPressed: isExpired
                        ? null
                        : () => _respondToRequest(request.id, 'accepted'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Accept"),
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
                    onPressed: isExpired
                        ? null
                        : () => _respondToRequest(request.id, 'declined'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Decline"),
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
