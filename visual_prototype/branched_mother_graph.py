"""V11.65: real branched crack paths on the WHOLE egg.

Independent study of static cut topology. No ready-made lower cradle, no
textures, no chick substitute, no Flutter modifications. Closed-loop boundary
is inherited from V11.64, with additional independently authored oblique
routes. All resulting solids share the same source mother-shell triangles.
"""
from collections import defaultdict
from dataclasses import dataclass
import heapq
import math
from pathlib import Path

import whole_mother_graph as base

# The source meridian index wraps at +/-80; negative goes to rear-left from
# the frontal camera. Joints are deliberate fracture graph nodes, not cell
# centres or random seeds. Row 0 is the upper pole side of the egg.
CRACK_NODES = {
    'L0': (-48, 'rim'),
    'L1': (-19, 'rim'),
    'R0': (15, 'rim'),
    'R1': (52, 'rim'),
    'L': (-39, 29),
    'P': (-24, 16),
    'O': (-4, 26),
    'Q': (22, 17),
    'R': (37, 30),
    'UL': (-17, 3),
    'UR': (17, 3),
    'TOP': (0, 'top'),
}
# The graph is *specified first*, then the triangles are partitioned.
# Anchored forks create true junctions and arcs rather than one giant top cap.
BRANCHES = (
    ('L0', 'L'), ('L', 'P'), ('P', 'UL'),
    ('L1', 'O'), ('O', 'P'), ('O', 'Q'),
    ('R0', 'R'), ('R', 'Q'), ('R1', 'R'),
    ('Q', 'UR'),
    ('UL', 'TOP'), ('UR', 'TOP'),
)


@dataclass(frozen=True)
class FracturedMother:
    mother: base.FullMother
    parts: tuple
    bottom_part: base.Region
    cuts: frozenset
    effective_cuts: frozenset
    routes: tuple
    branching_nodes: tuple


def _norm_sector(s):
    return s % base.SECTORS


def _make_graph(mother):
    faces = mother.outer_faces
    edges = base._edge_faces(faces)
    graph = defaultdict(list)
    for (u, v), owners in edges.items():
        if len(owners) != 2:
            raise ValueError('Original mother has a non-manifold edge')
        d = math.dist(mother.vertices[u], mother.vertices[v])
        graph[u].append((v, d))
        graph[v].append((u, d))
    return graph, edges


