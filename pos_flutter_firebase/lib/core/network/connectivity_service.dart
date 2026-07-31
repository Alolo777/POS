import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _online = _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }

  final Connectivity _connectivity;
  late final Stream<bool> _online;
  bool _lastKnownStatus = true;

  Stream<bool> get onOnlineStatusChanged => _online;

  bool get isOnline => _lastKnownStatus;

  Future<bool> hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _lastKnownStatus = results.any((result) => result != ConnectivityResult.none);
      return _lastKnownStatus;
    } catch (_) {
      return true;
    }
  }

  Future<void> requireConnection(String actionName) async {
    final isConnected = await hasConnection();
    if (!isConnected) {
      throw StateError(
        '$actionName requiere conexion a internet. '
        'La operacion se guardara y sincronizara cuando haya conexion.',
      );
    }
  }
}