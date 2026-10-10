"""Independent static Blender proof of the 00:00 eggshell silhouette.

Run in Blender: blender -b --python visual_prototype/scene_00.py
Optional pure-Python OBJ: python visual_prototype/scene_00.py --obj shell_00.obj

The chick is intentionally NOT recreated: its approved appearance currently
exists only in the reference artwork, not as a separate 3D asset. This is a
geometry/art-direction gate, not a finished scene or a replacement for Flutter.
"""
import math
import sys
from pathlib import Path

HALF_HEIGHT = 220.0
MAX_RADIUS = 150.0
DEPTH_RATIO = 0.92
THICKNESS = 2.5
SECTORS = 192
LAYERS = 40
PROFILE = (
    (-1.0, 0), (-.98, .1811), (-.95, .2652), (-.90, .3703),
    (-.80, .5052), (-.70, .6065), (-.60, .6912), (-.50, .7603),
    (-.40, .8198), (-.30, .8689), (-.20, .9111), (-.10, .9439),
    (0, .9721), (.10, .9895), (.20, .9980), (.30, .9989),
    (.40, .9917), (.50, .9683), (.60, .9305), (.70, .8680),
    (.80, .7721), (.85, .7040), (.90, .6131), (.95, .4590),
    (.98, .3238), (1, 0),
)


def radius_at(y):
    v = max(-1, min(1, y / HALF_HEIGHT))
    if abs(v) >= 1:
        return 0.0
    i = next(j for j in range(len(PROFILE) - 1) if v <= PROFILE[j + 1][0])
    a, b = PROFILE[i], PROFILE[i + 1]
    h = b[0] - a[0]
    t = (v - a[0]) / h

    def slope(j):
        lo, hi = max(0, j - 1), min(len(PROFILE) - 1, j + 1)
        return (PROFILE[hi][1] - PROFILE[lo][1]) / (PROFILE[hi][0] - PROFILE[lo][0])

    p = ((2 * t**3 - 3 * t**2 + 1) * a[1]
         + (t**3 - 2 * t**2 + t) * h * slope(i)
         + (-2 * t**3 + 3 * t**2) * b[1]
         + (t**3 - t**2) * h * slope(i + 1))
    return MAX_RADIUS * max(0, min(1.01, p))


# Shared cut positions use one fixed, asymmetric series of angular
# fracture stations. The different lengths keep the edge irregular without
# independent frame-by-frame noise or sinusoidal decorative teeth.
RIM_KNOTS = (
    (-math.pi, -6), (-2.93, 1), (-2.70, -4), (-2.48, 7),
    (-2.33, -7), (-2.08, 4), (-1.92, -6), (-1.68, 8),
    (-1.47, 0), (-1.31, 8), (-1.06, -4), (-.83, 7),
    (-.66, -9), (-.40, -3), (-.19, 9), (.03, -4),
    (.27, 9), (.49, -10), (.73, 8), (.86, -4),
    (1.11, 4), (1.30, -7), (1.56, 1), (1.78, 10),
    (2.02, -7), (2.18, 4), (2.43, -6), (2.61, 7),
    (2.85, -1), (math.pi, -6),
)


def rim_y(theta):
    """Asymmetric cradle: lower front opening and raised side lips.

    Returns a *physical* 360-degree shell rim, not a 2D clipping mask.
    The tall broken rear shell visible behind the reference chick will be
    modeled as a separate material fragment, never faked as a high arch.
    """
    angle = (theta + math.pi) % (2 * math.pi) - math.pi
    c = math.cos(angle)
    front = 32 + 58 * c**1.35 if c >= 0 else 32
    foundation = front + 32 * max(0.0, -c)**2.2
    for (a, delta_a), (b, delta_b) in zip(RIM_KNOTS, RIM_KNOTS[1:]):
        if a <= angle <= b:
            fract = (angle - a) / (b - a)
            noise = delta_a + (delta_b - delta_a) * fract
            break
    else:
        noise = RIM_KNOTS[-1][1]
    return max(-130, min(125, foundation + noise))


def surface(y, theta):
    r = radius_at(y)
    # Blender: X horizontal, Y depth (front negative), Z vertical.
    return (r * math.sin(theta), -r * DEPTH_RATIO * math.cos(theta), -y)


def inward_normal(y, theta):
    eps = .25
    deriv = (radius_at(min(HALF_HEIGHT, y + eps))
             - radius_at(max(-HALF_HEIGHT, y - eps))) / (2 * eps)
    r = radius_at(y)
    # Inherited Flutter outward normal (x, -r*dr/dy, z/depthRatio^2).
    fx = r * math.sin(theta)
    fy = -r * deriv
    fz = r * math.cos(theta) / DEPTH_RATIO
    length = math.sqrt(fx * fx + fy * fy + fz * fz)
    if length < 1e-8:
        return (0, 0, 1)
    # Map -outward to Blender coordinates.
    return (-fx / length, fz / length, fy / length)


