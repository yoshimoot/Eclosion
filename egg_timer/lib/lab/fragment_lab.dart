import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'egg_shell_model.dart';
import 'egg_fracture_network.dart';

/// Active 3D shell laboratory. The legacy 2D FragmentScene is intentionally
/// not reachable from this UI; it remains in the repository for old tests.
class FragmentLab extends StatefulWidget {
  const FragmentLab({super.key});

  @override
  State<FragmentLab> createState() => _FragmentLabState();
}

class _FragmentLabState extends State<FragmentLab> {
  static const double _fragmentThickness = 2.5;
  bool _guides = true;
  static final EggFractureNetwork _staticCracks =
      EggFractureNetwork.fixed();

  static List<ShellCrackStroke> _strokesFor({required bool onCap}) =>
      List<ShellCrackStroke>.unmodifiable(
        _staticCracks.edges
            .where((edge) => edge.kind != EggCrackKind.crown)
            .where((edge) {
              final end = _staticCracks.nodes[edge.endNode];
              final belongsToCap =
                  end.y < _staticCracks.model.crownFractureY(end.angle);
              return belongsToCap == onCap;
            })
            .map((edge) => (
                  samples: edge.samples,
                  primary: edge.kind != EggCrackKind.secondary,
                )),
      );

  static final List<ShellCrackStroke> _fixedCracks =
      _strokesFor(onCap: false);
  static final List<ShellCrackStroke> _movingCracks =
      _strokesFor(onCap: true);
  bool _identifySurfaces = false;
  double _f1Open = .55;

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Atelier Éclosion',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Modèle 3D unique avec réseau de fissures permanent. '
        'L’ouverture F1 reste un diagnostic provisoire. '
        'Les autres fragments et le poussin ne sont pas encore intégrés.',
      ),
      const SizedBox(height: 20),
      Text(
        'Œuf 3D · fissures et ouverture F1',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Text('Ouverture F1 · ${(_f1Open * 100).round()} %'),
      Slider(
        value: _f1Open,
        min: 0,
        max: 1,
        onChanged: (value) => setState(() => _f1Open = value),
      ),
      const SizedBox(height: 12),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Repères de cadrage'),
        value: _guides,
        onChanged: (value) => setState(() => _guides = value ?? false),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Identifier les surfaces'),
        value: _identifySurfaces,
        onChanged: (value) =>
            setState(() => _identifySurfaces = value ?? false),
      ),
      if (_identifySurfaces)
        const Text(
          'F1 : extérieur vert · intérieur magenta · tranche orange. '
          'Bol : extérieur cyan · intérieur arrière bleu. '
          'Fond brun non couvert. Désactiver pour le rendu normal.',
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.copy),
        label: const Text('Copier les réglages'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await Clipboard.setData(
            ClipboardData(
              text: jsonEncode({
                'atelier': 'EggShellModel 3D avec fissures intégrées',
                'staticCracks': true,
                'seed': _staticCracks.seed,
                'showF1': true,
                'f1Opening': _f1Open,
                'thickness': _fragmentThickness,
                'guides': _guides,
                'identifySurfaces': _identifySurfaces,
                'portraitRatio': '9:16',
                'devicePixelRatio': MediaQuery.devicePixelRatioOf(context),
              }),
            ),
          );
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Réglages copiés')),
          );
        },
      ),
    ],
  );

  Widget _preview(double height) => SizedBox(
    height: height,
    child: Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            painter: EggShellF1PreviewPainter(
              guides: _guides,
              shadow: true,
              thickness: _fragmentThickness,
              openAmount: _f1Open,
              identifySurfaces: _identifySurfaces,
              fixedCracks: _fixedCracks,
              movingCracks: _movingCracks,
            ),
            child: const SizedBox.expand(),
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
