import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'local_store.dart';

/// Sessão do inspetor. O token e o usuário ficam no aparelho: depois do primeiro login online o app abre
/// e funciona sem internet. Só inspetores usam o aplicativo (gestores usam o painel web).
class SessionController extends ChangeNotifier {
  SessionController({required this.api, required LocalStore store}) : _store = store {
    api.onUnauthorized = expire;
    final saved = _store.token;
    final user = _store.user;
    if (saved != null && user != null) {
      api.token = saved;
      _user = UserInfo.fromJson(user);
    }
  }

  final InfraCheckApi api;
  final LocalStore _store;
  UserInfo? _user;

  UserInfo? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Devolve a mensagem de erro para a tela, ou `null` quando o login deu certo.
  Future<String?> login(String email, String password) async {
    try {
      final result = await api.login(email, password);
      if (result.user.role != Role.inspector) {
        api.token = null;
        return 'Gestores e administradores acessam o painel web. Este aplicativo é para inspetores.';
      }
      api.token = result.token;
      _user = result.user;
      await _store.saveSession(result.token, result.user.toJson());
      notifyListeners();
      return null;
    } on ApiError catch (e) {
      if (e.isNetwork) return 'Sem conexão. O primeiro acesso precisa de internet.';
      return e.status == 401 ? 'E-mail ou senha incorretos.' : e.fullMessage;
    }
  }

  /// Token recusado pelo servidor: volta ao login, mas mantém as inspeções gravadas no aparelho.
  void expire() {
    if (_user == null) return;
    logout();
  }

  Future<void> logout() async {
    api.token = null;
    _user = null;
    ApiImage.clearCache();
    await _store.clearSession();
    notifyListeners();
  }
}
