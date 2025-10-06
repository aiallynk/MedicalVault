import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

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

  /// Remove selected file
  void _removeSelectedFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          yesterday, // Default to yesterday if no date selected
      firstDate: DateTime(2000),
      lastDate: now, // ✅ Restrict to current date and earlier (no future dates)
      helpText: "Select document date",
      cancelText: "Cancel",
      confirmText: "Select",
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null ||
        _titleController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Fill all fields and select a file")),
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
        const SnackBar(content: Text("❌ Upload failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Document")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.title, color: Colors.blue),
                  labelText: "Document Title",
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
                  labelText: "Category",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  "Report",
                  "Prescription",
                  "Bill",
                  "Insurance",
                ]
                    .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)))
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
                      labelText: "Document Date",
                      hintText: "Select date when document was created",
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
                  labelText: "Notes (optional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                  // ✅ Add remove button when file is selected
                  if (_selectedFile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.red),
                      onPressed: _removeSelectedFile,
                      tooltip: "Remove selected file",
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFile != null
                          ? _selectedFile!.path.split('/').last
                          : "No file selected / photo captured",
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
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
                                  "Uploading... ${_uploadProgress.toInt()}%",
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
                        label: const Text(
                          "Upload Document",
                          style: TextStyle(color: Colors.blue),
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
}
