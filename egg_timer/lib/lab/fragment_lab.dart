import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fragment_scene.dart';

class FragmentLab extends StatefulWidget {
  const FragmentLab({super.key});

  @override
  State<FragmentLab> createState() => _FragmentLabState();
}

class _FragmentLabState extends State<FragmentLab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  static const double _fragmentThickness = 2.5;
  static const double _eggMotion = 1.5;
  bool _slow = false;
  bool _guides = true;
  bool _egg = true;
  bool _shadow = true;
  bool _tall = false;

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> change) => Column(
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
        Text('Atelier Éclosion', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Test de géométrie et de mouvement.\nDécor et matière provisoires ; aucun poussin à ce stade.'),
        const SizedBox(height: 20),
        Text(fragmentPhase(_time.value),
            style: Theme.of(context).textTheme.titleMedium),
        _slider('Progression du test · ${(_time.value * 100).round()} %',
            _time.value, 0, 1, (v) { _time.stop(); _time.value = v; }),
        Wrap(spacing: 8, runSpacing: 8, children: [
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
          OutlinedButton(onPressed: () => _time.forward(from: .55),
              child: const Text('Rejouer la chute')),
          OutlinedButton(onPressed: () { _time.reset(); setState(() {}); },
              child: const Text('Début')),
        ]),
        const SizedBox(height: 16),
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Ralenti ×4'), value: _slow,
          onChanged: (v) {
            final playing = _time.isAnimating;
            setState(() { _slow = v;
              _time.duration = Duration(seconds: v ? 24 : 6); });
            if (playing) _time.forward();
          }),
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Format 9:20 (sinon 9:16)'), value: _tall,
          onChanged: (v) => setState(() => _tall = v)),
        CheckboxListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Repères de cadrage'), value: _guides,
          onChanged: (v) => setState(() => _guides = v!)),
        CheckboxListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Afficher l’œuf'), value: _egg,
          onChanged: (v) => setState(() => _egg = v!)),
        CheckboxListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Afficher les ombres'), value: _shadow,
          onChanged: (v) => setState(() => _shadow = v!)),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copier les réglages'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text:
                'Éclosion fragment-v1 | progression=${_time.value.toStringAsFixed(3)}'
                ' | format=${_tall ? "9:20" : "9:16"} | ralenti=$_slow'));
            if (!mounted) return;
            messenger.showSnackBar(const SnackBar(content: Text('Réglages copiés')));
          },
        ),
      ],
    ),
  );

  Widget _preview(double height) => SizedBox(
    height: height,
    child: Center(child: AspectRatio(
      aspectRatio: _tall ? 9 / 20 : 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(animation: _time, builder: (context, child) =>
          CustomPaint(painter: FragmentScene(
            progress: _time.value,
            thickness: _fragmentThickness, motion: _eggMotion,
            guides: _guides, showEgg: _egg, shadow: _shadow,
          ), child: const SizedBox.expand())),
      ),
    )),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 850) {
        return Padding(padding: const EdgeInsets.all(24), child: Row(children: [
          Expanded(child: _preview(box.maxHeight - 48)),
          const SizedBox(width: 32),
          SizedBox(width: 350, child: SingleChildScrollView(child: _controls())),
        ]));
      }
      return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [
          _preview((box.maxHeight * .78).clamp(280.0, 760.0)),
          const SizedBox(height: 24), _controls(),
        ]));
    })),
  );
}
