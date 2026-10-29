import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'core/app_services.dart';
import 'presentation/home/home_shell.dart';
import 'presentation/login/login_page.dart';

/// Aplicação raiz do app do inspetor: tema InfraCheck e porta de entrada conforme a sessão.
///
/// Ao voltar para o app (primeiro plano) baixa as inspeções novas e tenta enviar o que está pendente.
class InspectorApp extends StatefulWidget {
  const InspectorApp({super.key, required this.services});

  final AppServices services;

  @override
  State<InspectorApp> createState() => _InspectorAppState();
}

class _InspectorAppState extends State<InspectorApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late bool _wasLoggedIn = widget.services.session.isLoggedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.session.addListener(_onSessionChanged);
    if (widget.services.session.isLoggedIn) _syncNow();
  }

  @override
  void dispose() {
    widget.services.session.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.services.session.isLoggedIn) _syncNow();
  }

  Future<void> _syncNow() async {
    await widget.services.sync.syncAll();
    await widget.services.repository.refresh();
  }

  /// Entrou ou saiu: volta à raiz (a pilha de telas do usuário anterior é descartada) e sincroniza.
  void _onSessionChanged() {
    final logged = widget.services.session.isLoggedIn;
    if (logged != _wasLoggedIn) {
      _navigator.currentState?.popUntil((r) => r.isFirst);
      if (logged) _syncNow();
    }
    _wasLoggedIn = logged;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp(
        title: 'InfraCheck',
        debugShowCheckedModeBanner: false,
        theme: InfraCheckTheme.light(),
        navigatorKey: _navigator,
        home: ListenableBuilder(
          listenable: widget.services.session,
          builder: (context, _) => widget.services.session.isLoggedIn ? const HomeShell() : const LoginPage(),
        ),
      ),
    );
  }
}
