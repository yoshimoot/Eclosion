"""Geometric regressions for V11.66: true 3D crater from a whole egg."""
from collections import defaultdict
import math
import tempfile
from pathlib import Path
import unittest

import cradle_from_full_egg as m


def uses(faces):
    edges=defaultdict(list)
    for a,b,c in faces:
        for u,v in ((a,b),(b,c),(c,a)):
            edges[(min(u,v),max(u,v))].append((u,v))
    return edges


class CradleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=m.cut_mother()

    def test_mother_is_intact_full_egg_before_cut(self):
        v=self.result.mother.vertices
        f=self.result.mother.faces
        self.assertEqual(len(v),2*(m.RINGS*m.SECTORS+2))
        self.assertEqual(len(self.result.mother.exterior),2*m.RINGS*m.SECTORS)
        self.assertTrue(all(math.isfinite(x) for p in v for x in p))
        self.assertTrue(all(q[0]==q[1][::-1] and len(q)==2 for q in uses(f).values()))
        self.assertGreater(m.signed_volume(v,f),100_000)
        self.assertNotIn('build_shell',m.build_full_mother.__code__.co_names)

    def test_physical_cut_creates_closed_watertight_cradle(self):
        r=self.result
        self.assertEqual(len(r.pieces),2)
        self.assertIn(r.cradle,r.pieces)
        self.assertEqual(r.cradle.name,'fracture_derived_cradle')
        self.assertEqual(len(r.cut_edges),m.SECTORS)
        for child in r.pieces:
            self.assertTrue(all(len(q)==2 and q[0]==q[1][::-1]
                                for q in uses(child.faces).values()), child.name)
            self.assertGreater(m.signed_volume(child.vertices,child.faces),1000)

    def test_true_hollow_bowl_with_lateral_raised_lips(self):
        # Physical bowl opening is tall on both sides, lower front centre.
        self.assertGreater(m.fracture_y(0)-m.fracture_y(-math.pi/2),105)
        self.assertGreater(m.fracture_y(0)-m.fracture_y(math.pi/2),105)
        self.assertLess(abs(m.fracture_y(-math.pi)-m.fracture_y(math.pi)),1e-10)
        self.assertGreater(m.fracture_y(0),75)
        self.assertLess(m.fracture_y(math.pi/2),25)
        # The edge is asymmetric, variable-height and physically scalloped.
        samples=[m.fracture_y(i*2*math.pi/m.SECTORS) for i in range(m.SECTORS)]
        self.assertGreater(max(samples)-min(samples),120)
        self.assertNotAlmostEqual(m.fracture_y(-.55),m.fracture_y(.53),places=2)
        r=self.result
        ring=[r.mother.vertices[i] for i in r.mother.border_ring]
        self.assertGreater(max(p[2] for p in ring)-min(p[2] for p in ring),120)

    def test_same_fracture_edge_on_both_parts(self):
        r=self.result
        self.assertEqual(set(r.cut_edges),set((min(r.mother.border_ring[i],r.mother.border_ring[(i+1)%m.SECTORS]),
                                               max(r.mother.border_ring[i],r.mother.border_ring[(i+1)%m.SECTORS]))
                                              for i in range(m.SECTORS)))
        material={}
        for child in r.pieces:
            for a,b,c in child.faces:
                face=(child.vertices[a],child.vertices[b],child.vertices[c])
                material.setdefault(tuple(sorted(face)),[]).append(face)
        original={tuple(sorted(tuple(r.mother.vertices[i] for i in face))) for face in r.mother.faces}
        exterior={k for k,v in material.items() if len(v)==1}
        self.assertEqual(exterior,original)
        for owners in material.values():
            self.assertLessEqual(len(owners),2)
            if len(owners)==2:
                a,b=owners
                self.assertIn(b,((a[0],a[2],a[1]),(a[2],a[1],a[0]),(a[1],a[0],a[2])))

    def test_constant_2_point_5_thickness_and_volume(self):
        r=self.result
        total=math.fsum(m.signed_volume(p.vertices,p.faces) for p in r.pieces)
        mother=m.signed_volume(r.mother.vertices,r.mother.faces)
        self.assertLess(abs(total-mother)/mother,1e-10)
        for part in r.pieces:
            half=len(part.vertices)//2
            for j in range(0,half,max(1,half//140)):
                self.assertAlmostEqual(math.dist(part.vertices[j],part.vertices[half+j]),m.THICKNESS,places=6)

    def test_no_spike_or_inverted_poles(self):
        r=self.result
        v=r.mother.vertices
        bottom,top=r.mother.poles
        self.assertAlmostEqual(v[bottom][2],-m.HALF_HEIGHT)
        self.assertAlmostEqual(v[top][2],m.HALF_HEIGHT)
        self.assertLess(min(q[2] for q in r.cradle.vertices),-m.HALF_HEIGHT+1)
        self.assertLess(max(q[2] for q in r.cradle.vertices),100)

    def test_exports_distinguish_bowl_and_closed_egg(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'bowl.obj';a=Path(td)/'intact.obj'
            m.write_obj(p,self.result,only_cradle=True)
            m.write_obj(a,self.result)
            self.assertEqual(p.read_text().count('\no ')+p.read_text().startswith('o '),1)
            self.assertEqual(a.read_text().count('\no ')+a.read_text().startswith('o '),2)
            self.assertGreater(a.stat().st_size,p.stat().st_size)

    def test_deterministic_nonanimated_geometry(self):
        again=m.cut_mother()
        self.assertEqual(again.mother.vertices,self.result.mother.vertices)
        self.assertEqual(again.cut_edges,self.result.cut_edges)
        self.assertEqual(tuple(x.faces for x in again.pieces),
                         tuple(x.faces for x in self.result.pieces))

if __name__=='__main__':unittest.main()
