"""V11.70 candidate: fracture-graph redesign on exactly the V11.67 egg.

This is a standalone structural experiment, not a Flutter animation.
Input OBJ contains physically split V11.67 shell surfaces and the V11.66 bowl.
Rebuilds one intact mother surface by sharing original vertices; all new
cracks are graph paths on that surface, not texture strokes or image masks.
"""
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import heapq
import math
import sys
from refine_upper_cap_obj import read_obj, Part, write_obj

SECTORS=192
TOP_STEPS=38
# Source mother shell row indices: top:0, V11.66 cut:38, bottom:72.
# Deliberately different side lengths/angles: one intact polar crown.
CROWN = ((23,18),(9,55),(26,84),(15,112),(21,144),(12,170),(21,190))
ROOT_SECTORS = (42,57,95,108,136,157,9)
BENDS = ((31,10),(31,47),(32,91),(29,122),(30,151),(30,166),(30,187))

@dataclass(frozen=True)
class Mother:
    vertices:tuple
    triangles:tuple
    upper_face_count:int
    lower_part:Part
    lat_index:dict
    bowl_wall_faces:dict

@dataclass(frozen=True)
class Network:
    mother:Mother
    parts:tuple
    paths:tuple
    cracks:frozenset
    labels:tuple
    junctions:tuple

def build_mother(original):
    points=[]; inner=[]; index={}; outer_faces=[]; groups=[]
    for part in original:
        n=len(part.vertices)//2
        for tri in part.faces:
            if max(tri)>=n:
                continue
            ids=[]
            for local in tri:
                p=part.vertices[local]
                if p not in index:
                    index[p]=len(points)
                    points.append(p)
                    inner.append(part.vertices[local+n])
                else:
                    assert inner[index[p]]==part.vertices[local+n], 'Nonmatching inner surface'
                ids.append(index[p])
            outer_faces.append(tuple(ids))
            groups.append(part.name)
    # 'canonical mother': exactly same external triangles, without inner cut walls
    edge_owners=_edge_owners(outer_faces)
    if not all(len(own)==2 for own in edge_owners.values()):
        raise ValueError('Incomplete mother mesh topology')
    # Recover whole egg latitudes from identical 192-longitudes per row.
    sectors=defaultdict(list)
    poles=[]
    for i,(x,y,z) in enumerate(points):
        if abs(abs(z)-220)<.000001:
            poles.append(i);continue
        theta=math.atan2(x,-y/.92)%(2*math.pi)
        s=round(theta*SECTORS/(2*math.pi))%SECTORS
        sectors[s].append((z,i))
    if len(poles)!=2 or set(sectors)!=set(range(SECTORS)):
        raise ValueError('Unexpected EggShellModel sampling')
    lat_index={}
    for sec,values in sectors.items():
        if len(values)!=73:
            raise ValueError('Expected 73 rings per meridian')
        for row,(z,i) in enumerate(sorted(values,reverse=True)):
            lat_index[row,sec]=i
    half=len(points)
    faces=list(outer_faces)+[tuple(j+half for j in reversed(face)) for face in outer_faces]
    bottom=next(p for p in original if p.name.startswith('lower_cradle_'))
    # Record old lower shell exactly. No new boolean/surface generation.
    # AUTHORITATIVE V11.66 bowl cut walls. Preserve their exact diagonal:
    # matching four corners alone is insufficient on a nonplanar 3D rim.
    bowl_walls=defaultdict(list)
    n_bowl=len(bottom.vertices)//2
    for tri in bottom.faces:
        if min(tri)<n_bowl<=max(tri):
            outer_ids=sorted({k % n_bowl for k in tri})
            if len(outer_ids)!=2:
                raise ValueError('Invalid original cradle rim wall triangle')
            key=tuple(sorted((bottom.vertices[k] for k in outer_ids)))
            triangle=tuple(bottom.vertices[k] for k in tri)
            bowl_walls[key].append(triangle)
    if not all(len(t)==2 for t in bowl_walls.values()):
        raise ValueError('Invalid two-sided original cradle rim')
    return Mother(tuple(points+inner),tuple(faces),len(outer_faces),bottom,lat_index,dict(bowl_walls))

