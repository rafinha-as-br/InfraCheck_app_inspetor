import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../data/execution_summary.dart';
import '../../data/inspection_repository.dart';
import '../../data/local_execution.dart';

/// Estado da execução de uma inspeção: item atual, respostas e fotos.
///
/// Cada alteração é aplicada na memória na hora e gravada no aparelho logo em seguida (com um pequeno
/// atraso para agrupar digitação). Nada depende de conexão.
class ExecutionController extends ChangeNotifier {
  ExecutionController({required this.repository, required this.detail, required LocalExecution execution})
      : _exec = execution {
    _index = summary.firstPendingIndex ?? 0;
  }

  final InspectionRepository repository;
  final InspectionDetail detail;

  LocalExecution _exec;
  int _index = 0;
  Timer? _saveTimer;
  bool _disposed = false;

  LocalExecution get execution => _exec;
  int get index => _index;
  int get itemCount => detail.items.length;
  InspectionItem get item => detail.items[_index];
  bool get isFirst => _index == 0;
  bool get isLast => _index == itemCount - 1;
  ExecutionSummary get summary => ExecutionSummary(detail, _exec);
  ItemAnswer? get answer => summary.answerOf(item);

  /// Fotos já no servidor (inspeção devolvida) + as tiradas neste aparelho.
  int get photoCount => summary.photoCount(item);
  List<LocalPhoto> get localPhotos => _exec.photosOf(item.id);

  /// Item não conforme sem criticidade ou sem foto: o avanço fica bloqueado até resolver.
  bool get needsPhoto => answer?.result == ItemResult.nonConforming && photoCount == 0;

  void goTo(int i) {
    _index = i.clamp(0, itemCount - 1);
    notifyListeners();
  }

  void next() => goTo(_index + 1);
  void previous() => goTo(_index - 1);

  // ------------------------------------------------------------------ respostas

  void setResult(ItemResult result) {
    final current = answer;
    if (result == ItemResult.nonConforming) {
      _update(ItemAnswer(
        itemId: item.id,
        result: result,
        criticality: current?.criticality ?? Criticality.medium,
        description: current?.description,
        recommendedAction: current?.recommendedAction,
      ));
    } else {
      // Criticidade, descrição e ação só existem para não conformidades.
      _update(ItemAnswer(itemId: item.id, result: result));
    }
  }

  void setCriticality(Criticality c) {
    final a = answer;
    if (a == null || a.result != ItemResult.nonConforming) return;
    _update(ItemAnswer(
        itemId: item.id, result: a.result, criticality: c, description: a.description, recommendedAction: a.recommendedAction));
  }

  void setDescription(String text) {
    final a = answer;
    if (a == null || a.result != ItemResult.nonConforming) return;
    _update(ItemAnswer(
        itemId: item.id, result: a.result, criticality: a.criticality, description: text, recommendedAction: a.recommendedAction));
  }

  void setRecommendedAction(String text) {
    final a = answer;
    if (a == null || a.result != ItemResult.nonConforming) return;
    _update(ItemAnswer(
        itemId: item.id, result: a.result, criticality: a.criticality, description: a.description, recommendedAction: text));
  }

  void _update(ItemAnswer a) {
    _exec = _exec.copyWith(answers: {..._exec.answers, a.itemId: a});
    _persistSoon();
    notifyListeners();
  }

  // ------------------------------------------------------------------ fotos

  /// Guarda a foto (bytes em arquivo, metadados com data/hora/GPS) e a vincula ao item atual.
  Future<void> addPhoto(Uint8List bytes) async {
    _exec = await repository.addPhoto(_exec, item.id, bytes);
    notifyListeners();
  }

  Future<void> removePhoto(String photoId) async {
    _exec = await repository.removePhoto(_exec, photoId);
    notifyListeners();
  }

  // ------------------------------------------------------------------ persistência

  void _persistSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  /// Grava imediatamente (ao sair da tela ou avançar para a revisão).
  Future<void> flush() async {
    _saveTimer?.cancel();
    await repository.saveExecution(_exec);
  }

  /// Aplica na execução alterações feitas por outra tela (ex.: a assinatura na revisão).
  void adopt(LocalExecution e) {
    _exec = e;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      repository.saveExecution(_exec); // não perder a última digitação ao sair
    }
    super.dispose();
  }
}
