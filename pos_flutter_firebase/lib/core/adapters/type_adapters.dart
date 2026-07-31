import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/product.dart';
import '../../shared/models/product_stock.dart';
import '../../shared/models/category.dart';
import '../../shared/models/modifier.dart';
import '../../shared/models/discount.dart';
import '../../shared/models/store.dart';
import '../../shared/models/business.dart';
import '../../shared/models/employee.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/shift.dart';
import '../../shared/models/open_ticket.dart';
import '../../shared/models/inventory_movement.dart';
import '../../shared/models/butcher_section.dart';

// ── Category ──
class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 2;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      color: fields[2] as int,
      active: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.color);
    writer.writeByte(3);
    writer.write(obj.active);
  }
}

// ── Modifier ──
class ModifierAdapter extends TypeAdapter<Modifier> {
  @override
  final int typeId = 3;

  @override
  Modifier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Modifier(
      id: fields[0] as String,
      name: fields[1] as String,
      price: fields[2] as double,
      active: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Modifier obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.price);
    writer.writeByte(3);
    writer.write(obj.active);
  }
}

// ── Discount ──
class DiscountAdapter extends TypeAdapter<Discount> {
  @override
  final int typeId = 4;

  @override
  Discount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Discount(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      value: fields[3] as double,
      active: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Discount obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.type);
    writer.writeByte(3);
    writer.write(obj.value);
    writer.writeByte(4);
    writer.write(obj.active);
  }
}

// ── Store ──
class StoreAdapter extends TypeAdapter<Store> {
  @override
  final int typeId = 5;

  @override
  Store read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Store(
      id: fields[0] as String,
      name: fields[1] as String,
      address: fields[2] as String,
      phone: fields[3] as String,
      active: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Store obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.address);
    writer.writeByte(3);
    writer.write(obj.phone);
    writer.writeByte(4);
    writer.write(obj.active);
  }
}

// ── Business ──
class BusinessAdapter extends TypeAdapter<Business> {
  @override
  final int typeId = 6;

  @override
  Business read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Business(
      id: fields[0] as String,
      name: fields[1] as String,
      currency: fields[2] as String,
      timezone: fields[3] as String,
      active: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Business obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.currency);
    writer.writeByte(3);
    writer.write(obj.timezone);
    writer.writeByte(4);
    writer.write(obj.active);
  }
}

// ── Employee ──
class EmployeeAdapter extends TypeAdapter<Employee> {
  @override
  final int typeId = 7;

  @override
  Employee read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Employee(
      id: fields[0] as String,
      businessId: fields[1] as String,
      authUid: fields[2] as String,
      name: fields[3] as String,
      email: fields[4] as String,
      role: fields[5] as String,
      storeIds: (fields[6] as List).cast<String>(),
      permissions: (fields[7] as List).cast<String>(),
      pin: fields[8] as String,
      active: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Employee obj) {
    writer.writeByte(10);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.businessId);
    writer.writeByte(2);
    writer.write(obj.authUid);
    writer.writeByte(3);
    writer.write(obj.name);
    writer.writeByte(4);
    writer.write(obj.email);
    writer.writeByte(5);
    writer.write(obj.role);
    writer.writeByte(6);
    writer.write(obj.storeIds);
    writer.writeByte(7);
    writer.write(obj.permissions);
    writer.writeByte(8);
    writer.write(obj.pin);
    writer.writeByte(9);
    writer.write(obj.active);
  }
}

// ── Product ──
class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 0;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      categoryId: fields[2] as String?,
      categoryName: fields[3] as String?,
      sellBy: fields[4] as String,
      price: fields[5] as double,
      cost: fields[6] as double,
      ref: fields[7] as String,
      trackStock: fields[8] as bool,
      stockQuantity: fields[9] as double,
      lowStockAlertQuantity: fields[10] as double,
      presentationType: fields[11] as String,
      presentationShape: fields[12] as String,
      presentationColor: fields[13] as int,
      imageUrl: fields[14] as String?,
      localImagePath: fields[15] as String?,
      active: fields[16] as bool,
      stockLoaded: fields[17] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer.writeByte(18);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.categoryId);
    writer.writeByte(3);
    writer.write(obj.categoryName);
    writer.writeByte(4);
    writer.write(obj.sellBy);
    writer.writeByte(5);
    writer.write(obj.price);
    writer.writeByte(6);
    writer.write(obj.cost);
    writer.writeByte(7);
    writer.write(obj.ref);
    writer.writeByte(8);
    writer.write(obj.trackStock);
    writer.writeByte(9);
    writer.write(obj.stockQuantity);
    writer.writeByte(10);
    writer.write(obj.lowStockAlertQuantity);
    writer.writeByte(11);
    writer.write(obj.presentationType);
    writer.writeByte(12);
    writer.write(obj.presentationShape);
    writer.writeByte(13);
    writer.write(obj.presentationColor);
    writer.writeByte(14);
    writer.write(obj.imageUrl);
    writer.writeByte(15);
    writer.write(obj.localImagePath);
    writer.writeByte(16);
    writer.write(obj.active);
    writer.writeByte(17);
    writer.write(obj.stockLoaded);
  }
}

