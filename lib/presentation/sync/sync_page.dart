import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../../data/local_execution.dart';
import '../details/details_page.dart';

/// Sincronização: o que está no aparelho esperando para ir ao servidor, com o motivo de qualquer recusa.
/// Também permite forçar o envio e baixar as inspeções novas.
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sincronização', style: t.titleLarge?.copyWith(color: IcColors.onPrimary)),
          Text('Envio e atualização dos dados', style: t.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
        ]),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([services.repository, services.sync]),
        builder: (context, _) {
          final repo = services.repository;
          final unsent = repo.unsent;
          final busy = services.sync.syncing || repo.refreshing;
          return ListView(padding: const EdgeInsets.all(IcSpacing.s4), children: [
            IcNotice(
              kind: repo.offline ? NoticeKind.warn : NoticeKind.ok,
              icon: repo.offline ? Icons.wifi_off : Icons.cloud_done_outlined,
              title: repo.offline ? 'Sem conexão.' : 'Conectado.',
              message: repo.offline
                  ? 'Seus dados estão salvos no aparelho e serão enviados quando o sinal voltar.'
                  : unsent.isEmpty
                      ? 'Não há nada pendente de envio.'
                      : 'Há ${unsent.length} ${unsent.length == 1 ? 'inspeção' : 'inspeções'} para enviar.',
            ),
            const SizedBox(height: IcSpacing.s4),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await services.sync.syncAll();
                      await repo.refresh();
                    },
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: Text(busy ? 'Sincronizando...' : 'Sincronizar agora'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch)),
            ),
            const SizedBox(height: IcSpacing.s6),
            Text('Aguardando envio', style: t.titleMedium),
            const SizedBox(height: IcSpacing.s3),
            if (unsent.isEmpty) Text('Nenhuma inspeção na fila.', style: t.bodyMedium),
            for (final e in unsent)
              Builder(builder: (context) {
                final summary = repo.summaries.where((s) => s.id == e.inspectionId).firstOrNull;
                return Container(
                  margin: const EdgeInsets.only(bottom: IcSpacing.s3),
                  padding: const EdgeInsets.all(IcSpacing.s4),
                  decoration: BoxDecoration(
                      color: IcColors.surface0,
                      borderRadius: BorderRadius.circular(IcRadius.lg),
                      border: Border.all(color: IcColors.borderSubtle)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('OS ${summary?.number ?? ''}', style: IcText.mono()),
                      const Spacer(),
                      Text(e.sync == SyncState.failed ? 'Recusada' : 'Na fila',
                          style: t.bodySmall?.copyWith(
                              color: e.sync == SyncState.failed ? IcColors.danger700 : IcColors.warning700, fontWeight: FontWeight.w700)),
                    ]),
                    if (summary != null) Text(summary.clientName, style: t.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        '${e.photos.length} ${e.photos.length == 1 ? 'foto' : 'fotos'} · ${e.photos.where((p) => !p.uploaded).length} por enviar'
                        '${e.finishedAt != null ? ' · encerrada ${IcFormat.dayMonthTime(e.finishedAt!)}' : ''}',
                        style: t.bodySmall?.copyWith(color: IcColors.ink600)),
                    if (e.syncError != null) ...[
                      const SizedBox(height: 8),
                      IcNotice(kind: NoticeKind.danger, message: e.syncError!),
                    ],
                    if (e.sync == SyncState.failed && summary != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DetailsPage(summary: summary))),
                        child: const Text('Corrigir'),
                      ),
                    ],
                  ]),
                );
              }),
          ]);
        },
      ),
    );
  }
}
