import 'package:egg_timer/lab/egg_organic_release_seed.dart';
import 'package:egg_timer/lab/egg_organic_staged_assembly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.37: release seed is the EXACT last attached 3D material pose',
      () {
    final staged = EggOrganicStagedAssembly.fixed();
    final graph = staged.meshes.partition.organic.draft;
    final seedCenters = <double>[];
    for (var i = 0; i < staged.hinges.length; i++) {
      final pose = staged.hinges[i];
      final mesh = staged.meshes.children[i];
      final seed = EggOrganicReleaseSeed.fromStaged(staged, i);

      expect(seed.childId, mesh.regionId);
      expect(seed.releaseProgress, pose.releaseProgress);
      expect(seed.releaseProgress,
          staged.attachments.children[i].hinge.ruptureProgress);
      expect(seed.outer.length, mesh.outer.length);
      expect(seed.inner.length, mesh.inner.length);
      expect(seed.materialRadius, greaterThan(1));
      expect(seed.outward.length, closeTo(1, 1e-9));
      expect(seed.hingeAxis.length, closeTo(1, 1e-9));
      expect(seed.floorY, graph.model.halfHeight + 8);
      expect(seed.center.x.isFinite && seed.center.y.isFinite &&
          seed.center.z.isFinite, isTrue);
      seedCenters.add(seed.center.x);

      for (var j = 0; j < seed.outer.length; j += 29) {
        expect((seed.outer[j] -
            pose.releasePositionOf(mesh.outer[j])).length,
            lessThan(1e-9));
        expect((seed.inner[j] -
            pose.releasePositionOf(mesh.inner[j])).length,
            lessThan(1e-9));
        expect((seed.outer[j] - seed.inner[j]).length,
            closeTo(mesh.thickness, 1e-7));
        expect((seed.outer[j] - seed.center).length,
            lessThanOrEqualTo(seed.materialRadius + 1e-8));
      }

      final fresh = EggOrganicReleaseSeed.fromStaged(staged, i);
      expect((fresh.center - seed.center).length, lessThan(1e-10));
      expect((fresh.outward - seed.outward).length, lessThan(1e-10));
      expect(fresh.releaseProgress, seed.releaseProgress);
    }
    expect(seedCenters.toSet().length, 3);
    expect(() => EggOrganicReleaseSeed.fromStaged(staged, -1),
        throwsRangeError);
    expect(() => EggOrganicReleaseSeed.fromStaged(staged, 3),
        throwsRangeError);
  });
}
