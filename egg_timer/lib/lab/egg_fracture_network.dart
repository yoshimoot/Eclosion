import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'egg_shell_model.dart';

/// A named junction on the single EggShellModel surface.
class EggCrackNode {
  const EggCrackNode(this.id, this.y, this.angle);

  final int id;
  final double y;
  final double angle;

  EggShellPoint3 onShell(EggShellModel model) => model.pointAt(y, angle);
}

enum EggCrackKind { crown, primary, connection, secondary }

/// One shared material boundary. Adjacent regions are only assigned for the
/// crown: branch region ownership must wait for validated fragment topology.
class EggCrackEdge {
  const EggCrackEdge({
    required this.id,
    required this.startNode,
    required this.endNode,
    required this.kind,
    required this.samples,
    this.regionA,
    this.regionB,
  });

  final int id;
  final int startNode;
  final int endNode;
  final EggCrackKind kind;
  final List<EggShellPoint3> samples;
  final String? regionA;
  final String? regionB;
}

/// Immutable static draft of a shared-edge crack network.
///
/// The fixed seed is recorded for reproducibility; session-to-session
/// variation is deliberately deferred until this topology is approved.
/// Neither drawing nor animation regenerates nodes or edges each frame.
class EggFractureNetwork {
  EggFractureNetwork._(this.model, this.seed, this.nodes, this.edges);

  static const fixedSeed = 20261008;

  final EggShellModel model;
  final int seed;
  final List<EggCrackNode> nodes;
  final List<EggCrackEdge> edges;

  factory EggFractureNetwork.fixed({
    EggShellModel model = EggShellModel.reference,
  }) {
    final graph = _CrackGraphBuilder(model);
    const sections = 24;

    // A continuous 360-degree crown edge is the very same cut used by F1.
    // One edge object is shared by both future adjacent shell regions.
    for (var i = 0; i < sections; i++) {
      final angle = -math.pi + i * (2 * math.pi / sections);
      graph.node(model.crownFractureY(angle), angle);
    }
    for (var i = 0; i < sections; i++) {
      graph.edge(i, (i + 1) % sections, EggCrackKind.crown);
    }

    // V10.3: three descending fractures, two distinct lower junctions
    // and sparse lateral exits based on the user's annotated red drawing.
    // Material edges and junctions are always sampled on EggShellModel.
    // The unchanged F1 crown and cap scratches are deliberately excluded.
    final left = graph.chain(7, const [
      _CrackLocation(-90, -1.11),
      _CrackLocation(-62, -.99),
      _CrackLocation(-30, -.77),
      _CrackLocation(13, -.56),
    ]);
    final middle = graph.chain(11, const [
      _CrackLocation(-91, -.23),
      _CrackLocation(-55, -.12),
      _CrackLocation(10, .05),
      _CrackLocation(37, .15),
    ]);
    final right = graph.chain(16, const [
      _CrackLocation(-88, .97),
      _CrackLocation(-52, .81),
      _CrackLocation(-23, .68),
      _CrackLocation(-9, .66),
    ]);

    // Two low boundaries join DIFFERENT central mother nodes, avoiding
    // a four-way intersection and keeping real graph-edge provenance.
    final leftLower = graph.chain(left.last, const [
      _CrackLocation(26, -.41),
      _CrackLocation(28, -.16),
    ], kind: EggCrackKind.connection);
    graph.edge(leftLower.last, middle[2], EggCrackKind.connection);

    final rightLower = graph.chain(right.last, const [
      _CrackLocation(6, .54),
      _CrackLocation(23, .38),
    ], kind: EggCrackKind.connection);
    graph.edge(rightLower.last, middle[3], EggCrackKind.connection);

    // Three sparse exits remain on the FRONT shell surface near the
    // silhouette. They are NOT yet rear-surface material cuts or pieces.
    graph.chain(left[1], const [
      _CrackLocation(-35, -1.16),
      _CrackLocation(-12, -1.45),
    ], kind: EggCrackKind.secondary);
    graph.chain(left.last, const [
      _CrackLocation(32, -1.08),
      _CrackLocation(62, -1.47),
    ], kind: EggCrackKind.secondary);
    graph.chain(right.last, const [
      _CrackLocation(10, 1.03),
      _CrackLocation(44, 1.47),
    ], kind: EggCrackKind.secondary);

    // F1 cap scratches: both validated chains stay exactly unchanged.
    graph.chain(10, const [
      _CrackLocation(-142, -.57),
      _CrackLocation(-164, -.36),
    ], kind: EggCrackKind.secondary);
    graph.chain(13, const [
      _CrackLocation(-147, .29),
      _CrackLocation(-170, .16),
    ], kind: EggCrackKind.secondary);

    return EggFractureNetwork._(
      model,
      fixedSeed,
      List<EggCrackNode>.unmodifiable(graph.nodes),
      List<EggCrackEdge>.unmodifiable(graph.edges),
    );
  }
}

class _CrackLocation {
  const _CrackLocation(this.y, this.angle);

  final double y;
  final double angle;
}

class _CrackGraphBuilder {
  _CrackGraphBuilder(this.model);

  final EggShellModel model;
  final nodes = <EggCrackNode>[];
  final edges = <EggCrackEdge>[];

  int node(double y, double angle) {
    final id = nodes.length;
    nodes.add(EggCrackNode(id, y, angle));
    return id;
  }

  List<int> chain(
    int from,
    List<_CrackLocation> locations, {
    EggCrackKind kind = EggCrackKind.primary,
  }) {
    final result = <int>[];
    var previous = from;
    for (final position in locations) {
      final next = node(position.y, position.angle);
      edge(previous, next, kind);
      result.add(next);
      previous = next;
    }
    return result;
  }

