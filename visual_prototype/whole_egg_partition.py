"""V11.59: one complete egg shell partitioned before any piece moves.

The closed egg is built ONCE from the inherited EggShellModel. Its mother
surface is exactly the union of the seven angular pieces, the retained lower
cradle and one upper cap. All cut-edge coordinates are real shared vertices.
No 2D masks, independent patch generation, opacity tricks, or change to Flutter.
The segmentation is a structural proof, not the final organic fracture design.
"""
from dataclasses import dataclass
from collections import Counter
import math
from pathlib import Path
from scene_00 import (build_shell, surface, inward_normal, rim_y,
                      validate_shell, SECTORS, LAYERS, THICKNESS, HALF_HEIGHT)

UPPER_ROWS = 20
CAP_ROWS = 14
# Unequal sectors, so the closed egg contains more than two huge panels.
SIDE_CUTS = (0, 26, 62, 94, 119, 151, 174, SECTORS)
PIECE_NAMES = ('front_right_large', 'front_right_upper', 'rear_right',
               'rear_centre', 'rear_left_upper', 'front_left_large',
               'front_left_small')


def crown_y(angle):
    """Exact analytic F1 crown-height formula of EggShellModel."""
    u = ((angle + math.pi) / (2 * math.pi)) % 1.0
    wave = (9 * math.cos(angle) + 6 * math.sin(u * math.pi * 6 + .45)
            + 3.5 * math.sin(u * math.pi * 14 + 1.15)
            + 4 * math.sin(angle - .35))
    return max(-132., min(-94., -114 + wave))


# First bounded material-seam study. Stations lie on the *shared* 3D
# network; their offsets change direction at unequal intervals to avoid the
# straight vertical wedge boundaries of V11.59. Both ends remain unchanged.
FRACTURE_STATIONS = (
    (0.00, 0.00), (.14, -.35), (.30, .83), (.43, -.17),
    (.56, .70), (.71, -.59), (.85, .38), (1.00, 0.00),
)


def displaced_angle(j, sector):
    """One non-crossing zigzag seam; opposite pieces reuse exact points."""
    t = j / UPPER_ROWS
    a = (sector % SECTORS) * 2 * math.pi / SECTORS
    for (lo, alo), (hi, ahi) in zip(FRACTURE_STATIONS,FRACTURE_STATIONS[1:]):
        if t <= hi:
            k=(t-lo)/(hi-lo)
            bend=alo+(ahi-alo)*k
            break
    else:
        bend=0
    shift=bend*(.055+.014*math.sin(5*a+.28)+.010*math.sin(9*a+.8))
    return a+shift

def _faces_for_strip(row_count, count):
    faces=[]
    for r in range(row_count-1):
        for i in range(count-1):
            a = r*count+i
            b = a+1
            c = (r+1)*count+i
            d = c+1
            faces.extend(((a,b,c),(b,d,c)))
    return faces


def _closed_patch(name, rows, outer, inner, ext, bottom_keys, top_keys):
    """Watertight physical surface patch, side walls from its exact outline."""
    shift=len(outer)
    faces=list(ext)
    faces.extend(tuple(v+shift for v in reversed(t)) for t in ext)
    directed={}
    for a,b,c in ext:
        for u,v in ((a,b),(b,c),(c,a)):
            directed.setdefault((min(u,v),max(u,v)),[]).append((u,v))
    cut_edges=[v[0] for v in directed.values() if len(v)==1]
    for u,v in cut_edges:
        # A nonplanar 3D cut wall admits two diagonals. Adjacent pieces
        # MUST select the same diagonal or they leave tiny geometric gaps
        # despite matching endpoints and individually watertight meshes.
        # The original V11.55 lower cradle already fixes its rim diagonal.
        bottom_rim=(name != 'upper_cap' and u < len(bottom_keys)
                    and v < len(bottom_keys))
        if bottom_rim or outer[u] < outer[v]:
            faces.extend(((v,u,u+shift),(v,u+shift,v+shift)))
        else:
            faces.extend(((v,u,v+shift),(u,u+shift,v+shift)))
    vertices=tuple(outer+inner)
    validate_shell(vertices,faces)
    return ShellRegion(name,vertices,tuple(faces),tuple(ext),
                       tuple(bottom_keys),tuple(top_keys),
                       tuple((u,v) for u,v in cut_edges))


