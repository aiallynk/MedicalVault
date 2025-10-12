import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:permission_handler/permission_handler.dart';

import 'Document_model.dart';
import 'api_service.dart';
import 'main.dart';

class CategoryVaultPage extends StatefulWidget {
  final String category;
  final String userId;

  const CategoryVaultPage({
    super.key,
    required this.category,
    required this.userId,
  });

  @override
  State<CategoryVaultPage> createState() => _CategoryVaultPageState();
}

class _CategoryVaultPageState extends State<CategoryVaultPage> {
  List<Document> files = [];
  List<Document> filteredFiles = [];
  bool _isLoading = true;
  final Dio dio = Dio();

  // Time filter options
  String selectedTimeFilter = 'All';
  final List<String> timeFilterOptions = [
    'All',
    '1 Month',
    '3 Months',
    '6 Months',
    '12 Months'
  ];

  // Search and sort state
  final TextEditingController _searchController = TextEditingController();

  // Combined sort options (date + name)
  String _selectedSort = 'Newest First';
  final List<String> sortOptions = [
    'Newest First',
    'Oldest First',
    'Name A-Z',
    'Name Z-A',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to apply date filter
  List<Document> _applyDateFilter(List<Document> docs) {
    if (selectedTimeFilter == 'All') {
      return docs;
    }

    final now = DateTime.now();
    int dayLimit;

    switch (selectedTimeFilter) {
      case '1 Month':
        dayLimit = 30;
        break;
      case '3 Months':
        dayLimit = 90;
        break;
      case '6 Months':
        dayLimit = 180;
        break;
      case '12 Months':
        dayLimit = 365;
        break;
      default:
        return docs;
    }

    return docs.where((doc) {
      if (doc.date == null || doc.date!.isEmpty) {
        return false; // Exclude documents without date
      }

      final docDate = DateTime.tryParse(doc.date!);
      if (docDate == null) {
        return false; // Exclude documents with invalid date
      }

      final daysDifference = now.difference(docDate).inDays;
      return daysDifference <= dayLimit;
    }).toList();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final docs = await ApiService.fetchMyDocs(widget.userId);

      // ✅ Filter by normalizedType from model
      final categoryFiltered = docs.where((d) {
        switch (widget.category.toLowerCase()) {
          case "reports":
          case "report":
            return d.normalizedType == "report";
          case "prescriptions":
          case "prescription":
            return d.normalizedType == "prescription";
          case "bills":
          case "bill":
            return d.normalizedType == "bill";
          case "insurance":
          case "insurance details":
            return d.normalizedType == "insurance";
          default:
            return false;
        }
      }).toList();

      setState(() {
        files = categoryFiltered; // Store all category files
        filteredFiles =
            _recomputeFilteredFiles(); // Apply all filters for display
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("⚠️ Error loading files: $e");
    }
  }

  // Handle filter change
  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != selectedTimeFilter) {
      setState(() {
        selectedTimeFilter = newFilter;
        filteredFiles = _recomputeFilteredFiles();
      });
    }
  }

  void _onSortChanged(String? newSort) {
    if (newSort != null && newSort != _selectedSort) {
      setState(() {
        _selectedSort = newSort;
        filteredFiles = _recomputeFilteredFiles();
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      filteredFiles = _recomputeFilteredFiles();
    });
  }

  List<Document> _recomputeFilteredFiles() {
    // Start from category files and apply date filter
    final dateFiltered = _applyDateFilter(files);

    // Apply search by title/fileName
    final query = _searchController.text.trim().toLowerCase();
    var results = dateFiltered.where((doc) {
      final name = (doc.title ?? doc.fileName ?? '').toLowerCase();
      if (query.isEmpty) return true;
      return name.contains(query);
    }).toList();

    // Apply sorting based on selected option
    int compareByName(Document a, Document b) {
      final aName = (a.title ?? a.fileName ?? '').toLowerCase();
      final bName = (b.title ?? b.fileName ?? '').toLowerCase();
      return aName.compareTo(bName);
    }

    switch (_selectedSort) {
      case 'Name A-Z':
        results.sort(compareByName);
        break;
      case 'Name Z-A':
        results.sort((a, b) => -compareByName(a, b));
        break;
      case 'Oldest First':
        results.sort((a, b) {
          final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime(1970);
          return dateA.compareTo(dateB); // Ascending
        });
        break;
      case 'Newest First':
      default:
        results.sort((a, b) {
          final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA); // Descending
        });
        break;
    }

    return results;
  }

