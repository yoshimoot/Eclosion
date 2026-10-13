"""Regression gates for the limited V11.72 clearance change."""
import math
import os
import tempfile
from pathlib import Path
import unittest
import hinge_motion_v1171 as base
import clearance_motion_v1172 as candidate


class TestLimitedClearance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        filepath=os.environ.get('ECLOSION_REFERENCE_OBJ')
        if not filepath:
            from organic_network_v1170 import design, source_from_repo, export_obj
            cls.temporary=tempfile.TemporaryDirectory()
            filepath=Path(cls.temporary.name)/'v1170.obj'
            export_obj(filepath,design(source_from_repo()))
        cls.parts=base.read_obj(filepath)
        cls.hinges=base.make_hinges(cls.parts)
        cls.byname={x.name:x for x in cls.parts}

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls,'temporary'):cls.temporary.cleanup()

    def test_source_geometry_unchanged(self):
        self.assertEqual(len(self.parts),9)
        self.assertEqual(candidate.rigid_poses(0,self.hinges)[base.BOWL],base.IDENTITY)
        self.assertEqual(candidate.rigid_poses(0,self.hinges),base.rigid_poses(0,self.hinges))

    def test_only_two_and_their_direct_child_change(self):
        t=.75
        before=base.rigid_poses(t,self.hinges)
        after=candidate.rigid_poses(t,self.hinges)
        touched=set(candidate.EARLY_CLEARANCE)|{base.CAP}
        for name in before:
            if name not in touched:self.assertEqual(after[name],before[name])
        self.assertGreater(base.NORM(candidate.correction_shift('upper_organic_01',t,self.hinges)),0)
        self.assertGreater(base.NORM(candidate.correction_shift('upper_organic_04',t,self.hinges)),0)

    def test_cap_inherits_exact_world_translation(self):
        for t in (.5,.6,.75,.95,1):
            old=base.rigid_poses(t,self.hinges)
            new=candidate.rigid_poses(t,self.hinges)
            dp=base.SUB(new[base.CAP_PARENT].translation,old[base.CAP_PARENT].translation)
            dc=base.SUB(new[base.CAP].translation,old[base.CAP].translation)
            self.assertLess(base.NORM(base.SUB(dp,dc)),1e-10)
            self.assertEqual(new[base.CAP_PARENT].rotation,old[base.CAP_PARENT].rotation)

    def test_no_scaling_and_constant_material(self):
        for t in (.25,.5,.75,1):
            poses=candidate.rigid_poses(t,self.hinges)
            for p in self.parts:
                v=p.vertices
                a,b=v[0],v[len(v)//3]
                self.assertAlmostEqual(base.NORM(base.SUB(a,b)),
                    base.NORM(base.SUB(poses[p.name].move(a),poses[p.name].move(b))),places=7)

    def test_c1_continuity_for_ramp_and_release(self):
        for name in candidate.EARLY_CLEARANCE:
            start=base.OPEN_START[name];release=base.DETACH_AT[name]
            for t in (start, start+candidate.OPEN_RAMP[name],release):
                h=1e-5
                d0=candidate.correction_shift(name,t-h,self.hinges)
                d1=candidate.correction_shift(name,t,self.hinges)
                d2=candidate.correction_shift(name,t+h,self.hinges)
                self.assertLess(base.NORM(base.SUB(d2,d0)),.001)
                self.assertLess(base.NORM(base.SUB(base.V(d2,d0),base.SCALE(d1,2))),.0001)

    def test_postrelease_moves_further_without_modifying_bowl(self):
        d85=base.NORM(candidate.correction_shift('upper_organic_04',.85,self.hinges))
        d100=base.NORM(candidate.correction_shift('upper_organic_04',1,self.hinges))
        self.assertGreater(d100-d85,11.0)
        for t in (0,.25,.75,1):
            self.assertEqual(candidate.rigid_poses(t,self.hinges)[base.BOWL],base.IDENTITY)

if __name__=='__main__':unittest.main()
