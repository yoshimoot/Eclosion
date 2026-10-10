"""Export the full V11.59 egg as nine INDIVIDUALLY SELECTABLE Blender objects.

Unlike the exploded presentation, all vertices stay at their original source
coordinates: moving any selected object reveals its real shared-edge cut.
The result is a material partition of the SAME closed whole egg, not meshes
independently sculpted to resemble an egg after the fact.
"""
from pathlib import Path
from whole_egg_partition import build_whole_egg


def save_assembled_parts(path, egg=None):
    egg=egg or build_whole_egg()
    with Path(path).open('w',encoding='utf-8') as out:
        out.write('# V11.59 closed egg split into physical objects; do not rescale.\n')
        offset=0
        for region in egg.regions:
            out.write(f'o {region.name}\n')
            for x,y,z in region.vertices:
                out.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
            for a,b,c in region.faces:
                out.write(f'f {a+offset+1} {b+offset+1} {c+offset+1}\n')
            offset+=len(region.vertices)
    return len(egg.regions)


if __name__=='__main__':
    import sys
    if len(sys.argv)!=2:
        raise SystemExit('Usage: python export_assembled_parts.py egg_assembled_parts.obj')
    print('Blender objects:',save_assembled_parts(sys.argv[1]))
