import 'package:flutter/material.dart';
import 'colors.dart';

/// Tokens de color SEMÁNTICOS que cambian según el tema (claro/oscuro).
///
/// Las constantes crudas de marca ([kPrimary], semáforo…) son fijas y afinadas
/// para claro; sobre fondo oscuro quedan o muy brillantes (el azul) o con poco
/// contraste (rojo/naranja como texto). Este `ThemeExtension` define la versión
/// correcta de cada rol POR TEMA, siguiendo `Design-Tokens`: el modo oscuro solo
/// cambia estos tokens, los widgets usan `context.sgi.<rol>` y no se enteran.
@immutable
class SgiColors extends ThemeExtension<SgiColors> {
  /// Fondo de barras/headers/botones de marca (su texto es blanco).
  final Color brandBar;

  /// El azul de marca usado como TEXTO / icono / indicador activo sobre una
  /// superficie (en oscuro se aclara para cumplir contraste).
  final Color accent;

  /// Colores de estado usados como TEXTO/icono sobre superficie (aclarados en
  /// oscuro). El FONDO translúcido de los chips usa el color crudo vía [tileAlpha].
  final Color danger;
  final Color warning;
  final Color success;
  final Color orange;

  /// Opacidad del fondo de tiles/chips de estado (suave en claro, más visible
  /// en oscuro).
  final double tileAlpha;

  const SgiColors({
    required this.brandBar,
    required this.accent,
    required this.danger,
    required this.warning,
    required this.success,
    required this.orange,
    required this.tileAlpha,
  });

  /// Fondo translúcido de un chip/tile de estado a partir de su color.
  Color tileBg(Color c) => c.withValues(alpha: tileAlpha);

  static const light = SgiColors(
    brandBar: kPrimary,            // #007BFF
    accent: kPrimary,             // #007BFF
    danger: kDanger,              // #DC3545
    warning: kWarning,            // #FFC107
    success: kSuccess,            // #28A745
    orange: Color(0xFFE65100),
    tileAlpha: 0.07,
  );

  static const dark = SgiColors(
    brandBar: Color(0xFF123A6B),  // navy apagado — texto blanco ≈11:1
    accent: Color(0xFF6FA8FF),    // azul claro ≈6.6:1 sobre surface oscuro
    danger: Color(0xFFFF6B78),    // ≈5.8:1
    warning: Color(0xFFFFCA28),
    success: Color(0xFF4ADE80),
    orange: Color(0xFFFF9E5C),
    tileAlpha: 0.18,
  );

  @override
  SgiColors copyWith({
    Color? brandBar,
    Color? accent,
    Color? danger,
    Color? warning,
    Color? success,
    Color? orange,
    double? tileAlpha,
  }) =>
      SgiColors(
        brandBar: brandBar ?? this.brandBar,
        accent: accent ?? this.accent,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        success: success ?? this.success,
        orange: orange ?? this.orange,
        tileAlpha: tileAlpha ?? this.tileAlpha,
      );

  @override
  SgiColors lerp(ThemeExtension<SgiColors>? other, double t) {
    if (other is! SgiColors) return this;
    return SgiColors(
      brandBar: Color.lerp(brandBar, other.brandBar, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      tileAlpha: (tileAlpha + (other.tileAlpha - tileAlpha) * t),
    );
  }
}

/// Acceso corto a los tokens semánticos: `context.sgi.brandBar`.
/// Si el tema no registró la extensión (p. ej. en un test que monta una
/// pantalla con un `MaterialApp` propio), cae a [SgiColors.light] en vez de
/// lanzar, para no romper widgets fuera de `AppTheme`.
extension SgiColorsContext on BuildContext {
  SgiColors get sgi => Theme.of(this).extension<SgiColors>() ?? SgiColors.light;
}

/// Temas claro y oscuro. Las superficies se FIJAN con `.copyWith` sobre el
/// `ColorScheme` semilla (el claro queda blanco puro como el diseño de Stitch;
/// el oscuro usa un gris azulado de marca). Los colores semánticos viven en
/// [SgiColors].
class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  // Paleta clara (Stitch)
  static const _lightBg = Color(0xFFF8F9FA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightOnSurface = Color(0xFF223542);
  static const _lightOnSurfaceVariant = kTextMuted;
  static const _lightOutlineVariant = Color(0xFFDEE2E6);

  // Paleta oscura (gris azulado de marca)
  static const _darkBg = Color(0xFF0E1620);
  static const _darkSurface = Color(0xFF1A2230);
  static const _darkContainer = Color(0xFF222C3C);
  static const _darkContainerHigh = Color(0xFF2A3647);
  static const _darkOnSurface = Color(0xFFE3E8EE);
  static const _darkOnSurfaceVariant = Color(0xFF9FB0BE);
  static const _darkOutlineVariant = Color(0xFF35414F);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: kPrimary, brightness: brightness);
    final scheme = isDark
        ? base.copyWith(
            surface: _darkSurface,
            onSurface: _darkOnSurface,
            onSurfaceVariant: _darkOnSurfaceVariant,
            outlineVariant: _darkOutlineVariant,
            surfaceContainerLowest: _darkBg,
            surfaceContainerLow: _darkSurface,
            surfaceContainer: _darkContainer,
            surfaceContainerHigh: _darkContainerHigh,
            surfaceContainerHighest: _darkContainerHigh,
          )
        : base.copyWith(
            surface: _lightSurface,
            onSurface: _lightOnSurface,
            onSurfaceVariant: _lightOnSurfaceVariant,
            outlineVariant: _lightOutlineVariant,
            surfaceContainerLowest: _lightSurface,
            surfaceContainerLow: _lightBg,
            surfaceContainer: _lightBg,
            surfaceContainerHigh: _lightBg,
            surfaceContainerHighest: _lightBg,
          );

    return ThemeData(
      colorScheme: scheme,
      primaryColor: kPrimary,
      scaffoldBackgroundColor: isDark ? _darkBg : _lightBg,
      useMaterial3: true,
      extensions: [isDark ? SgiColors.dark : SgiColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 2,
        shadowColor: Colors.black26,
      ),
      // Inputs correctos en ambos temas desde un solo lugar: antes cada
      // pantalla ponía su fillColor blanco y chocaba en oscuro.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkContainerHigh : _lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDanger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Oscuro: navy apagado de marca (como los headers); claro: azul de marca.
          backgroundColor: isDark ? SgiColors.dark.brandBar : kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: kPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: kPrimary,
      ),
    );
  }
}
