import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'execution_summary.dart';
import 'inspection_repository.dart';
import 'local_execution.dart';

/// Envia ao servidor as execuções encerradas, na ordem: fotos (idempotentes) e depois o pacote final.
///
/// Regras de segurança dos dados:
/// - sem conexão, nada é descartado: a execução continua `pending` e é tentada de novo (periodicamente, ao
///   voltar ao app e quando o inspetor pede);
/// - se o servidor recusar o conteúdo (ex.: validação), a execução fica `failed` com o motivo, e o inspetor
///   corrige e reenvia;
/// - só depois da confirmação do servidor a cópia local (e as fotos) é apagada.
class SyncService extends ChangeNotifier {
  SyncService(this._repo);

  final InspectionRepository _repo;
  Timer? _timer;
  bool _syncing = false;

  bool get syncing => _syncing;

  /// Liga a tentativa automática periódica enquanto o app está aberto.
  void startAutoSync({Duration every = const Duration(seconds: 45)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) {
      if (_repo.unsent.any((e) => e.sync == SyncState.pending)) syncAll();
    });
  }

  /// Tenta enviar tudo o que está pendente. Seguro para chamar a qualquer momento (não reentra).
  Future<void> syncAll() async {
    if (_syncing) return;
    final pending = _repo.unsent.where((e) => e.sync == SyncState.pending).toList();
    if (pending.isEmpty) return;
    _syncing = true;
    notifyListeners();
    var anySuccess = false;
    try {
      for (final exec in pending) {
        final result = await _syncOne(exec);
        if (result == _Result.offline) break;
        if (result == _Result.sent) anySuccess = true;
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
    if (anySuccess) await _repo.refresh();
  }

  Future<_Result> _syncOne(LocalExecution original) async {
    var exec = original;
    final detail = await _repo.detail(exec.inspectionId);
    if (detail == null) return _Result.offline;
    try {
      for (final photo in exec.photos.where((p) => !p.uploaded)) {
        final bytes = await _repo.blobs.read(photo.id);
        if (bytes == null) {
          await _repo.saveExecution(exec.copyWith(
              sync: SyncState.failed, syncError: 'Uma foto não foi encontrada no aparelho. Tire a foto novamente.'));
          return _Result.failed;
        }
        await _repo.api.uploadPhoto(
          inspectionId: exec.inspectionId,
          photoId: photo.id,
          itemId: photo.itemId,
          bytes: bytes,
          capturedAt: photo.capturedAt,
          location: photo.location,
        );
        exec = exec.copyWith(photos: [for (final p in exec.photos) p.id == photo.id ? p.copyWith(uploaded: true) : p]);
        await _repo.saveExecution(exec);
      }
      await _repo.api.submit(exec.inspectionId, ExecutionSummary(detail, exec).toPayload());
      _repo.reportConnectivity(offline: false);
      await _repo.completeSync(exec);
      return _Result.sent;
    } on ApiError catch (e) {
      if (e.isNetwork) {
        _repo.reportConnectivity(offline: true);
        return _Result.offline;
      }
      if (e.isUnauthorized) return _Result.offline; // a sessão cuida do retorno ao login; os dados ficam
      await _repo.saveExecution(exec.copyWith(sync: SyncState.failed, syncError: e.fullMessage));
      return _Result.failed;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

enum _Result { sent, offline, failed }
