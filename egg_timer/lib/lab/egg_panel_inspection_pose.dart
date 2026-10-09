import 'dart:math' as math;

import 'egg_shell_model.dart';

/// A reversible, rigid inspection pose for an existing shell panel.
///
/// This is NOT an egg-fracture motion model. All exterior, interior and
/// thickness-wall vertices are transformed by the SAME 3D rotation and
/// translation. The original EggShellPoint3 objects are never modified.
class EggPanelInspectionPose {
  const EggPanelInspectionPose._(
    this.centerX,
    this.centerZ,
    this.yawRadians,
    this.shiftX,
    this.shiftY,
  );

  final double centerX;
  final double centerZ;
  final double yawRadians;
  final double shiftX;
  final double shiftY;

  factory EggPanelInspectionPose.forPanel(
    List<EggShellPoint3> exterior, {
    required double yawDegrees,
    double shiftX = 0,
    double shiftY = 0,
  }) {
    if (exterior.isEmpty) {
      throw ArgumentError.value(exterior, 'exterior', 'Panel is empty');
    }
    if (!yawDegrees.isFinite || yawDegrees.abs() > 75) {
      throw ArgumentError.value(yawDegrees, 'yawDegrees');
    }
    if (!shiftX.isFinite || !shiftY.isFinite) {
      throw ArgumentError('Inspection translations must be finite');
    }
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minZ = double.infinity, maxZ = double.negativeInfinity;
    for (final point in exterior) {
      if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) {
        throw ArgumentError.value(point, 'exterior', 'Non-finite vertex');
      }
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minZ = math.min(minZ, point.z);
      maxZ = math.max(maxZ, point.z);
    }
    return EggPanelInspectionPose._(
      (minX + maxX) / 2,
      (minZ + maxZ) / 2,
      yawDegrees * math.pi / 180,
      shiftX,
      shiftY,
    );
  }

  /// Rotate about a vertical Y axis through the panel's own XZ centre,
  /// then apply a positional XY offset used only for diagnostic spacing.
  EggShellPoint3 transform(EggShellPoint3 point) {
    final x = point.x - centerX;
    final z = point.z - centerZ;
    final c = math.cos(yawRadians), s = math.sin(yawRadians);
    return EggShellPoint3(
      centerX + x * c + z * s + shiftX,
      point.y + shiftY,
      centerZ - x * s + z * c,
    );
  }

  /// Rotate a geometric normal with the SAME rigid matrix. Translation
  /// does not alter normals or lighting.
  EggShellPoint3 rotateNormal(EggShellPoint3 normal) {
    final c = math.cos(yawRadians), s = math.sin(yawRadians);
    return EggShellPoint3(
      normal.x * c + normal.z * s,
      normal.y,
      -normal.x * s + normal.z * c,
    );
  }

  List<EggShellPoint3> transformAll(List<EggShellPoint3> points) =>
      List<EggShellPoint3>.unmodifiable([
        for (final point in points) transform(point),
      ]);
}
