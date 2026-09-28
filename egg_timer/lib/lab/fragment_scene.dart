import 'dart:math' as math;

import 'package:flutter/material.dart';

double _part(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);
double _smooth(double t) => t * t * (3 - 2 * t);
double _smoother(double t) => t * t * t * (t * (t * 6 - 15) + 10);

double _pulse(double t, double center, double halfWidth) {
  final distance = ((t - center) / halfWidth).abs();
  return distance >= 1 ? 0 : _smooth(1 - distance);
}

class _PressureEvent {
  const _PressureEvent(this.center, this.halfWidth, this.strength, this.point);
  final double center, halfWidth, strength;
  final Offset point;
  double at(double t) => strength * _pulse(t, center, halfWidth);
  double advance(double t) => _part(t, center - halfWidth, center + halfWidth);
}

class _CrackAdvance {
  const _CrackAdvance(this.pressure, this.start, this.end);
  final int pressure;
  final double start, end;
  double at(double t, List<_PressureEvent> events) =>
      _smooth(_part(events[pressure].advance(t), start, end));
}

class _LiftPush {
  const _LiftPush(this.start, this.end, this.amount, this.point);
  final double start, end, amount;
  final Offset point;
  double at(double t) => amount * _smooth(_part(t, start, end));
}

class _ShellAttachment {
  const _ShellAttachment(
    this.vertex, this.releaseStart, this.releaseEnd, this.scarEnd,
  );
  final int vertex;
  final double releaseStart, releaseEnd;
  final Offset scarEnd;
  double hold(double t) => 1 - _smooth(_part(t, releaseStart, releaseEnd));
}

class _BodyEpisode {
  const _BodyEpisode(this.start, this.peak, this.end, this.tilt, this.rise);
  final double start, peak, end, tilt, rise;

  double weight(double t) {
    if (t <= start || t >= end) return 0;
    return t < peak
        ? _smoother(_part(t, start, peak))
        : 1 - _smoother(_part(t, peak, end));
  }
}

String fragmentPhase(double t) => t < .25
    ? 'Coquille intacte'
    : t < .495
    ? 'Propagation de la fissure'
    : t < .6
    ? 'Soulèvement du fragment'
    : t < 1
    ? 'Chute du fragment'
    : 'Fragment au sol';

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V rotate(double pitch, double yaw, double roll) {
    final yy = y * math.cos(pitch) - z * math.sin(pitch);
    final zz = y * math.sin(pitch) + z * math.cos(pitch);
    final xx = x * math.cos(yaw) + zz * math.sin(yaw);
    return _V(
      xx * math.cos(roll) - yy * math.sin(roll),
      xx * math.sin(roll) + yy * math.cos(roll),
      -x * math.sin(yaw) + zz * math.cos(yaw),
    );
  }

  Offset get xy => Offset(x, y);
}

class _Face {
  _Face(
    this.vertices,
    this.color, {
    this.shader,
    this.shade = 0,
    this.highlight = 0,
  });
  final List<_V> vertices;
  final Color color;
  final Shader? shader;
  final double shade, highlight;
  double get depth => vertices.fold(0.0, (s, v) => s + v.z) / vertices.length;
  double get screenArea {
    var area = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      area += a.x * b.y - b.x * a.y;
    }
    return area;
  }
}

double _diffuse(List<_V> vertices) {
  final a = vertices[0];
  final b = vertices[1];
  final c = vertices[2];
  final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  final nx = uy * vz - uz * vy;
  final ny = uz * vx - ux * vz;
  final nz = ux * vy - uy * vx;
  final length = math.sqrt(nx * nx + ny * ny + nz * nz);
  if (length == 0) return 0;
  return ((-.35 * nx - .45 * ny + .82 * nz) / length).clamp(0.0, 1.0);
}

Path _polygon(Iterable<Offset> points) =>
    Path()..addPolygon(points.toList(), true);

class _CrackOpening {
  const _CrackOpening(this.gap, this.lightLip, this.shadedLip);
  final Path gap, lightLip, shadedLip;
}

