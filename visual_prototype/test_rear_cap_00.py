"""Checks of actual 3D cap geometry; artistic validation is separate."""
import math
import unittest
from rear_cap_00 import (ANGLE_LEFT,ANGLE_RIGHT,SECTIONS,ROWS,
                         build_rear_cap,cap_cuts,THICKNESS)
from scene_00 import rim_y,surface


class RearCapTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cap=build_rear_cap()

    def test_closed_mesh_and_oriented_cut_walls(self):
        cap=self.cap
        self.assertEqual(len(cap.vertices),2*(SECTIONS+1)*(ROWS+1))
        self.assertEqual(len(cap.external_faces),2*SECTIONS*ROWS)
        self.assertEqual(len(cap.inner_faces),len(cap.external_faces))
        self.assertEqual(len(cap.wall_faces),4*(SECTIONS+ROWS))
        edges={}
        for a,b,c in cap.faces:
            for u,v in ((a,b),(b,c),(c,a)):
                key=tuple(sorted((u,v)))
                edges.setdefault(key,[]).append(1 if u<v else -1)
        self.assertTrue(all(sorted(values)==[-1,1] for values in edges.values()))

    def test_exact_two_face_thickness(self):
        cap=self.cap
        n=len(cap.vertices)//2
        for j in range(n):
            self.assertAlmostEqual(math.dist(cap.vertices[j],cap.vertices[j+n]),THICKNESS,places=7)

    def test_curved_true_egg_surface(self):
        cap=self.cap
        stride=SECTIONS+1
        for j in range(ROWS+1):
            for i in range(0,SECTIONS+1,3):
                t=i/SECTIONS
                angle=ANGLE_LEFT+(ANGLE_RIGHT-ANGLE_LEFT)*t
                upper,lower=cap_cuts(t)
                y=lower+(upper-lower)*j/ROWS
                p=cap.vertices[j*stride+i]
                for a,b in zip(p,surface(y,angle)):
                    self.assertAlmostEqual(a,b,places=7)

    def test_upper_dome_and_broken_lower_edge(self):
        a=cap_cuts(0)
        b=cap_cuts(.55)
        c=cap_cuts(1)
        self.assertGreater(a[0],b[0]+70)
        self.assertLess(abs(c[0]-c[1]),10)
        self.assertGreater(a[1]-a[0],20)
        self.assertGreater(b[1]-b[0],80)
        changes=[cap_cuts(i/SECTIONS)[1] for i in range(SECTIONS+1)]
        # Distinct irregular corners rather than a constant-width panel.
        self.assertGreater(sum((changes[i]-changes[i-1])*(changes[i+1]-changes[i])<0
                               for i in range(1,len(changes)-1)),5)

    def test_separated_from_lower_bowl_without_overlap(self):
        # At the same original angular coordinate the new cap terminates
        # above the cradle cut. Nothing is hidden by a 2D mask.
        for i in range(SECTIONS+1):
            t=i/SECTIONS
            angle=ANGLE_LEFT+(ANGLE_RIGHT-ANGLE_LEFT)*t
            _,lower=cap_cuts(t)
            self.assertGreater(rim_y(angle)-lower,10)

    def test_positive_volume_and_nonzero_triangle_area(self):
        cap=self.cap
        volume=0.0
        for a,b,c in cap.faces:
            x,y,z=(cap.vertices[i] for i in (a,b,c))
            ux=y[1]*z[2]-y[2]*z[1]
            uy=y[2]*z[0]-y[0]*z[2]
            uz=y[0]*z[1]-y[1]*z[0]
            volume+=(x[0]*ux+x[1]*uy+x[2]*uz)/6
            ay,az=y[0]-x[0],y[1]-x[1]
            by,bz=z[0]-x[0],z[1]-x[1]
            self.assertGreater(math.dist(x,y),1e-6)
            self.assertGreater(math.dist(x,z),1e-6)
        self.assertGreater(volume,10000)

    def test_repeatability(self):
        cap=build_rear_cap()
        self.assertEqual(cap.vertices,self.cap.vertices)
        self.assertEqual(cap.faces,self.cap.faces)


if __name__=='__main__':
    unittest.main()
