"""V11.65 regression checks for a fracture-derived cradle and upper pieces."""
from collections import defaultdict, Counter
import math
import tempfile
from pathlib import Path
import unittest

import branched_mother_graph as m
import whole_mother_graph as base


class BranchedMotherTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=m.build_branched_mother()

    def test_mother_is_still_original_full_egg(self):
        self.assertEqual(self.result.mother, base.mother_shell())
        self.assertEqual(len(self.result.routes),len(m.BRANCHES))
        self.assertGreaterEqual(len(self.result.parts),6)
        self.assertEqual(self.result.bottom_part.name,'lower_cradle_from_graph')

    def test_graph_is_true_material_cut_no_drawn_fake_crack(self):
        self.assertEqual(self.result.cuts,self.result.effective_cuts)
        self.assertGreater(len(self.result.cuts),base.SECTORS+150)
        incident=base._edge_faces(self.result.mother.outer_faces)
        self.assertTrue(self.result.cuts.issubset(incident))
        self.assertEqual(len(incident),len(set(incident)))

    def test_graph_contains_real_branching_junctions(self):
        degree=Counter()
        for a,b in self.result.cuts:
            degree[a]+=1;degree[b]+=1
        self.assertGreaterEqual(sum(d>=3 for d in degree.values()),6)
        self.assertGreaterEqual(len(m.CRACK_NODES),10)
        self.assertGreaterEqual(len(m.BRANCHES),10)

    def test_no_fragments_only_a_couple_of_faces(self):
        for piece in self.result.parts:
            self.assertGreater(len(piece.outside),500,piece.name)

    def test_all_volumes_are_closed_and_oriented(self):
        for part in self.result.parts:
            edge_uses=defaultdict(list)
            for a,b,c in part.faces:
                for u,v in ((a,b),(b,c),(c,a)):
                    edge_uses[(min(u,v),max(u,v))].append((u,v))
            self.assertTrue(all(len(v)==2 and v[0]==v[1][::-1]
                                for v in edge_uses.values()),part.name)
            self.assertGreater(base.signed_volume(part.vertices,part.faces),1000,part.name)

    def test_exterior_owned_once_all_internal_faces_owned_twice(self):
        parent=self.result.mother
        keyset={tuple(sorted(f)) for f in [(tuple(parent.vertices[i] for i in face))
                                              for face in parent.faces]}
        face_owners=defaultdict(list)
        for piece in self.result.parts:
            for a,b,c in piece.faces:
                f=(piece.vertices[a],piece.vertices[b],piece.vertices[c])
                face_owners[tuple(sorted(f))].append(f)
        self.assertEqual(keyset,{k for k,owners in face_owners.items() if len(owners)==1})
        self.assertGreater(sum(len(v)==2 for v in face_owners.values()),300)
        for owners in face_owners.values():
            self.assertLessEqual(len(owners),2)
            if len(owners)==2:
                a,b=owners
                self.assertIn(b,((a[0],a[2],a[1]),(a[1],a[0],a[2]),(a[2],a[1],a[0])))

    def test_thickness_and_exact_volume_conservation(self):
        mother=self.result.mother
        mother_volume=base.signed_volume(mother.vertices,mother.faces)
        piece_volume=math.fsum(base.signed_volume(p.vertices,p.faces)
                              for p in self.result.parts)
        self.assertLess(abs(piece_volume-mother_volume)/mother_volume,1e-10)
        for part in self.result.parts:
            n=len(part.vertices)//2
            for i in range(0,n,max(1,n//75)):
                self.assertAlmostEqual(math.dist(part.vertices[i],part.vertices[i+n]),2.5,places=5)

    def test_repeatable_without_any_random_animation(self):
        another=m.build_branched_mother()
        self.assertEqual(self.result.cuts,another.cuts)
        self.assertEqual(tuple(p.faces for p in self.result.parts),
                         tuple(p.faces for p in another.parts))
        with tempfile.TemporaryDirectory() as folder:
            out=Path(folder)/'parts.obj'
            m.export_obj(out,self.result)
            self.assertEqual(sum(x.startswith('o ') for x in out.read_text().splitlines()),
                             len(self.result.parts))

if __name__=='__main__':unittest.main()
