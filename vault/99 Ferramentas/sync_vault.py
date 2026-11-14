"""Build a local Obsidian knowledge base from project documents and resources.
Only writes inside vault/. No network, engine execution or project edits.
Existing notes edited by the user are preserved. Python 3.11+, standard library.
"""
import argparse
from collections import Counter
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote

VAULT=Path(__file__).resolve().parents[1]
PROJECT=VAULT.parent
MANIFEST=VAULT/'99 Ferramentas/manifest.json'
DATE=''
NOTES={}
SOURCES={}
REFS={}
DEPENDENCIES={}
CATEGORIES={
    'weapons':('Armas','weapon_data.gd','Arma'),
    'classes':('Classes','class_data.gd','Classe'),
    'enemies':('Inimigos','enemy_data.gd','Inimigo'),
    'cards':('Cartas','card_data.gd','Carta'),
    'perks':('Perks','perk_data.gd','Perk'),
    'power_ups':('Power-ups','power_up_data.gd','Power-up'),
    'missions':('Missões','mission_data.gd','Missão'),
    'biomes':('Biomas','biome_data.gd','Bioma'),
    'modifiers':('Modificadores','modifier_data.gd','Modificador'),
}
LABELS={'damage':'Dano base (HP)','fire_rate':'Cadência (tiros/s)','range_m':'Alcance (m)',
        'spread_deg':'Dispersão (graus)','pellets':'Projéteis por disparo','pierce':'Alvos por projétil',
        'max_ammo':'Reserva (-1 = infinita)','magazine':'Carregador (0 = sem carregador)',
        'reload_seconds':'Recarga (s)','movement_mult':'Multiplicador de movimento','unlock_cost':'Desbloqueio (Intel)',
        'close_damage_mult':'Multiplicador de dano próximo','close_range':'Distância do bónus próximo (m)',
        'knockback':'Empurrão (m)','primary':'Arma principal','hp':'Vida base (HP)',
        'speed_min':'Velocidade mínima (m/s)','speed_max':'Velocidade máxima (m/s)',
        'attack_interval':'Intervalo de ataques (s)','height':'Altura nominal (m)',
        'radius_scale':'Escala visual','xp':'XP base','front_armor':'Redução frontal (0–1)',
        'grabs':'Agarra o jogador','pushable':'Pode ser empurrado','keep_away':'Distância de afastamento (m)',
        'explodes':'Explode','max_stacks':'Ranks máximos','category':'Categoria','class_filter':'Filtro de classe',
        'weapon_filter':'Filtro de arma','requires_finite_weapon':'Exige arma com reserva limitada',
        'prerequisites':'Pré-requisitos','branch':'Ramo','tier':'Patamar','option':'Alternativa (0=A, 1=B)',
        'benefit':'Benefício','benefit_values':'Valores do benefício (I/II/III)',
        'benefit_2':'Segundo benefício','benefit_2_values':'Valores do segundo benefício',
        'penalty':'Contrapartida','penalty_values':'Valores da contrapartida (I/II/III)',
        'ability':'Habilidade','cost':'Custo (Intel)','on_route':'Disponível nas rotas',
        'intel_mult':'Multiplicador de Intel','duration':'Duração (s)','spawn_delay':'Atraso de spawns (s)',
        'reroll_amount':'Rerolls adicionais','shield_fill':'Fração de escudo reposta','weight':'Peso no sorteio',
        'legacy_ids':'IDs antigos','points':'Quantidade de pontos','seconds_per_point':'Segundos por ponto',
        'preferred_biomes':'Biomas preferidos','preferred_weight':'Peso nos biomas preferidos',
        'preferred_islands':'Ilhas preferidas','tags':'Etiquetas do jogo','glyph':'Símbolo',
}


def digest(value):
    return hashlib.sha256(value if isinstance(value,bytes) else value.encode('utf-8')).hexdigest()


def read(source):
    path=PROJECT/source
    raw=path.read_bytes();SOURCES[source]=digest(raw)
    return raw.decode('utf-8-sig')


def link(path,label=None):
    target=str(path).removesuffix('.md')
    return '[['+target+('|' + label if label else '')+']]'


def note(path,title,body,kind='nota',sources=(),state='consulta',tags=()):
    metadata={'titulo':title,'tipo':kind,'estado':state,'atualizado':DATE,
              'tags':['horde-breaker',*tags],'fontes':list(sources)}
    header='---\n'+'\n'.join(k+': '+json.dumps(v,ensure_ascii=False) for k,v in metadata.items())+'\n---\n'
    NOTES[path]=header+'\n# '+title+'\n\n'+body.strip()+'\n'
    DEPENDENCIES[path]=list(sources)


def ref(source,label=None):
    return link(REFS[source],label or Path(source).stem)


def code(source):
    return '`'+source+'`'


def strip_code(text):
    return re.sub(r'(?ms)^(`{3,}|~{3,}).*?^\1[^\n]*$','',text)


def source_inventory():
    tracked=subprocess.run(['git','ls-files','-z'],cwd=PROJECT,check=True,capture_output=True).stdout.decode().split('\0')
    selected=[]
    for source in tracked:
        if not source.endswith('.md'):continue
        if source.startswith('docs/engine-reference/'):
            if source not in ['docs/engine-reference/godot/VERSION.md','docs/engine-reference/godot/breaking-changes.md']:continue
        elif not (source.startswith(('docs/','spikes/')) or source in ['README.md','TODO.md','CLAUDE.md','AGENTS.md','game/README.md','game/ui/art/README.md','tools/export/README.md','tools/real_island/README.md','assets/LICENSES.md']
                  or (source.startswith('assets/models/') and Path(source).name in ['README.md','NOTES.md'])):continue
        selected.append(source)
    selected += [s for s in ['project.yaml','project.godot','docs/architecture/tr-registry.yaml','docs/registry/architecture.yaml'] if (PROJECT/s).exists()]
    for source in sorted(set(selected)):
        p=Path('90 Referências')/source
        if p.name in ['AGENTS.md','CLAUDE.md']:p=p.with_name(p.stem+' - referência.md')
        if p.suffix!='.md':p=p.with_name(p.name+'.md')
        REFS[source]=p.as_posix()


def rewrite_links(text,source):
    def replace(match):
        image_prefix,label,target=match.groups();target=target.strip().strip('<>')
        if target.startswith(('#','https:','http:','mailto:','obsidian:')):return match.group(0)
        if re.match(r'^[A-Za-z]+:',target):return label+' ('+code(target)+')'
        raw,_,anchor=unquote(target).partition('#')
        resolved=(PROJECT/Path(source).parent/raw).resolve()
        if not resolved.is_relative_to(PROJECT):return label+' ('+code(target)+')'
        rel=resolved.relative_to(PROJECT).as_posix()
        if rel in REFS and not image_prefix:
            return link(REFS[rel],label) # File-level links survive heading/title changes.
        return ('Imagem: ' if image_prefix else '')+label+' ('+code(rel)+')'
    chunks=re.split(r'(?ms)(^```.*?^```[^\n]*$|^~~~.*?^~~~[^\n]*$)',text)
    for i in range(0,len(chunks),2):
        chunks[i]=re.sub(r'(!?)\[([^\]\n]+)\]\((<[^>]+>|[^)\n]+)\)',replace,chunks[i])
    return ''.join(chunks)


def references():
    for source,path in REFS.items():
        original=read(source)
        if '/legacy/' in source:state='historico'
        elif '/history/' in source:state='relatorio_historico'
        elif source=='docs/DECISIONS.md':state='decisoes_registadas'
        elif source=='TODO.md':state='copia_da_lista_ativa'
        else:state='referencia_a_confrontar'
        warning='Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original.'
        if source=='TODO.md':warning+=' O único backlog ativo é `TODO.md` na raiz; não gerir tarefas nesta cópia.'
        if source.startswith('docs/design/') or source=='docs/tech/ARCHITECTURE.md':warning+=' Pode conter propostas e regras antigas. Confrontar com as decisões datadas e com os recursos atuais.'
        if '/legacy/' in source or '/history/' in source:warning+=' Arquivo: não usar como lista de trabalho atual.'
        body='> [!warning] Cópia de consulta\n> '+warning+'\n\nFonte: '+code(source)+' · SHA-256: `'+SOURCES[source]+'`\n\n'
        if source.endswith('.md'):body+=rewrite_links(original,source)
        else:body+='```'+('ini' if source.endswith('.godot') else 'yaml')+'\n'+original.strip()+'\n```'
        note(path,source,body,'referencia',[source],state,['referencia'])


