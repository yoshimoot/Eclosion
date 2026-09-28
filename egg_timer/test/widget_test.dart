import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/main.dart';
import 'package:egg_timer/lab/fragment_scene.dart';

void main() {
  testWidgets('Lecture, pause et retour au début reproductibles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    FragmentScene scene() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<FragmentScene>()
        .single;
    expect(scene().progress, 0);
    await tester.tap(find.text('Lire'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(scene().progress, greaterThan(0));
    await tester.tap(find.text('Pause'));
    await tester.pump();
    final stopped = scene().progress;
    await tester.pump(const Duration(seconds: 1));
    expect(scene().progress, stopped);
    await tester.tap(find.text('Début'));
    await tester.pump();
    expect(scene().progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le rejeu atteint le sol sans erreur de peinture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Rejouer la chute'));
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Fragment au sol'), findsOneWidget);
  });

  testWidgets('Le ralenti traverse fissure, ouverture et chute', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Ralenti ×4'));
    await tester.pump();
    await tester.tap(find.text('Lire'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Propagation de la fissure'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Soulèvement du fragment'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Chute du fragment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La surface garde sa couleur au début du détachement', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 693));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    Future<List<int>> sample(double progress) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            painter: FragmentScene(
              progress: progress,
              thickness: 4,
              motion: 0,
              guides: false,
              showEgg: true,
              shadow: false,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final rgba = await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final offset = (265 * image.width + 240) * 4;
          return List<int>.generate(4, (i) => bytes!.getUint8(offset + i));
        } finally {
          image.dispose();
        }
      });
      return rgba!;
    }

    final attached = await sample(.45);
    final detaching = await sample(.45001);
    for (var channel = 0; channel < 3; channel++) {
      expect((attached[channel] - detaching[channel]).abs(), lessThan(12));
    }
  });
}