// ── ProductStock ──
class ProductStockAdapter extends TypeAdapter<ProductStock> {
  @override
  final int typeId = 1;

  @override
  ProductStock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ProductStock(
      productId: fields[0] as String,
      storeId: fields[1] as String,
      stockQuantity: fields[2] as double,
      lowStockAlertQuantity: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ProductStock obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.productId);
    writer.writeByte(1);
    writer.write(obj.storeId);
    writer.writeByte(2);
    writer.write(obj.stockQuantity);
    writer.writeByte(3);
    writer.write(obj.lowStockAlertQuantity);
  }
}

// ── InventoryMovement ──
class InventoryMovementAdapter extends TypeAdapter<InventoryMovement> {
  @override
  final int typeId = 11;

  @override
  InventoryMovement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return InventoryMovement(
      id: fields[0] as String,
      businessId: fields[1] as String,
      storeId: fields[2] as String,
      productId: fields[3] as String,
      productName: fields[4] as String,
      type: fields[5] as String,
      previousQuantity: fields[6] as double,
      newQuantity: fields[7] as double,
      reason: fields[8] as String,
      employeeId: fields[9] as String,
      createdAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryMovement obj) {
    writer.writeByte(11);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.businessId);
    writer.writeByte(2);
    writer.write(obj.storeId);
    writer.writeByte(3);
    writer.write(obj.productId);
    writer.writeByte(4);
    writer.write(obj.productName);
    writer.writeByte(5);
    writer.write(obj.type);
    writer.writeByte(6);
    writer.write(obj.previousQuantity);
    writer.writeByte(7);
    writer.write(obj.newQuantity);
    writer.writeByte(8);
    writer.write(obj.reason);
    writer.writeByte(9);
    writer.write(obj.employeeId);
    writer.writeByte(10);
    writer.write(obj.createdAt);
  }
}

// ── ButcherSection ──
class ButcherSectionAdapter extends TypeAdapter<ButcherSection> {
  @override
  final int typeId = 12;

  @override
  ButcherSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ButcherSection(
      id: fields[0] as String?,
      name: fields[1] as String,
      productId: fields[2] as String?,
      productName: fields[3] as String?,
      percentage: fields[4] as double,
      sortOrder: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ButcherSection obj) {
    writer.writeByte(6);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.productId);
    writer.writeByte(3);
    writer.write(obj.productName);
    writer.writeByte(4);
    writer.write(obj.percentage);
    writer.writeByte(5);
    writer.write(obj.sortOrder);
  }
}

// ── OpenTicket ──
class OpenTicketAdapter extends TypeAdapter<OpenTicket> {
  @override
  final int typeId = 10;

  @override
  OpenTicket read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return OpenTicket(
      id: fields[0] as String,
      businessId: fields[1] as String,
      storeId: fields[2] as String,
      employeeId: fields[3] as String,
      name: fields[4] as String,
      items: (fields[5] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      total: fields[6] as double,
      status: fields[7] as String,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, OpenTicket obj) {
    writer.writeByte(10);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.businessId);
    writer.writeByte(2);
    writer.write(obj.storeId);
    writer.writeByte(3);
    writer.write(obj.employeeId);
    writer.writeByte(4);
    writer.write(obj.name);
    writer.writeByte(5);
    writer.write(obj.items);
    writer.writeByte(6);
    writer.write(obj.total);
    writer.writeByte(7);
    writer.write(obj.status);
    writer.writeByte(8);
    writer.write(obj.createdAt);
    writer.writeByte(9);
    writer.write(obj.updatedAt);
  }
}

