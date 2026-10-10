"""V11.62 deterministic shared fracture network and reconstruction checks."""
from collections import defaultdict
import math
import tempfile
import unittest
from pathlib import Path

from organic_network import build_fracture_network, _edge_map, write_obj, SEEDS
from scene_00 import THICKNESS


def signed_volume(vertices,faces):
    total=[]
    for a,b,c in faces:
        x,y,z=(vertices[i] for i in (a,b,c))
        total.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(total)


class NetworkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.network=build_fracture_network()

    def test_unmodified_mother_model_and_retained_shell_pieces(self):
        n=self.network
        self.assertIs(n.mother_vertices,n.source.mother_vertices)
        self.assertIs(n.mother_faces,n.source.mother_faces)
        self.assertEqual(len(n.regions),len(SEEDS)+2)
        self.assertEqual(set(n.seed_names),{'lower_cradle','upper_cap'}|
                         {f'organique_{i:02d}' for i in range(len(SEEDS))})

    def test_closed_shells_with_shared_original_points(self):
        n=self.network
        outercount=len(n.mother_vertices)//2
        canonical={id(p):i for i,p in enumerate(n.mother_vertices)}
        for region in n.regions:
            self.assertEqual(region.thickness,THICKNESS)
            side=len(region.vertices)//2
            self.assertTrue(0<len(region.exterior_faces)<len(region.faces))
            edges=defaultdict(list)
            for a,b,c in region.faces:
                for u,v in ((a,b),(b,c),(c,a)):
                    edges[(min(u,v),max(u,v))].append(1 if u<v else -1)
            self.assertTrue(all(sorted(x)==[-1,1] for x in edges.values()),region.name)
            for i in range(side):
                v=canonical[id(region.vertices[i])]
                self.assertIs(region.vertices[side+i],n.mother_vertices[v+outercount])
                self.assertAlmostEqual(math.dist(region.vertices[i],region.vertices[side+i]),
                                       THICKNESS,places=7)

    def test_outer_faces_owned_once_and_contact_walls_twice(self):
        n=self.network
        identities={id(x):i for i,x in enumerate(n.mother_vertices)}
        faces=defaultdict(list)
        for part in n.regions:
            for tri in part.faces:
                triplet=tuple(identities[id(part.vertices[i])] for i in tri)
                faces[tuple(sorted(triplet))].append(triplet)
        outer={tuple(sorted(t)) for t in n.mother_faces}
        self.assertEqual(outer,{key for key,owners in faces.items() if len(owners)==1})
        internal=0
        for own in faces.values():
            self.assertLessEqual(len(own),2)
            if len(own)==2:
                a,b=own
                self.assertIn(b,((a[0],a[2],a[1]),(a[1],a[0],a[2]),
                                 (a[2],a[1],a[0])))
                internal+=1
        self.assertGreater(internal,600)

    def test_each_fragment_is_one_connected_3d_object(self):
        # Pure Python: face-edge adjacency, no extra Blender/trimesh package.
        for region in self.network.regions:
            edge_faces=defaultdict(list)
            for idx,(a,b,c) in enumerate(region.faces):
                for u,v in ((a,b),(b,c),(c,a)):
                    edge_faces[(min(u,v),max(u,v))].append(idx)
            adjacency=[[] for _ in region.faces]
            for neighbours in edge_faces.values():
                self.assertEqual(len(neighbours),2)
                a,b=neighbours
                adjacency[a].append(b)
                adjacency[b].append(a)
            seen={0}; pending=[0]
            for at in pending:
                for other in adjacency[at]:
                    if other not in seen:
                        seen.add(other)
                        pending.append(other)
            self.assertEqual(len(seen),len(region.faces),region.name)
            self.assertGreater(signed_volume(region.vertices,region.faces),0)

    def test_volume_conserved_without_geometry_masks(self):
        n=self.network
        mother=signed_volume(n.mother_vertices,n.mother_faces)
        fragments=math.fsum(signed_volume(p.vertices,p.faces) for p in n.regions)
        self.assertGreater(mother,100000)
        self.assertLess(abs(mother-fragments)/mother,1e-9)

    def test_seams_have_real_branch_points_and_variable_patch_areas(self):
        n=self.network
        self.assertGreater(len(n.junctions),20)
        self.assertGreater(len(n.seams),700)
        sizes=[len(r.exterior_faces) for r in n.regions if r.name.startswith('organique_')]
        self.assertGreater(min(sizes),120)
        self.assertLess(max(sizes)/min(sizes),7)
        adjacency={tuple(sorted((a,b))) for _,a,b in n.seams}
        self.assertGreater(len(adjacency),30)

    def test_front_side_fissures_not_dominated_by_vertical_panels(self):
        n=self.network
        side_names={'lower_cradle','upper_cap'}
        def near_vertical_fraction(vertices,seams):
            sample=[]
            for i,j in seams:
                p,q=vertices[i],vertices[j]
                if (p[1]+q[1])/2 >=-16:continue
                dx=q[0]-p[0]; dz=q[2]-p[2]
                sample.append(abs(dx)<.32*abs(dz))
            return sum(sample)/len(sample)
        candidate=[edge for edge,a,b in n.seams
                   if a not in side_names and b not in side_names]
        # Derive V11.61's former long parent joints from the untouched mother.
        prev=n.source
        original_faces=prev.mother_faces[:len(prev.mother_faces)//2]
        old_owners=[r.name for r in prev.regions for _ in r.exterior_faces]
        old_seams=[edge for edge,adj in _edge_map(original_faces).items()
                   if len(adj)==2 and old_owners[adj[0]]!=old_owners[adj[1]]
                   and old_owners[adj[0]] not in side_names
                   and old_owners[adj[1]] not in side_names]
        self.assertLess(near_vertical_fraction(n.mother_vertices,candidate),
                        near_vertical_fraction(prev.mother_vertices,old_seams)-.04)

    def test_reproducibility_and_selection_in_obj(self):
        n=self.network
        again=build_fracture_network()
        self.assertEqual(n.assignments,again.assignments)
        self.assertEqual(n.seams,again.seams)
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'assembled.obj'
            write_obj(p,n)
            lines=p.read_text().splitlines()
            self.assertEqual(sum(x.startswith('o ') for x in lines),len(n.regions))
            self.assertGreater(sum(x.startswith('f ') for x in lines),30000)


if __name__=='__main__':unittest.main()
