import 'egg_organic_full_shell_draft.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.51: actual material split of the previously fixed FRONT bowl into
/// an upper side band and the smaller lower-front cradle projection.
///
/// BOTH perimeters are based on the same graph-owned 3D bottom cut.
/// No overlay and no draw-time cropping: the upper side material MUST be
/// removed as explicit fragment meshes before the lower bowl is shown.
class EggOrganicUpperFrontBand {
  const EggOrganicUpperFrontBand._(
    this.shell, this.topPerimeter, this.lowerFrontArc,
    this.rightSeam, this.leftSeam, this.lowerFrontPerimeter,
    this.upperFrontPerimeter, this.originalEquivalentPerimeter,
  );

  final EggShellPanelMesh shell;
  final List<EggShellPoint3> topPerimeter;
  final List<EggShellPoint3> lowerFrontArc;
  final List<EggShellPoint3> rightSeam, leftSeam;
  final List<EggShellPoint3> lowerFrontPerimeter;
  final List<EggShellPoint3> upperFrontPerimeter;
  final List<EggShellPoint3> originalEquivalentPerimeter;

  static EggOrganicUpperFrontBand build({
    EggOrganicFullShellDraft? draft,
    int silhouetteSamples = 16,
    double thickness = 2.5,
  }) {
    if (silhouetteSamples < 4 || silhouetteSamples > 128) {
      throw ArgumentError.value(silhouetteSamples, 'silhouetteSamples');
    }
    final plan = draft ?? EggOrganicFullShellDraft.fixed();
    if (thickness != plan.cradle.thickness ||
        thickness != plan.crown.thickness) {
      throw ArgumentError('Every shared shell region needs one thickness');
    }
    final graph = plan.network;
    final model = graph.model;
    final top = <EggShellPoint3>[];
    for (final edge in plan.partition.frontUpperBoundary) {
      final samples = edge.samples(graph);
      top.addAll(top.isEmpty ? samples : samples.skip(1));
    }
    final bottomFront = <EggShellPoint3>[];
    for (var i = 6; i < 18; i++) {
      final edge = graph.edges[plan.cradle.cutEdgeIds[i]];
      bottomFront.addAll(
        bottomFront.isEmpty ? edge.samples : edge.samples.skip(1),
      );
    }
    if (top.length < 3 || bottomFront.length < 3 ||
        top.first.x >= 0 || top.last.x <= 0 ||
        bottomFront.first.x >= 0 || bottomFront.last.x <= 0) {
      throw StateError('Missing front crack limits');
    }
    final highestOldCut = top.map((p) => p.y).reduce(
        (a, b) => a > b ? a : b);
    final lowestNewCut = bottomFront.map((p) => p.y).reduce(
        (a, b) => a < b ? a : b);
    if (highestOldCut >= lowestNewCut) {
      throw StateError('New lower seam intersects old front fracture');
    }
    List<EggShellPoint3> silhouette(
      EggShellPoint3 from, EggShellPoint3 to, double angle,
    ) => List<EggShellPoint3>.unmodifiable([
      for (var i = 0; i <= silhouetteSamples; i++)
        i == 0 ? from
            : i == silhouetteSamples ? to
            : model.pointAt(
                from.y + (to.y - from.y) * i / silhouetteSamples,
                angle,
              ),
    ]);
    final topRightToLow = silhouette(
        top.last, bottomFront.last, 1.5707963267948966);
    final lowLeftToTop = silhouette(
        bottomFront.first, top.first, -1.5707963267948966);
    final lowRightToPole = silhouette(
        bottomFront.last, model.pointAt(model.halfHeight, 0),
        1.5707963267948966);
    final poleToLowLeft = silhouette(
        lowRightToPole.last, bottomFront.first, -1.5707963267948966);

    List<EggShellPoint3> close(
      List<EggShellPoint3> raw,
    ) => List<EggShellPoint3>.unmodifiable([
      ...raw,
      raw.first,
    ]);

    // Each perimeter excludes its duplicate closing vertex until close().
    final upper = close([
      ...top,
      ...topRightToLow.skip(1),
      ...bottomFront.reversed.skip(1),
      ...lowLeftToTop.skip(1).take(lowLeftToTop.length - 2),
    ]);
    final lower = close([
      ...bottomFront,
      ...lowRightToPole.skip(1),
      ...poleToLowLeft.skip(1).take(poleToLowLeft.length - 2),
    ]);
    final original = close([
      ...top,
      ...topRightToLow.skip(1),
      ...lowRightToPole.skip(1),
      ...poleToLowLeft.skip(1),
      ...lowLeftToTop.skip(1).take(lowLeftToTop.length - 2),
    ]);
    for (final perimeter in [upper, lower, original]) {
      if ((perimeter.first - perimeter.last).length > 1e-8) {
        throw StateError('Disconnected material perimeter');
      }
    }
    final mesh = EggShellPanelMeshBuilder.fromClosedPerimeter(
      model: model,
      regionId: 'upper-front-side-band',
      closedPerimeter: upper,
      thickness: thickness,
      maxEdgeXY: 24,
    );
    return EggOrganicUpperFrontBand._(
      mesh,
      List<EggShellPoint3>.unmodifiable(top),
      List<EggShellPoint3>.unmodifiable(bottomFront),
      topRightToLow,
      lowLeftToTop,
      lower,
      upper,
      original,
    );
  }

  static double projectedArea(List<EggShellPoint3> boundary) {
    var signed = 0.0;
    for (var i = 0; i + 1 < boundary.length; i++) {
      final a = boundary[i], b = boundary[i + 1];
      signed += a.x * b.y - b.x * a.y;
    }
    return signed.abs() / 2;
  }

  double get areaResidual =>
      projectedArea(upperFrontPerimeter) +
      projectedArea(lowerFrontPerimeter) -
      projectedArea(originalEquivalentPerimeter);
}
