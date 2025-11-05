import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:hello/HowQrAcessWorks.dart';
import 'package:hello/api_service.dart';
import 'package:hello/main.dart';

/// 👉 Backend base URL (no trailing slash)
const String kApiBase = 'https://backend-medicalvault.onrender.com';

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

  @override
  void initState() {
    super.initState();
    _regenerateQR(); // auto-generate on open

    // Set status bar style
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusBarHelper.setStatusBarStyle(context);
    });
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
        _lastError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _shareQR() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final xfile =
          XFile.fromData(pngBytes, name: 'qr_code.png', mimeType: 'image/png');
      await Share.shareXFiles([xfile], text: 'Share this QR code');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'QR Code',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to previous screen
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
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
                "Doctor will scan this QR to request access",
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
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
                        label: const Text("Share QR"),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Regenerate QR
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
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
                        label: const Text("Regenerate QR"),
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
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
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
                        child: const Text(
                          "How QR access works?",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
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
                    ? Colors.black.withOpacity(0.6)
                    : Colors.white.withOpacity(0.6),
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