def _edge_owners(faces):
    owner=defaultdict(list)
    for j,(a,b,c) in enumerate(faces):
        for x,y in ((a,b),(b,c),(c,a)):
            owner[min(x,y),max(x,y)].append(j)
    return owner

def _uv_dist(a,b):
    dr=a[0]-b[0]
    ds=abs(a[1]-b[1]);ds=min(ds,SECTORS-ds)
    return math.hypot(dr*2.4,ds)

def _off_line(p,a,b):
    arow,asec=a;brow,bsec=b;row,sec=p
    dx=brow-arow
    dy=(bsec-asec+SECTORS/2)%SECTORS-SECTORS/2
    py=(sec-asec+SECTORS/2)%SECTORS-SECTORS/2
    px=row-arow
    xx,yy=dx*2.4,dy
    denom=xx*xx+yy*yy
    t=max(0.,min(1., (px*2.4*xx+py*yy)/denom)) if denom else 0
    return math.hypot(px*2.4-t*xx,py-t*yy)

def _path(start,end,graph,uv,used,banned):
    frontier=[(0.,start)]
    dist={start:0.}
    parent={}
    pa,pb=uv[start],uv[end]
    while frontier:
        score,at=heapq.heappop(frontier)
        if score>dist[at]+1e-9:continue
        if at==end:
            route=[end]
            while route[-1]!=start:
                route.append(parent[route[-1]])
            return tuple(reversed(route))
        for nxt in sorted(graph[at]):
            if nxt!=end and (nxt in used or nxt in banned):continue
            if nxt!=end and uv[nxt][0] in (0,TOP_STEPS):continue
            offset=_off_line(uv[nxt],pa,pb)
            length=_uv_dist(uv[at],uv[nxt])
            step=length*(1+min(30, (offset/9)**2*2.6))
            candidate=score+step
            if candidate+1e-8<dist.get(nxt,math.inf):
                dist[nxt]=candidate
                parent[nxt]=at
                heapq.heappush(frontier,(candidate,nxt))
    raise ValueError('Unable to route complete crack without crossing existing junctions')

def _solid(name,ext_global,mother):
    n=len(mother.vertices)//2
    oldid={}; ext=[]
    for tri in ext_global:
        f=[]
        for vert in tri:
            if vert not in oldid:oldid[vert]=len(oldid)
            f.append(oldid[vert])
        ext.append(tuple(f))
    globals_=tuple(oldid)
    offset=len(globals_)
    vertices=tuple(mother.vertices[j] for j in globals_)+tuple(mother.vertices[j+n] for j in globals_)
    faces=list(ext)+[tuple(j+offset for j in reversed(tri)) for tri in ext]
    incidence=defaultdict(list)
    for a,b,c in ext:
        for x,y in ((a,b),(b,c),(c,a)):
            incidence[min(x,y),max(x,y)].append((x,y))
    lookup={p:k for k,p in enumerate(vertices)}
    for directed in incidence.values():
        if len(directed)!=1:continue
        u,v=directed[0]
        physical=tuple(sorted((vertices[u],vertices[v])))
        if physical in mother.bowl_wall_faces:
            # The lower shell's wall triangles are authoritative; invert
            # winding while retaining its exact two triangle diagonals.
            for triangle in mother.bowl_wall_faces[physical]:
                faces.append(tuple(lookup[q] for q in reversed(triangle)))
            continue
        # Canonical wall diagonal via mother global ID, independent of piece.
        if globals_[u]<globals_[v]:
            faces.extend(((v,u,v+offset),(u,u+offset,v+offset)))
        else:
            faces.extend(((v,u,u+offset),(v,u+offset,v+offset)))
    return Part(name,vertices,tuple(faces))

