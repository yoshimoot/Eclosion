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

enum EggCrackKind { crown, primary, secondary }

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

    // Organic front-facing branches. Each fork reuses its source node,
    // including the parent crown junction; no free-floating 2D strokes.
    final left = graph.chain(8, const [
      _CrackLocation(-79, -1.10),
      _CrackLocation(-49, -.91),
      _CrackLocation(-18, -.98),
      _CrackLocation(14, -.80),
    ]);
    graph.chain(left[2], const [
      _CrackLocation(-23, -1.23),
      _CrackLocation(-9, -1.34),
    ], kind: EggCrackKind.secondary);

    final middle = graph.chain(11, const [
      _CrackLocation(-81, -.18),
      _CrackLocation(-57, -.38),
      _CrackLocation(-27, -.27),
      _CrackLocation(7, -.42),
      _CrackLocation(34, -.30),
    ]);
    graph.chain(middle[2], const [
      _CrackLocation(-49, -.07),
      _CrackLocation(-31, .10),
    ], kind: EggCrackKind.secondary);

    final right = graph.chain(14, const [
      _CrackLocation(-83, .66),
      _CrackLocation(-59, .57),
      _CrackLocation(-29, .76),
      _CrackLocation(4, .57),
    ]);
    graph.chain(right[2], const [
      _CrackLocation(-48, .91),
      _CrackLocation(-34, 1.02),
    ], kind: EggCrackKind.secondary);

    graph.chain(17, const [
      _CrackLocation(-84, 1.40),
      _CrackLocation(-52, 1.21),
    ]);
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

  void edge(int from, int to, EggCrackKind kind) {
    final id = edges.length;
    final start = nodes[from];
    final end = nodes[to];
    final crown = kind == EggCrackKind.crown;
    final steps = crown ? 16 : 6;
    final points = <EggShellPoint3>[];
    final lastAngle = crown && to == 0 ? math.pi : end.angle;

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      var angle = start.angle + (lastAngle - start.angle) * t;
      var y = crown
          ? model.crownFractureY(angle)
          : start.y + (end.y - start.y) * t;
      if (!crown && i > 0 && i < steps) {
        // A reproducible small angular kink, never applied at junctions.
        final kink = (((id + 3) * 17 + i * 13) % 7 - 3) *
            math.sin(math.pi * t);
        angle += .007 * kink;
        y += .60 * kink;
      }
      points.add(model.pointAt(y, angle));
    }

    // Exact graph-node positions at each junction. Two connected edges
    // refer to the same 3D endpoint, not coincident-looking 2D patches.
    points[0] = start.onShell(model);
    points[steps] = end.onShell(model);
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
