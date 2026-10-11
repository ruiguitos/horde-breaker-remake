"""Copy the proven Recruit integration helpers to isolated Vanguard filenames."""
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parent;WORK=ROOT/'vanguard_v01_work';PROJECT=WORK/'godot_validation'
PROJECT.mkdir(parents=True,exist_ok=True)
for source,destination in [('Recruit_UAL_loader.gd','Vanguard_UAL_loader.gd'),('Recruit_Rifle_Hold.gd','Vanguard_Rifle_Hold.gd'),('Recruit_v03.tscn','Vanguard_v01.tscn')]:
    text=(ROOT/source).read_text(encoding='utf-8').replace('Recruit','Vanguard').replace('Vanguard_v03','Vanguard_v01')
    (ROOT/destination).write_text(text,encoding='utf-8')
shutil.copyfile(ROOT/'Recruit_Rifle_Hold_pose.json',ROOT/'Vanguard_Rifle_Hold_pose.json')
shutil.copyfile(ROOT/'recruit_v03_work/UAL_skeleton_reference.json',WORK/'UAL_skeleton_reference.json')
shutil.copyfile(ROOT/'recruit_v03_work/godot_validation/project.godot',PROJECT/'project.godot')
for name in ['validate_ual.gd','validate_demo.gd']:
    text=(ROOT/'recruit_v03_work/godot_validation'/name).read_text(encoding='utf-8').replace('Recruit','Vanguard').replace('recruit_v03_work','vanguard_v01_work').replace('Vanguard_v03','Vanguard_v01')
    (PROJECT/name).write_text(text,encoding='utf-8')
print('Vanguard support scripts prepared')
