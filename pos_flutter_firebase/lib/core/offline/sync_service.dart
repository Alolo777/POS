// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_queue.dart';

typedef SyncHandler = Future<void> Function(Map<String, dynamic> data);

class SyncService {
  SyncService({
    required Map<String, SyncHandler> handlers,
    Connectivity? connectivity,
    bool autoStart = true,
    Duration syncInterval = const Duration(seconds: 10),
  })  : _handlers = handlers,
        _syncInterval = syncInterval {
    _connectivity = connectivity ?? Connectivity();
    if (autoStart) _setupListener();
  }

  late final Connectivity _connectivity;
  final Map<String, SyncHandler> _handlers;
  final Duration _syncInterval;
  StreamSubscription? _subscription;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  void _setupListener() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_isSyncing) {
        processQueue();
      }
    });
    _periodicTimer = Timer.periodic(_syncInterval, (_) {
      if (SyncQueue.pendingCount > 0 && !_isSyncing) {
        processQueue();
      }
    });
    _initialSync();
  }

  Future<void> _initialSync() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) {
        await processQueue();
      }
    } catch (_) {
      // Sin conexion en el arranque; se reintenta con el timer o al reconectar.
    }
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = SyncQueue.getPending();
      for (final operation in pending) {
        final handler = _handlers[operation.type];
        if (handler == null) {
          await SyncQueue.markFailed(operation.id, error: 'No hay handler registrado para ${operation.type}');
          continue;
        }

        await SyncQueue.markSyncing(operation.id);
        try {
          await handler(operation.data);
          await SyncQueue.markCompleted(operation.id);
        } catch (e) {
          await SyncQueue.markFailed(operation.id, error: e);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> hasPending() async {
    return SyncQueue.pendingCount > 0;
  }

  Future<int> pendingCount() async {
    return SyncQueue.pendingCount;
  }

  Future<int> failedCount() async {
    return SyncQueue.failedCount;
  }

  void dispose() {
    _subscription?.cancel();
    _periodicTimer?.cancel();
  }
}