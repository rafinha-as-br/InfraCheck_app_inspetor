import 'package:flutter/widgets.dart';

import '../data/inspection_repository.dart';
import '../data/session_controller.dart';
import '../data/sync_service.dart';

/// Serviços compartilhados do app (sessão, dados, sincronização), criados uma vez em `main`.
class AppServices {
  const AppServices({required this.session, required this.repository, required this.sync});

  final SessionController session;
  final InspectionRepository repository;
  final SyncService sync;
}

/// Disponibiliza os [AppServices] para a árvore de widgets.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope ausente na árvore');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope old) => services != old.services;
}
