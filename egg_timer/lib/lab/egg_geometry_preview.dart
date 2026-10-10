import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'egg_fragment_regions.dart';
import 'egg_exit_motion_config.dart';
import 'egg_panel_inspection_pose.dart';
import 'egg_panel_hinge_pose.dart';
import 'egg_panel_release_motion.dart';
import 'egg_organic_continuous_pose.dart';
import 'egg_organic_front_bowl_shell.dart';
import 'egg_organic_rear_bowl_shell.dart';
import 'egg_fracture_network.dart';
import 'egg_rear_bowl_boundary.dart';
import 'egg_rear_bowl_mesh.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_front_assembly.dart';
import 'egg_shell_model.dart';
import 'egg_stationary_bowl_shell.dart';

/// Diagnostic display phases only; the product timer is separate.
class EggExitTimeline {
  const EggExitTimeline._();
  static const releaseThreshold = .55;
  static const finalHingeDegrees = 30.0;
  // V11.26: complete the staged, collision-conscious physical departure.
  // The original 1.2 s truncated the V11.25 sideways travel at 100%.
  static const freeDuration = 2.0;

  static void _check(double p) {
    if (!p.isFinite || p < 0 || p > 1) {
      throw ArgumentError.value(p, 'progress');
    }
  }

  static double hingeAngle(double p) {
    _check(p);
    final u = (p / releaseThreshold).clamp(0.0, 1.0);
    return finalHingeDegrees * u * u * (3 - 2 * u);
  }

  static double freeSeconds(double p) {
    _check(p);
    return p <= releaseThreshold
        ? 0.0
        : (p - releaseThreshold) / (1 - releaseThreshold) * freeDuration;
  }

  static bool released(double p) {
    _check(p);
    return p > releaseThreshold;
  }
}

/// Keep a fixed camera for the whole exit sequence. The diagnostic must
/// preserve 3D positions, not move the camera to chase each fragment.
/// All samples are computed once from the real V11.19 motion.
class EggExitFraming {
  const EggExitFraming._();

  static double horizontalExtent({
    required double stationaryRadius,
    required List<EggShellPanelMesh> panels,
    required List<EggPanelReleaseMotion> motions,
  }) {
    if (!stationaryRadius.isFinite ||
        stationaryRadius <= 0 ||
        panels.isEmpty ||
        panels.length != motions.length) {
      throw ArgumentError('Invalid shell exit framing');
    }
    var extent = stationaryRadius;
    for (var i = 0; i < panels.length; i++) {
      for (final group in [panels[i].outer, panels[i].inner]) {
        for (final point in group) {
          extent = math.max(extent, point.x.abs());
          for (var sample = 0; sample <= 24; sample++) {
            final time = EggExitTimeline.freeDuration * sample / 24;
            extent = math.max(
              extent, motions[i].transform(point, time).x.abs(),
            );
          }
        }
      }
    }
    // Additional physical-space slack also covers between-sample extrema.
    return extent + 8;
  }
  /// V11.26: retain a fixed, fully visible portrait camera even if the
  /// longer material flight changes vertical as well as horizontal extents.
  static double verticalExtent({
    required double stationaryHalfHeight,
    required List<EggShellPanelMesh> panels,
    required List<EggPanelReleaseMotion> motions,
  }) {
    if (!stationaryHalfHeight.isFinite ||
        stationaryHalfHeight <= 0 ||
        panels.isEmpty ||
        panels.length != motions.length) {
      throw ArgumentError('Invalid vertical exit framing');
    }
    var extent = stationaryHalfHeight;
    for (var i = 0; i < panels.length; i++) {
      for (final group in [panels[i].outer, panels[i].inner]) {
        for (final point in group) {
          extent = math.max(extent, point.y.abs());
          for (var sample = 0; sample <= 24; sample++) {
            final time = EggExitTimeline.freeDuration * sample / 24;
            extent = math.max(
              extent, motions[i].transform(point, time).y.abs(),
            );
          }
        }
      }
    }
    return extent + 8;
  }
}

/// Integer raster extents follow actual material vertices each frame.
/// Clipping a moving fragment against a fixed 340-unit z-buffer is invalid.
class EggDepthRasterBounds {
  const EggDepthRasterBounds._(
    this.left, this.top, this.width, this.height,
  );

  final int left, top, width, height;