@dataclass(frozen=True)
class ShellRegion:
    name: str
    vertices: tuple
    faces: tuple
    exterior_faces: tuple
    bottom_keys: tuple
    top_keys: tuple
    material_rim: tuple
    thickness: float=THICKNESS


@dataclass(frozen=True)
class WholeEgg:
    mother_vertices: tuple
    mother_faces: tuple
    regions: tuple
    global_outer: tuple
    global_inner: tuple
    strips: tuple
    crown: tuple
    cradle: ShellRegion

    def reconstruct(self):
        return self.mother_vertices,self.mother_faces


def build_whole_egg():
    # Mother cradle vertices are authoritative for every lower break edge.
    cradle_verts,cradle_faces=build_shell()
    base_count=len(cradle_verts)//2
    base_outer=cradle_verts[:base_count]
    base_inner=cradle_verts[base_count:]
    base_ext_count=(LAYERS-1)*SECTORS*2+SECTORS
    cradle=ShellRegion('lower_cradle',tuple(cradle_verts),tuple(cradle_faces),
                       tuple(cradle_faces[:base_ext_count]),tuple(),tuple(),tuple())

    strips=[]
    strip_inner=[]
    for j in range(UPPER_ROWS+1):
        exterior=[]
        interior=[]
        for sector in range(SECTORS):
            if j==0:
                exterior.append(base_outer[sector])
                interior.append(base_inner[sector])
            else:
                theta=displaced_angle(j,sector)
                q=j/UPPER_ROWS
                y=rim_y(theta)*(1-q)+crown_y(theta)*q
                p=surface(y,theta)
                norm=inward_normal(y,theta)
                exterior.append(p)
                interior.append(tuple(p[k]+THICKNESS*norm[k] for k in range(3)))
        strips.append(tuple(exterior))
        strip_inner.append(tuple(interior))

    crown=[strips[-1]]
    crown_inner=[strip_inner[-1]]
    for j in range(1,CAP_ROWS):
        ext=[]
        inn=[]
        t=j/CAP_ROWS
        for sector in range(SECTORS):
            a=sector*2*math.pi/SECTORS
            y=crown_y(a)*(1-t)-HALF_HEIGHT*t
            p=surface(y,a)
            n=inward_normal(y,a)
            ext.append(p)
            inn.append(tuple(p[k]+THICKNESS*n[k] for k in range(3)))
        crown.append(tuple(ext))
        crown_inner.append(tuple(inn))
    top_pole=(0.,0.,HALF_HEIGHT)
    top_pole_inner=(0.,0.,HALF_HEIGHT-THICKNESS)

    # Reuse all border *objects*: no independent front/rear mesh sampling.
    pieces=[]
    for left,right,name in zip(SIDE_CUTS,SIDE_CUTS[1:],PIECE_NAMES):
        angular=tuple(i%SECTORS for i in range(left,right+1))
        out=[strips[j][i] for j in range(UPPER_ROWS+1) for i in angular]
        inn=[strip_inner[j][i] for j in range(UPPER_ROWS+1) for i in angular]
        external=_faces_for_strip(UPPER_ROWS+1,len(angular))
        pieces.append(_closed_patch(name,UPPER_ROWS+1,out,inn,external,
                                    tuple((0,i) for i in angular),
                                    tuple((UPPER_ROWS,i) for i in angular)))
    cap_out=[p for row in crown for p in row]+[top_pole]
    cap_in=[p for row in crown_inner for p in row]+[top_pole_inner]
    cap_faces=[]
    for j in range(CAP_ROWS-1):
        for i in range(SECTORS):
            nxt=(i+1)%SECTORS
            a=j*SECTORS+i
            b=j*SECTORS+nxt
            c=(j+1)*SECTORS+i
            d=(j+1)*SECTORS+nxt
            cap_faces.extend(((a,b,c),(b,d,c)))
    pole_idx=len(cap_out)-1
    start=(CAP_ROWS-1)*SECTORS
    for i in range(SECTORS):
        cap_faces.append((start+i,start+(i+1)%SECTORS,pole_idx))
    cap=_closed_patch('upper_cap',CAP_ROWS,cap_out,cap_in,cap_faces,
                      tuple((UPPER_ROWS,i) for i in range(SECTORS)),tuple())
    pieces.append(cap)

    # Canonical intact mother: exactly one copy of EVERY exterior/interior
    # triangle, without the internal cut walls required by independent pieces.
    full_out=base_outer+[p for row in strips[1:] for p in row]+[
        p for row in crown[1:] for p in row]+[top_pole]
    full_in=base_inner+[p for row in strip_inner[1:] for p in row]+[
        p for row in crown_inner[1:] for p in row]+[top_pole_inner]
    lookup={id(v):i for i,v in enumerate(full_out)}
    if len(lookup)!=len(full_out) or len({id(v) for v in full_in})!=len(full_in):
        raise ValueError('Duplicate material vertices in mother mesh')
    ext_faces=list(cradle.exterior_faces)
    for piece in pieces:
        # For cap/strips, local outside vertices are the canonical mother
        # vertices by identity, so triangles can be copied without changes.
        for a,b,c in piece.exterior_faces:
            ext_faces.append(tuple(lookup[id(piece.vertices[i])] for i in (a,b,c)))
    shift=len(full_out)
    mother_faces=ext_faces+[
        tuple(shift+i for i in reversed(face)) for face in ext_faces]
    mother_vertices=tuple(full_out+full_in)
    validate_shell(mother_vertices,mother_faces)
    return WholeEgg(mother_vertices,tuple(mother_faces),tuple([cradle]+pieces),
                    tuple(full_out),tuple(full_in),tuple(strips),tuple(crown),cradle)


