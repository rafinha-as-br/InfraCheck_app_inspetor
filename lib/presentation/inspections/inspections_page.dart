import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../details/details_page.dart';
import 'inspection_buckets.dart';
import 'inspection_card.dart';

/// M02 — Minhas inspeções: filtros Hoje / Próximas / Concluídas e aviso de conexão/envio pendente.
class InspectionsPage extends StatefulWidget {
  const InspectionsPage({super.key});

  @override
  State<InspectionsPage> createState() => _InspectionsPageState();
}

class _InspectionsPageState extends State<InspectionsPage> {
  InspectionBucket _bucket = InspectionBucket.today;
  bool _started = false;

  static const _weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AppScope.of(context).repository.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final repo = services.repository;
    final now = DateTime.now();
    final user = services.session.user;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Row(children: [
          const IcLogo(LogoVariant.markReverse, height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Minhas inspeções', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: IcColors.onPrimary)),
              Text('${_weekdays[now.weekday - 1]}, ${IcFormat.dayMonth(now)} · ${user?.name ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
            ]),
          ),
        ]),
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final buckets = bucketInspections(repo.summaries, repo.effectiveStatus, now);
          final list = buckets[_bucket]!;
          final unsent = repo.unsent.length;
          return RefreshIndicator(
            onRefresh: () async {
              await services.sync.syncAll();
              await repo.refresh();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(IcSpacing.s4),
              children: [
                if (unsent > 0 || repo.offline) ...[
                  IcNotice(
                    kind: NoticeKind.warn,
                    title: repo.offline ? 'Sem conexão.' : 'Envio pendente.',
                    message: unsent > 0
                        ? '$unsent ${unsent == 1 ? 'inspeção será enviada' : 'inspeções serão enviadas'} quando o sinal voltar.'
                        : 'Você pode continuar trabalhando: tudo fica salvo no aparelho.',
                  ),
                  const SizedBox(height: IcSpacing.s3),
                ],
                if (repo.refreshError != null) ...[
                  IcNotice(kind: NoticeKind.danger, title: 'Não foi possível atualizar.', message: repo.refreshError!),
                  const SizedBox(height: IcSpacing.s3),
                ],
                _Chips(
                    selected: _bucket,
                    counts: {for (final e in buckets.entries) e.key: e.value.length},
                    onSelected: (b) => setState(() => _bucket = b)),
                const SizedBox(height: IcSpacing.s3),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: IcSpacing.s12),
                    child: Column(children: [
                      Text(repo.refreshing ? 'Atualizando...' : 'Nenhuma inspeção aqui', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Puxe a lista para baixo para atualizar.', style: Theme.of(context).textTheme.bodyMedium),
                    ]),
                  ),
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: IcSpacing.s3),
                    child: InspectionCard(
                      summary: s,
                      status: repo.effectiveStatus(s),
                      execution: repo.executionOf(s.id),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DetailsPage(summary: s))),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.selected, required this.counts, required this.onSelected});

  final InspectionBucket selected;
  final Map<InspectionBucket, int> counts;
  final ValueChanged<InspectionBucket> onSelected;

  @override
  Widget build(BuildContext context) {
    String label(InspectionBucket b) => switch (b) {
          InspectionBucket.today => 'Hoje',
          InspectionBucket.upcoming => 'Próximas',
          InspectionBucket.done => 'Concluídas',
        };
    return Wrap(spacing: 8, children: [
      for (final b in InspectionBucket.values)
        Semantics(
          button: true,
          selected: selected == b,
          child: ChoiceChip(
            selected: selected == b,
            onSelected: (_) => onSelected(b),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            side: BorderSide(color: selected == b ? IcColors.primary700 : IcColors.borderStrong, width: selected == b ? 2 : 1),
            selectedColor: IcColors.primary100,
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label(b)),
              const SizedBox(width: 6),
              Text('${counts[b]}', style: IcText.mono(size: 12, color: IcColors.ink600)),
            ]),
          ),
        ),
    ]);
  }
}
