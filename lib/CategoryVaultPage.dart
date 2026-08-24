import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:permission_handler/permission_handler.dart';

import 'Document_model.dart';
import 'api_service.dart';
import 'localization/app_localizations.dart';
import 'UploadDocument.dart';
import 'services/document_external_open_service.dart';
import 'utils/timezone_utils.dart';

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

class _CategoryVaultPageState extends State<CategoryVaultPage>
    with WidgetsBindingObserver {
  static const _documentPageSize = 24;
  List<Document> files = [];
  List<Document> filteredFiles = [];
  StreamSubscription<dynamic>? _connectivitySubscription;
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _wasConnected = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isDocumentRequestInFlight = false;
  bool _reloadAfterCurrentRequest = false;
  bool _hasMoreDocuments = true;
  int _nextDocumentPage = 1;
  int _documentQueryRevision = 0;
  String _resolvedUserId = '';
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

  String _localizedCategoryLabel(String value, AppLocalizations l10n) {
    switch (value.toLowerCase()) {
      case 'reports':
      case 'report':
        return l10n.t('documents.category.reports');
      case 'prescriptions':
      case 'prescription':
        return l10n.t('documents.category.prescriptions');
      case 'bills':
      case 'bill':
        return l10n.t('documents.category.bills');
      case 'insurance':
      case 'insurance details':
        return l10n.t('documents.category.insurance');
      case 'all':
        return l10n.t('myVault.category.all');
      default:
        return value;
    }
  }

  String _localizedTimeFilterLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'All':
        return l10n.t('myVault.timeFilter.all');
      case '1 Month':
        return l10n.t('myVault.timeFilter.1month');
      case '3 Months':
        return l10n.t('myVault.timeFilter.3months');
      case '6 Months':
        return l10n.t('myVault.timeFilter.6months');
      case '12 Months':
        return l10n.t('myVault.timeFilter.12months');
      default:
        return value;
    }
  }

  String _localizedSortLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'Newest First':
        return l10n.t('myVault.sort.newestFirst');
      case 'Oldest First':
        return l10n.t('myVault.sort.oldestFirst');
      case 'Name A-Z':
        return l10n.t('myVault.sort.nameAZ');
      case 'Name Z-A':
        return l10n.t('myVault.sort.nameZA');
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConnectivityObserver();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadFiles();
  }

  @override
  void didUpdateWidget(covariant CategoryVaultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId.trim() != widget.userId.trim() ||
        oldWidget.category != widget.category) {
      _resolvedUserId = '';
      _loadFiles();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFiles();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 360) {
      return;
    }
    unawaited(_loadMoreFiles());
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
      unawaited(_loadFiles());
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

  // Helper method to apply date filter
  List<Document> _applyDateFilter(List<Document> docs) {
    if (selectedTimeFilter == 'All') {
      return docs;
    }

    final now = nowForContextTimeZone(context);
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

      final docDate = combineDateAndTimeForContext(
        context,
        doc.date!,
        null,
        defaultHour: 0,
        defaultMinute: 0,
      );
      if (docDate == null) {
        return false; // Exclude documents with invalid date
      }

      final daysDifference = now.difference(docDate).inDays;
      return daysDifference <= dayLimit;
    }).toList();
  }

  Future<String> _resolveDocumentUserId() async {
    if (_resolvedUserId.isNotEmpty) return _resolvedUserId;
    final prefs = await SharedPreferences.getInstance();
    final fromWidget = widget.userId.trim();
    final fromActiveProfile = (prefs.getString('activeProfileId') ?? '').trim();
    final fromPrefs = (prefs.getString('userId') ?? '').trim();
    _resolvedUserId = fromWidget.isNotEmpty
        ? fromWidget
        : (fromActiveProfile.isNotEmpty ? fromActiveProfile : fromPrefs);
    if (_resolvedUserId.isEmpty) {
      final remoteUser = await ApiService.me();
      _resolvedUserId = (remoteUser?['id']?.toString() ??
              remoteUser?['_id']?.toString() ??
              '')
          .trim();
      if (_resolvedUserId.isNotEmpty) {
        await prefs.setString('userId', _resolvedUserId);
      }
    }
    return _resolvedUserId;
  }

  String _apiCategory() => switch (widget.category.toLowerCase()) {
        'reports' || 'report' => 'report',
        'prescriptions' || 'prescription' => 'prescription',
        'bills' || 'bill' => 'bill',
        'insurance' || 'insurance details' => 'insurance',
        _ => widget.category,
      };

  String _apiSort() => switch (_selectedSort) {
        'Oldest First' => 'oldest',
        'Name A-Z' => 'name_asc',
        'Name Z-A' => 'name_desc',
        _ => 'newest',
      };

  String? _dateAfter() {
    final days = switch (selectedTimeFilter) {
      '1 Month' => 30,
      '3 Months' => 90,
      '6 Months' => 180,
      '12 Months' => 365,
      _ => 0,
    };
    if (days == 0) return null;
    return nowForContextTimeZone(context)
        .subtract(Duration(days: days))
        .toUtc()
        .toIso8601String();
  }

  Future<void> _loadFiles() async {
    final queryRevision = ++_documentQueryRevision;
    if (_isDocumentRequestInFlight) {
      _reloadAfterCurrentRequest = true;
      return;
    }
    _nextDocumentPage = 1;
    _hasMoreDocuments = true;
    if (mounted) setState(() => _isLoading = files.isEmpty);
    await _fetchFilesPage(reset: true, queryRevision: queryRevision);
  }

  Future<void> _loadMoreFiles() async {
    if (_isLoading || _isLoadingMore || !_hasMoreDocuments) return;
    await _fetchFilesPage(reset: false, queryRevision: _documentQueryRevision);
  }

  Future<void> _fetchFilesPage({
    required bool reset,
    required int queryRevision,
  }) async {
    if (_isDocumentRequestInFlight ||
        (!reset && (_isLoadingMore || !_hasMoreDocuments))) {
      return;
    }
    _isDocumentRequestInFlight = true;
    if (!reset && mounted) setState(() => _isLoadingMore = true);
    try {
      final userId = await _resolveDocumentUserId();
      if (userId.isEmpty) return;
      final result = await ApiService.fetchMyDocsPage(
        userId,
        page: _nextDocumentPage,
        limit: _documentPageSize,
        category: _apiCategory(),
        search: _searchController.text,
        after: _dateAfter(),
        sort: _apiSort(),
      );
      if (result == null || queryRevision != _documentQueryRevision) return;
      final seenIds = <String>{};
      final next = reset ? <Document>[] : List<Document>.of(files);
      for (final document in next) {
        if (document.id != null) seenIds.add(document.id!);
      }
      for (final document in result.documents) {
        if (document.id == null || seenIds.add(document.id!)) {
          next.add(document);
        }
      }
      files = next;
      _nextDocumentPage += 1;
      _hasMoreDocuments = result.hasMore;
      if (mounted) setState(() => filteredFiles = _recomputeFilteredFiles());
    } catch (error) {
      debugPrint('Error loading document page: $error');
    } finally {
      _isDocumentRequestInFlight = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      if (_reloadAfterCurrentRequest && mounted) {
        _reloadAfterCurrentRequest = false;
        unawaited(_loadFiles());
      }
    }
  }

  List<Document> _filterDocsByCurrentCategory(List<Document> docs) {
    return docs.where((d) {
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
    }).toList(growable: false);
  }

  // Handle filter change
  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != selectedTimeFilter) {
      setState(() {
        selectedTimeFilter = newFilter;
        filteredFiles = _recomputeFilteredFiles();
      });
      unawaited(_loadFiles());
    }
  }

  void _onSortChanged(String? newSort) {
    if (newSort != null && newSort != _selectedSort) {
      setState(() {
        _selectedSort = newSort;
        filteredFiles = _recomputeFilteredFiles();
      });
      unawaited(_loadFiles());
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() => filteredFiles = _recomputeFilteredFiles());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) unawaited(_loadFiles());
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
          final dateA = combineDateAndTimeForContext(
                context,
                a.date,
                null,
                defaultHour: 0,
                defaultMinute: 0,
              ) ??
              DateTime.utc(1970);
          final dateB = combineDateAndTimeForContext(
                context,
                b.date,
                null,
                defaultHour: 0,
                defaultMinute: 0,
              ) ??
              DateTime.utc(1970);
          return dateA.compareTo(dateB); // Ascending
        });
        break;
      case 'Newest First':
      default:
        results.sort((a, b) {
          final dateA = combineDateAndTimeForContext(
                context,
                a.date,
                null,
                defaultHour: 0,
                defaultMinute: 0,
              ) ??
              DateTime.utc(1970);
          final dateB = combineDateAndTimeForContext(
                context,
                b.date,
                null,
                defaultHour: 0,
                defaultMinute: 0,
              ) ??
              DateTime.utc(1970);
          return dateB.compareTo(dateA); // Descending
        });
        break;
    }

    return results;
  }

  // ---------------- OPEN FILE ----------------
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

    try {
      final lowerFileName = fileName.toLowerCase();
      final isPdf = fileType.contains("pdf") || lowerFileName.endsWith(".pdf");
      final isImage = fileType.startsWith("image/") ||
          lowerFileName.endsWith(".jpg") ||
          lowerFileName.endsWith(".jpeg") ||
          lowerFileName.endsWith(".png");

      if (isPdf) {
        await DocumentExternalOpenService.openDocument(document);
      } else if (isImage) {
        // âœ… Use backend preview endpoint for images
        final previewUrl = await _getPreviewUrl(document.id!);
        if (!mounted) return;
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
        await DocumentExternalOpenService.openDocument(document);
      }
    } catch (e) {
      debugPrint("âŒ Preview error: $e");
      if (!mounted) return;
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
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception(context.l10n.t('common.noToken'));
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
          context.l10n.format('documentDetail.previewUrlFailed', {
            'message': response.data['message']?.toString() ??
                context.l10n.t('common.unknown')
          }),
        );
      }
    } catch (e) {
      debugPrint("âŒ Error getting preview URL: $e");
      throw Exception(
        context.l10n
            .format('documentDetail.previewUrlFailed', {'message': '$e'}),
      );
    }
  }

  Widget _buildMedicalVerificationChip(Document document) {
    final verification = document.medicalVerification;
    final isVerified = document.isMedicalVerified;
    final isAccepted = verification?.isAccepted == true;
    if (!isVerified && !isAccepted) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final label = context.l10n.t(isVerified
        ? 'documents.verification.verified'
        : 'documents.verification.accepted');
    final color = isVerified ? Colors.green : scheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified
                ? Icons.verified_rounded
                : Icons.medical_services_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  // ---------------- DOWNLOAD ONLY ----------------
  Future<void> _downloadFile(Document document) async {
    final l10n = context.l10n;
    if (document.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.invalidDocumentId'))),
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

      // âœ… All files â†’ use backend download endpoint with auth
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
        SnackBar(
          content: Text(
            l10n.format(
                'documentDetail.downloadSuccessPath', {'path': filePath}),
          ),
        ),
      );
    } catch (e) {
      debugPrint("âŒ Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.format('common.downloadFailed', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  // ---------------- EDIT FILE ----------------
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
      debugPrint("âš ï¸ Could not get preview URL: $e");
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
                              final now = nowForContextTimeZone(context);
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateController.text.isNotEmpty
                                    ? DateTime.tryParse(dateController.text) ??
                                        now
                                    : now,
                                firstDate: DateTime(1900),
                                lastDate: now,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  dateController.text = formatDateForContext(
                                    context,
                                    picked,
                                    pattern: 'yyyy-MM-dd',
                                    fallback: dateController.text,
                                  );
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
                                  final fileIndex = files
                                      .indexWhere((d) => d.id == document.id);
                                  final filteredIndex = filteredFiles
                                      .indexWhere((d) => d.id == document.id);
                                  if (fileIndex != -1) {
                                    files[fileIndex] = updatedDoc;
                                  }
                                  if (filteredIndex != -1) {
                                    filteredFiles[filteredIndex] = updatedDoc;
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

  // ---------------- DELETE ----------------
  Future<void> _deleteFile(Document document) async {
    final l10n = context.l10n;
    if (document.id == null || document.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('common.invalidDocumentId'))),
      );
      return;
    }

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
      debugPrint("ðŸ—‘ Deleting file with id=${document.id}");
      final success = await ApiService.deleteDocument(document.id!);

      if (success) {
        setState(() {
          files.remove(document);
          filteredFiles.remove(document);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('common.deleteSuccess'))),
        );
      } else {
        throw Exception("Server rejected delete for id=${document.id}");
      }
    } catch (e) {
      debugPrint("âŒ Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              l10n.format('common.deleteFailedWithMessage', {'error': '$e'})),
        ),
      );
    }
  }

  // ---------------- THUMBNAIL ----------------
  Widget _buildThumbnail(BuildContext context, Document document) {
    final scheme = Theme.of(context).colorScheme;
    final fileType = (document.fileType ?? "").toLowerCase();
    if (fileType.startsWith("image/")) {
      // For thumbnails, use a simple icon instead of loading the full image
      // This prevents ANR issues and improves performance
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.image,
          color: scheme.secondary,
          size: 30,
        ),
      );
    } else if (fileType.contains("pdf")) {
      return Icon(Icons.picture_as_pdf, color: scheme.error, size: 40);
    } else if (fileType.contains("word")) {
      return Icon(Icons.description, color: scheme.primary, size: 40);
    }
    return Icon(Icons.insert_drive_file, color: scheme.outline, size: 40);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_localizedCategoryLabel(widget.category, l10n)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to upload form with category pre-selected
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadDocument(
                userId: widget.userId,
                initialCategory: widget.category,
              ),
            ),
          );
          // Refresh files if upload was successful
          if (result is Document && mounted) {
            final categoryFiltered = _filterDocsByCurrentCategory([result]);
            if (categoryFiltered.isNotEmpty) {
              setState(() {
                files.removeWhere((doc) => doc.id == result.id);
                files.insert(0, result);
                filteredFiles = _recomputeFilteredFiles();
              });
            }
          }
          if (result == true || result is Document) {
            _loadFiles();
          }
        },
        icon: Icon(Icons.add, color: scheme.onPrimaryContainer),
        label: Text(
          l10n.t('myVault.uploadDocument'),
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: scheme.primaryContainer,
        elevation: 4,
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
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.16),
                          scheme.secondary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.folder_special_rounded,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _localizedCategoryLabel(widget.category, l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${filteredFiles.length} ${l10n.t('myVault.documentsCount')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${filteredFiles.length}/${files.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter & Sort controls (Single Line)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedTimeFilter,
                            decoration: InputDecoration(
                              labelText: l10n.t('myVault.timeFilterTitle'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: timeFilterOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  _localizedTimeFilterLabel(option, l10n),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: _onFilterChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedSort,
                            decoration: InputDecoration(
                              labelText: l10n.t('myVault.sortTitle'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: sortOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  _localizedSortLabel(option, l10n),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: _onSortChanged,
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
                        hintText: l10n.t('categoryVault.searchHint'),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: scheme.primary,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        fillColor: scheme.surfaceContainerLowest,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: scheme.primary,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Document list
                  Expanded(
                    child: filteredFiles.isEmpty
                        ? Center(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 24,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    size: 60,
                                    color: scheme.outline,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    files.isEmpty
                                        ? l10n.t(
                                            'categoryVault.noDocsUploadedTitle')
                                        : l10n.t(
                                            'categoryVault.noDocsFilteredTitle'),
                                    textAlign: TextAlign.center,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    files.isEmpty
                                        ? l10n.t(
                                            'categoryVault.noDocsUploadedSubtitle')
                                        : l10n.t(
                                            'categoryVault.noDocsFilteredSubtitle'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: filteredFiles.length +
                                (_hasMoreDocuments ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredFiles.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: _isLoadingMore
                                        ? const SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }
                              final file = filteredFiles[index];
                              final title = file.title ??
                                  file.fileName ??
                                  l10n.t('documentDetail.untitled');
                              final categoryChip = _localizedCategoryLabel(
                                  file.category ?? '', l10n);
                              final uploadedLabel =
                                  '${l10n.t('documents.uploadedOnShort')} ${file.date?.isNotEmpty == true ? formatDateForContext(
                                      context,
                                      file.date,
                                      pattern: 'yyyy-MM-dd',
                                      fallback: l10n.t('common.unknown'),
                                    ) : l10n.t('common.unknown')}';
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _openFile(file),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildThumbnail(context, file),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 6,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: scheme.primary
                                                            .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                      ),
                                                      child: Text(
                                                        categoryChip,
                                                        style: theme.textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                          color: scheme.primary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      uploadedLabel,
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: theme.hintColor,
                                                      ),
                                                    ),
                                                    if (file
                                                        .hasMedicalVerification)
                                                      _buildMedicalVerificationChip(
                                                          file),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert_rounded,
                                              color: theme.iconTheme.color,
                                            ),
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'edit':
                                                  _editFile(file);
                                                  break;
                                                case 'preview':
                                                  _openFile(file);
                                                  break;
                                                case 'download':
                                                  _downloadFile(file);
                                                  break;
                                                case 'delete':
                                                  _deleteFile(file);
                                                  break;
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) => [
                                              PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_rounded,
                                                      size: 20,
                                                      color: scheme.primary,
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
                                                    Icon(
                                                      Icons
                                                          .remove_red_eye_rounded,
                                                      size: 20,
                                                      color: scheme.secondary,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(l10n
                                                        .t('common.preview')),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'download',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.download_rounded,
                                                      size: 20,
                                                      color: scheme.tertiary,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(l10n
                                                        .t('common.download')),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 20,
                                                      color: scheme.error,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(l10n
                                                        .t('common.delete')),
                                                  ],
                                                ),
                                              ),
                                            ],
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
  final String? fileName;
  final String? cacheKey;

  const PdfPreviewPage({
    super.key,
    required this.url,
    required this.title,
    this.fileName,
    this.cacheKey,
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  bool _isLoading = true;
  String? _error;
  String? _localPdfPath;
  double? _downloadProgress;
  int _retryCount = 0;
  CancelToken? _cancelToken;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf({bool forceRefresh = false}) async {
    _cancelToken?.cancel('Starting a new PDF load');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _downloadProgress = null;
      });

      final pdfFile = await _cachedPdfFile();
      if (forceRefresh && await pdfFile.exists()) {
        await pdfFile.delete();
      }

      if (await pdfFile.exists() && await pdfFile.length() > 0) {
        if (!mounted || cancelToken.isCancelled) return;
        setState(() {
          _localPdfPath = pdfFile.path;
          _isLoading = false;
        });
        return;
      }

      await _downloadPdf(pdfFile, cancelToken);
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _localPdfPath = pdfFile.path;
        _isLoading = false;
        _downloadProgress = null;
      });
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || !mounted) return;
      setState(() {
        _isLoading = false;
        _error = _formatLoadError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _formatLoadError(e);
      });
    }
  }

  Future<File> _cachedPdfFile() async {
    final dir = await getTemporaryDirectory();
    final key = (widget.cacheKey?.trim().isNotEmpty == true
            ? widget.cacheKey!.trim()
            : widget.url)
        .hashCode
        .toUnsigned(32)
        .toRadixString(16);
    final rawName = (widget.fileName?.trim().isNotEmpty == true
            ? widget.fileName!.trim()
            : widget.title.trim())
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    var safeName = rawName.isEmpty ? 'document.pdf' : rawName;
    if (!safeName.toLowerCase().endsWith('.pdf')) {
      safeName = '$safeName.pdf';
    }
    if (safeName.length > 90) {
      safeName = '${safeName.substring(0, 86)}.pdf';
    }
    return File('${dir.path}/pdf_preview_${key}_$safeName');
  }

  Future<void> _downloadPdf(File target, CancelToken cancelToken) async {
    await target.parent.create(recursive: true);
    final token = await ApiService.getToken();
    final headers = <String, String>{
      'Accept': 'application/pdf,application/octet-stream,*/*',
    };
    if (_shouldAttachAuthHeader(widget.url) && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final dio = Dio();
    final response = await dio.download(
      widget.url,
      target.path,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 15),
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 400,
      ),
      onReceiveProgress: (received, total) {
        if (!mounted || total <= 0 || cancelToken.isCancelled) return;
        final progress = received / total;
        setState(() {
          _downloadProgress = progress.clamp(0.0, 1.0).toDouble();
        });
      },
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception('Server returned ${response.statusCode}');
    }
    if (!await target.exists() || await target.length() == 0) {
      throw Exception('Downloaded PDF is empty');
    }
  }

  bool _shouldAttachAuthHeader(String url) {
    final apiUri = Uri.tryParse(ApiService.baseUrl);
    final targetUri = Uri.tryParse(url);
    if (apiUri == null ||
        targetUri == null ||
        targetUri.host.isEmpty ||
        targetUri.scheme.isEmpty) {
      return true;
    }
    return targetUri.host == apiUri.host &&
        targetUri.port == apiUri.port &&
        targetUri.scheme == apiUri.scheme;
  }

  String _formatLoadError(Object error) {
    final message = error is DioException
        ? (error.response?.data?.toString().trim().isNotEmpty == true
            ? error.response!.data.toString()
            : error.message ?? error.toString())
        : error.toString();
    return context.l10n.format(
      'common.errorWithMessage',
      {'message': message},
    );
  }

  Future<void> _retryLoadPdf() async {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
        _isLoading = true;
        _error = null;
      });

      await _loadPdf(forceRefresh: true);
    } else {
      setState(() {
        _error = context.l10n
            .format('pdf.failAfterAttempts', {'max': '$_maxRetries'});
      });
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel('PDF preview closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_localPdfPath != null)
            IconButton(
              tooltip: 'Open with another app',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => OpenFile.open(_localPdfPath!),
            ),
          IconButton(
            tooltip: context.l10n.t('common.retry'),
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _loadPdf(forceRefresh: true),
          ),
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
      final hasLocalPdf =
          _localPdfPath != null && File(_localPdfPath!).existsSync();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryLoadPdf,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _retryCount > 0
                          ? l10n.format('pdf.retryWithCount', {
                              'current': '$_retryCount',
                              'total': '$_maxRetries'
                            })
                          : l10n.t('common.retry'),
                    ),
                  ),
                  if (hasLocalPdf)
                    OutlinedButton.icon(
                      onPressed: () => OpenFile.open(_localPdfPath!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open with another app'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _localPdfPath == null) {
      final progressText = _downloadProgress == null
          ? null
          : '${(_downloadProgress! * 100).clamp(0, 100).toStringAsFixed(0)}%';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 16),
            Text(
              progressText == null
                  ? l10n.t('pdf.loading')
                  : '${l10n.t('pdf.loading')} $progressText',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SfPdfViewer.file(
      File(_localPdfPath!),
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        setState(() {
          _isLoading = false;
          _error = context.l10n
              .format('common.errorWithMessage', {'message': details.error});
        });
      },
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _isLoading = false;
        });
      },
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
    final l10n = context.l10n;
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
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 64, color: Colors.red),
                                        const SizedBox(height: 16),
                                        Text(
                                          context.l10n.t('image.failedTitle'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : Image.file(
                                File(_imageDataUrl!),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            size: 64, color: Colors.red),
                                        const SizedBox(height: 16),
                                        Text(
                                          context.l10n.t('image.failedTitle'),
                                        ),
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
