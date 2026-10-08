import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'egg_shell_model.dart';

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
  bool _showF1 = true;
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
        'Validation du modèle 3D unifié : œuf intact ou chapeau F1. '
        'Les autres fragments et le poussin ne sont pas encore intégrés.',
      ),
      const SizedBox(height: 20),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Afficher F1 3D seul'),
        subtitle: const Text(
          'Désactivé : œuf 3D intact, sur la même surface géométrique.',
        ),
        value: _showF1,
        onChanged: (value) => setState(() => _showF1 = value),
      ),
      Text(
        _showF1 ? 'Modèle 3D unifié · F1 supérieur' : 'Modèle 3D unifié · œuf intact',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (_showF1) ...[
        const SizedBox(height: 12),
        Text('Ouverture F1 · ${(_f1Open * 100).round()} %'),
        Slider(
          value: _f1Open,
          min: 0,
          max: 1,
          onChanged: (value) => setState(() => _f1Open = value),
        ),
      ],
      const SizedBox(height: 12),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Repères de cadrage'),
        value: _guides,
        onChanged: (value) => setState(() => _guides = value ?? false),
      ),
      if (_showF1)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Identifier les surfaces'),
          value: _identifySurfaces,
          onChanged: (value) =>
              setState(() => _identifySurfaces = value ?? false),
        ),
      if (_showF1 && _identifySurfaces)
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
                'atelier': 'EggShellModel F1 unifié',
                'showF1': _showF1,
                'f1Opening': _f1Open,
                'thickness': _fragmentThickness,
                'guides': _guides,
                'identifySurfaces': _showF1 && _identifySurfaces,
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
            painter: _showF1
                ? EggShellF1PreviewPainter(
                    guides: _guides,
                    shadow: true,
                    thickness: _fragmentThickness,
                    openAmount: _f1Open,
                    identifySurfaces: _identifySurfaces,
                  )
                : EggShellModelPainter(
                    guides: _guides,
                    shadow: true,
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
