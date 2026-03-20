import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'package:hello/Document_model.dart';
import 'package:hello/UploadDocument.dart';
import 'package:hello/api_service.dart';
import 'package:hello/localization/app_localizations.dart';

// ================= DOCUMENT DETAIL PAGE =================
class DocumentDetailPage extends StatelessWidget {
  final Document document;

  const DocumentDetailPage({super.key, required this.document});

  Future<void> _previewFile(BuildContext context) async {
    final l10n = context.l10n;
    if (document.id == null || document.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('documentDetail.missingId'))),
      );
      return;
    }

    try {
      final ext = document.fileName?.split('.').last.toLowerCase() ?? '';

      if (ext == 'pdf') {
        // ✅ Use backend preview endpoint to get signed URL for PDFs
        final previewUrl = await _getPreviewUrl(context, document.id!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewPage(
              url: previewUrl,
              title: document.title ??
                  document.fileName ??
                  l10n.t('documentDetail.pdfPreviewTitle'),
            ),
          ),
        );
      } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
        // ✅ Use backend preview endpoint for images too
        final previewUrl = await _getPreviewUrl(context, document.id!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewPage(
              url: previewUrl,
              title:
                  document.title ?? l10n.t('documentDetail.imagePreviewTitle'),
            ),
          ),
        );
      } else {
        await _downloadAndOpenFile(context);
      }
    } catch (e) {
      debugPrint("❌ Error previewing: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.format('common.errorWithMessage', {'message': e.toString()}),
          ),
        ),
      );
    }
  }

  Future<String> _getPreviewUrl(BuildContext context, String documentId) async {
    final l10n = context.l10n;
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception(l10n.t('common.noToken'));
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
        throw Exception(l10n.format('documentDetail.previewUrlFailed', {
          'message':
              response.data['message']?.toString() ?? l10n.t('common.unknown')
        }));
      }
    } catch (e) {
      debugPrint("❌ Error getting preview URL: $e");
      throw Exception(
          l10n.format('documentDetail.previewUrlFailed', {'message': '$e'}));
    }
  }

  Future<void> _downloadAndOpenFile(BuildContext context) async {
    final l10n = context.l10n;
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
        SnackBar(
          content: Text(
            l10n.format('common.downloadFailed', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  Future<void> _downloadFile(BuildContext context) async {
    final l10n = context.l10n;
    try {
      if (document.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('common.invalidDocumentId'))),
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
        SnackBar(
          content: Text(
            l10n.format(
                'documentDetail.downloadSuccessPath', {'path': filePath}),
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.format('common.downloadFailed', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          document.title ??
              document.fileName ??
              l10n.t('documentDetail.untitled'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "${l10n.t('documentDetail.categoryLabel')} ${document.category ?? l10n.t('common.unknown')}",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text(
                "${l10n.t('documentDetail.uploadedOn')} ${document.date ?? l10n.t('common.unknown')}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _previewFile(context),
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(l10n.t('common.preview')),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _downloadFile(context),
                  icon: Icon(
                    Icons.download,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(l10n.t('common.download')),
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

  // Time filter options (matching CategoryVaultPage)
  String _selectedTimeFilter = "All";
  final List<String> _timeFilterOptions = [
    "All",
    "1 Month",
    "3 Months",
    "6 Months",
    "12 Months"
  ];

  // Combined sort options (date + name)
  String _selectedSort = "Newest First";
  final List<String> _sortOptions = [
    "Newest First",
    "Oldest First",
    "Name A-Z",
    "Name Z-A",
  ];

  String _localizedCategoryLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case "All":
        return l10n.t('myVault.category.all');
      case "Report":
        return l10n.t('documents.category.reports');
      case "Prescription":
        return l10n.t('documents.category.prescriptions');
      case "Bill":
        return l10n.t('documents.category.bills');
      case "Insurance":
        return l10n.t('documents.category.insurance');
      default:
        return value;
    }
  }

  String _localizedTimeFilterLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case "All":
        return l10n.t('myVault.timeFilter.all');
      case "1 Month":
        return l10n.t('myVault.timeFilter.1month');
      case "3 Months":
        return l10n.t('myVault.timeFilter.3months');
      case "6 Months":
        return l10n.t('myVault.timeFilter.6months');
      case "12 Months":
        return l10n.t('myVault.timeFilter.12months');
      default:
        return value;
    }
  }

  String _localizedSortLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case "Newest First":
        return l10n.t('myVault.sort.newestFirst');
      case "Oldest First":
        return l10n.t('myVault.sort.oldestFirst');
      case "Name A-Z":
        return l10n.t('myVault.sort.nameAZ');
      case "Name Z-A":
        return l10n.t('myVault.sort.nameZA');
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
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
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    // Step 1: Filter by category
    var docs = _selectedCategory == "All"
        ? MyVault._allDocuments
        : MyVault._allDocuments
            .where((doc) =>
                (doc.category ?? '').toLowerCase() ==
                _selectedCategory.toLowerCase())
            .toList();

    // Step 2: Apply time filter
    if (_selectedTimeFilter != "All") {
      int dayLimit;
      switch (_selectedTimeFilter) {
        case "1 Month":
          dayLimit = 30;
          break;
        case "3 Months":
          dayLimit = 90;
          break;
        case "6 Months":
          dayLimit = 180;
          break;
        case "12 Months":
          dayLimit = 365;
          break;
        default:
          dayLimit = 365;
      }

      docs = docs.where((doc) {
        if (doc.date == null || doc.date!.isEmpty) return false;
        final docDate = DateTime.tryParse(doc.date!);
        if (docDate == null) return false;
        final daysDifference = now.difference(docDate).inDays;
        return daysDifference <= dayLimit;
      }).toList();
    }

    // Step 3: Apply search filter
    if (query.isNotEmpty) {
      docs = docs.where((doc) {
        final name = (doc.title ?? doc.fileName ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }

    // Step 4: Apply sorting based on selected option
    int compareByName(Document a, Document b) {
      final aName = (a.title ?? a.fileName ?? '').toLowerCase();
      final bName = (b.title ?? b.fileName ?? '').toLowerCase();
      return aName.compareTo(bName);
    }

    switch (_selectedSort) {
      case "Name A-Z":
        docs.sort(compareByName);
        break;
      case "Name Z-A":
        docs.sort((a, b) => -compareByName(a, b));
        break;
      case "Oldest First":
        docs.sort((a, b) {
          final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime(1970);
          return dateA.compareTo(dateB); // Ascending
        });
        break;
      case "Newest First":
      default:
        docs.sort((a, b) {
          final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA); // Descending
        });
        break;
    }

    return docs;
  }

  Future<void> _openFile(Document document) async {
    final l10n = context.l10n;
    if (document.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.invalidDocument'))),
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
              title:
                  document.title ?? l10n.t('documentDetail.imagePreviewTitle'),
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
        SnackBar(
          content: Text(
            l10n.format('common.couldNotOpenFile', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  Future<String> _getPreviewUrl(String documentId) async {
    final l10n = context.l10n;
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception(l10n.t('common.noToken'));
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
          l10n.format('documentDetail.previewUrlFailed', {
            'message':
                response.data['message']?.toString() ?? l10n.t('common.unknown')
          }),
        );
      }
    } catch (e) {
      debugPrint("❌ Error getting preview URL: $e");
      throw Exception(
        l10n.format('documentDetail.previewUrlFailed', {'message': '$e'}),
      );
    }
  }

  Future<void> _downloadFile(Document document) async {
    final l10n = context.l10n;
    try {
      if (document.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('common.invalidDocumentId'))),
        );
        return;
      }

      if (Platform.isAndroid) {
        // Request both storage permissions for Android 11+
        final storageStatus = await Permission.storage.request();
        await Permission.manageExternalStorage.request();

        if (!storageStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('common.storagePermission'))),
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
        SnackBar(
          content: Text(l10n.t('myVault.downloadedToDownloads')),
        ),
      );
    } catch (e) {
      debugPrint("❌ Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.format('common.downloadFailed', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  Future<void> _downloadAndOpenFile(Document document) async {
    final l10n = context.l10n;
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
        SnackBar(
          content: Text(
            l10n.format('common.downloadFailed', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  Future<void> _editFile(Document document) async {
    final l10n = context.l10n;
    if (document.id == null || document.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.invalidDocumentId'))),
      );
      return;
    }

    // Get preview URL for the modal
    String? previewUrl;
    try {
      previewUrl = await _getPreviewUrl(document.id!);
    } catch (e) {
      debugPrint("⚠️ Could not get preview URL: $e");
    }

    // Controllers for editing
    final titleController = TextEditingController(text: document.title ?? '');
    final descriptionController =
        TextEditingController(text: document.description ?? '');
    final notesController = TextEditingController(text: document.notes ?? '');
    final dateController = TextEditingController(
      text: document.date != null && document.date!.isNotEmpty
          ? document.date!.split('T')[0]
          : '',
    );
    // Normalize category to match dropdown values (capitalized)
    String _normalizeCategory(String? category) {
      if (category == null || category.isEmpty) return 'Report';
      final lower = category.toLowerCase().trim();
      if (lower.contains('report')) return 'Report';
      if (lower.contains('prescription')) return 'Prescription';
      if (lower.contains('bill')) return 'Bill';
      if (lower.contains('insurance')) return 'Insurance';
      return 'Report'; // Default
    }

    // Initialize with normalized category
    String initialCategory = _normalizeCategory(document.category);
    // Ensure it's one of the valid dropdown values
    const validCategories = ['Report', 'Prescription', 'Bill', 'Insurance'];
    if (!validCategories.contains(initialCategory)) {
      initialCategory = 'Report';
    }

    await showDialog(
      context: context,
      builder: (context) {
        // State variable that persists across rebuilds
        String selectedCategory = initialCategory;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9),
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.t('myVault.editDocument.title'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Theme.of(context).iconTheme.color),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // File Preview
                          if (previewUrl != null)
                            Container(
                              height: 200,
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (document.fileType ?? '')
                                        .toLowerCase()
                                        .contains('image')
                                    ? Image.network(
                                        previewUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              size: 64,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.insert_drive_file,
                                          size: 64,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                              ),
                            ),
                          // Title
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.t('myVault.editDocument.titleLabel'),
                              hintText:
                                  l10n.t('myVault.editDocument.titleHint'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.title,
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Category
                          DropdownButtonFormField<String>(
                            value: validCategories.contains(selectedCategory)
                                ? selectedCategory
                                : 'Report',
                            decoration: InputDecoration(
                              labelText:
                                  l10n.t('myVault.editDocument.categoryLabel'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.category,
                                  color: Theme.of(context).primaryColor),
                            ),
                            items: validCategories
                                .map((cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                          _localizedCategoryLabel(cat, l10n)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null &&
                                  validCategories.contains(value)) {
                                selectedCategory = value;
                                setDialogState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Date
                          TextField(
                            controller: dateController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.t('myVault.editDocument.dateLabel'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.calendar_today,
                                  color: Theme.of(context).primaryColor),
                              suffixIcon: Icon(Icons.edit,
                                  color: Theme.of(context).iconTheme.color),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateController.text.isNotEmpty
                                    ? DateTime.tryParse(dateController.text) ??
                                        DateTime.now()
                                    : DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  dateController.text =
                                      picked.toIso8601String().split('T')[0];
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Description
                          TextField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: l10n
                                  .t('myVault.editDocument.descriptionLabel'),
                              hintText: l10n
                                  .t('myVault.editDocument.descriptionHint'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.description,
                                  color: Theme.of(context).primaryColor),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          // Notes
                          TextField(
                            controller: notesController,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.t('myVault.editDocument.notesLabel'),
                              hintText:
                                  l10n.t('myVault.editDocument.notesHint'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.note,
                                  color: Theme.of(context).primaryColor),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.t('common.cancel')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final updates = {
                              'title': titleController.text.trim(),
                              'category': selectedCategory,
                              'description': descriptionController.text.trim(),
                              'notes': notesController.text.trim(),
                              if (dateController.text.isNotEmpty)
                                'date': dateController.text,
                            };

                            try {
                              final result = await ApiService.updateDocument(
                                  document.id!, updates);
                              if (result != null && result['success'] == true) {
                                // Update local document
                                final updatedDoc =
                                    Document.fromApi(result['document']);
                                setState(() {
                                  final index = MyVault._allDocuments
                                      .indexWhere((d) => d.id == document.id);
                                  if (index != -1) {
                                    MyVault._allDocuments[index] = updatedDoc;
                                  }
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        l10n.t('myVault.editDocument.success')),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        l10n.t('myVault.editDocument.failed')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.format('common.errorWithMessage',
                                        {'message': e.toString()}),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Text(l10n.t('common.save')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteFile(Document document) async {
    final l10n = context.l10n;
    final fileName = document.title ??
        document.fileName ??
        l10n.t('documentDetail.untitled');

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('myVault.deleteDocument.title')),
        content: Text(
          l10n.format('myVault.deleteDocument.message', {'fileName': fileName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(l10n.t('common.delete')),
          ),
        ],
      ),
    );

    // If user didn't confirm, return early
    if (confirmed != true) return;

    try {
      final success = await ApiService.deleteDocument(document.id!);
      if (success) {
        setState(() {
          MyVault.removeDocument(document.id!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('common.deleteSuccess'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('common.deleteFailed'))),
        );
      }
    } catch (e) {
      debugPrint("❌ Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.format(
                'common.deleteFailedWithMessage', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final docs = _filterAndSortDocuments();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  hintText: l10n.t('myVault.searchHint'),
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
                      label: Text(_localizedCategoryLabel(cat, l10n)),
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

            // ⏳ Filter & Sort Controls (Single Line)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                children: [
                  // Time Filter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('myVault.timeFilterTitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedTimeFilter,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          items: _timeFilterOptions
                              .map((option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(
                                        _localizedTimeFilterLabel(option, l10n),
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTimeFilter = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort By
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('myVault.sortTitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedSort,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          items: _sortOptions
                              .map((option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(
                                        _localizedSortLabel(option, l10n),
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSort = val);
                            }
                          },
                        ),
                      ],
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
                      ? Center(child: Text(l10n.t('myVault.noDocuments')))
                      : ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final categoryLabel = _localizedCategoryLabel(
                                doc.category ?? '', l10n);
                            final dateLabel = doc.date?.isNotEmpty == true
                                ? doc.date!
                                : l10n.t('common.unknown');
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file,
                                    color: Colors.blue),
                                title: Text(
                                  doc.title ??
                                      doc.fileName ??
                                      l10n.t('documentDetail.untitled'),
                                ),
                                subtitle: Text("$categoryLabel • $dateLabel",
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _editFile(doc);
                                        break;
                                      case 'preview':
                                        _openFile(doc);
                                        break;
                                      case 'download':
                                        _downloadFile(doc);
                                        break;
                                      case 'delete':
                                        _deleteFile(doc);
                                        break;
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 20,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(l10n.t('common.edit')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'preview',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.remove_red_eye,
                                            size: 20,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(l10n.t('common.preview')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'download',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.download,
                                            size: 20,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(l10n.t('common.download')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(l10n.t('common.delete')),
                                        ],
                                      ),
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
              child: Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  final onPrimary = scheme.onPrimary;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, scheme.secondary, 0.6)!,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
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
                      icon: Icon(Icons.upload, color: onPrimary),
                      label: Text(
                        l10n.t('myVault.uploadDocument'),
                        style: TextStyle(
                          color: onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: onPrimary,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        _error = context.l10n
            .format('common.errorWithMessage', {'message': e.toString()});
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
        _error = context.l10n
            .format('pdf.failAfterAttempts', {'max': '$_maxRetries'});
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
    final l10n = context.l10n;
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
              l10n.t('pdf.failedTitle'),
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
              label: Text(
                _retryCount > 0
                    ? l10n.format('pdf.retryWithCount',
                        {'current': '$_retryCount', 'total': '$_maxRetries'})
                    : l10n.t('common.retry'),
              ),
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
              _error = context.l10n.format(
                  'common.errorWithMessage', {'message': details.error});
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('pdf.loading'),
                    style: const TextStyle(
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
      final l10n = context.l10n;
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
            _error = l10n.t('common.noToken');
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
            _error = l10n.t('image.failedTitle');
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error =
            context.l10n.format('image.errorLoading', {'error': e.toString()});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                        child: Text(l10n.t('common.retry')),
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
                                  final localL10n = context.l10n;
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 64, color: Colors.red),
                                        const SizedBox(height: 16),
                                        Text(localL10n.t('image.failedTitle')),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : Image.file(
                                File(_imageDataUrl!),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  final localL10n = context.l10n;
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 64, color: Colors.red),
                                        const SizedBox(height: 16),
                                        Text(localL10n.t('image.failedTitle')),
                                      ],
                                    ),
                                  );
                                },
                              )),
                      )
                    : Text(l10n.t('image.noData')),
      ),
    );
  }
}
