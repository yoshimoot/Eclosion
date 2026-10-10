import 'package:egg_timer/lab/egg_organic_attachment_plan.dart';
import 'package:egg_timer/lab/egg_organic_bowl_partition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.35: four physical attachments per child have two owners', () {
    final plan = EggOrganicAttachmentPlan.fixed();
    expect(plan.children.length, 3);
    expect(plan.propagationSpeed, greaterThan(0));
    final partition = plan.partition;
    final originalCutIds = partition.originalBowl.cutEdges
        .map((edge) => edge.edgeId).toSet();
    for (final child in plan.children) {
      expect(child.attachments.length, 4);
      final ids = child.attachments.map((a) => a.edgeId).toSet();
      expect(ids.length, 4);
      expect(child.attachments.where(
          (a) => a.kind == EggOrganicAttachmentKind.parentCrack).length, 1);
      expect(child.attachments.where(
          (a) => a.kind == EggOrganicAttachmentKind.bowlCrack).length, 2);
      expect(child.attachments.where(
          (a) => a.kind == EggOrganicAttachmentKind.hinge).length, 1);
      expect(child.parentId, anyOf('left', 'right'));
      expect(child.parentCrack.neighborId, child.parentId);
      expect(child.parentCrack.travelDistance, 0);
      expect(child.parentCrack.ruptureProgress,
          EggOrganicAttachmentPlan.parentReleaseProgress);
      expect(originalCutIds, contains(child.parentCrack.edgeId));
      for (final edge in child.attachments) {
        expect(edge.travelDistance.isFinite, isTrue);
        expect(edge.travelDistance, greaterThanOrEqualTo(0));
        expect(edge.ruptureProgress,
            inInclusiveRange(.55, 1.0));
        final owners = partition.edgeOwners[edge.edgeId]!;
        expect(owners, {child.childId, edge.neighborId});
        expect(edge.edgeId,
            inInclusiveRange(0, partition.organic.draft.edges.length - 1));
        expect(edge.kind == EggOrganicAttachmentKind.parentCrack,
            originalCutIds.contains(edge.edgeId));
      }
    }
  });

  test('V11.35: crack wave uses ONE velocity and keeps last hinge', () {
    final plan = EggOrganicAttachmentPlan.fixed();
    final childReleaseMoments = <double>[];
    for (final child in plan.children) {
      final side = child.attachments.where(
          (a) => a.kind == EggOrganicAttachmentKind.bowlCrack).toList()
        ..sort((a, b) => a.ruptureProgress.compareTo(b.ruptureProgress));
      expect(side.length, 2);
      for (final edge in side) {
        final expected = EggOrganicAttachmentPlan.parentReleaseProgress +
            edge.travelDistance / plan.propagationSpeed;
        expect(edge.ruptureProgress, closeTo(expected, 1e-12));
      }
      expect(side[0].ruptureProgress, lessThan(side[1].ruptureProgress));
      final hinge = child.hinge;
      expect(hinge.ruptureProgress,
          closeTo(EggOrganicAttachmentPlan.parentReleaseProgress +
              hinge.travelDistance / plan.propagationSpeed +
              EggOrganicAttachmentPlan.hingeLag, 1e-12));
      expect(hinge.ruptureProgress,
          greaterThan(side[1].ruptureProgress));
      childReleaseMoments.add(hinge.ruptureProgress);
      expect(child.stateAt(0).intactCount, 4);
      expect(child.stateAt(.54).intactCount, 4);
      expect(child.stateAt(.55).intactCount, 3);
      final halfway = (side[1].ruptureProgress +
          hinge.ruptureProgress) / 2;
      expect(child.stateAt(halfway).intactCount, 1);
      expect(child.stateAt(halfway).hingeIntact, isTrue);
      expect(child.stateAt(halfway).fullyReleased, isFalse);
      expect(child.stateAt(hinge.ruptureProgress).intactCount, 0);
      expect(child.stateAt(hinge.ruptureProgress).fullyReleased, isTrue);
      expect(child.stateAt(1).fullyReleased, isTrue);
    }
    // Distinct material lengths cause staggered release; this is not
    // three clones of the same hardcoded per-piece timer.
    expect(childReleaseMoments.toSet().length, greaterThan(1));
    expect(childReleaseMoments.every((t) => t > .55 && t <= .91 + 1e-9),
        isTrue);
  });

  test('V11.35: state queries rewind deterministically and never accumulate',
      () {
    final plan = EggOrganicAttachmentPlan.fixed();
    final independent = EggOrganicAttachmentPlan.fixed();
    final times = [0.0, .55, .82, .96, .68, 1.0, .30, .82, 0.0];
    for (var i = 0; i < plan.children.length; i++) {
      final a = plan.children[i], b = independent.children[i];
      expect(a.childId, b.childId);
      expect(a.parentId, b.parentId);
      expect(a.attachments.map((e) => e.edgeId),
          b.attachments.map((e) => e.edgeId));
      for (final progress in times) {
        final current = a.stateAt(progress);
        final repeat = b.stateAt(progress);
        expect(current.intactEdgeIds, repeat.intactEdgeIds);
        expect(current.hingeIntact, repeat.hingeIntact);
        expect(current.fullyReleased, repeat.fullyReleased);
      }
      expect(a.stateAt(0).intactCount, 4);
      expect(a.stateAt(1).intactCount, 0);
      expect(() => a.stateAt(-.01), throwsArgumentError);
      expect(() => a.stateAt(1.01), throwsArgumentError);
      expect(() => a.stateAt(double.nan), throwsArgumentError);
      expect(() => a.stateAt(double.infinity), throwsArgumentError);
    }
  });

  test('V11.35: physical parent-to-child sequence uses partition data', () {
    final partition = EggOrganicBowlPartition.fixed();
    final plan = EggOrganicAttachmentPlan.fixed();
    for (var i = 0; i < plan.children.length; i++) {
      final candidate = partition.organic.candidates[i];
      final child = plan.children[i];
      expect(child.childId, candidate.id);
      expect(child.attachments.map((a) => a.edgeId).toSet(),
          candidate.boundary.map((e) => e.edgeId).toSet());
      for (final edge in child.attachments) {
        final original = partition.organic.draft.edges[edge.edgeId];
        final inPlan = plan.partition.organic.draft.edges[edge.edgeId];
        expect(original.id, inPlan.id);
        expect(original.samples.length, inPlan.samples.length);
        expect(original.startNode, inPlan.startNode);
        expect(original.endNode, inPlan.endNode);
      }
    }
  });
}
