import 'package:flutter_test/flutter_test.dart';
import 'package:infracheck_inspetor/presentation/inspections/inspection_buckets.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2025, 6, 12, 9);

  test('distribui em Hoje, Próximas e Concluídas', () {
    final all = [
      summary(id: 'a', number: 1, date: '2025-06-12'),
      summary(id: 'b', number: 2, date: '2025-06-13'),
      summary(id: 'c', number: 3, status: 'APPROVED', date: '2025-06-10'),
      summary(id: 'd', number: 4, status: 'REJECTED', date: '2025-06-11'),
      summary(id: 'e', number: 5, date: '2025-06-11'), // atrasada: continua em Hoje
    ];
    final b = bucketInspections(all, (s) => s.status, now);
    expect(b[InspectionBucket.today]!.map((s) => s.id), unorderedEquals(['a', 'e']));
    expect(b[InspectionBucket.upcoming]!.map((s) => s.id), ['b']);
    expect(b[InspectionBucket.done]!.map((s) => s.id), unorderedEquals(['c', 'd']));
  });

  test('urgentes e em andamento vêm primeiro em Hoje', () {
    final all = [
      summary(id: 'a', number: 1),
      summary(id: 'b', number: 2, status: 'IN_PROGRESS'),
      summary(id: 'c', number: 3, urgent: true),
    ];
    final today = bucketInspections(all, (s) => s.status, now)[InspectionBucket.today]!;
    expect(today.map((s) => s.id), ['c', 'b', 'a']);
  });

  test('usa o status efetivo (execução encerrada só no aparelho vai para Concluídas)', () {
    final all = [summary(id: 'a', number: 1)];
    final b = bucketInspections(all, (_) => InspectionStatus.completed, now);
    expect(b[InspectionBucket.done], hasLength(1));
    expect(b[InspectionBucket.today], isEmpty);
  });
}
