import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_organic_fracture_plan.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:flutter_test/flutter_test.dart';

/// Graph connectivity, NOT count of free-flying shell pieces. The crown is
/// one cycle and every additional connection on this connected graph creates
/// another closed candidate path. The geometric split is a later stage.
int cycleRank(EggFractureNetwork graph) {
  final incident = List.generate(graph.nodes.length, (_) => <int>[]);
  for (final e in graph.edges) {
    incident[e.startNode].add(e.endNode);
    incident[e.endNode].add(e.startNode);
  }
  final visited = <int>{};
  var components = 0;
  for (var first = 0; first < graph.nodes.length; first++) {
    if (!visited.add(first)) continue;
    components++;
    final pending = [first];
    for (var head = 0; head < pending.length; head++) {
      for (final next in incident[pending[head]]) {
        if (visited.add(next)) pending.add(next);
      }
    }
  }
  return graph.edges.length - graph.nodes.length + components;
}

List<int> shortestExistingPath(
  EggFractureNetwork graph, int startNode, int endNode,
) {
  final pending = [startNode];
  final parents = <int, (int, int)>{};
  final visited = <int>{startNode};
  for (var head = 0; head < pending.length; head++) {
    final node = pending[head];
    if (node == endNode) break;
    for (final e in graph.edges) {
      if (e.startNode != node && e.endNode != node) continue;
      final next = e.startNode == node ? e.endNode : e.startNode;
      if (visited.add(next)) {
        parents[next] = (node, e.id);
        pending.add(next);
      }
    }
  }
  if (!visited.contains(endNode)) return [];
  final path = <int>[];
  var node = endNode;
  while (node != startNode) {
    final previous = parents[node]!;
    path.add(previous.$2);
    node = previous.$1;
  }
  return path.reversed.toList();
}

