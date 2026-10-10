import 'package:egg_timer/lab/egg_organic_full_shell_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.50: one graph owns the original and both future 360° cuts', () {
    final all = EggOrganicFullShellDraft.fixed();
    final original = all.partition.organic.draft;
    expect(original.edges.length, 55);
    expect(all.network.edges.length, 79);
    expect(all.crown.edgeOwners.length, 24);
    expect(all.cradle.cutEdgeIds.length, 24);
    expect(all.cradle.cutEdgeIds.first, 55);
    expect(all.cradle.cutEdgeIds.last, 78);
    expect(all.crown.partition, same(all.partition));
    expect(all.cradle.draft, same(all.network));
    expect(all.network.seed, original.seed);
    for (var i = 0; i < original.nodes.length; i++) {
      expect(all.network.nodes[i], same(original.nodes[i]));
    }
    for (var i = 0; i < original.edges.length; i++) {
      expect(all.network.edges[i], same(original.edges[i]));
    }
  });

  test('V11.50: neither the upper nor lower 3D cap is a fake crop', () {
    final all = EggOrganicFullShellDraft.fixed();
    final model = all.network.model;
    expect(all.crown.outer.last.y, -model.halfHeight);
    expect(all.cradle.outer.last.y, model.halfHeight);
    expect(all.crown.thickness, 2.5);
    expect(all.cradle.thickness, 2.5);
    expect(all.cradle.retainedHeightFraction,
        inInclusiveRange(.27, .32));
    // The lower edge is ready, but WITHOUT subtracting upper-side
    // fragments the complete shell is not a valid material partition.
    // The renderer MUST NOT yet draw the low bowl on top of old walls.
    expect(all.lowerSideRegionsAssigned, isFalse);
    expect(all.partition.organic.candidates.length, 3);
    expect(all.partition.originalRegions.regions.length, 2);
  });
}
