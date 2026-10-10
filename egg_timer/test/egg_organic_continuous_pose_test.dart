import 'package:egg_timer/lab/egg_organic_continuous_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.39: no jump or size change between hinge and free flight', () {
    final coordinator = EggOrganicContinuousPoseCoordinator.fixed();
    expect(coordinator.flights.length, 3);
    const epsilon = 1e-6;
    for (var i = 0; i < coordinator.flights.length; i++) {
      final seed = coordinator.seeds[i];
      final pointBefore = coordinator.poseAt(i, seed.releaseProgress-epsilon);
      final onRelease = coordinator.poseAt(i, seed.releaseProgress);
      expect(pointBefore.phase, EggOrganicMotionPhase.attached);
      expect(onRelease.phase, EggOrganicMotionPhase.flying);
      expect(onRelease.mesh, same(pointBefore.mesh));
      expect(onRelease.outer.length, pointBefore.outer.length);
      expect(onRelease.inner.length, pointBefore.inner.length);
      for (var j = 0; j < onRelease.outer.length; j += 17) {
        expect((pointBefore.outer[j] - onRelease.outer[j]).length,
            lessThan(.01),
            reason: 'The shell must not be re-created when the hinge breaks');
        expect((pointBefore.inner[j] - onRelease.inner[j]).length,
            lessThan(.01));
      }
      final finalCountdown = coordinator.poseAt(i, 1);
      expect(finalCountdown.outer.length, onRelease.outer.length);
      for (var j = 0; j < finalCountdown.outer.length; j += 29) {
        expect((finalCountdown.outer[j] -
                finalCountdown.inner[j]).length,
            closeTo(2.5, 1e-7));
      }
      // Subsequent residual fall is allowed after 00:00, but never
      // changes the actual time at which the shell first detached.
      final afterZero = coordinator.poseAt(i, 1, afterZeroSeconds: .25);
      expect(afterZero.outer.length, finalCountdown.outer.length);
      expect(afterZero.mesh, same(finalCountdown.mesh));
      expect((afterZero.outer[0] - finalCountdown.outer[0]).length,
          greaterThan(0));
    }
  });

  test('V11.39: playback order and post-zero time cannot corrupt pose',
      () {
    final coordinator = EggOrganicContinuousPoseCoordinator.fixed();
    for (var i = 0; i < 3; i++) {
      final progress = coordinator.seeds[i].releaseProgress;
      final ordered = [
        0.0, .3, progress - .0001, progress,
        .98, 1.0, .55, .0, 1.0,
      ];
      final expectedAtStart = coordinator.poseAt(i, 0);
      for (final p in ordered) {
        final current = coordinator.poseAt(i, p);
        final repeated = coordinator.poseAt(i, p);
        expect(current.phase, repeated.phase);
        expect((current.outer[0] - repeated.outer[0]).length,
            lessThan(1e-10));
        expect((current.inner[0] - repeated.inner[0]).length,
            lessThan(1e-10));
      }
      expect((coordinator.poseAt(i, 0).outer[0] -
              expectedAtStart.outer[0]).length, lessThan(1e-10));
    }
    expect(() => coordinator.poseAt(-1, .2), throwsRangeError);
    expect(() => coordinator.poseAt(3, .2), throwsRangeError);
    expect(() => coordinator.poseAt(0, double.nan), throwsArgumentError);
    expect(() => coordinator.poseAt(0, 1.02), throwsArgumentError);
    expect(() => coordinator.poseAt(0, .5, afterZeroSeconds: .1),
        throwsArgumentError);
    expect(() => coordinator.poseAt(0, 1, afterZeroSeconds: 3.1),
        throwsArgumentError);
  });
}
