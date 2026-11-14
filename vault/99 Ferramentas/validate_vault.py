"""Check vault links, catalogue coverage, source freshness and safe updates.
Python 3.11+; no third-party packages, network or Godot.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile

VAULT=Path(__file__).resolve().parents[1]
PROJECT=VAULT.parent
sys.dont_write_bytecode=True


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def without_code(text):
    return re.sub(r'(?ms)^(`{3,}|~{3,}).*?^\1[^\n]*$','',text)


def protection_checks():
    spec=importlib.util.spec_from_file_location('vault_sync_check',VAULT/'99 Ferramentas/sync_vault.py')
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    with tempfile.TemporaryDirectory(prefix='hb_vault_check_') as folder:
        root=Path(folder).resolve()
        assert root.is_relative_to(Path(tempfile.gettempdir()).resolve())
        m.VAULT=root;m.MANIFEST=root/'manifest.json';m.NOTES={'A.md':'first\n'};m.SOURCES={};m.DEPENDENCIES={};m.DATE='2026-11-14'
        report=m.write_notes(check=True)
        assert len(report['written'])==1 and not list(root.iterdir()),'Check mode wrote files'
        m.write_notes();assert (root/'A.md').read_text()=='first\n'
        report=m.write_notes();assert not report['written'],'Identical run is not idempotent'
        (root/'A.md').write_text('human edit\n',encoding='utf-8')
        (root/'Personal.md').write_text('personal note\n',encoding='utf-8')
        m.NOTES['A.md']='new generated version\n'
        report=m.write_notes()
        assert report['protected_user_edits']==['A.md']
        assert (root/'A.md').read_text()=='human edit\n'
        assert (root/'Personal.md').read_text()=='personal note\n'
    return {'check_mode_read_only':True,'unchanged_run_idempotent':True,'edited_note_preserved':True,'personal_note_preserved':True}


def main():
    manifest=json.loads((VAULT/'99 Ferramentas/manifest.json').read_text(encoding='utf-8'))
    paths={p.relative_to(VAULT).as_posix():p for p in VAULT.rglob('*') if p.is_file()}
    stems={k.removesuffix('.md').casefold():k for k in paths}
    errors=[];warnings=[];links=0
    for relative,path in paths.items():
        if path.suffix!='.md':continue
        text=path.read_text(encoding='utf-8-sig');body=without_code(text)
        if relative in manifest['notes']:
            if not text.startswith('---\n'):errors.append(relative+': missing properties')
            else:
                for line in text.split('---',2)[1].strip().splitlines():
                    key,_,encoded=line.partition(': ')
                    try:json.loads(encoded)
                    except ValueError:errors.append(relative+': invalid property '+key)
        for spec in re.findall(r'\[\[([^\]\n]+)\]\]',body):
            target=spec.replace(r'\|','|').split('|',1)[0].split('#',1)[0]
            if not target:continue
            links+=1;key=target.removesuffix('.md').casefold()
            if key not in stems:errors.append(relative+': unresolved '+target)
        for line in body.splitlines():
            if line.startswith('|'):
                for match in re.findall(r'\[\[[^\]]+\]\]',line):
                    if re.search(r'(?<!\\)\|',match):errors.append(relative+': unescaped alias in table')
    for relative,entry in manifest['notes'].items():
        if relative not in paths:errors.append('Missing generated file: '+relative);continue
        if sha(paths[relative])!=entry['sha256']:warnings.append('User-modified note: '+relative)
    for source,expected in manifest['sources'].items():
        file=PROJECT/source
        if not file.exists() or sha(file)!=expected:errors.append('Source changed since generation: '+source)
    categories={'weapons':('Armas','Arma'),'classes':('Classes','Classe'),'enemies':('Inimigos','Inimigo'),
                'cards':('Cartas','Carta'),'perks':('Perks','Perk'),'power_ups':('Power-ups','Power-up'),
                'missions':('Missões','Missão'),'biomes':('Biomas','Bioma'),'modifiers':('Modificadores','Modificador')}
    coverage={}
    for folder,(plural,prefix) in categories.items():
        source_ids={p.stem for p in (PROJECT/'game/data'/folder).glob('*.tres')}
        actual={p.stem.removeprefix(prefix+' - ') for p in (VAULT/'02 Conteúdo'/plural).glob('*.md')}
        if actual!=source_ids:errors.append('Catalogue mismatch: '+folder)
        coverage[folder]=len(actual)
        for asset_id in source_ids:
            text=(VAULT/'02 Conteúdo'/plural/(prefix+' - '+asset_id+'.md')).read_text(encoding='utf-8')
            if '**ID:** `'+asset_id+'`' not in text:errors.append('Wrong resource ID: '+asset_id)
            if 'game/data/'+folder+'/'+asset_id+'.tres' not in text:errors.append('Missing resource provenance: '+asset_id)
    # Independent regression checks: effective values include omitted defaults.
    samples=[('02 Conteúdo/Armas/Arma - rifle.md','Dano base (HP)','12.0'),
             ('02 Conteúdo/Armas/Arma - rifle.md','Projéteis por disparo','1'),
             ('02 Conteúdo/Inimigos/Inimigo - walker.md','Vida base (HP)','30.0'),
             ('02 Conteúdo/Cartas/Carta - fast_learner.md','Ranks máximos','5')]
    for relative,label,expected in samples:
        text=(VAULT/relative).read_text(encoding='utf-8')
        if '| '+label+' | '+expected+' |' not in text:errors.append('Missing expected effective stat: '+relative+' / '+label)
    canvas=json.loads((VAULT/'Mapa do projeto.canvas').read_text(encoding='utf-8'))
    node_ids={n['id'] for n in canvas['nodes']}
    for node in canvas['nodes']:
        if node.get('type')=='file' and node['file'] not in paths:errors.append('Broken Canvas file: '+node['file'])
    for edge in canvas['edges']:
        if edge['fromNode'] not in node_ids or edge['toNode'] not in node_ids:errors.append('Broken Canvas edge')
    protection=protection_checks()
    report={'passed':not errors,'date':manifest['date'],'markdown_notes':sum(p.suffix=='.md' for p in paths.values()),
            'source_reference_notes':sum(k.startswith('90 Referências/') and k.endswith('.md') for k in paths),
            'catalogue_notes':sum(coverage.values()),'catalogue_coverage':coverage,'source_files_hashed':len(manifest['sources']),
            'wiki_links_checked':links,'canvas_nodes':len(canvas['nodes']),'canvas_edges':len(canvas['edges']),
            'update_safety':protection,'errors':errors,'warnings':warnings,'godot_executed':False,'obsidian_ui_tested':False}
    (VAULT/'99 Ferramentas/validation_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if errors:raise SystemExit(1)


if __name__=='__main__':main()
