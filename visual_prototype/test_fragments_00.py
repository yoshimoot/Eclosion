"""Static material-contract checks, independent of Blender/Flutter."""
import math
import unittest

from fragments_00 import (build_piece_set, validate_shared_material,
                          FRAGMENT_SPECS, THICKNESS, SECTORS)
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

    def test_reproducible_and_asymmetric(self):
        _, again = build_piece_set()
        self.assertEqual([(p.name,p.vertices,p.faces) for p in self.pieces],
                         [(p.name,p.vertices,p.faces) for p in again])
        self.assertNotEqual(FRAGMENT_SPECS[1][2]-FRAGMENT_SPECS[1][1],
                            FRAGMENT_SPECS[2][2]-FRAGMENT_SPECS[2][1])


if __name__ == '__main__':
    unittest.main()
