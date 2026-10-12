"""V11.68 tests, runnable locally without Blender/Flutter."""
from collections import defaultdict
import math
from pathlib import Path
import tempfile
import unittest

from refine_upper_cap_obj import read_obj, refine, write_obj

def original_parts():
    # Build the fixture from the live V11.67 repo geometry, without
    # checking a large binary OBJ into GitHub.
    import upper_fragment_network as source
    with tempfile.TemporaryDirectory() as folder:
        path=Path(folder)/'original.obj'
        source.export_obj(path,source.build_upper_partition())
        return read_obj(path)

def signed_volume(part):
    terms=[]
    for a,b,c in part.faces:
        x,y,z=(part.vertices[i] for i in (a,b,c))
        terms.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(terms)

def surface_faces(part):
    return [tuple(part.vertices[i] for i in face) for face in part.faces]

def edge_uses(part):
    used=defaultdict(list)
    for a,b,c in part.faces:
        for u,v in ((a,b),(b,c),(c,a)):
            used[(min(u,v),max(u,v))].append((u,v))
    return used

class UpperCapDivisionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original=original_parts()
        cls.result=refine(cls.original)
        cls.old={p.name:p for p in cls.original}
        cls.new={p.name:p for p in cls.result.parts}

    def test_only_largest_top_fragment_split(self):
        self.assertEqual(len(self.original),10)
        self.assertEqual(len(self.result.parts),11)
        self.assertEqual(self.result.parent,'upper_fragment_00')
        self.assertGreater(min(self.result.daughter_outer_faces),1000)
        self.assertLess(max(self.result.daughter_outer_faces)/min(self.result.daughter_outer_faces),1.5)
        self.assertGreater(len(self.result.seam),35)

    def test_approved_bowl_and_eight_other_fragments_unchanged(self):
        for name,old in self.old.items():
            if name==self.result.parent:continue
            self.assertEqual(old,self.new[name],name)

    def test_every_volume_closed_one_shell(self):
        for part in self.result.parts:
            self.assertTrue(all(len(e)==2 and e[0]==e[1][::-1]
                                for e in edge_uses(part).values()),part.name)
            self.assertGreater(signed_volume(part),0,part.name)

    def test_parent_material_faces_preserved_without_overlaps(self):
        parent=self.old[self.result.parent]
        descendants=[self.new[n] for n in self.result.daughter_names]
        original={tuple(sorted(f)) for f in surface_faces(parent)}
        owners=defaultdict(list)
        for child in descendants:
            for face in surface_faces(child):
                owners[tuple(sorted(face))].append(face)
        self.assertEqual(original,{k for k,v in owners.items() if len(v)==1})
        self.assertGreater(sum(len(v)==2 for v in owners.values()),200)
        for two in owners.values():
            self.assertLessEqual(len(two),2)
            if len(two)==2:
                a,b=two
                self.assertIn(b,((a[0],a[2],a[1]),(a[2],a[1],a[0]),(a[1],a[0],a[2])))

    def test_exact_volume_conservation_and_material_thickness(self):
        original=self.old[self.result.parent]
        new=[self.new[n] for n in self.result.daughter_names]
        self.assertLess(abs(signed_volume(original)-math.fsum(map(signed_volume,new)))/
                        signed_volume(original),1e-10)
        for p in new:
            n=len(p.vertices)//2
            for i in range(0,n,max(1,n//80)):
                self.assertAlmostEqual(math.dist(p.vertices[i],p.vertices[i+n]),2.5,places=5)

    def test_repeatability_and_blender_export(self):
        self.assertEqual(self.result,refine(self.original))
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'v1168.obj'
            write_obj(path,self.result.parts)
            self.assertEqual(read_obj(path),self.result.parts)

if __name__=='__main__':
    unittest.main()
