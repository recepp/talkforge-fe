import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the "Gece Stüdyosu" modernization handoff, exposed as
/// a ThemeExtension so widgets read `Theme.of(context).extension<AppColors>()!`
/// instead of hardcoding colors per-screen.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.bord,
    required this.bordSoft,
    required this.tx,
    required this.tx2,
    required this.tx3,
    required this.acc,
    required this.accSoft,
    required this.accTx,
    required this.roleWriterTx,
  });

  final Color bg;
  final Color surf;
  final Color surf2;
  final Color bord;
  final Color bordSoft;
  final Color tx;
  final Color tx2;
  final Color tx3;
  final Color acc;
  final Color accSoft;
  final Color accTx;

  /// "Yazar" role pill text color — the one token that differs by theme
  /// independently of the acc/tx scale (dark:#34D399, light:#047857).
  final Color roleWriterTx;

  // Status colors are identical across both themes.
  static const Color completed = Color(0xFF10B981);
  static const Color processing = Color(0xFF3B82F6);
  static const Color pending = Color(0xFFF59E0B);
  static const Color failed = Color(0xFFEF4444);
  static const Color sharedBadgeBg = Color(0x1F10B981); // rgba(16,185,129,.12)
  static const Color sharedBadgeTx = Color(0xFF34D399);
  static const Color dangerTx = Color(0xFFF87171);
  static const Color dangerBord = Color(0x59F87171); // rgba(248,113,113,.35)

  static const AppColors dark = AppColors(
    bg: Color(0xFF0C111D),
    surf: Color(0xFF151B2B),
    surf2: Color(0xFF0F1522),
    bord: Color(0x2494A3B8), // rgba(148,163,184,.14)
    bordSoft: Color(0x1494A3B8), // rgba(148,163,184,.08)
    tx: Color(0xFFF1F5F9),
    tx2: Color(0xFFA6AEC0),
    tx3: Color(0xFF64748B),
    acc: Color(0xFF6366F1),
    accSoft: Color(0x246366F1), // rgba(99,102,241,.14)
    accTx: Color(0xFFC7D2FE),
    roleWriterTx: Color(0xFF34D399),
  );

  static const AppColors light = AppColors(
    bg: Color(0xFFF4F6FA),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFEEF1F7),
    bord: Color(0x1F0F172A), // rgba(15,23,42,.12)
    bordSoft: Color(0x120F172A), // rgba(15,23,42,.07)
    tx: Color(0xFF0F172A),
    tx2: Color(0xFF46506A),
    tx3: Color(0xFF7C8699),
    acc: Color(0xFF4F46E5),
    accSoft: Color(0x174F46E5), // rgba(79,70,229,.09)
    accTx: Color(0xFF4338CA),
    roleWriterTx: Color(0xFF047857),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surf,
    Color? surf2,
    Color? bord,
    Color? bordSoft,
    Color? tx,
    Color? tx2,
    Color? tx3,
    Color? acc,
    Color? accSoft,
    Color? accTx,
    Color? roleWriterTx,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surf: surf ?? this.surf,
      surf2: surf2 ?? this.surf2,
      bord: bord ?? this.bord,
      bordSoft: bordSoft ?? this.bordSoft,
      tx: tx ?? this.tx,
      tx2: tx2 ?? this.tx2,
      tx3: tx3 ?? this.tx3,
      acc: acc ?? this.acc,
      accSoft: accSoft ?? this.accSoft,
      accTx: accTx ?? this.accTx,
      roleWriterTx: roleWriterTx ?? this.roleWriterTx,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surf: Color.lerp(surf, other.surf, t)!,
      surf2: Color.lerp(surf2, other.surf2, t)!,
      bord: Color.lerp(bord, other.bord, t)!,
      bordSoft: Color.lerp(bordSoft, other.bordSoft, t)!,
      tx: Color.lerp(tx, other.tx, t)!,
      tx2: Color.lerp(tx2, other.tx2, t)!,
      tx3: Color.lerp(tx3, other.tx3, t)!,
      acc: Color.lerp(acc, other.acc, t)!,
      accSoft: Color.lerp(accSoft, other.accSoft, t)!,
      accTx: Color.lerp(accTx, other.accTx, t)!,
      roleWriterTx: Color.lerp(roleWriterTx, other.roleWriterTx, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.acc` instead of
/// `Theme.of(context).extension<AppColors>()!.acc`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  AppTheme._();

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.schibstedGroteskTextTheme(base.textTheme).apply(
      bodyColor: c.tx,
      displayColor: c.tx,
    );

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      useMaterial3: true,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: c.acc,
        secondary: c.accTx,
        surface: c.surf,
        error: AppColors.failed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.tx,
        elevation: 0,
        titleTextStyle: GoogleFonts.schibstedGrotesk(
          color: c.tx,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerColor: c.bordSoft,
      extensions: [c],
    );
  }

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);
}
