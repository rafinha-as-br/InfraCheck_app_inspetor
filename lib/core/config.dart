import 'package:flutter/foundation.dart';

/// Configuração em tempo de build.
///
/// Endereço da API: `flutter run --dart-define=API_BASE_URL=https://api.exemplo.com`.
/// Sem a variável, usa a API local do protótipo: `10.0.2.2` no emulador Android (alias do computador
/// anfitrião) e `localhost` nas demais plataformas.
abstract final class AppConfig {
  /// SOMENTE DESENVOLVIMENTO: "lat,lng" que substitui o GPS (emuladores/navegador). Ignorado em release.
  /// Ex.: --dart-define=FAKE_GPS=-23.5613,-46.6559.
  static const fakeGps = String.fromEnvironment('FAKE_GPS');

  static const _fromEnv = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }
}
