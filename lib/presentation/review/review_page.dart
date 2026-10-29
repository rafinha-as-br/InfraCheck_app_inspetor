import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../../data/execution_summary.dart';
import '../../data/location_service.dart';
import '../execution/execution_controller.dart';
import '../execution/item_widgets.dart';
import 'signature_pad.dart';

/// M05 — Revisão e envio: resumo de conformidade, não conformidades, verificações, observações gerais,
/// assinatura e o botão "Encerrar e enviar". Sem conexão, a inspeção fica salva e vai sozinha depois.
///
/// Fecha devolvendo `true` quando a inspeção foi encerrada (a tela de execução também se fecha).
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.detail, required this.controller});

  final InspectionDetail detail;
  final ExecutionController controller;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final _notes = TextEditingController(text: widget.controller.execution.generalNotes);
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  ExecutionController get _c => widget.controller;

  Future<void> _sign() async {
    final user = AppScope.of(context).session.user;
    final png = await SignatureDialog.show(context, signerName: '${user?.name ?? ''}${user?.registration != null ? ' · ${user!.registration}' : ''}');
    if (png == null) return;
    await _persist(signature: base64Encode(png));
  }

  Future<void> _persist({Object? signature = _keep}) async {
    final repo = AppScope.of(context).repository;
    final updated = _c.execution.copyWith(
      generalNotes: _notes.text,
      signaturePngBase64: identical(signature, _keep) ? _c.execution.signaturePngBase64 : signature as String?,
    );
    _c.adopt(updated);
    await repo.saveExecution(updated);
  }

  static const _keep = Object();

  Future<void> _send() async {
    final services = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _persist();
      await services.repository.closeExecution(widget.detail, _c.execution);
      services.sync.syncAll(); // tenta enviar já; se não houver sinal, a fila cuida depois
      if (mounted) setState(() => _done = true);
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _DoneView(detail: widget.detail, onClose: () => Navigator.of(context).pop(true));
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_c, services.repository]),
      builder: (context, _) {
        final s = _c.summary;
        final user = services.session.user;
        final t = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Revisar e enviar', style: t.titleLarge?.copyWith(color: IcColors.onPrimary)),
              Text('OS ${widget.detail.number} · ${widget.detail.contract.clientName}',
                  style: t.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
            ]),
          ),
          body: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(IcSpacing.s4), children: [
                _ConformityCard(summary: s),
                const SizedBox(height: IcSpacing.s3),
                _NonConformities(summary: s, onOpen: (i) {
                  _c.goTo(i);
                  Navigator.of(context).pop(false);
                }),
                const SizedBox(height: IcSpacing.s3),
                _Checks(summary: s),
                const SizedBox(height: IcSpacing.s3),
                ItemCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _notes,
                      onChanged: (_) => _persist(),
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      style: t.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Observações gerais'),
                    ),
                    const SizedBox(height: 12),
                    Text('ASSINATURA DO INSPETOR', style: t.labelSmall?.copyWith(color: IcColors.ink700)),
                    const SizedBox(height: 6),
                    _SignatureArea(pngBase64: s.execution.signaturePngBase64, onTap: _sign),
                    Row(children: [
                      Expanded(child: Text('${user?.name ?? ''}${user?.registration != null ? ' · ${user!.registration}' : ''}', style: t.bodySmall?.copyWith(color: IcColors.ink600))),
                      if (s.hasSignature) TextButton(onPressed: () => _persist(signature: null), child: const Text('Limpar')),
                    ]),
                  ]),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(IcSpacing.s4),
              decoration: const BoxDecoration(color: IcColors.surface0, border: Border(top: BorderSide(color: IcColors.borderSubtle)), boxShadow: IcShadows.md),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null) ...[
                    IcNotice(kind: NoticeKind.danger, title: 'Não foi possível encerrar.', message: _error!),
                    const SizedBox(height: 8),
                  ],
                  if (services.repository.offline) ...[
                    const IcNotice(kind: NoticeKind.warn, title: 'Sem conexão:', message: 'a inspeção fica salva e é enviada sozinha ao reconectar.'),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _busy || !s.canSubmit ? null : _send,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined),
                    label: const Text('Encerrar e enviar'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch)),
                  ),
                  if (!s.canSubmit)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_blockReason(s), textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: IcColors.ink700)),
                    ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  /// Motivo (em texto) pelo qual o envio ainda está desabilitado.
  static String _blockReason(ExecutionSummary s) {
    if (s.unanswered.isNotEmpty) return 'Falta responder ${s.unanswered.length} ${s.unanswered.length == 1 ? 'item' : 'itens'}.';
    if (s.ncWithoutCriticality.isNotEmpty) return 'Informe a criticidade das não conformidades.';
    if (s.ncWithoutPhoto.isNotEmpty) return 'Falta foto em ${s.ncWithoutPhoto.length} ${s.ncWithoutPhoto.length == 1 ? 'item não conforme' : 'itens não conformes'}.';
    return 'Assine acima para liberar o envio.';
  }
}

class _ConformityCard extends StatelessWidget {
  const _ConformityCard({required this.summary});

