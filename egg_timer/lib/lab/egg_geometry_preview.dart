import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'egg_fragment_regions.dart';
import 'egg_panel_inspection_pose.dart';
import 'egg_panel_hinge_pose.dart';
import 'egg_fracture_network.dart';
import 'egg_rear_bowl_boundary.dart';
import 'egg_rear_bowl_mesh.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_front_assembly.dart';
import 'egg_shell_model.dart';
import 'egg_stationary_bowl_shell.dart';

/// Separate, read-only Chrome diagnostic of the actual V11.8 shell meshes.
/// The validated F1 painter and all motion mechanics remain untouched.
class EggGeometryPreview extends StatefulWidget {
  const EggGeometryPreview({super.key});

  @override
  State<EggGeometryPreview> createState() => _EggGeometryPreviewState();
}

class _EggGeometryPreviewState extends State<EggGeometryPreview> {
  late final EggShellFrontAssembly _assembly;
  late final EggFragmentRegionPlan _regions;
  late final EggStationaryBowlShell _front;
  late final EggRearBowlMesh _rear;
  late final EggShellModel _model;
  int _mode = 0; // 0: assembled, 1: free inspection, 2: attached hinge
  double _hingeDegrees = 20;
  bool _left = true;
  bool _right = true;
  bool _inside = true;
  bool _outlines = true;
  double _inspectionYaw = 42;

  @override
  void initState() {
    super.initState();
    final network = EggFractureNetwork.fixed();
    _model = network.model;
    _regions = EggFragmentRegionPlan.fromNetwork(network);
    _assembly = EggShellFrontAssemblyBuilder.build(_regions);
    _front = EggStationaryBowlShellBuilder.build(_assembly);
    _rear = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(_front),
    );
  }

  Widget _viewer(double height) => SizedBox(
    height: height,
    child: Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _ShellMeshPainter(
              model: _model,
              front: _front,
              rear: _rear,
              panels: _assembly.panels,
              mode: _mode,
              regions: _regions,
              hingeDegrees: _hingeDegrees,
              leftPanel: _left,
              rightPanel: _right,
              showInside: _inside,
              outlines: _outlines,
              inspectionYaw: _inspectionYaw,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Géométrie V11.8',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Aperçu statique des vrais maillages du bol avant, '
          'de la coquille arrière et des deux panneaux. '
          'Le chapeau F1 n’est pas encore inclus dans cet assemblage.'),
      const SizedBox(height: 20),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Assemblé')),
          ButtonSegment(value: 1, label: Text('Écarté')),
          ButtonSegment(value: 2, label: Text('Pivot')),
        ],
        selected: {_mode},
        onSelectionChanged: (values) =>
            setState(() => _mode = values.first),
      ),
      const SizedBox(height: 8),
      Text(_mode == 2
          ? 'Pivot : deux points d’une courte arête existante restent '
              'fixes. Aucun mouvement libre ni rupture automatique.'
          : 'Écarté = décalage de présentation, '
              'pas une animation physique validée.',
          style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 14),
      Text('Inclinaison 3D des panneaux · ${_inspectionYaw.round()}°'),
      Slider(
        value: _inspectionYaw,
        min: 0,
        max: 70,
        divisions: 14,
        onChanged: _mode == 1
            ? (value) => setState(() => _inspectionYaw = value)
            : null,
      ),
      const Text('Inspection uniquement en mode Écarté : rotation rigide '
          'des faces et des tranches autour d’un axe vertical.',
          style: TextStyle(fontSize: 12)),
      const SizedBox(height: 12),
      Text('Ouverture autour de l’attache · ${_hingeDegrees.round()}°'),
      Slider(
        value: _hingeDegrees,
        min: 0,
        max: 55,
        divisions: 11,
        onChanged: _mode == 2
            ? (value) => setState(() => _hingeDegrees = value)
            : null,
      ),
      const Text('V11.12 : charnière sur une connexion inférieure '
          'issue des fissures V10.4. La géométrie tourne d’un seul '
          'bloc ; expulsion et chute non intégrées.',
          style: TextStyle(fontSize: 12)),
      const SizedBox(height: 14),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Panneau gauche'),
        value: _left,
        onChanged: (value) => setState(() => _left = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Panneau droit'),
        value: _right,
        onChanged: (value) => setState(() => _right = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Face intérieure arrière'),
        value: _inside,
        onChanged: (value) => setState(() => _inside = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Contours matériels'),
        value: _outlines,
        onChanged: (value) => setState(() => _outlines = value),
      ),
      const SizedBox(height: 8),
      Text('Épaisseur 2,5 · raffinement commun '
          '${_assembly.refinementPasses}',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      const Text('Vue orthographique à occultation 3D. '
          'Couleurs et déplacements uniquement diagnostiques ; '
          'sans poussin, chapeau mobile ni minuteur.',
          style: TextStyle(fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Éclosion · maillages 3D')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 850) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Expanded(child: _viewer(box.maxHeight - 36)),
                const SizedBox(width: 24),
                SizedBox(width: 340,
                    child: SingleChildScrollView(child: _controls())),
              ]),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _viewer((box.maxHeight * .68).clamp(270.0, 720.0)),
              const SizedBox(height: 16),
              _controls(),
            ]),
          );
        },
      ),
    ),
  );
}

