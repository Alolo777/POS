import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<void> requireConnection(String actionName) async {
    final isConnected = await hasConnection();
    if (!isConnected) {
      throw StateError(
        '$actionName requiere conexion a internet por ahora. '
        'En la fase offline-first se guardara localmente y se sincronizara despues.',
      );
    }
  }
}