_CrackOpening _gapRibbon(
  List<Offset> edge,
  double growth,
  double Function(Offset) widthAt,
) {
  var total = 0.0;
  for (var i = 1; i < edge.length; i++) {
    total += (edge[i] - edge[i - 1]).distance;
  }
  var remaining = total * growth;
  final visible = <Offset>[edge.first];
  for (var i = 1; i < edge.length && remaining > 0; i++) {
    final length = (edge[i] - edge[i - 1]).distance;
    final part = (remaining / length).clamp(0.0, 1.0).toDouble();
    visible.add(Offset.lerp(edge[i - 1], edge[i], part)!);
    remaining -= length;
  }
  if (visible.length < 2) return _CrackOpening(Path(), Path(), Path());
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < visible.length; i++) {
    final before = visible[i == 0 ? 0 : i - 1];
    final after = visible[i == visible.length - 1 ? i : i + 1];
    final tangent = after - before;
    final length = tangent.distance;
    if (length == 0) continue;
    final normal = Offset(-tangent.dy / length, tangent.dx / length);
    final taper = i == visible.length - 1 ? .18 : i == 0 ? .65 : 1.0;
    final span = (after - before).distance;
    final localWidth = widthAt(visible[i]) *
        (.76 + .24 * (span / 18).clamp(0.0, 1.0).toDouble());
    // The plate keeps the original fracture line. Material opens only on the
    // remaining-shell side, so the same face can move without filling a gap.
    final offset = normal * (localWidth * taper);
    left.add(visible[i]);
    right.add(visible[i] - offset);
  }
  return _CrackOpening(
    _polygon([...left, ...right.reversed]),
    Path()..addPolygon(left, false),
    Path()..addPolygon(right, false),
  );
}

class FragmentScene extends CustomPainter {
  FragmentScene({
    required this.progress,
    required this.thickness,
    required this.motion,
    required this.guides,
    required this.showEgg,
    required this.shadow,
  });
  final double progress, thickness, motion;
  final bool guides, showEgg, shadow;

  // One immutable boundary drives the crack, aperture and moving fragment.
  static const _boundary = [
    Offset(9, -108),
    Offset(34, -123),
    Offset(47, -109),
    Offset(72, -94),
    Offset(64, -71),
    Offset(78, -57),
    Offset(53, -36),
    Offset(32, -43),
    Offset(13, -34),
    Offset(4, -60),
    Offset(-7, -75),
    Offset(6, -88),
  ];

  // Fixed, small deviations from each structural edge. These are material
  // breaks, not frame-by-frame noise; the same points define crack and cut.
  static const _fractureSteps = [
    [Offset(.21, .7), Offset(.47, -.5), Offset(.79, 1.1)],
    [Offset(.3, -.6), Offset(.63, .8)],
    [Offset(.18, 1.1), Offset(.44, -.4), Offset(.76, .6)],
    [Offset(.26, -.8), Offset(.58, .4), Offset(.83, -.5)],
    [Offset(.34, .7), Offset(.71, -.9)],
    [Offset(.16, -.6), Offset(.39, .8), Offset(.74, -.4)],
    [Offset(.23, .5), Offset(.53, -1.1), Offset(.81, .3)],
    [Offset(.29, -.7), Offset(.67, .5)],
    [Offset(.2, .8), Offset(.49, -.4), Offset(.72, .9)],
    [Offset(.31, -.9), Offset(.62, .5)],
    [Offset(.17, .5), Offset(.45, -.7), Offset(.78, .4)],
    [Offset(.36, -.6), Offset(.7, .8)],
  ];
  static final _fractureEdges = _buildFractureEdges();
  static final _fractureBoundary = [
    for (final edge in _fractureEdges) ...edge.take(edge.length - 1),
  ];

  static List<List<Offset>> _buildFractureEdges() {
    return List.generate(_boundary.length, (i) {
      final a = _boundary[i];
      final b = _boundary[(i + 1) % _boundary.length];
      final direction = b - a;
      final length = direction.distance;
      final normal = Offset(-direction.dy / length, direction.dx / length);
      return [
        a,
        for (final step in _fractureSteps[i])
          a + direction * step.dx + normal * step.dy,
        b,
      ];
    });
  }

