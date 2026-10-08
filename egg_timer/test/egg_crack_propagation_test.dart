import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_crack_propagation.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';

void main() {
  test('V9: every material edge has one reproducible causal schedule', () {
    final network = EggFractureNetwork.fixed();
    final one = EggCrackPropagationPlan(network);
    final two = EggCrackPropagationPlan(EggFractureNetwork.fixed());
    expect(one.schedules.length, network.edges.length);
    expect(two.schedules.length, one.schedules.length);

    for (var id = 0; id < one.schedules.length; id++) {
      final a = one.schedules[id], b = two.schedules[id];
      expect(a.edgeId, id);
      expect(a.kind, network.edges[id].kind);
      expect(a.onset, b.onset);
      expect(a.completion, b.completion);
      expect(a.predecessorEdgeId, b.predecessorEdgeId);
      expect(a.preservedF1, b.preservedF1);
      if (!a.preservedF1) {
        expect(a.completion, greaterThan(a.onset));
        expect(a.onset, inInclusiveRange(0.0, 1.0));
        expect(a.completion, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  test('V9: original F1 and cap scratches are never retimed', () {
    final network = EggFractureNetwork.fixed();
    final plan = EggCrackPropagationPlan(network);
    final preserved = plan.schedules.where((e) => e.preservedF1).toList();

    expect(
      preserved.where((e) => e.kind == EggCrackKind.crown).length,
      24,
    );
    expect(
      preserved.where((e) => e.kind == EggCrackKind.secondary).length,
      4,
    );
    expect(preserved.length, 28);
    for (final t in [0.0, .1, .25, .5, .75, 1.0]) {
      for (final edge in preserved) {
        expect(edge.visibleFraction(t), 1.0);
      }
    }
    expect(
      plan.schedules.where((e) => !e.preservedF1).every(
        (e) => e.visibleFraction(0) == 0 &&
               e.visibleFraction(1) == 1,
      ),
      isTrue,
    );
  });

  test('V9: forks and late connections wait for their real parent edge', () {
    final plan = EggCrackPropagationPlan(EggFractureNetwork.fixed());
    var dependentBranches = 0;
    var lateConnections = 0;
    var mothers = 0;
    for (final edge in plan.schedules) {
      if (edge.preservedF1) continue;
      if (edge.predecessorEdgeId != null) {
        final parent = plan.schedules[edge.predecessorEdgeId!];
        expect(parent.completion, lessThanOrEqualTo(edge.onset));
        expect(
          plan.network.edges[parent.edgeId].endNode,
          plan.network.edges[edge.edgeId].startNode,
          reason: 'The triggering junction must be a shared 3D node',
        );
        if (edge.kind == EggCrackKind.secondary) dependentBranches++;
      }
      if (edge.kind == EggCrackKind.connection) {
        lateConnections++;
        expect(edge.onset, greaterThanOrEqualTo(.69));
      }
      if (edge.kind == EggCrackKind.primary) {
        mothers++;
        expect(edge.onset, lessThan(.70));
      }
    }
    expect(mothers, greaterThanOrEqualTo(12));
    expect(dependentBranches, greaterThanOrEqualTo(5));
    expect(lateConnections, 6);
  });

  test('V9: progress is smooth, monotone, reversible and clamp-safe', () {
    final plan = EggCrackPropagationPlan(EggFractureNetwork.fixed());
    final times = [0.0, .125, .25, .50, .70, .80, .90, 1.0];
    final frames = [for (final t in times) plan.visibleFractionsAt(t)];

    for (var id = 0; id < plan.schedules.length; id++) {
      for (var k = 1; k < frames.length; k++) {
        expect(frames[k][id], greaterThanOrEqualTo(frames[k - 1][id]));
        expect(frames[k][id], inInclusiveRange(0.0, 1.0));
      }
      final edge = plan.schedules[id];
      if (!edge.preservedF1) {
        final midpoint = (edge.onset + edge.completion) / 2;
        expect(edge.visibleFraction(midpoint), closeTo(.5, 1e-12));
        expect(edge.visibleFraction(edge.onset), 0);
        expect(edge.visibleFraction(edge.completion), 1);
      }
    }
    expect(plan.visibleFractionsAt(.5), plan.visibleFractionsAt(.5));
    expect(plan.visibleFractionsAt(-20), plan.visibleFractionsAt(0));
    expect(plan.visibleFractionsAt(20), plan.visibleFractionsAt(1));
    expect(
      () => plan.visibleFractionsAt(double.nan),
      throwsArgumentError,
    );
    expect(
      () => plan.visibleFractionsAt(double.infinity),
      throwsArgumentError,
    );
  });

  test('V9: building a timeline does not change shared 3D crack geometry', () {
    final network = EggFractureNetwork.fixed();
    final before = <List<double>>[
      for (final edge in network.edges)
        <double>[
          for (final p in edge.samples) ...<double>[p.x, p.y, p.z],
        ],
    ];
    final plan = EggCrackPropagationPlan(network);
    for (final t in [0.0, .12, .38, .78, 1.0]) {
      plan.visibleFractionsAt(t);
    }
    for (var i = 0; i < network.edges.length; i++) {
      final edge = network.edges[i];
      expect(edge.id, i);
      expect(edge.samples.length * 3, before[i].length);
      final after = <double>[
        for (final p in edge.samples) ...<double>[p.x, p.y, p.z],
      ];
      expect(after, before[i]);
    }
  });
}
