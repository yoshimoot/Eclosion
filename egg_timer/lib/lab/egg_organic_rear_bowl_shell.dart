import 'egg_fracture_network.dart';
import 'egg_organic_front_bowl_shell.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Rear patch following the EXACT material seam of the newly refined
/// organic front, without creating artificial side caps or a screen mask.
/// The unchanged F1 rear crown remains the V11.8 12-edge material graph.
class EggOrganicRearBowlShell {
  const EggOrganicRearBowlShell._(
    this.front, this.rightSeam, this.leftSeam, this.rearCrown,
    this.closedPerimeter, this.exterior, this.interior,
    this.outerFaces, this.innerFaces, this.rearCrownWalls,
  );

  final EggOrganicFrontBowlShell front;
  final List<int> rightSeam, leftSeam;
  final List<EggShellPoint3> rearCrown, closedPerimeter;
  final List<EggShellPoint3> exterior, interior;
  final List<EggShellTriangle> outerFaces, innerFaces, rearCrownWalls;

  int get perimeterLength => closedPerimeter.length - 1;
  int get crownEdgeCount => rearCrown.length - 1;
  int get sideSeamEdgeCount => perimeterLength - crownEdgeCount;
}

class EggOrganicRearBowlShellBuilder {
  const EggOrganicRearBowlShellBuilder._();

  static bool _same(EggShellPoint3 a, EggShellPoint3 b) =>
      (a - b).length < 1e-6;

  static EggOrganicRearBowlShell build(
    EggOrganicFrontBowlShell front, {
    int interiorBands = 3,
    double centerY = 34,
  }) {
    if (interiorBands < 1 || interiorBands > 8) {
      throw ArgumentError.value(interiorBands, 'interiorBands');
    }
    final model = front.meshes.partition.organic.draft.model;
    if (!centerY.isFinite ||
        centerY <= -model.halfHeight ||
        centerY >= model.halfHeight) {
      throw ArgumentError.value(centerY, 'centerY');
    }
    final rim = front.meshes.bowl.rim;
    final upper = front.upperCutRim;
    final vertices = front.exterior;
    if (upper.length < 2 || rim.length < upper.length + 3) {
      throw StateError('Organic front has no separate lateral seam');
    }
    final rp = rim.indexOf(upper.last);
    final lp = rim.indexOf(upper.first);
    if (rp < 0 || lp < 0) {
      throw StateError('Missing organic F1 seam endpoints');
    }
    final n = rim.length;
    final beforeUpper = upper[upper.length - 2];
    final direction = rim[(rp - 1 + n) % n] == beforeUpper
        ? 1
        : rim[(rp + 1) % n] == beforeUpper
            ? -1
            : 0;
    if (direction == 0) {
      throw StateError('Organic upper rim and silhouette are disconnected');
    }
    final side = <int>[];
    var cursor = rp;
    while (true) {
      side.add(rim[cursor]);
      if (cursor == lp) break;
      if (side.length > n) throw StateError('Disconnected organic side');
      cursor = (cursor + direction + n) % n;
    }
    if (side.length + upper.length - 2 != rim.length) {
      throw StateError('Organic side seam overlaps the top cut');
    }
    final poles = <int>[
      for (var i = 0; i < side.length; i++)
        if ((vertices[side[i]].y - model.halfHeight).abs() <= 1e-7 &&
            vertices[side[i]].x.abs() <= 1e-7)
          i,
    ];
    if (poles.length != 1 ||
        poles.single == 0 ||
        poles.single == side.length - 1) {
      throw StateError('Organic front/rear needs a single shared pole');
    }
    final right = side.sublist(0, poles.single + 1);
    final left = side.sublist(poles.single).reversed.toList();
    if (right.length != left.length ||
        right.last != left.last ||
        right.first != upper.last ||
        left.first != upper.first) {
      throw StateError('Organic side rims differ in material subdivisions');
    }
    final graph = front.meshes.partition.organic.original;
    final crown = <EggShellPoint3>[vertices[right.first]];
    for (final id in <int>[
      for (var i = 18; i < 24; i++) i,
      for (var i = 0; i < 6; i++) i,
    ]) {
      final edge = graph.edges[id];
      if (edge.kind != EggCrackKind.crown ||
          !_same(crown.last, edge.samples.first)) {
        throw StateError('Original rear crown mismatch: edge $id');
      }
      crown.addAll(edge.samples.skip(1));
    }
    if (!_same(crown.last, vertices[left.first])) {
      throw StateError('Rear crown misses organic F1 join');
    }
    crown[crown.length - 1] = vertices[left.first];
    final closed = <EggShellPoint3>[
      ...crown,
      for (final id in left.skip(1)) vertices[id],
      for (final id in right.reversed.skip(1)) vertices[id],
    ];
    if (!identical(closed.first, closed.last) ||
        closed.length != crown.length + left.length + right.length - 2) {
      throw StateError('Organic rear material perimeter does not close');
    }
    final count = closed.length - 1;
    final shell = List<EggShellPoint3>.of(closed.take(count));
    final center = model.surfaceAt(0, centerY, back: true);
    // Use the validated V11.8 concentric rear bands, preserving every
    // boundary vertex from the NEW front mesh without resampling it.
    for (var layer = 1; layer <= interiorBands; layer++) {
      final t = layer / (interiorBands + 1);
      for (var i = 0; i < count; i++) {
        final p = shell[i];
        shell.add(model.surfaceAt(
          p.x * (1 - t), p.y + (centerY - p.y) * t, back: true,
        ));
      }
    }
    final centerIndex = shell.length;
    shell.add(center);
    final faces = <EggShellTriangle>[];
    for (var layer = 0; layer < interiorBands; layer++) {
      final a = layer * count, b = (layer + 1) * count;
      for (var i = 0; i < count; i++) {
        final j = (i + 1) % count;
        faces.add(EggShellTriangle(a + i, a + j, b + i));
        faces.add(EggShellTriangle(a + j, b + j, b + i));
      }
    }
    final base = interiorBands * count;
    for (var i = 0; i < count; i++) {
      faces.add(EggShellTriangle(
        base + i, base + (i + 1) % count, centerIndex,
      ));
    }
    final inside = List<EggShellPoint3>.unmodifiable([
      for (final point in shell) model.inset(point, front.thickness),
    ]);
    final offset = shell.length;
    final innerFaces = List<EggShellTriangle>.unmodifiable([
      for (final t in faces)
        EggShellTriangle(t.a + offset, t.c + offset, t.b + offset),
    ]);
    final walls = <EggShellTriangle>[];
    for (var i = 0; i + 1 < crown.length; i++) {
      walls.add(EggShellTriangle(i + 1, i, i + offset));
      walls.add(EggShellTriangle(i + 1, i + offset, i + 1 + offset));
    }
    return EggOrganicRearBowlShell._(
      front, List<int>.unmodifiable(right), List<int>.unmodifiable(left),
      List<EggShellPoint3>.unmodifiable(crown),
      List<EggShellPoint3>.unmodifiable(closed),
      List<EggShellPoint3>.unmodifiable(shell),
      inside, List<EggShellTriangle>.unmodifiable(faces),
      innerFaces, List<EggShellTriangle>.unmodifiable(walls),
    );
  }
}
