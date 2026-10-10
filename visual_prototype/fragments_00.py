"""V11.57 standalone three-fragment material study of the 00:00 cradle.

Each piece is a physically closed curved shell solid on the SAME surface as
scene_00.build_shell(). Its lower cut reuses the exact source cradle rim vertex
coordinates, including the 2.5-unit inner cut. The fragments are at their
rest/source positions, before any displacement or animation.

Not a Blender-rendered final image; not wired to Flutter; no chick substitution.
"""
from dataclasses import dataclass
import math
from pathlib import Path
from scene_00 import (SECTORS, HALF_HEIGHT, THICKNESS, rim_y, surface,
                      inward_normal, build_shell, validate_shell)

# Indices refer to the SAME periodic 192-sector rim of scene_00; the left
# region has index >96 (negative signed angle). Intervals do NOT overlap.
# Broad rear-left panel reads above/behind the approved chick silhouette;
# two unequal small front pieces establish the raised chipped front edge.
FRAGMENT_SPECS = (
    ("rear_left_high", 107, 150, 94.0, 9.0, .31),
    ("front_left_small", 171, 186, 31.0, 6.0, .85),
    ("front_right_small", 8, 29, 24.0, 4.0, -.48),
)
LAYERS = 12

# V11.57: the rear-left chip must not look like a rectangular standing panel.
# These *fixed material stations* shape a sloping, non-symmetric, arched
# break. Heights are multiples of the rear panel rise in FRAGMENT_SPECS.
# The first and last stations taper close to the mother shell cut; the
# higher interior stations form the large bent piece behind the chick.
# No per-frame randomness, alpha blending, or edited mother rim.
REAR_TOP_STATIONS = (
    (0.00, 1.55), (.12, 1.67), (.29, 1.48), (.43, 1.55),
    (.54, 1.40), (.65, 1.27), (.73, 1.10), (.82, .79),
    (.92, .48), (1.00, .28),
)


def _rise_at(name, sector, start, end, rise, irregularity, phase):
    u = (sector - start) / (end - start)
    if name == 'rear_left_high':
        for (u0, factor0), (u1, factor1) in zip(
                REAR_TOP_STATIONS, REAR_TOP_STATIONS[1:]):
            if u <= u1:
                t = (u - u0) / (u1 - u0)
                return rise * (factor0 + (factor1 - factor0) * t)
        return rise * REAR_TOP_STATIONS[-1][1]
    # The two small front chips are frozen in V11.57.
    return rise + irregularity * (math.sin(5 * math.pi * u + phase)
                                  + .35 * math.sin(11 * math.pi * u - .2))


@dataclass(frozen=True)
class ShellPiece:
    name: str
    vertices: tuple
    faces: tuple
    rim_sector_indices: tuple
    lower_count: int
    thickness: float = THICKNESS

    @property
    def source_rim_outer(self):
        return self.vertices[:self.lower_count]

    @property
    def source_rim_inner(self):
        shift = len(self.vertices) // 2
        return self.vertices[shift:shift + self.lower_count]


def _material_angle(name, theta, u, t):
    # The large rear wall inclines inward toward the centre as it rises.
    # Its base stays on the original crack samples; no patch or projection.
    if name == 'rear_left_high':
        return theta - .37 * (1 - u) ** 2 * t
    return theta


