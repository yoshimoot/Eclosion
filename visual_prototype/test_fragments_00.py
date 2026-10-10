"""Static material-contract checks, independent of Blender/Flutter."""
import math
import unittest

from fragments_00 import (build_piece_set, validate_shared_material,
                          FRAGMENT_SPECS, REAR_TOP_STATIONS, THICKNESS, SECTORS)
from scene_00 import rim_y


class SharedFragmentsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cradle, cls.pieces = build_piece_set()

    def test_three_closed_material_solids(self):
        self.assertEqual(len(self.pieces), 3)
        for piece in self.pieces:
            self.assertGreater(len(piece.faces), 0)
            self.assertAlmostEqual(piece.thickness, THICKNESS)
            self.assertTrue(all(math.isfinite(v) for p in piece.vertices for v in p))
            # Each physical material edge has two oppositely wound owners.
            uses = {}
            for a, b, c in piece.faces:
                for u, v in ((a,b),(b,c),(c,a)):
                    uses.setdefault((min(u,v),max(u,v)), []).append(1 if u<v else -1)
            self.assertTrue(all(sorted(v)==[-1,1] for v in uses.values()))

    def test_constant_material_thickness(self):
        for piece in self.pieces:
            offset = len(piece.vertices) // 2
            for i in range(offset):
                a, b = piece.vertices[i], piece.vertices[i + offset]
                self.assertAlmostEqual(math.dist(a, b), THICKNESS, places=7)

    def test_shared_source_rim_is_identical(self):
        cradle_verts = self.cradle[0]
        edge_owners = validate_shared_material(cradle_verts, self.pieces)
        self.assertEqual(len(edge_owners), sum(len(p.rim_sector_indices)-1
                                               for p in self.pieces))

    def test_upper_faces_do_not_occupy_cradle(self):
        for piece in self.pieces:
            count = piece.lower_count
            for row in range(1, len(piece.vertices)//(2*count)):
                for column, sector in enumerate(piece.rim_sector_indices):
                    z = piece.vertices[row*count + column][2]
                    self.assertGreater(z, -rim_y(2*math.pi*sector/SECTORS))

    def test_rear_chip_is_an_asymmetric_arch_not_a_rectangle(self):
        rear = self.pieces[0]
        span = rear.lower_count
        # Index of top exterior row is one row before the inner-face offset.
        outer_count = len(rear.vertices) // 2
        vertical_heights = [
            rear.vertices[outer_count-span+i][2] - rear.vertices[i][2]
            for i in range(span)
        ]
        self.assertGreater(max(vertical_heights), 125)
        self.assertGreater(vertical_heights[0], 135)
        self.assertLess(vertical_heights[-1], 30)
        self.assertGreater(vertical_heights[span//2], vertical_heights[-1] * 4)
        self.assertNotAlmostEqual(vertical_heights[0], vertical_heights[-1])
        # The upper near-center edge is inclined in real 3D, not a
        # vertical planar side of a rectangular panel.
        top = rear.vertices[len(rear.vertices)//2 - span]
        base = rear.vertices[0]
        self.assertGreater(top[0] - base[0], 25)
        self.assertEqual(REAR_TOP_STATIONS[0][0], 0)
        self.assertEqual(REAR_TOP_STATIONS[-1][0], 1)

    def test_front_chip_geometry_is_unchanged(self):
        # Baseline V11.56 front-chip heights are deterministic and untouched.
        for piece, spec in zip(self.pieces[1:], FRAGMENT_SPECS[1:]):
            _, first, last, rise, irregularity, phase = spec
            mid = (first + last) // 2
            theta = 2 * math.pi * mid / SECTORS
            u = (mid - first) / (last - first)
            expected = rise + irregularity * (
                math.sin(5 * math.pi * u + phase)
                + .35 * math.sin(11 * math.pi * u - .2))
            j = mid - first
            top_index = len(piece.vertices) // 2 - piece.lower_count + j
            bottom_index = j
            self.assertAlmostEqual(
                piece.vertices[top_index][2] - piece.vertices[bottom_index][2],
                expected, places=7)

    def test_reproducible_and_asymmetric(self):
        _, again = build_piece_set()
        self.assertEqual([(p.name,p.vertices,p.faces) for p in self.pieces],
                         [(p.name,p.vertices,p.faces) for p in again])
        self.assertNotEqual(FRAGMENT_SPECS[1][2]-FRAGMENT_SPECS[1][1],
                            FRAGMENT_SPECS[2][2]-FRAGMENT_SPECS[2][1])


if __name__ == '__main__':
    unittest.main()
