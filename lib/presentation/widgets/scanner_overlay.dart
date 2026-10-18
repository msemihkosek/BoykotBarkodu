import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ScannerOverlay extends StatefulWidget {
  final Rect scanWindow;

  const ScannerOverlay({
    super.key,
    required this.scanWindow,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _laserAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScannerPainter(
            scanWindow: widget.scanWindow,
            laserPosition: _laserAnimation.value,
          ),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final Rect scanWindow;
  final double laserPosition;

  _ScannerPainter({
    required this.scanWindow,
    required this.laserPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Viewfinder deliğini keserek arka planı çiz
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(24)));

    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalPath, backgroundPaint);

    // Kutu etrafında ince çerçeve
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(24)), borderPaint);

    // 4 Köşe vurguları (Köşebentler)
    final cornerPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;
    const radius = 24.0;

    // Sol Üst
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.left, scanWindow.top + cornerLength)
        ..lineTo(scanWindow.left, scanWindow.top + radius)
        ..arcToPoint(
          Offset(scanWindow.left + radius, scanWindow.top),
          radius: const Radius.circular(radius),
        )
        ..lineTo(scanWindow.left + cornerLength, scanWindow.top),
      cornerPaint,
    );

    // Sağ Üst
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.right - cornerLength, scanWindow.top)
        ..lineTo(scanWindow.right - radius, scanWindow.top)
        ..arcToPoint(
          Offset(scanWindow.right, scanWindow.top + radius),
          radius: const Radius.circular(radius),
        )
        ..lineTo(scanWindow.right, scanWindow.top + cornerLength),
      cornerPaint,
    );

    // Sol Alt
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.left, scanWindow.bottom - cornerLength)
        ..lineTo(scanWindow.left, scanWindow.bottom - radius)
        ..arcToPoint(
          Offset(scanWindow.left + radius, scanWindow.bottom),
          radius: const Radius.circular(radius),
        )
        ..lineTo(scanWindow.left + cornerLength, scanWindow.bottom),
      cornerPaint,
    );

    // Sağ Alt
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.right - cornerLength, scanWindow.bottom)
        ..lineTo(scanWindow.right - radius, scanWindow.bottom)
        ..arcToPoint(
          Offset(scanWindow.right, scanWindow.bottom - radius),
          radius: const Radius.circular(radius),
        )
        ..lineTo(scanWindow.right, scanWindow.bottom - cornerLength),
      cornerPaint,
    );

    // Kayan Lazer Çizgisi
    final laserY = scanWindow.top + (scanWindow.height * laserPosition);

    final laserGlowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primaryLight.withValues(alpha: 0.0),
          AppColors.primaryLight.withValues(alpha: 0.4),
          AppColors.primaryLight.withValues(alpha: 0.8),
          AppColors.primaryLight.withValues(alpha: 0.4),
          AppColors.primaryLight.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(scanWindow.left, laserY - 6, scanWindow.width, 12));

    canvas.drawRect(Rect.fromLTWH(scanWindow.left + 8, laserY - 3, scanWindow.width - 16, 6), laserGlowPaint);

    final laserLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(scanWindow.left + 16, laserY),
      Offset(scanWindow.right - 16, laserY),
      laserLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.laserPosition != laserPosition || oldDelegate.scanWindow != scanWindow;
  }
}
