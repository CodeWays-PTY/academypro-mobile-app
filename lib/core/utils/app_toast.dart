import 'package:flutter/material.dart';

class AppToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _currentOverlay;

  /// Displays a modern, floating toast safe-area banner below the status bar.
  static void showSuccess(BuildContext? context, {required String title, String? message}) {
    final ctx = context ?? navigatorKey.currentContext;
    if (ctx == null) return;
    _showToast(
      ctx,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF0F172A),
      accentColor: const Color(0xFF10B981),
    );
  }

  static void showError(BuildContext? context, {required String title, String? message}) {
    final ctx = context ?? navigatorKey.currentContext;
    if (ctx == null) return;
    _showToast(
      ctx,
      title: title,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: const Color(0xFF7F1D1D),
      accentColor: const Color(0xFFF87171),
    );
  }

  static void showInfo(BuildContext? context, {required String title, String? message}) {
    final ctx = context ?? navigatorKey.currentContext;
    if (ctx == null) return;
    _showToast(
      ctx,
      title: title,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: const Color(0xFF003EC7),
      accentColor: const Color(0xFF60A5FA),
    );
  }

  static void _showToast(
    BuildContext context, {
    required String title,
    String? message,
    required IconData icon,
    required Color backgroundColor,
    required Color accentColor,
  }) {
    // Remove previous toast overlay if active
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback to standard SnackBar if overlay context is unavailable
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: ${message ?? ''}'),
          backgroundColor: backgroundColor,
        ),
      );
      return;
    }

    final topInset = MediaQuery.of(context).padding.top;
    // Guaranteed top margin sitting completely below hardware notch / status bar
    final topOffset = topInset > 0 ? topInset + 12.0 : 54.0;

    OverlayEntry entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: topOffset,
          left: 16.0,
          right: 16.0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () {
                  _currentOverlay?.remove();
                  _currentOverlay = null;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16.0,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accentColor, size: 22.0),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (message != null && message.trim().isNotEmpty) ...[
                              const SizedBox(height: 3.0),
                              Text(
                                message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12.0,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6), size: 18.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentOverlay = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (_currentOverlay == entry) {
        entry.remove();
        _currentOverlay = null;
      }
    });
  }
}
