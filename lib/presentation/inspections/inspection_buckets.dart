import 'package:infracheck_modules/infracheck_modules.dart';

/// Filtros da tela "Minhas inspeções".
enum InspectionBucket { today, upcoming, done }

/// Distribui as inspeções nos filtros do design. Lógica pura, sem Flutter.
///
/// - **Hoje**: ainda exigem trabalho (pendente/em andamento) e previstas para hoje ou atrasadas.
/// - **Próximas**: pendentes previstas para depois de hoje.
/// - **Concluídas**: encerradas (concluída, aprovada) e as rejeitadas, que voltam para correção.
///
/// [statusOf] devolve o status *efetivo* (considera o que só existe no aparelho).
Map<InspectionBucket, List<InspectionSummary>> bucketInspections(
  List<InspectionSummary> all,
  InspectionStatus Function(InspectionSummary) statusOf,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final result = {for (final b in InspectionBucket.values) b: <InspectionSummary>[]};
  for (final s in all) {
    final status = statusOf(s);
    final day = DateTime(s.scheduledDate.year, s.scheduledDate.month, s.scheduledDate.day);
    if (status == InspectionStatus.completed || status == InspectionStatus.approved || status == InspectionStatus.rejected) {
      result[InspectionBucket.done]!.add(s);
    } else if (day.isAfter(today)) {
      result[InspectionBucket.upcoming]!.add(s);
    } else {
      result[InspectionBucket.today]!.add(s);
    }
  }
  // Hoje: urgentes primeiro e em andamento antes de pendentes; demais por data.
  result[InspectionBucket.today]!.sort((a, b) {
    if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
    final ai = statusOf(a) == InspectionStatus.inProgress, bi = statusOf(b) == InspectionStatus.inProgress;
    if (ai != bi) return ai ? -1 : 1;
    return a.number.compareTo(b.number);
  });
  result[InspectionBucket.upcoming]!.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  return result;
}
