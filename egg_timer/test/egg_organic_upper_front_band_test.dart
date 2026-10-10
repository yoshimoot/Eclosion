import 'package:egg_timer/lab/egg_organic_full_shell_draft.dart';
import 'package:egg_timer/lab/egg_organic_upper_front_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.51: front side material is split by real lower 3D crack', () {
    final full = EggOrganicFullShellDraft.fixed();
    final band = EggOrganicUpperFrontBand.build(draft: full);
    expect(band.shell.regionId, 'upper-front-side-band');
    expect(band.shell.thickness, 2.5);
    expect(band.shell.outerTriangles, isNotEmpty);
    expect(band.shell.innerTriangles, isNotEmpty);
    expect(band.shell.sideTriangles, isNotEmpty);
    expect(band.topPerimeter.length, greaterThan(2));

    // All 12 low-front graph edges appear once in the same left-to-right
    // orientation along BOTH sides of the material partition.
    final lowerGraph = <Object>[];
    for (var id = 6; id < 18; id++) {
      final samples = full.network.edges[full.cradle.cutEdgeIds[id]].samples;
      lowerGraph.addAll(lowerGraph.isEmpty ? samples : samples.skip(1));
    }
    final lower = band.lowerFrontPerimeter;
    final upper = band.upperFrontPerimeter;
    for (final point in lowerGraph) {
      expect(lower.any((p) => identical(p, point)), isTrue);
      expect(upper.any((p) => identical(p, point)), isTrue);
    }
    expect((lower.first - lower.last).length, lessThan(1e-10));
    expect((upper.first - upper.last).length, lessThan(1e-10));
    expect((band.originalEquivalentPerimeter.first -
            band.originalEquivalentPerimeter.last).length,
        lessThan(1e-10));
  });

  test('V11.51: cutting the front shell conserves projected material area',
      () {
    final band = EggOrganicUpperFrontBand.build();
    final upperArea = EggOrganicUpperFrontBand.projectedArea(
        band.upperFrontPerimeter);
    final lowerArea = EggOrganicUpperFrontBand.projectedArea(
        band.lowerFrontPerimeter);
    final before = EggOrganicUpperFrontBand.projectedArea(
        band.originalEquivalentPerimeter);
    expect(upperArea, greaterThan(0));
    expect(lowerArea, greaterThan(0));
    expect(before, closeTo(upperArea + lowerArea, 1e-4));
    expect(band.areaResidual.abs(), lessThan(1e-4));
    // This proves a non-overlapping FRONT material split only. The rear
    // band and the upper-side motions are still awaiting construction.
    expect(() => EggOrganicUpperFrontBand.build(
      silhouetteSamples: 2,
    ), throwsArgumentError);
    expect(() => EggOrganicUpperFrontBand.build(
      thickness: 3,
    ), throwsArgumentError);
  });
}
