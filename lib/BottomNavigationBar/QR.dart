import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:hello/HowQrAcessWorks.dart';
import 'package:hello/api_service.dart';
import 'package:hello/localization/app_localizations.dart';

/// 👉 Backend base URL (no trailing slash)
class QRPage extends StatefulWidget {
  const QRPage({super.key});
  @override
  State<QRPage> createState() => _QRPageState();
}

class _QRPageState extends State<QRPage> {
  String _qrData = '';
  String? _lastError;
  final GlobalKey _repaintKey = GlobalKey();
  final Uuid _uuid = const Uuid();
  bool _loading = false;
  List<Map<String, dynamic>> _qrAds = [];
  List<Map<String, dynamic>> _qrActions = [];
  Color? _remoteButtonColor;
  Color? _remoteIconColor;

  @override
  void initState() {
    super.initState();
    _regenerateQR(); // auto-generate on open
    _loadDynamicQrContent();
  }

  // Removed unused _readSessionToken

  Future<void> _regenerateQR() async {
    setState(() {
      _loading = true;
      _lastError = null;
    });

    try {
      // Best-effort: ask backend to invalidate previous tokens before creating a new one.
      await ApiService.invalidatePreviousQrTokens();

      final token = await ApiService.generateQrToken();

      if (token != null) {
        if (!mounted) return;
        setState(() {
          _qrData = token; // Or show QR URL instead if you prefer
          _loading = false;
        });
      } else {
        throw Exception("Failed to generate QR");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrData = "DoctorAccess:${_uuid.v4()}"; // fallback
        _lastError =
            context.l10n.format('qr.generateError', {'error': e.toString()});
        _loading = false;
      });
    }
  }

  Future<void> _loadDynamicQrContent() async {
    try {
      final adsFuture = ApiService.fetchAdvertisements(placement: 'QR_PAGE');
      final configFuture = ApiService.fetchUiConfig();
      final results = await Future.wait([adsFuture, configFuture]);

      final ads = (results[0] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final config = results[1] as Map<String, dynamic>?;

      final qrActionsRaw = config?['qrActions'];
      final qrActions = qrActionsRaw is List
          ? qrActionsRaw
              .whereType<Map>()
              .map((item) => item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _qrAds = ads;
        _qrActions = qrActions;
        _remoteButtonColor = _parseHexColor(config?['buttonColor']);
        _remoteIconColor = _parseHexColor(config?['iconColor']);
      });
    } catch (e) {
      debugPrint('Failed to load QR dynamic content: $e');
    }
  }

  Color? _parseHexColor(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    var hex = raw.replaceAll('#', '').replaceAll('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return null;
    return Color(intValue);
  }

  IconData _iconFromName(String value) {
    switch (value.toLowerCase()) {
      case 'share':
        return Icons.share_rounded;
      case 'refresh':
      case 'regenerate':
        return Icons.refresh_rounded;
      case 'help':
      case 'info':
        return Icons.info_outline_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.auto('Unable to open the link')),
        ),
      );
    }
  }

  Future<void> _openTrackedAd(
    Map<String, dynamic> ad, {
    required String placement,
  }) async {
    final fallbackUrl = ad['redirectUrl']?.toString().trim() ?? '';
    if (fallbackUrl.isEmpty) return;

    String finalUrl = fallbackUrl;
    final adId =
        ad['_id']?.toString().trim() ?? ad['id']?.toString().trim() ?? '';
    if (adId.isNotEmpty) {
      final trackedUrl = await ApiService.fetchTrackedAdvertisementUrl(
        adId: adId,
        placement: placement,
      );
      if (trackedUrl != null && trackedUrl.isNotEmpty) {
        finalUrl = trackedUrl;
      }
    }

    if (!mounted) return;
    await _openExternalUrl(finalUrl);
  }

  Future<void> _handleQrAction(Map<String, dynamic> action) async {
    final label = action['label']?.toString().trim().toLowerCase() ?? '';
    final actionUrl = action['actionUrl']?.toString().trim() ?? '';

    if (actionUrl.isNotEmpty) {
      await _openExternalUrl(actionUrl);
      return;
    }

    if (label.contains('share')) {
      await _shareQR();
      return;
    }

    if (label.contains('regenerate') || label.contains('refresh')) {
      await _regenerateQR();
      return;
    }

    if (label.contains('help') || label.contains('how')) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QrAccessWorks()),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.auto('Action is not configured.'))),
    );
  }

  Future<void> _shareQR() async {
    try {
      final shareText = context.l10n.t('qr.shareText');
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final xfile =
          XFile.fromData(pngBytes, name: 'qr_code.png', mimeType: 'image/png');
      await Share.shareXFiles(
        [xfile],
        text: shareText,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.format('qr.shareError', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final primary = _remoteButtonColor ?? Theme.of(context).colorScheme.primary;
    final secondary =
        _remoteIconColor ?? Theme.of(context).colorScheme.secondary;
    final activeActions = _qrActions
        .where(
          (action) => action['isActive'] == null || action['isActive'] == true,
        )
        .toList(growable: false);
    final activeAds = _qrAds
        .where((ad) => ad['isActive'] == null || ad['isActive'] == true)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.t('qr.title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: Navigator.canPop(context),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // QR Card
              GestureDetector(
                onTap: () {
                  if (_qrData.isEmpty) return;
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 400),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) => QRZoomPage(qrData: _qrData),
                    ),
                  );
                },
                child: Hero(
                  tag: "qrHero",
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black26,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : QrImageView(
                                  data: _qrData,
                                  version: QrVersions.auto,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                l10n.t('qr.instructions'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),

              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  children: [
                    // Share QR
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, secondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _qrData.isEmpty ? null : _shareQR,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: Text(l10n.t('qr.share')),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Regenerate QR
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, secondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _regenerateQR,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: Text(l10n.t('qr.regenerate')),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Error/status box
                    if (_lastError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _lastError!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // How QR works link
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [primary, secondary],
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const QrAccessWorks()),
                          );
                        },
                        child: Text(
                          l10n.t('qr.accessHelp'),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    if (activeActions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.auto('Quick actions'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...activeActions.map((action) {
                        final label = action['label']?.toString().trim();
                        if (label == null || label.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final iconName =
                            action['icon']?.toString().trim() ?? 'info';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton.icon(
                            onPressed: () => _handleQrAction(action),
                            icon: Icon(_iconFromName(iconName)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              foregroundColor:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                              side: BorderSide(
                                color: primary.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            label: Text(label),
                          ),
                        );
                      }),
                    ],

                    if (activeAds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.auto('Sponsored'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...activeAds.map((ad) {
                        final title = ad['title']?.toString().trim();
                        final imageUrl = ad['imageUrl']?.toString().trim();
                        final redirectUrl =
                            ad['redirectUrl']?.toString().trim() ?? '';

                        if (title == null || title.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return InkWell(
                          onTap: redirectUrl.isEmpty
                              ? null
                              : () => _openTrackedAd(
                                    ad,
                                    placement: 'QR_PAGE',
                                  ),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 56,
                                            height: 56,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.local_hospital_outlined,
                                            size: 20,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                if (redirectUrl.isNotEmpty)
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    color: primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zoomed QR page (unchanged)
class QRZoomPage extends StatefulWidget {
  final String qrData;
  const QRZoomPage({super.key, required this.qrData});

  @override
  State<QRZoomPage> createState() => _QRZoomPageState();
}

class _QRZoomPageState extends State<QRZoomPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) => Navigator.pop(context));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: (Theme.of(context).brightness == Brightness.dark)
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Center(
              child: Hero(
                tag: "qrHero",
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: QrImageView(
                      data: widget.qrData,
                      version: QrVersions.auto,
                      size: 350.0,
                      backgroundColor: Colors.white,
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
