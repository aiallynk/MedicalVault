import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../screens/chat_screen.dart';

class AIFloatingButton extends StatefulWidget {
  final String? documentId;
  final String? documentName;

  const AIFloatingButton({
    super.key,
    this.documentId,
    this.documentName,
  });

  @override
  State<AIFloatingButton> createState() => _AIFloatingButtonState();
}

class _AIFloatingButtonState extends State<AIFloatingButton> {
  void _navigateToChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
          initialDocumentId: widget.documentId,
          initialDocumentName: widget.documentName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide from bottom with fade effect
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          var offsetAnimation = animation.drive(tween);
          var fadeAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToChat,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Lottie.asset(
          'assets/chatbot.json',
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}
