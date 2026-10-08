import 'dart:math' as math;

class EggShellCrackPoint {
  const EggShellCrackPoint(this.angle, this.y);

  final double angle;
  final double y;
}

class EggShellCrackBranch {
  const EggShellCrackBranch(this.points);

  final List<EggShellCrackPoint> points;
}

/// Deterministic fracture layout for one hatching session.
///
/// The seed is chosen once per session. Geometry is then frozen for the whole
/// animation: no random values are generated frame by frame.
class EggShellCrackNetwork {
  EggShellCrackNetwork(this.seed);

  final int seed;

  static const _baseBoundary = <double>[
    -128,
    -124,
    -126,
    -118,
    -121,
    -112,
    -115,
    -106,
    -109,
    -101,
    -104,
    -96,
    -100,
    -94,
    -99,
    -103,
    -98,
    -102,
    -108,
    -105,
    -112,
    -109,
    -117,
    -114,
    -122,
    -119,
    -126,
    -128,
    -125,
    -130,
    -127,
    -129,
  ];

  int _mix(int value) {
    var x = (value ^ seed) & 0x7fffffff;
    x = (x ^ (x << 13)) & 0x7fffffff;
    x = (x ^ (x >> 17)) & 0x7fffffff;
    x = (x ^ (x << 5)) & 0x7fffffff;
    return x & 0x7fffffff;
  }

  double _signed(int channel) {
    final value = _mix(channel * 1103515245 + 12345);
    return (value / 0x7fffffff) * 2 - 1;
  }

  double _boundaryKnot(int index) {
    final wrapped = index % _baseBoundary.length;
    final jitter = 2.8 * _signed(100 + wrapped);
    return _baseBoundary[wrapped] + jitter;
  }

  /// Closed 360-degree fracture loop defining the actual lower edge of F1.
  double f1BoundaryY(double angle) {
    var u = (angle + math.pi) / (2 * math.pi);
    u -= u.floorToDouble();
    final scaled = u * _baseBoundary.length;
    final index = scaled.floor();
    final t = scaled - index;
    final a = _boundaryKnot(index);
    final b = _boundaryKnot(index + 1);
    return (a + (b - a) * t).clamp(-133.0, -92.0).toDouble();
  }

  double get pressureAngle => .03 + .12 * _signed(700);

  double get pressureY => f1BoundaryY(pressureAngle);

  /// Open branches below the F1 loop. They do not create independent fragments
  /// yet; they are the future shared network from which neighbouring fragments
  /// can be derived.
  List<EggShellCrackBranch> get branches {
    EggShellCrackBranch branch({
      required int channel,
      required double startAngle,
      required double angleDrift,
      required double length,
    }) {
      final start =
          startAngle + .045 * _signed(channel) + .018 * _signed(channel + 1);
      final startY = f1BoundaryY(start);
      final p1 = EggShellCrackPoint(
        start + angleDrift * .26 + .025 * _signed(channel + 2),
        startY + length * .28,
      );
      final p2 = EggShellCrackPoint(
        start + angleDrift * .62 + .035 * _signed(channel + 3),
        startY + length * .63,
      );
      final p3 = EggShellCrackPoint(
        start + angleDrift + .03 * _signed(channel + 4),
        startY + length,
      );
      return EggShellCrackBranch([
        EggShellCrackPoint(start, startY),
        p1,
        p2,
        p3,
      ]);
    }

    final center = pressureAngle;
    return [
      branch(
        channel: 800,
        startAngle: center - .34,
        angleDrift: -.16,
        length: 39 + 5 * _signed(805),
      ),
      branch(
        channel: 820,
        startAngle: center + .02,
        angleDrift: .035,
        length: 47 + 6 * _signed(825),
      ),
      branch(
        channel: 840,
        startAngle: center + .35,
        angleDrift: .18,
        length: 36 + 5 * _signed(845),
      ),
    ];
  }
}
