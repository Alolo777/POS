import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductPresentation extends StatelessWidget {
  const ProductPresentation({
    super.key,
    required this.product,
    this.size = 56,
  });

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (product.presentationType == 'image' && product.localImagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(product.localImagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _ShapePresentation(product: product, size: size),
        ),
      );
    }

    if (product.presentationType == 'image' && product.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          product.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _ShapePresentation(product: product, size: size),
        ),
      );
    }

    return _ShapePresentation(product: product, size: size);
  }
}

class _ShapePresentation extends StatelessWidget {
  const _ShapePresentation({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(product.presentationColor);
    final child = Center(
      child: Text(
        product.name.isEmpty ? '?' : product.name.characters.first.toUpperCase(),
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.32,
        ),
      ),
    );

    if (product.presentationShape == 'circle') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child,
      );
    }

    if (product.presentationShape == 'hexagon') {
      return ClipPath(
        clipper: _HexagonClipper(),
        child: Container(width: size, height: size, color: color, child: child),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final width = size.width;
    final height = size.height;

    return Path()
      ..moveTo(width * 0.5, 0)
      ..lineTo(width, height * 0.25)
      ..lineTo(width, height * 0.75)
      ..lineTo(width * 0.5, height)
      ..lineTo(0, height * 0.75)
      ..lineTo(0, height * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
