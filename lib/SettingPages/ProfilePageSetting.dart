import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../Document_model.dart';
import '../api_service.dart';

class ProfileName extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileName({super.key, required this.userData});

  @override
  State<ProfileName> createState() => _ProfileNameState();
}

class _ProfileNameState extends State<ProfileName> {
  late Map<String, dynamic> user;
  bool _loading = true;
  Map<String, List<dynamic>> medicalRecords = {
    "reports": [],
    "prescriptions": [],
    "bills": [],
    "insurance": [],
  };

  @override
  void initState() {
    super.initState();
    user = widget.userData;
    _fetchProfile();
    _fetchMedicalRecords();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("authToken");
      if (token == null) return;

      final response = await http.get(
        Uri.parse("https://backend-medicalvault.onrender.com/api/auth/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          user = body["data"]["user"];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print("❌ Fetch error: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMedicalRecords() async {
    try {
      final email = user['email'];
      if (email == null) {
        print("❌ No email found in user data");
        return;
      }

      print("🔍 Fetching medical records for email: $email");

      // ✅ Use the new API service method
      final response = await ApiService.fetchGroupedDocsByEmail(email);

      print("📋 API Response: $response");

      if (response != null && response['success'] == true) {
        final records = response['records'];
        print("📁 Records structure: $records");

        if (records != null) {
          setState(() {
            medicalRecords = {
              "reports":
                  List<Map<String, dynamic>>.from(records["reports"] ?? []),
              "prescriptions": List<Map<String, dynamic>>.from(
                  records["prescriptions"] ?? []),
              "bills": List<Map<String, dynamic>>.from(records["bills"] ?? []),
              "insurance":
                  List<Map<String, dynamic>>.from(records["insurance"] ?? []),
            };
          });

          print(
              "✅ Medical records loaded: Reports: ${medicalRecords["reports"]?.length ?? 0}, "
              "Prescriptions: ${medicalRecords["prescriptions"]?.length ?? 0}, "
              "Bills: ${medicalRecords["bills"]?.length ?? 0}, "
              "Insurance: ${medicalRecords["insurance"]?.length ?? 0}");
        } else {
          print("❌ Records is null in response");
        }
      } else {
        print("❌ Error fetching records - Response: $response");
        print("❌ Success flag: ${response?['success']}");
        print("❌ Error message: ${response?['msg']}");
      }
    } catch (e) {
      print("❌ Medical Records fetch error: $e");
      setState(() {
        medicalRecords = {
          "reports": [],
          "prescriptions": [],
          "bills": [],
          "insurance": [],
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Lottie.asset(
            'assets/twodotloading.json',
            width: 150,
            height: 150,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header
              Card(
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(
                            'https://cdn-icons-png.flaticon.com/512/9203/9203764.png'),
                      ),
                      const SizedBox(height: 8),
                      Text(user['name'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(user['email'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
              ),

              // Sections
              _sectionTitle("Personal Information"),
              _infoRow(Icons.phone, "Mobile", user['mobile'] ?? ''),
              _infoRow(Icons.security, "Aadhaar", user['aadhaar'] ?? ''),
              _infoRow(Icons.calendar_today, "DOB",
                  user['dateOfBirth']?.toString().split("T")[0] ?? ''),

              _sectionTitle("Health Information"),
              _infoRow(Icons.person, "Gender", user['gender'] ?? ''),
              _infoRow(Icons.water_drop, "Blood Type", user['bloodType'] ?? ''),
              _infoRow(Icons.healing, "Allergies",
                  (user['allergies'] ?? '').toString()),
              _infoRow(Icons.height, "Height", user['height'] ?? ''),
              _infoRow(Icons.monitor_weight, "Weight", user['weight'] ?? ''),
              _infoRow(Icons.calendar_month, "Last Visit",
                  user['lastVisit']?.toString().split("T")[0] ?? ''),
              _infoRow(Icons.event, "Next Appointment",
                  user['nextAppointment']?.toString().split("T")[0] ?? ''),

              _sectionTitle("Emergency Contact"),
              _infoRow(Icons.person, "Name",
                  user['emergencyContact']?['name'] ?? ''),
              _infoRow(Icons.people, "Relationship",
                  user['emergencyContact']?['relationship'] ?? ''),
              _infoRow(Icons.phone, "Phone",
                  user['emergencyContact']?['phone'] ?? ''),

              _sectionTitle("Medical History"),
              _listSection(
                  user['medicalHistory'] ?? [],
                  (item) =>
                      "${item['condition']} (${item['status']}) - ${item['diagnosed']}"),

              _sectionTitle("Medications"),
              _listSection(
                  user['medications'] ?? [],
                  (item) =>
                      "${item['name']} - ${item['dosage']} (${item['frequency']})"),

              _medicalRecordsSection(),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(userData: user),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        user = result;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(value.isNotEmpty ? value : "N/A",
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _listSection(List items, String Function(dynamic) format) {
    return items.isEmpty
        ? Text("No data available",
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).hintColor))
        : Column(
            children: items
                .map<Widget>((item) => Card(
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                          title: Text(format(item),
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ))
                .toList(),
          );
  }

  Widget _medicalRecordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Medical Records"),
        _recordCategoryTile("Reports", medicalRecords["reports"] ?? []),
        _recordCategoryTile(
            "Prescriptions", medicalRecords["prescriptions"] ?? []),
        _recordCategoryTile("Bills", medicalRecords["bills"] ?? []),
        _recordCategoryTile("Insurance", medicalRecords["insurance"] ?? []),
      ],
    );
  }

  Widget _recordCategoryTile(String title, List items) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        children: items.isEmpty
            ? [
                ListTile(
                    title: Text("No records available",
                        style: Theme.of(context).textTheme.bodyMedium))
              ]
            : items.map<Widget>((item) {
                // ✅ Convert to Document object for consistent handling
                final document = Document.fromApi(item);

                return ListTile(
                  leading: _getFileIcon(document.fileType ?? ""),
                  title: Text(document.title ?? "Untitled",
                      style: Theme.of(context).textTheme.bodyLarge),
                  subtitle: Text(
                      "${document.date ?? 'Unknown date'} • ${document.fileType ?? 'Unknown type'}",
                      style: Theme.of(context).textTheme.bodySmall),
                  // ✅ No onTap - just show metadata as requested
                );
              }).toList(),
      ),
    );
  }

  // ✅ Helper method to get appropriate file icon
  Widget _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    if (type.contains("pdf")) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (type.startsWith("image/")) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (type.contains("word")) {
      return const Icon(Icons.description, color: Colors.blue);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }
}

// ================= Edit Profile Page =================

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  List<Map<String, dynamic>> medicalHistory = [];
  List<Map<String, dynamic>> medications = [];

  @override
  void initState() {
    super.initState();
    for (var field in [
      "name",
      "email",
      "mobile",
      "aadhaar",
      "dateOfBirth",
      "age",
      "gender",
      "bloodType",
      "height",
      "weight",
      "allergies",
      "lastVisit",
      "nextAppointment",
      "Emergency Contact Name",
      "Emergency Contact Relationship",
      "Emergency Contact Phone"
    ]) {
      String value = "";
      if (field.startsWith("ec")) {
        String ecField = field.substring(2).toLowerCase();
        value = widget.userData["emergencyContact"]?[ecField]?.toString() ?? "";
      } else {
        value = widget.userData[field]?.toString() ?? "";
      }
      _controllers[field] = TextEditingController(text: value);
    }

    medicalHistory = List<Map<String, dynamic>>.from(
        widget.userData["medicalHistory"] ?? []);
    medications =
        List<Map<String, dynamic>>.from(widget.userData["medications"] ?? []);
  }

  Future<void> _selectDate(BuildContext context, String fieldKey) async {
    DateTime initialDate =
        DateTime.tryParse(_controllers[fieldKey]!.text) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _controllers[fieldKey]!.text = picked.toIso8601String().split("T")[0];
      });
    }
  }

  void _addMedicalHistory() {
    final conditionController = TextEditingController();
    final statusController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Medical History"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: conditionController,
                decoration: const InputDecoration(labelText: "Condition")),
            TextField(
                controller: statusController,
                decoration: const InputDecoration(
                    labelText: "Status (active/resolved/chronic)")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                medicalHistory.add({
                  "condition": conditionController.text,
                  "status": statusController.text,
                  "diagnosed": DateTime.now().toIso8601String(),
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _addMedication() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final freqController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Medication"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Medicine Name")),
            TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: "Dosage")),
            TextField(
                controller: freqController,
                decoration: const InputDecoration(labelText: "Frequency")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                medications.add({
                  "name": nameController.text,
                  "dosage": dosageController.text,
                  "frequency": freqController.text,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(Map<String, dynamic> updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("authToken");
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse("https://backend-medicalvault.onrender.com/api/auth/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode(updatedUser),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await prefs.setString('userData', jsonEncode(body["data"]));
        Navigator.pop(context, body["data"]);
      } else {
        print("❌ Error: ${response.body}");
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              for (var field in _controllers.keys)
                Column(
                  children: [
                    TextFormField(
                      controller: _controllers[field],
                      readOnly: field == "dateOfBirth" ||
                          field == "lastVisit" ||
                          field == "nextAppointment",
                      onTap: (field == "dateOfBirth" ||
                              field == "lastVisit" ||
                              field == "nextAppointment")
                          ? () => _selectDate(context, field)
                          : null,
                      decoration: InputDecoration(
                        labelText: field,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Medical History
              // Medical History
              const Text("Medical History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...medicalHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final mh = entry.value;
                return Dismissible(
                  key: Key("mh_$index"),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      medicalHistory.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Medical history deleted")),
                    );
                  },
                  child: ListTile(
                    title: Text(mh["condition"]),
                    subtitle: Text(mh["status"]),
                  ),
                );
              }),
              ElevatedButton(
                  onPressed: _addMedicalHistory,
                  child: const Text("Add Medical History")),

              const SizedBox(height: 20),

              // Medications
              const Text("Medications",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...medications.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                return Dismissible(
                  key: Key("med_$index"),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      medications.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Medication deleted")),
                    );
                  },
                  child: ListTile(
                    title: Text(med["name"]),
                    subtitle: Text("${med["dosage"]} - ${med["frequency"]}"),
                  ),
                );
              }),
              ElevatedButton(
                  onPressed: _addMedication,
                  child: const Text("Add Medication")),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final updatedUser = {
                      "name": _controllers["name"]!.text,
                      "email": _controllers["email"]!.text,
                      "mobile": _controllers["mobile"]!.text,
                      "aadhaar": _controllers["aadhaar"]!.text,
                      "dateOfBirth": _controllers["dateOfBirth"]!.text,
                      "age": int.tryParse(_controllers["age"]!.text),
                      "gender": _controllers["gender"]!.text,
                      "bloodType": _controllers["bloodType"]!.text,
                      "height": _controllers["height"]!.text,
                      "weight": _controllers["weight"]!.text,
                      "allergies": _controllers["allergies"]!.text,
                      "lastVisit": _controllers["lastVisit"]!.text,
                      "nextAppointment": _controllers["nextAppointment"]!.text,
                      "emergencyContact": {
                        "name": _controllers["Emergency Contact Name"]!.text,
                        "relationship":
                            _controllers["Emergency Contact Relationship"]!
                                .text,
                        "phone": _controllers["Emergency Contact Phone"]!.text,
                      },
                      "medicalHistory": medicalHistory,
                      "medications": medications,
                    };
                    await _saveProfile(updatedUser);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("Save Changes",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
