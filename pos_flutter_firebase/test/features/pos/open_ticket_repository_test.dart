import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_flutter_firebase/shared/models/cart_item.dart';
import 'package:pos_flutter_firebase/shared/models/product.dart';
import 'package:pos_flutter_firebase/core/adapters/type_adapters.dart';
import 'package:pos_flutter_firebase/core/offline/sync_queue.dart';
import 'package:pos_flutter_firebase/core/network/connectivity_service.dart';
import 'package:pos_flutter_firebase/features/pos/data/open_ticket_service.dart';

const businessId = 'test_business';
const storeId = 'test_store';
const employeeId = 'test_employee';

class OfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> hasConnection() async => false;
}

Product _product(String id) {
  return Product(
    id: id,
    name: 'Producto',
    categoryId: null,
    categoryName: null,
    sellBy: 'unit',
    price: 10.0,
    cost: 5.0,
    ref: 'REF-$id',
    trackStock: true,
    stockQuantity: 100,
    lowStockAlertQuantity: 10,
    presentationType: 'shape',
    presentationShape: 'square',
    presentationColor: 0xFF9E9E9E,
    imageUrl: null,
    localImagePath: null,
    active: true,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pos-ticket-test-');
    Hive.init(tempDir.path);
    registerTypeAdapters();
    await Hive.openBox<List>('openTickets_v2');
    await Hive.openBox<Map>('syncQueue');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('OpenTicketService.saveOpenTicket (online)', () {
    test('creates new ticket and returns id', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: ConnectivityService());

      final items = [CartItem(product: _product('p1'), quantity: 2)];
      final id = await service.saveOpenTicket(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        name: 'Mesa 5',
        items: items,
        total: 20.0,
      );

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('openTickets').doc(id).get();
      expect(doc.data()?['name'], 'Mesa 5');
      expect(doc.data()?['total'], 20.0);
      expect(doc.data()?['status'], 'open');
      expect(doc.data()?['items'], isNotEmpty);
    });

    test('updates existing ticket when ticketId is provided', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('openTickets').doc('t1')
          .set({'name': 'Old', 'status': 'open', 'items': [], 'total': 0});

      final items = [CartItem(product: _product('p1'), quantity: 1)];
      final id = await service.saveOpenTicket(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        name: 'Updated',
        items: items,
        total: 10.0,
        ticketId: 't1',
      );

      expect(id, 't1');
      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('openTickets').doc('t1').get();
      expect(doc.data()?['name'], 'Updated');
      expect(doc.data()?['total'], 10.0);
    });
  });

  group('OpenTicketService.saveOpenTicket (offline)', () {
    test('enqueues operation and returns temp id', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: OfflineConnectivity());

      final items = [CartItem(product: _product('p1'), quantity: 1)];
      final id = await service.saveOpenTicket(
        businessId: businessId,
        storeId: storeId,
        employeeId: employeeId,
        name: 'Offline',
        items: items,
        total: 10.0,
      );

      expect(id, startsWith('temp_'));
      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'saveOpenTicket');
    });
  });

  group('OpenTicketService.saveOpenTicket (validation)', () {
    test('throws on empty items', () async {
      final service = OpenTicketService(
        firestore: FakeFirebaseFirestore(),
        connectivityService: ConnectivityService(),
      );

      expect(
        () => service.saveOpenTicket(
          businessId: businessId,
          storeId: storeId,
          employeeId: employeeId,
          name: 'Empty',
          items: [],
          total: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('OpenTicketService.closeOpenTicket', () {
    test('online: sets status to closed', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('openTickets').doc('t_close')
          .set({'status': 'open'});

      await service.closeOpenTicket(businessId: businessId, ticketId: 't_close');

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('openTickets').doc('t_close').get();
      expect(doc.data()?['status'], 'closed');
    });

    test('offline: enqueues close operation', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: OfflineConnectivity());

      await service.closeOpenTicket(businessId: businessId, ticketId: 't_off');

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'closeOpenTicket');
    });
  });

  group('OpenTicketService.cancelOpenTicket', () {
    test('online: sets status to cancelled', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: ConnectivityService());

      await db.collection('businesses').doc(businessId)
          .collection('openTickets').doc('t_cancel')
          .set({'status': 'open'});

      await service.cancelOpenTicket(businessId: businessId, ticketId: 't_cancel');

      final doc = await db
          .collection('businesses').doc(businessId)
          .collection('openTickets').doc('t_cancel').get();
      expect(doc.data()?['status'], 'cancelled');
    });

    test('offline: enqueues cancel operation', () async {
      final db = FakeFirebaseFirestore();
      final service = OpenTicketService(firestore: db, connectivityService: OfflineConnectivity());

      await service.cancelOpenTicket(businessId: businessId, ticketId: 't_off');

      expect(SyncQueue.pendingCount, 1);
      expect(SyncQueue.getPending().single.type, 'cancelOpenTicket');
    });
  });
}
