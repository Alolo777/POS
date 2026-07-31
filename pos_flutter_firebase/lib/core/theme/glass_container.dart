import 'package:flutter/material.dart';
import 'glass_theme.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 0,
    this.blur,
    this.borderOpacity,
    this.gradient,
    this.width,
    this.height,
    this.onTap,
    this.customDecoration,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? blur;
  final double? borderOpacity;
  final Gradient? gradient;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Decoration? customDecoration;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = color ?? (isDark ? const Color(0xFF25262B) : Colors.white);

    final decoration = customDecoration ?? BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.zero,
      border: border ?? Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.5),
      gradient: gradient,
    );

    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Container(decoration: decoration, child: child),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

extension GlassAnimationExtension on Widget {
  Widget withFadeIn({int milliseconds = 300}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: milliseconds),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: this,
    );
  }

  Widget withSlideUp({int milliseconds = 400}) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(0, 0.15), end: Offset.zero),
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) => FractionalTranslation(translation: offset, child: child),
      child: this,
    );
  }

  Widget withScaleIn({int milliseconds = 300}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1),
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: this,
    );
  }
}
