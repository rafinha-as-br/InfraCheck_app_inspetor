import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../data/local_execution.dart';

/// Cartão de inspeção da lista (design: `ic-card-link` / `ic-insp`): OS e selos no topo, cliente, três
/// linhas de metadados, progresso (quando em andamento), motivo da rejeição e rodapé com chevron.
/// O cartão inteiro é o alvo de toque.
class InspectionCard extends StatelessWidget {
  const InspectionCard({super.key, required this.summary, required this.status, required this.onTap, this.execution});

  final InspectionSummary summary;

  /// Status efetivo (considera o que só existe no aparelho).
  final InspectionStatus status;
  final LocalExecution? execution;
  final VoidCallback onTap;

  String _when() {
    final s = summary;
    return switch (status) {
      InspectionStatus.pending => IcFormat.scheduled(s.scheduledDate, s.shift),
      InspectionStatus.inProgress => 'Iniciada ${IcFormat.dayMonthTime((execution?.startedAt ?? s.startedAt) ?? s.scheduledDate)}',
      InspectionStatus.completed =>
        'Encerrada ${IcFormat.dayMonthTime((execution?.finishedAt ?? s.finishedAt) ?? s.scheduledDate)}',
      InspectionStatus.approved => 'Encerrada ${s.finishedAt == null ? '' : IcFormat.dayMonthTime(s.finishedAt!)}',
      InspectionStatus.rejected => 'Devolvida pelo gestor',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = summary;
    final answered = status == InspectionStatus.inProgress && execution != null ? execution!.answers.length : null;
    final total = s.stats.total;
    Widget meta(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: IcColors.ink600),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: t.bodyMedium?.copyWith(color: IcColors.ink700))),
          ]),
        );
    return Material(
      color: IcColors.surface0,
      borderRadius: BorderRadius.circular(IcRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(IcRadius.lg),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: IcSpacing.touch),
          padding: const EdgeInsets.all(IcSpacing.s4),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(IcRadius.lg), border: Border.all(color: IcColors.borderSubtle), boxShadow: IcShadows.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('OS ${s.number}', style: IcText.mono()),
              const Spacer(),
              if (s.urgent) ...[const UrgentBadge(), const SizedBox(width: 6)],
              StatusBadge(status),
            ]),
            const SizedBox(height: 8),
            Text(s.clientName, style: t.titleMedium),
            meta(Icons.place_outlined, s.address),
            meta(Icons.fact_check_outlined, '${s.type.label} · $total itens'),
            meta(Icons.schedule, _when()),
            if (answered != null && total > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: answered / total, minHeight: 8, color: IcColors.primary700, backgroundColor: IcColors.surface100),
              ),
              const SizedBox(height: 4),
              Text('$answered de $total itens respondidos', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
            ],
            if (status == InspectionStatus.rejected && s.reviewComment != null) ...[
              const SizedBox(height: 10),
              IcNotice(kind: NoticeKind.danger, title: '${s.managerName}:', message: s.reviewComment!),
            ],
            if (execution?.sync == SyncState.failed && execution?.syncError != null) ...[
              const SizedBox(height: 10),
              IcNotice(kind: NoticeKind.danger, title: 'Envio recusado.', message: execution!.syncError!),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(cardFooter(s, status, execution), style: t.bodySmall?.copyWith(color: IcColors.ink600))),
              const Icon(Icons.chevron_right, color: IcColors.ink600),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Texto de apoio do rodapé do cartão, conforme o estado (inclui o que só existe no aparelho).
String cardFooter(InspectionSummary s, InspectionStatus status, LocalExecution? exec) {
  if (exec != null && (exec.sync == SyncState.pending)) return 'Aguardando envio ao servidor';
  if (exec != null && exec.sync == SyncState.failed) return 'Envio recusado · toque para corrigir';
  return switch (status) {
    InspectionStatus.pending => 'Atribuída por ${s.managerName}',
    InspectionStatus.inProgress => 'Toque para retomar',
    InspectionStatus.completed => 'Aguardando revisão do gestor',
    InspectionStatus.approved => 'Aprovada pelo gestor',
    InspectionStatus.rejected => 'Toque para corrigir',
  };
}
