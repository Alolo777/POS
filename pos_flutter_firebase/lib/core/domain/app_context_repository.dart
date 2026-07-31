import '../../shared/models/app_session.dart';

abstract class AppContextRepository {
  Future<AppSession?> loadSession();
}
