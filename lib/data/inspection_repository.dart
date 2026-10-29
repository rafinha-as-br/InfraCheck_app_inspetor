import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../core/ids.dart';
import 'execution_summary.dart';
import 'local_execution.dart';
import 'local_store.dart';
import 'location_service.dart';

/// Fonte única de dados do app: junta o que veio do servidor (cache local) com o que o inspetor já coletou
/// no aparelho. A UI nunca fala direto com a API nem com o armazenamento.
///
/// Offline-first:
/// - a lista e os checklists das inspeções abertas são baixados em [refresh] e guardados no aparelho;
/// - cada resposta/foto é gravada em disco no mesmo instante ([saveExecution]);
/// - o envio ao servidor é feito à parte, pelo `SyncService`, quando houver conexão.
class InspectionRepository extends ChangeNotifier {
  InspectionRepository({required this.api, required this.store, required this.blobs, required this.location}) {
    _summaries = [for (final j in store.cachedList) InspectionSummary.fromJson(j)];
    _executions = {for (final e in store.allExecutions()) e.inspectionId: e};
  }

  final InfraCheckApi api;
  final LocalStore store;
  final PhotoBlobStore blobs;
  final LocationService location;

  List<InspectionSummary> _summaries = const [];
  Map<String, LocalExecution> _executions = {};
  bool _refreshing = false;
  bool _offline = false;
  String? _refreshError;

  List<InspectionSummary> get summaries => _summaries;
  bool get refreshing => _refreshing;

  /// A última tentativa de falar com o servidor não teve resposta (sem sinal).
  bool get offline => _offline;
  String? get refreshError => _refreshError;

  LocalExecution? executionOf(String inspectionId) => _executions[inspectionId];

  /// Execuções encerradas que ainda não chegaram ao servidor.
  List<LocalExecution> get unsent =>
      _executions.values.where((e) => e.sync == SyncState.pending || e.sync == SyncState.failed).toList();

  /// Marca que há (ou não) conexão, conforme o resultado da última chamada à API.
  void reportConnectivity({required bool offline}) {
    if (_offline != offline) {
      _offline = offline;
      notifyListeners();
    }
  }

  /// Status exibido ao inspetor, levando em conta o que existe só no aparelho.
  InspectionStatus effectiveStatus(InspectionSummary s) {
    final e = _executions[s.id];
    if (e == null) return s.status;
    return switch (e.sync) {
      SyncState.draft => s.status == InspectionStatus.rejected ? InspectionStatus.rejected : InspectionStatus.inProgress,
      SyncState.pending || SyncState.failed => InspectionStatus.completed,
      SyncState.synced => s.status,
    };
  }

  // ------------------------------------------------------------------ servidor → aparelho

