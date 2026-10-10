"""V11.59: run with python -m unittest discover -s visual_prototype -p 'test_*.py'."""
import math
import unittest
from collections import defaultdict
from whole_egg_partition import (build_whole_egg, displaced_angle, crown_y,
                                  save_obj, SIDE_CUTS, SECTORS, UPPER_ROWS,
                                  CAP_ROWS, THICKNESS)
from scene_00 import surface, rim_y, HALF_HEIGHT


def edges(faces):
    result=defaultdict(list)
    for a,b,c in faces:
        for u,v in ((a,b),(b,c),(c,a)):
            result[(min(u,v),max(u,v))].append(1 if u<v else -1)
    return result


def signed_volume(vertices, faces):
    terms=[]
    for a,b,c in faces:
        x,y,z=(vertices[i] for i in (a,b,c))
        terms.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(terms)


class FullMotherPartitionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.egg=build_whole_egg()

    def test_whole_egg_is_closed_with_original_dimensions(self):
        egg=self.egg
        self.assertEqual(len(egg.regions),9)
        self.assertEqual(len(egg.mother_vertices),2*len(egg.global_outer))
        self.assertTrue(all(math.isfinite(x) for p in egg.mother_vertices for x in p))
        self.assertAlmostEqual(max(p[2] for p in egg.global_outer),HALF_HEIGHT)
        self.assertAlmostEqual(min(p[2] for p in egg.global_outer),-HALF_HEIGHT)
        for turns in edges(egg.mother_faces).values():
            self.assertEqual(sorted(turns),[-1,1])

    def test_each_piece_is_watertight(self):
        for piece in self.egg.regions:
            self.assertEqual(piece.thickness,2.5)
            for turns in edges(piece.faces).values():
                self.assertEqual(sorted(turns),[-1,1],piece.name)

    def test_one_single_canonical_source_for_every_exterior_triangle(self):
        egg=self.egg
        mother_ids={id(p):j for j,p in enumerate(egg.global_outer)}
        outside=[]
        for region in egg.regions:
            for triangle in region.exterior_faces:
                outside.append(tuple(mother_ids[id(region.vertices[i])]
                                     for i in triangle))
        self.assertEqual(len(set(outside)),len(outside))
        self.assertEqual(set(outside),set(egg.mother_faces[:len(outside)]))

    def test_internal_thickness_walls_cancel_exactly(self):
        # The surfaces of every connected piece are doubly owned only where
        # a physical cut actually exists. Both owners use the SAME 3D
        # triangulation, not merely four corners with opposite diagonals.
        egg=self.egg
        key={id(p):i for i,p in enumerate(egg.mother_vertices)}
        directed=defaultdict(list)
        for region in egg.regions:
            for tri in region.faces:
                face=tuple(key[id(region.vertices[i])] for i in tri)
                directed[tuple(sorted(face))].append(face)
        joined=0
        exposed=0
        for incidences in directed.values():
            if len(incidences)==1:
                exposed+=1
            elif len(incidences)==2:
                (a,b,c),(d,e,f)=incidences
                self.assertEqual(set((a,b,c)),set((d,e,f)))
                reverse=[(a,c,b),(c,b,a),(b,a,c)]
                self.assertIn((d,e,f),reverse)
                joined+=1
            else:
                self.fail('A physical triangle has three or more owners')
        self.assertEqual(exposed,len(egg.mother_faces))
        self.assertGreater(joined,1000)

    def test_cradle_shares_every_lower_cut_vertex_by_identity(self):
        egg=self.egg
        n=len(egg.cradle.vertices)//2
        for piece in egg.regions[1:-1]:
            for i,(row,sector) in enumerate(piece.bottom_keys):
                self.assertEqual(row,0)
                self.assertIs(piece.vertices[i],egg.cradle.vertices[sector])
                self.assertIs(piece.vertices[len(piece.vertices)//2+i],
                              egg.cradle.vertices[n+sector])
        self.assertEqual(sum(len(x.bottom_keys)-1 for x in egg.regions[1:-1]),SECTORS)

    def test_side_seams_shared_and_compatible(self):
        strips=self.egg.regions[1:-1]
        for left,right in zip(strips,strips[1:]):
            width_left=len(left.bottom_keys)
            width_right=len(right.bottom_keys)
            self.assertEqual(left.bottom_keys[-1][1],right.bottom_keys[0][1])
            for row in range(UPPER_ROWS+1):
                self.assertIs(left.vertices[row*width_left+width_left-1],
                              right.vertices[row*width_right])
                self.assertIs(left.vertices[len(left.vertices)//2+row*width_left+width_left-1],
                              right.vertices[len(right.vertices)//2+row*width_right])
        # The complete ring, including wraparound at sector 0/192.
        first,last=strips[0],strips[-1]
        width_last=len(last.bottom_keys)
        for row in range(UPPER_ROWS+1):
            self.assertIs(first.vertices[row*len(first.bottom_keys)],
                          last.vertices[row*width_last+width_last-1])

    def test_upper_cap_share_all_crown_samples_by_identity(self):
        egg=self.egg
        cap=egg.regions[-1]
        outer_count=len(cap.vertices)//2
        for i in range(SECTORS):
            self.assertIs(cap.vertices[i],egg.strips[-1][i])
            self.assertIs(cap.vertices[outer_count+i],egg.global_inner[
                len(egg.cradle.vertices)//2+(UPPER_ROWS-1)*SECTORS+i])
        self.assertEqual(len(egg.crown),CAP_ROWS)

    def test_volume_conserved_by_partition(self):
        egg=self.egg
        mother=signed_volume(egg.mother_vertices,egg.mother_faces)
        children=sum(signed_volume(region.vertices,region.faces)
                     for region in egg.regions)
        self.assertGreater(mother,100_000)
        self.assertAlmostEqual(children/mother,1.,places=9)

    def test_thickness_and_surface_are_constant(self):
        egg=self.egg
        shift=len(egg.global_outer)
        for j in range(0,shift,13):
            a,b=egg.mother_vertices[j],egg.mother_vertices[j+shift]
            self.assertAlmostEqual(math.dist(a,b),THICKNESS,places=7)
        for row in (0,2,7,15,20):
            for i in (0,31,79,138,191):
                a=displaced_angle(row,i)
                t=row/UPPER_ROWS
                y=rim_y(a)*(1-t)+crown_y(a)*t
                self.assertEqual(egg.strips[row][i],surface(y,a))

    def test_deterministic_full_egg(self):
        same=build_whole_egg()
        self.assertEqual(same.mother_vertices,self.egg.mother_vertices)
        self.assertEqual(same.mother_faces,self.egg.mother_faces)
        self.assertEqual([r.faces for r in same.regions],[r.faces for r in self.egg.regions])

    def test_no_unapproved_change_to_crown_or_cradle(self):
        from scene_00 import build_shell
        old_v,old_f=build_shell()
        self.assertEqual(self.egg.cradle.vertices,tuple(old_v))
        self.assertEqual(self.egg.cradle.faces,tuple(old_f))
        self.assertEqual(SIDE_CUTS[0],0)
        self.assertEqual(SIDE_CUTS[-1],192)

if __name__=='__main__':
    unittest.main()
