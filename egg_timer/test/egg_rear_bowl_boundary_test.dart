import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  late EggStationaryBowlShell front;
  late EggRearBowlBoundary rear;

  setUpAll(() {
    final assembly = EggShellFrontAssemblyBuilder.build(regions);
    front = EggStationaryBowlShellBuilder.build(assembly);
    rear = EggRearBowlBoundaryBuilder.build(front);
  });

  test('V11.7: both rear sides use the exact refined front vertices', () {
    final right = rear.rightSide;
    final left = rear.leftSide;
    expect(right.length, left.length);
    expect(right.length, greaterThan(64));
    expect(right.length + left.length - 2, front.openSilhouetteEdgeCount);
    expect(rear.openFrontSideEdges, front.openSilhouetteEdgeCount);
    for (var i = 0; i < right.length; i++) {
      expect(identical(right[i],
          front.exterior[rear.rightFrontIndices[i]]), isTrue);
      expect(identical(left[i],
          front.exterior[rear.leftFrontIndices[i]]), isTrue);
    }
    expect(rear.rightFrontIndices.first, front.upperRim.last);
    expect(rear.leftFrontIndices.first, front.upperRim.first);
    expect(rear.rightFrontIndices.last, rear.leftFrontIndices.last);
    expect(identical(right.last, left.last), isTrue);
    expect(right.last.y, closeTo(network.model.halfHeight, 1e-7));
  });

  test('V11.7: side seams follow exactly the original front rim edges', () {
    final rim = front.assembly.bowl.surface.rim;
    final observedEdges = <String>{};
    String key(int a, int b) =>
        a < b ? '$a:$b' : '$b:$a';
    final rimEdges = <String>{
      for (var i = 0; i < rim.length; i++)
        key(rim[i], rim[(i + 1) % rim.length]),
    };
    for (final indices in [
      rear.rightFrontIndices, rear.leftFrontIndices,
    ]) {
      for (var i = 0; i + 1 < indices.length; i++) {
        final segment = key(indices[i], indices[i + 1]);
        expect(rimEdges.contains(segment), isTrue);
        expect(observedEdges.add(segment), isTrue);
      }
    }
    expect(observedEdges.length, front.openSilhouetteEdgeCount);
    expect(front.upperRim.toSet().contains(rear.rightFrontIndices.last),
        isFalse);
  });

  test('V11.7: rear crown is the 12 original F1 edges, not a redraw', () {
    final crown = rear.rearCrown;
    expect(crown.length, 12 * 16 + 1);
    expect(identical(crown.first, rear.rightSide.first), isTrue);
    expect(identical(crown.last, rear.leftSide.first), isTrue);
    expect(identical(crown[1], network.edges[18].samples[1]), isTrue);
    expect(identical(crown[16], network.edges[18].samples.last), isTrue);
    expect(identical(crown[192 - 1], network.edges[5].samples[15]), isTrue);
    expect([
      for (var i = 18; i < 24; i++) network.edges[i].kind,
      for (var i = 0; i < 6; i++) network.edges[i].kind,
    ].every((kind) => kind == EggCrackKind.crown), isTrue);
  });

  test('V11.7: one closed 3D perimeter joins crown and both seams', () {
    final closed = rear.closedPerimeter;
    expect(identical(closed.first, closed.last), isTrue);
    expect(closed.length,
        rear.rearCrown.length + rear.leftSide.length +
            rear.rightSide.length - 2);
    expect(closed.every((p) =>
        p.x.isFinite && p.y.isFinite && p.z.isFinite), isTrue);
    expect(rear.rightSide.last.x, closeTo(0, 1e-7));
    expect(rear.rightSide.last.y,
        closeTo(network.model.halfHeight, 1e-7));
    expect(network.nodes.length, 50);
    expect(network.edges.length, 52);
  });

  test('V11.7: reproducible with minimum supported side resolution', () {
    final a = EggRearBowlBoundaryBuilder.build(
      EggStationaryBowlShellBuilder.build(
        EggShellFrontAssemblyBuilder.build(
          regions, sideSegments: 2,
        ),
      ),
    );
    expect(a.rightSide.length, rear.rightSide.length);
    expect(a.leftSide.length, rear.leftSide.length);
    expect(a.rearCrown.length, rear.rearCrown.length);
    for (var i = 0; i < a.closedPerimeter.length; i++) {
      final x = a.closedPerimeter[i], y = rear.closedPerimeter[i];
      expect(x.x, closeTo(y.x, 1e-7));
      expect(x.y, closeTo(y.y, 1e-7));
      expect(x.z, closeTo(y.z, 1e-6));
    }
  });
}