void main() {
  test('V11.33: organic draft preserves the validated original network', () {
    final source = EggFractureNetwork.fixed();
    final draft = EggFractureNetwork.organicStaticDraft();
    expect(source.seed, EggFractureNetwork.fixedSeed);
    expect(draft.seed, source.seed);
    expect(draft.nodes.length, source.nodes.length);
    expect(draft.edges.length, source.edges.length + 3);
    expect(cycleRank(source), 3); // Crown + the existing two regions.
    expect(cycleRank(draft), 6); // Three additional *candidate* cycles.
    expect(EggFragmentRegionPlan.fromNetwork(source).regions.length, 2);
    for (var i = 0; i < source.edges.length; i++) {
      // A separately built seed may not share object identity, but must
      // retain the very same edge IDs, node links, material samples, kinds.
      final old = source.edges[i], same = draft.edges[i];
      expect(same.id, old.id);
      expect(same.startNode, old.startNode);
      expect(same.endNode, old.endNode);
      expect(same.kind, old.kind);
      expect(same.samples.length, old.samples.length);
      for (var j = 0; j < old.samples.length; j++) {
        expect((same.samples[j] - old.samples[j]).length, lessThan(1e-12));
      }
    }
  });

  test('V11.33: three organic closures are local shared 3D boundaries', () {
    final source = EggFractureNetwork.fixed();
    final draft = EggFractureNetwork.organicStaticDraft();
    const closures = <(int, int)>[(41, 26), (43, 36), (45, 38)];
    for (var i = 0; i < closures.length; i++) {
      final (tip, mother) = closures[i];
      final edge = draft.edges[source.edges.length + i];
      expect(edge.id, source.edges.length + i);
      expect(edge.kind, EggCrackKind.connection);
      expect((edge.startNode, edge.endNode), (tip, mother));
      expect(shortestExistingPath(source, tip, mother).length, 3);
      expect(edge.samples.length, greaterThanOrEqualTo(4));
      expect((edge.samples.first - draft.nodes[tip].onShell(draft.model)).length,
          lessThan(1e-12));
      expect((edge.samples.last - draft.nodes[mother].onShell(draft.model)).length,
          lessThan(1e-12));
      for (final p in edge.samples) {
        final expected = draft.model.surfaceAt(p.x, p.y);
        expect((p - expected).length, lessThan(1e-8));
        expect(p.z, greaterThanOrEqualTo(0));
      }
    }
  });

  test('V11.33: closed organic region perimeters reuse graph topology', () {
    final plan = EggOrganicFracturePlan.fixed();
    expect(plan.candidates.map((candidate) => candidate.id), [
      'upper-left-small', 'lower-left-small', 'lower-right-small',
    ]);
    expect(plan.draft.edges.length, plan.original.edges.length + 3);

    for (var i = 0; i < plan.candidates.length; i++) {
      final region = plan.candidates[i];
      final rim = region.sampledPerimeter(plan.draft);
      expect(region.boundary.length, 4);
      expect(region.boundary.first.edgeId,
          plan.original.edges.length + i);
      expect(region.boundary.map((edge) => edge.edgeId).toSet().length, 4);
      expect((rim.first - rim.last).length, lessThan(1e-9));
      expect(rim.length, greaterThan(12));
      // A nonzero 2D projection permits the existing curved tessellator
      // to consume this boundary in a future isolated mesh-validation pass.
      var signedDoubleArea = 0.0;
      for (var j = 0; j < rim.length - 1; j++) {
        signedDoubleArea +=
            rim[j].x * rim[j + 1].y - rim[j + 1].x * rim[j].y;
      }
      expect(signedDoubleArea.abs(), greaterThan(1e-5));
      for (final vertex in rim) {
        expect(
          (vertex - plan.draft.model.surfaceAt(vertex.x, vertex.y)).length,
          lessThan(1e-8),
        );
      }
      // Every piece perimeter is a chain of ORIGINAL oriented
      // EggCrackEdge samples plus precisely one new material connection.
      for (final segment in region.boundary) {
        final original = plan.draft.edges[segment.edgeId].samples;
        final oriented = segment.samples(plan.draft);
        expect(oriented.length, original.length);
        final first = segment.forward ? original.first : original.last;
        expect(identical(oriented.first, first), isTrue);
      }
    }
  });

  test('V11.33: candidates build real 2.5-thick three-surface solids', () {
    final plan = EggOrganicFracturePlan.fixed();
    for (final region in plan.candidates) {
      final shell = EggShellPanelMeshBuilder.fromClosedPerimeter(
        model: plan.draft.model,
        regionId: region.id,
        closedPerimeter: region.sampledPerimeter(plan.draft),
      );
      expect(shell.regionId, region.id);
      expect(shell.thickness, 2.5);
      expect(shell.outer.length, shell.inner.length);
      expect(shell.outerTriangles, isNotEmpty);
      expect(shell.innerTriangles.length, shell.outerTriangles.length);
      expect(shell.sideTriangles.length, shell.rim.length * 2);
      for (var j = 0; j < shell.outer.length; j += 7) {
        final outer = shell.outer[j];
        final inner = shell.inner[j];
        expect((outer - inner).length, closeTo(2.5, 1e-7));
        expect(
          (outer - plan.draft.model.surfaceAt(outer.x, outer.y)).length,
          lessThan(1e-7),
        );
      }
      // This is a static candidate solid only, not an independent flying
      // fragment. It still overlaps the present parent-panel shell.
    }
  });

  test('V11.33: candidate links are reproducible without animation state', () {
    final a = EggFractureNetwork.organicStaticDraft();
    final b = EggFractureNetwork.organicStaticDraft();
    expect(a.edges.length, b.edges.length);
    for (var i = 0; i < a.edges.length; i++) {
      expect(a.edges[i].id, b.edges[i].id);
      for (var j = 0; j < a.edges[i].samples.length; j++) {
        expect((a.edges[i].samples[j] - b.edges[i].samples[j]).length,
            lessThan(1e-12));
      }
    }
  });
}
