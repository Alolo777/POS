import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter_firebase/shared/models/butcher_section.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/butcher/data/butcher_receipt_service.dart';
import 'package:pos_flutter_firebase/features/butcher/data/butcher_stock_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';
const employeeId = 'test_employee';

void main() {
  group('ButcherReceiptService.registerEntry', () {
    test('creates receipt and yields for chicken entry', () async {
      final db = FakeFirebaseFirestore();
      final stockService = ButcherStockService(firestore: db);
      final service = ButcherReceiptService(
        connectivityService: ConnectivityService(),
        stockService: stockService,
        firestore: db,
      );

      final result = await service.registerEntry(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        chickenCount: 10,
        avgWeight: 2.5,
        sections: [
          ButcherSection(name: 'Pechuga', percentage: 40, sortOrder: 1),
          ButcherSection(name: 'Pierna', percentage: 30, sortOrder: 2),
        ],
      );

      expect(result.receiptId, isNotEmpty);
      expect(result.yields.length, 2);
      expect(result.yields[0].name, 'Pechuga');
      expect(result.yields[0].weight, 10.0);
      expect(result.yields[0].percentage, 40.0);
      expect(result.yields[1].name, 'Pierna');
      expect(result.yields[1].weight, 7.5);

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('butcherReceipts').doc(result.receiptId).get();
      expect(doc.data()?['type'], 'chicken');
      expect(doc.data()?['chickenCount'], 10);
      expect(doc.data()?['totalWeight'], 25.0);
      expect(doc.data()?['status'], 'active');
    });

    test('creates receipt for parts entry', () async {
      final db = FakeFirebaseFirestore();
      final stockService = ButcherStockService(firestore: db);
      final service = ButcherReceiptService(
        connectivityService: ConnectivityService(),
        stockService: stockService,
        firestore: db,
      );

      final result = await service.registerPartsEntry(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        parts: [
          (name: 'Pechuga', weight: 8.0),
          (name: 'Pierna', weight: 5.0),
        ],
      );

      expect(result.receiptId, isNotEmpty);
      expect(result.yields.length, 2);
      expect(result.yields[0].percentage, closeTo(61.54, 0.1));
      expect(result.yields[1].percentage, closeTo(38.46, 0.1));

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('butcherReceipts').doc(result.receiptId).get();
      expect(doc.data()?['type'], 'parts');
      expect(doc.data()?['totalWeight'], 13.0);
    });

    test('throws when offline', () async {
      final db = FakeFirebaseFirestore();
      final stockService = ButcherStockService(firestore: db);
      final service = ButcherReceiptService(
        connectivityService: _OfflineConnectivityService(),
        stockService: stockService,
        firestore: db,
      );

      expect(
        () => service.registerEntry(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          chickenCount: 1,
          avgWeight: 2.0,
          sections: [ButcherSection(name: 'X', percentage: 100, sortOrder: 1)],
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ButcherReceiptService.cancelEntry', () {
    test('cancels receipt and updates stock', () async {
      final db = FakeFirebaseFirestore();
      final stockService = ButcherStockService(firestore: db);
      final service = ButcherReceiptService(
        connectivityService: ConnectivityService(),
        stockService: stockService,
        firestore: db,
      );

      final receiptRef = db
          .collection('businesses').doc(businessId)
          .collection('butcherReceipts').doc('r1');
      await receiptRef.set({
        'type': 'chicken',
        'storeId': storeId,
        'yields': [
          {'name': 'Pechuga', 'weight': 10.0, 'percentage': 100.0},
        ],
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      await service.cancelEntry(
        businessId: businessId,
        receiptId: 'r1',
        reason: 'Error en registro',
        cancelledBy: employeeId,
      );

      final doc = await receiptRef.get();
      expect(doc.data()?['status'], 'cancelled');
      expect(doc.data()?['cancelReason'], 'Error en registro');
      expect(doc.data()?['cancelledBy'], employeeId);
    });

    test('throws when receipt not found', () async {
      final db = FakeFirebaseFirestore();
      final stockService = ButcherStockService(firestore: db);
      final service = ButcherReceiptService(
        connectivityService: ConnectivityService(),
        stockService: stockService,
        firestore: db,
      );

      expect(
        () => service.cancelEntry(
          businessId: businessId,
          receiptId: 'nonexistent',
          reason: 'Test',
          cancelledBy: employeeId,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _OfflineConnectivityService extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}
