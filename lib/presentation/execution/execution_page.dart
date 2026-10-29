import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../review/review_page.dart';
import 'execution_controller.dart';
import 'item_widgets.dart';

/// M04 — Executar inspeção: um item por vez, com resultado, criticidade, descrição, ação recomendada e fotos.
/// Tudo é salvo no aparelho a cada toque.
class ExecutionPage extends StatefulWidget {
  const ExecutionPage({super.key, required this.detail});

  final InspectionDetail detail;

  @override
  State<ExecutionPage> createState() => _ExecutionPageState();
}

class _ExecutionPageState extends State<ExecutionPage> {
  ExecutionController? _c;
  String? _photoError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c == null) {
      final repo = AppScope.of(context).repository;
      _c = ExecutionController(repository: repo, detail: widget.detail, execution: repo.executionOf(widget.detail.id)!);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    setState(() => _photoError = null);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
      if (file == null) return;
      await _c!.addPhoto(await file.readAsBytes());
    } on PlatformException {
      if (mounted) setState(() => _photoError = 'Não foi possível abrir a câmera. Verifique a permissão do app.');
    }
  }

  Future<void> _openReview() async {
    final repo = AppScope.of(context).repository;
    await _c!.flush();
    if (!mounted) return;
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReviewPage(detail: widget.detail, controller: _c!)));
    if (!mounted) return;
    if (done == true) {
      Navigator.of(context).pop();
    } else {
      final latest = repo.executionOf(widget.detail.id);
      if (latest != null) _c!.adopt(latest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final item = c.item;
        final a = c.answer;
        final exec = c.execution;
        final nc = a?.result == ItemResult.nonConforming;
        final start = exec.startLocation;
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('OS ${widget.detail.number}', style: t.titleLarge?.copyWith(color: IcColors.onPrimary)),
              Text(widget.detail.contract.clientName, style: t.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
            ]),
            actions: [
              IconButton(tooltip: 'Revisar e enviar', icon: const Icon(Icons.fact_check_outlined), onPressed: _openReview),
            ],
          ),
          body: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: IcSpacing.s4, vertical: IcSpacing.s3),
              decoration: const BoxDecoration(color: IcColors.surface0, border: Border(bottom: BorderSide(color: IcColors.borderSubtle))),
              child: Column(children: [
                Row(children: [
                  Text('Item ${(c.index + 1).toString().padLeft(2, '0')} de ${c.itemCount}', style: IcText.mono()),
                  const Spacer(),
                  const Icon(Icons.save_outlined, size: 16, color: IcColors.ink600),
                  const SizedBox(width: 4),
                  Text('Salvo no aparelho', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
                ]),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Progresso da inspeção',
                  value: '${c.index + 1} de ${c.itemCount}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: (c.index + 1) / c.itemCount, minHeight: 8, color: IcColors.primary700, backgroundColor: IcColors.surface100),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(IcSpacing.s4), children: [
                ItemCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.category.toUpperCase(), style: t.labelSmall?.copyWith(color: IcColors.ink600)),
                    const SizedBox(height: 8),
                    Text(item.statement, style: t.titleLarge),
                    if (item.location != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 18, color: IcColors.ink700),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.location!, style: t.bodyLarge?.copyWith(color: IcColors.ink700))),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: IcSpacing.s3),
                ItemCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Resultado', style: t.titleMedium),
                    const SizedBox(height: 12),
                    ResultSegment(selected: a?.result, onSelected: c.setResult),
                  ]),
                ),
                if (nc) ...[
                  const SizedBox(height: IcSpacing.s3),
                  NonConformityCard(
                    key: ValueKey('nc-${item.id}'),
                    answer: a!,
                    onCriticality: c.setCriticality,
                    onDescription: c.setDescription,
                    onAction: c.setRecommendedAction,
                  ),
                ],
                const SizedBox(height: IcSpacing.s3),
                PhotosCard(
                  key: ValueKey('photos-${item.id}'),
                  serverPhotos: item.photos,
                  localPhotos: c.localPhotos,
                  needsPhoto: c.needsPhoto,
                  error: _photoError,
                  onAdd: _takePhoto,
                  onRemove: c.removePhoto,
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(IcSpacing.s4),
              decoration: const BoxDecoration(color: IcColors.surface0, border: Border(top: BorderSide(color: IcColors.borderSubtle)), boxShadow: IcShadows.md),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 16, color: IcColors.ink600),
                    const SizedBox(width: 6),
                    Text(
                        start == null
                            ? 'Início registrado às ${IcFormat.time(exec.startedAt)}'
                            : 'Início registrado às ${IcFormat.time(exec.startedAt)} · GPS${start.accuracy != null ? ' ±${start.accuracy!.round()} m' : ''}',
                        style: IcText.mono(size: 12, color: IcColors.ink600)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: c.isFirst ? null : c.previous,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Anterior'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, IcSpacing.touch)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: c.isLast
                          ? FilledButton(
                              onPressed: _openReview,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, IcSpacing.touch),
                                  backgroundColor: IcColors.signal500,
                                  foregroundColor: IcColors.ink900),
                              child: const Text('Revisar e enviar'))
                          : FilledButton.icon(
                              onPressed: c.needsPhoto ? null : c.next,
                              icon: const Icon(Icons.arrow_forward),
                              iconAlignment: IconAlignment.end,
                              label: const Text('Próximo item'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, IcSpacing.touch)),
                            ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