  // ---------------- OPEN FILE ----------------
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

  // ---------------- DOWNLOAD & OPEN LOCALLY ----------------
  Future<void> _downloadAndOpenFile(Document document) async {
    if (document.id == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${document.fileName ?? "file"}';
      final url = '${ApiService.baseUrl}/files/${document.id}/download';

      // ✅ Add authentication headers for this specific request
      final token = await ApiService.getToken();
      final options = Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status! < 500, // Allow 4xx errors to be handled
      );

      await dio.download(url, filePath, options: options);
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint("❌ Download and open error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  // ---------------- DOWNLOAD ONLY ----------------
  Future<void> _downloadFile(Document document) async {
    if (document.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid document ID")),
      );
      return;
    }

    try {
      // No broad storage permissions needed; save to app-scoped directory

      // Prefer app-scoped Downloads/documents directory to avoid broad permissions
      final dir = Platform.isAndroid
          ? await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory()
          : await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${document.fileName ?? "file"}';

      // ✅ All files → use backend download endpoint with auth
      final downloadUrl = '${ApiService.baseUrl}/files/${document.id}/download';

      final token = await ApiService.getToken();
      final options = Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status! < 500, // Allow 4xx errors to be handled
      );

      await dio.download(downloadUrl, filePath, options: options);

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

  // ---------------- DELETE ----------------
  Future<void> _deleteFile(Document document) async {
    if (document.id == null || document.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid document id")),
      );
      return;
    }

    try {
      debugPrint("🗑 Deleting file with id=${document.id}");
      final success = await ApiService.deleteDocument(document.id!);

      if (success) {
        setState(() {
          files.remove(document);
          filteredFiles.remove(document);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Document deleted")),
        );
      } else {
        throw Exception("Server rejected delete for id=${document.id}");
      }
    } catch (e) {
      debugPrint("❌ Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to delete document: $e")),
      );
    }
  }

  // ---------------- THUMBNAIL ----------------
  Widget _buildThumbnail(Document document) {
    final fileType = (document.fileType ?? "").toLowerCase();
    if (fileType.startsWith("image/")) {
      // For thumbnails, use a simple icon instead of loading the full image
      // This prevents ANR issues and improves performance
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image,
          color: Colors.grey,
          size: 30,
        ),
      );
    } else if (fileType.contains("pdf")) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40);
    } else if (fileType.contains("word")) {
      return const Icon(Icons.description, color: Colors.blue, size: 40);
    }
    return const Icon(Icons.insert_drive_file, color: Colors.grey, size: 40);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    // Ensure status bar is configured
    StatusBarHelper.setStatusBarStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Lottie.asset(
                  "assets/twodotloading.json",
                  width: 150,
                  height: 150,
                ),
              )
            : Column(
                children: [
                  // Filter & Sort controls (Single Line)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Time Filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedTimeFilter,
                            decoration: InputDecoration(
                              labelText: 'Time Filter',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            items: timeFilterOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(option,
                                    style: TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: _onFilterChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sort By
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSort,
                            decoration: InputDecoration(
                              labelText: 'Sort By',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            items: sortOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(option,
                                    style: TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: _onSortChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Document count
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${filteredFiles.length} / ${files.length}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name',
                        prefixIcon: const Icon(Icons.search),
                        fillColor: Theme.of(context).cardColor,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Document list
                  Expanded(
                    child: filteredFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open,
                                    size: 64,
                                    color: Theme.of(context).disabledColor),
                                const SizedBox(height: 16),
                                Text(
                                  files.isEmpty
                                      ? "No documents uploaded yet"
                                      : "No documents found for selected time period",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          fontSize: 18,
                                          color: Theme.of(context).hintColor),
                                ),
                                Text(
                                  files.isEmpty
                                      ? "Upload documents to see them here"
                                      : "Try selecting a different time filter",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredFiles.length,
                            itemBuilder: (context, index) {
                              final file = filteredFiles[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: _buildThumbnail(file),
                                  title: Text(file.title ?? "Untitled"),
                                  subtitle: Text(
                                    'Uploaded: ${file.date ?? ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_red_eye,
                                            color: Colors.blue),
                                        onPressed: () => _openFile(file),
                                        tooltip: "Preview",
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.download,
                                            color: Colors.green),
                                        onPressed: () => _downloadFile(file),
                                        tooltip: "Download",
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteFile(file),
                                        tooltip: "Delete",
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
