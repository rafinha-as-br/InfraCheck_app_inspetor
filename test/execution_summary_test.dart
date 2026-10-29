import 'package:flutter_test/flutter_test.dart';
import 'package:infracheck_inspetor/data/execution_summary.dart';
import 'package:infracheck_inspetor/data/local_execution.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'support/fixtures.dart';

LocalExecution exec({Map<String, ItemAnswer> answers = const {}, List<LocalPhoto> photos = const [], String? signature}) =>
    LocalExecution(
      inspectionId: 'insp-1',
      startedAt: DateTime.utc(2025, 6, 12, 11),
      startLocation: const GeoPoint(lat: -23.56, lng: -46.65, accuracy: 6),
      answers: answers,
      photos: photos,
      signaturePngBase64: signature,
      finishedAt: DateTime.utc(2025, 6, 12, 12),
      endLocation: const GeoPoint(lat: -23.56, lng: -46.65),
    );

LocalPhoto photo(String itemId) => LocalPhoto(id: 'p-$itemId', itemId: itemId, capturedAt: DateTime.utc(2025, 6, 12, 11, 30));

void main() {
  final d = detail();

  test('sem respostas, nada pode ser enviado e o primeiro item está pendente', () {
    final s = ExecutionSummary(d, exec());
    expect(s.unanswered, hasLength(2));
    expect(s.canSubmit, isFalse);
    expect(s.firstPendingIndex, 0);
  });

  test('não conformidade sem foto bloqueia o envio; com foto e assinatura libera', () {
    final answers = {
      'item-1': const ItemAnswer(itemId: 'item-1', result: ItemResult.conforming),
      'item-2': const ItemAnswer(itemId: 'item-2', result: ItemResult.nonConforming, criticality: Criticality.high, description: 'Trinca'),
    };
    final semFoto = ExecutionSummary(d, exec(answers: answers, signature: 'sig'));
    expect(semFoto.ncWithoutPhoto.single.id, 'item-2');
    expect(semFoto.canSubmit, isFalse);
    expect(semFoto.firstPendingIndex, 1);

    final completo = ExecutionSummary(d, exec(answers: answers, photos: [photo('item-2')], signature: 'sig'));
    expect(completo.canSubmit, isTrue);
    expect(completo.conformityPercent, 50);
    expect(completo.totalPhotos, 1);
  });

  test('sem assinatura não envia, mesmo com tudo respondido', () {
    final answers = {
      for (final i in d.items) i.id: ItemAnswer(itemId: i.id, result: ItemResult.notApplicable),
    };
    final s = ExecutionSummary(d, exec(answers: answers));
    expect(s.unanswered, isEmpty);
    expect(s.hasSignature, isFalse);
    expect(s.canSubmit, isFalse);
  });

  test('o pacote de envio contém todas as respostas, na ordem do checklist', () {
    final answers = {
      'item-2': const ItemAnswer(itemId: 'item-2', result: ItemResult.conforming),
      'item-1': const ItemAnswer(itemId: 'item-1', result: ItemResult.notApplicable),
    };
    final payload = ExecutionSummary(d, exec(answers: answers, signature: 'sig')).toPayload();
    expect(payload.items.map((e) => e.itemId), ['item-1', 'item-2']);
    expect(payload.signaturePngBase64, 'sig');
  });
}
