import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/shared/models/product_stock.dart';
import 'package:pos_flutter_firebase/features/products/domain/product_repository.dart';
import 'package:pos_flutter_firebase/features/inventory/domain/stock_repository.dart';
import 'package:pos_flutter_firebase/features/pos/ui/widgets/product_grid.dart';

class MockProductRepository extends Mock implements ProductRepository {}
class MockStockRepository extends Mock implements StockRepository {}

Product makeProduct({
  String id = 'prod_1',
  String name = 'Test Product',
  String? categoryId,
  String? categoryName,
  String sellBy = 'unit',
  double price = 10.0,
  double cost = 5.0,
  String ref = 'REF-001',
  bool trackStock = true,
  double stockQuantity = 50,
  double lowStockAlertQuantity = 5,
  int presentationColor = 0xFF607D8B,
  bool active = true,
}) {
  return Product(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryName,
    sellBy: sellBy,
    price: price,
    cost: cost,
    ref: ref,
    trackStock: trackStock,
    stockQuantity: stockQuantity,
    lowStockAlertQuantity: lowStockAlertQuantity,
    presentationType: 'shape',
    presentationShape: 'square',
    presentationColor: presentationColor,
    imageUrl: null,
    localImagePath: null,
    active: active,
  );
}

Widget buildApp({
  required ProductRepository productRepo,
  required StockRepository stockRepo,
  String searchQuery = '',
  String? selectedCategoryId,
  void Function(Product)? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MultiProvider(
        providers: [
          Provider<ProductRepository>.value(value: productRepo),
          Provider<StockRepository>.value(value: stockRepo),
        ],
        child: ProductGrid(
          businessId: 'biz_1',
          storeId: 'store_1',
          searchQuery: searchQuery,
          selectedCategoryId: selectedCategoryId,
          onTap: onTap ?? (_) {},
        ),
      ),
    ),
  );
}

Future<void> emitData(
  WidgetTester tester,
  StreamController<List<Product>> productController,
  StreamController<Map<String, ProductStock>> stockController, {
  List<Product> products = const [],
  Map<String, ProductStock> stocks = const {},
}) async {
  productController.add(products);
  await tester.pump();
  stockController.add(stocks);
  await tester.pumpAndSettle();
}

void main() {
  late MockProductRepository mockProductRepo;
  late MockStockRepository mockStockRepo;
  late StreamController<List<Product>> productController;
  late StreamController<Map<String, ProductStock>> stockController;

  setUp(() {
    mockProductRepo = MockProductRepository();
    mockStockRepo = MockStockRepository();
    productController = StreamController<List<Product>>.broadcast();
    stockController = StreamController<Map<String, ProductStock>>.broadcast();

    when(() => mockProductRepo.watchProducts(businessId: any(named: 'businessId')))
        .thenAnswer((_) => productController.stream);
    when(() => mockStockRepo.watchStockByStore(
      businessId: any(named: 'businessId'),
      storeId: any(named: 'storeId'),
    )).thenAnswer((_) => stockController.stream);
  });

  tearDown(() {
    productController.close();
    stockController.close();
  });

  group('ProductGrid', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no products', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      await emitData(tester, productController, stockController, products: []);

      expect(find.text('No tienes productos. Agrega el primero con + Producto.'), findsOneWidget);
    });

    testWidgets('shows products in grid', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Coca Cola', price: 25.0),
        makeProduct(id: 'p2', name: 'Sabritas', price: 18.0),
      ]);

      expect(find.text('Coca Cola'), findsOneWidget);
      expect(find.text('Sabritas'), findsOneWidget);
      expect(find.text('\$25.00'), findsOneWidget);
      expect(find.text('\$18.00'), findsOneWidget);
    });

    testWidgets('displays stock quantity for tracked products', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Leche', trackStock: true),
      ], stocks: {
        'p1': const ProductStock(productId: 'p1', storeId: 'store_1', stockQuantity: 20, lowStockAlertQuantity: 5),
      });

      expect(find.text('Stock: 20'), findsOneWidget);
    });

    testWidgets('filters by search query', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
        searchQuery: 'Coca',
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Coca Cola'),
        makeProduct(id: 'p2', name: 'Sabritas'),
        makeProduct(id: 'p3', name: 'Cafe'),
      ]);

      expect(find.text('Coca Cola'), findsOneWidget);
      expect(find.text('Sabritas'), findsNothing);
    });

    testWidgets('filters by category', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
        selectedCategoryId: 'cat_bebidas',
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Coca Cola', categoryId: 'cat_bebidas', categoryName: 'Bebidas'),
        makeProduct(id: 'p2', name: 'Sabritas', categoryId: 'cat_comida', categoryName: 'Comida'),
      ]);

      expect(find.text('Coca Cola'), findsOneWidget);
      expect(find.text('Sabritas'), findsNothing);
    });

    testWidgets('calls onTap when product is tapped', (tester) async {
      Product? tappedProduct;
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
        onTap: (p) => tappedProduct = p,
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Tap Me', price: 15.0),
      ]);

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tappedProduct, isNotNull);
      expect(tappedProduct!.id, 'p1');
      expect(tappedProduct!.name, 'Tap Me');
    });

    testWidgets('shows error state on stream error', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      productController.addError(Exception('Firebase error'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('renders product with stock from StockRepository', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Galletas', trackStock: true),
      ], stocks: {
        'p1': const ProductStock(
          productId: 'p1', storeId: 'store_1', stockQuantity: 100, lowStockAlertQuantity: 10,
        ),
      });

      expect(find.text('Stock: 100'), findsOneWidget);
    });

    testWidgets('hides stock for non-tracked products', (tester) async {
      await tester.pumpWidget(buildApp(
        productRepo: mockProductRepo,
        stockRepo: mockStockRepo,
      ));

      await emitData(tester, productController, stockController, products: [
        makeProduct(id: 'p1', name: 'Servicio', trackStock: false),
      ]);

      expect(find.textContaining('Stock:'), findsNothing);
    });
  });
}