/// A 3D mesh in a temporary diagnostic position (no model mutation).
class _Surface {
  _Surface(this.points, this.faces, this.color,
      {this.offset = Offset.zero, this.inside = false, this.rim,
      this.originalPoints, this.pose, this.hingePose});

  final List<EggShellPoint3> points;
  final List<EggShellTriangle> faces;
  final Color color;
  final Offset offset;
  final bool inside;
  final List<int>? rim;
  final List<EggShellPoint3>? originalPoints;
  final EggPanelInspectionPose? pose;
  final EggPanelHingePose? hingePose;
  late final List<Offset> xy = [
    for (final p in points) Offset(p.x + offset.dx, p.y + offset.dy),
  ];
  late final List<int> indices = [
    for (final t in faces) ...[t.a, t.b, t.c],
  ];
}

/// Resolve 3D depth at every model-pixel centre, then clip the original
/// curved shaded triangle meshes to their visible ownership pixels.
/// This avoids claiming a simple group draw-order is a depth test.
class _ShellMeshPainter extends CustomPainter {
  const _ShellMeshPainter({
    required this.model,
    required this.front,
    required this.rear,
    required this.panels,
    required this.mode,
    required this.regions,
    required this.hingeDegrees,
    required this.leftPanel,
    required this.rightPanel,
    required this.showInside,
    required this.outlines,
    required this.inspectionYaw,
  });

  final EggShellModel model;
  final EggStationaryBowlShell front;
  final EggRearBowlMesh rear;
  final List<EggShellPanelMesh> panels;
  final int mode;
  final EggFragmentRegionPlan regions;
  final double hingeDegrees;
  final bool leftPanel;
  final bool rightPanel;
  final bool showInside;
  final bool outlines;
  final double inspectionYaw;

  List<_Surface> _meshes() {
    final result = <_Surface>[];
    if (showInside) {
      final offset = rear.exterior.length;
      result.add(_Surface(
        rear.interior,
        [for (final t in rear.innerFaces)
          EggShellTriangle(t.a - offset, t.b - offset, t.c - offset)],
        const Color(0xffd1a887),
        inside: true,
      ));
    } else {
      result.add(_Surface(rear.exterior, rear.outerFaces,
          const Color(0xffc1987b)));
    }
    result.add(_Surface(
      [...rear.exterior, ...rear.interior],
      rear.rearCrownWalls, const Color(0xffa87351), inside: true,
    ));
    result.add(_Surface(front.exterior, front.outerFaces,
        const Color(0xfff3d4a6),
        rim: front.assembly.bowl.surface.rim));
    result.add(_Surface(
      [...front.exterior, ...front.interior],
      front.upperCutWalls, const Color(0xffae7753), inside: true,
    ));
    for (var i = 0; i < panels.length; i++) {
      if ((i == 0 && !leftPanel) || (i == 1 && !rightPanel)) continue;
      final panel = panels[i];
      // Pure diagnostic rigid rotation: apply the SAME 3D pose to
      // exterior, inner face and thickness walls, never to the source mesh.
      // At rest retain the exact original objects and drawing behavior.
      final pose = mode == 1
          ? EggPanelInspectionPose.forPanel(
              panel.outer,
              yawDegrees: i == 0 ? -inspectionYaw : inspectionYaw,
              shiftX: i == 0 ? -18 : 18,
              shiftY: i == 0 ? -9 : -13,
            )
          : null;
      final hinge = mode == 2
          ? EggPanelHingePose.fromGraph(
              panel: panel,
              region: regions.regions[i],
              neighbor: regions.regions[1 - i],
              network: regions.network,
              openingDegrees: hingeDegrees,
            )
          : null;
      final exterior = hinge?.transformAll(panel.outer) ??
          pose?.transformAll(panel.outer) ?? panel.outer;
      final interior = hinge?.transformAll(panel.inner) ??
          pose?.transformAll(panel.inner) ?? panel.inner;
      result.add(_Surface(
        exterior, panel.outerTriangles,
        i == 0 ? const Color(0xffffe0b4) : const Color(0xfffbd09a),
        rim: panel.rim, originalPoints: panel.outer,
        pose: pose, hingePose: hinge,
      ));
      result.add(_Surface(
        [...exterior, ...interior],
        panel.sideTriangles, const Color(0xffa67857),
        inside: true,
        originalPoints: [...panel.outer, ...panel.inner],
        pose: pose, hingePose: hinge,
      ));
      if (mode != 0) {
        final offset = panel.outer.length;
        result.add(_Surface(interior, [
          for (final t in panel.innerTriangles)
            EggShellTriangle(t.a - offset, t.b - offset, t.c - offset),
        ], const Color(0xffd9b18e),
          inside: true, originalPoints: panel.inner,
          pose: pose, hingePose: hinge,
        ));
      }
    }
    return result;
  }

