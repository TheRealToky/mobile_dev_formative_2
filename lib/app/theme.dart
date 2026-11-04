import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens and Material 3 themes for the app.
///
/// Every value here comes from `DESIGN_NOTES.md`; change both together.

/// Seed for the whole Material 3 colour scheme ("lake teal").
const Color kSeedColor = Color(0xFF0E5E6F);

/// Spacing scale in logical pixels. Use these instead of raw numbers.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. Rounder shapes are more temporary (sheets > cards > chips).
abstract final class Radii {
  static const double chip = 8;
  static const double card = 12;
  static const double sheet = 28;
}

/// Widest content column; keeps line length readable on tablets/landscape.
const double kMaxContentWidth = 640;

/// Foreground (icon + text) and container (background) colour for a status.
@immutable
class StatusPalette {
  const StatusPalette({required this.foreground, required this.container});

  final Color foreground;
  final Color container;

  StatusPalette lerp(StatusPalette other, double t) => StatusPalette(
    foreground: Color.lerp(foreground, other.foreground, t)!,
    container: Color.lerp(container, other.container, t)!,
  );
}

/// Semantic status colours, kept outside the seeded scheme so each status
/// means the same thing in light and dark mode.
///
/// Read it with `Theme.of(context).extension<StatusColors>()!`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.submitted,
    required this.underReview,
    required this.inProgress,
    required this.resolved,
    required this.rejected,
  });

  final StatusPalette submitted;
  final StatusPalette underReview;
  final StatusPalette inProgress;
  final StatusPalette resolved;
  final StatusPalette rejected;

  static const light = StatusColors(
    submitted: StatusPalette(
      foreground: Color(0xFF3D4F66),
      container: Color(0xFFE3E9F1),
    ),
    underReview: StatusPalette(
      foreground: Color(0xFF7A4E00),
      container: Color(0xFFFCEBC7),
    ),
    inProgress: StatusPalette(
      foreground: Color(0xFF9A3412),
      container: Color(0xFFFDE3D3),
    ),
    resolved: StatusPalette(
      foreground: Color(0xFF1E6B3C),
      container: Color(0xFFD7F0DF),
    ),
    rejected: StatusPalette(
      foreground: Color(0xFF9F1D1D),
      container: Color(0xFFFADBDB),
    ),
  );

  static const dark = StatusColors(
    submitted: StatusPalette(
      foreground: Color(0xFFC4D2E3),
      container: Color(0xFF2A3646),
    ),
    underReview: StatusPalette(
      foreground: Color(0xFFF5CD7A),
      container: Color(0xFF4A3300),
    ),
    inProgress: StatusPalette(
      foreground: Color(0xFFFDBA94),
      container: Color(0xFF5A2410),
    ),
    resolved: StatusPalette(
      foreground: Color(0xFF9FDCB4),
      container: Color(0xFF163F27),
    ),
    rejected: StatusPalette(
      foreground: Color(0xFFF3A6A6),
      container: Color(0xFF5C1616),
    ),
  );

  @override
  StatusColors copyWith({
    StatusPalette? submitted,
    StatusPalette? underReview,
    StatusPalette? inProgress,
    StatusPalette? resolved,
    StatusPalette? rejected,
  }) => StatusColors(
    submitted: submitted ?? this.submitted,
    underReview: underReview ?? this.underReview,
    inProgress: inProgress ?? this.inProgress,
    resolved: resolved ?? this.resolved,
    rejected: rejected ?? this.rejected,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      submitted: submitted.lerp(other.submitted, t),
      underReview: underReview.lerp(other.underReview, t),
      inProgress: inProgress.lerp(other.inProgress, t),
      resolved: resolved.lerp(other.resolved, t),
      rejected: rejected.lerp(other.rejected, t),
    );
  }
}

/// Builds the light and dark [ThemeData] from one seed colour.
abstract final class AppTheme {
  /// Light theme. Pass `useGoogleFont: false` in tests to avoid network.
  static ThemeData light({bool useGoogleFont = true}) =>
      _build(Brightness.light, useGoogleFont: useGoogleFont);

  /// Dark theme generated from the same seed.
  static ThemeData dark({bool useGoogleFont = true}) =>
      _build(Brightness.dark, useGoogleFont: useGoogleFont);

  static ThemeData _build(
    Brightness brightness, {
    required bool useGoogleFont,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, useGoogleFont);
    final roundedField = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.card),
    );
    const buttonSize = Size(48, 52);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
    );

    return base.copyWith(
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [
        brightness == Brightness.light ? StatusColors.light : StatusColors.dark,
      ],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: roundedField,
        enabledBorder: roundedField.copyWith(
          borderSide: BorderSide(color: scheme.outline),
        ),
        filled: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }

  /// Applies Atkinson Hyperlegible and the weights from DESIGN_NOTES.md.
  static TextTheme _textTheme(TextTheme base, bool useGoogleFont) {
    final themed = useGoogleFont
        ? GoogleFonts.atkinsonHyperlegibleTextTheme(base)
        : base;
    const bold = FontWeight.w700;
    return themed.copyWith(
      headlineSmall: themed.headlineSmall?.copyWith(fontWeight: bold),
      titleLarge: themed.titleLarge?.copyWith(fontWeight: bold),
      titleMedium: themed.titleMedium?.copyWith(fontWeight: bold),
      labelLarge: themed.labelLarge?.copyWith(fontWeight: bold),
      labelMedium: themed.labelMedium?.copyWith(fontWeight: bold),
    );
  }
}
