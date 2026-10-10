"""V11.61 structural tests; requires only Python's standard library."""
from collections import defaultdict
import math
import unittest
from subdivide_organic import (build_organic_partition, cut_fraction,
                               SPLIT_PARENTS, SPLIT_ROW)
from whole_egg_partition import UPPER_ROWS, THICKNESS


def oriented_faces(vertices, faces):
    out=defaultdict(list)
    for a,b,c in faces:
        v=(vertices[a],vertices[b],vertices[c])
        out[tuple(sorted(v))].append(v)
    return out


def volume(vertices, faces):
    terms=[]
    for a,b,c in faces:
        x,y,z=vertices[a],vertices[b],vertices[c]
        terms.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(terms)


class OrganicFullEggTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stage=build_organic_partition()

    def test_three_parents_divided_into_real_solids(self):
        s=self.stage
        self.assertEqual(len(s.regions),12)
        self.assertEqual(len(s.daughters),3)
        self.assertEqual(len(s.source.regions),9)
        self.assertEqual(tuple(s.source.regions[1+i].name for i in SPLIT_PARENTS),
                         tuple(x[0] for x in s.daughters))
        self.assertIs(s.regions[0],s.source.regions[0])
        self.assertIs(s.regions[-1],s.source.regions[-1])

    def test_each_volume_has_opposite_material_edge_winding(self):
        for part in self.stage.regions:
            incidences=defaultdict(list)
            for a,b,c in part.faces:
                for u,v in ((a,b),(b,c),(c,a)):
                    incidences[(min(u,v),max(u,v))].append(1 if u<v else -1)
            self.assertTrue(all(sorted(val)==[-1,1]
                                for val in incidences.values()),part.name)
            self.assertEqual(part.thickness,THICKNESS)

    def test_cut_is_smooth_nonhorizontal_and_strictly_monotone(self):
        for index in SPLIT_PARENTS:
            cols=len(self.stage.source.regions[index+1].bottom_keys)
            values=[cut_fraction(SPLIT_ROW,c,cols,index) for c in range(cols)]
            self.assertAlmostEqual(values[0],SPLIT_ROW/UPPER_ROWS)
            self.assertAlmostEqual(values[-1],SPLIT_ROW/UPPER_ROWS)
            self.assertGreater(max(values)-min(values),.045)
            self.assertLess(max(abs(a-b) for a,b in zip(values,values[1:])),.05)
            for c in range(cols):
                levels=[cut_fraction(j,c,cols,index) for j in range(UPPER_ROWS+1)]
                self.assertAlmostEqual(levels[0],0)
                self.assertAlmostEqual(levels[-1],1)
                self.assertTrue(all(0<=a<b<=1 for a,b in zip(levels,levels[1:])))

    def test_all_outer_faces_unique_and_exhaustive(self):
        stage=self.stage
        source_ids={id(p):i for i,p in enumerate(stage.mother_vertices)}
        all_faces=[]
        for part in stage.regions:
            for tri in part.exterior_faces:
                all_faces.append(tuple(source_ids[id(part.vertices[i])]
                                       for i in tri))
        self.assertEqual(len(set(all_faces)),len(all_faces))
        self.assertEqual(set(all_faces),set(stage.mother_faces[:len(all_faces)]))

    def test_contact_walls_are_double_owned_with_reverse_winding(self):
        stage=self.stage
        uses=oriented_faces(stage.mother_vertices,stage.mother_faces)
        child=defaultdict(list)
        for region in stage.regions:
            for key, v in oriented_faces(region.vertices,region.faces).items():
                child[key].extend(v)
        self.assertEqual(set(uses),{k for k,v in child.items() if len(v)==1})
        count=0
        for verts in child.values():
            self.assertLessEqual(len(verts),2)
            if len(verts)==2:
                a,b=verts
                self.assertIn(b,((a[0],a[2],a[1]),
                                 (a[2],a[1],a[0]),(a[1],a[0],a[2])))
                count+=1
        self.assertGreater(count,1000)

    def test_all_cuts_use_one_identical_vertex_instance(self):
        stage=self.stage
        for parent_name,(lower_name,upper_name) in stage.daughters:
            lower=next(x for x in stage.regions if x.name==lower_name)
            upper=next(x for x in stage.regions if x.name==upper_name)
            cols=len(lower.bottom_keys)
            a=len(lower.vertices)//2
            b=len(upper.vertices)//2
            for col in range(cols):
                self.assertIs(lower.vertices[a-cols+col],upper.vertices[col])
                self.assertIs(lower.vertices[2*a-cols+col],upper.vertices[b+col])
        # The old lower bowl's exact lower cut is never re-generated.
        base=stage.source.regions[0]
        self.assertIs(stage.regions[0],base)

    def test_positive_material_volumes_exactly_conserved(self):
        s=self.stage
        mother=volume(s.mother_vertices,s.mother_faces)
        child_volumes=[volume(r.vertices,r.faces) for r in s.regions]
        self.assertGreater(mother,100000)
        self.assertTrue(all(v>0 for v in child_volumes))
        self.assertAlmostEqual(math.fsum(child_volumes)/mother,1,places=10)

    def test_reference_profile_and_thickness_preserved(self):
        from scene_00 import surface, inward_normal, rim_y
        from whole_egg_partition import displaced_angle, crown_y
        s=self.stage
        for i in SPLIT_PARENTS:
            part=s.source.regions[1+i]
            # Each fresh sample is evaluated on the real common egg surface.
            cnt=len(part.bottom_keys)
            for col in range(1,cnt-1,3):
                _,sector=part.bottom_keys[col]
                theta=displaced_angle(SPLIT_ROW,sector)
                q=cut_fraction(SPLIT_ROW,col,cnt,i)
                y=rim_y(theta)*(1-q)+crown_y(theta)*q
                expected=surface(y,theta)
                lower_name=s.daughters[SPLIT_PARENTS.index(i)][1][0]
                lower=next(x for x in s.regions if x.name==lower_name)
                p=lower.vertices[SPLIT_ROW*cnt+col]
                self.assertEqual(p,expected)
                n=lower.vertices[len(lower.vertices)//2+SPLIT_ROW*cnt+col]
                self.assertAlmostEqual(math.dist(p,n),THICKNESS,places=7)

    def test_repeatability_without_random_frame_variation(self):
        again=build_organic_partition()
        self.assertEqual(again.mother_vertices,self.stage.mother_vertices)
        self.assertEqual(again.mother_faces,self.stage.mother_faces)
        self.assertEqual(tuple(x.faces for x in again.regions),
                         tuple(x.faces for x in self.stage.regions))

if __name__=='__main__':
    unittest.main()
