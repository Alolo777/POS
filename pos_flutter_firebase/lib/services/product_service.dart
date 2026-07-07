import 'dart:typed_data';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/product.dart';
import 'connectivity_service.dart';

class ProductService {
  final _db = FirebaseFirestore.instance;
  final _connectivityService = ConnectivityService();

  Stream<List<Product>> watchProducts({required String businessId}) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs.map(Product.fromDoc).toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    });
  }

  Future<String> getSuggestedRef({required String businessId}) async {
    await _connectivityService.requireConnection('Generar REF automatico');

    final counterDoc = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('counters')
        .doc('products')
        .get();

    final nextNumber = (counterDoc.data()?['nextRefNumber'] as num? ?? 1).toInt();
    return nextNumber.toString().padLeft(6, '0');
  }

  Future<void> addProduct({
    required String businessId,
    required String storeId,
    required String name,
    required String? categoryId,
    required String? categoryName,
    required String sellBy,
    required double price,
    required double cost,
    required String ref,
    required bool trackStock,
    required double stockQuantity,
    required double lowStockAlertQuantity,
    required String presentationType,
    required String presentationShape,
    required int presentationColor,
    XFile? imageFile,
  }) async {
    await _connectivityService.requireConnection('Crear producto');

    final trimmedName = name.trim();
    final normalizedRef = ref.trim().toUpperCase();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre es obligatorio');
    }
    if (normalizedRef.isEmpty) {
      throw StateError('El REF es obligatorio');
    }
    if (price < 0 || cost < 0) {
      throw StateError('Precio y coste no pueden ser negativos');
    }
    if (trackStock && stockQuantity < 0) {
      throw StateError('El inventario no puede ser negativo');
    }
    if (trackStock && sellBy == 'unit' && stockQuantity % 1 != 0) {
      throw StateError('Los productos por unidad deben usar cantidades enteras');
    }

    final productsRef = _db.collection('businesses').doc(businessId).collection('products');
    final productRef = productsRef.doc();
    final stockRef = productRef.collection('stockByStore').doc(storeId);
    final refLockRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('productRefs')
        .doc(normalizedRef);
    final counterRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('counters')
        .doc('products');
    final localImagePath = imageFile == null
        ? null
        : await _saveProductImageLocally(
            businessId: businessId,
            productId: productRef.id,
            imageFile: imageFile,
          );

    await _db.runTransaction((transaction) async {
      final existingRef = await transaction.get(refLockRef);
      if (existingRef.exists) {
        throw StateError('Ya existe un producto con ese REF');
      }

      final counterSnapshot = await transaction.get(counterRef);
      final currentNext = (counterSnapshot.data()?['nextRefNumber'] as num? ?? 1).toInt();
      final numericRef = int.tryParse(normalizedRef);
      final nextRefNumber = numericRef != null && numericRef >= currentNext
          ? numericRef + 1
          : currentNext;

      transaction.set(refLockRef, {
        'productId': productRef.id,
        'ref': normalizedRef,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(counterRef, {
        'nextRefNumber': nextRefNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(productRef, {
        'businessId': businessId,
        'name': trimmedName,
        'description': '',
        'sku': normalizedRef,
        'barcode': '',
        'categoryId': categoryId,
        'categoryName': categoryName,
        'sellBy': sellBy,
        'imageUrl': null,
        'localImagePath': localImagePath,
        'price': price,
        'cost': cost,
        'ref': normalizedRef,
        'trackStock': trackStock,
        'stock': trackStock ? stockQuantity.round() : 0,
        'stockQuantity': trackStock ? stockQuantity : 0,
        'lowStockAlert': trackStock ? lowStockAlertQuantity.round() : 0,
        'lowStockAlertQuantity': trackStock ? lowStockAlertQuantity : 0,
        'presentationType': presentationType,
        'presentationShape': presentationShape,
        'presentationColor': presentationColor,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(stockRef, {
        'businessId': businessId,
        'storeId': storeId,
        'productId': productRef.id,
        'stock': trackStock ? stockQuantity.round() : 0,
        'stockQuantity': trackStock ? stockQuantity : 0,
        'lowStockAlert': trackStock ? lowStockAlertQuantity.round() : 0,
        'lowStockAlertQuantity': trackStock ? lowStockAlertQuantity : 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateProduct({
    required String businessId,
    required String storeId,
    required Product product,
    required String name,
    required String? categoryId,
    required String? categoryName,
    required String sellBy,
    required double price,
    required double cost,
    required String ref,
    required bool trackStock,
    required double stockQuantity,
    required double lowStockAlertQuantity,
    required String presentationType,
    required String presentationShape,
    required int presentationColor,
    XFile? imageFile,
  }) async {
    await _connectivityService.requireConnection('Editar producto');

    final trimmedName = name.trim();
    final normalizedRef = ref.trim().toUpperCase();
    if (trimmedName.isEmpty) {
      throw StateError('El nombre es obligatorio');
    }
    if (normalizedRef.isEmpty) {
      throw StateError('El REF es obligatorio');
    }
    if (price < 0 || cost < 0) {
      throw StateError('Precio y coste no pueden ser negativos');
    }
    if (trackStock && stockQuantity < 0) {
      throw StateError('El inventario no puede ser negativo');
    }
    if (trackStock && sellBy == 'unit' && stockQuantity % 1 != 0) {
      throw StateError('Los productos por unidad deben usar cantidades enteras');
    }

    final businessRef = _db.collection('businesses').doc(businessId);
    final productRef = businessRef.collection('products').doc(product.id);
    final stockRef = productRef.collection('stockByStore').doc(storeId);
    final oldRefLockRef = businessRef.collection('productRefs').doc(product.ref);
    final newRefLockRef = businessRef.collection('productRefs').doc(normalizedRef);
    final counterRef = businessRef.collection('counters').doc('products');
    final localImagePath = imageFile == null
        ? product.localImagePath
        : await _saveProductImageLocally(
            businessId: businessId,
            productId: product.id,
            imageFile: imageFile,
          );

    await _db.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw StateError('El producto ya no existe');
      }

      if (normalizedRef != product.ref) {
        final existingRef = await transaction.get(newRefLockRef);
        if (existingRef.exists) {
          throw StateError('Ya existe un producto con ese REF');
        }

        transaction.set(newRefLockRef, {
          'productId': product.id,
          'ref': normalizedRef,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(oldRefLockRef);
      }

      final counterSnapshot = await transaction.get(counterRef);
      final currentNext = (counterSnapshot.data()?['nextRefNumber'] as num? ?? 1).toInt();
      final numericRef = int.tryParse(normalizedRef);
      if (numericRef != null && numericRef >= currentNext) {
        transaction.set(counterRef, {
          'nextRefNumber': numericRef + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.update(productRef, {
        'name': trimmedName,
        'sku': normalizedRef,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'sellBy': sellBy,
        'imageUrl': null,
        'localImagePath': presentationType == 'image' ? localImagePath : null,
        'price': price,
        'cost': cost,
        'ref': normalizedRef,
        'trackStock': trackStock,
        'stock': trackStock ? stockQuantity.round() : 0,
        'stockQuantity': trackStock ? stockQuantity : 0,
        'lowStockAlert': trackStock ? lowStockAlertQuantity.round() : 0,
        'lowStockAlertQuantity': trackStock ? lowStockAlertQuantity : 0,
        'presentationType': presentationType,
        'presentationShape': presentationShape,
        'presentationColor': presentationColor,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(stockRef, {
        'businessId': businessId,
        'storeId': storeId,
        'productId': product.id,
        'stock': trackStock ? stockQuantity.round() : 0,
        'stockQuantity': trackStock ? stockQuantity : 0,
        'lowStockAlert': trackStock ? lowStockAlertQuantity.round() : 0,
        'lowStockAlertQuantity': trackStock ? lowStockAlertQuantity : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> deactivateProduct({
    required String businessId,
    required Product product,
  }) async {
    await _connectivityService.requireConnection('Eliminar producto');

    final businessRef = _db.collection('businesses').doc(businessId);
    final productRef = businessRef.collection('products').doc(product.id);
    final refLockRef = businessRef.collection('productRefs').doc(product.ref);

    await _db.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw StateError('El producto ya no existe');
      }

      transaction.update(productRef, {
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(refLockRef);
    });
  }

  Future<String> _saveProductImageLocally({
    required String businessId,
    required String productId,
    required XFile imageFile,
  }) async {
    final optimizedBytes = await _optimizeImage(imageFile);
    final appDir = await getApplicationDocumentsDirectory();
    final productsDir = Directory('${appDir.path}/businesses/$businessId/products');

    if (!await productsDir.exists()) {
      await productsDir.create(recursive: true);
    }

    final file = File('${productsDir.path}/$productId.jpg');
    await file.writeAsBytes(optimizedBytes, flush: true);
    return file.path;
  }

  Future<Uint8List> _optimizeImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Formato de imagen no compatible');
    }

    final oriented = img.bakeOrientation(decoded);
    final largestSide = oriented.width > oriented.height ? oriented.width : oriented.height;
    final resized = largestSide > 1200
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 1200 : null,
            height: oriented.height > oriented.width ? 1200 : null,
            interpolation: img.Interpolation.average,
          )
        : oriented;

    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }
}
