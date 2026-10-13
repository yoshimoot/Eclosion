"""V11.71 geometry/kinematics tests, isolated from Flutter and Blender."""
import math
import os
from pathlib import Path
import tempfile
import unittest
import hinge_motion_v1171 as h


def model_path():
    override=os.getenv('ECLOSION_REFERENCE_OBJ')
    if override:return Path(override)
    # Regenerate V11.70 from canonical repo sources when running locally.
    import organic_network_v1170
    folder=tempfile.TemporaryDirectory()
    net=organic_network_v1170.design(organic_network_v1170.source_from_repo())
    path=Path(folder.name)/'v1170.obj'
    organic_network_v1170.export_obj(path,net)
    return folder,path

class HingeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture=model_path()
        if isinstance(fixture,tuple):
            cls.fixture,fixture=fixture
        cls.parts=h.read_obj(fixture)
        cls.hinges=h.make_hinges(cls.parts)

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls,'fixture'):cls.fixture.cleanup()

    def test_all_eight_hinges_derive_from_physical_shared_material(self):
        self.assertEqual(len(self.parts),9)
        self.assertEqual(len(self.hinges),8)
        seams=h.contacts(self.parts)
        for name,item in self.hinges.items():
            key=tuple(sorted((name,item.parent)))
            self.assertEqual(len(seams[key]),item.contact_edges)
            self.assertGreater(item.contact_length,50)
            self.assertAlmostEqual(h.NORM(item.axis),1,places=12)
            # Pivot is at the actual cumulative length midpoint of the seam.
            pivot,axis,length=h.longest_chain(seams[key])
            self.assertLess(h.NORM(h.SUB(pivot,item.pivot)),1e-8)
            self.assertAlmostEqual(length,item.contact_length,places=6)

    def test_cap_pole_is_one_solid_with_an_attached_parent(self):
        self.assertEqual(self.hinges[h.CAP].parent,h.CAP_PARENT)
        self.assertEqual(sum((0.,0.,220.) in p.vertices for p in self.parts),1)
        self.assertTrue((0.,0.,220.) in next(p for p in self.parts if p.name==h.CAP).vertices)
        self.assertTrue(all(self.hinges[p].parent==h.BOWL for p in h.UPPER_ORDER))

    def test_exact_intact_pose_and_static_bowl(self):
        poses=h.rigid_poses(0.,self.hinges)
        self.assertEqual(poses[h.BOWL],h.IDENTITY)
        for p in self.parts:
            self.assertEqual(poses[p.name],h.IDENTITY)
            for v in p.vertices[::max(1,len(p.vertices)//40)]:
                self.assertEqual(poses[p.name].move(v),v)
        self.assertEqual(h.rigid_poses(1.,self.hinges)[h.BOWL],h.IDENTITY)

    def test_no_scaling_or_vertex_deformation(self):
        for t in (.15,.35,.50,.70,.85,1.):
            poses=h.rigid_poses(t,self.hinges)
            for part in self.parts:
                pose=poses[part.name]
                verts=part.vertices
                step=max(1,len(verts)//15)
                for k in range(0,len(verts)-step,step):
                    a,b=verts[k],verts[k+step]
                    self.assertAlmostEqual(h.NORM(h.SUB(pose.move(a),pose.move(b))),
                                           h.NORM(h.SUB(a,b)),places=7)

    def test_c1_continuity_at_all_releases(self):
        for point in tuple(h.OPEN_START.values())+tuple(h.DETACH_AT.values()):
            l=h.rigid_poses(max(0,point-1e-7),self.hinges)
            r=h.rigid_poses(min(1,point+1e-7),self.hinges)
            for part in self.parts:
                pose_l,pose_r=l[part.name],r[part.name]
                for v in part.vertices[:3]:
                    self.assertLess(h.NORM(h.SUB(pose_l.move(v),pose_r.move(v))),.001)

    def test_parent_pose_is_composed_not_independent(self):
        t=.76
        poses=h.rigid_poses(t,self.hinges)
        own_hinge=self.hinges[h.CAP]
        start=h.OPEN_START[h.CAP];release=h.DETACH_AT[h.CAP]
        angle=.54*h.smoothstep((t-start)/(release-start))
        local=h.rotate_around(own_hinge.axis,angle,own_hinge.pivot)
        expected=poses[h.CAP_PARENT].compose(local)
        for v in next(p for p in self.parts if p.name==h.CAP).vertices[:6]:
            self.assertLess(h.NORM(h.SUB(poses[h.CAP].move(v),expected.move(v))),1e-7)

    def test_aabb_is_only_a_conservative_collision_diagnostic(self):
        for t in (0.,.35,.70,1.):
            poses=h.rigid_poses(t,self.hinges)
            boxes=h.transformed_aabbs(self.parts,poses)
            self.assertEqual(len(boxes),9)
            for part in self.parts:
                lo,hi=boxes[part.name]
                for v in part.vertices[::max(1,len(part.vertices)//20)]:
                    x=poses[part.name].move(v)
                    self.assertTrue(all(lo[i]-1e-8<=x[i]<=hi[i]+1e-8 for i in range(3)))
            candidates=h.broadphase_pairs(self.parts,poses)
            self.assertEqual(len(set(candidates)),len(candidates))
        self.assertGreater(len(h.broadphase_pairs(self.parts,h.rigid_poses(.7,self.hinges))),0)

if __name__=='__main__':unittest.main()
