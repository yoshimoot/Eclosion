"""V11.70 structure tests; no Blender, Flutter or trimesh dependency."""
from collections import defaultdict
import math
import os
from pathlib import Path
import tempfile
import unittest
from refine_upper_cap_obj import read_obj
from organic_network_v1170 import (design, export_obj, source_from_repo,
                                   _edge_owners, SECTORS, TOP_STEPS, CROWN)


def signed_volume(part):
    terms=[]
    for a,b,c in part.faces:
        x,y,z=(part.vertices[i] for i in (a,b,c))
        terms.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(terms)


def geometrical_owners(parts):
    owners=defaultdict(list)
    for part in parts:
        for face in part.faces:
            vertices=tuple(part.vertices[i] for i in face)
            owners[tuple(sorted(vertices))].append(vertices)
    return owners


class TrueOrganicFractureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        override=os.getenv('ECLOSION_REFERENCE_OBJ')
        cls.original=read_obj(override) if override else source_from_repo()
        cls.model=design(cls.original)

    def test_bowl_and_source_mother_unchanged(self):
        old=next(p for p in self.original if p.name.startswith('lower_cradle_'))
        new=next(p for p in self.model.parts if p.name.startswith('lower_cradle_'))
        self.assertEqual(old,new)
        original_triangles=[]
        for p in self.original:
            n=len(p.vertices)//2
            original_triangles.extend(tuple(sorted(p.vertices[i] for i in tri))
                                      for tri in p.faces if max(tri)<n)
        mother=self.model.mother
        old_set=set(original_triangles)
        new_set={tuple(sorted(mother.vertices[i] for i in tri))
                 for tri in mother.triangles[:mother.upper_face_count]}
        self.assertEqual(len(old_set),len(original_triangles))
        self.assertEqual(old_set,new_set)

    def test_one_polar_piece_and_seven_physical_junctions(self):
        model=self.model
        self.assertEqual(len(model.parts),9)
        pole=(0.,0.,220.)
        owners=[part.name for part in model.parts if pole in part.vertices]
        self.assertEqual(owners,['upper_organic_00'])
        self.assertEqual(len(model.junctions),7)
        self.assertEqual(len(model.paths),14)
        self.assertEqual(len(CROWN),7)
        mother=model.mother
        polar_ids={i for i,v in enumerate(mother.vertices[:len(mother.vertices)//2])
                   if v==pole}
        self.assertEqual(len(polar_ids),1)
        self.assertTrue(all(not set(edge)&polar_ids for edge in model.cracks))

    def test_graph_is_a_real_split_and_not_decorative(self):
        model=self.model
        n=model.mother.upper_face_count
        outer=model.mother.triangles[:n]
        owner=_edge_owners(outer)
        effective={edge for edge,adj in owner.items()
                   if model.labels[adj[0]] != model.labels[adj[1]]}
        self.assertEqual(effective,model.cracks)
        self.assertEqual(len(model.cracks),654)
        # Nonparallel paths at multiple heights rather than seven straight
        # meridians from the same latitude.
        self.assertGreater(len({row for row,sector in CROWN}),4)

    def test_all_solids_are_manifold_with_positive_volume(self):
        for part in self.model.parts:
            edges=defaultdict(list)
            for a,b,c in part.faces:
                for u,v in ((a,b),(b,c),(c,a)):
                    edges[(min(u,v),max(u,v))].append((u,v))
            self.assertTrue(all(len(v)==2 and v[0]==v[1][::-1]
                                for v in edges.values()),part.name)
            self.assertGreater(signed_volume(part),0,part.name)

    def test_shared_cut_walls_identical_oppositely_oriented(self):
        owners=geometrical_owners(self.model.parts)
        mother=self.model.mother
        source={tuple(sorted(mother.vertices[i] for i in tri))
                for tri in mother.triangles}
        self.assertEqual(source,{k for k,v in owners.items() if len(v)==1})
        self.assertGreater(sum(len(v)==2 for v in owners.values()),900)
        for incidences in owners.values():
            self.assertLessEqual(len(incidences),2)
            if len(incidences)==2:
                a,b=incidences
                self.assertIn(b,((a[0],a[2],a[1]),(a[2],a[1],a[0]),(a[1],a[0],a[2])))

    def test_volume_and_2_point_5_thickness(self):
        mother=self.model.mother
        n=len(mother.vertices)//2
        exterior=mother.triangles[:mother.upper_face_count]
        orig=math.fsum((
            (mother.vertices[a][0]*(mother.vertices[b][1]*mother.vertices[c][2]-mother.vertices[b][2]*mother.vertices[c][1])+
             mother.vertices[a][1]*(mother.vertices[b][2]*mother.vertices[c][0]-mother.vertices[b][0]*mother.vertices[c][2])+
             mother.vertices[a][2]*(mother.vertices[b][0]*mother.vertices[c][1]-mother.vertices[b][1]*mother.vertices[c][0]))/6
             ) for a,b,c in mother.triangles)
        pieces=math.fsum(signed_volume(p) for p in self.model.parts)
        self.assertLess(abs(pieces-orig)/orig,1e-10)
        for p in self.model.parts:
            k=len(p.vertices)//2
            for i in range(0,k,max(1,k//40)):
                self.assertAlmostEqual(math.dist(p.vertices[i],p.vertices[i+k]),2.5,places=5)

    def test_no_tiny_fragments_and_variation_of_shape(self):
        sizes=[]
        for piece in self.model.parts:
            if piece.name.startswith('upper_') and piece.name!='upper_organic_00':
                n=len(piece.vertices)//2
                count=sum(max(f)<n for f in piece.faces)
                sizes.append(count)
        self.assertEqual(len(sizes),7)
        self.assertGreater(min(sizes),500)
        self.assertGreater(max(sizes)/min(sizes),2.0)

    def test_determinism_and_obj_roundtrip(self):
        repeat=design(self.original)
        self.assertEqual(self.model.cracks,repeat.cracks)
        self.assertEqual(self.model.labels,repeat.labels)
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'reassembled.obj'
            export_obj(path,self.model)
            self.assertEqual(read_obj(path),self.model.parts)


if __name__=='__main__':unittest.main()
