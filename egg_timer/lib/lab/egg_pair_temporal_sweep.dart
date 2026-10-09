import 'dart:math' as math;

import 'egg_panel_pair_collision.dart';
import 'egg_panel_release_motion.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// A sampled contact is not an exact time of impact. Only [certifiedClear]
/// excludes ALL contacts over the complete requested interval, under the
/// unchanged V11.13 rigid kinematic model and conservative motion bound.
enum EggPairSweepVerdict { certifiedClear, observedContact, inconclusive }

class EggPairSweepReport {
  const EggPairSweepReport({
    required this.verdict,
    required this.sampledFrames,
    required this.provenIntervals,
    required this.unresolvedIntervals,
    required this.testedPairs,
    required this.firstObservedTime,
    required this.firstObservedFrame,
  });

  final EggPairSweepVerdict verdict;
  final int sampledFrames, provenIntervals, unresolvedIntervals, testedPairs;
  final double? firstObservedTime;
  final EggPanelPairCollisionFrame? firstObservedFrame;

  bool get provenClear => verdict == EggPairSweepVerdict.certifiedClear;
  bool get hasObservedContact =>
      verdict == EggPairSweepVerdict.observedContact;
}

/// Conservative adaptive search over elapsed time for BOTH moving panels.
///
/// In the first panel's material frame, the second vertex follows:
///
/// q = M1 + R1^-1 (C2-C1 + R2*(p-M2)).
///
/// Its derivative magnitude is bounded by:
/// |v1| + |v2| + |w2|*r2 + |w1|*(|C2-C1| + r2).
/// C_i are release centres, v_i are bounded linear speeds, w_i the angular
/// rates, and r2 bounds all actual second-panel vertex radii.
///
/// At interval midpoint, every triangle box of the second panel expands
/// by maxRelativeSpeed * halfInterval. If no box overlaps the first panel's
/// prebuilt BVH, the ENTIRE interval is free of material triangle contact.
/// A possible overlap is subdivided, never silently declared safe.
class EggPairTemporalSweep {
  EggPairTemporalSweep({
    required EggShellPanelMesh first,
    required EggShellPanelMesh second,
    required EggPanelReleaseMotion firstMotion,
    required EggPanelReleaseMotion secondMotion,
    double tolerance = 1e-7,
  }) : _first = firstMotion,
       _second = secondMotion,
       _radius = _largestRadius(second, secondMotion.materialCenter),
       _pairs = EggPanelPairCollisionInspector(
         first: first,
         second: second,
         firstMotion: firstMotion,
         secondMotion: secondMotion,
         tolerance: tolerance,
       );

  final EggPanelReleaseMotion _first, _second;
  final EggPanelPairCollisionInspector _pairs;
  final double _radius;

  static double _largestRadius(EggShellPanelMesh panel,
      EggShellPoint3 materialCenter) {
    var r = 0.0;
    for (final point in [...panel.outer, ...panel.inner]) {
      r = math.max(r, (point - materialCenter).length);
    }
    if (!r.isFinite || r <= 0) {
      throw StateError('Invalid second-panel material radius');
    }
    return r;
  }

  static void _validWindow(double first, double second, double duration) {
    if (!first.isFinite || !second.isFinite || !duration.isFinite ||
        first < 0 || second < 0 || duration < 0 ||
        first + duration > 2 || second + duration > 2) {
      throw ArgumentError('Both release clocks must remain in [0, 2]');
    }
  }

  /// Upper bound on the displacement of any second-panel vertex in the
  /// original first-panel frame, from the midpoint to any point of this
  /// complete interval. Computed without sampling individual triangles.
  double displacementBound({
    required double firstStart,
    required double secondStart,
    required double duration,
  }) {
    _validWindow(firstStart, secondStart, duration);
    final h = duration / 2;
    // Include both orthogonal acceleration components: their sum is
    // an upper bound, including the V11.19 diagnostic departure impulse.
    final maxV1 = _first.initialSpeed +
        (_first.outwardAcceleration +
            _first.circumferentialAcceleration +
            _first.gravityAcceleration) * (firstStart + duration);
    final maxV2 = _second.initialSpeed +
        (_second.outwardAcceleration +
            _second.circumferentialAcceleration +
            _second.gravityAcceleration) * (secondStart + duration);
    final w1 = _first.spinDegreesPerSecond * math.pi / 180;
    final w2 = _second.spinDegreesPerSecond * math.pi / 180;
    final centerDistance = (
      _second.centerAt(secondStart + h) -
      _first.centerAt(firstStart + h)
    ).length;
    final distanceUpper = centerDistance + (maxV1 + maxV2) * h;
    final speedUpper = maxV1 + maxV2 +
        w2 * _radius + w1 * (distanceUpper + _radius);
    final bound = speedUpper * h;
    if (!bound.isFinite || bound < 0) {
      throw StateError('Non-finite temporal displacement envelope');
    }
    return bound;
  }

  EggPairSweepReport inspect({
    required double firstStart,
    required double secondStart,
    required double duration,
    int maxDepth = 7,
    int maxFrames = 24,
    int maxPairsPerFrame = 10000,
    double minInterval = .0125,
  }) {
    _validWindow(firstStart, secondStart, duration);
    if (maxDepth < 0 || maxDepth > 20 || maxFrames < 0 ||
        maxPairsPerFrame <= 0 || !minInterval.isFinite ||
        minInterval < 0) {
      throw ArgumentError('Invalid temporal diagnostic budget');
    }
    var frames = 0, proven = 0, unresolved = 0, tested = 0;
    double? observedTime;
    EggPanelPairCollisionFrame? observedFrame;

    bool traverse(double start, double end, int depth) {
      final span = end - start;
      final mid = start + span / 2;
      final bound = displacementBound(
        firstStart: firstStart + start,
        secondStart: secondStart + start,
        duration: span,
      );
      if (!_pairs.hasBroadPhaseCandidate(
        firstSeconds: firstStart + mid,
        secondSeconds: secondStart + mid,
        padding: bound,
      )) {
        proven++;
        return true;
      }
      if (frames >= maxFrames) {
        unresolved++;
        return false;
      }
      final result = _pairs.inspect(
        firstSeconds: firstStart + mid,
        secondSeconds: secondStart + mid,
        maxPairs: maxPairsPerFrame,
      );
      frames++;
      tested += result.testedPairs;
      if (result.hasContact) {
        observedTime = mid;
        observedFrame = result;
        return false;
      }
      if (!result.complete) {
        unresolved++;
        return false;
      }
      if (span == 0) {
        proven++;
        return true;
      }
      if (depth >= maxDepth || span <= minInterval) {
        unresolved++;
        return false;
      }
      final left = traverse(start, mid, depth + 1);
      if (observedFrame != null) return false;
      final right = traverse(mid, end, depth + 1);
      return left && right;
    }

    final clear = traverse(0, duration, 0);
    return EggPairSweepReport(
      verdict: observedFrame != null
          ? EggPairSweepVerdict.observedContact
          : clear && unresolved == 0
              ? EggPairSweepVerdict.certifiedClear
              : EggPairSweepVerdict.inconclusive,
      sampledFrames: frames,
      provenIntervals: proven,
      unresolvedIntervals: unresolved,
      testedPairs: tested,
      firstObservedTime: observedTime,
      firstObservedFrame: observedFrame,
    );
  }
}