def build_shell():
    """Returns one connected closed shell mesh (two sides + broken rim)."""
    outer = []
    for j in range(LAYERS):
        u = j / LAYERS
        for i in range(SECTORS):
            angle = 2 * math.pi * i / SECTORS
            y0 = rim_y(angle)
            y = y0 + (HALF_HEIGHT - y0) * u
            outer.append((y, angle, surface(y, angle)))
    outer_pole = len(outer)
    outer.append((HALF_HEIGHT, 0, (0, 0, -HALF_HEIGHT)))
    shift = len(outer)
    positions = [p for _, _, p in outer]
    for y, angle, p in outer:
        inward = inward_normal(y, angle)
        positions.append(tuple(p[k] + THICKNESS * inward[k] for k in range(3)))
    faces = []
    for j in range(LAYERS - 1):
        for i in range(SECTORS):
            nxt = (i + 1) % SECTORS
            a, b = j * SECTORS + i, j * SECTORS + nxt
            c, d = (j + 1) * SECTORS + i, (j + 1) * SECTORS + nxt
            faces.extend(((a, b, c), (b, d, c)))
    for i in range(SECTORS):
        j = (i + 1) % SECTORS
        faces.append(((LAYERS - 1) * SECTORS + i,
                      (LAYERS - 1) * SECTORS + j, outer_pole))
    outside_faces = tuple(faces)
    faces.extend(tuple(v + shift for v in reversed(f)) for f in outside_faces)
    # Break rim: same vertices on the exterior/interior (no decorative border).
    for i in range(SECTORS):
        j = (i + 1) % SECTORS
        faces.extend(((i, i + shift, j), (j, i + shift, j + shift)))
    # Blender-facing normals point outward on all material surfaces.
    return positions, [(a, c, b) for a, b, c in faces]


def validate_shell(vertices, faces):
    edge_usage = {}
    for a, b, c in faces:
        if len({a, b, c}) != 3:
            raise ValueError('Degenerate face indices')
        for u, v in ((a, b), (b, c), (c, a)):
            key = (min(u, v), max(u, v))
            edge_usage[key] = edge_usage.get(key, 0) + 1
    if any(count != 2 for count in edge_usage.values()):
        raise ValueError('Non-manifold shell: missing/duplicated material edge')
    if not all(math.isfinite(value) for pt in vertices for value in pt):
        raise ValueError('Non-finite shell coordinate')
    return True


def write_obj(filename, vertices, faces):
    with Path(filename).open('w', encoding='utf-8') as f:
        f.write('# Eclosion 00:00 shell proof; not the approved chick\n')
        for x, y, z in vertices:
            f.write(f'v {x:.8f} {y:.8f} {z:.8f}\n')
        for a, b, c in faces:
            f.write(f'f {a + 1} {b + 1} {c + 1}\n')


def build_blender_scene(vertices, faces):
    import bpy
    from mathutils import Vector

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    mesh = bpy.data.meshes.new('Reference-derived egg shell; 2.5 thick')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    ob = bpy.data.objects.new('00:00 | Broken lower cradle | geometry study', mesh)
    bpy.context.collection.objects.link(ob)
    for poly in mesh.polygons:
        poly.use_smooth = True

    shell = bpy.data.materials.new('Terracotta shell | procedural draft')
    shell.diffuse_color = (.60, .30, .17, 1)
    shell.use_nodes = True
    nodes = shell.node_tree.nodes
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (.60, .30, .17, 1)
    bsdf.inputs['Roughness'].default_value = .86
    tex = nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 3.2
    tex.inputs['Detail'].default_value = 3.0
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .13
    bump.inputs['Distance'].default_value = .7
    shell.node_tree.links.new(tex.outputs['Fac'], bump.inputs['Height'])
    shell.node_tree.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    ob.data.materials.append(shell)

    # Neutral studio stage: no replacement of the approved chick or barn.
    floor_mat = bpy.data.materials.new('Matte neutral ground')
    floor_mat.diffuse_color = (.16, .12, .095, 1)
    bpy.ops.mesh.primitive_plane_add(size=1600, location=(0, 0, -222))
    ground = bpy.context.object
    ground.name = 'Ground reference | NOT straw artwork'
    ground.data.materials.append(floor_mat)

    def area(name, location, power, size):
        data = bpy.data.lights.new(name=name, type='AREA')
        data.energy = power
        data.shape = 'DISK'
        data.size = size
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector((0, 0, 0)) - obj.location).to_track_quat('-Z', 'Y').to_euler()

    area('Warm key', (-300, -380, 460), 900, 420)
    area('Soft fill', (280, -200, 220), 450, 370)
    area('Rim light', (50, 250, 360), 900, 300)
    cam_data = bpy.data.cameras.new('Fixed frontal reference')
    cam = bpy.data.objects.new('Fixed frontal reference', cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0, -940, 240)
    target = Vector((0, 0, -12))
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 620
    bpy.context.scene.camera = cam
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = '//eclosion_00_shell_study.png'
    scene.world.color = (.22, .17, .13)
    bpy.ops.wm.save_as_mainfile(filepath=str(Path.cwd() / 'eclosion_00_shell_study.blend'))
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    verts, triangles = build_shell()
    validate_shell(verts, triangles)
    if '--obj' in sys.argv:
        at = sys.argv.index('--obj')
        if at + 1 >= len(sys.argv):
            raise SystemExit('--obj requires filename')
        write_obj(sys.argv[at + 1], verts, triangles)
    else:
        try:
            import bpy  # noqa: F401
        except ImportError:
            print('Blender required for rendering; use --obj filename.obj for pure Python mesh export.')
        else:
            build_blender_scene(verts, triangles)
