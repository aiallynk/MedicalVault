import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/ai_service.dart';

class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({
    super.key,
    required this.documentId,
    required this.documentName,
  });

  final String documentId;
  final String documentName;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final preview = await AIService.getPreviewUrl(widget.documentId);
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _loading = false;
      _error = preview == null
          ? 'I could not load that report. Please try again.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _preview?['previewUrl']?.toString() ?? '';
    final mimeType = (_preview?['mimeType']?.toString() ?? '').toLowerCase();
    final isPdf = mimeType.contains('pdf') ||
        widget.documentName.toLowerCase().endsWith('.pdf');
    final isImage = mimeType.startsWith('image/') ||
        RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false)
            .hasMatch(widget.documentName);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _PreviewError(message: _error!, onRetry: _loadPreview)
              : isPdf
                  ? SfPdfViewer.network(
                      url,
                      canShowScrollHead: false,
                      canShowScrollStatus: true,
                      onDocumentLoadFailed: (_) => _loadPreview(),
                    )
                  : isImage
                      ? InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _PreviewError(
                                message:
                                    'The document preview link expired. Refreshing it now…',
                                onRetry: _loadPreview,
                              ),
                            ),
                          ),
                        )
                      : _PreviewError(
                          message:
                              'This file type cannot be previewed in the app.',
                          onRetry: _loadPreview,
                        ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
