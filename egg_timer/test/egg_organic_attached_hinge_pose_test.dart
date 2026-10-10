import 'dart:math' as math;

import 'package:egg_timer/lab/egg_organic_attachment_plan.dart';
import 'package:egg_timer/lab/egg_organic_attached_hinge_pose.dart';
import 'package:egg_timer/lab/egg_organic_partitioned_meshes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.36: three true material hinges keep physical anchors fixed', () {
    final partition = EggOrganicPartitionedStaticMeshes.build();
    final graph = partition.partition.organic.draft;
    final attachments = EggOrganicAttachmentPlan.fixed();
    expect(attachments.children.length, partition.children.length);

    for (var i = 0; i < partition.children.length; i++) {
      final child = attachments.children[i];
      final mesh = partition.children[i];
      final pose = EggOrganicAttachedHingePose.build(
        child: child, mesh: mesh, graph: graph,
      );
      expect(pose.hingeEdge.id, child.hinge.edgeId);
      expect(pose.openingStartProgress,
          lessThan(pose.releaseProgress));
      expect(pose.signedMaxRadians.abs(),
          closeTo(26 * math.pi / 180, 1e-12));

      final times = [
        0.0, .55, pose.openingStartProgress,
        (pose.openingStartProgress + pose.releaseProgress) / 2,
        pose.releaseProgress,
      ];
      for (final t in times) {
        expect((pose.transformAttached(pose.anchorA, t) -
                pose.anchorA).length, lessThan(1e-8));
        expect((pose.transformAttached(pose.anchorB, t) -
                pose.anchorB).length, lessThan(1e-8));
        final posed = pose.transformAllAttached(mesh.outer, t);
        for (var j = 0; j < mesh.outer.length; j += 31) {
          expect((posed[j] -
                  pose.transformAttached(mesh.outer[j], t)).length,
              lessThan(1e-9));
          final thickness = (pose.transformAttached(mesh.outer[j], t) -
              pose.transformAttached(mesh.inner[j], t)).length;
          expect(thickness, closeTo(mesh.thickness, 1e-8));
        }
        final a = mesh.outer[0], b = mesh.outer[mesh.outer.length ~/ 3];
        expect((pose.transformAttached(a, t) -
                pose.transformAttached(b, t)).length,
            closeTo((a - b).length, 1e-8),
            reason: 'The entire child must rotate as one rigid solid');
      }
      expect(pose.angleAt(pose.openingStartProgress), 0);
      expect(pose.angleAt(pose.releaseProgress),
          closeTo(pose.signedMaxRadians, 1e-10));
      expect(pose.angleAt(0), 0);
      final probe = mesh.outer[mesh.outer.length ~/ 2];
      expect((pose.releasePositionOf(probe) -
              pose.transformAttached(probe, pose.releaseProgress)).length,
          lessThan(1e-10));
      expect(() => pose.transformAttached(probe,
          math.min(1.0, pose.releaseProgress + .001)), throwsStateError);
    }
  });

  test('V11.36: open only after two side breaks, no popping on rewind',
      () {
    final partition = EggOrganicPartitionedStaticMeshes.build();
    final graph = partition.partition.organic.draft;
    final attachments = EggOrganicAttachmentPlan.fixed();

    for (var i = 0; i < partition.children.length; i++) {
      final pose = EggOrganicAttachedHingePose.build(
        child: attachments.children[i],
        mesh: partition.children[i],
        graph: graph,
      );
      final child = attachments.children[i];
      final start = pose.openingStartProgress;
      final end = pose.releaseProgress;
      expect(child.stateAt(start).intactCount, 1);
      expect(child.stateAt(start).hingeIntact, isTrue);
      expect(child.stateAt(end).fullyReleased, isTrue);

      final samples = [
        0.0, start, (start + end) / 2, end,
        (start + end) / 2, start, end, 0.0,
      ];
      for (final t in samples) {
        final old = pose.angleAt(t);
        expect(pose.angleAt(t), old);
        if (t <= start) expect(old, 0);
        if (t > start && t < end) {
          expect(old.abs(), inExclusiveRange(0, pose.signedMaxRadians.abs()));
        }
      }
      expect(() => pose.angleAt(-.01), throwsArgumentError);
      expect(() => pose.angleAt(double.nan), throwsArgumentError);
      expect(() => pose.angleAt(1.01), throwsArgumentError);
      expect(() => EggOrganicAttachedHingePose.build(
          child: child, mesh: partition.children[i], graph: graph,
          maximumOpeningDegrees: 60,
        ), throwsArgumentError);
    }
  });
}