  /// Baixa a lista e, para cada inspeção que ainda exige trabalho do inspetor, o checklist completo.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    try {
      final j = await api.listInspectionsJson();
      final content = j['content'] as List;
      await store.saveList(content);
      _summaries = [for (final e in content) InspectionSummary.fromJson(e as Map<String, dynamic>)];
      for (final s in _summaries.where(_needsOfflineDetail)) {
        await store.saveDetail(s.id, await api.getInspectionJson(s.id));
      }
      _offline = false;
      _refreshError = null;
    } on ApiError catch (e) {
      _offline = e.isNetwork;
      _refreshError = e.isNetwork ? null : e.fullMessage;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  static bool _needsOfflineDetail(InspectionSummary s) =>
      s.status == InspectionStatus.pending || s.status == InspectionStatus.inProgress || s.status == InspectionStatus.rejected;

  /// Inspeção completa: do cache; se não houver (ex.: concluída antiga), tenta o servidor.
  Future<InspectionDetail?> detail(String id) async {
    final cached = store.cachedDetail(id);
    if (cached != null) return InspectionDetail.fromJson(cached);
    try {
      final json = await api.getInspectionJson(id);
      await store.saveDetail(id, json);
      _offline = false;
      return InspectionDetail.fromJson(json);
    } on ApiError catch (e) {
      _offline = e.isNetwork;
      notifyListeners();
      return null;
    }
  }

  // ------------------------------------------------------------------ execução em campo

  /// Inicia (ou retoma) a execução. Registra horário e GPS reais; sem GPS não inicia.
  ///
  /// Em inspeção devolvida pelo gestor reaproveita o início original. Tenta avisar o servidor
  /// ("em andamento"), mas a falta de conexão nunca impede o trabalho.
  Future<LocalExecution> beginExecution(InspectionDetail d) async {
    final existing = _executions[d.id];
    if (existing != null && existing.sync == SyncState.draft) return existing;

    LocalExecution exec;
    if (d.status == InspectionStatus.rejected && d.startedAt != null) {
      exec = LocalExecution(inspectionId: d.id, startedAt: d.startedAt!, startLocation: d.startLocation);
    } else {
      final start = await location.current();
      exec = LocalExecution(inspectionId: d.id, startedAt: DateTime.now(), startLocation: start);
      _tryNotifyStart(d, exec);
    }
    await saveExecution(exec);
    return exec;
  }

  Future<void> _tryNotifyStart(InspectionDetail d, LocalExecution exec) async {
    if (d.status != InspectionStatus.pending || exec.startLocation == null) return;
    try {
      await api.startInspection(d.id, exec.startedAt, exec.startLocation!);
      _offline = false;
    } on ApiError {
      // Offline ou recusado: o início segue gravado no aparelho e vai junto com o envio final.
    }
  }

  /// Grava a execução no aparelho e avisa a UI. Chamado a cada alteração (nada se perde sem conexão).
  Future<void> saveExecution(LocalExecution e) async {
    _executions = {..._executions, e.inspectionId: e};
    await store.saveExecution(e);
    notifyListeners();
  }

  /// Guarda os bytes da foto e a registra na execução, com data, hora e (se houver) GPS da captura.
  Future<LocalExecution> addPhoto(LocalExecution exec, String itemId, Uint8List bytes) async {
    final id = newUuid();
    final gps = await location.currentOrNull();
    await blobs.save(id, bytes);
    final updated = exec.copyWith(
        photos: [...exec.photos, LocalPhoto(id: id, itemId: itemId, capturedAt: DateTime.now(), location: gps)]);
    await saveExecution(updated);
    return updated;
  }

  Future<LocalExecution> removePhoto(LocalExecution exec, String photoId) async {
    await blobs.delete(photoId);
    final updated = exec.copyWith(photos: [for (final p in exec.photos) if (p.id != photoId) p]);
    await saveExecution(updated);
    return updated;
  }

  /// Encerra a execução: grava horário e GPS de término e a coloca na fila de envio.
  /// Falha com [LocationException] se não houver GPS; o inspetor pode tentar de novo sem perder nada.
  Future<LocalExecution> closeExecution(InspectionDetail d, LocalExecution exec) async {
    final end = await location.current();
    final closed = exec.copyWith(finishedAt: DateTime.now(), endLocation: end, sync: SyncState.pending, syncError: null);
    await saveExecution(closed);
    return closed;
  }

  /// Devolve ao inspetor uma execução que o servidor recusou, para que ele corrija o que for preciso.
  Future<void> reopen(String inspectionId) async {
    final e = _executions[inspectionId];
    if (e == null) return;
    await saveExecution(e.copyWith(sync: SyncState.draft, syncError: null));
  }

  /// Chamado pelo `SyncService` quando o servidor confirmou o recebimento: apaga a cópia local
  /// (inclusive as fotos, dados sensíveis) e atualiza a lista.
  Future<void> completeSync(LocalExecution e) async {
    for (final p in e.photos) {
      await blobs.delete(p.id);
    }
    _executions = {..._executions}..remove(e.inspectionId);
    await store.deleteExecution(e.inspectionId);
    notifyListeners();
  }

  ExecutionSummary? summaryOf(InspectionDetail d) {
    final e = _executions[d.id];
    return e == null ? null : ExecutionSummary(d, e);
  }
}
