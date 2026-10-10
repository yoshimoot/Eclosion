"""V11.62 — Connected 3D fracture cells on the *existing* complete eggshell.

The fracture network is the set of shared triangle edges of one source mother
shell. It has real Y junctions and diagonal/lateral crack directions, rather
than seven uninterrupted longitude seams. Each region is a closed two-face
shell with a physical 2.5-unit rim. No image masks or replacement frames.
"""
from collections import defaultdict
from dataclasses import dataclass
import heapq
import math
from pathlib import Path

from scene_00 import THICKNESS, rim_y, surface, validate_shell
from whole_egg_partition import crown_y, _closed_patch
from subdivide_organic import build_organic_partition

# Coordinates: unwrapped fraction of circumference, normalized distance from
# the lower rim to crown. Deliberately NOT an equal-width row/column grid.
# Larger gaps produce broad curved shell chunks; staggered smaller gaps produce
# shorter oblique fissures. Immutable within the whole hatching sequence.
SEEDS = (
    (.052, .365), (.142, .499), (.354, .692), (.479, .381),
    (.584, .827), (.736, .834), (.837, .813), (.940, .115),
    (.035, .868), (.207, .219), (.320, .599), (.440, .922),
    (.699, .774), (.752, .352), (.877, .310), (.052, .188),
    (.161, .759), (.415, .541), (.497, .328), (.686, .909),
    (.766, .701), (.919, .806),
)

@dataclass(frozen=True)
class FractureNetwork:
    source: object
    mother_vertices: tuple
    mother_faces: tuple
    regions: tuple
    assignments: tuple
    seams: tuple
    junctions: tuple
    seed_names: tuple


def _seed_xyz(u, v):
    theta = 2 * math.pi * u
    return surface(rim_y(theta)*(1-v) + crown_y(theta)*v, theta)


def _edge_map(faces):
    incident = defaultdict(list)
    for index, tri in enumerate(faces):
        for a,b in ((tri[0],tri[1]),(tri[1],tri[2]),(tri[2],tri[0])):
            incident[(min(a,b),max(a,b))].append(index)
    if any(len(owners)>2 for owners in incident.values()):
        raise ValueError('Non-manifold source mother shell')
    return incident


def _labels(stage):
    faces = stage.mother_faces[:len(stage.mother_faces)//2]
    positions = stage.mother_vertices
    sources=[]
    # Faces are rebuilt from the exact outer triangles of each staged region.
    for region in stage.regions:
        sources.extend([region.name]*len(region.exterior_faces))
    if len(sources)!=len(faces):
        raise ValueError('Source face attribution is not exhaustive')
    region_indices=[i for i,n in enumerate(sources) if n not in ('lower_cradle','upper_cap')]
    if not region_indices:raise ValueError('No side shell to fracture')
    points=[tuple(sum(positions[j][k] for j in faces[i])/3 for k in range(3))
            for i in region_indices]
    neighbours=[[] for _ in region_indices]
    local={original:i for i,original in enumerate(region_indices)}
    for owners in _edge_map(faces).values():
        if len(owners)!=2 or owners[0] not in local or owners[1] not in local:
            continue
        a,b=local[owners[0]],local[owners[1]]
        d=math.dist(points[a],points[b])
        # One material-energy cost for both directions; orientation bias
        # varies smoothly over the shell, never by time or frame index.
        mid=tuple((points[a][k]+points[b][k])*.5 for k in range(3))
        stress=(1+.20*math.sin(mid[0]*.031+mid[2]*.017)
                  +.14*math.cos(mid[1]*.024-mid[2]*.021))
        cost=d*stress
        neighbours[a].append((b,cost))
        neighbours[b].append((a,cost))
    heap=[]
    distances=[math.inf]*len(region_indices)
    owner=[-1]*len(region_indices)
    selected=[]
    for label,(u,v) in enumerate(SEEDS):
        goal=_seed_xyz(u,v)
        start=min(range(len(points)),key=lambda i: math.dist(points[i],goal))
        if start in selected:
            raise ValueError('Two fracture seeds claim one triangle')
        selected.append(start)
        distances[start]=0
        owner[start]=label
        heapq.heappush(heap,(0.,label,start))
    while heap:
        distance,label,index=heapq.heappop(heap)
        if distance>distances[index]+1e-10 or label!=owner[index]:continue
        for next_index,cost in neighbours[index]:
            tentative=distance+cost
            if tentative+1e-10<distances[next_index]:
                distances[next_index]=tentative
                owner[next_index]=label
                heapq.heappush(heap,(tentative,label,next_index))
    if any(o==-1 for o in owner):
        raise ValueError('Disconnected source shell graph')
    assignments=list(sources)
    for i,source_index in enumerate(region_indices):
        assignments[source_index]=f'organique_{owner[i]:02d}'
    return faces,tuple(assignments)


def build_fracture_network(source=None):
    stage=source if source is not None else build_organic_partition()
    faces,labels=_labels(stage)
    outer_count=len(stage.mother_vertices)//2
    if len(stage.mother_faces)!=2*len(faces):raise ValueError('Mother has wrong faces')
    positions=stage.mother_vertices
    grouped=defaultdict(list)
    for face,label in zip(faces,labels):grouped[label].append(face)
    expected={'lower_cradle','upper_cap'}|{f'organique_{i:02d}' for i in range(len(SEEDS))}
    if set(grouped)!=expected:
        raise ValueError('Empty organic material region')
    result=[]
    for label,triangles in grouped.items():
        points=[];inward=[];remap={}
        ext=[]
        for face in triangles:
            loc=[]
            for v in face:
                if v not in remap:
                    remap[v]=len(points)
                    points.append(positions[v])
                    inward.append(positions[v+outer_count])
                loc.append(remap[v])
            ext.append(tuple(loc))
        result.append(_closed_patch(label,0,points,inward,ext,(),()))
    edgeowners=_edge_map(faces)
    seams=[];junctions=set();vowners=defaultdict(set)
    for face,label in zip(faces,labels):
        for v in face:vowners[v].add(label)
    for edge,adjacent in edgeowners.items():
        if len(adjacent)!=2:raise ValueError('Open surface edge')
        a,b=adjacent
        if labels[a]!=labels[b]:seams.append((edge,labels[a],labels[b]))
    for vertex,names in vowners.items():
        if len(names)>=3:junctions.add(vertex)
    return FractureNetwork(stage,stage.mother_vertices,stage.mother_faces,
                           tuple(result),tuple(labels),tuple(seams),
                           tuple(sorted(junctions)),tuple(sorted(grouped)))


def write_obj(path,network,exploded=False):
    with Path(path).open('w',encoding='utf8') as f:
        offset=0
        for i,region in enumerate(network.regions):
            f.write(f'o {region.name}\ng {region.name}\n')
            center=tuple(sum(p[k] for p in region.vertices[:len(region.vertices)//2]) /
                         (len(region.vertices)//2) for k in range(3))
            alpha=.14 if exploded and region.name not in ('lower_cradle','upper_cap') else 0.
            shift=(alpha*center[0],alpha*center[1],alpha*center[2])
            for xyz in region.vertices:
                f.write('v '+' '.join(f'{xyz[k]+shift[k]:.8f}' for k in range(3))+'\n')
            for a,b,c in region.faces:
                f.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(region.vertices)


if __name__=='__main__':
    import sys
    n=build_fracture_network()
    print('Material regions',len(n.regions),'seam edges',len(n.seams),
          '3-way junction vertices',len(n.junctions))
    if '--obj' in sys.argv:write_obj(sys.argv[sys.argv.index('--obj')+1],n,
                                   exploded='--exploded' in sys.argv)
