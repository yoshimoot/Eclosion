"""V11.63 | Author fracture strokes first, then deduce true shell fragments.

A fixed physical graph is snapped to EDGES of the existing complete egg
mother mesh. Regions are connected exterior faces separated by those edges;
each becomes one closed, 2.5-thick solid with canonical shared cut walls.
Geometry never changes when exporting a frame; no alpha fades or 2D masks.
"""
from collections import defaultdict, deque
from dataclasses import dataclass
import heapq
import math
from pathlib import Path

# UV-like coordinates over the side shell: u=0.5 is the front,
# u=0/1 the back; v=0 the upper lip of the cradle, v=1 the F1 crown.
# Nodes are hand-directed branching cracks, NOT Voronoi/cell seeds.
# Adjoining long edges define the blue branching skeleton; the mesh only
# provides a shared, physical 3D snapping surface.
NODES = {
    # Two upper and two lower anchors are physically ON the shell rings.
    'A':(.320,1.0), 'B':(.695,1.0),
    'E':(.350,0.), 'F':(.705,0.),
    # One irregular upper arch, centre of fracture, lower diagonal arch.
    'P':(.398,.690), 'Q':(.634,.835), 'O':(.512,.502),
    'R':(.415,.215), 'S':(.617,.382),
    # Left and right branch intersections: no parallel columns.
    'C':(.336,.485), 'D':(.684,.622),
}
LINKS = (
    ('A','P'), ('B','Q'),
    ('P','Q'), ('P','O'), ('Q','O'),
    ('P','C'), ('C','R'), ('Q','D'), ('D','S'),
    ('O','R'), ('O','S'),
    ('R','E'), ('S','F'),
)
SWAY = {
    ('P','Q'):+.018, ('R','S'):-.022,
    ('P','O'):-.014, ('O','S'):+.015,
}

@dataclass(frozen=True)
class Piece:
    name: str
    vertices: tuple
    faces: tuple
    exterior_faces: tuple
    thickness: float = 2.5

@dataclass(frozen=True)
class FracturedEgg:
    mother_vertices: tuple
    mother_faces: tuple
    regions: tuple
    junctions: tuple
    paths: tuple
    cut_edges: frozenset
    face_labels: tuple
    material_seams: frozenset
    original: object


def _edge_map(faces):
    edges=defaultdict(list)
    for fi,face in enumerate(faces):
        a,b,c=face
        for u,v in ((a,b),(b,c),(c,a)):
            edges[(min(u,v),max(u,v))].append(fi)
    return edges


def _uv(point, rim_y, crown_y):
    x,depth,z=point
    a=math.atan2(x,-depth/.92)
    u=(a/(2*math.pi)+.5)%1.0
    ry=rim_y(a); cy=crown_y(a)
    return (u, (ry+z)/(ry-cy))


def _distance_to_segment(a,b,p):
    # Within the hand-authored graph's unwrapped front UV domain.
    ab=(b[0]-a[0],b[1]-a[1]);ap=(p[0]-a[0],p[1]-a[1])
    den=ab[0]**2+ab[1]**2
    t=max(0.,min(1.,(ap[0]*ab[0]+ap[1]*ab[1])/den)) if den else 0
    return math.hypot((p[0]-a[0]-ab[0]*t)*350,
                      (p[1]-a[1]-ab[1]*t)*220)


def _trace(start,end,grid,coordinates,source,target,used):
    """A* using one continuous route along EXISTING triangular edges."""
    goal=coordinates[end]
    A=source; B=target
    def h(v):
        p=coordinates[v];q=goal
        return math.hypot((p[0]-q[0])*350,(p[1]-q[1])*220)
    frontier=[(h(start),0,start)]
    best={start:0.}
    prev={}
    while frontier:
        _,cost,current=heapq.heappop(frontier)
        if cost>best[current]+1e-8:continue
        if current==end:
            route=[current]
            while current!=start:
                current=prev[current]
                route.append(current)
            return tuple(route[::-1])
        for nxt in grid[current]:
            p=coordinates[current];q=coordinates[nxt]
            if (min(p[0],q[0])<.10 or max(p[0],q[0])>.91):
                continue
            length=math.hypot((p[0]-q[0])*350,(p[1]-q[1])*220)
            center=((p[0]+q[0])/2,(p[1]+q[1])/2)
            off=_distance_to_segment(A,B,center)
            # A designed crack, not the shortest circumferential cell edge.
            tentative=cost+length*(1+min(40,(off/30)**2*3))
            if tentative<best.get(nxt,math.inf):
                best[nxt]=tentative
                prev[nxt]=current
                heapq.heappush(frontier,(tentative+h(nxt),tentative,nxt))
    raise ValueError('Fracture cannot follow the mother 3D mesh')


