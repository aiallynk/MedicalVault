import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  
  const SplashScreen({
    super.key,
    required this.child,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _gradientController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _gradientAnimation;
  
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    
    // Fade animation for text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Scale animation for logo
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Gradient animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _gradientController,
        curve: Curves.easeInOut,
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    // Start scale animation
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_isDisposed) {
      _scaleController.forward();
    }

    // Start fade animation
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isDisposed) {
      _fadeController.forward();
    }

    // Navigate after animations complete
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!_isDisposed && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.child,
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fadeController.dispose();
    _scaleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Set status bar style for splash
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        // Dark theme gradient
                        Color.lerp(
                          const Color(0xFF0A0E27),
                          const Color(0xFF1A1F3A),
                          _gradientAnimation.value,
                        )!,
                        Color.lerp(
                          const Color(0xFF1A1F3A),
                          const Color(0xFF2D3561),
                          _gradientAnimation.value,
                        )!,
                        Color.lerp(
                          const Color(0xFF2D3561),
                          const Color(0xFF1A1F3A),
                          _gradientAnimation.value,
                        )!,
                      ]
                    : [
                        // Light theme gradient
                        Color.lerp(
                          const Color(0xFF4A90E2),
                          const Color(0xFF5BA3F5),
                          _gradientAnimation.value,
                        )!,
                        Color.lerp(
                          const Color(0xFF50E3C2),
                          const Color(0xFF6EF4D8),
                          _gradientAnimation.value,
                        )!,
                        Color.lerp(
                          const Color(0xFF6EF4D8),
                          const Color(0xFF50E3C2),
                          _gradientAnimation.value,
                        )!,
                      ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo/Icon with glow effect
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Main container
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.medical_services_rounded,
                                size: 70,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Animated "Medical Vault" Text
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Text with gradient and shadow
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.9),
                                Colors.white.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: const Text(
                              'Medical Vault',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnimation.value * 0.8,
                                child: Text(
                                  'Your Health, Your Vault',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Loading indicator
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

