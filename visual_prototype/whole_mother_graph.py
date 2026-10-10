"""V11.64 | mother shell FIRST, then a physical fracture graph, then the cradle.

Independent study. Does not import build_shell() or rim_y(). The lower shell
is identified by connectivity to the bottom pole AFTER cutting source mesh.
No Flutter changes, no masks, no prebuilt bowl and no per-frame randomness.
"""
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import math
from scene_00 import HALF_HEIGHT, THICKNESS, surface, inward_normal

SECTORS = 160
RINGS = 72
# Graph heights are angular *fracture guide nodes*, NOT a built bowl surface.
# Normalized to original full-egg vertical coordinate: 0 top, 1 bottom.
LOWER_GUIDES = ((0, .66), (.10, .54), (.19, .58), (.28, .72),
                (.38, .64), (.50, .72), (.61, .67), (.74, .55),
                (.83, .62), (.92, .70), (1, .66))


def mother_shell():
    """Closed dual-sided full egg from pole to pole; no lower division."""
    outer=[]; inner=[]
    for j in range(RINGS):
        y = -HALF_HEIGHT + 3 + (2 * HALF_HEIGHT - 6) * j/(RINGS-1)
        for i in range(SECTORS):
            a=2*math.pi*i/SECTORS
            p=surface(y,a); n=inward_normal(y,a)
            outer.append(p)
            inner.append(tuple(p[k]+THICKNESS*n[k] for k in range(3)))
    outer += [(0.,0.,HALF_HEIGHT),(0.,0.,-HALF_HEIGHT)]
    inner += [(0.,0.,HALF_HEIGHT-THICKNESS),(0.,0.,-HALF_HEIGHT+THICKNESS)]
    front=[]
    for j in range(RINGS-1):
        for i in range(SECTORS):
            nxt=(i+1)%SECTORS
            a=j*SECTORS+i; b=j*SECTORS+nxt
            c=(j+1)*SECTORS+i; d=(j+1)*SECTORS+nxt
            front.extend(((a,b,c),(b,d,c)))
    north=RINGS*SECTORS; south=north+1
    for i in range(SECTORS):
        nxt=(i+1)%SECTORS
        front.append((north,nxt,i))
        a=(RINGS-1)*SECTORS+i
        b=(RINGS-1)*SECTORS+nxt
        front.append((a,b,south))
    # Correct orientation once, using the outer surface signed volume.
    if signed_volume(outer,front)<0:
        front=[(a,c,b) for a,b,c in front]
    shift=len(outer)
    faces=tuple(front+[tuple(shift+v for v in reversed(t)) for t in front])
    return FullMother(tuple(outer+inner),faces,tuple(front),north,south)


def signed_volume(v,faces):
    terms=[]
    for a,b,c in faces:
        x,y,z=v[a],v[b],v[c]
        terms.append((x[0]*(y[1]*z[2]-y[2]*z[1])+
                      x[1]*(y[2]*z[0]-y[0]*z[2])+
                      x[2]*(y[0]*z[1]-y[1]*z[0]))/6)
    return math.fsum(terms)


@dataclass(frozen=True)
class FullMother:
    vertices: tuple
    faces: tuple
    outer_faces: tuple
    top_pole: int
    bottom_pole: int


@dataclass(frozen=True)
class Region:
    name: str
    vertices: tuple
    faces: tuple
    outside: tuple


@dataclass(frozen=True)
class CutResult:
    mother: FullMother
    graph_edges: frozenset
    parts: tuple
    bottom_part: Region
    boundary_edges: frozenset


def _edge_faces(faces):
    result=defaultdict(list)
    for idx,(a,b,c) in enumerate(faces):
        for u,v in ((a,b),(b,c),(c,a)):
            result[(min(u,v),max(u,v))].append(idx)
    return result


def _guide_at(u):
    for (a,ya),(b,yb) in zip(LOWER_GUIDES,LOWER_GUIDES[1:]):
        if u<=b:
            t=(u-a)/(b-a)
            return ya+(yb-ya)*t
    return LOWER_GUIDES[-1][1]


