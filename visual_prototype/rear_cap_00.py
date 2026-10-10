"""V11.58: isolated upper-left shell-cap candidate for the final 00:00 frame.

The chick is not reconstructed. This mesh is a real curved two-face solid
cut from the same EggShellModel as scene_00, with a smooth upper dome and an
irregular lower fracture. It is NOT connected to the current fracture graph;
source material ownership still needs to be established before animation.
"""
from dataclasses import dataclass
import math
from scene_00 import HALF_HEIGHT, THICKNESS, surface, inward_normal, validate_shell

# Around the egg: theta 0 = front, negative = left, theta<-pi/2 = rear left.
ANGLE_LEFT = -2.08
ANGLE_RIGHT = -.08
SECTIONS = 72
ROWS = 16

# Height values use EggShellModel's downward-positive Y. The upper contour
# follows the curved eggshell dome. Unlike the older V11.57 standing panel,
# the exposed *lower* boundary is the irregular fracture seen in the artwork.
DOME_STATIONS = (
    (0.0, -34.), (.18, -89.), (.38, -143.),
    (.62, -175.), (.83, -182.), (1., -154.),
)
LOWER_CRACK_STATIONS = (
    (0., -10.), (.08, 0.), (.16, -26.), (.23, -18.),
    (.31, -43.), (.40, -34.), (.49, -62.),
    (.58, -51.), (.67, -81.), (.76, -72.),
    (.85, -108.), (.93, -113.), (1., -150.),
)


def _station_value(t, stations, smooth):
    for (at, value), (next_at, next_value) in zip(stations, stations[1:]):
        if t <= next_at:
            u = (t - at) / (next_at - at)
            if smooth:
                u = u*u*(3.-2.*u)
            return value + (next_value - value)*u
    return stations[-1][1]


def cap_cuts(t):
    """One actual upper/lower boundary pair, deterministic per latitude."""
    if not 0 <= t <= 1:
        raise ValueError('Cap angular fraction outside [0,1]')
    upper = _station_value(t, DOME_STATIONS, smooth=True)
    lower = _station_value(t, LOWER_CRACK_STATIONS, smooth=False)
    if upper >= lower - 2.5:
        raise ValueError('Self-overlapping shell cap boundary')
    return upper, lower


@dataclass(frozen=True)
class RearCap:
    vertices: tuple
    faces: tuple
    external_faces: tuple
    inner_faces: tuple
    wall_faces: tuple
    first_outer_row: tuple
    last_outer_row: tuple
    thickness: float = THICKNESS


def build_rear_cap():
    front = []
    for j in range(ROWS+1):
        blend = j/ROWS
        for i in range(SECTIONS+1):
            t = i/SECTIONS
            theta = ANGLE_LEFT+(ANGLE_RIGHT-ANGLE_LEFT)*t
            upper,lower = cap_cuts(t)
            y = lower + (upper-lower)*blend
            if y <= -HALF_HEIGHT or y >= HALF_HEIGHT:
                raise ValueError('Shell cap outside source surface')
            front.append(surface(y, theta))
    stride = SECTIONS+1
    shift = len(front)
    back = []
    for j in range(ROWS+1):
        blend = j/ROWS
        for i in range(SECTIONS+1):
            t = i/SECTIONS
            theta = ANGLE_LEFT+(ANGLE_RIGHT-ANGLE_LEFT)*t
            upper,lower = cap_cuts(t)
            y = lower+(upper-lower)*blend
            n = inward_normal(y,theta)
            p=front[j*stride+i]
            back.append(tuple(p[k]+n[k]*THICKNESS for k in range(3)))
    external=[]
    for j in range(ROWS):
        for i in range(SECTIONS):
            a = j*stride+i
            b = a+1
            c = a+stride
            d = c+1
            external.extend(((a,b,c),(b,d,c)))
    inner=[tuple(v+shift for v in reversed(t)) for t in external]
    directed={}
    for a,b,c in external:
        for u,v in ((a,b),(b,c),(c,a)):
            key=(min(u,v),max(u,v))
            directed.setdefault(key,[]).append((u,v))
    rim=[v[0] for v in directed.values() if len(v)==1]
    if len(rim)!=2*SECTIONS+2*ROWS:
        raise ValueError('Invalid cap perimeter')
    walls=[]
    for u,v in rim:
        walls.extend(((v,u,u+shift),(v,u+shift,v+shift)))
    # Same winding convention as the existing Blender procedural meshes.
    faces=list(external+inner+walls)
    ext=list(external)
    ins=list(inner)
    sides=list(walls)
    vertices=tuple(front+back)
    validate_shell(vertices,faces)
    return RearCap(vertices,tuple(faces),tuple(ext),tuple(ins),tuple(sides),
                   tuple(front[:stride]), tuple(front[-stride:]))


def write_obj(path, cap):
    from pathlib import Path
    with Path(path).open('w',encoding='utf8') as f:
        f.write('# Independent material shell cap: V11.58 diagnostic only\n')
        f.write('o rear_upper_cap_candidate\n')
        for x,y,z in cap.vertices:
            f.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
        for a,b,c in cap.faces:
            f.write(f'f {a+1} {b+1} {c+1}\n')


if __name__=='__main__':
    cap=build_rear_cap()
    print('Rear cap:',len(cap.vertices),'vertices',len(cap.faces),'triangles')
    import sys
    if '--obj' in sys.argv:
        write_obj(sys.argv[sys.argv.index('--obj')+1],cap)
