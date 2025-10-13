import 'package:flutter/material.dart';
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

class Dashboard1 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Dashboard1({super.key, required this.userData});

  @override
  State<Dashboard1> createState() => _Dashboard1State();
}

class _Dashboard1State extends State<Dashboard1> {
  int _currentIndex = 0;
  late PageController _pageController;

  Map<String, int> _documentCounts = {};
  bool _isLoadingCounts = true;
  List<Map<String, dynamic>> _linkedProfiles = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadDocumentCounts();
    _loadLinkedProfiles();

    // Set status bar style
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusBarHelper.setStatusBarStyle(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Ensure status bar is configured
    StatusBarHelper.setStatusBarStyle(context);

    final passedName = (widget.userData['name'] ?? "").toString();

    return FutureBuilder<String?>(
      future: _getStoredName(),
      builder: (context, snapshot) {
        final userName =
            passedName.isNotEmpty ? passedName : (snapshot.data ?? "Patient");

        return WillPopScope(
          onWillPop: () async {
            // Show confirmation dialog when back button is pressed on dashboard
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit App'),
                content: const Text('Are you sure you want to exit the app?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            );
            return shouldExit ?? false;
          },
          child: SafeArea(
            child: Scaffold(
              body: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                children: [
                  // 🏠 Dashboard tab
                  RefreshIndicator(
                    onRefresh: _loadDocumentCounts,
                    child: ListView(
                      padding: const EdgeInsets.all(30.0),
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showProfileSwitcher(context),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: widget.userData['profilePicture'] != null
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, $userName 👋',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (_linkedProfiles.isNotEmpty)
                                    Text(
                                      '${_linkedProfiles.length + 1} profiles available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showProfileSwitcher(context),
                              icon: Icon(
                                Icons.swap_horiz,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              tooltip: "Switch Profile",
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text("Quick Actions",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0E0E0),
                            child: Icon(Icons.qr_code, color: Colors.black),
                          ),
                          title: const Text('Generate / Share QR'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => QRPage()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0E0E0),
                            child: Icon(Icons.list_alt, color: Colors.black),
                          ),
                          title: const Text('Access Requests'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RequestsPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('My Documents',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            if (!_isLoadingCounts)
                              Text(
                                '${_documentCounts.values.fold(0, (sum, count) => sum + count)} total',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
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
                                "title": "Reports",
                                "image": "assets/Reports.png",
                                "category": "Reports",
                                "count": _documentCounts["Reports"] ?? 0
                              },
                              {
                                "title": "Prescriptions",
                                "image": "assets/Prescription.png",
                                "category": "Prescription",
                                "count": _documentCounts["Prescription"] ?? 0
                              },
                              {
                                "title": "Bills",
                                "image": "assets/2851468.png",
                                "category": "Bill",
                                "count": _documentCounts["Bill"] ?? 0
                              },
                              {
                                "title": "Insurance Details",
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
                        )
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
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BottomNavigationBar(
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
                    items: const [
                      BottomNavigationBarItem(
                          icon: Icon(Icons.home), label: 'Home'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.lock), label: 'Vault'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.qr_code), label: 'QR'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.list_alt), label: 'Requests'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.settings), label: 'Settings'),
                    ],
                    selectedItemColor: Theme.of(context)
                        .bottomNavigationBarTheme
                        .selectedItemColor,
                    unselectedItemColor: Theme.of(context)
                        .bottomNavigationBarTheme
                        .unselectedItemColor,
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
                '$count document${count != 1 ? 's' : ''}',
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
}
