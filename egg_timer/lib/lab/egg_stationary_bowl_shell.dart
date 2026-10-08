import 'egg_shell_front_assembly.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// The inward face and physical upper-cut thickness of the stationary
/// FRONT bowl from V11.5. The lateral silhouette is deliberately OPEN:
/// closing it here would insert fake flat material at the front/rear join.
///
/// Indices in innerFaces and upperCutWalls address the combined vertex
/// sequence [exterior, interior]. This is diagnostic geometry only.
class EggStationaryBowlShell {
  const EggStationaryBowlShell._({
    required this.assembly,
    required this.thickness,
    required this.interior,
    required this.innerFaces,
    required this.upperRim,
    required this.upperCutWalls,
  });

  final EggShellFrontAssembly assembly;
  final double thickness;
  final List<EggShellPoint3> interior;
  final List<EggShellTriangle> innerFaces;

  /// Original upper rim of the stationary bowl: from F1 crown node 6
  /// through the shared 15-edge cut to crown node 18, including the three
  /// unchanged front-crown segments.
  final List<int> upperRim;

  /// Exactly two wall triangles per consecutive upper-rim vertex pair.
  /// The lower and side silhouette edges remain open for the rear shell.
  final List<EggShellTriangle> upperCutWalls;

  List<EggShellPoint3> get exterior => assembly.bowl.surface.vertices;
  List<EggShellTriangle> get outerFaces => assembly.bowl.surface.triangles;

  int get vertexCount => exterior.length + interior.length;

  int get openSilhouetteEdgeCount =>
      assembly.bowl.surface.rim.length - upperRim.length + 1;
}

/// V11.6: build the inner/front cut geometry without changing the already
/// verified exterior mesh, the original V10.4 cracks, or F1.
class EggStationaryBowlShellBuilder {
  const EggStationaryBowlShellBuilder._();

  static bool _same(EggShellPoint3 a, EggShellPoint3 b) =>
      (a.x - b.x).abs() <= 1e-7 &&
      (a.y - b.y).abs() <= 1e-7 &&
      (a.z - b.z).abs() <= 1e-6;

  static bool _alongFirstSample(
    EggShellPoint3 point,
    EggShellPoint3 start,
    EggShellPoint3 next,
  ) {
    final dx = next.x - start.x;
    final dy = next.y - start.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 1e-14) {
      throw StateError('Degenerate first F1 crown sample');
    }
    final ux = point.x - start.x;
    final uy = point.y - start.y;
    final t = (ux * dx + uy * dy) / lengthSquared;
    final cross = ux * dy - uy * dx;
    return t > 1e-9 && t <= 1 + 1e-7 &&
        cross.abs() <= 1e-7;
  }

  static EggStationaryBowlShell build(
    EggShellFrontAssembly assembly, {
    double thickness = 2.5,
  }) {
    if (!thickness.isFinite || thickness <= 0) {
      throw ArgumentError.value(thickness, 'thickness');
    }
    if (assembly.panels.any((p) => (p.thickness - thickness).abs() > 1e-8)) {
      throw StateError('Stationary bowl and panels must share thickness');
    }

    final boundary = assembly.bowl.boundary;
    final network = boundary.plan.network;
    final patch = assembly.bowl.surface;
    final rim = patch.rim;
    final exterior = patch.vertices;

    // Read the ORIGINAL material samples in graph order. At joins, two
    // edge objects may have identical coordinates but different identities.
    // The mesh itself supplies the refined intermediate positions.
    final originalTop = <EggShellPoint3>[];
    for (final segment in boundary.frontUpperBoundary) {
      final samples = segment.samples(network);
      originalTop.addAll(
        originalTop.isEmpty ? samples : samples.skip(1),
      );
    }
    if (originalTop.length < 3) {
      throw StateError('Missing physical bowl upper material boundary');
    }
    final first = originalTop.first;
    final next = originalTop[1];
    final last = originalTop.last;
    final startCandidates = <int>[
      for (var i = 0; i < rim.length; i++)
        if (_same(exterior[rim[i]], first)) i,
    ];
    if (startCandidates.length != 1) {
      throw StateError('Cannot identify a unique F1 left rim contact');
    }

    final firstIndex = startCandidates.single;
    final n = rim.length;
    final ahead = exterior[rim[(firstIndex + 1) % n]];
    final behind = exterior[rim[(firstIndex - 1 + n) % n]];
    final aheadOnUpper = _alongFirstSample(ahead, first, next);
    final behindOnUpper = _alongFirstSample(behind, first, next);
    if (aheadOnUpper == behindOnUpper) {
      throw StateError('Ambiguous upper/material versus side/silhouette rim');
    }

    final step = aheadOnUpper ? 1 : -1;
    final upper = <int>[];
    var cursor = firstIndex;
    while (true) {
      upper.add(rim[cursor]);
      if (_same(exterior[rim[cursor]], last)) {
        break;
      }
      if (upper.length >= rim.length) {
        throw StateError('The upper material rim never reaches crown node 18');
      }
      cursor = (cursor + step + n) % n;
    }

    // Each original graph subsegment is split into 2^passes segments.
    // Reject accidentally tracing the silhouette or missing crack samples.
    final subdivision = 1 << assembly.refinementPasses;
    final expected = (originalTop.length - 1) * subdivision + 1;
    if (upper.length != expected) {
      throw StateError('Upper rim has inconsistent shared subdivisions');
    }
    for (var i = 0; i < originalTop.length; i++) {
      if (!_same(exterior[upper[i * subdivision]], originalTop[i])) {
        throw StateError('A physical material junction moved during refinement');
      }
    }

    final offset = exterior.length;
    final inside = List<EggShellPoint3>.unmodifiable([
      for (final p in exterior) network.model.inset(p, thickness),
    ]);
    final innerFaces = List<EggShellTriangle>.unmodifiable([
      for (final t in patch.triangles)
        EggShellTriangle(t.a + offset, t.c + offset, t.b + offset),
    ]);

    // Follow the positive-winding original outer mesh, not the order of
    // the crack graph, to orient the wall consistently with its outer face.
    final walls = <EggShellTriangle>[];
    for (var i = 0; i + 1 < upper.length; i++) {
      final a = step == 1 ? upper[i] : upper[i + 1];
      final b = step == 1 ? upper[i + 1] : upper[i];
      walls.add(EggShellTriangle(b, a, a + offset));
      walls.add(EggShellTriangle(b, a + offset, b + offset));
    }

    return EggStationaryBowlShell._(
      assembly: assembly,
      thickness: thickness,
      interior: inside,
      innerFaces: innerFaces,
      upperRim: List<int>.unmodifiable(upper),
      upperCutWalls: List<EggShellTriangle>.unmodifiable(walls),
    );
  }
}