def _solid(name,triangles,outer,inner):
    ids={}
    ext=[]
    for tri in triangles:
        local=[]
        for vertex in tri:
            if vertex not in ids:ids[vertex]=len(ids)
            local.append(ids[vertex])
        ext.append(tuple(local))
    original_ids=list(ids)
    vertices=tuple([outer[i] for i in original_ids]+[inner[i] for i in original_ids])
    offset=len(original_ids)
    faces=list(ext)+[tuple(v+offset for v in reversed(t)) for t in ext]
    perimeter=_edge_map(ext)
    for edge,owners in perimeter.items():
        if len(owners)!=1:continue
        low,high=edge
        # Each cut must have one diagonal in BOTH adjacent pieces, even if
        # the four shell-rim vertices are not perfectly coplanar.
        # Retrieve directed orientation from its exterior triangle.
        a,b,c=ext[owners[0]]
        u,v=next((u,v) for u,v in ((a,b),(b,c),(c,a)) if (min(u,v),max(u,v))==edge)
        if original_ids[u]<original_ids[v]:
            faces.extend(((v,u,v+offset),(u,u+offset,v+offset)))
        else:
            faces.extend(((v,u,u+offset),(v,u+offset,v+offset)))
    return Piece(name,vertices,tuple(faces),tuple(ext))