def fracture_graph():
    """Physical edges on full mother, a CLOSED crack loop, not a bol mask."""
    target=[max(3,min(RINGS-4,round(_guide_at(i/SECTORS)*(RINGS-1))))
            for i in range(SECTORS)]
    edges=set()
    for i in range(SECTORS):
        next_i=(i+1)%SECTORS
        row=target[i]; nextrow=target[next_i]
        # Horizontal first, then each real vertical material edge on the
        # next meridian. These are all actual pre-existing triangle edges.
        a=row*SECTORS+i; b=row*SECTORS+next_i
        edges.add((min(a,b),max(a,b)))
        for r in range(min(row,nextrow),max(row,nextrow)):
            x=r*SECTORS+next_i; y=(r+1)*SECTORS+next_i
            edges.add((x,y))
    return frozenset(edges)


def _region(name,triangles,mother):
    unique={};front=[]
    for tri in triangles:
        face=[]
        for vertex in tri:
            if vertex not in unique:unique[vertex]=len(unique)
            face.append(unique[vertex])
        front.append(tuple(face))
    original=tuple(unique)
    shift=len(original); half=len(mother.vertices)//2
    verts=tuple(mother.vertices[i] for i in original)+tuple(
        mother.vertices[half+i] for i in original)
    faces=list(front)+[tuple(shift+i for i in reversed(t)) for t in front]
    incidence=defaultdict(list)
    for a,b,c in front:
        for u,v in ((a,b),(b,c),(c,a)):
            incidence[(min(u,v),max(u,v))].append((u,v))
    for owners in incidence.values():
        if len(owners)!=1:continue
        u,v=owners[0]
        # Canonical diagonal by original global vertex ID, shared by both
        # sides of a cut even when the quadrilateral is not planar.
        if original[u]<original[v]:
            faces += [(v,u,v+shift),(u,u+shift,v+shift)]
        else:
            faces += [(v,u,u+shift),(v,u+shift,v+shift)]
    return Region(name,verts,tuple(faces),tuple(front))


def cut_full_mother(mother=None):
    mother=mother or mother_shell()
    cuts=fracture_graph()
    incident=_edge_faces(mother.outer_faces)
    if not cuts.issubset(incident):raise ValueError('Graph goes outside mother mesh')
    neighbours=defaultdict(list)
    for edge,owners in incident.items():
        if len(owners)!=2:raise ValueError('Open source egg')
        if edge not in cuts:
            a,b=owners
            neighbours[a].append(b);neighbours[b].append(a)
    labels=[-1]*len(mother.outer_faces)
    groups=[]
    for start in range(len(labels)):
        if labels[start]>=0:continue
        part_id=len(groups);todo=[start];labels[start]=part_id
        for at in todo:
            for other in neighbours[at]:
                if labels[other]<0:
                    labels[other]=part_id;todo.append(other)
        groups.append(todo)
    bottom_face=next(i for i,tri in enumerate(mother.outer_faces)
                     if mother.bottom_pole in tri)
    bottom_label=labels[bottom_face]
    parts=tuple(_region('lower_cradle_from_graph' if i==bottom_label else
                        'detached_upper_shell_'+str(i),
                        [mother.outer_faces[k] for k in group],mother)
                for i,group in enumerate(groups))
    real_cuts=frozenset(edge for edge,owners in incident.items()
                       if labels[owners[0]]!=labels[owners[1]])
    if cuts!=real_cuts:raise ValueError('Some crack edges fail to separate material')
    return CutResult(mother,cuts,parts,parts[bottom_label],real_cuts)


def export_obj(path,result,*,exploded=False):
    with Path(path).open('w',encoding='utf-8') as f:
        offset=0
        for part in result.parts:
            f.write(f'o {part.name}\ng {part.name}\n')
            # Diagnostic object separation only. Original intact geometry
            # is exported with exploded=False, suitable for Blender.
            drift=(0,0,0) if not exploded or part is result.bottom_part else (0,0,58)
            for v in part.vertices:
                f.write('v '+' '.join(f'{v[k]+drift[k]:.8f}' for k in range(3))+'\n')
            for a,b,c in part.faces:
                f.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(part.vertices)


if __name__=='__main__':
    import sys
    r=cut_full_mother()
    print('full egg pieces',len(r.parts),'cradle vertices',len(r.bottom_part.vertices))
    if '--obj' in sys.argv:
        export_obj(sys.argv[sys.argv.index('--obj')+1],r,exploded='--exploded' in sys.argv)