  final ExecutionSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = summary;
    Widget stat(int n, Widget badge) => Expanded(child: Column(children: [Text('$n', style: t.titleLarge), const SizedBox(height: 4), badge]));
    return ItemCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(IcFormat.percent(s.conformityPercent), style: t.displayMedium),
          const SizedBox(width: 10),
          Text('de conformidade', style: t.bodyMedium?.copyWith(color: IcColors.ink700)),
        ]),
        const SizedBox(height: 10),
        Semantics(
          label: '${s.conforming} de ${s.total} itens conformes',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: s.total == 0 ? 0 : s.conforming / s.total, minHeight: 8, color: IcColors.success700, backgroundColor: IcColors.surface100),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          stat(s.conforming, const ResultBadge(ItemResult.conforming, label: 'Conformes')),
          stat(s.nonConforming, const ResultBadge(ItemResult.nonConforming, label: 'Não conf.')),
          stat(s.notApplicable, const ResultBadge(ItemResult.notApplicable)),
        ]),
      ]),
    );
  }
}

class _NonConformities extends StatelessWidget {
  const _NonConformities({required this.summary, required this.onOpen});

  final ExecutionSummary summary;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = summary.nonConformingItems;
    return ItemCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Não conformidades (${items.length})', style: t.titleMedium),
        if (items.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Nenhuma não conformidade registrada.', style: t.bodyMedium)),
        for (final i in items)
          InkWell(
            onTap: () => onOpen(summary.detail.items.indexOf(i)),
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: IcColors.borderSubtle))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Item ${i.itemNo.toString().padLeft(2, '0')}', style: IcText.mono()),
                  const Spacer(),
                  if (summary.answerOf(i)?.criticality != null) CriticalityBadge(summary.answerOf(i)!.criticality!),
                ]),
                const SizedBox(height: 6),
                Text(i.statement, style: t.bodyLarge),
                const SizedBox(height: 4),
                Text('${i.location ?? ''} · ${summary.photoCount(i)} ${summary.photoCount(i) == 1 ? 'foto' : 'fotos'}',
                    style: t.bodySmall?.copyWith(color: summary.photoCount(i) == 0 ? IcColors.danger700 : IcColors.ink600)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Checks extends StatelessWidget {
  const _Checks({required this.summary});

  final ExecutionSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final e = s.execution;
    Widget row(bool ok, String text, {bool neutral = false}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ok ? Icons.check_circle_outline : (neutral ? Icons.radio_button_unchecked : Icons.error_outline),
                size: 22, color: ok ? IcColors.success700 : (neutral ? IcColors.ink700 : IcColors.danger700)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          ]),
        );
    return ItemCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verificações', style: Theme.of(context).textTheme.titleMedium),
        row(s.unanswered.isEmpty, '${s.answered} de ${s.total} itens respondidos'),
        row(s.ncWithoutPhoto.isEmpty && s.ncWithoutCriticality.isEmpty,
            '${s.nonConforming - s.ncWithoutPhoto.length} de ${s.nonConforming} não conformidades com foto (${s.ncPhotos} ${s.ncPhotos == 1 ? 'foto' : 'fotos'})'),
        row(true,
            'Início registrado às ${IcFormat.time(e.startedAt)}${e.startLocation?.accuracy != null ? ' · GPS ±${e.startLocation!.accuracy!.round()} m' : ''}'),
        row(false, 'Encerramento: será registrado ao enviar', neutral: true),
        row(s.hasSignature, s.hasSignature ? 'Assinatura do inspetor registrada' : 'Falta a assinatura do inspetor'),
      ]),
    );
  }
}

class _SignatureArea extends StatelessWidget {
  const _SignatureArea({required this.pngBase64, required this.onTap});

  final String? pngBase64;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Assinar na tela',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IcRadius.md),
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
              color: IcColors.surface0,
              borderRadius: BorderRadius.circular(IcRadius.md),
              border: Border.all(color: IcColors.borderStrong, width: 1.5)),
          child: pngBase64 == null
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.draw_outlined, color: IcColors.primary700),
                  const SizedBox(width: 8),
                  Text('Toque para assinar', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: IcColors.primary700)),
                ])
              : Padding(padding: const EdgeInsets.all(8), child: Image.memory(base64Decode(pngBase64!), fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

/// Tela final: a inspeção foi encerrada. Mostra se já chegou ao servidor ou se está na fila de envio.
class _DoneView extends StatelessWidget {
  const _DoneView({required this.detail, required this.onClose});

  final InspectionDetail detail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.repository,
          builder: (context, _) {
            final exec = services.repository.executionOf(detail.id);
            final sent = exec == null; // a cópia local some quando o servidor confirma
            final failed = exec?.syncError != null;
            return Padding(
              padding: const EdgeInsets.all(IcSpacing.s6),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(failed ? Icons.error_outline : Icons.check_circle_outline, size: 64, color: failed ? IcColors.danger700 : IcColors.success700),
                const SizedBox(height: 16),
                Text('Inspeção encerrada', style: t.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  sent
                      ? 'A OS ${detail.number} foi enviada ao gestor para revisão.'
                      : failed
                          ? 'O servidor recusou o envio: ${exec.syncError}'
                          : 'A OS ${detail.number} foi salva no aparelho e será enviada ao gestor assim que houver conexão.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: IcColors.ink700),
                ),
                const SizedBox(height: 24),
                ItemCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('OS ${detail.number}', style: IcText.mono()),
                      const Spacer(),
                      const StatusBadge(InspectionStatus.completed),
                    ]),
                    const SizedBox(height: 8),
                    Text(detail.contract.clientName, style: t.titleMedium),
                    const SizedBox(height: 4),
                    Text(sent ? 'Enviada ao servidor' : 'Aguardando envio', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
                  ]),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onClose,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(IcSpacing.touch)),
                  child: const Text('Voltar às minhas inspeções'),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