def value(expr):
    s=expr.strip()
    if s.startswith('&"'):s=s[1:]
    try:return json.loads(s)
    except (ValueError,TypeError):return s


def defaults(source):
    result={}
    for line in read(source).splitlines():
        m=re.search(r'@export[^\n]*?\bvar\s+(\w+)\s*:\s*[^=]+?=\s*(.+)',line)
        if m:result[m[1]]=m[2].split(' ##')[0].strip()
    return result


def resource(source,base):
    text=read(source);body=text.split('[resource]',1)[1];matches=list(re.finditer(r'(?m)^(\w+) = ',body))
    explicit={m[1]:body[m.end():matches[i+1].start() if i+1<len(matches) else len(body)].strip() for i,m in enumerate(matches)}
    explicit.pop('script',None)
    return {**base,**explicit},explicit


def display(raw):
    v=value(raw)
    if v is True:return 'Sim'
    if v is False:return 'Não'
    if isinstance(v,(int,float)):return str(v)
    if isinstance(v,list):return ', '.join(map(str,v)) or '—'
    return str(v).replace('\n',' ').replace('|','\\|')


def content_notes():
    catalog={}
    for category,(plural,script,prefix) in CATEGORIES.items():
        base_source='game/data/resources/'+script;base=defaults(base_source);entries=[]
        for file in sorted((PROJECT/'game/data'/category).glob('*.tres')):
            source=file.relative_to(PROJECT).as_posix();props,explicit=resource(source,base)
            title=str(value(props.get('display_name',props.get('title',json.dumps(file.stem)))))
            path='02 Conteúdo/'+plural+'/'+prefix+' - '+file.stem+'.md'
            text=next((str(value(props[k])) for k in ['description','text','role'] if k in props and value(props[k])), '')
            body='← '+link('02 Conteúdo/'+plural+'.md',plural)+'\n\n'
            if text:body+=text+'\n\n'
            body+='> [!info] Dados observados, não equilíbrio final\n> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.\n\n'
            body+='**ID:** `'+file.stem+'` · **Nome no jogo:** '+title+'\n\n| Campo | Valor | Origem |\n|---|---|---|\n'
            for field,raw in props.items():
                if field in ['display_name','title','description','text','role','order','color','icon']:continue
                if category=='missions' and field not in explicit and field not in ['on_route','preferred_weight']:continue
                if value(raw) in ['',[],{}] and field not in ['class_filter','prerequisites']:continue
                body+='| '+LABELS.get(field,field)+' | '+display(raw)+' | '+('`.tres`' if field in explicit else 'Por defeito no Resource')+' |\n'
            if category=='classes':body+='\nA vida, o Breaker e o comportamento da habilidade são aplicados na simulação, não definidos por este Resource. Ver '+link('03 Sistemas/Combate e movimento.md')+'.\n'
            if category=='cards':body+='\nVer '+link('03 Sistemas/XP e cartas.md')+' para recolha de XP, ranks máximos e rerolls.\n'
            if category=='perks':body+='\nOs arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver '+link('03 Sistemas/Intel e perks.md')+'.\n'
            if category=='power_ups':body+='\nO efeito exige recolha. Expirar ou sair da ilha sem apanhar perde o power-up. Ver '+link('03 Sistemas/Power-ups e pickups.md')+'.\n'
            body+='\n## Fontes\n\n- '+code(source)+'\n- '+code(base_source)+'\n- '+ref('docs/tech/COMBAT_CATALOG.md','Catálogo técnico — referência com histórico')+'\n'
            note(path,prefix+' — '+title,body,'conteudo',[source,base_source],'dados_observados',[category])
            entries.append({'id':file.stem,'title':title,'path':path,'props':props,'source':source})
        catalog[category]=entries
        body='← '+link('02 Conteúdo/Conteúdo.md')+'\n\n**'+str(len(entries))+' registos observados** em '+code('game/data/'+category+'/')+'. Cada ficha aplica os valores por defeito do Resource quando o `.tres` omite um campo.\n\n'
        body+='| Ficha | ID |\n|---|---|\n'+''.join('| '+link(e['path'],e['title'])+' | `'+e['id']+'` |\n' for e in entries)
        if category=='enemies':body+='\nInclui o Crawler e o Behemoth. O registo `walker` corresponde ao Walker; o Crawler tem registo próprio.\n'
        if category=='missions':body+='\n`on_route=false` distingue conteúdos de expedição das missões sorteadas nas rotas. A existência do Resource não prova que todas as combinações de mapa e missão foram jogadas.\n'
        note('02 Conteúdo/'+plural+'.md',plural,body,'mapa',[e['source'] for e in entries],tags=[category])
    return catalog


def inventories():
    files=sorted((PROJECT/'game').rglob('*.gd'));rows=[]
    for file in files:
        source=file.relative_to(PROJECT).as_posix();text=read(source)
        cls=re.search(r'(?m)^class_name\s+(\w+)',text);base=re.search(r'(?m)^extends\s+([^\n]+)',text)
        functions=re.findall(r'(?m)^(?:static )?func (\w+)\(',text)
        rows.append('| '+code(source)+' | '+(cls[1] if cls else '—')+' | '+(base[1].strip() if base else '—')+' | '+str(len(functions))+' |')
    note('05 Desenvolvimento/Mapa do código.md','Mapa do código','← '+link('05 Desenvolvimento/Desenvolvimento.md')+'\n\nInventário estático dos '+str(len(files))+' scripts próprios em `game/`; não é prova de execução.\n\n| Ficheiro | Classe | Base | Funções de topo |\n|---|---|---|---|\n'+'\n'.join(rows),sources=[p.relative_to(PROJECT).as_posix() for p in files])
    tests=sorted([*(PROJECT/'tests').glob('test_*.gd'),*(PROJECT/'spikes').glob('*/tests/test_*.gd')])
    body='← '+link('05 Desenvolvimento/Testes e validação.md')+'\n\n**'+str(len(tests))+' ficheiros descobertos**, sem os executar nesta tarefa. A descoberta do runner e o resultado de uma execução real são coisas diferentes.\n\n| Teste | Descrição inicial |\n|---|---|\n'
    for file in tests:
        source=file.relative_to(PROJECT).as_posix();lines=read(source).splitlines()
        comments=[l.lstrip('# ').strip() for l in lines[:12] if l.startswith('##')]
        body+='| '+code(source)+' | '+(' '.join(comments)[:220].replace('|','\\|') or 'Sem descrição inicial; consultar o teste.')+' |\n'
    note('05 Desenvolvimento/Inventário de testes.md','Inventário de testes',body,sources=[p.relative_to(PROJECT).as_posix() for p in tests])
    scenes=sorted((PROJECT/'game/world/handmade/islands').glob('*.tscn'))
    exfil=PROJECT/'game/world/handmade/test/exfil_test.tscn'
    if exfil.exists():scenes.append(exfil)
    for file in scenes:
        source=file.relative_to(PROJECT).as_posix();text=read(source)
        nodes=re.findall(r'(?m)^\[node name="([^"]+)"',text)
        markers=Counter(re.sub(r'[_\d]+$','',name) for name in nodes if re.match(r'(Generator|Spawn|Extraction|Player|Rescue|Escort|Signal|Search|Nest|Machine|Arena|Delivery|Hold)',name))
        body='← '+link('02 Conteúdo/Mapas e expedições.md')+'\n\nCena observada no disco: '+code(source)+'.\n\n**'+str(len(nodes))+' nós declarados** no texto da cena. Não substitui a importação nem conta nós de subcenas instanciadas.\n\n| Família de marcador | Quantidade no texto |\n|---|---|\n'+''.join('| '+k+' | '+str(v)+' |\n' for k,v in sorted(markers.items()))
        body+='\nRelacionados: '+link('03 Sistemas/Missões e objetivos.md')+' · '+link('04 Arte e interface/Ilhas e cenário.md')+'\n'
        note('02 Conteúdo/Mapas/Mapa - '+file.stem+'.md','Mapa — '+file.stem,body,'mapa_cena',[source],'cena_observada')
    return len(tests),scenes