def design(original):
    mother=build_mother(original)
    surface=mother.triangles[:mother.upper_face_count]
    edge_owners=_edge_owners(surface)
    bound=set()
    for sec in range(SECTORS):
        a=mother.lat_index[TOP_STEPS,sec]
        b=mother.lat_index[TOP_STEPS,(sec+1)%SECTORS]
        bound.add((min(a,b),max(a,b)))
    assert bound<=edge_owners.keys()
    surface_graph=defaultdict(set)
    lookup={v:key for key,v in mother.lat_index.items() if key[0]<=TOP_STEPS}
    for a,b in edge_owners:
        if a in lookup and b in lookup:
            surface_graph[a].add(b);surface_graph[b].add(a)
    node=lambda uv: mother.lat_index[uv]
    crown=[node(p) for p in CROWN]
    roots=[node((TOP_STEPS,sector)) for sector in ROOT_SECTORS]
    bends=[node(p) for p in BENDS]
    authored=set(crown+roots+bends)
    used=set(); cuts=set(bound); routes=[]
    def draw(name,chain):
        line=[]
        for a,b in zip(chain,chain[1:]):
            block=authored-{a,b}
            segment=_path(a,b,surface_graph,lookup,used-{a,b},block)
            line.extend(segment if not line else segment[1:])
        for u,v in zip(line,line[1:]):
            edge=(min(u,v),max(u,v))
            assert edge not in bound
            cuts.add(edge)
        used.update(line)
        routes.append((name,tuple(line)))
    for i in range(len(crown)):
        draw('crown_'+str(i),(crown[i],crown[(i+1)%len(crown)]))
    for i in range(len(crown)):
        draw('branch_'+str(i),(crown[i],bends[i],roots[i]))
    adjacent=defaultdict(list)
    for e,owners in edge_owners.items():
        if e not in cuts:
            a,b=owners
            adjacent[a].append(b);adjacent[b].append(a)
    labels=[-1]*len(surface); groups=[]
    for seed in range(len(surface)):
        if labels[seed]>=0:continue
        k=len(groups)
        q=[seed]; labels[seed]=k
        for curr in q:
            for nxt in adjacent[curr]:
                if labels[nxt]<0:
                    labels[nxt]=k;q.append(nxt)
        groups.append(q)
    lower_src=set()
    for tri in mother.lower_part.faces:
        if max(tri)>=len(mother.lower_part.vertices)//2:continue
        lower_src.add(tuple(sorted(mother.lower_part.vertices[j] for j in tri)))
    bowl_face=next(i for i,tri in enumerate(surface) if tuple(sorted(mother.vertices[j] for j in tri)) in lower_src)
    bowl_label=labels[bowl_face]
    regions=[]
    for i,faces in enumerate(groups):
        if i==bowl_label:
            regions.append(mother.lower_part)
        else:
            regions.append(_solid(f'upper_organic_{i:02d}',[surface[k] for k in faces],mother))
    effective={e for e,owners in edge_owners.items() if labels[owners[0]]!=labels[owners[1]]}
    if cuts!=effective:
        raise ValueError('Decorative (non-separating) crack edges: '+str(len(cuts-effective)))
    degree=defaultdict(int)
    for a,b in cuts-bound:
        degree[a]+=1;degree[b]+=1
    intersections=[p for p,val in degree.items() if val>=3]
    return Network(mother,tuple(regions),tuple(routes),frozenset(cuts),tuple(labels),tuple(intersections))

def export_obj(path,network):
    write_obj(path,network.parts)

def source_from_repo():
    """Reproduce V11.67 source from unchanged repository modules."""
    import tempfile
    import upper_fragment_network
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/'reference_v1167.obj'
        upper_fragment_network.export_obj(path,upper_fragment_network.build_upper_partition())
        return read_obj(path)


if __name__=='__main__':
    if len(sys.argv)==2:
        original=source_from_repo()
        target=sys.argv[1]
    elif len(sys.argv)==3:
        original=read_obj(sys.argv[1])
        target=sys.argv[2]
    else:
        raise SystemExit('Usage: python organic_network_v1170.py [source_v1167.obj] output_v1170.obj')
    n=design(original)
    export_obj(target,n)
    print('parts',len(n.parts),'cracks',len(n.cracks),'Y junctions',len(n.junctions))
    for name,path in n.paths:print(name,len(path))
