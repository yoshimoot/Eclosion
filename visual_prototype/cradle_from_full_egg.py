"""V11.66 -- Bowl silhouette from ONE full-egg 3D fracture, not a prefabricated bowl.

The cut path is specified as a stress-driven contour on the SAME EggShellModel
surface as the intact egg. A single adaptive surface tessellation embeds the
fracture into the entire egg first; face ownership is assigned only AFTER the
complete (closed) mother shell is constructed. The lower-pole component is the
resulting cradle. No 2D clip, opaque patch or dimensional shrinking.

This stage validates ONE design issue: believable 3D cradle geometry. The large
upper region is intentionally not yet subdivided into an organic hatch network.
"""
from collections import defaultdict
from dataclasses import dataclass
import math
from pathlib import Path

from scene_00 import HALF_HEIGHT, THICKNESS, surface, inward_normal
from whole_mother_graph import _region, signed_volume, _edge_faces

SECTORS = 192
TOP_STEPS = 38
BOTTOM_STEPS = 34
RINGS = TOP_STEPS + BOTTOM_STEPS + 1

# Source art constraints (front = theta 0, left/right at -/+ pi/2):
# a deep central opening, raised lateral shell lips, and asymmetric rear.
# These are fracture guide points, not a separate bol geometry or 2D mask.
# 1st/last stations coincide on the hidden rear seam.
CUT_GUIDES = (
    (-math.pi, 32.), (-2.78, 37.), (-2.53, 24.),
    (-2.20, -2.), (-1.93, 12.), (-1.68, -35.),
    (-1.48, -11.), (-1.25, 13.), (-1.04, 28.),
    (-.75, 66.), (-.55, 79.), (-.32, 91.),
    (-.12, 117.), (.05, 97.), (.28, 111.),
    (.53, 68.), (.75, 66.), (1.02, 24.),
    (1.23, -11.), (1.52, -31.), (1.76, -13.),
    (2.04, -7.), (2.22, 27.), (2.49, 19.),
    (2.76, 43.), (math.pi, 32.),
)


def fracture_y(theta):
    """Fixed, bounded contour of the true shell crack, in egg-local Y.

    Sharp short turns deliberately break the edge while broad scale
    side/front curvature provides the physical bowl silhouette. Does not
    mutate individual fragment shapes independently of mother shell.
    """
    angle = (theta + math.pi) % (2*math.pi)-math.pi
    for (a,ya),(b,yb) in zip(CUT_GUIDES,CUT_GUIDES[1:]):
        if angle<=b:
            t=(angle-a)/(b-a)
            # Preserve angular fractures as a real, continuous zigzag.
            baseline=ya+(yb-ya)*t
            # Short non-periodic-looking chips on the same true 3D cut.
            teeth=(5.2*math.sin(17*angle+.23) +
                   2.8*math.sin(37*angle-.39)) * math.sin(math.pi*t)**2
            return max(-65.,min(128.,baseline+teeth))
    return CUT_GUIDES[-1][1]


@dataclass(frozen=True)
class Mother:
    vertices: tuple
    faces: tuple
    exterior: tuple
    poles: tuple
    border_ring: tuple


@dataclass(frozen=True)
class Result:
    mother: Mother
    pieces: tuple
    cradle: object
    cut_edges: frozenset
    labels: tuple


