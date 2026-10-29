import 'package:infracheck_modules/infracheck_modules.dart';

import 'local_execution.dart';

/// Visão calculada de uma execução em andamento: o que já foi respondido e o que ainda impede o envio.
///
/// Combina o checklist da inspeção ([InspectionDetail]) com o que está gravado no aparelho
/// ([LocalExecution]). Em inspeções devolvidas (rejeitadas), as respostas e fotos já enviadas ao servidor
/// valem até que o inspetor as altere. Lógica pura (sem Flutter), por isso testável isoladamente.
///
/// Os requisitos espelham o servidor (briefing): todos os itens respondidos, não conformidade com
/// criticidade e ao menos uma foto, e assinatura do inspetor.
class ExecutionSummary {
  const ExecutionSummary(this.detail, this.execution);

  final InspectionDetail detail;
  final LocalExecution execution;

  /// Resposta vigente do item: a gravada no aparelho ou, na falta dela, a que o servidor já tem.
  ItemAnswer? answerOf(InspectionItem item) {
    final local = execution.answers[item.id];
    if (local != null) return local;
    if (item.result == null) return null;
    return ItemAnswer(
        itemId: item.id,
        result: item.result!,
        criticality: item.criticality,
        description: item.description,
        recommendedAction: item.recommendedAction);
  }

  /// Fotos do item: já no servidor + tiradas neste aparelho.
  int photoCount(InspectionItem item) => item.photos.length + execution.photosOf(item.id).length;

  List<InspectionItem> get unanswered => [for (final i in detail.items) if (answerOf(i) == null) i];

  List<InspectionItem> get nonConformingItems =>
      [for (final i in detail.items) if (answerOf(i)?.result == ItemResult.nonConforming) i];

  List<InspectionItem> get ncWithoutPhoto => [for (final i in nonConformingItems) if (photoCount(i) == 0) i];

  List<InspectionItem> get ncWithoutCriticality =>
      [for (final i in nonConformingItems) if (answerOf(i)?.criticality == null) i];

  int get total => detail.items.length;
  int get answered => total - unanswered.length;
  int get conforming => detail.items.where((i) => answerOf(i)?.result == ItemResult.conforming).length;
  int get nonConforming => nonConformingItems.length;
  int get notApplicable => detail.items.where((i) => answerOf(i)?.result == ItemResult.notApplicable).length;
  int get totalPhotos => detail.items.fold(0, (sum, i) => sum + photoCount(i));
  int get ncPhotos => nonConformingItems.fold(0, (sum, i) => sum + photoCount(i));

  /// Conformes / total de itens (mesma definição do servidor e do design: 38 de 42 = 90,5%).
  double get conformityPercent => total == 0 ? 0 : (conforming * 1000 / total).round() / 10;

  bool get hasSignature => execution.signaturePngBase64 != null;

  bool get canSubmit =>
      total > 0 && unanswered.isEmpty && ncWithoutPhoto.isEmpty && ncWithoutCriticality.isEmpty && hasSignature;

  /// Índice do primeiro item que ainda exige atenção (sem resposta, ou NC sem foto/criticidade).
  int? get firstPendingIndex {
    for (var i = 0; i < detail.items.length; i++) {
      final item = detail.items[i];
      if (answerOf(item) == null || ncWithoutPhoto.contains(item) || ncWithoutCriticality.contains(item)) return i;
    }
    return null;
  }

  /// Monta o pacote de envio. Só deve ser chamado com a execução encerrada ([LocalExecution.finishedAt] e
  /// [LocalExecution.endLocation] preenchidos).
  SubmitPayload toPayload() => SubmitPayload(
        startedAt: execution.startedAt,
        startLocation: execution.startLocation,
        finishedAt: execution.finishedAt!,
        endLocation: execution.endLocation!,
        generalNotes: execution.generalNotes,
        signaturePngBase64: execution.signaturePngBase64!,
        items: [for (final i in detail.items) answerOf(i)!],
      );
}
