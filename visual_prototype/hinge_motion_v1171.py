"""V11.71 — contact-derived diagnostic hinges for the immutable V11.70 OBJ.

This is NOT a completed collision solver, nor the Flutter animation. Static
shell meshes stay untouched. Seven pieces hinge from the approved lower bowl;
the polar cap is a child of a lateral piece and initially follows its pose.
Only rigid transforms act on whole meshes. Contacts use EXACT source vertices
and shared cut EDGES, never an independent painted/approximate fracture.
"""
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import math
import sys

BOWL='lower_cradle_from_V11_66'
CAP='upper_organic_00'
CAP_PARENT='upper_organic_04'
UPPER_ORDER=('upper_organic_01','upper_organic_02','upper_organic_07',
             'upper_organic_03','upper_organic_06','upper_organic_05','upper_organic_04')
# The sequence is diagnostic and is not a timing integration contract.
OPEN_START={name:0.04+i*.085 for i,name in enumerate(UPPER_ORDER)}
DETACH_AT={name:0.50+i*.060 for i,name in enumerate(UPPER_ORDER)}
OPEN_START[CAP]=0.54
DETACH_AT[CAP]=0.91

V=lambda a,b:(a[0]+b[0],a[1]+b[1],a[2]+b[2])
SUB=lambda a,b:(a[0]-b[0],a[1]-b[1],a[2]-b[2])
SCALE=lambda a,t:(a[0]*t,a[1]*t,a[2]*t)
DOT=lambda a,b:a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
CROSS=lambda a,b:(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
NORM=lambda a:math.sqrt(DOT(a,a))

def unit(a):
    norm=NORM(a)
    if norm<1e-8:raise ValueError('Degenerate hinge axis')
    return SCALE(a,1/norm)

@dataclass(frozen=True)
class Part:
    name:str
    vertices:tuple
    faces:tuple

@dataclass(frozen=True)
class Hinge:
    name:str
    parent:str
    pivot:tuple
    axis:tuple
    contact_length:float
    contact_edges:int
    def to_dict(self):
        return dict(name=self.name,parent=self.parent,pivot=self.pivot,
                    axis=self.axis,contact_length=round(self.contact_length,3),
                    contact_edges=self.contact_edges,
                    opens_at=OPEN_START[self.name],detaches_at=DETACH_AT[self.name])

@dataclass(frozen=True)
class Pose:
    rotation:tuple
    translation:tuple
    def move(self,point):return V(matvec(self.rotation,point),self.translation)
    def compose(self,child):
        return Pose(tuple(tuple(DOT(row,col) for col in zip(*child.rotation))
                          for row in self.rotation),
                    V(matvec(self.rotation,child.translation),self.translation))

IDENTITY=Pose(((1.,0.,0.),(0.,1.,0.),(0.,0.,1.)),(0.,0.,0.))

def matvec(M,p):return tuple(DOT(row,p) for row in M)

def rotation(axis,angle):
    x,y,z=unit(axis);c=math.cos(angle);s=math.sin(angle);t=1-c
    return ((t*x*x+c,t*x*y-s*z,t*x*z+s*y),
            (t*x*y+s*z,t*y*y+c,t*y*z-s*x),
            (t*x*z-s*y,t*y*z+s*x,t*z*z+c))

def rotate_around(axis,angle,pivot,shift=(0.,0.,0.)):
    R=rotation(axis,angle)
    return Pose(R,V(SUB(pivot,matvec(R,pivot)),shift))

def read_obj(path):
    """Load standard untextured multiobject OBJ with one local vertex list/object."""
    parts=[];name=None;vertices=[];faces=[];before=0
    with Path(path).open(encoding='utf8') as data:
        lines=data.readlines()
    for line in lines:
        if line.startswith('o '):
            if name is not None:
                parts.append(Part(name,tuple(vertices),tuple(faces)))
                before+=len(vertices)
            name=line[2:].strip();vertices=[];faces=[]
        elif line.startswith('v '):
            if name is None:raise ValueError('OBJ vertices before first object')
            vertices.append(tuple(float(v) for v in line.split()[1:]))
        elif line.startswith('f '):
            if name is None:raise ValueError('OBJ faces before first object')
            ids=tuple(int(v.split('/')[0])-before-1 for v in line.split()[1:])
            if len(ids)!=3 or min(ids)<0 or max(ids)>=len(vertices):
                raise ValueError('Invalid triangle index')
            faces.append(ids)
    if name is not None:parts.append(Part(name,tuple(vertices),tuple(faces)))
    if len({p.name for p in parts})!=len(parts):raise ValueError('Duplicate shell name')
    return tuple(parts)

def exterior_rim(part):
    """Count undirected edges belonging to precisely one exterior triangle."""
    limit=len(part.vertices)//2
    if not limit or len(part.vertices)!=2*limit:raise ValueError('Missing inner material')
    count=defaultdict(int)
    for a,b,c in part.faces:
        if max(a,b,c)>=limit:continue
        for u,v in ((a,b),(b,c),(c,a)):
            count[tuple(sorted((part.vertices[u],part.vertices[v])))]+=1
    return {edge for edge,owners in count.items() if owners==1}

def contacts(parts):
    claimed=defaultdict(list)
    for part in parts:
        for edge in exterior_rim(part):claimed[edge].append(part.name)
    if any(len(names)!=2 for names in claimed.values()):
        raise ValueError('Open or triply owned material seam')
    pairs=defaultdict(list)
    for edge,owners in claimed.items():
        key=tuple(sorted(owners));pairs[key].append(edge)
    return dict(pairs)

def longest_chain(edges):
    """Recover an actual shared cut polyline and choose a robust local tangent."""
    neighbors=defaultdict(list)
    for a,b in edges:
        neighbors[a].append(b);neighbors[b].append(a)
    terminals=sorted(v for v,around in neighbors.items() if len(around)==1)
    if len(terminals)!=2 or any(len(around)>2 for around in neighbors.values()):
        raise ValueError('Expected a single unbranched two-ended contact seam')
    ordered=[terminals[0]]
    while ordered[-1]!=terminals[1]:
        current=ordered[-1]
        options=[v for v in neighbors[current] if len(ordered)<2 or v!=ordered[-2]]
        if len(options)!=1:raise ValueError('Broken hinge contact line')
        ordered.append(options[0])
        if len(ordered)>len(edges)+1:raise ValueError('Looping hinge contact line')
    if len(ordered)!=len(edges)+1:raise ValueError('Disconnected seam')
    length=sum(NORM(SUB(b,a)) for a,b in zip(ordered,ordered[1:]))
    distance=[0.]
    for a,b in zip(ordered,ordered[1:]):distance.append(distance[-1]+NORM(SUB(b,a)))
    def at(t):
        location=t*length
        for i in range(len(ordered)-1):
            if distance[i+1]>=location:
                frac=(location-distance[i])/(distance[i+1]-distance[i])
                return V(SCALE(ordered[i],1-frac),SCALE(ordered[i+1],frac))
        return ordered[-1]
    return at(.5),unit(SUB(at(.66),at(.34))),length

def make_hinges(parts):
    by_name={p.name:p for p in parts}; contact=contacts(parts)
    required={BOWL,CAP,*UPPER_ORDER}
    if set(by_name)!=required:raise ValueError('V11.70 nine-object contract changed')
    hinges={}
    for name in (*UPPER_ORDER,CAP):
        parent=CAP_PARENT if name==CAP else BOWL
        seam=contact.get(tuple(sorted((parent,name))))
        if not seam:raise ValueError(f'No physical hinge between {name} and {parent}')
        pivot,axis,length=longest_chain(seam)
        center=tuple(sum(v[i] for v in by_name[name].vertices[:len(by_name[name].vertices)//2])/
                     (len(by_name[name].vertices)//2) for i in range(3))
        outward=unit((center[0],center[1],0.))
        delta=CROSS(axis,SUB(center,pivot))
        if DOT(delta,outward)<0:axis=SCALE(axis,-1.)
        hinges[name]=Hinge(name,parent,pivot,axis,length,len(seam))
    return hinges

def smoothstep(x):
    t=max(0.,min(1.,x));return t*t*(3-2*t)

def rigid_poses(t,hinges):
    """C1-continuous diagnostic swing and release, not collision-solved motion.

    A cap initially inherits its parent's full rigid pose; after detaching,
    it still composes with parent as a *visual study*. Its resulting trajectory
    is not a free physical rigid body and must be replaced after validation.
    """
    if not 0<=t<=1:raise ValueError('Progress must be in [0,1]')
    poses={BOWL:IDENTITY}
    for name in (*UPPER_ORDER,CAP):
        hinge=hinges[name]
        start=OPEN_START[name]; release=DETACH_AT[name]
        phase=smoothstep((t-start)/(release-start))
        angle=(.70 if name!=CAP else .54)*phase
        after=max(0.,t-release)
        r=math.hypot(hinge.pivot[0],hinge.pivot[1])
        radial=(hinge.pivot[0]/r,hinge.pivot[1]/r,0.) if r>1e-8 else (0.,1.,0.)
        shift=V(SCALE(radial,105*after*after), (0.,0.,-210*after*after))
        own=rotate_around(hinge.axis,angle,hinge.pivot,shift)
        poses[name]=poses[hinge.parent].compose(own)
    return poses

def transformed_aabbs(parts,poses):
    """Broad phase ONLY: overlapping bounding boxes aren't true collisions."""
    result={}
    for part in parts:
        pose=poses[part.name]
        # AABB of the 8 OBB corners is conservative and cheap for rigid bodies.
        lo=[min(v[i] for v in part.vertices) for i in range(3)]
        hi=[max(v[i] for v in part.vertices) for i in range(3)]
        corners=[pose.move((x,y,z)) for x in (lo[0],hi[0])
                 for y in (lo[1],hi[1]) for z in (lo[2],hi[2])]
        result[part.name]=(tuple(min(p[k] for p in corners) for k in range(3)),
                           tuple(max(p[k] for p in corners) for k in range(3)))
    return result

def broadphase_pairs(parts,poses):
    box=transformed_aabbs(parts,poses)
    names=sorted(box)
    return tuple((a,b) for ia,a in enumerate(names) for b in names[ia+1:]
                 if all(max(box[a][0][i],box[b][0][i]) <=
                        min(box[a][1][i],box[b][1][i]) for i in range(3)))

def diagnostic(parts,frames=(0.,.15,.35,.55,.75,.95,1.)):
    hinges=make_hinges(parts)
    return {'hinges':[hinges[p.name].to_dict() for p in parts if p.name in hinges],
            'frames':[{'fraction':t,'aabb_potential_pairs':list(broadphase_pairs(parts,rigid_poses(t,hinges)))}
                      for t in frames],
            'notes':'Broad phase does NOT establish actual collisions or absence of intersections.'}

if __name__=='__main__':
    import json
    if len(sys.argv)!=3:
        raise SystemExit('Usage: python hinge_motion_v1171.py input_v1170.obj report.json')
    report=diagnostic(read_obj(sys.argv[1]))
    Path(sys.argv[2]).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('8 true seam hinges; diagnostic broadphase computed')
