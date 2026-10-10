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

  test('V11.40: post-zero broad phase stays deterministic', () {
    final preflight = EggOrganicAabbPreflight.build();
    final now = preflight.inspect(1.0, afterZeroSeconds: .4);
    final same = preflight.inspect(1.0, afterZeroSeconds: .4);
    expect(now.bowlCandidatePairs, same.bowlCandidatePairs);
    expect(now.siblingCandidatePairs, same.siblingCandidatePairs);
    expect(now.complete, same.complete);
  });
}
