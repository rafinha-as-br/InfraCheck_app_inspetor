import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../../data/local_execution.dart';
import '../../data/location_service.dart';
import '../execution/execution_page.dart';

/// M03 — Detalhes da inspeção: local, prazo, checklist por categoria, observação do gestor e o botão que
/// inicia (ou retoma, ou corrige) a execução.
class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key, required this.summary});

  final InspectionSummary summary;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  Future<InspectionDetail?>? _detail;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detail ??= AppScope.of(context).repository.detail(widget.summary.id);
  }

  Future<void> _start(InspectionDetail d) async {
    final repo = AppScope.of(context).repository;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (repo.executionOf(d.id)?.sync == SyncState.failed) await repo.reopen(d.id);
      await repo.beginExecution(d);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ExecutionPage(detail: d)));
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final status = repo.effectiveStatus(widget.summary);
        final exec = repo.executionOf(widget.summary.id);
        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('OS ${widget.summary.number}', style: t.titleLarge?.copyWith(color: IcColors.onPrimary)),
                  Text(widget.summary.type.label, style: t.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
                ]),
              ),
              StatusBadge(status),
            ]),
          ),
          body: FutureBuilder<InspectionDetail?>(
            future: _detail,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final d = snap.data;
              if (d == null) {
                return Padding(
                  padding: const EdgeInsets.all(IcSpacing.s4),
                  child: const IcNotice(
                      kind: NoticeKind.warn,
                      title: 'Detalhes indisponíveis sem conexão.',
                      message: 'Abra esta inspeção uma vez com internet para baixar o checklist.'),
                );
              }
              return Column(children: [
                Expanded(child: _Body(detail: d)),
                _ActionBar(
                  detail: d,
                  status: status,
                  exec: exec,
                  busy: _busy,
                  error: _error,
                  onStart: () => _start(d),
                  onSync: () => AppScope.of(context).sync.syncAll(),
                ),
              ]);
            },
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final InspectionDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = detail;
    final categories = <String, int>{};
    for (final i in d.items) {
      categories[i.category] = (categories[i.category] ?? 0) + 1;
    }
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(IcSpacing.s4),
          decoration: BoxDecoration(
              color: IcColors.surface0,
              borderRadius: BorderRadius.circular(IcRadius.lg),
              border: Border.all(color: IcColors.borderSubtle),
              boxShadow: IcShadows.sm),
          child: child,
        );
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(k, style: t.bodySmall?.copyWith(color: IcColors.ink600))),
            Expanded(child: Text(v, style: t.bodyMedium)),
          ]),
        );
    Widget bullet(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: IcColors.primary700, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: t.bodyLarge)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(IcSpacing.s4), children: [
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.contract.clientName, style: t.titleLarge),
        kv('Local', d.contract.address),
        kv('Data prevista', IcFormat.scheduled(d.scheduledDate, d.shift)),
        kv('Checklist', '${d.checklistCode} · ${d.items.length} itens'),
        kv('Atribuída por', '${d.manager.name}, ${IcFormat.dayMonthTime(d.events.isEmpty ? d.scheduledDate : d.events.first.occurredAt)}'),
        if (d.contract.responsibleName != null) kv('Responsável no local', d.contract.responsibleName!),
      ])),
      if (d.notes != null) ...[
        const SizedBox(height: IcSpacing.s3),
        IcNotice(kind: NoticeKind.brand, title: 'Observação do gestor:', message: d.notes!),
      ],
      if (d.status == InspectionStatus.rejected && d.reviewComment != null) ...[
        const SizedBox(height: IcSpacing.s3),
        IcNotice(kind: NoticeKind.danger, title: '${d.reviewedBy ?? d.manager.name} devolveu a inspeção:', message: d.reviewComment!),
      ],
      const SizedBox(height: IcSpacing.s3),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('O que você vai verificar', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final e in categories.entries)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: IcColors.borderSubtle))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(e.key, style: t.bodyLarge)),
              Text('${e.value} itens', style: IcText.mono()),
            ]),
          ),
      ])),
      const SizedBox(height: IcSpacing.s3),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ao iniciar', style: t.titleMedium),
        bullet(Icons.place_outlined, 'Registramos sua localização ao iniciar e ao encerrar, para comprovar a visita.'),
        bullet(Icons.photo_camera_outlined, 'Itens não conformes exigem pelo menos uma foto.'),
        bullet(Icons.wifi_off, 'Você pode trabalhar sem internet: tudo fica salvo no aparelho.'),
      ])),
    ]);
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.detail,
    required this.status,
    required this.exec,
    required this.busy,
    required this.error,
    required this.onStart,
    required this.onSync,
  });

  final InspectionDetail detail;
  final InspectionStatus status;
  final LocalExecution? exec;
  final bool busy;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final failed = exec?.sync == SyncState.failed;
    final waiting = exec?.sync == SyncState.pending;
    final String? label = failed
        ? 'Corrigir e reenviar'
        : waiting
            ? null
            : switch (status) {
                InspectionStatus.pending => 'Iniciar inspeção',
                InspectionStatus.inProgress => 'Retomar inspeção',
                InspectionStatus.rejected => 'Corrigir e reenviar',
                _ => null,
              };
    return Container(
      padding: const EdgeInsets.all(IcSpacing.s4),
      decoration: const BoxDecoration(color: IcColors.surface0, border: Border(top: BorderSide(color: IcColors.borderSubtle)), boxShadow: IcShadows.md),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (error != null) ...[
            IcNotice(kind: NoticeKind.danger, title: 'Não foi possível iniciar.', message: error!),
            const SizedBox(height: IcSpacing.s3),
          ],
          if (failed && exec?.syncError != null) ...[
            IcNotice(kind: NoticeKind.danger, title: 'O servidor recusou o envio.', message: exec!.syncError!),
            const SizedBox(height: IcSpacing.s3),
          ],
          if (waiting) ...[
            const IcNotice(
                kind: NoticeKind.warn,
                title: 'Aguardando envio.',
                message: 'A inspeção está salva no aparelho e será enviada quando houver conexão.'),
            const SizedBox(height: IcSpacing.s3),
            OutlinedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                label: const Text('Tentar enviar agora'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch))),
          ] else if (label != null)
            FilledButton.icon(
              onPressed: busy ? null : onStart,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(label),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch)),
            )
          else
            Text(
                status == InspectionStatus.approved ? 'Inspeção aprovada pelo gestor.' : 'Inspeção enviada. Aguardando revisão do gestor.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    );
  }
}
