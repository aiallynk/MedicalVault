import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'Document_model.dart';
import 'UploadDocument.dart';
import 'api_service.dart';
import 'main.dart';

// ================= DOCUMENT DETAIL PAGE =================
class DocumentDetailPage extends StatelessWidget {
  final Document document;

  const DocumentDetailPage({super.key, required this.document});

  Future<void> _previewFile(BuildContext context) async {
    if (document.id == null || document.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document ID is missing")),
      );
      return;
    }

    try {
      final ext = document.fileName?.split('.').last.toLowerCase() ?? '';

      if (ext == 'pdf') {
        // ✅ Use backend preview endpoint to get signed URL for PDFs
        final previewUrl = await _getPreviewUrl(document.id!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewPage(
              url: previewUrl,
              title: document.title ?? document.fileName ?? 'PDF Preview',
            ),
          ),
        );
      } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
        // ✅ Use backend preview endpoint for images too
        final previewUrl = await _getPreviewUrl(document.id!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewPage(
              url: previewUrl,
              title: document.title ?? 'Image Preview',
            ),
          ),
        );
      } else {
        await _downloadAndOpenFile(context);
      }
    } catch (e) {
      debugPrint("❌ Error previewing: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }

  Future<String> _getPreviewUrl(String documentId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final dio = Dio();
      final response = await dio.get(
        "${ApiService.baseUrl}/files/$documentId/preview",
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['signedUrl'];
      } else {
        throw Exception(
            'Failed to get preview URL: ${response.data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint("❌ Error getting preview URL: $e");
      throw Exception('Failed to get preview URL: $e');
    }
  }

  Future<void> _downloadAndOpenFile(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${document.fileName}';
      final dio = Dio();

      final token = await ApiService.getToken();
      if (token != null) dio.options.headers['Authorization'] = 'Bearer $token';

      await dio.download(
          "${ApiService.baseUrl}/files/${document.id}/download", filePath);
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint("❌ Download+Open error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      if (document.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid file ID")),
        );
        return;
      }

      // No broad storage permissions needed; save to app-scoped directory

      // Prefer app-scoped directory to avoid broad permissions
      final dir = Platform.isAndroid
          ? await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory()
          : await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${document.fileName ?? "file"}';

      final dio = Dio();
      final token = await ApiService.getToken();
      final options = Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status! < 500, // Allow 4xx errors to be handled
      );

      await dio.download(
          "${ApiService.baseUrl}/files/${document.id}/download", filePath,
          options: options);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ File downloaded: $filePath")),
      );
    } catch (e) {
      debugPrint("❌ Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title ?? "Untitled")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Category: ${document.category ?? 'Unknown'}",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Uploaded on: ${document.date ?? 'Unknown'}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _previewFile(context),
                  icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  label: const Text("Preview"),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _downloadFile(context),
                  icon: const Icon(Icons.download, color: Colors.blue),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  label: const Text("Download"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================= MY VAULT =================
class MyVault extends StatefulWidget {
  final String userId;

  const MyVault({super.key, required this.userId});

  static final List<Document> _allDocuments = [];

  static void addDocument(Document doc) => _allDocuments.add(doc);
  static void removeDocument(String docId) =>
      _allDocuments.removeWhere((doc) => doc.id == docId);

  @override
  State<MyVault> createState() => _MyVaultState();
}

class _MyVaultState extends State<MyVault> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  final List<String> _categories = [
    "All",
    "Report",
    "Prescription",
    "Bill",
    "Insurance",
  ];
  String _selectedCategory = "All";

  String _selectedSort = "Today";
  final List<String> _sortOptions = [
    "Today",
    "Last 2 days",
    "Last 7 days",
    "Last 30 days"
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadDocumentsFromAPI();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentsFromAPI() async {
    setState(() => _isLoading = true);
    MyVault._allDocuments.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId");

      if (userId != null) {
        final docs = await ApiService.fetchMyDocs(userId);
        MyVault._allDocuments.addAll(docs);
        debugPrint("✅ Loaded ${docs.length} documents for user: $userId");
      } else {
        debugPrint("❌ No userId found in SharedPreferences");
      }
    } catch (e) {
      debugPrint("❌ Error loading documents: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<Document> _filterAndSortDocuments() {
    final query = _searchController.text.toLowerCase();
    final now = DateTime.now();

    var docs = _selectedCategory == "All"
        ? MyVault._allDocuments
        : MyVault._allDocuments
            .where((doc) =>
                (doc.category ?? '').toLowerCase() ==
                _selectedCategory.toLowerCase())
            .toList();

    docs = docs
        .where((doc) => (doc.title ?? '').toLowerCase().contains(query))
        .toList();

    docs = docs.where((doc) {
      if (doc.date == null) return false;
      final docDate = DateTime.tryParse(doc.date!);
      if (docDate == null) return false;
      final difference = now.difference(docDate).inDays;
      switch (_selectedSort) {
        case "Today":
          return difference == 0;
        case "Last 2 days":
          return difference <= 1;
        case "Last 7 days":
          return difference <= 7;
        case "Last 30 days":
          return difference <= 30;
        default:
          return true;
      }
    }).toList();

    docs.sort((a, b) {
      final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return docs;
  }

  Future<void> _openFile(Document document) async {
    if (document.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid document")),
      );
      return;
    }

    final fileType = (document.fileType ?? "").toLowerCase();
    final fileName = document.fileName ?? "";
    debugPrint("🔍 Opening file: $fileName ($fileType)");

    try {
      if (fileType.contains("pdf")) {
        // ✅ Always download and open PDFs externally
        await _downloadAndOpenFile(document);
      } else if (fileType.startsWith("image/") ||
          fileName.toLowerCase().endsWith(".jpg") ||
          fileName.toLowerCase().endsWith(".jpeg") ||
          fileName.toLowerCase().endsWith(".png")) {
        // ✅ Use backend preview endpoint for images
        final previewUrl = await _getPreviewUrl(document.id!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewPage(
              url: previewUrl,
              title: document.title ?? 'Image Preview',
            ),
          ),
        );
      } else {
        // ✅ Fallback: download & open locally
        await _downloadAndOpenFile(document);
      }
    } catch (e) {
      debugPrint("❌ Preview error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open file: $e")),
      );
    }
  }

  Future<String> _getPreviewUrl(String documentId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final dio = Dio();
      final response = await dio.get(
        "${ApiService.baseUrl}/files/$documentId/preview",
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['signedUrl'];
      } else {
        throw Exception(
            'Failed to get preview URL: ${response.data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint("❌ Error getting preview URL: $e");
      throw Exception('Failed to get preview URL: $e');
    }
  }

  Future<void> _downloadFile(Document document) async {
    try {
      if (document.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid document ID")),
        );
        return;
      }

      if (Platform.isAndroid) {
        // Request both storage permissions for Android 11+
        final storageStatus = await Permission.storage.request();
        await Permission.manageExternalStorage.request();

        if (!storageStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission required")),
          );
          return;
        }
      }

      // Use Downloads directory
      final dir = Platform.isAndroid
          ? Directory("/storage/emulated/0/Download")
          : await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${document.fileName ?? "file"}';

      final dio = Dio();
      final token = await ApiService.getToken();
      final options = Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status! < 500, // Allow 4xx errors to be handled
      );

      await dio.download(
          "${ApiService.baseUrl}/files/${document.id}/download", filePath,
          options: options);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ File downloaded to Downloads folder")),
      );
    } catch (e) {
      debugPrint("❌ Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  Future<void> _downloadAndOpenFile(Document document) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${document.fileName ?? "file"}';
      final dio = Dio();
      final token = await ApiService.getToken();
      final options = Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status! < 500, // Allow 4xx errors to be handled
      );

      await dio.download(
          "${ApiService.baseUrl}/files/${document.id}/download", filePath,
          options: options);
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint("❌ Download and open error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  Future<void> _deleteFile(Document document) async {
    try {
      final success = await ApiService.deleteDocument(document.id!);
      if (success) {
        setState(() {
          MyVault.removeDocument(document.id!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ File deleted")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Delete failed")),
        );
      }
    } catch (e) {
      debugPrint("❌ Delete error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure status bar is configured
    StatusBarHelper.setStatusBarStyle(context);

    final docs = _filterAndSortDocuments();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 Search Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // 🏷️ Categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // ⏳ Sort Dropdown
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Sort",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: 160,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSort,
                      items: _sortOptions
                          .map((option) => DropdownMenuItem(
                                value: option,
                                child: Text(option),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSort = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 📂 Documents List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Lottie.asset(
                        'assets/twodotloading.json',
                        width: 150,
                        height: 150,
                      ),
                    )
                  : docs.isEmpty
                      ? const Center(child: Text("No documents found"))
                      : ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file,
                                    color: Colors.blue),
                                title: Text(doc.title ?? "Untitled"),
                                subtitle: Text("${doc.category} • ${doc.date}",
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye,
                                          color: Colors.green),
                                      onPressed: () => _openFile(doc),
                                      tooltip: "Preview",
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download,
                                          color: Colors.blue),
                                      onPressed: () => _downloadFile(doc),
                                      tooltip: "Download",
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deleteFile(doc),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // 📤 Upload Button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF42A5F5),
                      Color(0xFF26C6DA),
                      Color(0xFF80DEEA)
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadDocument(
                          userId: widget.userId,
                        ),
                      ),
                    );
                    _loadDocumentsFromAPI();
                  },
                  icon: const Icon(Icons.upload, color: Colors.white),
                  label: const Text('Upload Document',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- PDF Preview Page ----------------
class PdfPreviewPage extends StatefulWidget {
  final String url;
  final String title;

  const PdfPreviewPage({super.key, required this.url, required this.title});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  bool _isLoading = true;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Add a small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));

      // Set up a timeout for the PDF loading
      await Future.delayed(const Duration(seconds: 1));

      // The SfPdfViewer will handle the actual loading
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _retryLoadPdf() async {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
        _isLoading = true;
        _error = null;
      });

      // Add exponential backoff delay
      await Future.delayed(Duration(seconds: _retryCount * 2));
      _loadPdf();
    } else {
      setState(() {
        _error =
            'Failed to load PDF after $_maxRetries attempts. Please check your internet connection and try again.';
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load PDF',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryLoadPdf,
              icon: const Icon(Icons.refresh),
              label: Text(_retryCount > 0
                  ? 'Retry (${_retryCount}/$_maxRetries)'
                  : 'Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SfPdfViewer.network(
          widget.url,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            setState(() {
              _isLoading = false;
              _error = details.error;
            });
            // ✅ Fallback: open externally if viewer fails
            OpenFile.open(widget.url);
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.8),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading PDF...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------- Image Preview Page ----------------
class ImagePreviewPage extends StatefulWidget {
  final String url;
  final String title;

  const ImagePreviewPage({super.key, required this.url, required this.title});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  String? _imageDataUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAuthenticatedImage();
  }

  Future<void> _loadAuthenticatedImage() async {
    try {
      // Check if the URL is a signed URL (contains query parameters)
      // Signed URLs don't need additional authentication
      final isSignedUrl = widget.url.contains('?');

      if (isSignedUrl) {
        // For signed URLs, use them directly without additional auth headers
        setState(() {
          _imageDataUrl = widget.url;
          _isLoading = false;
        });
      } else {
        // For non-signed URLs, use authentication
        final token = await ApiService.getToken();
        if (token == null) {
          setState(() {
            _error = 'No authentication token available';
            _isLoading = false;
          });
          return;
        }

        // Download to temp file first to avoid memory issues
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final dio = Dio();
        await dio.download(
          widget.url,
          tempFile.path,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            validateStatus: (status) =>
                status! < 500, // Allow 4xx errors to be handled
          ),
        );

        if (await tempFile.exists()) {
          setState(() {
            _imageDataUrl = tempFile.path; // Use file path directly
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Failed to download image';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading image: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAuthenticatedImage,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : _imageDataUrl != null
                    ? InteractiveViewer(
                        child: (_imageDataUrl!.startsWith('http')
                            ? Image.network(
                                _imageDataUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 64, color: Colors.red),
                                        SizedBox(height: 16),
                                        Text('Failed to load image'),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : Image.file(
                                File(_imageDataUrl!),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 64, color: Colors.red),
                                        SizedBox(height: 16),
                                        Text('Failed to load image'),
                                      ],
                                    ),
                                  );
                                },
                              )),
                      )
                    : const Text('No image data available'),
      ),
    );
  }
}
