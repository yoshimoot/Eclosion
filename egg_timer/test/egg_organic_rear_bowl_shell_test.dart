import 'dart:collection';

import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_organic_front_bowl_shell.dart';
import 'package:egg_timer/lab/egg_organic_partitioned_meshes.dart';
import 'package:egg_timer/lab/egg_organic_rear_bowl_shell.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_rear_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EggOrganicFrontBowlShell front;
  late EggOrganicRearBowlShell rear;
  setUpAll(() {
    front = EggOrganicFrontBowlShellBuilder.build(
      EggOrganicPartitionedStaticMeshes.build(),
    );
    rear = EggOrganicRearBowlShellBuilder.build(front);
  });

  test('V11.47: exact organic front/rear seam objects and pole', () {
    expect(rear.front, same(front));
    expect(rear.rightSeam.length, rear.leftSeam.length);
    final exterior = front.exterior;
    expect(rear.rightSeam.first, front.upperCutRim.last);
    expect(rear.leftSeam.first, front.upperCutRim.first);
    expect(rear.rightSeam.last, rear.leftSeam.last);
    expect(rear.sideSeamEdgeCount,
        front.meshes.bowl.rim.length - front.upperCutRim.length + 1);
    // Identity-based lookup is linear over the refined mesh and does
    // not repeatedly scan all vertices for each side-seam sample.
    final rearVertices = HashSet<EggShellPoint3>.identity()
      ..addAll(rear.exterior);
    for (final id in [...rear.rightSeam, ...rear.leftSeam]) {
      expect(rearVertices.contains(exterior[id]), isTrue,
          reason: 'The rear MUST reuse the organic front 3D sample');
    }
    expect(identical(rear.closedPerimeter.first,
        rear.closedPerimeter.last), isTrue);
    expect(identical(rear.rearCrown.first,
        exterior[rear.rightSeam.first]), isTrue);
    expect(identical(rear.rearCrown.last,
        exterior[rear.leftSeam.first]), isTrue);
    final pole = exterior[rear.rightSeam.last];
    expect((pole.y - front.meshes.partition.organic.original.model.halfHeight)
        .abs(), lessThan(1e-7));
    expect(pole.x.abs(), lessThan(1e-7));
  });

  test('V11.47: original rear crown is unchanged despite new front cuts', () {
    final network = EggFractureNetwork.fixed();
    final old = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(
        EggStationaryBowlShellBuilder.build(
          EggShellFrontAssemblyBuilder.build(
            EggFragmentRegionPlan.fromNetwork(network),
          ),
        ),
      ),
    );
    expect(rear.crownEdgeCount, 12 * 16);
    expect(rear.crownEdgeCount, old.crownEdgeCount);
    expect(rear.rearCrown.length, old.boundary.rearCrown.length);
    for (var i = 0; i < rear.rearCrown.length; i++) {
      expect((rear.rearCrown[i] - old.boundary.rearCrown[i]).length,
          lessThan(1e-7));
    }
  });

  test('V11.47: full curved rear has real two-sided 2.5 shell', () {
    expect(rear.exterior.length, rear.interior.length);
    expect(rear.outerFaces.length, rear.innerFaces.length);
    expect(rear.rearCrownWalls.length, rear.crownEdgeCount * 2);
    expect(rear.outerFaces, isNotEmpty);
    final frontThickness = front.thickness;
    expect(frontThickness, 2.5);
    for (var i = 0; i < rear.exterior.length; i += 13) {
      expect((rear.exterior[i] - rear.interior[i]).length,
          closeTo(frontThickness, 1e-7));
    }
    // The full material seam is the same along the inside also: normal
    // inset is evaluated from the SAME outer point on both halves.
    // Identity lookup is O(1) per seam point; do not scan the entire
    // refined rear vertex list once for EACH material contact.
    final rearIndices = HashMap<EggShellPoint3, int>.identity();
    for (var i = 0; i < rear.exterior.length; i++) {
      rearIndices[rear.exterior[i]] = i;
    }
    for (final id in [...rear.rightSeam, ...rear.leftSeam]) {
      final exterior = front.exterior[id];
      final frontInner = front.interior[id];
      final rearIndex = rearIndices[exterior];
      expect(rearIndex, isNotNull);
      expect((frontInner - rear.interior[rearIndex!]).length, lessThan(1e-7));
    }
    final vertexCount = rear.exterior.length * 2;
    for (final group in [
      rear.outerFaces, rear.innerFaces, rear.rearCrownWalls,
    ]) {
      for (final triangle in group) {
        expect(triangle.a >= 0 && triangle.a < vertexCount &&
            triangle.b >= 0 && triangle.b < vertexCount &&
            triangle.c >= 0 && triangle.c < vertexCount, isTrue);
      }
    }
  });

  test('V11.47: determinism and no invalid rear mesh settings', () {
    final again = EggOrganicRearBowlShellBuilder.build(front);
    expect(rear.closedPerimeter.length, again.closedPerimeter.length);
    expect(rear.outerFaces.length, again.outerFaces.length);
    for (var i = 0; i < rear.closedPerimeter.length; i++) {
      expect(identical(rear.closedPerimeter[i], again.closedPerimeter[i]),
          isTrue);
    }
    expect(() => EggOrganicRearBowlShellBuilder.build(
      front, interiorBands: 0,
    ), throwsArgumentError);
    expect(() => EggOrganicRearBowlShellBuilder.build(
      front, centerY: double.nan,
    ), throwsArgumentError);
  });
}
