"""Explicit VTK triangle collision check, not merely AABB overlap.

Checks confirmed bowl collisions using the identical V11.70 OBJ and V11.71
hinges. Contacts exactly at attached, unopened material seams are expected:
this diagnostic samples *after* the small seam-opening ramp completes.
Collision free *at sampled instants* does not prove continuous clearance.
"""
from pathlib import Path
import sys
import vtk
import hinge_motion_v1171 as base
import clearance_motion_v1172 as patch

TARGETS=('upper_organic_01','upper_organic_04')
SAMPLE_TIMES={'upper_organic_01':(.10,.20,.30,.40,.50,.60,.65,.70,.75,.80,.90,1.),
              'upper_organic_04':(.57,.60,.65,.70,.75,.80,.85,.90,.95,1.)}

def poly(part):
    points=vtk.vtkPoints();points.SetDataTypeToDouble()
    for p in part.vertices:points.InsertNextPoint(*p)
    triangles=vtk.vtkCellArray()
    for a,b,c in part.faces:
        face=vtk.vtkTriangle()
        for i,id_ in enumerate((a,b,c)):face.GetPointIds().SetId(i,id_)
        triangles.InsertNextCell(face)
    mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(triangles)
    return mesh

def transform(pose):
    t=vtk.vtkTransform();matrix=vtk.vtkMatrix4x4()
    for i in range(3):
        for j in range(3):matrix.SetElement(i,j,pose.rotation[i][j])
        matrix.SetElement(i,3,pose.translation[i])
    t.SetMatrix(matrix);return t

def has_contact(a,b,pose_a,pose_b):
    f=vtk.vtkCollisionDetectionFilter()
    f.SetInputData(0,a);f.SetInputData(1,b)
    f.SetTransform(0,transform(pose_a));f.SetTransform(1,transform(pose_b))
    f.SetCollisionModeToFirstContact();f.SetNumberOfCellsPerNode(2)
    f.Update()
    return f.GetNumberOfContacts()>0

def check(parts, detailed=False):
    mesh={p.name:poly(p) for p in parts}
    hinges=base.make_hinges(parts)
    report=[]
    for target in TARGETS:
        for time in SAMPLE_TIMES[target]:
            old=base.rigid_poses(time,hinges)
            new=patch.rigid_poses(time,hinges)
            was=has_contact(mesh[base.BOWL],mesh[target],old[base.BOWL],old[target])
            now=has_contact(mesh[base.BOWL],mesh[target],new[base.BOWL],new[target])
            report.append((target,time,was,now))
            if detailed:print(target, f'{time:.2f}', 'before',int(was),'after',int(now),flush=True)
    return report

if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('Usage: python collision_check_v1172.py v1170.obj')
    parts=base.read_obj(sys.argv[1])
    rows=check(parts,True)
    print('remaining target collisions:',sum(r[-1] for r in rows))
    if any(r[-1] for r in rows):sys.exit(2)
