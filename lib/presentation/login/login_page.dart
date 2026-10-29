import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';

/// M01 — Login do inspetor. O primeiro acesso exige internet; depois o app funciona offline.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AppScope.of(context).session.login(_email.text.trim(), _password.text);
    if (mounted && error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: IcColors.surface0,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 340,
              child: Stack(children: [
                const Positioned.fill(child: FramePattern()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  child: SafeArea(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const IcLogo(LogoVariant.horizontalReverse, height: 40),
                      const Spacer(),
                      Text('Inspeção registrada. Relatório no prazo.',
                          style: t.displayMedium?.copyWith(color: IcColors.onPrimary, fontSize: 34, height: 1.1)),
                      const SizedBox(height: 12),
                      Text('Entre para ver as inspeções atribuídas a você.',
                          style: t.bodyLarge?.copyWith(color: IcColors.onPrimaryMuted)),
                    ]),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null) ...[
                    IcNotice(kind: NoticeKind.danger, title: 'Não foi possível entrar.', message: _error!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    validator: _required,
                    style: t.bodyLarge,
                    decoration: const InputDecoration(labelText: 'E-mail corporativo', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    validator: _required,
                    onFieldSubmitted: (_) => _submit(),
                    style: t.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: 'Mostrar ou ocultar senha',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch)),
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Para redefinir a senha, fale com o gestor de contrato ou com o administrador.'))),
                    child: const Text('Esqueci minha senha'),
                  ),
                  const SizedBox(height: 8),
                  const IcNotice(
                    kind: NoticeKind.info,
                    icon: Icons.wifi_off,
                    message: 'Depois do primeiro acesso, o app funciona sem internet e sincroniza quando o sinal voltar.',
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
              child: Text('InfraCheck Inspeções e Manutenção Industrial Ltda · versão de demonstração',
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: IcColors.ink600)),
            ),
          ]),
        ),
      ),
    );
  }
}