  factory EggDepthRasterBounds.fromPoints(
    Iterable<EggShellPoint3> points,
  ) {
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in points) {
      if (!p.x.isFinite || !p.y.isFinite) {
        throw ArgumentError('Non-finite projected shell vertex');
      }
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    if (!minX.isFinite) {
      throw ArgumentError('Cannot build a depth raster without vertices');
    }
    final x0 = (minX - 2).floor();
    final y0 = (minY - 2).floor();
    return EggDepthRasterBounds._(
      x0, y0, (maxX + 2).ceil() - x0, (maxY + 2).ceil() - y0,
    );
  }

  bool contains(EggShellPoint3 point) =>
      point.x >= left && point.x < left + width &&
      point.y >= top && point.y < top + height;
}

/// Separate, read-only Chrome diagnostic of the actual V11.8 shell meshes.
/// The validated F1 painter and all motion mechanics remain untouched.
class EggGeometryPreview extends StatefulWidget {
  const EggGeometryPreview({super.key});

  @override
  State<EggGeometryPreview> createState() => _EggGeometryPreviewState();
}

class _EggGeometryPreviewState extends State<EggGeometryPreview>
    with SingleTickerProviderStateMixin {
  late final EggShellFrontAssembly _assembly;
  late final EggFragmentRegionPlan _regions;
  late final EggStationaryBowlShell _front;
  late final EggRearBowlMesh _rear;
  late final EggShellModel _model;
  late final AnimationController _exitPlayback;
  late final List<EggPanelReleaseMotion> _exitMotion;
  late final double _exitHorizontalExtent;
  late final double _exitVerticalExtent;
  // Lazily allocated only when the experimental mode is selected.
  late final EggOrganicContinuousPoseCoordinator _organic =
      EggOrganicContinuousPoseCoordinator.fixed();
  late final EggOrganicFrontBowlShell _organicFront =
      EggOrganicFrontBowlShellBuilder.build(_organic.staged.meshes);
  late final EggOrganicRearBowlShell _organicRear =
      EggOrganicRearBowlShellBuilder.build(_organicFront);
  int _mode = 0; // 0 assembled, 1 separated, 2 hinge, 3 exit, 4 organic
  double _hingeDegrees = 20;
  bool _left = true;
  bool _right = true;
  bool _inside = true;
  bool _outlines = true;
  double _inspectionYaw = 42;

  @override
  void initState() {
    super.initState();
    _exitPlayback = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    );
    final network = EggFractureNetwork.fixed();
    _model = network.model;
    _regions = EggFragmentRegionPlan.fromNetwork(network);
    _assembly = EggShellFrontAssemblyBuilder.build(_regions);
    _front = EggStationaryBowlShellBuilder.build(_assembly);
    _rear = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(_front),
    );
    // Build physical full-release trajectories once, never per paint frame.
    _exitMotion = List<EggPanelReleaseMotion>.unmodifiable([
      for (var i = 0; i < _assembly.panels.length; i++)
        EggExitMotionConfig.build(
          panel: _assembly.panels[i],
          model: _model,
          hinge: EggPanelHingePose.fromGraph(
            panel: _assembly.panels[i],
            region: _regions.regions[i],
            neighbor: _regions.regions[1 - i],
            network: network,
            openingDegrees: EggExitTimeline.finalHingeDegrees,
          ),
        ),
    ]);
    _exitHorizontalExtent = EggExitFraming.horizontalExtent(
      stationaryRadius: _model.maxRadius,
      panels: _assembly.panels,
      motions: _exitMotion,
    );
    _exitVerticalExtent = EggExitFraming.verticalExtent(
      stationaryHalfHeight: _model.halfHeight,
      panels: _assembly.panels,
      motions: _exitMotion,
    );
  }

  @override
  void dispose() {
    _exitPlayback.dispose();
    super.dispose();
  }

  void _playOrPause() {
    if (_exitPlayback.isAnimating) {
      _exitPlayback.stop();
    } else {
      if (_exitPlayback.value >= 1) _exitPlayback.value = 0;
      _exitPlayback.forward();
    }
    setState(() {});
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
              exitPlayback: _exitPlayback,
              exitMotion: _exitMotion,
              exitHorizontalExtent: _exitHorizontalExtent,
              exitVerticalExtent: _exitVerticalExtent,
              organic: _mode == 4 ? _organic : null,
              organicFront: _mode == 4 ? _organicFront : null,
              organicRear: _mode == 4 ? _organicRear : null,
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
      Text(_mode == 4 ? 'Géométrie V11.48 · organique expérimental'
          : 'Géométrie V11.32',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Maillages 3D du bol avant, de la coquille arrière et '
          'des deux panneaux. Mode Sortie animé uniquement en diagnostic. '
          'Le chapeau F1 est visualisé séparément dans l’atelier principal.'),
      const SizedBox(height: 20),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Assemblé')),
          ButtonSegment(value: 1, label: Text('Écarté')),
          ButtonSegment(value: 2, label: Text('Pivot')),
          ButtonSegment(value: 3, label: Text('Sortie')),
          ButtonSegment(value: 4, label: Text('Organique')),
        ],
        selected: {_mode},
        onSelectionChanged: (values) {
          _exitPlayback.stop();
          setState(() => _mode = values.first);
        },
      ),
      const SizedBox(height: 8),
      Text(_mode == 4
          ? 'Organique · essai non validé : trois nouveaux morceaux de '
              'coquille 3D. Contacts diagnostiqués, pas corrigés.'
          : _mode == 3
          ? 'Sortie : pivot attaché puis expulsion rigide. '
              'Collisions non résolues automatiquement.'
          : _mode == 2
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
      if (_mode == 2)
        const Text('V11.12 : charnière sur une connexion inférieure '
            'issue des fissures V10.4. La géométrie tourne d’un seul '
            'bloc ; expulsion et chute non intégrées.',
            style: TextStyle(fontSize: 12)),
      if (_mode == 3 || _mode == 4)
        AnimatedBuilder(
          animation: _exitPlayback,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('Progression pivot et expulsion · '
                  '${(_exitPlayback.value * 100).round()} %'),
              Slider(
                key: const Key('exit-sequence-progress'),
                value: _exitPlayback.value,
                onChanged: (p) {
                  _exitPlayback.stop();
                  _exitPlayback.value = p;
                },
              ),
              Text(
                EggExitTimeline.released(_exitPlayback.value)
                    ? 'Libéré · '
                        '${EggExitTimeline.freeSeconds(_exitPlayback.value).toStringAsFixed(2)} s'
                    : 'Attaché · '
                        '${EggExitTimeline.hingeAngle(_exitPlayback.value).toStringAsFixed(1)}°',
                style: const TextStyle(fontSize: 12),
              ),
              Row(children: [
                FilledButton.tonalIcon(
                  onPressed: _playOrPause,
                  icon: Icon(_exitPlayback.isAnimating
                      ? Icons.pause : Icons.play_arrow),
                  label: Text(_exitPlayback.isAnimating ? 'Pause' : 'Lire'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _exitPlayback.stop();
                    _exitPlayback.value = 0;
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Rejouer'),
                ),
              ]),
              const Text('Pivot 0–55 %, puis poussée 3D extérieure et '
                  'latérale, chute et contact 3D avec le sol. '
                  'Après impact : basculement rigide vers l’extérieur '
                  'et glissement amorti ; collisions diagnostiquées.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
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
      Text(_mode == 4
          ? 'Épaisseur 2,5 · raffinement organique '
              '${_organic.staged.meshes.refinementPasses}'
          : 'Épaisseur 2,5 · raffinement commun '
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
      {this.inside = false, this.rim,
      this.originalPoints, this.pose, this.hingePose,
      this.releaseMotion, this.releaseSeconds = 0,
      this.organicNormalRotation});

  final List<EggShellPoint3> points;
  final List<EggShellTriangle> faces;
  final Color color;
  final bool inside;
  final List<int>? rim;
  final List<EggShellPoint3>? originalPoints;
  final EggPanelInspectionPose? pose;
  final EggPanelHingePose? hingePose;
  final EggPanelReleaseMotion? releaseMotion;
  final double releaseSeconds;
  final EggShellPoint3 Function(EggShellPoint3)? organicNormalRotation;
  late final List<Offset> xy = [
    for (final p in points) Offset(p.x, p.y),
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
    required this.exitPlayback,
    required this.exitMotion,
    required this.exitHorizontalExtent,
    required this.exitVerticalExtent,
    this.organic,
    this.organicFront,
    this.organicRear,
  }) : super(repaint: exitPlayback);

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
  final Animation<double> exitPlayback;
  final List<EggPanelReleaseMotion> exitMotion;
  final double exitHorizontalExtent;
  final double exitVerticalExtent;
  final EggOrganicContinuousPoseCoordinator? organic;
  final EggOrganicFrontBowlShell? organicFront;
  final EggOrganicRearBowlShell? organicRear;

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
    final progress = exitPlayback.value;
    final seconds = mode == 3 ? EggExitTimeline.freeSeconds(progress) : 0.0;
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
      final release = mode == 3 && EggExitTimeline.released(progress)
          ? exitMotion[i] : null;
      final hinge = mode == 2 || (mode == 3 && release == null)
          ? EggPanelHingePose.fromGraph(
              panel: panel,
              region: regions.regions[i],
              neighbor: regions.regions[1 - i],
              network: regions.network,
              openingDegrees: mode == 2
                  ? hingeDegrees : EggExitTimeline.hingeAngle(progress),
            )
          : null;
      final exterior = release?.transformAll(panel.outer, seconds) ??
          hinge?.transformAll(panel.outer) ??
          pose?.transformAll(panel.outer) ?? panel.outer;
      final interior = release?.transformAll(panel.inner, seconds) ??
          hinge?.transformAll(panel.inner) ??
          pose?.transformAll(panel.inner) ?? panel.inner;
      result.add(_Surface(
        exterior, panel.outerTriangles,
        i == 0 ? const Color(0xffffe0b4) : const Color(0xfffbd09a),
        rim: panel.rim, originalPoints: panel.outer,
        pose: pose, hingePose: hinge,
        releaseMotion: release, releaseSeconds: seconds,
      ));
      result.add(_Surface(
        [...exterior, ...interior],
        panel.sideTriangles, const Color(0xffa67857),
        inside: true,
        originalPoints: [...panel.outer, ...panel.inner],
        pose: pose, hingePose: hinge,
        releaseMotion: release, releaseSeconds: seconds,
      ));
      if (mode != 0) {
        final offset = panel.outer.length;
        result.add(_Surface(interior, [
          for (final t in panel.innerTriangles)
            EggShellTriangle(t.a - offset, t.b - offset, t.c - offset),
        ], const Color(0xffd9b18e),
          inside: true, originalPoints: panel.inner,
          pose: pose, hingePose: hinge,
          releaseMotion: release, releaseSeconds: seconds,
        ));
      }
    }
    return result;
  }

  Color _shade(EggShellPoint3 point, Color base, bool inside,
      {EggShellPoint3? original, EggPanelInspectionPose? pose,
      EggPanelHingePose? hingePose,
      EggPanelReleaseMotion? releaseMotion, double releaseSeconds = 0,
      EggShellPoint3 Function(EggShellPoint3)? organicNormalRotation}) {
    final localNormal = model.normalAt(original ?? point);
    final n = organicNormalRotation?.call(localNormal) ??
        releaseMotion?.rotateNormal(localNormal, releaseSeconds) ??
        hingePose?.rotateNormal(localNormal) ??
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
    final baselineScale = math.min(
      size.width * .82 / (2 * model.maxRadius),
      size.height * .78 / (2 * model.halfHeight),
    );
    // V11.20/V11.26: fixed framing over the full extended 3D exit.
    // The camera never zooms with animation progress or clips the panel
    // just because the release now moves farther along the same trajectory.
    final scale = (mode == 3 || mode == 4)
        ? math.min(
            baselineScale,
            math.min(
              size.width * .46 / exitHorizontalExtent,
              size.height * .44 / exitVerticalExtent,
            ),
          )
        : baselineScale;
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
    final bounds = EggDepthRasterBounds.fromPoints(
      meshes.expand((mesh) => mesh.points),
    );
    final left = bounds.left, top = bounds.top;
    final width = bounds.width, height = bounds.height;
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
        while (x < width && owner[y * width + x] == id) {
          x++;
        }
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
                hingePose: mesh.hingePose,
                releaseMotion: mesh.releaseMotion,
                releaseSeconds: mesh.releaseSeconds,
                organicNormalRotation: mesh.organicNormalRotation),
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
      old.outlines != outlines || old.inspectionYaw != inspectionYaw ||
       old.exitPlayback != exitPlayback || old.exitMotion != exitMotion ||
       old.exitHorizontalExtent != exitHorizontalExtent ||
       old.exitVerticalExtent != exitVerticalExtent ||
        old.organic != organic || old.organicFront != organicFront ||
        old.organicRear != organicRear;
}
