"""Local integration evidence runner. Python standard library only."""
import json
import os
from pathlib import Path
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent/'suite'
GODOT=Path('C:/Users/Rui/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
OUT.mkdir(exist_ok=True)
ENV=os.environ.copy()
ENV['APPDATA']=str(ROOT/'.godot'/'weapon-integration-user')
Path(ENV['APPDATA']).mkdir(parents=True,exist_ok=True)
tests=sorted((ROOT/'tests').glob('test_*.gd'))
tests+=sorted((ROOT/'spikes').glob('*/tests/test_*.gd'))
summary_path=OUT/'summary.json'
results=json.loads(summary_path.read_text(encoding='utf-8'))['results'] if summary_path.exists() else []
completed={r['test'] for r in results}
pending=[t for t in tests if t.relative_to(ROOT).as_posix() not in completed]

def run_test(test):
    relative=test.relative_to(ROOT).as_posix()
    key=relative.replace('/','_').replace('.gd','')
    start=time.monotonic()
    test_env=ENV.copy()
    test_env['APPDATA']=str(ROOT/'.godot'/'weapon-integration-user'/key)
    Path(test_env['APPDATA']).mkdir(parents=True,exist_ok=True)
    try:
        process=subprocess.run([str(GODOT),'--headless','--log-file',str(OUT/(key+'.engine.log')),
            '--path',str(ROOT),'--script','res://'+relative],cwd=ROOT,env=test_env,stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,timeout=180)
        output=process.stdout.decode('utf-8',errors='replace')
        failures=[line for line in output.splitlines() if any(token in line for token in ['TEST FAIL','SCRIPT ERROR','Parse Error'])]
        passed=not failures and 'TEST:' in output and process.returncode in [0,5,139,-1073741819,3221225477]
        entry=dict(test=relative,passed=passed,exit_code=process.returncode,failures=failures[:12])
    except subprocess.TimeoutExpired as error:
        output=(error.stdout or b'').decode('utf-8',errors='replace')
        failures=[line for line in output.splitlines() if any(token in line for token in ['TEST FAIL','SCRIPT ERROR','Parse Error'])]
        entry=dict(test=relative,passed=False,failures=failures[:12]+['180 second timeout'])
    (OUT/(key+'.log')).write_text(output,encoding='utf-8')
    entry['seconds']=round(time.monotonic()-start,2)
    return entry

with ThreadPoolExecutor(max_workers=3) as pool:
    for future in as_completed([pool.submit(run_test,test) for test in pending]):
        entry=future.result()
        results.append(entry)
        summary_path.write_text(json.dumps(dict(passed=sum(r['passed'] for r in results),
            completed=len(results),total=len(tests),results=results),indent=2),encoding='utf-8')
        print(('PASS' if entry['passed'] else 'FAIL'),entry['test'],entry['seconds'],flush=True)
