import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'localization/app_localizations.dart';
import 'Document_model.dart';
import 'utils/timezone_utils.dart';

class UploadDocument extends StatefulWidget {
  final String userId;
  final String? initialCategory; // Optional pre-selected category

  const UploadDocument({
    super.key,
    required this.userId,
    this.initialCategory,
  });

  @override
  State<UploadDocument> createState() => _UploadDocumentState();
}

class _UploadDocumentState extends State<UploadDocument> {
  File? _selectedFile;
  String? _selectedCategory;
  DateTime? _selectedDate;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Set initial category if provided
    if (widget.initialCategory != null) {
      _selectedCategory = _normalizeCategory(widget.initialCategory!);
    }
  }

  // Normalize category to match valid backend categories
  String _normalizeCategory(String category) {
    final lower = category.toLowerCase().trim();
    if (lower.contains('report')) return 'Report';
    if (lower.contains('prescription')) return 'Prescription';
    if (lower.contains('bill')) return 'Bill';
    if (lower.contains('insurance')) return 'Insurance';
    return 'Report'; // Default
  }

  /// File picker
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  /// Camera capture
  Future<void> _pickFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        _selectedFile = File(photo.path);
      });
    }
  }

  /// Remove selected file with confirmation
  void _removeSelectedFile() {
    final l10n = context.l10n;
    final fileName = _selectedFile?.path.split('/').last ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('uploadDocument.deleteFile.title')),
        content: Text(
          l10n.format(
              'uploadDocument.deleteFile.message', {'fileName': fileName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedFile = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(l10n.t('common.delete')),
          ),
        ],
      ),
    );
  }

  /// Check if file is an image
  bool _isImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  Future<void> _pickDate() async {
    final l10n = context.l10n;
    final currentTimeZoneNow = nowForContextTimeZone(context);
    final now = DateTime(
      currentTimeZoneNow.year,
      currentTimeZoneNow.month,
      currentTimeZoneNow.day,
    );
    final yesterday = now.subtract(const Duration(days: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          yesterday, // Default to yesterday if no date selected
      firstDate: DateTime(2000),
      lastDate: now, // ✅ Restrict to current date and earlier (no future dates)
      helpText: l10n.t('uploadDocument.datePicker.help'),
      cancelText: l10n.t('uploadDocument.datePicker.cancel'),
      confirmText: l10n.t('uploadDocument.datePicker.confirm'),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _uploadDocument() async {
    final l10n = context.l10n;
    if (_selectedFile == null ||
        _titleController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('uploadDocument.error.missingFields'))),
      );
      return;
    }

    // Initialize progress to 0
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    // Small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 50));

    Document? doc;
    try {
      doc = await ApiService.uploadDocument(
        file: _selectedFile!,
        title: _titleController.text,
        category:
            _selectedCategory == "Reports" ? "Lab Report" : _selectedCategory!,
        notes: _notesController.text,
        date: _selectedDate?.toIso8601String() ??
            nowForContextTimeZone(context).toIso8601String(),
        onProgress: (progress) {
          // Ensure state updates happen on the main thread
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );
    } catch (e) {
      debugPrint("Upload error: $e");
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }

    if (doc != null) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('uploadDocument.error.uploadFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final pickerBackground = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: isDark ? 0.42 : 0.55);
    final categories = [
      {'value': 'Report', 'label': l10n.t('documents.category.reports')},
      {
        'value': 'Prescription',
        'label': l10n.t('documents.category.prescriptions')
      },
      {'value': 'Bill', 'label': l10n.t('documents.category.bills')},
      {'value': 'Insurance', 'label': l10n.t('documents.category.insurance')},
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('uploadDocument.title'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    color: primary,
                  ),
                  labelText: l10n.t('uploadDocument.field.titleLabel'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.folder_open_rounded,
                    color: primary,
                  ),
                  labelText: l10n.t('uploadDocument.field.categoryLabel'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: categories
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat['value'] as String,
                        child: Text(cat['label'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                          : "",
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.event_available_rounded,
                        color: primary,
                      ),
                      labelText: l10n.t('uploadDocument.field.dateLabel'),
                      hintText: l10n.t('uploadDocument.field.dateHint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.sticky_note_2_outlined,
                    color: primary,
                  ),
                  labelText: l10n.t('uploadDocument.field.notesLabel'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // File picker buttons
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: pickerBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.attach_file_rounded, color: primary),
                      onPressed: _pickFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: pickerBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.photo_camera_outlined, color: primary),
                      onPressed: _pickFromCamera,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.t('uploadDocument.field.filePlaceholder'),
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
              // File preview (appears below buttons when file is selected)
              if (_selectedFile != null) ...[
                const SizedBox(height: 12),
                _buildFilePreview(),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: _isUploading
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, theme.colorScheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.format('uploadDocument.progressLabel', {
                                    'percent':
                                        _uploadProgress.toInt().toString()
                                  }),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _uploadProgress / 100,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: 6,
                            ),
                          ],
                        ),
                      )
                    : FilledButton.icon(
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          l10n.t('uploadDocument.button.upload'),
                        ),
                        onPressed: _uploadDocument,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    if (_selectedFile == null) return const SizedBox.shrink();

    final isImage = _isImageFile(_selectedFile!);
    final fileName = _selectedFile!.path.split('/').last;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Preview content
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Image preview or file icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedFile!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.broken_image,
                                color: Theme.of(context).colorScheme.error,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.insert_drive_file,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                const SizedBox(width: 12),
                // File name
                Expanded(
                  child: Text(
                    fileName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Remove button (cross) on top right
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _removeSelectedFile,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
