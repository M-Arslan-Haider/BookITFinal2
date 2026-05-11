import 'package:flutter/material.dart';
import 'dart:async';

enum FancySnackType { success, error, warning, info, sync }

class FancySnackBar {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
      BuildContext context, {
        required String title,
        required String message,
        FancySnackType type = FancySnackType.info,
        Duration duration = const Duration(seconds: 4),
      }) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FancySnackWidget(
        title: title,
        message: message,
        type: type,
        onDismiss: () {
          _dismissTimer?.cancel();
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      entry.remove();
      if (_currentEntry == entry) _currentEntry = null;
    });
  }
}

class _FancySnackWidget extends StatefulWidget {
  final String title;
  final String message;
  final FancySnackType type;
  final VoidCallback onDismiss;

  const _FancySnackWidget({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_FancySnackWidget> createState() => _FancySnackWidgetState();
}

class _FancySnackWidgetState extends State<_FancySnackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _TypeConfig get _cfg {
    switch (widget.type) {
      case FancySnackType.success:
        return _TypeConfig(
          bg: const Color(0xFF37474F),
          accent: const Color(0xFF4CAF50),
          icon: Icons.check_circle_rounded,
          bubbleColor: const Color(0xFF4CAF50).withOpacity(0.25),
        );
      case FancySnackType.error:
        return _TypeConfig(
          bg: const Color(0xFF37474F),
          accent: const Color(0xFFEF5350),
          icon: Icons.cancel_rounded,
          bubbleColor: const Color(0xFFEF5350).withOpacity(0.25),
        );
      case FancySnackType.warning:
        return _TypeConfig(
          bg: const Color(0xFF37474F),
          accent: const Color(0xFFFF9800),
          icon: Icons.warning_rounded,
          bubbleColor: const Color(0xFFFF9800).withOpacity(0.25),
        );
      case FancySnackType.sync:
        return _TypeConfig(
          bg: const Color(0xFF37474F),
          accent: const Color(0xFF29B6F6),
          icon: Icons.cloud_sync_rounded,
          bubbleColor: const Color(0xFF29B6F6).withOpacity(0.25),
        );
      case FancySnackType.info:
      default:
        return _TypeConfig(
          bg: const Color(0xFF455A64),
          accent: const Color(0xFF90A4AE),
          icon: Icons.info_rounded,
          bubbleColor: const Color(0xFF90A4AE).withOpacity(0.25),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left bubble icon area
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Large background bubble
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cfg.bubbleColor,
                          ),
                        ),
                        // Small decorative bubble top-left
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cfg.accent.withOpacity(0.3),
                            ),
                          ),
                        ),
                        // Icon
                        Icon(cfg.icon, color: cfg.accent, size: 26),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss X
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeConfig {
  final Color bg;
  final Color accent;
  final IconData icon;
  final Color bubbleColor;
  const _TypeConfig({
    required this.bg,
    required this.accent,
    required this.icon,
    required this.bubbleColor,
  });
}