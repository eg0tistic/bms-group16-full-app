import 'package:flutter/material.dart';

/// Single source of truth for the app's visual language.
/// Spacing follows a 4pt grid; radii, shadows, and gradients come in a
/// small fixed set so every screen uses the same vocabulary.
abstract final class AppTokens {
  // Brand palette: Sudanese green with a warm clay action accent.
  static const ink = Color(0xFF18231E);
  static const inkSoft = Color(0xFF37473F);
  static const muted = Color(0xFF5F6F67);
  static const bg = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDCE5E0);
  static const borderStrong = Color(0xFFB8C8C0);

  static const teal = Color(0xFF0F6B58);
  static const tealDark = Color(0xFF0A4C3F);
  static const tealTint = Color(0xFFDCEFE8);
  static const clay = Color(0xFFC95636);
  static const clayDark = Color(0xFFA8422A);
  static const clayTint = Color(0xFFF9E8E2);
  static const gold = Color(0xFFA87517);
  static const goldTint = Color(0xFFF7EED9);

  // ── Semantic colors (each with a soft tint for containers) ─────────────
  static const success = Color(0xFF047857);
  static const successTint = Color(0xFFE6F6EF);
  static const warning = Color(0xFFB45309);
  static const warningTint = Color(0xFFFCF3E3);
  static const danger = Color(0xFFDC2626);
  static const dangerTint = Color(0xFFFDECEC);
  static const info = Color(0xFF2563EB);
  static const infoTint = Color(0xFFE8F0FE);

  // ── Radii ──────────────────────────────────────────────────────────────
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rXl = 24;

  // ── Shadows (layered, very soft — depth without heaviness) ─────────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 5)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> glowTeal = [
    BoxShadow(color: Color(0x2E0F6B58), blurRadius: 18, offset: Offset(0, 8)),
  ];

  // ── Gradients ──────────────────────────────────────────────────────────
  /// Dark brand surfaces used sparingly for identity and navigation.
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF173F35), Color(0xFF102820)],
  );

  /// Brand call-to-action gradient.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF13806A), Color(0xFF0A584A)],
  );

  /// Vertical bar-chart fill.
  static const bar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD66B4D), Color(0xFFC95636)],
  );
}