def build_fragment(name, start_sector, end_sector, rise, irregularity, phase,
                   cradle_vertices, *, layers=LAYERS):
    """A solid curved shell patch; not a surface overlay or fake face.

    Rim points ARE source cradle coordinates. Interior is offset using the
    same inherited egg normal. Its other three boundaries are genuinely
    exposed material walls, not decorated strokes.
    """
    if not (0 <= start_sector < end_sector < SECTORS and layers >= 2):
        raise ValueError('Invalid disjoint shell fragment sector range')
    if not (0 < rise < HALF_HEIGHT and irregularity >= 0):
        raise ValueError('Invalid shell rise')
    sectors = tuple(range(start_sector, end_sector + 1))
    count = len(sectors)
    num_rows = layers + 1
    shift_cradle = len(cradle_vertices) // 2
    outer = []
    for row in range(num_rows):
        t = row / layers
        for sector in sectors:
            theta = 2 * math.pi * sector / SECTORS
            # This row and its inner face follow the SAME source surface.
            local_rise = _rise_at(name, sector, start_sector, end_sector,
                                  rise, irregularity, phase)
            y = rim_y(theta) - local_rise * t
            surface_angle = _material_angle(
                name, theta, (sector-start_sector)/(end_sector-start_sector), t)
            if not -HALF_HEIGHT < y < HALF_HEIGHT:
                raise ValueError('Fragment moves above the existing egg pole')
            outer.append(cradle_vertices[sector] if row == 0 else surface(y, surface_angle))
    inner = []
    for row in range(num_rows):
        for col, sector in enumerate(sectors):
            i = row * count + col
            if row == 0:
                inner.append(cradle_vertices[shift_cradle + sector])
            else:
                point = outer[i]
                theta = 2 * math.pi * sector / SECTORS
                y = rim_y(theta) - _rise_at(
                    name, sector, start_sector, end_sector,
                    rise, irregularity, phase) * row / layers
                surface_angle = _material_angle(
                    name, theta, (sector-start_sector)/(end_sector-start_sector), row/layers)
                inward = inward_normal(y, surface_angle)
                inner.append(tuple(point[k] + THICKNESS * inward[k] for k in range(3)))
    outer_faces = []
    for j in range(layers):
        for i in range(count - 1):
            a = j * count + i
            b = a + 1
            c = a + count
            d = c + 1
            outer_faces.extend(((a, b, c), (b, d, c)))
    shift = len(outer)
    faces = list(outer_faces)
    faces.extend(tuple(index + shift for index in reversed(tri)) for tri in outer_faces)
    # Triangulated sidewalls along the *actual* boundary of the outer grid.
    # The boundary is determined by half-edge ownership, never redrawn.
    directed = {}
    for a, b, c in outer_faces:
        for u, v in ((a, b), (b, c), (c, a)):
            key = min(u, v), max(u, v)
            directed.setdefault(key, []).append((u, v))
    perimeter = [ends[0] for ends in directed.values() if len(ends) == 1]
    if len(perimeter) != 2 * (count - 1) + 2 * layers:
        raise AssertionError('Fragment perimeter does not close')
    for u, v in perimeter:
        faces.extend(((v, u, u + shift), (v, u + shift, v + shift)))
    piece = ShellPiece(name, tuple(outer + inner), tuple(faces), sectors, count)
    validate_shell(piece.vertices, piece.faces)
    return piece


def build_piece_set():
    cradle_vertices, cradle_faces = build_shell()
    pieces = tuple(build_fragment(*spec, cradle_vertices) for spec in FRAGMENT_SPECS)
    validate_shared_material(cradle_vertices, pieces)
    return (cradle_vertices, cradle_faces), pieces


def validate_shared_material(cradle_vertices, pieces):
    """One material region per upper patch, two owners for every shared edge."""
    claimed = set()
    source_inner_start = len(cradle_vertices) // 2
    for piece in pieces:
        assert piece.thickness == THICKNESS
        for i, sector in enumerate(piece.rim_sector_indices):
            # Object identity: the lower physical cut is EXACTLY the cradle rim.
            if piece.source_rim_outer[i] is not cradle_vertices[sector]:
                raise ValueError('Upper/lower shell seams do not share outer vertices')
            if piece.source_rim_inner[i] is not cradle_vertices[source_inner_start + sector]:
                raise ValueError('Upper/lower shell seams do not share inner vertices')
        for a, b in zip(piece.rim_sector_indices, piece.rim_sector_indices[1:]):
            edge = a, b
            if edge in claimed:
                raise ValueError('Two fragments claim the same mother-shell rim edge')
            claimed.add(edge)
    return claimed


def save_obj(path, cradle, pieces):
    """OBJ with actual separate watertight materials, not grouped triangles."""
    with Path(path).open('w', encoding='utf-8') as out:
        offset = 0
        for name, vertices, faces in (
            ('lower_cradle', *cradle),
            *((piece.name, piece.vertices, piece.faces) for piece in pieces),
        ):
            out.write(f'o {name}\n')
            for x, y, z in vertices:
                out.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
            for a, b, c in faces:
                out.write(f'f {a + offset + 1} {b + offset + 1} {c + offset + 1}\n')
            offset += len(vertices)


if __name__ == '__main__':
    import sys
    cradle, pieces = build_piece_set()
    print('cradle', len(cradle[0]), len(cradle[1]))
    for piece in pieces:
        print(piece.name, len(piece.vertices), len(piece.faces))
    if '--obj' in sys.argv:
        i = sys.argv.index('--obj')
        save_obj(sys.argv[i + 1], cradle, pieces)
