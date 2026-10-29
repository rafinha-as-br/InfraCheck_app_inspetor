import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../../core/config.dart';

/// Perfil do inspetor e saída da conta. Sair é bloqueado enquanto houver inspeções que ainda não chegaram
/// ao servidor, para que nenhum dado coletado em campo se perca.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text('Perfil', style: t.titleLarge?.copyWith(color: IcColors.onPrimary)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([services.session, services.repository]),
        builder: (context, _) {
          final user = services.session.user;
          final unsent = services.repository.unsent.length;
          if (user == null) return const SizedBox.shrink();
          return ListView(padding: const EdgeInsets.all(IcSpacing.s4), children: [
            Container(
              padding: const EdgeInsets.all(IcSpacing.s4),
              decoration: BoxDecoration(
                  color: IcColors.surface0,
                  borderRadius: BorderRadius.circular(IcRadius.lg),
                  border: Border.all(color: IcColors.borderSubtle)),
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: IcColors.primary100, child: Text(user.initials, style: t.titleMedium?.copyWith(color: IcColors.primary900))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: t.titleMedium),
                    Text(user.email, style: t.bodyMedium?.copyWith(color: IcColors.ink700)),
                    const SizedBox(height: 4),
                    Text('${user.role.label}${user.registration != null ? ' · ${user.registration}' : ''}', style: IcText.mono(size: 12, color: IcColors.ink600)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: IcSpacing.s4),
            if (unsent > 0)
              IcNotice(
                  kind: NoticeKind.warn,
                  title: 'Há $unsent ${unsent == 1 ? 'inspeção' : 'inspeções'} sem enviar.',
                  message: 'Conecte-se e sincronize antes de sair da conta.'),
            const SizedBox(height: IcSpacing.s4),
            OutlinedButton.icon(
              onPressed: unsent > 0 ? null : services.session.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch)),
            ),
            const SizedBox(height: IcSpacing.s6),
            Text('Servidor: ${AppConfig.apiBaseUrl}', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
            Text('InfraCheck Inspeções e Manutenção Industrial Ltda · versão de demonstração', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
          ]);
        },
      ),
    );
  }
}
