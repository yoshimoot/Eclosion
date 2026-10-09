import 'dart:math' as math;

import 'egg_panel_release_motion.dart';
import 'egg_shell_collision_diagnostic.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';
import 'egg_full_bowl_mesh.dart';

/// Only a conservative, model-relative conclusion is allowed.
/// An observedContact has a sampled timestamp, not a solved impact time.
enum EggBowlSweepVerdict { certifiedClear, observedContact, inconclusive }

class EggBowlSweepReport {
  const EggBowlSweepReport({
    required this.verdict,
    required this.sampledFrames,
    required this.provenIntervals,
    required this.unresolvedIntervals,
    required this.testedPairs,
    required this.firstObservedTime,
    required this.firstObservedFrame,
  });

  final EggBowlSweepVerdict verdict;
  final int sampledFrames;
  final int provenIntervals;
  final int unresolvedIntervals;
  final int testedPairs;
  /// Offset from the requested interval start, NOT time of first impact.
  final double? firstObservedTime;
  final EggBowlCollisionFrame? firstObservedFrame;

  bool get provenClear => verdict == EggBowlSweepVerdict.certifiedClear;
  bool get hasObservedContact =>
      verdict == EggBowlSweepVerdict.observedContact;
}

/// V11.17: continuous-interval conservatism for panel-vs-fixed-bowl checks.
///
/// The fixed bowl is in world coordinates. A rigid released vertex follows
///
/// p(t) = centerAt(t) + R(spin(t))*(hingedPoint - releaseCenter).
///
/// Therefore |p'(t)| <= v0 + a*t + |omega|*r_max.
/// Rates in V11.13 are non-negative, so the interval's END bounds speed.
/// At its midpoint, expanding each moving triangle AABB by
/// maxSpeed * halfDuration bounds every vertex for the WHOLE interval.
///
/// A broad-phase miss proves no triangle contact on that interval under
/// the exact V11.13 kinematics. A candidate is subdivided or marked
/// inconclusive; instantaneous sample hits are only observations.
/// This does not resolve physical collisions, falling impacts, or fracture.
class EggBowlTemporalSweep {
  EggBowlTemporalSweep({
    required EggFullBowlMesh bowl,
    required EggShellPanelMesh panel,
    required EggPanelReleaseMotion motion,
    double tolerance = 1e-7,
  }) : _motion = motion,
       _radius = _maxRadius(panel, motion.materialCenter),
       _inspector = EggBowlCollisionInspector(
         bowl: bowl,
         panel: panel,
         motion: motion,
         tolerance: tolerance,
       );

  final EggPanelReleaseMotion _motion;
  final double _radius;
  final EggBowlCollisionInspector _inspector;

  static double _maxRadius(
    EggShellPanelMesh panel,
    EggShellPoint3 materialCenter,
  ) {
    var radius = 0.0;
    for (final vertex in [...panel.outer, ...panel.inner]) {
      radius = math.max(radius, (vertex - materialCenter).length);
    }
    if (!radius.isFinite || radius <= 0) {
      throw StateError('Empty or degenerate shell release radius');
    }
    return radius;
  }

  static void _validateWindow(double start, double duration) {
    if (!start.isFinite || start < 0 ||
        !duration.isFinite || duration < 0 ||
        start + duration > 2) {
      throw ArgumentError('Release time interval must fit [0, 2]');
    }
  }

  /// Bound on the displacement of every vertex from an interval midpoint
  /// to any other time within the same interval (including end points).
  double displacementBound({
    required double start,
    required double duration,
  }) {
    _validateWindow(start, duration);
    // Each component follows its real V11.27 activation clock, while
    // preserving the conservative triangle inequality. Their speeds
    // increase monotonically, so the interval endpoint bounds all times.
    final end = start + duration;
    final maxLinearSpeed = _motion.linearSpeedUpperBoundAt(end);
    final angularSpeed = _motion.angularSpeedUpperBoundAt(end);
    final result =
        (maxLinearSpeed + angularSpeed * _radius) * duration / 2;
    if (!result.isFinite || result < 0) {
      throw StateError('Non-finite bound for stationary shell collision');
    }
    return result;
  }

  EggBowlSweepReport inspect({
    required double start,
    required double duration,
    int maxDepth = 7,
    int maxFrames = 24,
    int maxPairsPerFrame = 10000,
    double minInterval = .0125,
  }) {
    _validateWindow(start, duration);
    if (maxDepth < 0 || maxDepth > 20 || maxFrames < 0 ||
        maxPairsPerFrame <= 0 ||
        !minInterval.isFinite || minInterval < 0) {
      throw ArgumentError('Invalid stationary-shell sweep budget');
    }

    var frames = 0, proven = 0, unresolved = 0, tested = 0;
    double? observedTime;
    EggBowlCollisionFrame? observedFrame;

    bool traverse(double low, double high, int depth) {
      final length = high - low;
      final middle = low + length / 2;
      final bound = displacementBound(
        start: start + low,
        duration: length,
      );
      if (!_inspector.hasBroadPhaseCandidate(
        seconds: start + middle,
        padding: bound,
      )) {
        proven++;
        return true;
      }
      if (frames >= maxFrames) {
        unresolved++;
        return false;
      }
      final frame = _inspector.inspect(
        start + middle,
        maxPairs: maxPairsPerFrame,
      );
      frames++;
      tested += frame.testedPairs;
      if (frame.hasContact) {
        observedTime = middle;
        observedFrame = frame;
        return false;
      }
      if (!frame.complete) {
        unresolved++;
        return false;
      }
      if (length == 0) {
        proven++;
        return true;
      }
      if (depth >= maxDepth || length <= minInterval) {
        unresolved++;
        return false;
      }
      final left = traverse(low, middle, depth + 1);
      if (observedFrame != null) return false;
      final right = traverse(middle, high, depth + 1);
      return left && right;
    }

    final allClear = traverse(0, duration, 0);
    return EggBowlSweepReport(
      verdict: observedFrame != null
          ? EggBowlSweepVerdict.observedContact
          : allClear && unresolved == 0
              ? EggBowlSweepVerdict.certifiedClear
              : EggBowlSweepVerdict.inconclusive,
      sampledFrames: frames,
      provenIntervals: proven,
      unresolvedIntervals: unresolved,
      testedPairs: tested,
      firstObservedTime: observedTime,
      firstObservedFrame: observedFrame,
    );
  }
}
