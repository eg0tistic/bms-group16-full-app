import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Primary call-to-action button: teal brand gradient with a soft glow,
/// a pressed ripple, and an optional loading spinner.
class BrandButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.7,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: AppTokens.brand,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled ? AppTokens.glowTeal : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