  // Deterministic coordinates generated once per network (not per frame).
  static double _fixedSignedOffset(int edgeId, int step, int channel) {
    final basis =
        (edgeId + 11) * 379 + (step + 7) * 587 + (channel + 5) * 241;
    final hash = (basis * basis * 17 + basis * 19 + 97) % 65521;
    return 2 * hash / 65520 - 1;
  }

  void edge(int from, int to, EggCrackKind kind) {
    final id = edges.length;
    final start = nodes[from];
    final end = nodes[to];
    final crown = kind == EggCrackKind.crown;
    final startPoint = start.onShell(model);
    final endPoint = end.onShell(model);
    final dx = endPoint.x - startPoint.x;
    final dy = endPoint.y - startPoint.y;
    final span = math.sqrt(dx * dx + dy * dy);
    final points = <EggShellPoint3>[];
    final lastAngle = crown && to == 0 ? math.pi : end.angle;

    if (crown) {
      // F1's validated 360-degree seam remains exactly unchanged.
      const segments = 16;
      points.add(startPoint);
      for (var i = 1; i < segments; i++) {
        final angle =
            start.angle + (lastAngle - start.angle) * i / segments;
        points.add(model.pointAt(model.crownFractureY(angle), angle));
      }
      points.add(endPoint);
    } else {
      // Crack directions change at one to three meaningful corners, with
      // different lengths between them. Avoid independent jitter at every
      // sample, which previously produced a mechanical sawtooth pattern.
      // Connections have only one restrained corner per graph edge.
      // Other cracks keep the existing, more varied angularity.
      final bendCount = kind == EggCrackKind.connection
          ? 1
          : 1 + (((_fixedSignedOffset(id, 0, 4) + 1) * 1.5)
              .floor()
              .clamp(0, 2)).toInt();
      final corners = <EggShellPoint3>[startPoint];
      final amplitude = kind == EggCrackKind.connection
          ? (span * .065).clamp(1.4, 3.0).toDouble()
          : (span * .13).clamp(2.5, 5.5).toDouble();
      final lateralX = span > 1e-6 ? -dy / span : 0.0;
      final lateralY = span > 1e-6 ? dx / span : 0.0;

      for (var bend = 1; bend <= bendCount; bend++) {
        final t = (bend + _fixedSignedOffset(id, bend, 2) * .16) /
            (bendCount + 1);
        final value = _fixedSignedOffset(id, bend, 1);
        final direction = value < 0 ? -1.0 : 1.0;
        final kink = amplitude * (.6 + .4 * value.abs()) *
            direction * math.sin(math.pi * t);
        final y = startPoint.y + dy * t + lateralY * kink;
        final x = startPoint.x + dx * t + lateralX * kink;
        corners.add(model.surfaceAt(x, y));
      }
      corners.add(endPoint);

      // Subdivisions preserve the shared 3D surface but are collinear in
      // orthographic projection. Only the sparse corners introduce angles.
      final subdivisions = bendCount == 1 ? 3 : 2;
      points.add(startPoint);
      for (var segment = 0; segment < corners.length - 1; segment++) {
        final a = corners[segment];
        final b = corners[segment + 1];
        for (var step = 1; step <= subdivisions; step++) {
          if (segment == corners.length - 2 && step == subdivisions) {
            points.add(endPoint);
            continue;
          }
          final t = step / subdivisions;
          final y = a.y + (b.y - a.y) * t;
          final x = a.x + (b.x - a.x) * t;
          points.add(model.surfaceAt(x, y));
        }
      }
    }

    edges.add(EggCrackEdge(
      id: id,
      startNode: from,
      endNode: to,
      kind: kind,
      samples: List<EggShellPoint3>.unmodifiable(points),
      regionA: crown ? 'F1-crown' : null,
      regionB: crown ? 'fixed-bowl' : null,
    ));
  }
}

/// Static diagnostic visualization only. The lines are projected samples of
/// the real shared 3D edge graph; no fracture geometry is replaced or erased.
class EggCrackNetworkPainter extends CustomPainter {
  const EggCrackNetworkPainter({
    required this.network,
    this.guides = false,
  });

  final EggFractureNetwork network;
  final bool guides;

  @override
  void paint(Canvas canvas, Size size) {
    final model = network.model;
    EggShellModelPainter(
      model: model,
      guides: guides,
      shadow: true,
    ).paint(canvas, size);

    final scale = math.min(
      size.width * .76 / (2 * model.maxRadius),
      size.height * .80 / (2 * model.halfHeight),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height * .51);
    canvas.scale(scale);
    canvas.clipPath(model.silhouettePath());

    for (final edge in network.edges) {
      final path = Path();
      var drawing = false;
      for (final point in edge.samples) {
        // The intact shell hides its rear. In this orthographic projection,
        // only the camera-facing half of the common 3D surface is displayed.
        final visible = point.z > model.maxRadius * .002;
        if (!visible) {
          drawing = false;
          continue;
        }
        if (!drawing) {
          path.moveTo(point.x, point.y);
          drawing = true;
        } else {
          path.lineTo(point.x, point.y);
        }
      }
      final primary = edge.kind != EggCrackKind.secondary;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = primary ? .95 : .60
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = primary
              ? const Color(0xba704631)
              : const Color(0x93774e3a),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EggCrackNetworkPainter oldDelegate) =>
      oldDelegate.network != network || oldDelegate.guides != guides;
}
