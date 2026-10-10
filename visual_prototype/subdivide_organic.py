"""V11.61: continuous daughter fractures in a reassembled 3D egg.

Derives one canonical closed mother from an existing V11.60 source. Only
interior samples of three chosen large side pieces are resampled ON the
original EggShellModel, then physically divided along a common, curved 3D
row. Boundaries facing unchanged neighbours reuse the exact source point
objects. Each independent daughter is a genuine two-face 2.5-thick solid.
No frame-dependent randomness, alpha mask, separate artist-sculpted patch
or change to the legacy Flutter engine.
"""
from dataclasses import dataclass
import math
from whole_egg_partition import (build_whole_egg, _closed_patch,
    _faces_for_strip, displaced_angle, crown_y, UPPER_ROWS, THICKNESS)
from scene_00 import rim_y, surface, inward_normal, validate_shell

# Parent indices in the original seven side pieces, rather than global IDs.
SPLIT_PARENTS = (0, 4, 6)
SPLIT_ROW = 10


@dataclass(frozen=True)
class OrganicPartition:
    source: object
    mother_vertices: tuple
    mother_faces: tuple
    regions: tuple
    daughters: tuple


def cut_fraction(row, column, column_count, parent_index):
    """Monotone continuous material latitude across each chosen parent.

    Fixed on the original side seam, crown and lower cradle boundaries.
    The row SPLIT_ROW thus describes an irregular *continuous* crack,
    without snapping to coarse sample rows or staircase cut walls.
    """
    if not (0 <= row <= UPPER_ROWS and
            0 <= column < column_count and column_count > 3 and
            parent_index in SPLIT_PARENTS):
        raise ValueError('Invalid organic fracture coordinate')
    t = row / UPPER_ROWS
    u = column / (column_count - 1)
    envelope = math.sin(math.pi * u)**2
    phase = .63 * (parent_index + 1)
    wave = (.080 * math.sin(2 * math.pi * u + phase)
            + .026 * math.sin(5 * math.pi * u - phase))
    return t + math.sin(math.pi * t) * envelope * wave


def split_parent(parent, index):
    """Resample ONE common parent surface, then cut it into two solids."""
    count = len(parent.bottom_keys)
    outer_count = len(parent.vertices) // 2
    if (index not in SPLIT_PARENTS or count < 8 or
            outer_count != (UPPER_ROWS + 1)*count):
        raise ValueError('Expected an original complete parent side grid')
    outside, inside = [], []
    for row in range(UPPER_ROWS+1):
        outer_row=[]
        inner_row=[]
        for col,(_,sector) in enumerate(parent.bottom_keys):
            original_id = row*count+col
            if row in (0,UPPER_ROWS) or col in (0,count-1):
                # Physical seam identity with adjacent V11.60 material.
                outer=parent.vertices[original_id]
                inner=parent.vertices[outer_count+original_id]
            else:
                theta=displaced_angle(row,sector)
                q=cut_fraction(row,col,count,index)
                y=rim_y(theta)*(1-q)+crown_y(theta)*q
                outer=surface(y,theta)
                normal=inward_normal(y,theta)
                inner=tuple(outer[k]+THICKNESS*normal[k] for k in range(3))
            outer_row.append(outer)
            inner_row.append(inner)
        outside.append(tuple(outer_row))
        inside.append(tuple(inner_row))
    daughters=[]
    for suffix,lo,hi in [('lower',0,SPLIT_ROW),('upper',SPLIT_ROW,UPPER_ROWS)]:
        exterior=[p for row in outside[lo:hi+1] for p in row]
        interior=[p for row in inside[lo:hi+1] for p in row]
        external=_faces_for_strip(hi-lo+1,count)
        bottom=parent.bottom_keys if lo==0 else ()
        top=parent.top_keys if hi==UPPER_ROWS else ()
        daughters.append(_closed_patch(f'{parent.name}_{suffix}',hi-lo+1,
                                       exterior,interior,external,bottom,top))
    return tuple(daughters)


def build_organic_partition(source=None):
    original=source if source is not None else build_whole_egg()
    pieces=[original.regions[0]]
    daughters=[]
    for i,parent in enumerate(original.regions[1:-1]):
        if i in SPLIT_PARENTS:
            parts=split_parent(parent,i)
            pieces.extend(parts)
            daughters.append((parent.name,tuple(p.name for p in parts)))
        else:
            pieces.append(parent)
    pieces.append(original.regions[-1])

    # Canonical mother: reconstruct from shared region vertices, WITHOUT
    # any interior partition walls. This is the same single eggshell, now
    # with finer sampling only where a real fracture has been introduced.
    point_index={}
    outer=[]
    inner=[]
    for piece in pieces:
        count=len(piece.vertices)//2
        for i in range(count):
            p=piece.vertices[i]
            n=piece.vertices[i+count]
            found=point_index.get(id(p))
            if found is None:
                point_index[id(p)]=len(outer)
                outer.append(p)
                inner.append(n)
            elif inner[found] is not n:
                raise ValueError('Material neighbour disagrees on inner face')
    outer_faces=[]
    for piece in pieces:
        for tri in piece.exterior_faces:
            outer_faces.append(tuple(point_index[id(piece.vertices[i])]
                                     for i in tri))
    shift=len(outer)
    faces=outer_faces+[
        tuple(shift+i for i in reversed(t)) for t in outer_faces]
    vertices=tuple(outer+inner)
    validate_shell(vertices,faces)
    return OrganicPartition(original,vertices,tuple(faces),tuple(pieces),
                            tuple(daughters))


def save_assembled_obj(path, stage):
    """Blender OBJ: 12 independently selectable intact-position shell solids."""
    from pathlib import Path
    with Path(path).open('w',encoding='utf-8') as out:
        out.write('# V11.61 12 pieces at source position, no animation.\n')
        offset=0
        for piece in stage.regions:
            out.write(f'o {piece.name}\ng {piece.name}\n')
            for x,y,z in piece.vertices:
                out.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
            for a,b,c in piece.faces:
                out.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(piece.vertices)


if __name__=='__main__':
    import sys
    stage=build_organic_partition()
    print('Closed mother',len(stage.mother_vertices),'vertices',
          len(stage.mother_faces),'faces;',len(stage.regions),'solids')
    if '--obj' in sys.argv:
        save_assembled_obj(sys.argv[sys.argv.index('--obj')+1],stage)