def _coordinates(v):
    pole = base.RINGS * base.SECTORS
    if v >= pole:
        return (0, -1)
    row, sector = divmod(v, base.SECTORS)
    return (sector if sector <= base.SECTORS // 2 else sector-base.SECTORS, row)


def _rim_row(sector):
    return max(3,min(base.RINGS-4, round(base._guide_at(_norm_sector(sector)/base.SECTORS)*(base.RINGS-1))))


def _node(name):
    x, row = CRACK_NODES[name]
    if row == 'top':
        return base.RINGS*base.SECTORS
    row = _rim_row(x) if row == 'rim' else row
    return row*base.SECTORS + _norm_sector(x)


def _project_dist(p,a,b):
    # Number of shell samples; horizontal and vertical have comparable scale.
    dx=b[0]-a[0];dy=(b[1]-a[1])*1.65
    qx=p[0]-a[0];qy=(p[1]-a[1])*1.65
    den=dx*dx+dy*dy
    t=max(0.,min(1.,(qx*dx+qy*dy)/den)) if den else 0.
    return math.hypot(qx-t*dx,qy-t*dy)


def _route(start,end,graph,cut,protect):
    """Directed bounded Dijkstra on real existing shared triangular edges."""
    a=_coordinates(start); b=_coordinates(end)
    target=b
    heap=[(0.0,start)]
    best={start:0.0}
    parent={}
    while heap:
        cost,now=heapq.heappop(heap)
        if cost>best[now]+1e-9:continue
        if now==end:
            line=[end]
            while line[-1]!=start: line.append(parent[line[-1]])
            return tuple(reversed(line))
        for nxt,d in graph[now]:
            x,y=_coordinates(nxt)
            if nxt!=end:
                if not (-66<=x<=66 and 0<=y< _rim_row(x)):
                    continue
                if nxt in protect and nxt!=start:
                    continue
            else:
                if nxt in protect and nxt!=start:
                    continue
            mid=((_coordinates(now)[0]+x)/2,(_coordinates(now)[1]+y)/2)
            off=_project_dist(mid,a,target)
            nc=cost+d*(1.+.018*off*off)
            if nc<best.get(nxt,math.inf)-1e-10:
                best[nxt]=nc
                parent[nxt]=now
                heapq.heappush(heap,(nc,nxt))
    raise ValueError('Cannot trace physical branching cut path')


def build_branched_mother(mother=None):
    mother=mother or base.mother_shell()
    graph,incident=_make_graph(mother)
    # Re-use the existing physically closed seam for V11.64 comparison.
    original=base.fracture_graph()
    if not original.issubset(incident):raise ValueError('Out-of-mesh rim crack')
    paths=[]
    cuts=set(original)
    # No accidental junctions with previous routes. Explicit graph endpoints
    # may merge; every other route gets its own topological corridor.
    taken=set()
    degree=defaultdict(set)
    for a,b in BRANCHES:
        source=_node(a);target=_node(b)
        banned=taken-{source,target}
        line=_route(source,target,graph,cuts,banned)
        paths.append((a,b,line))
        for u,v in zip(line,line[1:]):cuts.add((min(u,v),max(u,v)))
        for v in line:taken.add(v);degree[v].add((a,b))
    # Refuse decorative or unusable strokes: each edge should actually cut
    # across two independent face components after flood fill.
    adjacent=defaultdict(list)
    for edge,owners in incident.items():
        if edge not in cuts:
            f1,f2=owners
            adjacent[f1].append(f2)
            adjacent[f2].append(f1)
    labels=[-1]*len(mother.outer_faces)
    components=[]
    for start in range(len(labels)):
        if labels[start]!=-1:continue
        n=len(components)
        todo=[start];labels[start]=n
        for f in todo:
            for g in adjacent[f]:
                if labels[g]==-1:
                    labels[g]=n;todo.append(g)
        components.append(todo)
    first_bottom=next(i for i,face in enumerate(mother.outer_faces) if mother.bottom_pole in face)
    bottom_id=labels[first_bottom]
    parts=tuple(base._region('lower_cradle_from_graph' if i==bottom_id else f'upper_fragment_{i:02d}',
                   [mother.outer_faces[j] for j in component],mother)
                for i,component in enumerate(components))
    real=frozenset(edge for edge,(u,v) in incident.items() if labels[u]!=labels[v])
    if not real.issubset(cuts):raise ValueError('Extra unexplained physical cut')
    branch_nodes=tuple((k,_node(k)) for k in CRACK_NODES)
    return FracturedMother(mother,parts,parts[bottom_id],frozenset(cuts),real,
                           tuple(paths),branch_nodes)


def export_obj(path,result,*,exploded=False):
    with Path(path).open('w',encoding='utf8') as f:
        offset=0
        for i,part in enumerate(result.parts):
            f.write(f'o {part.name}\ng {part.name}\n')
            # Do not mistake exploded preview translation for real motion.
            shift=((0.,0.,0.) if not exploded or part is result.bottom_part else
                   (0.,-i*1.2,38.+i*4.))
            for p in part.vertices:
                f.write('v '+' '.join(f'{p[k]+shift[k]:.8f}' for k in range(3))+'\n')
            for a,b,c in part.faces:
                f.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(part.vertices)

if __name__=='__main__':
    import sys
    r=build_branched_mother()
    print(len(r.parts),'solids',len(r.effective_cuts),'effective crack edges',len(r.routes),'branch paths')
    if '--obj' in sys.argv:
        export_obj(sys.argv[sys.argv.index('--obj')+1],r,exploded='--exploded' in sys.argv)
