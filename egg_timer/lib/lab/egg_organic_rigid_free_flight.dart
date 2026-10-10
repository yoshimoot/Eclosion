import 'dart:math' as math;

import 'egg_organic_release_seed.dart';
import 'egg_shell_model.dart';

/// V11.38 — deterministic rigid 3D flight of an ALREADY released organic
/// fragment. This object does not alter the earlier fracture/hinge pose.
///
/// The trajectory includes a finite normal-directed launch, fixed world
/// gravity, material spin, and the first vertex-to-ground impact. A simple
/// inelastic landing arrests spin and downward movement and damps horizontal
/// slide. Inter-object collisions (bowl, parents, other children) remain
/// UNSOLVED and must be certified before any painter uses this flight.
class EggOrganicRigidFreeFlight {
  EggOrganicRigidFreeFlight._(
    this.seed,
    this.launchSpeed,
    this.gravityAcceleration,
    this.angularSpeed,
    this.groundDamping,
    this.impactSeconds,
  );

  final EggOrganicReleaseSeed seed;
  final double launchSpeed;
  final double gravityAcceleration;
  final double angularSpeed;
  final double groundDamping;
  /// Actual earliest sampled/material-ground crossing, refined by bisection.
  /// Null only if none of the real vertices reaches ground in [0, 3] s.
  final double? impactSeconds;

  static EggShellPoint3 _cross(EggShellPoint3 a, EggShellPoint3 b) =>
      EggShellPoint3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  static double _dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  static EggShellPoint3 _rotate(
    EggShellPoint3 vector, EggShellPoint3 axis, double radians,
  ) {
    final c = math.cos(radians), s = math.sin(radians);
    return vector * c + _cross(axis, vector) * s +
        axis * (_dot(axis, vector) * (1 - c));
  }

  static void _checkSeconds(double t) {
    if (!t.isFinite || t < 0 || t > 3) {
      throw ArgumentError.value(t, 'seconds', 'Flight time must fit [0,3]');
    }
  }

  EggShellPoint3 _ballisticCenter(double t) =>
      seed.center +
      seed.outward * (launchSpeed * t) +
      EggShellPoint3(0, gravityAcceleration * t * t / 2, 0);

  factory EggOrganicRigidFreeFlight.fromSeed(
    EggOrganicReleaseSeed seed, {
    double launchSpeed = 32,
    double gravityAcceleration = 220,
    double angularSpeed = .48,
    double groundDamping = 8,
  }) {
    if (!launchSpeed.isFinite || launchSpeed < 0 ||
        !gravityAcceleration.isFinite || gravityAcceleration <= 0 ||
        !angularSpeed.isFinite ||
        !groundDamping.isFinite || groundDamping <= 0) {
      throw ArgumentError('Organic flight must have finite valid rates');
    }
    // Use only positions of the 3D faces; the side walls connect the same
    // endpoints and cannot protrude beyond the max of their vertices.
    final points = [...seed.outer, ...seed.inner];
    double clearance(double time) {
      final center = seed.center + seed.outward * (launchSpeed * time) +
          EggShellPoint3(0, gravityAcceleration * time * time / 2, 0);
      final angle = angularSpeed * time;
      var maxY = double.negativeInfinity;
      for (final point in points) {
        final rotated = _rotate(point - seed.center, seed.hingeAxis, angle);
        maxY = math.max(maxY, center.y + rotated.y);
      }
      return seed.floorY - maxY;
    }
    if (clearance(0) <= 0) {
      throw StateError('Organic fragment starts inside ground');
    }
    double? hit;
    var prior = 0.0;
    for (var step = 1; step <= 300; step++) {
      final next = step / 100;
      if (clearance(next) <= 0) {
        var lo = prior, hi = next;
        for (var iteration = 0; iteration < 32; iteration++) {
          final mid = (lo + hi) / 2;
          if (clearance(mid) > 0) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        hit = hi;
        break;
      }
      prior = next;
    }
    return EggOrganicRigidFreeFlight._(
      seed, launchSpeed, gravityAcceleration, angularSpeed, groundDamping,
      hit,
    );
  }

  /// Conservative speed envelopes for a future continuous-time collision
  /// inspector. After impact use the speed immediately BEFORE contact:
  /// the upper bound must remain valid for intervals that CROSS impact,
  /// even though the actual horizontal slide subsequently decelerates.
  double linearSpeedUpperBoundAt(double seconds) {
    _checkSeconds(seconds);
    return launchSpeed + gravityAcceleration *
        math.min(seconds, impactSeconds ?? seconds);
  }

  double angularSpeedUpperBoundAt(double seconds) {
    _checkSeconds(seconds);
    return angularSpeed.abs();
  }

  double materialVertexSpeedUpperBoundAt(double seconds) =>
      linearSpeedUpperBoundAt(seconds) +
      angularSpeedUpperBoundAt(seconds) * seed.materialRadius;

  double spinRadiansAt(double seconds) {
    _checkSeconds(seconds);
    final impact = impactSeconds;
    return angularSpeed * (impact == null
        ? seconds : math.min(seconds, impact));
  }

  EggShellPoint3 centerAt(double seconds) {
    _checkSeconds(seconds);
    final impact = impactSeconds;
    if (impact == null || seconds <= impact) {
      return _ballisticCenter(seconds);
    }
    // The rigid spin freezes at FIRST contact. Since vertex support stays
    // unchanged afterwards, the world Y of the centre must stay constant.
    final landed = _ballisticCenter(impact);
    final elapsed = seconds - impact;
    final decay = (1 - math.exp(-groundDamping * elapsed)) / groundDamping;
    final horizontal = seed.outward * launchSpeed;
    return EggShellPoint3(
      landed.x + horizontal.x * decay,
      landed.y,
      landed.z + horizontal.z * decay,
    );
  }

  /// Preserve original 3D surface lighting while the whole shell
  /// rotates as one rigid body after release and during ground settling.
  EggShellPoint3 rotateNormalAt(
    EggShellPoint3 originalAtRelease, double seconds,
  ) => _rotate(
    originalAtRelease, seed.hingeAxis, spinRadiansAt(seconds),
  ).normalized;

  EggShellPoint3 transform(
    EggShellPoint3 originalAtRelease, double seconds,
  ) {
    final center = centerAt(seconds);
    return center + _rotate(
      originalAtRelease - seed.center,
      seed.hingeAxis,
      spinRadiansAt(seconds),
    );
  }

  List<EggShellPoint3> transformAll(
    List<EggShellPoint3> atRelease, double seconds,
  ) {
    final center = centerAt(seconds), angle = spinRadiansAt(seconds);
    return List<EggShellPoint3>.unmodifiable([
      for (final point in atRelease)
        center + _rotate(point - seed.center, seed.hingeAxis, angle),
    ]);
  }

  /// The normalized 0–100% lab clock is NOT flight time. All daughters
  /// inherit the same existing mapping: .55..1 corresponds to 2 seconds.
  /// The free motion begins from each daughter's true hinge-release time.
  double elapsedAtProgress(double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(progress, 'progress');
    }
    if (progress <= seed.releaseProgress) return 0;
    return (progress - seed.releaseProgress) * (2 / .45);
  }
}