def save_obj(path,egg,*,exploded=False):
    """The first OBJ is exactly the complete egg, the second separates solids.

    Exploded offsets are preview transforms only; they never shrink or mutate
    any original shell geometry. This is not a baked egg-hatching animation.
    """
    with Path(path).open('w',encoding='utf-8') as out:
        if not exploded:
            groups=(('whole_egg',egg.mother_vertices,egg.mother_faces,(0,0,0)),)
        else:
            groups=[]
            for i,r in enumerate(egg.regions):
                if i==0: offset=(0,0,0)
                elif r.name=='upper_cap': offset=(0,-22,62)
                else:
                    a=(SIDE_CUTS[i-1]+SIDE_CUTS[i])*math.pi/SECTORS
                    offset=(math.sin(a)*26,-math.cos(a)*26,17+7*(i%3))
                groups.append((r.name,r.vertices,r.faces,offset))
        count=0
        for name,vertices,faces,offset in groups:
            out.write(f'o {name}\n')
            for xyz in vertices:
                out.write('v '+' '.join(f'{xyz[k]+offset[k]:.8f}' for k in range(3))+'\n')
            for a,b,c in faces:
                out.write(f'f {a+count+1} {b+count+1} {c+count+1}\n')
            count+=len(vertices)


if __name__=='__main__':
    import sys
    egg=build_whole_egg()
    print('Mother:',len(egg.mother_vertices),'vertices',len(egg.mother_faces),'triangles')
    for region in egg.regions:
        print(region.name,len(region.vertices),len(region.faces))
    if '--obj' in sys.argv:
        at=sys.argv.index('--obj')
        save_obj(sys.argv[at+1],egg,exploded='--exploded' in sys.argv)