def curated(catalog,test_count,scenes):
    def put(path,title,body,sources=(),kind='nota'):
        note(path,title,body,kind,sources,tags=['navegacao'] if kind=='mapa' else [])
    counts={k:len(v) for k,v in catalog.items()}
    put('00 Início.md','Horde Breaker — início',f'''
> [!tip] Começa aqui
> Escolhe um dos cinco mapas abaixo. As notas de trabalho podem ser editadas livremente; as referências têm a fonte e a data da recolha.

1. {link('01 Projeto/Projeto.md','Projeto')} — visão, decisões e situação atual.
2. {link('02 Conteúdo/Conteúdo.md','Conteúdo')} — classes, arsenal, cartas, perks, inimigos, biomas e missões.
3. {link('03 Sistemas/Sistemas.md','Sistemas')} — combate, progressão, horda e fluxo da run.
4. {link('04 Arte e interface/Arte e interface.md','Arte e interface')} — modelos, animação, cenário, menus e áudio.
5. {link('05 Desenvolvimento/Desenvolvimento.md','Desenvolvimento')} — arquitetura, testes, ferramentas e distribuição.

## Fotografia dos recursos — {DATE}

| Classes | Armas | Inimigos | Cartas | Perks | Missões | Biomas | Power-ups |
|---:|---:|---:|---:|---:|---:|---:|---:|
| {counts['classes']} | {counts['weapons']} | {counts['enemies']} | {counts['cards']} | {counts['perks']} | {counts['missions']} | {counts['biomes']} | {counts['power_ups']} |

Estas são contagens de Resources presentes, não uma certificação de equilíbrio ou de playtest.

## Continuar o trabalho

{link('80 Trabalho/Painel de trabalho.md')} · {link('01 Projeto/Situação atual.md')} · {link('05 Desenvolvimento/Como usar e atualizar o cofre.md')}

O ficheiro **Mapa do projeto.canvas** oferece uma vista visual dos cinco mapas. {link('90 Referências/Índice de fontes.md','Abrir a biblioteca de fontes')}.
''',['TODO.md','docs/DECISIONS.md'],'mapa')
    put('01 Projeto/Projeto.md','Projeto',f'''
← {link('00 Início.md')}

{link('01 Projeto/Visão e pilares.md')} · {link('01 Projeto/Situação atual.md')} · {link('01 Projeto/Decisões e âmbito.md')} · {link('01 Projeto/História e tom.md')} · {link('01 Projeto/Fontes e divergências.md')}

O remake é um projeto a solo em Godot 4.7, GDScript tipado e Forward+. As decisões datadas, os dados executáveis e as propostas têm papéis diferentes: consulta {link('01 Projeto/Fontes e divergências.md')} antes de transformar uma ideia antiga em tarefa.
''',['CLAUDE.md','project.godot'],'mapa')
    put('01 Projeto/Visão e pilares.md','Visão e pilares',f'''
Horde shooter de expedição para PC: atravessar ilhas, cumprir objetivos e romper a horda até à extração. O alvo de duração documentado é 20–30 minutos; não foi medido nesta organização do cofre.

| Pilar | Pergunta útil ao avaliar uma ideia |
|---|---|
| Romper a horda | Cria decisões de posição, orientação e uso do Breaker? |
| Cada ilha é uma decisão | Torna objetivos, mantimentos e risco legíveis? |
| Builds que mudam a forma de jogar | Muda o comportamento ou acrescenta apenas números? |

O GDD conserva o âmbito original e propostas. As decisões posteriores incluem três câmaras, sprint com disparo e rotas sorteadas entre ilhas. Ver {link('01 Projeto/Decisões e âmbito.md')} e {link('03 Sistemas/Fluxo da run.md')}.

Fontes: {ref('docs/design/GDD.md')} · {ref('docs/DECISIONS.md')}.
''',['docs/design/GDD.md','docs/DECISIONS.md'])
    put('01 Projeto/Situação atual.md','Situação atual',f'''
## Confirmado nesta leitura

- Os Resources contêm {counts['classes']} classes, {counts['weapons']} armas, {counts['enemies']} inimigos e {counts['missions']} tipos de missão.
- Há {counts['biomes']} biomas. O conteúdo é consultável em {link('02 Conteúdo/Conteúdo.md')}.
- Foram encontrados {test_count} ficheiros de teste; **não foram executados nesta tarefa**.
- Os ficheiros das cenas observadas estão em {link('02 Conteúdo/Mapas e expedições.md')}.

## Trabalho ativo

A lista única é {ref('TODO.md','TODO — cópia de consulta')}. Inclui playtest, validação visual, modelos, animação, equilíbrio, menus, cenário e exportação. Marcar trabalho como concluído no ficheiro original, não nesta visão.

## Decisões recentes registadas

As decisões de novembro aprovam Exfil, adiam co-op e escolhem a direção visual de menus «field dossier». A implementação dessa direção está parcial segundo o TODO: título e armory já descritos como feitos; restantes ecrãs ainda pendentes. Ver {link('04 Arte e interface/Menus e HUD.md')}.

## Limite desta fotografia

Foi feita leitura de ficheiros, não auditoria em execução. Um recurso presente, uma cena no disco e uma funcionalidade validada a jogar não são equivalentes.
''',['TODO.md','docs/DECISIONS.md','tests/run_all.gd'])
    put('01 Projeto/Decisões e âmbito.md','Decisões e âmbito',f'''
O registo oficial é {ref('docs/DECISIONS.md')}. Esta nota é um guia de leitura, sem criar decisões novas.

| Assunto | Decisão datada a consultar |
|---|---|
| Câmaras | 1.ª pessoa, 3.ª pessoa e fixa — 2026-10-11 |
| Armas | Opção B; principal + secundária; Machine Gun; Heavy Pistol removida — 2026-10-11 |
| Berlenga | Quatro partes, a pé — 2026-10-11 |
| Sprint | Dispara por regra base; restrições ao carregar bidões — 2026-10-14 |
| Reroll | Um grátis por ecrã, sem acumulação — 2026-10-14 |
| Transição | Contagem de 5 s, rota sorteada entre ilhas — 2026-10-14 |
| Exfil | Mantido, extração aos 10 min, mapa próprio — 2026-11-10 |
| Co-op | Pendente para mais tarde; forma ainda por decidir — 2026-11-10 |
| Menus | Direção A «field dossier», depois fotografia 3D no dossier — 2026-11-10 e 11 |
| Licenças | Consultar exceções específicas, não generalizar permissões — {link('04 Arte e interface/Assets e licenças.md')} |

Origin jogável e o mapa de rotas em grafo estão fora do plano atual segundo o TODO. Não converter ideias de expansão em implementação sem decisão.

Só Claude Code, como agente principal e nas condições do AGENTS, edita `docs/DECISIONS.md`. Codex pode registar propostas nas suas próprias notas, como {link('80 Trabalho/Ideias e propostas.md')}.
''',['docs/DECISIONS.md','TODO.md','AGENTS.md'])
    put('01 Projeto/História e tom.md','História e tom',f'''
A documentação enquadra o jogador como contratado da Salvage & Co., enviado ao arquipélago Halvard depois do Project TIDE. O Director Hale acompanha por rádio. O tom pretendido combina perigo com humor seco de burocracia empresarial.

O GDD e os textos narrativos podem conter planos além do jogo atual. Para acompanhar o que o jogador ouve, consultar os ficheiros `game/data/dialogue/briefing.dialogue`, `radio.dialogue` e `origin.dialogue`; a existência de um diálogo não comprova que toda a sequência esteja acessível.

Fontes: {ref('docs/design/GDD.md')} · {ref('docs/design/BRAINSTORM.md')}.
Relacionados: {link('04 Arte e interface/Áudio e diálogos.md')} · {link('02 Conteúdo/Mapas e expedições.md')}.
''',['docs/design/GDD.md','docs/design/BRAINSTORM.md'])
    put('01 Projeto/Fontes e divergências.md','Fontes e divergências',f'''
## Como resolver dúvidas

1. Para decisões aprovadas, ler {ref('docs/DECISIONS.md')} e as datas de substituição.
2. Para valores configurados, ler fichas em {link('02 Conteúdo/Conteúdo.md')}, os `.tres` e os defaults dos Resources.
3. Para comportamento, conferir a simulação e os testes; a descrição de uma carta pode estar desatualizada.
4. Para trabalho ativo, usar {ref('TODO.md')}. Os relatórios não são backlogs.
5. Para intenção e história, consultar design, propostas e arquivo com o respetivo contexto.

## Divergências observadas

| Fonte | Problema de leitura | Tratamento no cofre |
|---|---|---|
| `game/README.md` | O início diz 9 missões; há 11 Resources | Catálogo calculado dos recursos; referência preservada com aviso |
| `docs/tech/COMBAT_CATALOG.md` | Cabeçalho diz 7 inimigos e árvore de 9 nós/20 alternativas | Fichas mostram 8 inimigos e 26 Resources de perks; não confundir alternativas com nós |
| `perk_data.gd` | Comentário inicial fala em três ramos | `game_data.gd` declara quatro: combat, survival, breaker, logistics |
| `docs/tech/ARCHITECTURE.md` | Apresenta-se como proposta de pré-produção | Mapa do código descreve ficheiros observados; não promove a proposta a arquitetura implementada |
| Documentos de menus | Preservam Atlântico/azulejo e abrigo 3D | Decisões de novembro prevalecem nos menus fora da ilha |
| Relatórios antigos de testes | Podem mencionar crashes tolerados | Regra atual exige exit 0 e resultado, salvo whitelist explícita do runner |

Não foi determinada a atualidade de cada documento pelo histórico Git. As cópias são snapshots, não certificações de que o texto coincide com toda a implementação.

Fontes: {ref('docs/DECISIONS.md')} · {ref('game/README.md')} · {ref('docs/tech/COMBAT_CATALOG.md')} · {ref('docs/tech/ARCHITECTURE.md')}.
''',['docs/DECISIONS.md','game/README.md','docs/tech/COMBAT_CATALOG.md','game/data/resources/perk_data.gd','game/data/game_data.gd','tests/run_all.gd'])
    groups='\n'.join('- '+link('02 Conteúdo/'+v[0]+'.md')+' — '+str(counts[k])+' fichas.' for k,v in CATEGORIES.items())
    put('02 Conteúdo/Conteúdo.md','Conteúdo',f'''
← {link('00 Início.md')}

{groups}

{link('02 Conteúdo/Mapas e expedições.md')} · {link('03 Sistemas/Sistemas.md')}

Os IDs técnicos são preservados nos nomes dos ficheiros para distinguir conteúdos com nomes parecidos. «Field Medic» pode ser o título de uma carta; as classes presentes são as do registo de classes, não as do conceito inicial.
''',kind='mapa')
    maps='\n'.join('- '+link('02 Conteúdo/Mapas/Mapa - '+p.stem+'.md',p.stem) for p in scenes)
    expedition_scenes=list((PROJECT/'game/world/handmade/expeditions/berlenga').glob('*.tscn'))
    put('02 Conteúdo/Mapas e expedições.md','Mapas e expedições',f'''
← {link('02 Conteúdo/Conteúdo.md')}

## Cenas observadas

{maps}

Cada ficha conta os nós e marcadores declarados no texto da cena. Subcenas, terreno, navegação e viabilidade a jogar exigem validação própria.

## Berlenga

{link('02 Conteúdo/Berlenga.md')} descreve a expedição de quatro partes. Foram encontrados **{len(expedition_scenes)} ficheiros `.tscn` diretamente em `game/world/handmade/expeditions/berlenga/`** nesta leitura; isto pode refletir conteúdo gerado/local e não substitui a verificação no editor.

## Exfil

{link('03 Sistemas/Exfil.md')} tem mapa próprio de teste. O material local em `assets/models/environment/extraction_test_arena/` aparece como não versionado no início desta tarefa; não é tratado como entrega validada nem alterado por este cofre.

Fontes: {ref('docs/design/WORLD_AND_MISSIONS.md')} · {ref('docs/design/BERLENGA_EXPEDITION.md')} · {ref('docs/design/DEV_MENU.md')}.
''',['docs/design/WORLD_AND_MISSIONS.md','docs/design/BERLENGA_EXPEDITION.md','docs/design/DEV_MENU.md'])
    put('02 Conteúdo/Berlenga.md','Berlenga',f'''
Expedição própria de quatro partes, ligada a pé, com acampamentos entre partes. A vida, as armas e as cartas transitam; o resgate fecha a viagem.

| Parte | Local | Missão documentada |
|---|---|---|
| 1 | Carreiro do Mosteiro | Escort |
| 2 | Planalto do Farol | Light the Signals |
| 3 | Costa Sudoeste | Hold Sequence |
| 4 | Forte de São João Baptista | Holdout |

O documento regista substituições de objetivos e uma construção baseada no terreno real. Consultar o texto completo para datas, marcadores e limitações. O TODO ainda pede revisão a pé de ponta a ponta; esta tarefa não executou a expedição.

{ref('docs/design/BERLENGA_EXPEDITION.md','Fonte completa')} · {link('02 Conteúdo/Mapas e expedições.md')} · {link('03 Sistemas/Missões e objetivos.md')}.
''',['docs/design/BERLENGA_EXPEDITION.md','TODO.md'])
    systems=['Fluxo da run','Combate e movimento','XP e cartas','Intel e perks','Power-ups e pickups','Horda e diretor','Missões e objetivos','Exfil','Perfil e telemetria']
    put('03 Sistemas/Sistemas.md','Sistemas','← '+link('00 Início.md')+'\n\n'+'\n'.join('- '+link('03 Sistemas/'+n+'.md') for n in systems),kind='mapa')
    put('03 Sistemas/Fluxo da run.md','Fluxo da run',f'''
Título → Armory → barco → ilha → barco/acampamento → continuação → debrief → Armory.

Na run normal, a documentação descreve três ilhas e o vulcão no final. Berlenga e Exfil têm regras próprias. O primeiro barco oferece duas rotas; entre ilhas há contagem de 5 s e a rota seguinte é sorteada, segundo a decisão de 2026-10-14.

```mermaid
flowchart LR
    T[Título] --> A[Armory]
    A --> B[Barco]
    B --> I[Ilha]
    I --> C[Barco ou acampamento]
    C --> I
    I --> D[Debrief]
    D --> A
```

Morrer termina a run e conserva Intel ganho; extrair aplica o multiplicador definido nos dados. O diagrama é um resumo conceptual, não uma listagem exata de estados de código.

Fontes: {ref('docs/DECISIONS.md')} · {ref('game/README.md')}.
Código: `game/main.gd`, `game/core/run_context.gd`, `game/states/`.
''',['docs/DECISIONS.md','game/README.md','game/core/run_context.gd'])
    constants=read('game/data/game_data.gd')
    observed={m[1]:m[2].split(' ##')[0].strip() for m in re.finditer(r'(?m)^const (\w+):[^=\n]+ = ([^\n]+)',constants)}
    keys=['PLAYER_MAX_HP','PLAYER_SPEED','PLAYER_RADIUS','BREAKER_DISTANCE','BREAKER_DURATION','BREAKER_COOLDOWN','BREAKER_RADIUS','BREAKER_DAMAGE','BREAKER_STUN','SPRINT_MULTIPLIER','STAMINA_MAX','STAMINA_REGEN','STAMINA_REGEN_DELAY','MAX_MELEE_PER_FRAME','HEADSHOT_MULTIPLIER','HEADSHOT_CONE_DEG','CROSSHAIR_CONE_DEG']
    table='\n'.join('| `'+k+'` | '+observed[k]+' |' for k in keys)
    put('03 Sistemas/Combate e movimento.md','Combate e movimento',f'''
O jogador escolhe posição e orientação; o auto-fire decide disparar quando há um alvo válido. A mira e os testes de headshot diferem entre a câmara fixa e as câmaras com mira. Ver {link('04 Arte e interface/Câmaras e controlos.md')}.

O sprint dispara por regra base desde 2026-10-14. Carregar bidões impõe restrições próprias. O Breaker abre caminho e liberta Grabbers. As fórmulas de classe, cartas, perks e dificuldade modificam os valores base abaixo.

| Constante observada | Valor literal |
|---|---|
{table}

Unidades e significado completos estão nos comentários de `game/data/game_data.gd` e no catálogo técnico. O limite de dano corpo a corpo é por passo da simulação; não equivale a um teto universal para todos os ataques.

{link('02 Conteúdo/Armas.md')} · {link('02 Conteúdo/Classes.md')} · {link('02 Conteúdo/Inimigos.md')} · {ref('docs/tech/COMBAT_CATALOG.md')}.
''',['game/data/game_data.gd','game/world/island_run.gd','docs/DECISIONS.md','docs/tech/COMBAT_CATALOG.md'])
    put('03 Sistemas/XP e cartas.md','XP e cartas',f'''
Os abates deixam XP. Ao subir de nível escolhe-se uma carta; as ofertas e os filtros vivem em `game/world/card_offers.gd`. As fichas estão em {link('02 Conteúdo/Cartas.md')}.

## Regras a acompanhar

- A curva observada em `GameData.xp_for_level` é `10 × (8 + 6L + L²)` para o nível atual L.
- Fast Learner anuncia +5% por rank. A recolha usa o multiplicador e guarda a fração em `xp_fraction`; o arredondamento não deve perder sistematicamente o bónus.
- O nível de recolha automática de XP definido nos dados é 30.
- Há um reroll gratuito por ecrã; não acumula. Extra Reroll aplica-se ao ecrã seguinte.
- Cartas no rank máximo não devem continuar nas ofertas; isto pertence às regras de ofertas, não apenas ao texto da carta.

| Nível L | XP necessária pela fórmula base |
|---:|---:|
| 1 | 150 |
| 10 | 1 680 |
| 30 | 10 880 |

Esta nota não mede o tempo real para ganhar níveis. O equilíbrio precisa de runs e telemetria.

Fontes: `game/data/game_data.gd::xp_for_level`, `game/world/island_run.gd::_collect_xp_orb`, `game/world/card_offers.gd`, {ref('docs/DECISIONS.md')}.
''',['game/data/game_data.gd','game/world/island_run.gd','game/world/card_offers.gd','docs/DECISIONS.md'])
    put('03 Sistemas/Intel e perks.md','Intel e perks',f'''
Intel é a progressão entre runs. Morrer conserva o que foi ganho; o multiplicador de extração configurado é 1,5. Os preços específicos constam das fichas de armas, classes, cartas e perks.

## Árvore observada

`game_data.gd` declara quatro ramos: **combat, survival, breaker e logistics**; três patamares e três ranks máximos. Há {counts['perks']} Resources de alternativas. Recursos de alternativas, nós e slots não são a mesma contagem.

Os ranks são comprados por nó; as alternativas partilham ranks e podem ter filtros de classe. Os valores de benefício/penalização nos Resources são totais por rank. A regra de troca deve ser conferida no perfil e no Armory.

{link('02 Conteúdo/Perks.md')} · {link('02 Conteúdo/Armas.md')} · {link('02 Conteúdo/Classes.md')}.

Fontes: `game/data/game_data.gd`, `game/data/resources/perk_data.gd`, `game/core/profile.gd`, {ref('docs/design/CARDS_WEAPONS_PERKS.md')}.
''',['game/data/game_data.gd','game/data/resources/perk_data.gd','game/core/profile.gd','docs/design/CARDS_WEAPONS_PERKS.md'])
    keys=['POWER_UP_CHANCE','POWER_UP_SPECIAL_CHANCE','POWER_UP_PITY_KILLS','POWER_UP_DROP_INTERVAL','POWER_UP_GROUND_SECONDS','POWER_UP_BLINK_SECONDS','POWER_UP_PICKUP_RADIUS']
    table='\n'.join('| `'+k+'` | '+observed[k]+' |' for k in keys)
    put('03 Sistemas/Power-ups e pickups.md','Power-ups e pickups',f'''
Power-ups de abate são recolhas temporárias distintas das cartas e das caixas de mantimentos. **Só têm efeito quando apanhados.** Expirar ou sair sem recolher significa perder o power-up.

Há {counts['power_ups']} tipos em {link('02 Conteúdo/Power-ups.md')}. Cada ficha apresenta os campos do seu Resource; regras globais de queda, pity e tempo no chão ficam em `game_data.gd`.

| Constante observada | Valor literal |
|---|---|
{table}

Probabilidades são frações de 0 a 1; intervalos e tempos estão em segundos, e o raio em metros. São valores para playtest.

Fontes: {ref('docs/tech/POWER_UPS_AND_DEFEAT.md')} · {ref('docs/DECISIONS.md')} · `game/data/game_data.gd`.
''',['docs/tech/POWER_UPS_AND_DEFEAT.md','docs/DECISIONS.md','game/data/game_data.gd'])
    put('03 Sistemas/Horda e diretor.md','Horda e diretor',f'''
O diretor alterna crescimento, pico e alívio. A horda usa agentes como dados, pesquisas espaciais e flow field; a apresentação usa MultiMesh e shaders nos comuns. Não corresponde a um nó completo por zombie.

| Área | Fonte de implementação |
|---|---|
| Simulação da horda | `game/horde/` |
| Ritmo de população | `game/world/director.gd` |
| Regras de combate da ilha | `game/world/island_run.gd` |
| Aparência e deformação | `game/world/zombie_model.gd` e shaders associados |
| Especializados e boss | `game/world/special_enemy_model.gd` |

Limites de população dependem do modo e da dificuldade. O TODO pede observação da distribuição depois da correção de 2026-11-10; a existência do teste não prova leitura visual satisfatória.

{link('02 Conteúdo/Inimigos.md')} · {link('03 Sistemas/Exfil.md')} · {link('05 Desenvolvimento/Desempenho.md')} · {ref('docs/tech/SPECIAL_ENEMY_MODELS.md')}.
''',['game/world/director.gd','game/world/island_run.gd','game/world/zombie_model.gd','TODO.md','docs/tech/SPECIAL_ENEMY_MODELS.md'])
    put('03 Sistemas/Missões e objetivos.md','Missões e objetivos',f'''
As missões são declaradas em Resources e executadas pela simulação. Marcadores das cenas podem substituir posições e quantidades geradas. Consultar {link('02 Conteúdo/Missões.md')} para as {counts['missions']} fichas.

Uma missão, um bioma e um mapa são conceitos diferentes. «Holdout existe» não implica que entre no sorteio normal; o campo `on_route` controla essa disponibilidade.

O TODO regista pools de objetivos na beach_01 e pontos alternativos de extração no Exfil; a revisão visual dos locais continua pendente. A proposta geral de objetivos permanece uma referência de design, não prova de que todos foram integrados.

{link('02 Conteúdo/Mapas e expedições.md')} · {link('02 Conteúdo/Berlenga.md')} · {ref('docs/design/OBJECTIVES_PROPOSAL.md')} · {ref('docs/design/WORLD_AND_MISSIONS.md')}.
''',['game/data/resources/mission_data.gd','game/world/island_run.gd','TODO.md','docs/design/OBJECTIVES_PROPOSAL.md'])
    put('03 Sistemas/Exfil.md','Exfil',f'''
Modo mantido por decisão de 2026-11-10: hordas sem fim e extração aos dez minutos num mapa próprio. A documentação aponta a entrada atual pelo sandbox DEV.

Mapa: `game/world/handmade/test/exfil_test.tscn`. O TODO classifica os degraus do diretor e o ritmo de especiais como hipóteses de playtest. A telemetria do sandbox tem limites próprios; não assumir que grava os mesmos ficheiros de uma run normal.

A arena local em `assets/models/environment/extraction_test_arena/` está em trabalho noutra frente; o cofre não alterou nem certificou essa entrega. Confirmar geometria, grelha, cais, beacon e passagens no motor antes de a tratar como final.

{ref('docs/design/DEV_MENU.md')} · {ref('TODO.md')} · {link('02 Conteúdo/Mapas/Mapa - exfil_test.md')}.
''',['docs/DECISIONS.md','docs/design/DEV_MENU.md','TODO.md'])
    put('03 Sistemas/Perfil e telemetria.md','Perfil e telemetria',f'''
O perfil persiste preferências, Intel e desbloqueios; o contexto da run liga os estados durante a viagem. A lógica deve suportar saves antigos e tratar seleções inválidas.

| Ficheiro | Papel a consultar |
|---|---|
| `game/core/profile.gd` | Perfil, preferências e migrações |
| `game/core/run_context.gd` | Estado que transita entre partes da run |
| `game/world/island_run.gd` | Eventos e resultados da simulação |

A remoção da Heavy Pistol deve converter seleções antigas para Shotgun sem reembolso, conforme o catálogo técnico e a escolha do utilizador. Isso não implica conceder uma arma nova ou devolver Intel.

Para telemetria e limitações por modo, consultar {ref('game/README.md')}, {ref('TODO.md')} e os testes correspondentes. Não foram abertos saves pessoais nesta tarefa.
''',['game/core/profile.gd','game/core/run_context.gd','docs/tech/COMBAT_CATALOG.md','TODO.md'])
    art=['Menus e HUD','Câmaras e controlos','Modelos e animação','Ilhas e cenário','Áudio e diálogos','Assets e licenças']
    put('04 Arte e interface/Arte e interface.md','Arte e interface','← '+link('00 Início.md')+'\n\n'+'\n'.join('- '+link('04 Arte e interface/'+n+'.md') for n in art),kind='mapa')
    captures=[]
    for name in ['title','armory_class','armory_weapons','armory_perks']:
        source='docs/design/dossier_20261111/'+name+'.png'
        if (PROJECT/source).exists():
            raw=(PROJECT/source).read_bytes();target='98 Anexos/Menus/'+name+'.png'
            SOURCES[source]=digest(raw);NOTES[target]=raw;DEPENDENCIES[target]=[source]
            captures.append('!'+link(target))
    put('04 Arte e interface/Menus e HUD.md','Menus e HUD',f'''
## Direção aprovada mais recente

«Field dossier»: papel, tinta, máquina de escrever, carimbos e fotografias. A decisão de 2026-11-11 transforma a cena 3D do abrigo em fotografia presa à ficha da classe. Os perks usam quadro de cortiça; as armas, formulário de requisição.

## Implementação e validação a distinguir

O TODO descreve título e Armory como feitos nesta direção; barco, debrief, cartas, diálogos e pausa ainda têm trabalho pendente. O HUD mantém o UiTheme, com placas escuras aprovadas em novembro.

`docs/design/MENUS.md` conserva fases anteriores — Atlântico/azulejo e Armory com abrigo ao fundo. Ler as decisões datadas antes de replicar uma imagem antiga.

Fontes: {ref('docs/DECISIONS.md')} · {ref('TODO.md')} · {ref('docs/design/MENUS.md')} · {ref('docs/tech/ARMORY_REDESIGN.md')}.
Código relevante: `game/ui/dossier.gd`, `game/states/armory.gd`, `game/ui/perk_node_view.gd`, `game/ui/hud.gd`.

## Capturas de referência

Imagens copiadas sem alterações de `docs/design/dossier_20261111/`. São capturas já existentes na documentação, não uma nova sessão de validação.

{chr(10).join(captures)}
''',['docs/DECISIONS.md','TODO.md','docs/design/MENUS.md','docs/tech/ARMORY_REDESIGN.md'])
    put('04 Arte e interface/Câmaras e controlos.md','Câmaras e controlos',f'''
Três modos: primeira pessoa, terceira pessoa e fixa. O perfil guarda a preferência. As regras de auto-fire e de headshot devem ser lidas em conjunto com cada modo.

Os controlos documentados incluem WASD, rato, V para câmara, Espaço/botão direito para Breaker, Shift para sprint, G para habilidade, E para interação, 1/2 para armas, R para reroll e Esc para pausa/voltar. Rebinding e comando podem alterar as teclas reais.

Definições têm Display, Graphics, Controls e Audio. Os ícones de comando seguem o dispositivo ligado automaticamente, por decisão de 2026-10-18. Testar reconexão e comando físico continua a ser validação própria.

{ref('game/README.md','Tabela completa de controlos')} · {ref('docs/design/CAMERA_CONTROLS_HUD.md')} · {ref('docs/tech/SETTINGS_INPUT.md')} · {link('03 Sistemas/Combate e movimento.md')}.
''',['game/README.md','docs/DECISIONS.md','docs/design/CAMERA_CONTROLS_HUD.md','docs/tech/SETTINGS_INPUT.md'])
    put('04 Arte e interface/Modelos e animação.md','Modelos e animação',f'''
## Contratos importantes

- Recruit e Vanguard têm fontes e notas de integração próprias.
- Nomes e hierarquia do rig, pontos de pega e escala são contratos; não mudar para melhorar um render sem tratar as dependências.
- Braços de primeira pessoa e animações de recarga são assets diferentes dos corpos completos.
- Crawler tem requisitos de pose, alvo da cabeça e tombamento próprios.
- O Walker herói anterior é um molde de rig/clips: o TODO diz que a malha não entra no jogo atual.

O realismo das personagens está em aberto. O TODO regista tentativas que falharam anatomia; não apresentar esses protótipos como modelos finais aprovados.

Fontes: {ref('docs/tech/RECRUIT_MODEL.md')} · {ref('docs/tech/VANGUARD_MODEL.md')} · {ref('docs/tech/WEAPON_MODELS.md')} · {ref('docs/tech/LOCOMOTION.md')} · {ref('docs/tech/MODELS_ROUND_BRIEF.md')} · {ref('TODO.md')}.
''',['docs/tech/RECRUIT_MODEL.md','docs/tech/VANGUARD_MODEL.md','docs/tech/WEAPON_MODELS.md','docs/tech/LOCOMOTION.md','docs/tech/MODELS_ROUND_BRIEF.md','TODO.md'])
    put('04 Arte e interface/Ilhas e cenário.md','Ilhas e cenário',f'''
As cenas feitas à mão e os mapas gerados têm de oferecer obstáculos legíveis, caminhos de fuga e objetivos alcançáveis. A decisão de 2026-11-10 pede aspeto natural, com piloto na beach_01.

O TODO descreve integração das 13 peças do scenery_kit, vegetação variada, materiais de terreno e costa menos regular. Ter um kit GLB no repositório não equivale a estar colocado e validado na ilha.

O preset horror precisa de revisão em jogo: luz, estrada, cor dos biomas e leitura de erva/seixos. Este cofre não importou nem renderizou cenas do jogo.

{link('02 Conteúdo/Biomas.md')} · {link('02 Conteúdo/Mapas e expedições.md')} · {ref('docs/tech/REALISTIC_PROPS.md')} · {ref('docs/tech/MAPS_HANDOFF.md')} · {ref('TODO.md')}.
''',['docs/DECISIONS.md','TODO.md','docs/tech/REALISTIC_PROPS.md','docs/tech/MAPS_HANDOFF.md'])
    put('04 Arte e interface/Áudio e diálogos.md','Áudio e diálogos',f'''
O áudio próprio está em `game/audio/sfx.gd`, `music.gd` e `ambience.gd`. A documentação descreve sons sintetizados e música adaptativa; a revisão a ouvido continua no TODO.

Os diálogos de briefing, rádio e Origin ficam em `game/data/dialogue/`. Consultar {link('01 Projeto/História e tom.md')} para o enquadramento e distinguir texto existente de conteúdo efetivamente acessível.

Volume, equilíbrio, transições musicais, legibilidade dos avisos e conforto durante uma run exigem audição. A organização das notas não validou som.

Fontes: {ref('game/README.md')} · {ref('TODO.md')} · {ref('docs/tech/CREDITS.md')}.
''',['game/audio/sfx.gd','game/audio/music.gd','game/audio/ambience.gd','game/README.md','TODO.md'])
    put('04 Arte e interface/Assets e licenças.md','Assets e licenças',f'''
O registo de licenças é {ref('assets/LICENSES.md')}. Licenças livres não são todas equivalentes: algumas exigem atribuição, preservar avisos ou outras condições.

## Exceções explicitamente registadas

| Conteúdo | Licença / obrigação a consultar |
|---|---|
| Dados OpenStreetMap | ODbL; crédito «© OpenStreetMap contributors» |
| Céu noturno Sky3D, ESO/S. Brunier | CC BY 4.0; atribuição específica nos créditos |
| Special Elite | Apache 2.0, aceite a 2026-11-11 |
| Libre Franklin | OFL |
| Assets originais com declaração CC0 | Confirmar os ficheiros de licença da entrega; não generalizar a assets de terceiros |

As exceções aprovadas são específicas; aceitar o céu CC BY não autoriza qualquer modelo CC BY. Antes de integrar algo, conferir licença, origem, necessidade de créditos e escala/custo.

{ref('docs/tech/ASSETS.md')} · {ref('docs/tech/PLUGINS_REVIEW.md')} · {ref('docs/tech/CREDITS.md')} · {link('05 Desenvolvimento/Ferramentas e plugins.md')}.
''',['assets/LICENSES.md','docs/DECISIONS.md','docs/tech/ASSETS.md','docs/tech/PLUGINS_REVIEW.md','docs/tech/CREDITS.md'])
    dev=['Arquitetura observada','Mapa do código','Testes e validação','Inventário de testes','Desempenho','Ferramentas e plugins','Build e distribuição','Colaboração e regras','Como usar e atualizar o cofre']
    put('05 Desenvolvimento/Desenvolvimento.md','Desenvolvimento','← '+link('00 Início.md')+'\n\n'+'\n'.join('- '+link('05 Desenvolvimento/'+n+'.md') for n in dev),kind='mapa')
    put('05 Desenvolvimento/Arquitetura observada.md','Arquitetura observada',f'''
## Organização presente

| Área | Papel a investigar |
|---|---|
| `game/main.gd`, `states/` | Entrada, transições e ecrãs de estado |
| `game/core/` | Perfil, contexto e configurações |
| `game/data/` | Resources, registos YARD e constantes GameData |
| `game/world/island_run.gd` | Regras da simulação, separadas da apresentação |
| `game/world/island.gd`, `handmade/` | Cena, input, render e mapas |
| `game/horde/` | Simulação espacial da horda |
| `game/ui/`, `game/audio/` | Interface e apresentação sonora |

{link('05 Desenvolvimento/Mapa do código.md')} lista classes e bases efetivamente declaradas. O projeto contém dependências autoload em `project.godot`; não assumir os três autoloads propostos no documento antigo de arquitetura.

{ref('docs/tech/ARCHITECTURE.md')} apresenta-se como proposta de pré-produção e preserva estruturas que não são automaticamente as atuais. {ref('docs/registry/architecture.yaml','Registo de arquitetura')} e {ref('docs/architecture/tr-registry.yaml','Registo técnico')} ficam disponíveis como referências, sem lhes atribuir atualização garantida.
''',['project.godot','docs/tech/ARCHITECTURE.md','docs/registry/architecture.yaml','docs/architecture/tr-registry.yaml','game/world/island_run.gd'])
    put('05 Desenvolvimento/Testes e validação.md','Testes e validação',f'''
{test_count} ficheiros de teste foram descobertos; consultar {link('05 Desenvolvimento/Inventário de testes.md')}. **Não foram corridos nesta tarefa documental.**

## Regra atual de aprovação

O teste passa se termina com código 0, imprime pelo menos uma linha `TEST: ` e não contém `TEST FAIL`, `SCRIPT ERROR` ou `Parse Error`. Crash codes falham mesmo depois dos resultados, salvo exceção explicitamente listada em `KNOWN_SHUTDOWN_CRASH`.

## Comandos no diretório do projeto

```powershell
& 'C:/Users/Rui/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_all.gd
```

Teste isolado: substituir `res://tests/run_all.gd` pelo teste pretendido. Depois de novos `class_name`, seguir a importação e o restauro das bibliotecas atuais indicados no AGENTS; não reutilizar o comando antigo com Orchestrator e TerraBrush.

Playtests, comando físico, validação visual, som e medição em GPU não são substituídos por testes headless.

Fontes: {ref('AGENTS.md')} · `tests/run_all.gd` · {ref('TODO.md')}.
''',['AGENTS.md','tests/run_all.gd','TODO.md'])
    put('05 Desenvolvimento/Desempenho.md','Desempenho',f'''
Os números só valem para o cenário, resolução e máquina em que foram medidos. O TODO e `game/README.md` registam medições anteriores; o cofre não as repetiu.

O TODO ainda pede Berlenga, vulcão com Behemoth, cartas elementais em pico e resoluções maiores. Confirmar custo de geometria, materiais, sombras, efeitos, grelha e horda no jogo completo.

Para novas medições, usar {link('99 Modelos/Ensaio de validação.md')}, anotar condições e comparar antes/depois. O mapa de código é {link('05 Desenvolvimento/Mapa do código.md')}.

Fontes: {ref('game/README.md')} · {ref('TODO.md')} · {ref('docs/tech/ENGINE_MIGRATION.md')}.
''',['game/README.md','TODO.md','docs/tech/ENGINE_MIGRATION.md'])
    project=read('project.godot')
    plugins=re.findall(r'res://addons/[^"\n]+/plugin\.cfg',project)
    plugin_list='\n'.join('- '+code(p) for p in plugins)
    put('05 Desenvolvimento/Ferramentas e plugins.md','Ferramentas e plugins',f'''
## Plugins listados na configuração

{plugin_list}

Esta é a lista textual de `project.godot`, não uma prova de que cada addon carregou nesta máquina. O YARD gere os registos de dados; G.U.I.D.E participa no input e nos ícones; outros addons têm integração e licenças próprias.

## Framework de agentes

Claude Code Game Studios 1.2.0 está documentado como instalado com adaptações. O guia upstream não substitui as regras deste projeto e inclui convenções de testes e caminhos diferentes. Ler {ref('docs/tech/AGENT_FRAMEWORK.md')} antes de seguir os guias importados.

Engine/API: {ref('docs/engine-reference/godot/VERSION.md')} e {ref('docs/engine-reference/godot/breaking-changes.md')}. A versão instalada não foi sondada nesta tarefa.

{ref('docs/tech/PLUGINS_REVIEW.md')} · {link('04 Arte e interface/Assets e licenças.md')}.
''',['project.godot','docs/tech/AGENT_FRAMEWORK.md','docs/tech/PLUGINS_REVIEW.md'])
    put('05 Desenvolvimento/Build e distribuição.md','Build e distribuição',f'''
Plataforma-alvo: PC; versão configurada em `project.godot`: 0.1.0 nesta fotografia. A cena principal configurada é `game/main.tscn`.

O TODO pede reexportar o pacote Windows com o código atual, decidir ícone/versão e testar fora do editor. Não considerar o diretório de build como versão atual apenas por existir.

Antes de distribuir, conferir preset de exportação, assets e créditos, arranque limpo e diferenças entre debug e release. Ferramentas de DEV não devem ser confundidas com o fluxo público.

{ref('tools/export/README.md')} · {ref('docs/design/DEV_MENU.md')} · {ref('docs/tech/CREDITS.md')} · {link('05 Desenvolvimento/Testes e validação.md')}.
''',['project.godot','TODO.md','tools/export/README.md','docs/design/DEV_MENU.md','docs/tech/CREDITS.md'])
    put('05 Desenvolvimento/Colaboração e regras.md','Colaboração e regras',f'''
As regras atuais estão em {ref('CLAUDE.md')} e {ref('AGENTS.md')}. Estas cópias são documentação; não acrescentam instruções novas ao projeto.

- Código e texto do jogo em inglês; notas para o utilizador em português de Portugal.
- `TODO.md` é a lista ativa; handoffs e relatórios em `docs/history/` são registos.
- Só o agente principal Claude Code regista no `docs/DECISIONS.md` as decisões explícitas do utilizador, com data; Codex não o edita.
- Commit/push apenas quando pedidos; não usar stash nem incluir os ficheiros pessoais `world_test_handmade*`.
- Pareceres JEV são consultivos. Usar dados mínimos, sem segredos, e guardar respostas com o caminho indicado ao utilizador.

Nesta tarefa, os ficheiros locais de arena já existentes foram preservados; as alterações ficam no `vault/`.
''',['CLAUDE.md','AGENTS.md','TODO.md'])
    put('05 Desenvolvimento/Como usar e atualizar o cofre.md','Como usar e atualizar o cofre',f'''
## Abrir

No Obsidian, abrir a pasta `vault` deste repositório como cofre existente. Começar em {link('00 Início.md')}. Não exige plugins da comunidade; mapas, propriedades, ligações, backlinks e Canvas são recursos nativos.

## Três tipos de nota

| Área | Como usar |
|---|---|
| Mapas e fichas | Navegar e relacionar assuntos; todas têm fontes |
| `90 Referências/` | Cópias de consulta dos documentos; não substituem as fontes originais |
| `80 Trabalho/` e `99 Modelos/` | Registar ideias, sessões e ensaios sem criar um segundo backlog |

## Atualizar

No terminal, a partir da raiz do projeto:

```powershell
python 'vault/99 Ferramentas/sync_vault.py' --check
python 'vault/99 Ferramentas/sync_vault.py'
python 'vault/99 Ferramentas/validate_vault.py'
```

`--check` não escreve. A sincronização atualiza notas geradas que continuam intactas e **preserva notas editadas à mão**; os conflitos aparecem em `protected_user_edits` no manifest. Notas pessoais desconhecidas do gerador são preservadas. Não apaga notas nem devolve alterações às fontes.

O manifest guarda hashes das notas e das fontes. Conteúdo removido das fontes não é apagado automaticamente do cofre; rever a cobertura depois de uma atualização. Não há sincronização em tempo real.

## Trabalhar

Duplicar um modelo de `99 Modelos/`, guardar a nota em `80 Trabalho/Notas/` e ligá-la ao tema relevante. Para tarefas reais, atualizar o `TODO.md` original. Propostas ficam identificadas como propostas até decisão explícita.

## Validação e limites

O verificador testa ligações internas, dados copiados, inventário e ficheiros do cofre. Não executa Godot nem comprova o conteúdo de todas as propostas. Nesta entrega, a interface do Obsidian não foi aberta nem testada.

As respostas JEV desta tarefa ficam em `99 Ferramentas/JEV/`.
''',['TODO.md','AGENTS.md'])
    put('80 Trabalho/Painel de trabalho.md','Painel de trabalho',f'''
← {link('00 Início.md')}

1. Consultar {ref('TODO.md','a lista ativa — snapshot de consulta')} e escolher um tema.
2. Abrir a nota do sistema ou conteúdo correspondente.
3. Criar um registo com {link('99 Modelos/Registo de sessão.md')} ou {link('99 Modelos/Ensaio de validação.md')}.
4. Anotar evidência e dúvidas na sessão; alterar tarefas apenas no TODO original.

{link('80 Trabalho/Ideias e propostas.md')} · {link('80 Trabalho/Notas/Primeira nota.md')} · {link('01 Projeto/Situação atual.md')}.

Não há tarefas duplicadas neste painel. As áreas em aberto pertencem ao TODO e às decisões do utilizador.
''',['TODO.md'],'mapa')
    put('80 Trabalho/Ideias e propostas.md','Ideias e propostas','Registar aqui ideias antes de serem aprovadas. Cada proposta deve indicar problema, pilar, custo, alternativa e evidência.\n\nModelo: '+link('99 Modelos/Proposta de decisão.md')+'\n\nUm texto nesta área não modifica as decisões do projeto. Ligação ao registo oficial: '+ref('docs/DECISIONS.md')+'.')
    put('80 Trabalho/Notas/Primeira nota.md','Primeira nota','Esta nota é tua. Podes substituí-la por uma dúvida, observação ou ideia e ligá-la a uma ficha com o seletor de ligações do Obsidian.\n\nVoltar: '+link('80 Trabalho/Painel de trabalho.md')+'.',kind='trabalho')
    models={
        'Registo de sessão':'Data: {{date:YYYY-MM-DD}}\n\n## Objetivo\n\nUma frase.\n\n## Evidência e alterações\n\nIndicar ficheiros, observações e testes realmente executados.\n\n## Dúvidas\n\nSeparar dúvidas de decisões.\n\n## Próxima ação\n\nUma ação concreta; tarefas ficam no TODO original.',
        'Ensaio de validação':'Data: {{date:YYYY-MM-DD}}\n\n## Hipótese\n\nO que se quer confirmar?\n\n## Condições\n\nCena, seed, Threat, classe, armas, build, resolução e máquina.\n\n## Procedimento\n\nPassos reproduzíveis.\n\n## Resultado observado\n\nNúmeros, logs e imagens; não usar «passou» sem evidência.\n\n## Limites\n\nO que este ensaio não comprova?',
        'Ficha de asset':'## Uso e contrato\n\nSistema, escala, pivô, orientação, grips/ossos e limites de triângulos/texturas.\n\n## Origem e licença\n\nAutor, URL, licença exata e créditos exigidos.\n\n## Entrega e validação\n\nFicheiros, hashes, dimensões e testes executados.\n\n## Estado\n\nProposto, entregue, importado ou validado em jogo? São estados diferentes.',
        'Proposta de decisão':'## Estado\n\nProposta — não aprovada.\n\n## Problema e pilar\n\nO que melhora no jogo?\n\n## Opções\n\nComparar a proposta e uma alternativa simples.\n\n## Evidência e consequências\n\nDistinguir medição, hipótese e preferência.\n\n## Decisão do utilizador\n\nPreencher apenas depois de decisão explícita. O registo oficial continua no docs/DECISIONS.md, com o agente autorizado.',
    }
    for title,body in models.items():put('99 Modelos/'+title+'.md',title,body,kind='modelo')
    rows='\n'.join('| '+ref(source,source)+' | '+('Arquivo' if '/legacy/' in source or '/history/' in source else 'Consultar contexto')+' |' for source in REFS)
    put('90 Referências/Índice de fontes.md','Índice de fontes',f'''
← {link('00 Início.md')}

**{len(REFS)} documentos/configurações copiados** com fonte, hash e data. O código não é copiado integralmente: os dados têm fichas próprias e os scripts têm inventário.

A biblioteca de API do motor não é duplicada inteira; inclui os documentos de versão e breaking changes. Dependências de terceiros e memórias privadas dos agentes não são importadas. Os relatórios históricos e o design antigo ficam assinalados como arquivo ou referências a confrontar.

| Referência | Contexto |
|---|---|
{rows}
''',kind='mapa')
    nodes=[];edges=[]
    canvas_paths=['00 Início.md','01 Projeto/Projeto.md','02 Conteúdo/Conteúdo.md','03 Sistemas/Sistemas.md','04 Arte e interface/Arte e interface.md','05 Desenvolvimento/Desenvolvimento.md','80 Trabalho/Painel de trabalho.md']
    positions=[(0,0),(-650,-420),(0,-420),(650,-420),(-650,420),(0,420),(650,420)]
    for i,(path,(x,y)) in enumerate(zip(canvas_paths,positions)):
        nodes.append({'id':'n'+str(i),'type':'file','file':path,'x':x,'y':y,'width':460,'height':300,'color':str(1+i%6)})
        if i:edges.append({'id':'e'+str(i),'fromNode':'n0','fromSide':'top' if y<0 else 'bottom','toNode':'n'+str(i),'toSide':'bottom' if y<0 else 'top'})
    NOTES['Mapa do projeto.canvas']=json.dumps({'nodes':nodes,'edges':edges},ensure_ascii=False,indent=2)+'\n'
    DEPENDENCIES['Mapa do projeto.canvas']=[]


