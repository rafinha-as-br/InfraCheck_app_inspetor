import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

/// Tela cheia para o inspetor assinar com o dedo. Devolve o PNG (fundo transparente, tinta `ink-900`)
/// ou `null` se cancelar. A assinatura é dado sensível (LGPD) e vai junto com o envio da inspeção.
class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key, required this.signerName});

  final String signerName;

  /// Abre a tela de assinatura e devolve os bytes PNG.
  static Future<Uint8List?> show(BuildContext context, {required String signerName}) =>
      Navigator.of(context).push<Uint8List>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SignatureDialog(signerName: signerName)));

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final List<List<Offset>> _strokes = [];
  final _padKey = GlobalKey();

  Future<void> _confirm() async {
    final box = _padKey.currentContext!.findRenderObject() as RenderBox;
    final size = box.size;
    const scale = 2.0; // resolução 2x para a assinatura ficar nítida no relatório
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    _SignaturePainter(_strokes).paint(canvas, size);
    final image = await recorder.endRecording().toImage((size.width * scale).round(), (size.height * scale).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (mounted && data != null) Navigator.of(context).pop(data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura do inspetor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(IcSpacing.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Assine dentro do quadro com o dedo.', style: t.bodyLarge),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                key: _padKey,
                decoration: BoxDecoration(
                    color: IcColors.surface0,
                    borderRadius: BorderRadius.circular(IcRadius.md),
                    border: Border.all(color: IcColors.borderStrong, width: 2)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(IcRadius.md),
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                    onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
                    child: CustomPaint(painter: _SignaturePainter(_strokes), size: Size.infinite),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.signerName, style: t.bodySmall?.copyWith(color: IcColors.ink600)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, IcSpacing.touch)),
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _strokes.isEmpty ? null : _confirm,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, IcSpacing.touch)),
                  child: const Text('Confirmar assinatura'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = IcColors.borderSubtle
      ..strokeWidth = 1;
    canvas.drawLine(Offset(16, size.height * .72), Offset(size.width - 16, size.height * .72), guide);
    final ink = Paint()
      ..color = IcColors.ink900
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.5, ink..style = PaintingStyle.fill);
        ink.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
