"""Checks prove the 00:00 lower cradle is derived from a fracture, not prefab."""
from collections import defaultdict
import math
import tempfile
import unittest
from pathlib import Path
import whole_mother_graph as m


def directed_faces(verts, faces):
    result=defaultdict(list)
    for face in faces:
        tri=tuple(verts[i] for i in face)
        result[tuple(sorted(tri))].append(tri)
    return result


class WholeMotherFractureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=m.cut_full_mother()

    def test_mother_has_no_premade_cradle_or_rim(self):
        self.assertNotIn('rim_y',m.mother_shell.__code__.co_names)
        self.assertNotIn('build_shell',m.mother_shell.__code__.co_names)
        mother=self.out.mother
        self.assertIn(mother.top_pole,[v for tri in mother.outer_faces for v in tri])
        self.assertIn(mother.bottom_pole,[v for tri in mother.outer_faces for v in tri])
        self.assertEqual(len(mother.vertices),2*(m.SECTORS*m.RINGS+2))

    def test_graph_really_cuts_between_connected_shell_regions(self):
        self.assertEqual(len(self.out.parts),2)
        self.assertEqual(self.out.graph_edges,self.out.boundary_edges)
        self.assertGreater(len(self.out.graph_edges),m.SECTORS)
        self.assertEqual(self.out.bottom_part.name,'lower_cradle_from_graph')
        self.assertTrue(any(p.name.startswith('detached_upper_shell') for p in self.out.parts))

    def test_all_volumes_watertight_and_oriented(self):
        for name,vertices,faces in [('mother',self.out.mother.vertices,self.out.mother.faces)]+[
            (part.name,part.vertices,part.faces) for part in self.out.parts
        ]:
            edge_uses=defaultdict(list)
            for a,b,c in faces:
                for u,v in ((a,b),(b,c),(c,a)):
                    edge_uses[(min(u,v),max(u,v))].append((u,v))
            self.assertTrue(all(len(uses)==2 and uses[0]==uses[1][::-1]
                                for uses in edge_uses.values()),name)
            self.assertGreater(m.signed_volume(vertices,faces),1000,name)

    def test_no_external_surface_added_or_removed(self):
        parent=self.out.mother
        original={tuple(sorted(x)) for x in directed_faces(parent.vertices,parent.faces)}
        ownership=defaultdict(list)
        for part in self.out.parts:
            for key,values in directed_faces(part.vertices,part.faces).items():
                ownership[key].extend(values)
        outside={key for key,val in ownership.items() if len(val)==1}
        self.assertEqual(outside,original)
        self.assertGreater(len(ownership)-len(outside),m.SECTORS*2)
        for val in ownership.values():
            self.assertLessEqual(len(val),2)
            if len(val)==2:
                a,b=val
                self.assertIn(b,((a[0],a[2],a[1]),(a[1],a[0],a[2]),
                                 (a[2],a[1],a[0])))

    def test_material_volume_conservation(self):
        mother=m.signed_volume(self.out.mother.vertices,self.out.mother.faces)
        total=math.fsum(m.signed_volume(x.vertices,x.faces) for x in self.out.parts)
        self.assertGreater(mother,100000)
        self.assertLess(abs(mother-total)/mother,1e-10)

    def test_thickness_stays_at_2_point_5(self):
        for part in self.out.parts:
            half=len(part.vertices)//2
            for i in range(0,half,max(1,half//75)):
                self.assertAlmostEqual(math.dist(part.vertices[i],part.vertices[i+half]),
                                       m.THICKNESS,places=5)

    def test_repeatable_without_per_frame_noise(self):
        second=m.cut_full_mother()
        self.assertEqual(self.out.graph_edges,second.graph_edges)
        self.assertEqual(self.out.bottom_part.faces,second.bottom_part.faces)

    def test_obj_exports_independent_selectable_3d_solids(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'egg.obj'
            m.export_obj(path,self.out)
            file=path.read_text()
            self.assertEqual(sum(s.startswith('o ') for s in file.splitlines()),2)
            self.assertEqual(sum(s.startswith('f ') for s in file.splitlines()),
                             sum(len(r.faces) for r in self.out.parts))


if __name__=='__main__':unittest.main()