def write_notes(check=False):
    old=json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {'notes':{}}
    report={'written':[],'unchanged':[],'protected_user_edits':[],'source_changes':[]}
    entries=dict(old.get('notes',{}))
    for relative,text in NOTES.items():
        if relative.endswith('.md'):
            # Obsidian tables need escaped alias separators inside wikilinks.
            text='\n'.join(re.sub(r'\[\[[^\]]+\]\]',lambda m:m[0].replace('|',r'\|'),line)
                           if line.lstrip().startswith('|') else line for line in text.split('\n'))
        target=(VAULT/relative).resolve()
        assert target.is_relative_to(VAULT.resolve())
        new_hash=digest(text);current=digest(target.read_bytes()) if target.exists() else None
        previous=entries.get(relative,{}).get('sha256')
        if current==new_hash:report['unchanged'].append(relative)
        elif current is not None and current!=previous:
            report['protected_user_edits'].append(relative);continue
        else:
            report['written'].append(relative)
            if not check:
                target.parent.mkdir(parents=True,exist_ok=True)
                if isinstance(text,bytes):target.write_bytes(text)
                else:target.write_text(text,encoding='utf-8',newline='\n')
        entries[relative]={'sha256':new_hash,'sources':DEPENDENCIES.get(relative,[]),
                           'source_hashes':{s:SOURCES[s] for s in DEPENDENCIES.get(relative,[]) if s in SOURCES}}
    report['source_changes']=[s for s,h in SOURCES.items() if old.get('sources',{}).get(s) not in [None,h]]
    if not check:
        MANIFEST.parent.mkdir(parents=True,exist_ok=True)
        MANIFEST.write_text(json.dumps({'date':DATE,'notes':entries,'sources':SOURCES,'report':report},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return report


def main():
    global DATE
    parser=argparse.ArgumentParser();parser.add_argument('--date',default=date.today().isoformat());parser.add_argument('--check',action='store_true')
    args=parser.parse_args();DATE=date.fromisoformat(args.date).isoformat()
    source_inventory();references();catalog=content_notes();count,scenes=inventories();curated(catalog,count,scenes)
    report=write_notes(args.check)
    print(json.dumps({'notes':len(NOTES),'references':len(REFS),'catalog':{k:len(v) for k,v in catalog.items()},
                      **{k:len(v) for k,v in report.items()},'check_only':args.check},ensure_ascii=False))


if __name__=='__main__':main()
