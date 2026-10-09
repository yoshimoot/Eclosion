import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_panel_inspection_pose.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  late EggShellPanelMesh panel;

  setUpAll(() {
    panel = EggShellFrontAssemblyBuilder.build(regions).panels.first;
  });

  test('V11.10: zero angle and no translation preserve all 3D points', () {
    final pose = EggPanelInspectionPose.forPanel(
      panel.outer, yawDegrees: 0,
    );
    final transformed = pose.transformAll(panel.outer);
    for (var i = 0; i < panel.outer.length; i++) {
      expect(transformed[i].x, closeTo(panel.outer[i].x, 1e-10));
      expect(transformed[i].y, closeTo(panel.outer[i].y, 1e-10));
      expect(transformed[i].z, closeTo(panel.outer[i].z, 1e-10));
    }
  });

  test('V11.10: rigid Y rotation preserves distances and 2.5 thickness', () {
    final pose = EggPanelInspectionPose.forPanel(
      panel.outer,
      yawDegrees: -48,
      shiftX: -18,
      shiftY: -9,
    );
    final outer = pose.transformAll(panel.outer);
    final inner = pose.transformAll(panel.inner);
    expect(outer.length, panel.outer.length);
    expect(inner.length, panel.inner.length);
    final stride = math.max(1, panel.outer.length ~/ 19);
    for (var i = 0; i < panel.outer.length; i += stride) {
      expect((outer[i] - inner[i]).length, closeTo(panel.thickness, 1e-8));
      final j = (i + stride) % panel.outer.length;
      expect((outer[i] - outer[j]).length,
          closeTo((panel.outer[i] - panel.outer[j]).length, 1e-8));
      final normal = network.model.normalAt(panel.outer[i]);
      expect(pose.rotateNormal(normal).length,
          closeTo(normal.length, 1e-10));
    }
  });

  test('V11.10: outline and side walls share the rotated rim', () {
    final pose = EggPanelInspectionPose.forPanel(
      panel.outer,
      yawDegrees: 42,
      shiftX: 18,
      shiftY: -13,
    );
    final exterior = pose.transformAll(panel.outer);
    final interior = pose.transformAll(panel.inner);
    final n = exterior.length;
    expect(panel.sideTriangles.length, panel.rim.length * 2);
    for (var i = 0; i < panel.rim.length; i++) {
      final a = panel.rim[i];
      final b = panel.rim[(i + 1) % panel.rim.length];
      final first = panel.sideTriangles[2 * i];
      final second = panel.sideTriangles[2 * i + 1];
      expect((first.a, first.b, first.c), (b, a, a + n));
      expect((second.a, second.b, second.c), (b, a + n, b + n));
      expect((exterior[a] - interior[a]).length,
          closeTo(panel.thickness, 1e-8));
    }
  });

  test('V11.10: extreme input cannot corrupt the inspection mesh', () {
    expect(
      () => EggPanelInspectionPose.forPanel(
        const <EggShellPoint3>[], yawDegrees: 20,
      ), throwsArgumentError,
    );
    expect(
      () => EggPanelInspectionPose.forPanel(
        panel.outer, yawDegrees: double.nan,
      ), throwsArgumentError,
    );
    expect(
      () => EggPanelInspectionPose.forPanel(
        panel.outer, yawDegrees: 80,
      ), throwsArgumentError,
    );
    expect(
      () => EggPanelInspectionPose.forPanel(
        panel.outer, yawDegrees: 20, shiftX: double.infinity,
      ), throwsArgumentError,
    );
  });
}
