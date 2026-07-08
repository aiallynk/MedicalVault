import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../Document_model.dart';
import '../api_service.dart';

class DocumentExternalOpenService {
  static const MethodChannel _channel =
      MethodChannel('medical_vault/file_opener');

  const DocumentExternalOpenService._();

  static Future<File> prepareDocumentForExternalOpen(
    Document document, {
    bool forceRefresh = false,
    void Function(double progress)? onProgress,
  }) async {
    final documentId = document.id?.trim();
    if (documentId == null || documentId.isEmpty) {
      throw Exception('Invalid document id.');
    }

    final target = await _cachedFileFor(document);
    if (!forceRefresh && await target.exists() && await target.length() > 0) {
      onProgress?.call(1);
      return target;
    }

    await target.parent.create(recursive: true);
    final token = await ApiService.getToken();
    final dio = Dio();
    final response = await dio.download(
      '${ApiService.baseUrl}/files/$documentId/download',
      target.path,
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 15),
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 400,
      ),
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress?.call((received / total).clamp(0.0, 1.0).toDouble());
      },
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception('Server returned ${response.statusCode}');
    }
    if (!await target.exists() || await target.length() == 0) {
      throw Exception('Downloaded file is empty.');
    }
    onProgress?.call(1);
    return target;
  }

  static Future<void> openDocument(
    Document document, {
    bool forceRefresh = false,
    void Function(double progress)? onProgress,
  }) async {
    final file = await prepareDocumentForExternalOpen(
      document,
      forceRefresh: forceRefresh,
      onProgress: onProgress,
    );
    await openPreparedFile(
      file,
      mimeType: _mimeTypeFor(document),
      chooserTitle: 'Open file',
    );
  }

  static Future<void> openPreparedFile(
    File file, {
    required String mimeType,
    String chooserTitle = 'Open file',
  }) async {
    if (Platform.isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'openFileChooser',
          {
            'path': file.path,
            'mimeType': mimeType,
            'title': chooserTitle,
          },
        );
        if (opened == true) return;
      } on PlatformException catch (error) {
        throw Exception(error.message ?? 'No compatible viewer was found.');
      } on MissingPluginException {
        // Fall through to the plugin for desktop/tests or stale app installs.
      }
    }

    final result = await OpenFile.open(file.path, type: mimeType);
    if (result.type != ResultType.done) {
      throw Exception(
        result.message.trim().isEmpty
            ? 'No compatible viewer was found.'
            : result.message,
      );
    }
  }

  static Future<File> _cachedFileFor(Document document) async {
    final dir = await getTemporaryDirectory();
    final documentId = document.id?.trim().isNotEmpty == true
        ? document.id!.trim()
        : DateTime.now().millisecondsSinceEpoch.toString();
    final safeName = _safeFileName(document);
    return File('${dir.path}/document_open_cache/$documentId-$safeName');
  }

  static String _safeFileName(Document document) {
    final rawName = (document.fileName?.trim().isNotEmpty == true
            ? document.fileName!.trim()
            : null) ??
        (document.title?.trim().isNotEmpty == true
            ? document.title!.trim()
            : 'document');
    final sanitized = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final withExtension = sanitized.contains('.')
        ? sanitized
        : '$sanitized.${_extensionFor(document)}';
    if (withExtension.length <= 110) return withExtension;
    final extension = _extensionFor(document);
    return '${withExtension.substring(0, 104)}.$extension';
  }

  static String _extensionFor(Document document) {
    final lowerName = (document.fileName ?? '').toLowerCase();
    final lowerType = (document.fileType ?? '').toLowerCase();
    if (lowerName.endsWith('.pdf') || lowerType.contains('pdf')) return 'pdf';
    if (lowerName.endsWith('.png') || lowerType.contains('png')) return 'png';
    if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerType.contains('jpeg')) {
      return 'jpg';
    }
    return 'file';
  }

  static String _mimeTypeFor(Document document) {
    final lowerName = (document.fileName ?? '').toLowerCase();
    final lowerType = (document.fileType ?? '').toLowerCase().trim();
    if (lowerType.contains('/')) return lowerType;
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }
}
