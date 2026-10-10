"""V11.67: subdivide ONLY the upper mother shell around the approved cradle.

The V11.66 intact whole egg, lower break edge, and resulting cradle are
unchanged. All additional cuts are actual edges of the same mother mesh.
A hand-authored, asymmetric set of branch nodes defines the graph FIRST;
connected face regions become separately closed, 2.5-thick shell volumes.
No new bowl, masks, shrinkage, or frame-dependent random geometry.
"""
from collections import defaultdict
from dataclasses import dataclass
import heapq
import math
from pathlib import Path

import cradle_from_full_egg as base
from whole_mother_graph import _edge_faces, _region, signed_volume

# (latitude row above the approved cradle, angular sector on mother egg).
# The uneven internal ring is deliberately NOT a horizontal line or a set
# of parallel longitude panels. Outer/inner angular offsets yield diagonals.
INNER = ((11, 7), (21, 38), (10, 70), (20, 100),
         (12, 130), (22, 156), (9, 181))
RIM_SECTORS = (12, 43, 61, 93, 126, 151, 174)
# Mid-branch control vertices force varying diagonal changes of heading,
# rather than elongated meridian panels with one nearly vertical cut.
SPOKE_BENDS = ((27, 20), (30, 29), (27, 79), (28, 92),
               (27, 140), (30, 153), (26, 187))
# An additional true crack cuts the broad upper cap into two unequal parts.
UPPER_CROSS = ((7, 52), (6, 90), (8, 118))

@dataclass(frozen=True)
class Partition:
    mother: object
    cradle: object
    regions: tuple
    routes: tuple
    cut_edges: frozenset
    actual_edges: frozenset
    face_labels: tuple
    junctions: tuple


def _vertex(row, sector):
    if row < 0 or row > base.TOP_STEPS:
        raise ValueError('Upper fracture sample must stay above the cradle')
    return row*base.SECTORS + (sector % base.SECTORS)


def _point(v):
    return divmod(v, base.SECTORS)


def _distance_uv(p, q):
    dr=p[0]-q[0]
    ds=abs(p[1]-q[1]);ds=min(ds,base.SECTORS-ds)
    return math.hypot(dr*2.1,ds)


def _line_distance(p,a,b):
    # Angularly unwrap each segment along its shortest circular route.
    as_,bs_=a[1],b[1]
    delta=(bs_-as_+base.SECTORS/2)%base.SECTORS-base.SECTORS/2
    target_s=as_+delta
    u=(p[1]-as_+base.SECTORS/2)%base.SECTORS-base.SECTORS/2
    ax,ay=a[0]*2.1,0.
    bx,by=b[0]*2.1,delta
    px,py=p[0]*2.1,u
    vx,vy=bx-ax,by-ay
    t=max(0.,min(1.,((px-ax)*vx+(py-ay)*vy)/(vx*vx+vy*vy)))
    return math.hypot(px-(ax+vx*t),py-vy*t)


def _trace(start,end,adjacency,occupied,blocked, *,label):
    if start==end:raise ValueError('Zero-length physical fracture')
    startp,endp=_point(start),_point(end)
    visited={start:0.}
    parents={}
    # Use Dijkstra rather than A* to keep waypoints and curvature deterministic.
    pq=[(0.,start)]
    while pq:
        cost,here=heapq.heappop(pq)
        if cost>visited[here]+1e-8:continue
        if here==end:
            route=[here]
            while route[-1]!=start:route.append(parents[route[-1]])
            return tuple(reversed(route))
        for other in adjacency[here]:
            if other!=end:
                if other in occupied or other in blocked:continue
                row,_=_point(other)
                if row<=0 or row>=base.TOP_STEPS:continue
            p=_point(other)
            d=_distance_uv(_point(here),p)
            offset=_line_distance(p,startp,endp)
            # Preserve oblique direction while allowing actual zigzag facets.
            tentative=cost+d*(1.+min(20.,(offset/9.)**2*1.8))
            if tentative+1e-9<visited.get(other,math.inf):
                visited[other]=tentative
                parents[other]=here
                heapq.heappush(pq,(tentative,other))
    raise ValueError(f'Fracture route {label} cannot be embedded without overlap')


