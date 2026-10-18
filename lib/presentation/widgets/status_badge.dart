import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/boycott_result.dart';

class StatusBadge extends StatelessWidget {
  final BoycottStatus status;
  final String text;
  final bool isLarge;

  const StatusBadge({
    super.key,
    required this.status,
    required this.text,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData icon;

    switch (status) {
      case BoycottStatus.boycott:
        bgColor = AppColors.boykotRed.withValues(alpha: 0.15);
        textColor = AppColors.boykotRed;
        borderColor = AppColors.boykotRed.withValues(alpha: 0.4);
        icon = Icons.cancel_rounded;
        break;
      case BoycottStatus.clean:
        bgColor = AppColors.safeGreen.withValues(alpha: 0.15);
        textColor = AppColors.safeGreen;
        borderColor = AppColors.safeGreen.withValues(alpha: 0.4);
        icon = Icons.check_circle_rounded;
        break;
      case BoycottStatus.suspected:
      case BoycottStatus.unknown:
        bgColor = AppColors.warnAmber.withValues(alpha: 0.15);
        textColor = AppColors.warnAmber;
        borderColor = AppColors.warnAmber.withValues(alpha: 0.4);
        icon = Icons.help_outline_rounded;
        break;
    }

    if (isLarge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 8),
            Text(
              text.toUpperCase(),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