  Color _shade(EggShellPoint3 point, Color base, bool inside,
      {EggShellPoint3? original, EggPanelInspectionPose? pose,
      EggPanelHingePose? hingePose}) {
    final localNormal = model.normalAt(original ?? point);
    final n = hingePose?.rotateNormal(localNormal) ??
        pose?.rotateNormal(localNormal) ?? localNormal;
    final directional = (n.x * -.43 + n.y * -.39 + n.z * .78) *
        (inside ? -1 : 1);
    final weight = (.71 + .22 * directional).clamp(.30, 1.0).toDouble();
    return Color.lerp(const Color(0xff745039), base, weight)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xff665647), Color(0xffbea286)],
      ).createShader(Offset.zero & size),
    );
    final scale = math.min(
      size.width * .82 / (2 * model.maxRadius),
      size.height * .78 / (2 * model.halfHeight),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height * .52);
    canvas.scale(scale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, model.halfHeight + 8),
          width: model.maxRadius * 1.4, height: 16),
      Paint()
        ..color = const Color(0x55412b20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    final meshes = _meshes();
    const left = -170, top = -157, width = 340, height = 386;
    final depth = Float32List(width * height)
      ..fillRange(0, width * height, double.negativeInfinity);
    final owner = Uint8List(width * height);
    for (var id = 0; id < meshes.length; id++) {
      final mesh = meshes[id];
      final xy = mesh.xy;
      for (final t in mesh.faces) {
        final a = xy[t.a], b = xy[t.b], c = xy[t.c];
        final area = (b.dx - a.dx) * (c.dy - a.dy) -
            (b.dy - a.dy) * (c.dx - a.dx);
        if (area.abs() < 1e-9) continue;
        final x0 = (math.min(a.dx, math.min(b.dx, c.dx)) - left - .5)
            .ceil().clamp(0, width - 1).toInt();
        final x1 = (math.max(a.dx, math.max(b.dx, c.dx)) - left - .5)
            .floor().clamp(0, width - 1).toInt();
        final y0 = (math.min(a.dy, math.min(b.dy, c.dy)) - top - .5)
            .ceil().clamp(0, height - 1).toInt();
        final y1 = (math.max(a.dy, math.max(b.dy, c.dy)) - top - .5)
            .floor().clamp(0, height - 1).toInt();
        if (x0 > x1 || y0 > y1) continue;
        final inv = 1 / area;
        final da = (b.dy - c.dy) * inv;
        final db = (c.dy - a.dy) * inv;
        for (var y = y0; y <= y1; y++) {
          final py = top + y + .5;
          final px = left + x0 + .5;
          var u = ((b.dy - c.dy) * (px - c.dx) +
              (c.dx - b.dx) * (py - c.dy)) * inv;
          var v = ((c.dy - a.dy) * (px - c.dx) +
              (a.dx - c.dx) * (py - c.dy)) * inv;
          for (var x = x0; x <= x1; x++) {
            final w = 1 - u - v;
            if (u >= -1e-8 && v >= -1e-8 && w >= -1e-8) {
              final z = u * mesh.points[t.a].z +
                  v * mesh.points[t.b].z + w * mesh.points[t.c].z;
              final index = y * width + x;
              if (z > depth[index] + 1e-6) {
                depth[index] = z;
                owner[index] = id + 1;
              }
            }
            u += da;
            v += db;
          }
        }
      }
    }

    final masks = List<Path>.generate(meshes.length, (_) => Path());
    for (var y = 0; y < height; y++) {
      var x = 0;
      while (x < width) {
        final id = owner[y * width + x];
        final start = x;
        while (x < width && owner[y * width + x] == id) x++;
        if (id == 0) continue;
        masks[id - 1].addRect(Rect.fromLTWH(
          (left + start).toDouble(), (top + y).toDouble(),
          (x - start).toDouble(), 1,
        ));
      }
    }

    for (var i = 0; i < meshes.length; i++) {
      final mesh = meshes[i];
      canvas.save();
      canvas.clipPath(masks[i]);
      canvas.drawVertices(
        ui.Vertices(
          ui.VertexMode.triangles, mesh.xy,
          colors: [
            for (var j = 0; j < mesh.points.length; j++)
              _shade(mesh.points[j], mesh.color, mesh.inside,
                original: mesh.originalPoints?[j], pose: mesh.pose,
                hingePose: mesh.hingePose),
          ],
          indices: mesh.indices,
        ),
        BlendMode.srcOver,
        Paint()..color = Colors.white,
      );
      if (outlines && mesh.rim != null) {
        final path = Path();
        for (var k = 0; k < mesh.rim!.length; k++) {
          final p = mesh.xy[mesh.rim![k]];
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xff694631));
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShellMeshPainter old) =>
      old.model != model || old.front != front || old.rear != rear ||
      old.mode != mode || old.regions != regions ||
      old.hingeDegrees != hingeDegrees || old.leftPanel != leftPanel ||
      old.rightPanel != rightPanel || old.showInside != showInside ||
      old.outlines != outlines || old.inspectionYaw != inspectionYaw;
}
