import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/product_stock.dart';
import 'package:pos_flutter_firebase/features/products/domain/product_repository.dart';
import 'package:pos_flutter_firebase/features/inventory/domain/stock_repository.dart';

class ProductGrid extends StatefulWidget {
  const ProductGrid({
    super.key,
    required this.businessId,
    required this.storeId,
    required this.searchQuery,
    required this.selectedCategoryId,
    required this.onTap,
  });

  final String businessId;
  final String storeId;
  final String searchQuery;
  final String? selectedCategoryId;
  final ValueChanged<Product> onTap;

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  late Stream<List<Product>> _productsStream;
  late Stream<Map<String, ProductStock>> _stockStream;

  @override
  void initState() {
    super.initState();
    _productsStream = context
        .read<ProductRepository>()
        .watchProducts(businessId: widget.businessId);
    _stockStream = context
        .read<StockRepository>()
        .watchStockByStore(businessId: widget.businessId, storeId: widget.storeId);
  }

  @override
  void didUpdateWidget(ProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _productsStream = context
          .read<ProductRepository>()
          .watchProducts(businessId: widget.businessId);
    }
    if (oldWidget.businessId != widget.businessId || oldWidget.storeId != widget.storeId) {
      _stockStream = context
          .read<StockRepository>()
          .watchStockByStore(businessId: widget.businessId, storeId: widget.storeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, productsSnapshot) {
        if (productsSnapshot.connectionState == ConnectionState.waiting && !productsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (productsSnapshot.hasError) {
          return Center(child: Text('Error: ${productsSnapshot.error}'));
        }
        return StreamBuilder<Map<String, ProductStock>>(
          stream: _stockStream,
          builder: (context, stockSnapshot) {
            final stocks = stockSnapshot.data ?? const <String, ProductStock>{};
            final allProducts = (productsSnapshot.data ?? const <Product>[]).map((product) {
              final stock = stocks[product.id];
              return Product(
                id: product.id,
                name: product.name,
                categoryId: product.categoryId,
                categoryName: product.categoryName,
                sellBy: product.sellBy,
                price: product.price,
                cost: product.cost,
                ref: product.ref,
                trackStock: product.trackStock,
                stockQuantity: stock?.stockQuantity ?? 0,
                lowStockAlertQuantity: stock?.lowStockAlertQuantity ?? product.lowStockAlertQuantity,
                chickenCount: stock?.chickenCount,
                presentationType: product.presentationType,
                presentationShape: product.presentationShape,
                presentationColor: product.presentationColor,
                imageUrl: product.imageUrl,
                localImagePath: product.localImagePath,
                active: product.active,
              );
            }).toList();
            final query = widget.searchQuery.toLowerCase();
            final products = allProducts.where((product) {
              final matchesCategory = widget.selectedCategoryId == null || product.categoryId == widget.selectedCategoryId;
              final matchesQuery = query.isEmpty ||
                  product.name.toLowerCase().contains(query) ||
                  product.ref.toLowerCase().contains(query);
              return matchesCategory && matchesQuery;
            }).toList();

            if (products.isEmpty) {
              return Center(
                child: Text(
                  allProducts.isEmpty
                      ? 'No tienes productos. Agrega el primero con + Producto.'
                      : 'No se encontraron productos con ese filtro.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return GridView.builder(
              key: const PageStorageKey('pos_product_grid'),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) => _ProductButton(product: products[index], onTap: () => widget.onTap(products[index])),
            );
          },
        );
      },
    );
  }
}

class _ProductButton extends StatelessWidget {
  const _ProductButton({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (product.presentationType == 'image' && product.localImagePath != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(product.localImagePath!), fit: BoxFit.cover),
              _bottomOverlay(context),
            ],
          ),
        ),
      );
    }
    final color = Color(product.presentationColor);

    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _shapeIcon(),
              const SizedBox(height: 6),
              Text(product.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              if (product.trackStock)
                Text('Stock: ${_formatQty(product.stockQuantity)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomOverlay(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _shapeIcon() {
    final shape = product.presentationShape;
    switch (shape) {
      case 'circle':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          child: const Center(child: Icon(Icons.inventory_2, color: Colors.white70, size: 28)),
        );
      case 'hexagon':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          child: const Center(child: Icon(Icons.category, color: Colors.white70, size: 28)),
        );
      default:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          child: const Center(child: Icon(Icons.inventory_2, color: Colors.white70, size: 28)),
        );
    }
  }

  String _formatQty(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(3);
  }
}