def build_upper_partition(stage=None):
    stage=stage or base.cut_mother()
    mother=stage.mother
    exterior=mother.exterior
    edge_faces=_edge_faces(exterior)
    upper_faces=set(i for i,label in enumerate(stage.labels)
                    if mother.poles[0] not in exterior[i] and
                    stage.pieces[label] is not stage.cradle)
    # Build the native mother mesh graph above the V11.66 border only.
    adj=defaultdict(set)
    for (u,v),faces in edge_faces.items():
        if all(face not in upper_faces for face in faces):continue
        if u>=base.RINGS*base.SECTORS or v>=base.RINGS*base.SECTORS:continue
        adj[u].add(v);adj[v].add(u)

    ring=[_vertex(*item) for item in INNER]
    rim=[_vertex(base.TOP_STEPS,s) for s in RIM_SECTORS]
    cross=[_vertex(*item) for item in UPPER_CROSS]
    bends=[_vertex(*item) for item in SPOKE_BENDS]
    all_nodes=set(ring+rim+cross+bends)
    cut=set(stage.cut_edges) # approved bowl cut is frozen, never redrawn
    used=set()
    paths=[]

    def path(name,nodes):
        poly=[]
        for start,end in zip(nodes,nodes[1:]):
            # Other authored junctions cannot be visited accidentally.
            forbidden=all_nodes-{start,end}
            segment=_trace(start,end,adj,used-{start,end},forbidden,label=name)
            poly.extend(segment if not poly else segment[1:])
        for a,b in zip(poly,poly[1:]):
            key=(min(a,b),max(a,b))
            if key in stage.cut_edges:raise ValueError('Crack entered the frozen bowl')
            cut.add(key)
        used.update(poly)
        paths.append((name,tuple(poly)))

    # One closed, uneven upper fracture contour.
    for i in range(len(ring)):
        path(f'upper_arc_{i}',[ring[i],ring[(i+1)%len(ring)]])
    # Seven nonparallel, oblique branches from cradle edge up to this contour.
    for i in range(len(ring)):
        path(f'branch_{i}',[ring[i],bends[i],rim[i]])
    # A chord across the high dome creates an extra unequal cap fragment.
    path('upper_diagonal',[ring[1],*cross,ring[4]])

    # One coherent material partition by edge-connectivity, not cell seeds.
    neighbours=defaultdict(list)
    for edge,facelist in edge_faces.items():
        if len(facelist)!=2:raise ValueError('Mother is not a closed 3D shell')
        if edge not in cut:
            x,y=facelist
            neighbours[x].append(y);neighbours[y].append(x)
    labels=[-1]*len(exterior)
    groups=[]
    for i in range(len(exterior)):
        if labels[i]>=0:continue
        lab=len(groups)
        q=[i];labels[i]=lab
        for face in q:
            for friend in neighbours[face]:
                if labels[friend]==-1:
                    labels[friend]=lab;q.append(friend)
        groups.append(q)
    bottom_face=next(i for i,face in enumerate(exterior)
                     if mother.poles[0] in face)
    bottom_label=labels[bottom_face]
    regions=tuple(_region('lower_cradle_from_V11_66' if k==bottom_label
                          else f'upper_fragment_{k:02d}',
                          [exterior[i] for i in faces],mother)
                  for k,faces in enumerate(groups))
    actual=frozenset(edge for edge,(a,b) in edge_faces.items()
                     if labels[a]!=labels[b])
    if cut!=set(actual):
        missing=cut-set(actual)
        raise ValueError(f'{len(missing)} drawn crack edges do not separate material')
    if regions[bottom_label].vertices!=stage.cradle.vertices or \
       regions[bottom_label].faces!=stage.cradle.faces:
        raise ValueError('V11.66 validated cradle geometry has changed')
    counts=defaultdict(set)
    for label,poly in paths:
        for v in poly:counts[v].add(label)
    junctions=tuple(sorted(v for v,own in counts.items() if len(own)>=3))
    return Partition(mother,regions[bottom_label],regions,tuple(paths),
                     frozenset(cut),actual,tuple(labels),junctions)


def export_obj(filename,scene,*,exploded=False):
    with Path(filename).open('w',encoding='utf-8') as out:
        offset=0
        for i,fragment in enumerate(scene.regions):
            out.write(f'o {fragment.name}\ng {fragment.name}\n')
            if not exploded or fragment is scene.cradle:
                delta=(0.,0.,0.)
            else:
                # Only a static inspection offset; NEVER a physical animation.
                t=(i-1)*.8
                delta=(t*9., -(i%3)*8., 25.+7.*(i%3))
            for v in fragment.vertices:
                out.write('v '+' '.join(f'{v[k]+delta[k]:.8f}' for k in range(3))+'\n')
            for a,b,c in fragment.faces:
                out.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(fragment.vertices)


if __name__=='__main__':
    import sys
    stage=build_upper_partition()
    print(len(stage.regions),'regions,',len(stage.junctions),'branch junctions',
          len(stage.cut_edges),'actual physical crack edges')
    if '--obj' in sys.argv:
        i=sys.argv.index('--obj')
        export_obj(sys.argv[i+1],stage,exploded='--exploded' in sys.argv)
