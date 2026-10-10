import 'egg_organic_partitioned_meshes.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.44 — actual inner material surface and exposed upper-cut thickness
/// of the REMAINING organic front bowl. The two lateral silhouette seams
/// are left open for the existing rear shell, never closed by flat caps.
///
/// Triangle IDs reference [exterior, interior] in that exact order.
/// This is a separate static diagnostic structure, not a Flutter painter.
class EggOrganicFrontBowlShell {
  const EggOrganicFrontBowlShell._({
    required this.meshes,
    required this.thickness,
    required this.interior,
    required this.innerFaces,
    required this.upperCutRim,
    required this.upperCutWalls,
  });

  final EggOrganicPartitionedStaticMeshes meshes;
  final double thickness;
  final List<EggShellPoint3> interior;
  final List<EggShellTriangle> innerFaces;
  final List<int> upperCutRim;
  final List<EggShellTriangle> upperCutWalls;

  List<EggShellPoint3> get exterior => meshes.bowl.vertices;
  List<EggShellTriangle> get outerFaces => meshes.bowl.triangles;

  List<EggShellPoint3> get combinedVertices =>
      List<EggShellPoint3>.unmodifiable([...exterior, ...interior]);

  List<EggShellTriangle> get combinedFaces =>
      List<EggShellTriangle>.unmodifiable([
        ...outerFaces, ...innerFaces, ...upperCutWalls,
      ]);
}

class EggOrganicFrontBowlShellBuilder {
  const EggOrganicFrontBowlShellBuilder._();

  static bool _same(EggShellPoint3 a, EggShellPoint3 b) =>
      (a.x - b.x).abs() <= 1e-7 &&
      (a.y - b.y).abs() <= 1e-7 &&
      (a.z - b.z).abs() <= 1e-6;

  static bool _alongFirstSample(
    EggShellPoint3 point, EggShellPoint3 start, EggShellPoint3 next,
  ) {
    final dx = next.x - start.x, dy = next.y - start.y;
    final squared = dx * dx + dy * dy;
    if (squared <= 1e-14) {
      throw StateError('Degenerate organic F1 crown material sample');
    }
    final u = point.x - start.x, v = point.y - start.y;
    final t = (u * dx + v * dy) / squared;
    final cross = u * dy - v * dx;
    return t > 1e-9 && t <= 1 + 1e-7 && cross.abs() <= 1e-7;
  }

  static EggOrganicFrontBowlShell build(
    EggOrganicPartitionedStaticMeshes meshes, {
    double thickness = 2.5,
  }) {
    if (!thickness.isFinite || thickness <= 0 ||
        meshes.parents.any((p) => (p.thickness - thickness).abs() > 1e-8) ||
        meshes.children.any((p) => (p.thickness - thickness).abs() > 1e-8)) {
      throw ArgumentError('Organic shell faces must share exact thickness');
    }
    final graph = meshes.partition.organic.draft;
    final surface = meshes.bowl;
    final rim = surface.rim;
    final exterior = surface.vertices;
    final originalUpper = <EggShellPoint3>[];
    for (final step in meshes.partition.frontUpperBoundary) {
      final samples = step.samples(graph);
      originalUpper.addAll(
        originalUpper.isEmpty ? samples : samples.skip(1),
      );
    }
    if (originalUpper.length < 3 || rim.length < originalUpper.length) {
      throw StateError('Missing connected organic upper material rim');
    }
    final first = originalUpper.first;
    final next = originalUpper[1];
    final last = originalUpper.last;
    final candidates = <int>[
      for (var i = 0; i < rim.length; i++)
        if (_same(exterior[rim[i]], first)) i,
    ];
    if (candidates.length != 1) {
      throw StateError('Organic bowl has no unique left F1 rim contact');
    }
    final n = rim.length;
    final start = candidates.single;
    final ahead = exterior[rim[(start + 1) % n]];
    final behind = exterior[rim[(start - 1 + n) % n]];
    final aheadOnRim = _alongFirstSample(ahead, first, next);
    final behindOnRim = _alongFirstSample(behind, first, next);
    if (aheadOnRim == behindOnRim) {
      throw StateError('Cannot distinguish organic cut from silhouette');
    }
    final step = aheadOnRim ? 1 : -1;
    final upper = <int>[];
    var cursor = start;
    while (true) {
      upper.add(rim[cursor]);
      if (_same(exterior[rim[cursor]], last)) break;
      if (upper.length >= rim.length) {
        throw StateError('Organic cut never reaches right F1 crown');
      }
      cursor = (cursor + step + n) % n;
    }
    final subdivision = 1 << meshes.refinementPasses;
    if (upper.length != (originalUpper.length - 1) * subdivision + 1) {
      throw StateError('Organic bowl cut has a T-junction or subdivision gap');
    }
    for (var j = 0; j < originalUpper.length; j++) {
      if (!_same(exterior[upper[j * subdivision]], originalUpper[j])) {
        throw StateError('Organic material crack junction moved during meshing');
      }
    }
    final offset = exterior.length;
    final interior = List<EggShellPoint3>.unmodifiable([
      for (final p in exterior) graph.model.inset(p, thickness),
    ]);
    final innerFaces = List<EggShellTriangle>.unmodifiable([
      for (final t in surface.triangles)
        EggShellTriangle(t.a + offset, t.c + offset, t.b + offset),
    ]);
    final walls = <EggShellTriangle>[];
    for (var j = 0; j + 1 < upper.length; j++) {
      final a = step == 1 ? upper[j] : upper[j + 1];
      final b = step == 1 ? upper[j + 1] : upper[j];
      walls.add(EggShellTriangle(b, a, a + offset));
      walls.add(EggShellTriangle(b, a + offset, b + offset));
    }
    return EggOrganicFrontBowlShell._(
      meshes: meshes,
      thickness: thickness,
      interior: interior,
      innerFaces: innerFaces,
      upperCutRim: List<int>.unmodifiable(upper),
      upperCutWalls: List<EggShellTriangle>.unmodifiable(walls),
    );
  }
}
