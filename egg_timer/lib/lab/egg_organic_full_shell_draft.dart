import 'egg_fracture_network.dart';
import 'egg_organic_bowl_partition.dart';
import 'egg_organic_crown_material.dart';
import 'egg_organic_lower_cradle_material.dart';

/// Single-source static shell structure for the NEXT side-fragment stage.
///
/// Completed material boundaries: V10.4 two parents, V11.33 three organic
/// daughters, original F1 cap, existing front/rear stationary shell.
/// Pending material boundaries: all new lower-cradle edges still need
/// adjacent upper-side *regions* that own the removed material. Until that
/// exact partition exists, neither the cap nor the low bowl is rendered
/// over the active V11.49 mesh.
class EggOrganicFullShellDraft {
  const EggOrganicFullShellDraft._(
    this.partition, this.network, this.crown, this.cradle,
  );

  final EggOrganicBowlPartition partition;
  final EggFractureNetwork network;
  final EggOrganicCrownMaterial crown;
  final EggOrganicLowerCradleMaterial cradle;

  /// True only when the upper-front and upper-rear side solids have
  /// obtained and subtracted their own triangles along the lower ring.
  /// V11.50 intentionally remains a validated static preparation,
  /// NEVER a claimed non-overlapping full-shell mesh partition.
  bool get lowerSideRegionsAssigned => false;

  factory EggOrganicFullShellDraft.fixed() {
    final partition = EggOrganicBowlPartition.fixed();
    final source = partition.organic.draft;
    final crown = EggOrganicCrownMaterial.build(partition: partition);
    final full = EggFractureNetwork.lowerCradleStaticDraft(
      model: source.model, organicSource: source,
    );
    final cradle = EggOrganicLowerCradleMaterial.build(draft: full);

    // Do not merely compare silhouettes. The original 55 crack edges
    // must be IDENTICAL material objects throughout all three assets.
    for (var i = 0; i < source.edges.length; i++) {
      if (!identical(full.edges[i], source.edges[i])) {
        throw StateError('Organic material edge $i was regenerated');
      }
    }
    if (!identical(crown.partition, partition) ||
        !identical(cradle.draft, full)) {
      throw StateError('Crown and cradle have different graph ownership');
    }
    return EggOrganicFullShellDraft._(
      partition, full, crown, cradle,
    );
  }
}
