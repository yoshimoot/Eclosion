import 'package:egg_timer/lab/egg_organic_release_seed.dart';
import 'package:egg_timer/lab/egg_organic_rigid_free_flight.dart';
import 'package:egg_timer/lab/egg_organic_staged_assembly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.38: flight starts at the exact hinged release pose', () {
    final staged = EggOrganicStagedAssembly.fixed();
    for (var i = 0; i < staged.hinges.length; i++) {
      final seed = EggOrganicReleaseSeed.fromStaged(staged, i);
      final flight = EggOrganicRigidFreeFlight.fromSeed(seed);
      expect(flight.impactSeconds, isNotNull);
      expect(flight.impactSeconds!, inExclusiveRange(0, 3.0));
      expect(flight.elapsedAtProgress(seed.releaseProgress), 0);
      expect(flight.elapsedAtProgress(1), greaterThan(0));
      expect(flight.elapsedAtProgress(1), lessThan(2));
      expect(flight.spinRadiansAt(0), 0);
      expect((flight.centerAt(0) - seed.center).length, lessThan(1e-12));

      for (var j = 0; j < seed.outer.length; j += 29) {
        expect((flight.transform(seed.outer[j], 0) -
                seed.outer[j]).length, lessThan(1e-10));
        expect((flight.transform(seed.inner[j], 0) -
                seed.inner[j]).length, lessThan(1e-10));
      }
      final first = flight.transformAll(seed.outer, .2);
      final second = flight.transformAll(seed.inner, .2);
      for (var j = 0; j < first.length; j += 31) {
        expect((first[j] - second[j]).length,
            closeTo(staged.meshes.children[i].thickness, 1e-7));
        expect((first[j] - flight.transform(seed.outer[j], .2)).length,
            lessThan(1e-9));
      }
      expect(() => flight.centerAt(-.01), throwsArgumentError);
      expect(() => flight.centerAt(3.01), throwsArgumentError);
      expect(() => flight.elapsedAtProgress(double.nan), throwsArgumentError);
    }
  });

  test('V11.38: first REAL material-floor contact arrests spin and Y fall',
      () {
    final staged = EggOrganicStagedAssembly.fixed();
    for (var i = 0; i < staged.hinges.length; i++) {
      final seed = EggOrganicReleaseSeed.fromStaged(staged, i);
      final flight = EggOrganicRigidFreeFlight.fromSeed(seed);
      final impact = flight.impactSeconds!;
      final contactSpin = flight.spinRadiansAt(impact);

      for (final time in [
        0.0, .15, .4, impact / 2, impact,
        (impact + 3) / 2, 3.0,
      ]) {
        var lowest = double.negativeInfinity;
        for (final face in [seed.outer, seed.inner]) {
          final placed = flight.transformAll(face, time);
          for (final vertex in placed) {
            if (vertex.y > lowest) lowest = vertex.y;
          }
        }
        expect(lowest, lessThanOrEqualTo(seed.floorY + 1e-5),
            reason: 'Child $i penetrated floor at t=$time');
        if (time >= impact) {
          expect(lowest, closeTo(seed.floorY, 1e-5));
          expect(flight.spinRadiansAt(time),
              closeTo(contactSpin, 1e-12));
          expect(flight.centerAt(time).y,
              closeTo(flight.centerAt(impact).y, 1e-9));
        }
      }
      final hit = flight.centerAt(impact);
      final justAfter = flight.centerAt(impact + .000001);
      expect((justAfter - hit).length, lessThan(.001));
      final again = EggOrganicRigidFreeFlight.fromSeed(seed);
      expect(again.impactSeconds, closeTo(impact, 1e-10));
      expect((again.centerAt(3) - flight.centerAt(3)).length,
          lessThan(1e-10));
      // The painter is deliberately NOT wired to this isolated motor
      // until stationary bowl, parent and sibling collisions are checked.
    }
  });

  test('V11.38: invalid physical controls cannot generate shell motion', () {
    final staged = EggOrganicStagedAssembly.fixed();
    final seed = EggOrganicReleaseSeed.fromStaged(staged, 0);
    expect(() => EggOrganicRigidFreeFlight.fromSeed(
        seed, gravityAcceleration: -1), throwsArgumentError);
    expect(() => EggOrganicRigidFreeFlight.fromSeed(
        seed, launchSpeed: double.nan), throwsArgumentError);
    expect(() => EggOrganicRigidFreeFlight.fromSeed(
        seed, groundDamping: 0), throwsArgumentError);
    expect(() => EggOrganicRigidFreeFlight.fromSeed(
        seed, angularSpeed: double.infinity), throwsArgumentError);
  });
}
