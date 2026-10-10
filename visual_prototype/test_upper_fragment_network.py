"""V11.67 regression gate: keep V11.66 bowl while splitting the upper egg."""
from collections import defaultdict
import math
import tempfile
from pathlib import Path
import unittest

import cradle_from_full_egg as baseline
import upper_fragment_network as f
from whole_mother_graph import signed_volume


def edge_usage(faces):
    edges=defaultdict(list)
    for a,b,c in faces:
        for u,v in ((a,b),(b,c),(c,a)):
            edges[(min(u,v),max(u,v))].append((u,v))
    return edges


class UpperNetworkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old=baseline.cut_mother()
        cls.new=f.build_upper_partition(cls.old)

    def test_approved_3d_cradle_is_exactly_unchanged(self):
        old,new=self.old,self.new
        self.assertEqual(old.cradle.vertices,new.cradle.vertices)
        self.assertEqual(old.cradle.faces,new.cradle.faces)
        self.assertEqual(old.cradle.outside,new.cradle.outside)
        self.assertEqual(old.mother.vertices,new.mother.vertices)
        self.assertEqual(old.mother.faces,new.mother.faces)
        self.assertEqual(old.cut_edges & new.cut_edges,old.cut_edges)

    def test_real_material_fragments_not_two_long_panels(self):
        self.assertGreaterEqual(len(self.new.regions),9)
        self.assertEqual(sum(x is self.new.cradle for x in self.new.regions),1)
        self.assertGreaterEqual(len(self.new.junctions),5)
        for r in self.new.regions:
            self.assertGreater(len(r.outside),280,r.name)

    def test_routing_contains_long_oblique_and_transverse_cracks(self):
        self.assertEqual(len(self.new.routes),2*len(f.INNER)+1)
        diagonal=next(path for name,path in self.new.routes
                      if name=='upper_diagonal')
        self.assertGreater(len(diagonal),50)
        varied=0
        for i in range(len(f.INNER)):
            a=f.INNER[i][1]; b=f.SPOKE_BENDS[i][1]; c=f.RIM_SECTORS[i]
            if abs(a-b)>=8 and abs(c-b)>=8: varied+=1
        self.assertGreaterEqual(varied,4)

    def test_every_drawn_edge_separates_two_real_regions(self):
        self.assertEqual(self.new.actual_edges,self.new.cut_edges)
        edges=baseline._edge_faces(self.new.mother.exterior)
        for edge in self.new.cut_edges:
            left,right=edges[edge]
            self.assertNotEqual(self.new.face_labels[left],self.new.face_labels[right])

    def test_all_individual_solids_manifold_and_positive(self):
        for obj in self.new.regions:
            incident=edge_usage(obj.faces)
            self.assertTrue(all(len(v)==2 and v[0]==v[1][::-1]
                                for v in incident.values()),obj.name)
            self.assertGreater(signed_volume(obj.vertices,obj.faces),0,obj.name)

    def test_two_owners_only_for_internal_physical_rims(self):
        owner=defaultdict(list)
        for obj in self.new.regions:
            for tri in obj.faces:
                pts=tuple(obj.vertices[i] for i in tri)
                owner[tuple(sorted(pts))].append(pts)
        mother={tuple(sorted(tuple(self.new.mother.vertices[i] for i in face)))
                for face in self.new.mother.faces}
        self.assertEqual(mother,{key for key,values in owner.items() if len(values)==1})
        self.assertGreater(sum(len(values)==2 for values in owner.values()),800)
        for values in owner.values():
            self.assertLessEqual(len(values),2)
            if len(values)==2:
                a,b=values
                self.assertIn(b,((a[0],a[2],a[1]),(a[2],a[1],a[0]),(a[1],a[0],a[2])))

    def test_total_material_volume_preserved_at_source_pose(self):
        mother=signed_volume(self.new.mother.vertices,self.new.mother.faces)
        parts=math.fsum(signed_volume(a.vertices,a.faces) for a in self.new.regions)
        self.assertGreater(mother,100000)
        self.assertLess(abs(mother-parts)/mother,1e-10)
        for obj in self.new.regions:
            count=len(obj.vertices)//2
            for i in range(0,count,max(1,count//70)):
                self.assertAlmostEqual(math.dist(obj.vertices[i],obj.vertices[count+i]),
                                       f.base.THICKNESS,places=6)

    def test_determinism_and_selectable_blender_objects(self):
        again=f.build_upper_partition(self.old)
        self.assertEqual(self.new.cut_edges,again.cut_edges)
        self.assertEqual([x.faces for x in self.new.regions],
                         [x.faces for x in again.regions])
        with tempfile.TemporaryDirectory() as td:
            filename=Path(td)/'egg.obj'
            f.export_obj(filename,self.new)
            contents=filename.read_text()
            self.assertEqual(sum(line.startswith('o ') for line in contents.splitlines()),
                             len(self.new.regions))
            self.assertGreater(sum(line.startswith('f ') for line in contents.splitlines()),28032)


if __name__=='__main__':
    unittest.main()
