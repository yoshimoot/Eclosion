"""Dependency-free regression checks of the standalone 00:00 shell geometry."""
import math
import unittest

from scene_00 import (
    HALF_HEIGHT, THICKNESS, SECTORS, LAYERS,
    build_shell, radius_at, rim_y, validate_shell,
)


class BrokenCradleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.vertices, cls.faces = build_shell()

    def test_shell_topology(self):
        validate_shell(self.vertices, self.faces)
        self.assertEqual(len(self.vertices), 2 * (SECTORS * LAYERS + 1))
        self.assertEqual(len(self.faces), 4 * SECTORS * LAYERS)

    def test_opposed_shared_face_winding(self):
        oriented = {}
        for a, b, c in self.faces:
            for u, v in ((a, b), (b, c), (c, a)):
                key = min(u, v), max(u, v)
                oriented.setdefault(key, []).append(1 if u < v else -1)
        self.assertTrue(all(sorted(v) == [-1, 1] for v in oriented.values()))

    def test_physical_dimensions(self):
        self.assertEqual(THICKNESS, 2.5)
        self.assertAlmostEqual(radius_at(HALF_HEIGHT), 0)
        self.assertAlmostEqual(radius_at(0), 150 * .9721, places=4)
        self.assertTrue(all(math.isfinite(p) for v in self.vertices for p in v))

    def test_stable_asymmetric_cut(self):
        self.assertAlmostEqual(rim_y(-math.pi), rim_y(math.pi), places=8)
        self.assertGreater(rim_y(0) - rim_y(math.pi / 2), 35)
        self.assertGreater(rim_y(0) - rim_y(-math.pi / 2), 35)
        samples = [rim_y(2 * math.pi * i / SECTORS) for i in range(SECTORS)]
        self.assertGreater(max(samples) - min(samples), 40)
        self.assertLess(max(samples), HALF_HEIGHT)


if __name__ == '__main__':
    unittest.main()
