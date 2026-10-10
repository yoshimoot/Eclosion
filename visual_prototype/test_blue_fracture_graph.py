"""V11.63: graph-first physical cracks, independent of Blender/Flutter."""
from collections import defaultdict
import math
import tempfile
from pathlib import Path
import unittest

from blue_fracture_graph import (build_blue_network, _edge_map, save_obj,
                                 NODES, LINKS)


def signed_volume(vertices,faces):
    terms=[]
    for a,b,c in faces:
        x,y,z=(vertices[i] for i in (a,b,c))
        terms.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(terms)


class GraphFirstEggTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.egg=build_blue_network()

    def test_graph_is_authored_before_fragment_partition(self):
        e=self.egg
        self.assertGreaterEqual(len(LINKS),12)
        self.assertEqual(len(e.paths),len(LINKS))
        self.assertGreaterEqual(len(e.junctions),3)
        self.assertGreaterEqual(len(e.regions),8)
        for a,b,path in e.paths:
            self.assertIn(a,NODES)
            self.assertIn(b,NODES)
            self.assertGreater(len(path),3)
        self.assertIs(e.mother_vertices,e.original.mother_vertices)
        self.assertIs(e.mother_faces,e.original.mother_faces)

    def test_cracks_dont_follow_long_parallel_meridians(self):
        # The blue user-drawn example favours OBLIQUE material strokes.
        # Compare authored graph directions rather than triangulation pixel
        # strokes, which depend on mesh resolution and viewing angle.
        near_vertical=0
        for a,b in LINKS:
            dx=(NODES[a][0]-NODES[b][0])*350
            dz=(NODES[a][1]-NODES[b][1])*220
            near_vertical+=abs(dx)<.32*abs(dz)
        self.assertLessEqual(near_vertical,3)
        self.assertGreater(len(LINKS)-near_vertical,10)

    def test_all_seams_are_real_material_boundaries(self):
        e=self.egg
        self.assertTrue(e.cut_edges)
        self.assertTrue(e.cut_edges.issubset(e.material_seams))
        source_faces=e.mother_faces[:len(e.mother_faces)//2]
        for edge in e.cut_edges:
            owners=_edge_map(source_faces)[edge]
            self.assertEqual(len(owners),2)
            self.assertNotEqual(e.face_labels[owners[0]],e.face_labels[owners[1]])

    def test_every_solid_is_watertight(self):
        e=self.egg
        for region in e.regions:
            self.assertGreater(len(region.exterior_faces),200,region.name)
            self.assertEqual(region.thickness,2.5)
            incidence=defaultdict(list)
            for a,b,c in region.faces:
                for u,v in ((a,b),(b,c),(c,a)):
                    incidence[(min(u,v),max(u,v))].append(1 if u<v else -1)
            self.assertTrue(all(sorted(v)==[-1,1] for v in incidence.values()),region.name)
            self.assertGreater(signed_volume(region.vertices,region.faces),0)

    def test_every_parent_exterior_triangle_owned_once(self):
        e=self.egg
        ids={id(p):i for i,p in enumerate(e.mother_vertices)}
        exterior=[]
        for region in e.regions:
            for tri in region.exterior_faces:
                exterior.append(tuple(ids[id(region.vertices[i])] for i in tri))
        outside=e.mother_faces[:len(e.mother_faces)//2]
        self.assertEqual(len(exterior),len(outside))
        self.assertEqual(set(exterior),set(outside))

    def test_interior_contact_faces_double_owned_opposite_winding(self):
        e=self.egg
        ids={id(p):i for i,p in enumerate(e.mother_vertices)}
        used=defaultdict(list)
        for region in e.regions:
            for face in region.faces:
                tri=tuple(ids[id(region.vertices[i])] for i in face)
                used[tuple(sorted(tri))].append(tri)
        parent_faces={tuple(sorted(t)) for t in e.mother_faces}
        self.assertEqual(parent_faces,{k for k,v in used.items() if len(v)==1})
        duplicates=0
        for owners in used.values():
            self.assertLessEqual(len(owners),2)
            if len(owners)==2:
                a,b=owners
                self.assertIn(b,((a[0],a[2],a[1]),(a[1],a[0],a[2]),
                                 (a[2],a[1],a[0])))
                duplicates+=1
        self.assertGreater(duplicates,500)

    def test_thickness_and_total_volume(self):
        e=self.egg
        n=len(e.mother_vertices)//2
        for region in e.regions:
            k=len(region.vertices)//2
            for i in range(0,k,max(1,k//30)):
                self.assertAlmostEqual(math.dist(region.vertices[i],region.vertices[i+k]),
                                       2.5,places=5)
        mother=signed_volume(e.mother_vertices,e.mother_faces)
        total=math.fsum(signed_volume(r.vertices,r.faces) for r in e.regions)
        self.assertLess(abs(total-mother)/mother,1e-9)

    def test_stable_graph_and_obj_selectable_parts(self):
        e=self.egg
        again=build_blue_network()
        self.assertEqual(e.cut_edges,again.cut_edges)
        self.assertEqual(e.face_labels,again.face_labels)
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'blue_fractures.obj'
            save_obj(path,e)
            obj=path.read_text()
            self.assertEqual(obj.count('\no ')+obj.startswith('o '),len(e.regions))
            self.assertGreater(obj.count('\nf '),30000)

if __name__=='__main__':unittest.main()
