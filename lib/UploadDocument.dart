import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'localization/app_localizations.dart';

class UploadDocument extends StatefulWidget {
  final String userId;

  const UploadDocument({
    super.key,
    required this.userId,
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
          l10n.format('uploadDocument.deleteFile.message', {'fileName': fileName}),
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
    final now = DateTime.now();
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
        SnackBar(
            content:
                Text(l10n.t('uploadDocument.error.missingFields'))),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final doc = await ApiService.uploadDocument(
      file: _selectedFile!,
      title: _titleController.text,
      category:
          _selectedCategory == "Reports" ? "Lab Report" : _selectedCategory!,
      notes: _notesController.text,
      date:
          _selectedDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      onProgress: (progress) {
        setState(() {
          _uploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploading = false;
      _uploadProgress = 0.0;
    });

    if (doc != null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('uploadDocument.error.uploadFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  prefixIcon: const Icon(Icons.title, color: Colors.blue),
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
                  prefixIcon: const Icon(Icons.category, color: Colors.blue),
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
                      prefixIcon:
                          const Icon(Icons.calendar_today, color: Colors.blue),
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
                  prefixIcon: const Icon(Icons.notes, color: Colors.blue),
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.blue),
                      onPressed: _pickFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.blue),
                      onPressed: _pickFromCamera,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.t('uploadDocument.field.filePlaceholder'),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.black54,
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
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
                                    'percent': _uploadProgress.toInt().toString()
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
                    : ElevatedButton.icon(
                        icon:
                            const Icon(Icons.cloud_upload, color: Colors.blue),
                        label: Text(
                          l10n.t('uploadDocument.button.upload'),
                          style: const TextStyle(color: Colors.blue),
                        ),
                        onPressed: _uploadDocument,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
