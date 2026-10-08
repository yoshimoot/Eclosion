import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'fragment_scene.dart';
import 'fragment_playback.dart';

class FragmentLab extends StatefulWidget {
  const FragmentLab({super.key});

  @override
  State<FragmentLab> createState() => _FragmentLabState();
}

class _FragmentLabState extends State<FragmentLab>
    with SingleTickerProviderStateMixin {
  late final FragmentPlayback _time = FragmentPlayback(vsync: this);

  String _previewStage(double t) {
    final remaining = 1 - t;
    if (remaining > .75) return 'P1 · mouvements internes';
    if (remaining > .50) return 'P2 · bec : pression locale';
    if (remaining > .25) return 'P3 · tête/front : pression plus large';
    if (remaining > .05) return 'P4 · tête + haut du corps : ouverture';
    if (remaining > 1 / 60) return '5 % → 00:01 · ouverture finale';
    if (remaining > 0) return '00:01 → 00:00 · sortie';
    return '00:00 · éclosion';
  }
  static const double _fragmentThickness = 2.5;
  static const double _eggMotion = 1.5;
  bool _slow = false;
  bool _guides = true;
  bool _egg = true;
  bool _shadow = true;
  bool _tall = false;
  bool _identifySurfaces = false;
  FragmentPaintDiagnostics? _lastPaint;
  final _previewKey = GlobalKey();
  Offset? _probePoint;
  Map<String, Object>? _surfaceProbe;
  bool _probing = false;

  Future<void> _probeSurface(TapUpDetails tap) async {
    if (_probing) return;
    _time.stop();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    setState(() {
      _probing = true;
      _probePoint = null;
      _surfaceProbe = null;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_identifySurfaces) return;
      final painted = _lastPaint!;
      final probe = painted.probe;
      if (probe == null) return;
      final boundary =
          _previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (!mounted ||
            !_identifySurfaces ||
            !identical(_lastPaint, painted) ||
            bytes == null) {
          return;
        }
        final report = probe.rasterReport(
          bytes,
          image.width,
          image.height,
          ratio,
          tap.localPosition,
        );
        final trace = await probe.tracePixel(tap.localPosition, ratio);
        if (!mounted || !_identifySurfaces || !identical(_lastPaint, painted)) {
          return;
        }
        setState(() {
          _probePoint = tap.localPosition;
          _surfaceProbe = {
            'paintedProgress': painted.progress,
            'showEgg': _egg,
            'shadow': _shadow,
            'guides': _guides,
            'canvasWidth': painted.size.width,
            'canvasHeight': painted.size.height,
            ...report,
            ...trace,
          };
        });
      } finally {
        image.dispose();
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(value: value, min: min, max: max, onChanged: change),
    ],
  );

  Widget _controls() => AnimatedBuilder(
    animation: _time,
    builder: (context, child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atelier Éclosion',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Aperçu pression → fissures → fragments → détachement.\nDécor et poussin encore provisoires.',
        ),
        const SizedBox(height: 20),
        Text(
          _previewStage(_time.value),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'État mécanique interne : ${fragmentPhase(_time.value)}',
        ),
        _slider(
          'Progression de l’aperçu · ${(_time.value * 100).round()} %',
          _time.value,
          0,
          1,
          (v) {
            _time.stop();
            _time.value = v;
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () {
                if (_time.isAnimating) {
                  _time.stop();
                } else {
                  _time.forward(from: _time.value == 1 ? 0 : _time.value);
                }
                setState(() {});
              },
              child: Text(_time.isAnimating ? 'Pause' : 'Lire'),
            ),
            OutlinedButton(
              onPressed: () {
                _time.value = .75;
                setState(() {});
              },
              child: const Text('25 %'),
            ),
            OutlinedButton(
              onPressed: () {
                _time.value = .95;
                setState(() {});
              },
              child: const Text('5 %'),
            ),
            OutlinedButton(
              onPressed: () {
                _time.value = 59 / 60;
                setState(() {});
              },
              child: const Text('00:01'),
            ),
            OutlinedButton(
              onPressed: () {
                _time.reset();
                setState(() {});
              },
              child: const Text('Début'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ralenti ×4'),
          value: _slow,
          onChanged: (v) {
            setState(() {
              _slow = v;
              _time.slow = v;
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Format 9:20 (sinon 9:16)'),
          value: _tall,
          onChanged: (v) => setState(() => _tall = v),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repères de cadrage'),
          value: _guides,
          onChanged: (v) => setState(() => _guides = v!),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Afficher l’œuf'),
          value: _egg,
          onChanged: (v) => setState(() => _egg = v!),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Afficher les ombres'),
          value: _shadow,
          onChanged: (v) => setState(() => _shadow = v!),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copier les réglages'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(
              ClipboardData(
                text:
                    'Éclosion fragment-v1 | progression=${_time.value.toStringAsFixed(6)}'
                    ' | format=${_tall ? "9:20" : "9:16"} | ralenti=$_slow'
                    '\n${jsonEncode({...?_lastPaint?.toMap(), 'showEgg': _egg, 'shadow': _shadow, 'guides': _guides, 'identifySurfaces': _identifySurfaces, 'devicePixelRatio': MediaQuery.devicePixelRatioOf(context), if (_surfaceProbe != null) 'surfaceProbeCapture': _surfaceProbe})}',
              ),
            );
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Réglages copiés')),
            );
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Identifier les surfaces'),
          value: _identifySurfaces,
          onChanged: (value) => setState(() {
            _identifySurfaces = value!;
            _probePoint = null;
            _surfaceProbe = null;
          }),
        ),
        if (_identifySurfaces)
          const Text(
            'Diagnostic : coquille jaune · face extérieure cyan · '
            'face intérieure magenta · tranche mobile orange · '
            'lèvre fixe verte (2,5 selon la normale) · intérieur bleu · '
            'fond gris · ombres violettes.',
          ),
        if (_identifySurfaces) ...[
          const SizedBox(height: 8),
          Text(
            _probing ? 'Mesure de la surface…' : 'Cliquez dans la zone à analyser : lecture en pause, sonde et ROI de 16 × 16 px. Puis « Copier les réglages ».',
          ),
          if (_surfaceProbe case final report?)
            Text(
              'Sonde figée à ${(report['paintedProgress'] as double).toStringAsFixed(6)} : '
              'géométrie ${(report['point'] as Map)['expectedSurface']}, '
              'pixel ${(report['point'] as Map)['finalRenderedSurface']}. '
              'ROI mesurée : ${jsonEncode(report['renderedPercent'])} %.',
            ),
        ],
      ],
    ),
  );

  Widget _preview(double height) => SizedBox(
    height: height,
    child: Center(
      child: AspectRatio(
        aspectRatio: _tall ? 9 / 20 : 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: GestureDetector(
            onTapUp: _identifySurfaces ? _probeSurface : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  key: _previewKey,
                  child: AnimatedBuilder(
                    animation: _time,
                    builder: (context, child) => CustomPaint(
                      painter: FragmentScene(
                        progress: _time.value,
                        thickness: _fragmentThickness,
                        motion: _eggMotion,
                        guides: _guides,
                        showEgg: _egg,
                        shadow: _shadow,
                        identifySurfaces: _identifySurfaces,
                        onDiagnostics: (diagnostics) =>
                            _lastPaint = diagnostics,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                // Outside the captured boundary: the marker never contaminates
                // sampled pixels or the scene's normal rendering.
                if (_identifySurfaces && _probePoint != null)
                  AnimatedBuilder(
                    animation: _time,
                    builder: (context, child) =>
                        _surfaceProbe?['paintedProgress'] != _time.value
                        ? const SizedBox.shrink()
                        : Positioned(
                            left: _probePoint!.dx - 8,
                            top: _probePoint!.dy - 8,
                            width: 16,
                            height: 16,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 850) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(child: _preview(box.maxHeight - 48)),
                  const SizedBox(width: 32),
                  SizedBox(
                    width: 350,
                    child: SingleChildScrollView(child: _controls()),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _preview((box.maxHeight * .78).clamp(280.0, 760.0)),
                const SizedBox(height: 24),
                _controls(),
              ],
            ),
          );
        },
      ),
    ),
  );
}
