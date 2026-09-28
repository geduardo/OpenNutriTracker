import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';

abstract final class PregnancyPalette {
  static const berry = Color(0xffa43762);
  static const plum = Color(0xff432a38);
  static const muted = Color(0xff735967);
  static const blush = Color(0xfffce3ed);
  static const canvas = Color(0xfffff7fa);
  static const lavender = Color(0xffeee7f7);
  static const border = Color(0xffedd9e2);
}

ThemeData pregnancyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PregnancyPalette.berry,
    primary: PregnancyPalette.berry,
    onPrimary: Colors.white,
    primaryContainer: PregnancyPalette.blush,
    onPrimaryContainer: PregnancyPalette.plum,
    surface: Colors.white,
    onSurface: PregnancyPalette.plum,
    onSurfaceVariant: PregnancyPalette.muted,
    outlineVariant: PregnancyPalette.border,
  );
  final base = ThemeData(
      useMaterial3: true, colorScheme: scheme, fontFamily: 'PregnancySans');
  final rounded =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
  return base.copyWith(
    scaffoldBackgroundColor: PregnancyPalette.canvas,
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
              fontSize: 28,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: PregnancyPalette.plum),
          titleLarge: const TextStyle(
              fontSize: 21,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: PregnancyPalette.plum),
          titleMedium: const TextStyle(
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: PregnancyPalette.plum),
          bodyMedium: const TextStyle(
              fontSize: 14, height: 1.65, color: PregnancyPalette.muted),
          bodyLarge: const TextStyle(
              fontSize: 16, height: 1.55, color: PregnancyPalette.plum),
        )
        .apply(fontFamily: 'PregnancySans'),
    appBarTheme: const AppBarTheme(
      backgroundColor: PregnancyPalette.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: PregnancyPalette.plum,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
    ),
    cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded.copyWith(
            side: const BorderSide(color: PregnancyPalette.border))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontFamily: 'PregnancySans',
                fontSize: 14,
                fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: PregnancyPalette.berry))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
                fontFamily: 'PregnancySans',
                fontSize: 13,
                fontWeight: FontWeight.w600))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(18),
      helperMaxLines: 3,
      errorMaxLines: 3,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PregnancyPalette.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: PregnancyPalette.berry, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: PregnancyPalette.blush,
      height: 78,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontFamily: 'PregnancySans',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? PregnancyPalette.berry
              : PregnancyPalette.muted)),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? PregnancyPalette.berry
              : PregnancyPalette.muted)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: PregnancyPalette.berry,
        collapsedIconColor: PregnancyPalette.muted,
        tilePadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
    dialogTheme: DialogThemeData(
        backgroundColor: PregnancyPalette.canvas, shape: rounded),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PregnancyPalette.plum,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );
}

class SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  const SoftIcon(this.icon,
      {super.key, this.background = PregnancyPalette.blush});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: PregnancyPalette.berry, size: 24),
      ));
}

class PregnancyHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const PregnancyHero(
      {super.key, required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [
            PregnancyPalette.blush,
            Color(0xfff7eaf1),
            PregnancyPalette.lavender
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(
            builder: (context, constraints) => Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const AppText('A LITTLE CARE, EVERY DAY',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                                color: PregnancyPalette.berry)),
                        const SizedBox(height: 14),
                        AppText(title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 32)),
                        const SizedBox(height: 12),
                        AppText(subtitle,
                            style: const TextStyle(
                                color: PregnancyPalette.plum, height: 1.6)),
                        if (action != null) ...[
                          const SizedBox(height: 22),
                          action!
                        ],
                      ])),
                  if (constraints.maxWidth > 540) ...[
                    const SizedBox(width: 28),
                    ExcludeSemantics(
                        child: Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 8)),
                            child: const Icon(Icons.favorite_rounded,
                                color: PregnancyPalette.berry, size: 58))),
                  ],
                ])),
      );
}

class PregnancyShortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;
  final Color tint;
  const PregnancyShortcut(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      required this.actionLabel,
      required this.onTap,
      this.tint = PregnancyPalette.blush});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftIcon(icon, background: tint),
                    const SizedBox(height: 16),
                    AppText(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    AppText(description),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: AppText(actionLabel,
                              style: const TextStyle(
                                  color: PregnancyPalette.berry,
                                  fontWeight: FontWeight.w600))),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 20, color: PregnancyPalette.berry)
                    ]),
                  ])),
        ),
      ));
}