def build_full_mother():
    """Construct WHOLE egg first. Crack dictates remesh resolution only.

    Sampling alignment at crack is conventional 3D mesh refinement: mother
    is an intact *two-pole* watertight egg until faces are physically split.
    """
    outside=[];inside=[]
    for j in range(RINGS):
        for i in range(SECTORS):
            angle=2*math.pi*i/SECTORS
            seam=fracture_y(angle)
            if j<=TOP_STEPS:
                t=j/TOP_STEPS
                y=(-HALF_HEIGHT+2.0)*(1-t)+seam*t
            else:
                t=(j-TOP_STEPS)/BOTTOM_STEPS
                y=seam*(1-t)+(HALF_HEIGHT-2.0)*t
            p=surface(y,angle)
            inward=inward_normal(y,angle)
            outside.append(p)
            inside.append(tuple(p[k]+THICKNESS*inward[k] for k in range(3)))
    high=len(outside)
    outside.append((0.,0.,-HALF_HEIGHT))     # bottom pole
    outside.append((0.,0.,HALF_HEIGHT))      # top pole
    inside.append((0.,0.,-HALF_HEIGHT+THICKNESS))
    inside.append((0.,0.,HALF_HEIGHT-THICKNESS))
    bottom_pole=high; top_pole=high+1
    outer=[]
    for j in range(RINGS-1):
        for i in range(SECTORS):
            nxt=(i+1)%SECTORS
            a=j*SECTORS+i; b=j*SECTORS+nxt
            c=(j+1)*SECTORS+i;d=(j+1)*SECTORS+nxt
            outer.extend(((a,b,c),(b,d,c)))
    for i in range(SECTORS):
        nxt=(i+1)%SECTORS
        outer.append((top_pole,nxt,i))
        last=(RINGS-1)*SECTORS
        outer.append((last+i,last+nxt,bottom_pole))
    if signed_volume(outside,outer)<0:
        outer=[(a,c,b) for a,b,c in outer]
    shift=len(outside)
    inside_faces=[tuple(i+shift for i in reversed(tri)) for tri in outer]
    return Mother(tuple(outside+inside),tuple(outer+inside_faces),tuple(outer),
                  (bottom_pole,top_pole),tuple(TOP_STEPS*SECTORS+i for i in range(SECTORS)))


def cut_mother(mother=None):
    mother=mother or build_full_mother()
    face_edges=_edge_faces(mother.exterior)
    border=set()
    for i in range(SECTORS):
        a=mother.border_ring[i]
        b=mother.border_ring[(i+1)%SECTORS]
        border.add((min(a,b),max(a,b)))
    if not border.issubset(face_edges):
        raise ValueError('The actual 3D fracture must follow mother mesh edges')
    neighbors=defaultdict(list)
    for edge,owners in face_edges.items():
        if len(owners)!=2:raise ValueError('Mother surface is open')
        if edge not in border:
            a,b=owners
            neighbors[a].append(b);neighbors[b].append(a)
    labels=[-1]*len(mother.exterior)
    groups=[]
    for fi in range(len(labels)):
        if labels[fi]>=0:continue
        label=len(groups); queue=[fi];labels[fi]=label
        for current in queue:
            for nxt in neighbors[current]:
                if labels[nxt]<0:
                    labels[nxt]=label;queue.append(nxt)
        groups.append(queue)
    if len(groups)!=2:raise ValueError('Crack does not separate exactly two solids')
    bottom_face=next(i for i,f in enumerate(mother.exterior) if mother.poles[0] in f)
    bottom_label=labels[bottom_face]
    pieces=tuple(_region('fracture_derived_cradle' if idx==bottom_label else
                         'upper_source_shell',
                         [mother.exterior[f] for f in faces],mother)
                 for idx,faces in enumerate(groups))
    physical=frozenset(edge for edge,ab in face_edges.items()
                       if labels[ab[0]]!=labels[ab[1]])
    if physical!=frozenset(border):raise ValueError('Nonphysical/artificial cracks')
    return Result(mother,pieces,pieces[bottom_label],physical,tuple(labels))


def write_obj(file,result,*,only_cradle=False):
    with Path(file).open('w',encoding='utf8') as out:
        parts=(result.cradle,) if only_cradle else result.pieces
        offset=0
        for part in parts:
            out.write(f'o {part.name}\ng {part.name}\n')
            for x,y,z in part.vertices:
                out.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
            for a,b,c in part.faces:
                out.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(part.vertices)

if __name__=='__main__':
    import sys
    state=cut_mother()
    print('V11.66', len(state.pieces),'solids',len(state.cut_edges),'3D fracture edges')
    if '--obj' in sys.argv:
        write_obj(sys.argv[sys.argv.index('--obj')+1],state,
                  only_cradle='--only-cradle' in sys.argv)
