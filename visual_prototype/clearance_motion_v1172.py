"""V11.72 — narrow correction of two confirmed shell/bowl collisions.

The meshes and contact-derived hinges are unchanged from V11.71. Two pieces
move a few 3D units radially after the local seam starts to open, reflecting
progressive tearing of a nonstraight contact line rather than an impossible
perfect hinge along the entire curved edge. A bounded post-release outward
movement prevents the last lateral piece falling through the cradle. The cap
inherits its parent's translation so the parent/child seam stays coincident.

Diagnostic only; no physics solver, triangle-triangle clearance guarantee
between samples, or Flutter integration.
"""
import math
import hinge_motion_v1171 as base

EARLY_CLEARANCE = {'upper_organic_01': 6.0, 'upper_organic_04': 5.0}
RELEASE_CLEARANCE = {'upper_organic_04': 12.0}
OPEN_RAMP = {'upper_organic_01': .025, 'upper_organic_04': .015}


def correction_shift(name, t, hinges):
    """World-space offset, C1 continuous and identically zero before opening."""
    if name not in EARLY_CLEARANCE:
        return (0., 0., 0.)
    hinge = hinges[name]
    start = base.OPEN_START[name]
    release = base.DETACH_AT[name]
    ramp = base.smoothstep((t - start) / OPEN_RAMP[name])
    later = base.smoothstep((t-release)/(1-release))
    distance = EARLY_CLEARANCE[name]*ramp + RELEASE_CLEARANCE.get(name,0.)*later
    radial = base.unit((hinge.pivot[0],hinge.pivot[1],0.))
    return base.SCALE(radial,distance)


def rigid_poses(t, hinges):
    """Exact V11.71 poses except for two clearances and the cap's inheritance."""
    original = base.rigid_poses(t, hinges)
    result = dict(original)
    for name in EARLY_CLEARANCE:
        pose = original[name]
        result[name] = base.Pose(pose.rotation,base.V(pose.translation,correction_shift(name,t,hinges)))
    cap = original[base.CAP]
    result[base.CAP] = base.Pose(cap.rotation,
        base.V(cap.translation,correction_shift(base.CAP_PARENT,t,hinges)))
    return result


def diagnostic(parts,frames=(0,.1,.25,.5,.65,.75,.85,1)):
    hinges=base.make_hinges(parts)
    return {'corrections':EARLY_CLEARANCE,
            'post_release':RELEASE_CLEARANCE,
            'frames':[{'fraction':t,
                       'potential_pairs':base.broadphase_pairs(parts,rigid_poses(t,hinges))}
                      for t in frames],
            'note':'AABB broadphase only; use collision_check_v1172.py for sampled triangle contacts.'}

if __name__=='__main__':
    import json,sys
    from pathlib import Path
    if len(sys.argv)!=3:
        raise SystemExit('Usage: python clearance_motion_v1172.py original_v1170.obj output.json')
    model=base.read_obj(sys.argv[1])
    Path(sys.argv[2]).write_text(json.dumps(diagnostic(model),indent=2),encoding='utf8')


def export_obj(path, parts, poses):
    """A static Blender inspection pose: same meshes, no resizing or simulation."""
    with open(path,'w',encoding='utf8') as output:
        offset=0
        for part in parts:
            output.write(f'o {part.name}\ng {part.name}\n')
            pose=poses[part.name]
            for vertex in part.vertices:
                x,y,z=pose.move(vertex)
                output.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
            for a,b,c in part.faces:
                output.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(part.vertices)