def build_blue_network(stage=None):
    """Keep all faces of the original egg; replace only cut ownership."""
    if stage is None:
        from subdivide_organic import build_organic_partition
        stage=build_organic_partition()
        from scene_00 import rim_y
        from whole_egg_partition import crown_y
    else:
        # Still import the canonical model. Local tests can provide functions.
        from scene_00 import rim_y
        from whole_egg_partition import crown_y
    mother=stage.mother_vertices
    faces=stage.mother_faces[:len(stage.mother_faces)//2]
    half=len(mother)//2
    names=[r.name for r in stage.regions for _ in r.exterior_faces]
    if len(names)!=len(faces):raise ValueError('Mother face attribution mismatch')
    # Restrict routes to the current lateral surface. We DO NOT retain any
    # former vertical panel boundaries as material cuts.
    eligible={i for i,n in enumerate(names) if n not in ('lower_cradle','upper_cap')}
    if not eligible:raise ValueError('Missing side surface')
    edge_faces=_edge_map(faces)
    side_vertices=set(j for i in eligible for j in faces[i])
    # The original triangular surface remains our only geometry authority.
    coords={j:_uv(mother[j],rim_y,crown_y) for j in side_vertices}
    grid=defaultdict(set)
    for (u,v),owners in edge_faces.items():
        if u in side_vertices and v in side_vertices and any(f in eligible for f in owners):
            grid[u].add(v);grid[v].add(u)
    # Anchor endpoints at genuine material seam vertices of crown/cradle.
    cap_bound=set();bowl_bound=set()
    for (u,v),owners in edge_faces.items():
        if len(owners)!=2:continue
        n={names[owners[0]],names[owners[1]]}
        if 'upper_cap' in n:cap_bound.update((u,v))
        if 'lower_cradle' in n:bowl_bound.update((u,v))
    cap_bound.intersection_update(side_vertices)
    bowl_bound.intersection_update(side_vertices)
    anchors={}
    for key,point in NODES.items():
        candidates=(cap_bound if point[1]==1. else
                    bowl_bound if point[1]==0. else side_vertices)
        anchors[key]=min(candidates,key=lambda v:
            math.hypot((coords[v][0]-point[0])*350,
                       (coords[v][1]-point[1])*220))
    cut=set()
    paths=[]
    for ka,kb in LINKS:
        A=NODES[ka];B=NODES[kb]
        # Route by two real stages for the gently deflected main horizontal
        # cracks. The chosen joint is a real mesh vertex shared by both runs.
        bend=SWAY.get((ka,kb),0.)
        hops=[anchors[ka]]
        controls=[((A[0]+B[0])/2,(A[1]+B[1])/2+bend)] if bend else []
        for point in controls:
            via=min(side_vertices,key=lambda v:
                math.hypot((coords[v][0]-point[0])*350,
                           (coords[v][1]-point[1])*220))
            hops.append(via)
        hops.append(anchors[kb])
        trace=[]
        for idx,(start,end) in enumerate(zip(hops,hops[1:])):
            pa=A if idx==0 else controls[idx-1]
            pb=B if idx==len(hops)-2 else controls[idx]
            segment=_trace(start,end,grid,coords,pa,pb,cut)
            trace.extend(segment if not trace else segment[1:])
        for u,v in zip(trace,trace[1:]):cut.add((min(u,v),max(u,v)))
        paths.append((ka,kb,tuple(trace)))
    # Split ONLY by the physical line segments drawn above. Side faces are
    # flood-filled through all remaining uncut edges (not Voronoi-assigned).
    labels=[None]*len(faces)
    for i,name in enumerate(names):
        if name in ('upper_cap','lower_cradle'):labels[i]=name
    neighbours=defaultdict(list)
    for edge,adj in edge_faces.items():
        if len(adj)!=2:raise ValueError('Mother has open exterior edge')
        a,b=adj
        if edge in cut or labels[a] in ('upper_cap','lower_cradle') or labels[b] in ('upper_cap','lower_cradle'):
            continue
        neighbours[a].append(b);neighbours[b].append(a)
    groups=defaultdict(list)
    for i in range(len(faces)):
        if labels[i] is not None:continue
        label=f'organique_{len([v for v in groups if v.startswith("organique_")]):02d}'
        todo=[i];labels[i]=label
        for at in todo:
            groups[label].append(faces[at])
            for next_face in neighbours[at]:
                if labels[next_face] is None:
                    labels[next_face]=label;todo.append(next_face)
    for i,label in enumerate(labels):
        if label in ('upper_cap','lower_cradle'):groups[label].append(faces[i])
    pieces=tuple(_solid(name,triangles,mother[:half],mother[half:])
                 for name,triangles in groups.items())
    junction_degree=defaultdict(set)
    for a,b,path in paths:
        for v in path:junction_degree[v].add((a,b))
    junctions=tuple(sorted(v for v,owners in junction_degree.items() if len(owners)>=3))
    physical_seams=frozenset(edge for edge,owners in edge_faces.items()
                              if len(owners)==2 and labels[owners[0]]!=labels[owners[1]])
    # A traced line alone is NOT a true fracture if material on both
    # sides still belongs to the same volume. Never draw such a line.
    visible_cut=frozenset(edge for edge in cut if edge in physical_seams)
    return FracturedEgg(mother,stage.mother_faces,pieces,junctions,
                        tuple(paths),visible_cut,tuple(labels),physical_seams,stage)


def save_obj(filename,egg):
    """The intact shell, but physically separated into selectable objects."""
    with Path(filename).open('w',encoding='utf8') as f:
        shift=0
        for piece in egg.regions:
            f.write(f'o {piece.name}\ng {piece.name}\n')
            for x,y,z in piece.vertices:
                f.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
            for a,b,c in piece.faces:
                f.write(f'f {a+shift+1} {b+shift+1} {c+shift+1}\n')
            shift+=len(piece.vertices)


if __name__=='__main__':
    n=build_blue_network()
    print('V11.63',len(n.regions),'solids',len(n.paths),'strokes',
          len(n.cut_edges),'physical cut edges',len(n.junctions),'junctions')
    import sys
    if '--obj' in sys.argv:save_obj(sys.argv[sys.argv.index('--obj')+1],n)