  // Disconnected starts grow and pause independently; the last links close
  // only immediately before the plate can move. Each edge is still part of
  // the one contour shared by the hole and the rigid fragment.
  static const _crackAdvances = [
    _CrackAdvance(0, .15, .9), _CrackAdvance(3, .3, .95),
    _CrackAdvance(4, .25, .95), _CrackAdvance(5, .25, 1),
    _CrackAdvance(0, .35, 1), _CrackAdvance(2, .05, .9),
    _CrackAdvance(4, .35, 1), _CrackAdvance(5, .4, 1),
    _CrackAdvance(1, .1, .95), _CrackAdvance(3, .4, 1),
    _CrackAdvance(4, .05, .9), _CrackAdvance(5, .5, 1),
  ];
  static const _branchAdvances = [
    _CrackAdvance(1, .2, .9), _CrackAdvance(2, .1, .8),
    _CrackAdvance(3, .45, 1), _CrackAdvance(1, .35, 1),
    _CrackAdvance(2, .3, .9),
  ];
  static const _branches = [
    [Offset(72, -94), Offset(80, -91), Offset(83, -88), Offset(88, -86), Offset(95, -76)],
    [Offset(53, -36), Offset(65, -31), Offset(68, -28), Offset(76, -23), Offset(83, -16)],
    [Offset(-7, -75), Offset(-15, -68), Offset(-18, -66), Offset(-21, -61), Offset(-24, -53)],
    [Offset(34, -123), Offset(43, -129), Offset(47, -128), Offset(51, -132), Offset(64, -125)],
    [Offset(64, -71), Offset(76, -73), Offset(81, -70), Offset(83, -72), Offset(96, -62)],
  ];
  static const _microAdvances = [
    _CrackAdvance(1, .55, 1), _CrackAdvance(2, .45, .95),
    _CrackAdvance(4, .35, .9),
  ];
  static const _microBranches = [
    [Offset(47, -128), Offset(46, -133), Offset(44, -136)],
    [Offset(83, -88), Offset(87, -94)],
    [Offset(68, -28), Offset(69, -23), Offset(72, -21)],
  ];
  // Broad, asymmetric shifts of internal mass. The gaps shorten as activity
  // grows, while amplitudes stay restrained. Local pressure uses shorter pulses.
  static const _bodyEpisodes = [
    _BodyEpisode(.105, .141, .19, .18, .11),
    _BodyEpisode(.225, .257, .299, -.22, .16),
    _BodyEpisode(.327, .352, .389, -.13, .21),
    _BodyEpisode(.403, .424, .459, .27, .2),
    _BodyEpisode(.471, .491, .523, .14, .24),
    _BodyEpisode(.536, .561, .594, -.3, .26),
  ];
  // Pressure has a location independent of the fragment's geometric center.
  // More events or pressure zones can use the same data without changing the
  // rigid fragment representation.
  static const _pressureEvents = [
    _PressureEvent(.27, .02, .3, Offset(62, -87)),
    _PressureEvent(.327, .016, .42, Offset(14, -72)),
    _PressureEvent(.378, .014, .52, Offset(66, -62)),
    _PressureEvent(.43, .013, .68, Offset(25, -48)),
    _PressureEvent(.448, .013, .42, Offset(70, -71)),
    _PressureEvent(.482, .013, .34, Offset(63, -81)),
    _PressureEvent(.51, .015, .48, Offset(66, -62)),
    _PressureEvent(.554, .013, .66, Offset(28, -48)),
    _PressureEvent(.59, .01, .9, Offset(70, -70)),
  ];
  static const _liftPushes = [
    _LiftPush(.495, .514, .16, Offset(63, -81)),
    _LiftPush(.524, .542, .25, Offset(66, -62)),
    _LiftPush(.552, .57, .27, Offset(28, -48)),
    _LiftPush(.583, .6, .32, Offset(70, -70)),
  ];
  // The left and upper edge resists pressure applied mostly on the right.
  // Each connection gives way during a different lift episode.
  static const _attachments = [
    _ShellAttachment(10, .524, .542, Offset(-22, -77)),
    _ShellAttachment(8, .552, .57, Offset(15, -22)),
    _ShellAttachment(0, .583, .6, Offset(6, -120)),
  ];
  static final _grain = _makeGrain();

