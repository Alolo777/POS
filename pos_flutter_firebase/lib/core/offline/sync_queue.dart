import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class PendingOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retries;
  final String status;
  final String? lastError;
  final DateTime? failedAt;

  const PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retries = 0,
    this.status = 'pending',
    this.lastError,
    this.failedAt,
  });

  PendingOperation copyWith({
    int? retries,
    String? status,
    String? lastError,
    DateTime? failedAt,
  }) {
    return PendingOperation(
      id: id,
      type: type,
      data: data,
      timestamp: timestamp,
      retries: retries ?? this.retries,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      failedAt: failedAt ?? this.failedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retries': retries,
    'status': status,
    'lastError': lastError,
    'failedAt': failedAt?.toIso8601String(),
  };

  factory PendingOperation.fromMap(Map<String, dynamic> map) => PendingOperation(
    id: map['id'] as String,
    type: map['type'] as String,
    data: Map<String, dynamic>.from(map['data'] as Map),
    timestamp: DateTime.parse(map['timestamp'] as String),
    retries: map['retries'] as int? ?? 0,
    status: map['status'] as String? ?? 'pending',
    lastError: map['lastError'] as String?,
    failedAt: map['failedAt'] != null ? DateTime.parse(map['failedAt'] as String) : null,
  );
}

class SyncQueue {
  static const _boxName = 'syncQueue';

  static Future<void> initialize() async {
    await Hive.openBox<Map>(_boxName);
    await recoverStuckOps();
  }

  /// Recupera operaciones que quedaron en estado `syncing` (por ejemplo si la
  /// app murió a mitad de sincronización) y las devuelve a `pending` para que
  /// se reintenten. La idempotencia por `clientOpId` evita duplicados.
  static Future<void> recoverStuckOps() async {
    final stuck = _box.values.where((map) => map['status'] == 'syncing').toList();
    for (final item in stuck) {
      item['status'] = 'pending';
      await _box.put(item['id'] as String, item);
    }
  }

  static Box<Map> get _box => Hive.box<Map>(_boxName);

  static Future<void> enqueue({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final operation = PendingOperation(
      id: const Uuid().v4(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );
    // Clave de deduplicación: el handler puede usar esta misma operación como
    // id de documento para que los reintentos no dupliquen ventas/devoluciones.
    data['clientOpId'] = operation.id;
    await _box.put(operation.id, operation.toMap());
  }

  static List<PendingOperation> getPending() {
    return _box.values
        .map((map) => PendingOperation.fromMap(Map<String, dynamic>.from(map)))
        .where((op) => op.status == 'pending')
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static List<PendingOperation> getAll() {
    return _box.values
        .map((map) => PendingOperation.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static List<PendingOperation> getFailed() {
    return _box.values
        .map((map) => PendingOperation.fromMap(Map<String, dynamic>.from(map)))
        .where((op) => op.status == 'failed')
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<void> markSyncing(String id) async {
    final data = _box.get(id);
    if (data != null) {
      data['status'] = 'syncing';
      await _box.put(id, data);
    }
  }

  static Future<void> markCompleted(String id) async {
    await _box.delete(id);
  }

  static Future<void> markFailed(String id, {Object? error, int maxRetries = 5}) async {
    final data = _box.get(id);
    if (data != null) {
      final retries = (data['retries'] as int? ?? 0) + 1;
      data['retries'] = retries;
      data['lastError'] = error?.toString() ?? 'Error desconocido';
      if (retries >= maxRetries) {
        data['status'] = 'failed';
        data['failedAt'] = DateTime.now().toIso8601String();
      } else {
        data['status'] = 'pending';
      }
      await _box.put(id, data);
    }
  }

  static Future<void> retryFailed(String id) async {
    final data = _box.get(id);
    if (data != null && data['status'] == 'failed') {
      data['status'] = 'pending';
      data['lastError'] = null;
      data['failedAt'] = null;
      await _box.put(id, data);
    }
  }

  static int get pendingCount => getPending().length;
  static int get failedCount => getFailed().length;

  static Future<void> clearFailed() async {
    final failed = _box.values.where((map) => map['status'] == 'failed').toList();
    for (final item in failed) {
      await _box.delete(item['id'] as String);
    }
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }
}