// ── Sale ──
class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 8;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Sale(
      id: fields[0] as String,
      businessId: fields[1] as String,
      folio: fields[2] as String,
      storeId: fields[3] as String,
      employeeId: fields[4] as String,
      shiftId: fields[5] as String?,
      items: (fields[6] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      subtotal: fields[7] as double,
      discountTotal: fields[8] as double,
      taxTotal: fields[9] as double,
      total: fields[10] as double,
      paymentMethod: fields[11] as String,
      cashReceived: fields[12] as double?,
      changeDue: fields[13] as double?,
      status: fields[14] as String,
      originalSaleId: fields[15] as String?,
      returnedItems: (fields[16] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      createdAt: fields[17] as DateTime?,
      cancelledAt: fields[18] as DateTime?,
      cancelReason: fields[19] as String?,
      inventoryReturned: fields[20] as bool,
      clientCreatedAt: fields[21] as DateTime?,
      type: fields[22] as String,
      refund: fields[23] as bool,
      refundIds: (fields[24] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer.writeByte(25);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.businessId);
    writer.writeByte(2);
    writer.write(obj.folio);
    writer.writeByte(3);
    writer.write(obj.storeId);
    writer.writeByte(4);
    writer.write(obj.employeeId);
    writer.writeByte(5);
    writer.write(obj.shiftId);
    writer.writeByte(6);
    writer.write(obj.items);
    writer.writeByte(7);
    writer.write(obj.subtotal);
    writer.writeByte(8);
    writer.write(obj.discountTotal);
    writer.writeByte(9);
    writer.write(obj.taxTotal);
    writer.writeByte(10);
    writer.write(obj.total);
    writer.writeByte(11);
    writer.write(obj.paymentMethod);
    writer.writeByte(12);
    writer.write(obj.cashReceived);
    writer.writeByte(13);
    writer.write(obj.changeDue);
    writer.writeByte(14);
    writer.write(obj.status);
    writer.writeByte(15);
    writer.write(obj.originalSaleId);
    writer.writeByte(16);
    writer.write(obj.returnedItems);
    writer.writeByte(17);
    writer.write(obj.createdAt);
    writer.writeByte(18);
    writer.write(obj.cancelledAt);
    writer.writeByte(19);
    writer.write(obj.cancelReason);
    writer.writeByte(20);
    writer.write(obj.inventoryReturned);
    writer.writeByte(21);
    writer.write(obj.clientCreatedAt);
    writer.writeByte(22);
    writer.write(obj.type);
    writer.writeByte(23);
    writer.write(obj.refund);
    writer.writeByte(24);
    writer.write(obj.refundIds);
  }
}

// ── Shift ──
class ShiftAdapter extends TypeAdapter<Shift> {
  @override
  final int typeId = 9;

  @override
  Shift read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Shift(
      id: fields[0] as String,
      businessId: fields[1] as String,
      storeId: fields[2] as String,
      employeeId: fields[3] as String,
      status: fields[4] as String,
      openingCash: fields[5] as double,
      closingCash: fields[6] as double?,
      cashSales: fields[7] as double,
      cardSales: fields[8] as double,
      totalSales: fields[9] as double,
      cashRefunds: fields[10] as double,
      depositsTotal: fields[11] as double,
      payoutsTotal: fields[12] as double,
      cashMovements: (fields[13] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      expectedCash: fields[14] as double,
      cashDifference: fields[15] as double,
      openedAt: fields[16] as DateTime?,
      closedAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Shift obj) {
    writer.writeByte(18);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.businessId);
    writer.writeByte(2);
    writer.write(obj.storeId);
    writer.writeByte(3);
    writer.write(obj.employeeId);
    writer.writeByte(4);
    writer.write(obj.status);
    writer.writeByte(5);
    writer.write(obj.openingCash);
    writer.writeByte(6);
    writer.write(obj.closingCash);
    writer.writeByte(7);
    writer.write(obj.cashSales);
    writer.writeByte(8);
    writer.write(obj.cardSales);
    writer.writeByte(9);
    writer.write(obj.totalSales);
    writer.writeByte(10);
    writer.write(obj.cashRefunds);
    writer.writeByte(11);
    writer.write(obj.depositsTotal);
    writer.writeByte(12);
    writer.write(obj.payoutsTotal);
    writer.writeByte(13);
    writer.write(obj.cashMovements);
    writer.writeByte(14);
    writer.write(obj.expectedCash);
    writer.writeByte(15);
    writer.write(obj.cashDifference);
    writer.writeByte(16);
    writer.write(obj.openedAt);
    writer.writeByte(17);
    writer.write(obj.closedAt);
  }
}

bool _typeAdaptersRegistered = false;

/// Registers all TypeAdapters with Hive (idempotent).
void registerTypeAdapters() {
  if (_typeAdaptersRegistered) return;
  _typeAdaptersRegistered = true;
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(ProductStockAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ModifierAdapter());
  Hive.registerAdapter(DiscountAdapter());
  Hive.registerAdapter(StoreAdapter());
  Hive.registerAdapter(BusinessAdapter());
  Hive.registerAdapter(EmployeeAdapter());
  Hive.registerAdapter(SaleAdapter());
  Hive.registerAdapter(ShiftAdapter());
  Hive.registerAdapter(OpenTicketAdapter());
  Hive.registerAdapter(InventoryMovementAdapter());
  Hive.registerAdapter(ButcherSectionAdapter());
}