  static List<Offset> _makeGrain() {
    final random = math.Random(37);
    return List.generate(
      520,
      (_) => Offset(-115 + 230 * random.nextDouble(),
          -220 + 440 * random.nextDouble()),
    );
  }

  _V _surface(Offset p) => _V(
    p.dx,
    p.dy,
    65 *
        math.sqrt(
          math.max(0, 1 - math.pow(p.dx / 115, 2) - math.pow(p.dy / 220, 2)),
        ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform scale: changing the phone ratio reveals more vertical space.
    final scale = size.width / 390;
    final height = size.height / scale;
    canvas.save();
    canvas.scale(scale);
    final bounds = Rect.fromLTWH(0, 0, 390, height);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff463a30), Color(0xffa08562), Color(0xffd4b985)],
        ).createShader(bounds),
    );
    final base = height * .82;
    canvas.drawRect(
      Rect.fromLTWH(0, base, 390, height - base),
      Paint()..color = const Color(0xffb99a68),
    );
    // Fixed seed and fixed coordinates: background never moves or flickers.
    final random = math.Random(14);
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * 390;
      final y = base + random.nextDouble() * (height - base);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + random.nextDouble() * 35 - 17, y - 5),
        Paint()
          ..color = const Color(0xffe1c58d)
          ..strokeWidth = 1.5,
      );
    }
    final origin = Offset(186, base - 220);
    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(origin.dx, base + 3),
          width: 195,
          height: 22,
        ),
        Paint()
          ..color = const Color(0x55453221)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    // Whole-body motion has rounded acceleration and rests between episodes;
    // local shell pressure remains on its own, quicker schedule.
    final bodyTilt = _bodyEpisodes.fold(
      0.0, (sum, episode) => sum + episode.tilt * episode.weight(progress),
    );
    final bodyRise = _bodyEpisodes.fold(
      0.0, (sum, episode) => sum + episode.rise * episode.weight(progress),
    );
    final localPressure = _pressureEvents.fold(
      0.0, (sum, event) => sum + event.at(progress),
    );
    final pressurePoint = localPressure > 0
        ? _pressureEvents.fold(
            Offset.zero,
            (sum, event) => sum + event.point * event.at(progress),
          ) / localPressure
        : const Offset(35, -78);
    final wobble = .01 * motion * bodyTilt;
    canvas.translate(0, -1.8 * motion * bodyRise);
    canvas.translate(0, 220);
    canvas.rotate(wobble);
    canvas.translate(0, -220);
    final egg = Path()
      ..moveTo(0, -220)
      ..cubicTo(69, -220, 115, -52, 115, 75)
      ..cubicTo(115, 181, 75, 220, 0, 220)
      ..cubicTo(-75, 220, -115, 181, -115, 75)
      ..cubicTo(-115, -52, -69, -220, 0, -220)
      ..close();
    final aperture = _polygon(_fractureBoundary);
    final detached = progress > .495;
    final gap = Path();
    final openings = <_CrackOpening>[];
    for (var i = 0; i < _fractureEdges.length; i++) {
        final growth = _crackAdvances[i].at(progress, _pressureEvents);
        final opening = _smooth(_part(growth, .62, 1));
        if (opening == 0) continue;
        final source = _pressureEvents[_crackAdvances[i].pressure].point;
        double widthAt(Offset point) {
          final nearSource =
              (1 - ((point - source).distance / 120)
                  .clamp(0.0, 1.0).toDouble());
          final nearCurrentPressure =
              (1 - ((point - pressurePoint).distance / 110)
                  .clamp(0.0, 1.0).toDouble());
          var retention = 1.0;
          for (final attachment in _attachments) {
            final attachmentPoint = _boundary[attachment.vertex];
            final nearAttachment =
                (1 - ((point - attachmentPoint).distance / 13)
                    .clamp(0.0, 1.0).toDouble());
            retention *= 1 - attachment.hold(progress) * nearAttachment;
          }
          return opening * (.43 + .2 * nearSource +
              .09 * localPressure * nearCurrentPressure) * retention;
        }
        final cut = _gapRibbon(_fractureEdges[i], growth, widthAt);
        gap.addPath(cut.gap, Offset.zero);
        openings.add(cut);
    }
    final bridges = Path();
    if (detached) {
      for (final attachment in _attachments) {
        final hold = attachment.hold(progress);
        if (hold <= 0) continue;
        bridges.addOval(Rect.fromCircle(
          center: _boundary[attachment.vertex], radius: 1.8 * hold,
        ));
      }
    }
    final cutEgg = detached
        ? Path.combine(PathOperation.difference, egg, aperture)
        : egg;
    final connectedShell = detached
        ? Path.combine(PathOperation.union, cutEgg, bridges)
        : cutEgg;
    final shell = Path.combine(PathOperation.difference, connectedShell, gap);
    final shellShader = const RadialGradient(
      center: Alignment(-.5, -.6),
      radius: 1.4,
      colors: [Color(0xffffd8a0), Color(0xffd69b62), Color(0xff956039)],
    ).createShader(const Rect.fromLTWH(-115, -220, 230, 440));
    if (showEgg) {
      canvas.drawPath(gap, Paint()..color = const Color(0xff69442e));
      canvas.drawPath(shell, Paint()..color = const Color(0xff57402c));
      canvas.drawPath(shell, Paint()..shader = shellShader);
      if (openings.isNotEmpty) {
        canvas.save();
        canvas.clipPath(shell);
        for (final opening in openings) {
          canvas.drawPath(
            opening.lightLip,
            Paint()
              ..color = const Color(0x66ffe4be)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .42,
          );
          canvas.drawPath(
            opening.shadedLip,
            Paint()
              ..color = const Color(0x553d2417)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .35,
          );
        }
        canvas.restore();
      }
      final darkGrain = Paint()..color = const Color(0x16825234);
      final lightGrain = Paint()..color = const Color(0x14fff0d7);
      for (var i = 0; i < _grain.length; i++) {
        final spot = _grain[i];
        if (!shell.contains(spot)) continue;
        canvas.drawCircle(
          spot, .3 + .08 * (i % 5), i % 4 == 0 ? lightGrain : darkGrain,
        );
      }
    }
    if (showEgg && progress > .25) {
      // A local pressure mark lives on the still-intact shell. It fades as
      // the pressure releases and never changes the shared rigid contour.
      if (!detached && localPressure > 0) {
        canvas.save();
        canvas.clipPath(aperture);
        canvas.drawOval(
          Rect.fromCenter(center: pressurePoint, width: 93, height: 103),
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.fromRGBO(255, 239, 207, .1 * localPressure),
                const Color(0x00ffefcf),
              ],
            ).createShader(
              Rect.fromCenter(center: pressurePoint, width: 93, height: 103),
            ),
        );
        canvas.restore();
      }
      for (var i = 0; i < _fractureEdges.length && !detached; i++) {
        final growth = _crackAdvances[i].at(progress, _pressureEvents);
        if (growth == 0) continue;
        final opening = _smooth(_part(growth, .62, 1));
        final edge = Path()..addPolygon(_fractureEdges[i], false);
        final metric = edge.computeMetrics().first;
        final visible = metric.extractPath(0, metric.length * growth);
        final pressureAtEdge = localPressure *
            (1 - ((_fractureEdges[i].first - pressurePoint).distance / 160)
                .clamp(0.0, 1.0).toDouble());
        canvas.drawPath(
          visible,
          Paint()
            ..color = const Color(0xff6c4430)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (.45 + .25 * growth) * (1 - .8 * opening)
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.save();
      canvas.clipPath(shell);
      for (var i = 0; i < _branches.length; i++) {
        final growth = _branchAdvances[i].at(progress, _pressureEvents);
        if (growth == 0) continue;
        final branch = Path()..addPolygon(_branches[i], false);
        final metric = branch.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * growth),
          Paint()
            ..color = const Color(0xff765038)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .3 + .5 * growth
            ..strokeCap = StrokeCap.round,
        );
      }
      for (var i = 0; i < _microBranches.length; i++) {
        final growth = _microAdvances[i].at(progress, _pressureEvents);
        if (growth == 0) continue;
        final branch = Path()..addPolygon(_microBranches[i], false);
        final metric = branch.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * growth),
          Paint()
            ..color = const Color(0x88765038)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .32
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
    }
    // Unequal pushes leave brief holds and elastic returns. The rigid contour
    // never deforms; only its pose advances before the final release.
    final lift = (
      _liftPushes.fold(0.0, (sum, push) => sum + push.at(progress)) -
      .025 * _pulse(progress, .519, .005) -
      .02 * _pulse(progress, .547, .005) -
      .015 * _pulse(progress, .576, .006)
    ).clamp(0.0, 1.0);
    final flight = _part(progress, .6, .88);
    final turn = flight * (1.12 - .12 * flight);
    final settle = _smooth(_part(progress, .88, 1));
    final recoil =
        math.sin(2 * math.pi * settle) * (1 - settle) * (1 - settle);
    final bounce = 4 * math.sin(math.pi * settle) * (1 - settle);
    final center = _surface(const Offset(35, -78));
    var heldWeight = 0.0;
    var heldPoint = Offset.zero;
    for (final attachment in _attachments) {
      final hold = attachment.hold(progress);
      heldWeight += hold;
      heldPoint += _boundary[attachment.vertex] * hold;
    }
    final remainingPivot = heldWeight > 0
        ? heldPoint / heldWeight
        : const Offset(35, -78);
    final releasedShare = 1 - heldWeight / _attachments.length;
    final attachmentBlend = _smooth(_part(releasedShare, .55, 1));
    final pivotOnShell = Offset.lerp(
      remainingPivot, const Offset(35, -78), attachmentBlend,
    )!;
    final pivot = _surface(pivotOnShell);
    // Off-center pressure changes only the early pose. Its small torque fades
    // during flight, leaving the established fall and landing unchanged.
    final pressureRoll = _liftPushes.fold(
      0.0,
      (sum, push) =>
          sum + push.at(progress) * (push.point.dx - center.x) / 45,
    );
    final pressurePitch = _liftPushes.fold(
      0.0,
      (sum, push) =>
          sum + push.at(progress) * (push.point.dy - center.y) / 45,
    );
    final initialTorqueFade = 1 - turn;
    // Rotation never reaches an edge-on projection. The small damped roll and
    // lift after impact let the light shell settle on a broad face.
    const impactPitch = .55, impactYaw = .55, impactRoll = .35;
    final rotationX =
        -.38 * lift + (impactPitch + .38) * turn + .25 * settle +
        (.03 + .01 * releasedShare) * pressurePitch * initialTorqueFade;
    final rotationY =
        .45 * lift + (impactYaw - .45) * turn - .4 * settle + .03 * recoil;
    final rotationZ = impactRoll * turn - .5 * settle + .05 * recoil -
        (.14 + .025 * releasedShare) * pressureRoll * initialTorqueFade;
    _V rotate(_V v) =>
        (v - pivot).rotate(rotationX, rotationY, rotationZ) + pivot - center;
    final outer = _fractureBoundary.map(_surface).toList();
    final inner = outer.map((v) => _V(v.x, v.y, v.z - thickness)).toList();
    final rotated = [...outer, ...inner].map(rotate).toList();
    final bottom = rotated.map((v) => v.y).reduce(math.max);
    final impactBottom = [...outer, ...inner]
        .map((v) => (v - center).rotate(impactPitch, impactYaw, impactRoll).y)
        .reduce(math.max);
    final impactLandingY = 220 - center.y - impactBottom;
    // A fixed landing target gives the airborne piece a quadratic gravity arc.
    // After impact, the lowest vertex remains on the floor as the shell rocks.
    final ballisticY =
        -12 * lift * lift * (1 - flight) -
        20 * flight +
        (impactLandingY + 20) * flight * flight;
    final groundedY = 220 - center.y - bottom;
    final shift = _V(
      55 * flight + 4 * settle,
      (settle > 0 ? groundedY : ballisticY) - bounce,
      22 * lift * lift,
    );
    final fragmentShader = const RadialGradient(
      center: Alignment(-.5, -.6),
      radius: 1.4,
      colors: [Color(0xffffd8a0), Color(0xffd69b62), Color(0xff956039)],
    ).createShader(
      const Rect.fromLTWH(-115, -220, 230, 440)
          .shift(Offset(shift.x, shift.y)),
    );
    _V transform(_V v) => rotate(v) + center + shift;
    final projectedOuter = outer.map(transform).toList();
    final projectedInner = inner.map(transform).toList();
    if (shadow && flight > 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.x + shift.x, 222),
          width: 64,
          height: 10,
        ),
        Paint()
          ..color = Color.fromRGBO(
            60, 40, 20, .08 + .2 * flight - .04 * bounce / 4,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    if (shadow && showEgg && detached) {
      // The moving silhouette casts only onto the remaining shell, never a
      // blurred halo into the empty opening or the surrounding background.
      canvas.save();
      canvas.clipPath(shell);
      canvas.translate(4, 5);
      canvas.drawPath(
        _polygon(projectedOuter.map((v) => v.xy)),
        Paint()
          ..color = Color.fromRGBO(48, 29, 16, .24 * lift)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.restore();
    }

    // Before departure this exact contour is part of the intact egg. After
    // departure there is only one moving mesh and one matching empty aperture.
    if (detached || !showEgg) {
      final faces = <_Face>[];
      final third = outer.length ~/ 3;
      final outerLight = _diffuse([
        projectedOuter[0], projectedOuter[third],
        projectedOuter[2 * third],
      ]);
      final restingLight = _diffuse([
        outer[0], outer[third], outer[2 * third],
      ]);
      final lightChange = outerLight - restingLight;
      final outerFace = _Face(
        projectedOuter,
        Colors.white,
        shader: fragmentShader,
        shade: (-lightChange * .48).clamp(0.0, .22),
        highlight: (lightChange * .28).clamp(0.0, .15),
      );
      final innerFace = _Face(
        projectedInner.reversed.toList(),
        const Color(0xffe7c79e),
        shade: .06 + .2 *
            (1 - _diffuse([
              projectedInner[third], projectedInner[0],
              projectedInner[2 * third],
            ])),
      );
      faces.addAll([outerFace, innerFace]);
      for (var i = 0; i < outer.length; i++) {
        final j = (i + 1) % outer.length;
        final edgePoint = Offset(
          (outer[i].x + outer[j].x) / 2,
          (outer[i].y + outer[j].y) / 2,
        );
        var buried = 0.0;
        for (final attachment in _attachments) {
          final anchor = _boundary[attachment.vertex];
          final near =
              (1 - ((edgePoint - anchor).distance / 13)
                  .clamp(0.0, 1.0).toDouble());
          buried = math.max(buried, attachment.hold(progress) * near);
        }
        final exposed = 1 - buried;
        if (exposed < .03) continue;
        _V visibleInner(int index) => _V(
          projectedOuter[index].x +
              (projectedInner[index].x - projectedOuter[index].x) * exposed,
          projectedOuter[index].y +
              (projectedInner[index].y - projectedOuter[index].y) * exposed,
          projectedOuter[index].z +
              (projectedInner[index].z - projectedOuter[index].z) * exposed,
        );
        final rimFace = [
          projectedOuter[i],
          visibleInner(i),
          visibleInner(j),
          projectedOuter[j],
        ];
        faces.add(
          _Face(
            rimFace,
            const Color(0xffbd875a),
            shade: .1 + .3 * (1 - _diffuse(rimFace)),
          ),
        );
      }
      faces.sort((a, b) => a.depth.compareTo(b.depth));
      for (final face in faces) {
        // The inner face stays hidden until the fragment actually turns.
        if (face.screenArea <= 0) continue;
        final path = _polygon(face.vertices.map((v) => v.xy));
        final paint = Paint()
          ..color = face.color
          ..shader = face.shader;
        canvas.drawPath(path, paint);
        if (identical(face, outerFace)) {
          // A broad, moving highlight describes the curved shell without
          // exposing its construction or changing the fragment geometry.
          canvas.drawPath(
            path,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-.35, -.3),
                radius: 1.15,
                colors: [
                  Color.fromRGBO(255, 247, 225, .08 * lift),
                  const Color(0x00fff7e1),
                ],
              ).createShader(path.getBounds()),
          );
        }
        if (face.shade > 0) {
          canvas.drawPath(
            path,
            Paint()..color = Color.fromRGBO(38, 23, 12, face.shade),
          );
        }
        if (face.highlight > 0) {
          canvas.drawPath(
            path,
            Paint()..color = Color.fromRGBO(255, 238, 207, face.highlight),
          );
        }
      }
      final visibleSurface = outerFace.screenArea > 0
          ? outerFace
          : innerFace.screenArea > 0
              ? innerFace
              : null;
      if (visibleSurface != null) {
        final silhouette = _polygon(visibleSurface.vertices.map((v) => v.xy));
        if (identical(visibleSurface, outerFace)) {
          canvas.save();
          canvas.clipPath(silhouette);
          final darkGrain = Paint()..color = const Color(0x16825234);
          final lightGrain = Paint()..color = const Color(0x14fff0d7);
          for (var i = 0; i < _grain.length; i++) {
            final spot = _grain[i];
            if (!aperture.contains(spot)) continue;
            canvas.drawCircle(
              transform(_surface(spot)).xy,
              .3 + .08 * (i % 5),
              i % 4 == 0 ? lightGrain : darkGrain,
            );
          }
          canvas.restore();
        }
      }
    }

    if (showEgg && detached && progress < .6) {
      // Small bridges keep the opposite edge visibly tied to the shell until
      // each attachment yields. They connect the same boundary points, not a
      // second drawing of the fragment.
      for (final attachment in _attachments) {
        final hold = attachment.hold(progress);
        if (hold <= 0) continue;
        final shellPoint = _boundary[attachment.vertex];
        final piecePoint = transform(_surface(shellPoint)).xy;
        canvas.drawLine(
          shellPoint, piecePoint,
          Paint()
            ..color = Color.fromRGBO(215, 166, 111, .85 * hold)
            ..strokeWidth = thickness * hold
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (showEgg && detached) {
      canvas.save();
      canvas.clipPath(shell);
      for (final attachment in _attachments) {
        final broken = 1 - attachment.hold(progress);
        if (broken <= 0) continue;
        final shellPoint = _boundary[attachment.vertex];
        canvas.drawLine(
          shellPoint,
          Offset.lerp(shellPoint, attachment.scarEnd, broken)!,
          Paint()
            ..color = const Color(0xff765038)
            ..strokeWidth = .75
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
    }

    canvas.restore();
    if (guides) {
      final p = Paint()
        ..color = const Color(0x55ffffff)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(195, 0), Offset(195, height), p);
      canvas.drawLine(Offset(0, base), Offset(390, base), p);
    }
    final text = TextPainter(
      text: const TextSpan(
        text: 'ÉCLOSION\nÉtude de fragment · matière provisoire',
        style: TextStyle(color: Color(0xfff9e9cc), fontSize: 14, height: 1.8),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 350);
    text.paint(canvas, Offset((390 - text.width) / 2, 32));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FragmentScene old) =>
      progress != old.progress ||
      thickness != old.thickness ||
      motion != old.motion ||
      guides != old.guides ||
      showEgg != old.showEgg ||
      shadow != old.shadow;
}
