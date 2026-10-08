import 'egg_fracture_network.dart';
import 'egg_shell_model.dart';
import 'egg_stationary_bowl_shell.dart';

/// V11.7: exact 3D boundary of the missing stationary REAR bowl half.
///
/// The two sides come from the ACTUAL refined front-shell vertices. They
/// are not recalculated at an ideal meridian: curved-shell refinement can
/// shift intermediate vertices slightly away from z=0. Rebuilding them
/// independently would produce a visible seam or a non-manifold joint.
///
/// The upper rear crown comes directly from the 12 original F1 graph edges.
/// There is no rear triangulation, inner rear face, or rendered patch yet.
class EggRearBowlBoundary {
  const EggRearBowlBoundary._({
    required this.frontShell,
    required this.rightFrontIndices,
    required this.leftFrontIndices,
    required this.rearCrown,
    required this.closedPerimeter,
  });

  final EggStationaryBowlShell frontShell;

  /// Exact vertex IDs from the front mesh, starting at crown node 18 and
  /// ending at the shared bottom pole.
  final List<int> rightFrontIndices;

  /// Exact vertex IDs from the front mesh, starting at crown node 6 and
  /// ending at the SAME shared bottom pole.
  final List<int> leftFrontIndices;

  /// Crown node 18 -> node 6 around the back of F1, sampled directly from
  /// graph edges 18..23 and 0..5. Ends reuse exact front seam objects.
  final List<EggShellPoint3> rearCrown;

  /// One closed right->left rear crown, left->pole, pole->right perimeter.
  /// This describes the future rear outer surface; it is NOT a mesh yet.
  final List<EggShellPoint3> closedPerimeter;

  List<EggShellPoint3> get rightSide =>
      List<EggShellPoint3>.unmodifiable([
        for (final i in rightFrontIndices) frontShell.exterior[i],
      ]);

  List<EggShellPoint3> get leftSide =>
      List<EggShellPoint3>.unmodifiable([
        for (final i in leftFrontIndices) frontShell.exterior[i],
      ]);

  int get openFrontSideEdges =>
      rightFrontIndices.length + leftFrontIndices.length - 2;
}

class EggRearBowlBoundaryBuilder {
  const EggRearBowlBoundaryBuilder._();

  static bool _same(EggShellPoint3 a, EggShellPoint3 b) =>
      (a.x - b.x).abs() < 1e-7 &&
      (a.y - b.y).abs() < 1e-7 &&
      (a.z - b.z).abs() < 1e-6;

  static EggRearBowlBoundary build(EggStationaryBowlShell front) {
    final rim = front.assembly.bowl.surface.rim;
    final upper = front.upperRim;
    final vertices = front.exterior;
    final network = front.assembly.bowl.boundary.plan.network;
    if (upper.length < 2 || rim.length < upper.length + 3) {
      throw StateError('Invalid front shell material/silhouette boundary');
    }
    final rightPosition = rim.indexOf(upper.last);
    final leftPosition = rim.indexOf(upper.first);
    if (rightPosition < 0 || leftPosition < 0) {
      throw StateError('Missing original F1 contacts on the refined rim');
    }
    final n = rim.length;
    final previousInUpper = upper[upper.length - 2];
    final direction =
        rim[(rightPosition - 1 + n) % n] == previousInUpper
            ? 1
            : rim[(rightPosition + 1) % n] == previousInUpper
                ? -1
                : 0;
    if (direction == 0) {
      throw StateError('F1 upper rim is not contiguous with the silhouette');
    }

    // Traverse the rest of the SAME oriented front mesh rim, starting
    // from right F1 contact and ending at left F1 contact.
    final silhouette = <int>[];
    var cursor = rightPosition;
    while (true) {
      silhouette.add(rim[cursor]);
      if (cursor == leftPosition) break;
      if (silhouette.length > n) {
        throw StateError('Side seam is not one connected original rim arc');
      }
      cursor = (cursor + direction + n) % n;
    }
    if (silhouette.length - 1 != front.openSilhouetteEdgeCount) {
      throw StateError('Unexpected side silhouette edge count');
    }

    final halfHeight = network.model.halfHeight;
    final bottomCandidates = <int>[
      for (var i = 0; i < silhouette.length; i++)
        if ((vertices[silhouette[i]].y - halfHeight).abs() <= 1e-7 &&
            vertices[silhouette[i]].x.abs() <= 1e-7)
          i,
    ];
    if (bottomCandidates.length != 1) {
      throw StateError('The shell must have one shared bottom pole');
    }
    final bottom = bottomCandidates.single;
    if (bottom == 0 || bottom == silhouette.length - 1) {
      throw StateError('Bottom pole is not between the two silhouette sides');
    }

    final right = silhouette.sublist(0, bottom + 1);
    final left = silhouette.sublist(bottom).reversed.toList();
    if (right.length != left.length ||
        right.length + left.length - 2 != front.openSilhouetteEdgeCount ||
        right.last != left.last) {
      throw StateError('Front shell side edges do not share one bottom pole');
    }
    if (right.first != upper.last || left.first != upper.first) {
      throw StateError('Front shell crown endpoints have changed');
    }

    final crown = <EggShellPoint3>[vertices[right.first]];
    final rearEdgeIds = <int>[
      for (var i = 18; i < 24; i++) i,
      for (var i = 0; i < 6; i++) i,
    ];
    for (final edgeId in rearEdgeIds) {
      final edge = network.edges[edgeId];
      if (edge.kind != EggCrackKind.crown) {
        throw StateError('Only F1 original rear crown may close the bowl');
      }
      if (!_same(crown.last, edge.samples.first)) {
        throw StateError('Rear F1 crown edge $edgeId is discontinuous');
      }
      crown.addAll(edge.samples.skip(1));
    }
    if (!_same(crown.last, vertices[left.first])) {
      throw StateError('Back crown must meet front left F1 endpoint');
    }
    // Reuse the two original front objects, including at the wrap.
    crown[crown.length - 1] = vertices[left.first];

    final closed = <EggShellPoint3>[
      ...crown,
      for (final index in left.skip(1)) vertices[index],
      for (final index in right.reversed.skip(1)) vertices[index],
    ];
    if (!_same(closed.first, closed.last) ||
        !identical(closed.first, closed.last)) {
      throw StateError('The rear material perimeter does not close');
    }
    if (closed.length != crown.length + left.length + right.length - 2) {
      throw StateError('Unexpected duplicated rear perimeter vertices');
    }

    return EggRearBowlBoundary._(
      frontShell: front,
      rightFrontIndices: List<int>.unmodifiable(right),
      leftFrontIndices: List<int>.unmodifiable(left),
      rearCrown: List<EggShellPoint3>.unmodifiable(crown),
      closedPerimeter: List<EggShellPoint3>.unmodifiable(closed),
    );
  }
}
