import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../../data/local_execution.dart';

/// Cartão branco usado nas seções da execução.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(IcSpacing.s4),
        decoration: BoxDecoration(
            color: IcColors.surface0,
            borderRadius: BorderRadius.circular(IcRadius.lg),
            border: Border.all(color: IcColors.borderSubtle),
            boxShadow: IcShadows.sm),
        child: child,
      );
}

/// Seletor de resultado (`ic-seg`): três opções sempre visíveis lado a lado, 56 px de altura, operável
/// com uma mão. O selecionado muda de fundo e borda (nunca só a cor: ícone + palavra) e expõe `selected`
/// para leitores de tela.
class ResultSegment extends StatelessWidget {
  const ResultSegment({super.key, required this.selected, required this.onSelected});

  final ItemResult? selected;
  final ValueChanged<ItemResult> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget option(ItemResult r, IconData icon, String label) {
      final on = selected == r;
      final (bg, fg, border) = switch (r) {
        ItemResult.conforming => (on ? IcColors.success100 : IcColors.surface0, on ? IcColors.success700 : IcColors.ink700, on ? IcColors.success700 : IcColors.borderStrong),
        ItemResult.nonConforming => (on ? IcColors.danger700 : IcColors.surface0, on ? IcColors.onPrimary : IcColors.ink700, on ? IcColors.danger700 : IcColors.borderStrong),
        ItemResult.notApplicable => (on ? IcColors.surface100 : IcColors.surface0, IcColors.ink700, on ? IcColors.ink700 : IcColors.borderStrong),
      };
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(IcRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(IcRadius.md),
              onTap: () => onSelected(r),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(IcRadius.md), border: Border.all(color: border, width: on ? 2 : 1)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: fg),
                  const SizedBox(height: 2),
                  Text(label, style: t.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      option(ItemResult.conforming, Icons.check, 'Conforme'),
      const SizedBox(width: 8),
      option(ItemResult.nonConforming, Icons.warning_amber_rounded, 'Não conforme'),
      const SizedBox(width: 8),
      option(ItemResult.notApplicable, Icons.remove, 'N/A'),
    ]);
  }
}

/// Bloco "Não conformidade": criticidade (4 níveis com barras de sinal), descrição e ação recomendada.
class NonConformityCard extends StatefulWidget {
  const NonConformityCard({
    super.key,
    required this.answer,
    required this.onCriticality,
    required this.onDescription,
    required this.onAction,
  });

  final ItemAnswer answer;
  final ValueChanged<Criticality> onCriticality;
  final ValueChanged<String> onDescription;
  final ValueChanged<String> onAction;

  @override
  State<NonConformityCard> createState() => _NonConformityCardState();
}

class _NonConformityCardState extends State<NonConformityCard> {
  late final _description = TextEditingController(text: widget.answer.description);
  late final _action = TextEditingController(text: widget.answer.recommendedAction);

  @override
  void dispose() {
    _description.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ItemCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Não conformidade', style: t.titleMedium),
        const SizedBox(height: 14),
        Text('CRITICIDADE', style: t.labelSmall?.copyWith(color: IcColors.ink700)),
        const SizedBox(height: 6),
        Row(children: [
          for (final c in Criticality.values) ...[
            Expanded(child: _CriticalityOption(c, selected: widget.answer.criticality == c, onTap: () => widget.onCriticality(c))),
            if (c != Criticality.critical) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _description,
          onChanged: widget.onDescription,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          style: t.bodyLarge,
          decoration: const InputDecoration(labelText: 'Descrição da situação', hintText: 'Descreva o que foi encontrado'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _action,
          onChanged: widget.onAction,
          maxLength: 1000,
          style: t.bodyLarge,
          decoration: const InputDecoration(labelText: 'Ação recomendada', hintText: 'Ex.: substituir, recarregar, agendar revisão'),
        ),
      ]),
    );
  }
}

class _CriticalityOption extends StatelessWidget {
  const _CriticalityOption(this.criticality, {required this.selected, required this.onTap});

  final Criticality criticality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = criticalityColors(criticality);
    return Semantics(
      button: true,
      selected: selected,
      label: criticality.label,
      child: Material(
        color: selected ? bg : IcColors.surface0,
        borderRadius: BorderRadius.circular(IcRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(IcRadius.md),
          onTap: onTap,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(IcRadius.md),
                border: Border.all(color: selected ? fg : IcColors.borderStrong, width: selected ? 2 : 1)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SignalBars(level: criticality.level, color: selected ? fg : IcColors.ink700),
              const SizedBox(height: 4),
              Text(criticality.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? fg : IcColors.ink700, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bloco "Fotos": miniaturas com data/hora (cada foto grava data, hora e GPS na captura) e o botão de câmera.
class PhotosCard extends StatelessWidget {
  const PhotosCard({
    super.key,
    required this.serverPhotos,
    required this.localPhotos,
    required this.needsPhoto,
    required this.onAdd,
    required this.onRemove,
    this.error,
  });

  /// Fotos que já estão no servidor (inspeção devolvida para correção).
  final List<Photo> serverPhotos;
  final List<LocalPhoto> localPhotos;
  final bool needsPhoto;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final services = AppScope.of(context);
    final total = serverPhotos.length + localPhotos.length;
    return ItemCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Fotos', style: t.titleMedium)),
          Text(total == 1 ? '1 foto' : '$total fotos', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in serverPhotos)
            _Thumb(
              meta: IcFormat.dayMonthTime(p.capturedAt),
              child: ApiImage(cacheKey: 'photo-${p.id}', loader: () => services.session.api.photoBytes(p.id)),
            ),
          for (final p in localPhotos)
            _Thumb(
              meta: IcFormat.dayMonthTime(p.capturedAt),
              onRemove: () => onRemove(p.id),
              child: FutureBuilder<Uint8List?>(
                future: services.repository.blobs.read(p.id),
                builder: (_, snap) => snap.data == null
                    ? const ColoredBox(color: IcColors.surface100)
                    : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
          Semantics(
            button: true,
            label: 'Adicionar foto',
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(IcRadius.md),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: IcColors.primary50,
                    borderRadius: BorderRadius.circular(IcRadius.md),
                    border: Border.all(color: IcColors.primary700, width: 1.5)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.photo_camera_outlined, color: IcColors.primary700),
                  const SizedBox(height: 4),
                  Text('Adicionar', style: t.bodySmall?.copyWith(color: IcColors.primary700, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ]),
        if (error != null) ...[
          const SizedBox(height: 12),
          IcNotice(kind: NoticeKind.danger, message: error!),
        ],
        const SizedBox(height: 12),
        if (needsPhoto)
          const IcNotice(
              kind: NoticeKind.danger,
              title: 'Falta uma foto.',
              message: 'Item não conforme exige pelo menos uma foto para avançar.')
        else
          Text('Cada foto grava data, hora e GPS no momento da captura.', style: t.bodySmall?.copyWith(color: IcColors.ink600)),
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.meta, this.onRemove});

  final Widget child;
  final String meta;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(IcRadius.md),
        child: Stack(fit: StackFit.expand, children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xB30B2B4D),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(meta, textAlign: TextAlign.center, style: IcText.mono(size: 10, color: IcColors.onPrimary)),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Remover foto',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                style: IconButton.styleFrom(backgroundColor: const Color(0xB30B2B4D), foregroundColor: IcColors.onPrimary),
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
        ]),
      ),
    );
  }
}
