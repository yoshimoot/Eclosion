import 'package:egg_timer/lab/egg_organic_aabb_preflight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.40: broad phase reports possible contacts without certifying safety',
      () {
    final preflight = EggOrganicAabbPreflight.build();
    for (final progress in [0.0, .55, .72, .84, .93, 1.0]) {
      final report = preflight.inspect(progress);
      final repeated = preflight.inspect(progress);
      expect(report.progress, progress);
      expect(report.bowlCandidatePairs.length, 3);
      expect(report.siblingCandidatePairs.length, 3);
      expect(report.bowlCandidatePairs, repeated.bowlCandidatePairs);
      expect(report.siblingCandidatePairs,
          repeated.siblingCandidatePairs);
      expect(report.complete, repeated.complete);
      for (final count in [
        ...report.bowlCandidatePairs,
        ...report.siblingCandidatePairs.values,
      ]) {
        expect(count, inInclusiveRange(0, 20000));
      }
      // A nonzero candidate count is NOT proven triangle penetration;
      // even a zero count applies only to this sampled visible front shell.
    }
  });

  test('V11.40: a saturated collision budget cannot report full inspection',
      () {
    final preflight = EggOrganicAabbPreflight.build();
    final report = preflight.inspect(0.0, maxCandidatesPerPair: 1);
    expect(report.hasAnyPossibleContact, isTrue,
        reason: 'All organic children begin touching their cut rims');
    expect(report.complete, isFalse,
        reason: 'Candidate truncation must never be read as clear');
    expect(() => preflight.inspect(.4, maxCandidatesPerPair: 0),
        throwsArgumentError);
    expect(() => preflight.inspect(double.nan), throwsArgumentError);
    expect(() => preflight.inspect(.9, afterZeroSeconds: .1),
        throwsArgumentError);
  });

  test('V11.41: exact sampled contacts use shared 3D triangle kernel',
      () {
    final preflight = EggOrganicAabbPreflight.build();
    for (final progress in [0.0, .55, .84, 1.0]) {
      final report = preflight.inspectExact(
        progress, maxPairsPerPair: 1200,
      );
      final repeated = preflight.inspectExact(
        progress, maxPairsPerPair: 1200,
      );
      expect(report.progress, progress);
      expect(report.bowlTouching.length, 3);
      expect(report.bowlIntersections.length, 3);
      expect(report.siblingTouching.length, 3);
      expect(report.siblingIntersections.length, 3);
      expect(report.bowlTouching, repeated.bowlTouching);
      expect(report.bowlIntersections, repeated.bowlIntersections);
      expect(report.siblingTouching, repeated.siblingTouching);
      expect(report.siblingIntersections, repeated.siblingIntersections);
      expect(report.complete, repeated.complete);
      expect(report.testedPairs, repeated.testedPairs);
      expect(report.testedPairs, inInclusiveRange(0, 7200));
      for (final pair in [
        ...report.bowlTouching,
        ...report.bowlIntersections,
        ...report.siblingTouching.values,
        ...report.siblingIntersections.values,
      ]) {
        expect(pair, greaterThanOrEqualTo(0));
      }
      // Do NOT assert collision-free without inspecting all generated
      // surfaces. Existing connected source seams may legitimately touch.
    }
  });

  test('V11.41: partial narrow phase cannot certify a collision-free frame',
      () {
    final preflight = EggOrganicAabbPreflight.build();
    final incomplete = preflight.inspectExact(
      0.0, maxPairsPerPair: 1,
    );
    expect(incomplete.complete, isFalse);
    expect(incomplete.sampledFrameClear, isFalse);
    expect(incomplete.testedPairs, greaterThan(0));
    expect(() => preflight.inspectExact(
      .5, maxPairsPerPair: 0,
    ), throwsArgumentError);
    final future = preflight.inspectExact(
      1.0, afterZeroSeconds: .2, maxPairsPerPair: 1000,
    );
    expect(future.testedPairs, greaterThanOrEqualTo(0));
  });

  test('V11.42: exact sampled 3D contacts include parents and rear bowl',
      () {
    final preflight = EggOrganicEnvironmentPreflight.build();
    expect(preflight.parents.length, 2);
    expect(preflight.parentMeshes.length, 2);
    for (final time in [.55, .82, 1.0]) {
      final frame = preflight.inspectExact(
        time, maxPairsPerPair: 180,
      );
      final repeated = preflight.inspectExact(
        time, maxPairsPerPair: 180,
      );
      expect(frame.rearTouching.length, 3);
      expect(frame.rearIntersections.length, 3);
      expect(frame.parentTouching.length, 6);
      expect(frame.parentIntersections.length, 6);
      expect(frame.testedPairs,
          greaterThanOrEqualTo(frame.frontAndSiblings.testedPairs));
      expect(frame.testedPairs, repeated.testedPairs);
      expect(frame.complete, repeated.complete);
      expect(frame.parentTouching, repeated.parentTouching);
      expect(frame.parentIntersections, repeated.parentIntersections);
      expect(frame.rearTouching, repeated.rearTouching);
      expect(frame.rearIntersections, repeated.rearIntersections);
      expect(frame.testedPairs, inInclusiveRange(0, 2700));
    }
    final after = preflight.inspectExact(
      1.0, afterZeroSeconds: .2, maxPairsPerPair: 90,
    );
    expect(after.testedPairs, greaterThanOrEqualTo(0));
    // The per-frame exact results are diagnostic, not a continuous
    // proof or a collision response.
  });

  test('V11.42: limited parent/rear checks cannot imply full clearance',
      () {
    final preflight = EggOrganicEnvironmentPreflight.build();
    final frame = preflight.inspectExact(.55, maxPairsPerPair: 1);
    expect(frame.complete, isFalse);
    expect(frame.sampledFrameClear, isFalse);
    expect(() => preflight.inspectExact(.4), throwsArgumentError);
    expect(() => preflight.inspectExact(double.nan), throwsArgumentError);
    expect(() => preflight.inspectExact(.7, maxPairsPerPair: 0),
        throwsArgumentError);
  });

  test('V11.43: exact collision envelopes distinguish proof from sample',
      () {
    final preflight = EggOrganicEnvironmentPreflight.build();
    for (final (start, end) in [
      (.55, .57),
      (.79, .81),
      (.94, .96),
    ]) {
      final first = preflight.inspectInterval(
        startProgress: start, endProgress: end,
        maxBoxChecksPerPair: 20000,
        maxExactPairsPerPair: 300,
      );
      final again = preflight.inspectInterval(
        startProgress: start, endProgress: end,
        maxBoxChecksPerPair: 20000,
        maxExactPairsPerPair: 300,
      );
      expect(first.verdict, again.verdict);
      expect(first.envelopeComplete, again.envelopeComplete);
      expect(first.sampledExactComplete, again.sampledExactComplete);
      if (first.verdict == EggOrganicIntervalVerdict.certifiedClear) {
        expect(first.envelopeComplete, isTrue);
        for (final progress in [start, (start + end) / 2, end]) {
          final sample = preflight.inspectExact(
            progress, maxPairsPerPair: 300,
          );
          expect(sample.hasObservedIntersection, isFalse);
        }
      } else if (first.verdict ==
          EggOrganicIntervalVerdict.observedIntersection) {
        final sample = preflight.inspectExact(
          (start + end) / 2, maxPairsPerPair: 300,
        );
        expect(sample.hasObservedIntersection, isTrue);
      }
      // An inconclusive verdict MUST NOT be reinterpreted as safety.
    }
  });

  test('V11.43: reject unbounded or invalid continuous time windows', () {
    final preflight = EggOrganicEnvironmentPreflight.build();
    expect(() => preflight.inspectInterval(
      startProgress: .5, endProgress: .8,
    ), throwsArgumentError);
    expect(() => preflight.inspectInterval(
      startProgress: .8, endProgress: 1.01,
    ), throwsArgumentError);
    expect(() => preflight.inspectInterval(
      startProgress: .8, endProgress: .8,
    ), throwsArgumentError);
    expect(() => preflight.inspectInterval(
      startProgress: .82, endProgress: .80,
    ), throwsArgumentError);
    expect(() => preflight.inspectInterval(
      startProgress: .8, endProgress: .83,
      maxBoxChecksPerPair: 0,
    ), throwsArgumentError);
    expect(() => preflight.inspectInterval(
      startProgress: double.nan, endProgress: .9,
    ), throwsArgumentError);
  });

  test('V11.40: post-zero broad phase stays deterministic', () {
    final preflight = EggOrganicAabbPreflight.build();
    final now = preflight.inspect(1.0, afterZeroSeconds: .4);
    final same = preflight.inspect(1.0, afterZeroSeconds: .4);
    expect(now.bowlCandidatePairs, same.bowlCandidatePairs);
    expect(now.siblingCandidatePairs, same.siblingCandidatePairs);
    expect(now.complete, same.complete);
  });
}
