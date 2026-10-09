import 'egg_rear_bowl_mesh.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';
import 'egg_stationary_bowl_shell.dart';

/// V11.9: a single indexed, closed material surface for the stationary bowl.
///
/// It welds the *existing* front and rear vertices along their physical
/// lateral seam; it does not add a side wall, redraw cuts or move fragments.
/// The material already has front/rear exterior, inward faces, and crown
/// thickness rims. IDs address [exterior, interior] in this combined mesh.
class EggFullBowlMesh {
  const EggFullBowlMesh._({
    required this.front,
    required this.rear,
    required this.outer,
    required this.inner,
    required this.outerFaces,
    required this.innerFaces,
    required this.cutWalls,
    required this.sharedSideVertexCount,
  });

  final EggStationaryBowlShell front;
  final EggRearBowlMesh rear;
  final List<EggShellPoint3> outer;
  final List<EggShellPoint3> inner;
  final List<EggShellTriangle> outerFaces;
  final List<EggShellTriangle> innerFaces;
  final List<EggShellTriangle> cutWalls;
  final int sharedSideVertexCount;

  int get vertexCount => outer.length * 2;
  int get triangleCount =>
      outerFaces.length + innerFaces.length + cutWalls.length;
  Iterable<EggShellTriangle> get allFaces sync* {
    yield* outerFaces;
    yield* innerFaces;
    yield* cutWalls;
  }
}

class EggFullBowlMeshBuilder {
  const EggFullBowlMeshBuilder._();

  static bool _same(EggShellPoint3 a, EggShellPoint3 b) =>
      (a.x - b.x).abs() < 1e-7 &&
      (a.y - b.y).abs() < 1e-7 &&
      (a.z - b.z).abs() < 1e-6;

  static EggFullBowlMesh build(
    EggStationaryBowlShell front,
    EggRearBowlMesh rear,
  ) {
    if (!identical(rear.boundary.frontShell, front)) {
      throw StateError('Front and rear must share one original shell');
    }
    if ((front.thickness - rear.thickness).abs() > 1e-8) {
      throw StateError('Mismatched thickness at the front/rear seam');
    }
    final f = front.exterior.length;
    final r = rear.exterior.length;
    if (front.interior.length != f || rear.interior.length != r) {
      throw StateError('Exterior and interior vertex counts disagree');
    }
    final seam = rear.boundary;
    final frontAt = Map<EggShellPoint3, int>.identity();
    final sideIds = <int>{
      ...seam.rightFrontIndices,
      ...seam.leftFrontIndices,
    };
    for (final i in sideIds) {
      if (i < 0 || i >= f || frontAt.containsKey(front.exterior[i])) {
        throw StateError('Duplicated or invalid seam vertex');
      }
      frontAt[front.exterior[i]] = i;
    }
    if (sideIds.length != front.openSilhouetteEdgeCount + 1) {
      throw StateError('Shared material seam has missing endpoints');
    }

    final outside = List<EggShellPoint3>.of(front.exterior);
    final inside = List<EggShellPoint3>.of(front.interior);
    final rearToWhole = List<int>.filled(r, -1);
    var welded = 0;
    for (var j = 0; j < r; j++) {
      final existing = frontAt[rear.exterior[j]];
      if (existing != null) {
        // Weld outside AND inward faces to the exact same material normal.
        if (!_same(front.interior[existing], rear.interior[j])) {
          throw StateError('Different inner seam normal on shared vertex');
        }
        rearToWhole[j] = existing;
        welded++;
      } else {
        rearToWhole[j] = outside.length;
        outside.add(rear.exterior[j]);
        inside.add(rear.interior[j]);
      }
    }
    if (welded != sideIds.length) {
      throw StateError('One of the lateral seam vertices did not weld');
    }

    final fullSize = outside.length;
    final externalFaces = <EggShellTriangle>[
      ...front.outerFaces,
      for (final t in rear.outerFaces)
        EggShellTriangle(
          rearToWhole[t.a], rearToWhole[t.b], rearToWhole[t.c],
        ),
    ];
    final internalFaces = <EggShellTriangle>[
      for (final t in front.innerFaces)
        EggShellTriangle(
          t.a - f + fullSize, t.b - f + fullSize, t.c - f + fullSize,
        ),
      for (final t in rear.innerFaces)
        EggShellTriangle(
          rearToWhole[t.a - r] + fullSize,
          rearToWhole[t.b - r] + fullSize,
          rearToWhole[t.c - r] + fullSize,
        ),
    ];
    int frontIndex(int value) =>
        value < f ? value : value - f + fullSize;
    int rearIndex(int value) =>
        value < r ? rearToWhole[value] :
            rearToWhole[value - r] + fullSize;
    final walls = <EggShellTriangle>[
      for (final t in front.upperCutWalls)
        EggShellTriangle(
          frontIndex(t.a), frontIndex(t.b), frontIndex(t.c),
        ),
      for (final t in rear.rearCrownWalls)
        EggShellTriangle(
          rearIndex(t.a), rearIndex(t.b), rearIndex(t.c),
        ),
    ];

    return EggFullBowlMesh._(
      front: front,
      rear: rear,
      outer: List<EggShellPoint3>.unmodifiable(outside),
      inner: List<EggShellPoint3>.unmodifiable(inside),
      outerFaces: List<EggShellTriangle>.unmodifiable(externalFaces),
      innerFaces: List<EggShellTriangle>.unmodifiable(internalFaces),
      cutWalls: List<EggShellTriangle>.unmodifiable(walls),
      sharedSideVertexCount: welded,
    );
  }
}
