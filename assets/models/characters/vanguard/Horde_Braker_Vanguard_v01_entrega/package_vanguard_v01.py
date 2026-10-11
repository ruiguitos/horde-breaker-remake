"""Build GIFs, visual comparison, full rig report and a checked delivery ZIP."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json,zipfile,hashlib
ROOT=Path(__file__).resolve().parent;WORK=ROOT/'vanguard_v01_work';OUT=ROOT/'Vanguard_v01_previews'
rig=json.loads((WORK/'rig_validation.json').read_text());glb=json.loads((WORK/'glb_validation.json').read_text());engine=json.loads((WORK/'godot_validation.json').read_text())
assert glb['passed'] and engine['passed']
assert 'GODOT_IMPORTED_DEMO_VALIDATION true' in (WORK/'demo_validation.log').read_text()
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
sheet=Image.new('RGB',(1200,1310),(18,24,27));draw=ImageDraw.Draw(sheet)
draw.text((20,14),'Vanguard v01 · 2,025 m · 4.056 triângulos · UAL 53 ossos',font=font,fill=(244,244,230))
for n,(name,label) in enumerate([('frente','Frente'),('perfil','Perfil'),('costas','Costas · mochila suspensa'),('perspetiva_3_4','Perspetiva 3/4')]):
    x=(n%2)*600;y=55+(n//2)*625;sheet.paste(Image.open(OUT/(name+'.png')).convert('RGB').resize((600,600),Image.Resampling.LANCZOS),(x,y));draw.text((x+15,y+600),label,font=small,fill=(244,244,230))
sheet.save(OUT/'Vanguard_quatro_vistas.jpg',quality=94)
compare=Image.new('RGB',(1200,840),(14,21,24));draw=ImageDraw.Draw(compare)
draw.text((20,15),'Referência · costas',font=font,fill=(244,244,230));draw.text((620,15),'Vanguard v01 · costas',font=font,fill=(244,244,230))
ref=Image.open(WORK/'reference_vanguard_back.png').convert('RGB').crop((480,309,645,670));ref=ImageOps.contain(ref,(580,750),Image.Resampling.NEAREST)
back=Image.open(OUT/'costas.png').convert('RGB').crop((200,75,780,820));back=ImageOps.contain(back,(580,750),Image.Resampling.LANCZOS)
compare.paste(ref,((600-ref.width)//2,65+750-ref.height));compare.paste(back,(600+(600-back.width)//2,65+750-back.height));compare.save(OUT/'Vanguard_comparacao_referencia.jpg',quality=94)
for label,clip in [('Idle','Idle_Loop'),('Walk','Walk_Loop'),('Run_Sprint','Sprint_Loop'),('Walk_hold','Walk_Loop')]:
    names=sorted((WORK/'motion_frames').glob(label+'_[0-9][0-9].png'));assert len(names)==12,(label,len(names))
    frames=[]
    for name in names:
        im=Image.open(name).convert('RGB');d=ImageDraw.Draw(im);d.rectangle((0,0,480,35),fill=(18,24,27));d.text((10,6),'Vanguard · '+('Walk com duas mãos' if label=='Walk_hold' else clip),font=small,fill=(244,244,230));frames.append(im.quantize(colors=192,method=Image.Quantize.MEDIANCUT))
    frames[0].save(OUT/(label+'.gif'),save_all=True,append_images=frames[1:],duration=round(engine['clips'][clip]['length_s']*1000/12),loop=0,disposal=2,optimize=False)
lines=[]
def add(s=''):lines.append(s)
add('# Horde Braker — Vanguard v01')
add()
add('Vanguard criado a partir do Recruit aprovado, com autorização para derivar o rosto e a frente. Foram **reconstruídas 55 peças**, mantendo 104 componentes rígidos, 35 materiais de cor lisa e exatamente os 53 ossos UAL. A referência fornecida mostra apenas as costas; a frente é uma interpretação aprovada pelo utilizador, não uma vista documentada do Vanguard original.')
add()
add('## Alterações de geometria e visual')
add()
add('1. **Capacete:** copa nova mais quadrada, topo chanfrado, aba larga, placa frontal e proteções laterais reconstruídas. Altura total exata de 2,025 m, igual ao Recruit; rosto, nariz, olhos, sobrancelhas e boca aprovados preservados.')
add('2. **Armadura:** ombreiras em placas largas, colete com seção e espessura maiores, placa peitoral reconstruída, alças reforçadas e bolsas frontais mais compactas. As ombreiras usam os ossos das clavículas para permanecerem sobre os ombros com os braços baixos.')
add('3. **Mochila:** volume retangular suspenso por duas ligações superiores, moldura verde-oliva, painel traseiro escuro e apoios inferiores discretos. A antiga peça `Backpack_Rear_Pocket` foi convertida num painel plano, conservando o nome de componente para continuidade. Não foram acrescentados gadgets, antenas, armas novas ou acessórios sem base na referência.')
add('4. **Uniforme e proteção:** tronco, bacia, mangas, antebraços, coxas, canelas, joelheiras e botas reconstruídos com planos e chanfros low-poly. As mãos e o equipamento de apoio herdado do Recruit mantêm-se separados.')
add('5. **Cores:** paleta verde-oliva com contrastes escuros, interpretada a partir da captura fornecida. Tons da pele, cabelo e arma preservados; zero texturas, subdivisões ou suavização das faces.')
add()
add('## Entrega e utilização no Godot')
add()
add('- `Horde_Braker_Vanguard_v01_rigged.blend`: modelo editável, componentes individuais, armature, ações auxiliares e estúdio de renderização.')
add('- `Horde_Braker_Vanguard_v01_rigged.glb`: personagem, arma substituível, skin e 53 ossos; sem animações, chão, câmaras ou luzes.')
add('- `Vanguard_UAL_compatible.tres`: 46 clips externos, adaptados automaticamente a este rest; `Vanguard_v01.tscn` já tem a biblioteca e o apoio de duas mãos configurados.')
add('- `Vanguard_v01_previews`: quatro vistas principais, três vistas em T-pose, detalhe das costas em 3/4, pose de empunhadura, frames de Idle/Walk/Sprint, quatro GIFs e comparação com a referência.')
add('- Scripts Python/GDScript e relatórios JSON de validação incluídos. Os ficheiros de origem do Recruit e da UAL foram preservados por SHA-256.')
add()
add('**Próximo passo:** copie o GLB, `Vanguard_v01.tscn`, `Vanguard_UAL_compatible.tres`, `Vanguard_UAL_loader.gd`, `Vanguard_Rifle_Hold.gd` e `Vanguard_Rifle_Hold_pose.json` para a mesma pasta no projeto Godot e instancie `Vanguard_v01.tscn` na cena do jogo. O contentor inicia Idle e o apoio de duas mãos; não contém controlador de movimento, colisões nem câmara.')
add()
add('Para mudar de clip, chame `play_ual("Walk_Loop")` ou `play_ual("Sprint_Loop")` no nó raiz do contentor. Desative `use_rifle_hold` para usar o balanço genérico dos braços. Se integrar o GLB diretamente, associe o carregador a um nó da instância e atribua a biblioteca externa no Inspector; não há mapeamento manual de ossos.')
add()
add('## Esqueleto, escala e arma')
add()
add('O rig mantém **exatamente o mesmo rest do Recruit**, incluindo nomes, pais, posições e orientações dos 53 ossos. Unidades em metros, +Y vertical no Godot, frente -Z, origem e solas em Y=0 na pose base. A altura real de ambos é 2,025 m, apresentada arredondada como 2,03 m. A pose base é T-pose, verificada na biblioteca original. A rotação fixa de 180° no contentor `Rig` corrige a frente da biblioteca sem modificar os eixos locais; conserve-a.')
add()
add('Cada peça tem uma única influência de peso 1,0. Os ossos dos dedos são preservados, mas as luvas rígidas seguem a mão inteira. A biblioteca original contém canais absolutos de posição: use a cópia externa adaptada, pois aplicar todos os canais brutos pode restaurar as proporções originais da UAL. A adaptação é automática, sem mapeamento manual, e a biblioteca original permanece intacta.')
add()
add('A Assault Rifle existente foi mantida como **arma provisória substituível**; não foi criada uma Machine Gun nem os cinco modelos futuros. Todas as peças `Rifle_*` seguem `DEF-hand.R`. `Muzzle` é um nó independente na ponta do cano, com -Z local como direção do disparo e sem acrescentar um osso. Na T-pose, a arma acompanha a mão direita; o apoio esquerdo é fornecido pela sobreposição opcional de oito ossos do braço.')
add()
add('## Validação técnica')
add()
add('| Verificação | Resultado |');add('|---|---|')
for key,value in [
 ('Blender',rig['blender']),('Godot real',engine['godot_version']['string']),
 ('Altura do GLB',f"{glb['height_m']:.9f} m"),('Meshes / ossos / materiais','104 / 53 / 35'),
 ('Triângulos',str(glb['triangles'])),('Vértices no GLB',str(glb['render_vertices'])+' (normais planas duplicam vértices)'),
 ('Peças com nova topologia',str(len(rig['rebuilt_pieces']))),('Nomes e pais dos ossos','53/53, correspondência exata ao JSON'),
 ('Diferença de rest relativamente ao Recruit',str(glb['maximum_rest_difference_from_recruit'])),
 ('Topologia editável','Peças fechadas, manifold, volumes positivos, faces não degeneradas'),
 ('Pesos','Um único osso por peça, peso 1,0 por vértice'),('Animações / texturas no GLB','0 / 0'),
 ('Paleta','35 materiais; tons oliva e cores da pele/arma verificados'),
 ('Erro de matrizes de bind',f"{glb['max_bind_matrix_error']:.3g}"),
 ('Clips testados no motor',f"46; {sum(c['samples'] for c in engine['clips'].values())} amostras"),
 ('Idle / Walk / Sprint','17 amostras por clip, mais teste da empunhadura'),
 ('Erro máximo de escala em animação',f"{engine['maximum_bone_scale_error']:.3g}"),
 ('Erro da ligação do Muzzle',f"{engine['maximum_muzzle_attachment_error_m']:.3g} m"),
 ('Erro do apoio da mão esquerda',f"{engine['maximum_hold_contact_error_m']:.3g} m"),
 ('Cena importada pelo editor','Carregada e executada; Idle iniciado'),('Originais','Hashes SHA-256 preservados')]:add(f'| {key} | {value} |')
add()
add('Foram verificadas as matrizes de bind, a hierarquia, os nomes, os pesos, índices, áreas de triângulos, cores e dimensões no GLB. No Godot, foram avaliadas poses finitas, ausência de escalas indesejadas, ligação da arma e apoio esquerdo. Os testes numéricos dos 46 clips não equivalem a uma inspeção artística de todos os seus fotogramas. As vistas principais e amostras dos ciclos foram comparadas visualmente.')
add()
add('## Diferenças e limites que subsistem')
add()
add('- A referência é uma captura pequena, traseira, iluminada pelo jogo. A frente, as espessuras, os chanfros e os detalhes não visíveis foram interpretados a partir do Recruit com autorização; não se afirma uma correspondência exata com vistas inexistentes.')
add('- A silhueta mantém a mesma altura e o equipamento militar, mas tem detalhes adicionais de geometria herdados do Recruit e armadura mais volumosa do que a representação muito simples da captura. A mochila conserva o painel traseiro simples, sem a bolsa saliente do Recruit.')
add('- O skinning é rígido por pedido: não há deformação suave, articulação individual dos dedos ou expressões faciais. Flexões fortes podem revelar juntas ou interseções; armadura e colete volumosos podem tocar nos braços em alguns movimentos.')
add('- O apoio de duas mãos é uma pose fixa relativa ao tronco, não IK de mira global. O cano acompanha a inclinação do corpo. Novas armas podem precisar de offsets próprios de pega e apoio. Não foram implementados IK de pés, gameplay, colisões ou lógica da habilidade War Cry.')
add('- `Run_Sprint` mostra o clip `Sprint_Loop`, porque a biblioteca não tem um clip chamado `Run`. A integração foi testada no Godot 4.7.2; a sobreposição opcional usa `SkeletonModifier3D`, indisponível em algumas versões antigas de Godot 4.')
add()
add('## Repetir a construção')
add()
add('Mantenha na pasta os ficheiros aprovados do Recruit v03, os seus auxiliares de animação, os scripts de renderização e a biblioteca UAL original. `build_vanguard_v01.py` cria a geometria com bpy/bmesh e salva apenas nomes Vanguard. `prepare_vanguard_support.py` prepara cópias independentes da integração. O JSON do esqueleto está incluído em `vanguard_v01_work/UAL_skeleton_reference.json`. Os scripts param se a estrutura ou os critérios técnicos não corresponderem ao esperado.')
add()
add('```powershell')
add(r'python .\prepare_vanguard_support.py')
add(r'& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python .\build_vanguard_v01.py')
add(r'& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --threads 8 --python .\render_vanguard_v01.py -- --with-motion')
add(r'python .\validate_vanguard_v01.py')
add(r'& "CAMINHO\godot_console.exe" --headless --path .\vanguard_v01_work\godot_validation --script res://validate_ual.gd -- "C:/CAMINHO/PASTA_DO_MODELO"')
add('```')
add()
add('Para repetir o teste da cena importada, copie os seis ficheiros de integração para `vanguard_v01_work/godot_validation/demo`, execute Godot com `--headless --editor --import --path ... --quit` e depois `--headless --path ... --script res://validate_demo.gd`. Para regenerar o relatório, os GIFs e o ZIP, execute `python package_vanguard_v01.py` após esses testes. O Python externo precisa de numpy e Pillow; o Blender usa apenas módulos integrados. Uma nova execução substitui os entregáveis Vanguard v01, nunca os originais do Recruit. O pacote não duplica os executáveis do Blender/Godot nem os ficheiros de origem.')
add()
add('## Tabela completa: peça → osso')
add()
add('| Peça | Osso | Peso | Geometria | Materiais |');add('|---|---|---:|---|---|')
for p in rig['mapping']:add(f"| `{p['piece']}` | `{p['bone']}` | 1,0 | {'Reconstruída' if p['rebuilt'] else 'Herdada'} | {', '.join(p['materials'])} |")
add()
add('## Posições finais dos 53 ossos')
add()
add('Cabeças dos ossos em coordenadas globais do Godot, em metros, incluindo a orientação do contentor. +Y vertical; -Z frente. Extremos e dados completos constam de `vanguard_v01_work/rig_validation.json`.')
add()
add('| Osso | Pai | X | Y | Z |');add('|---|---|---:|---:|---:|')
for p in rig['bones']:
    x,y,z=p['head_global_godot_m'];add(f"| `{p['name']}` | `{p['parent']}` | {x:.6f} | {y:.6f} | {z:.6f} |")
add()
add('## Comparação visual')
add()
add('![Quatro vistas](Vanguard_v01_previews/Vanguard_quatro_vistas.jpg)')
add()
add('![Comparação traseira](Vanguard_v01_previews/Vanguard_comparacao_referencia.jpg)')
add()
add('![Walk com duas mãos](Vanguard_v01_previews/Walk_hold.gif)')
add()
add('## Integridade dos originais')
add()
for name,digest in rig['original_sha256'].items():add(f'- `{name}`: `{digest}`')
(ROOT/'Horde_Braker_Vanguard_v01_relatorio.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
files=[ROOT/name for name in ['Horde_Braker_Vanguard_v01_rigged.blend','Horde_Braker_Vanguard_v01_rigged.glb','Horde_Braker_Vanguard_v01_relatorio.md','Vanguard_v01.tscn','Vanguard_UAL_compatible.tres','Vanguard_UAL_loader.gd','Vanguard_Rifle_Hold.gd','Vanguard_Rifle_Hold_pose.json','build_vanguard_v01.py','prepare_vanguard_support.py','render_vanguard_v01.py','recruit_render.py','validate_vanguard_v01.py','gltf_inspect_utils.py','package_vanguard_v01.py']]
files+=list(OUT.glob('*.png'))+list(OUT.glob('*.jpg'))+list(OUT.glob('*.gif'))
files+=[WORK/name for name in ['reference_vanguard_back.png','UAL_skeleton_reference.json','rig_validation.json','glb_validation.json','godot_validation.json','demo_validation.log','godot_validation/project.godot','godot_validation/validate_ual.gd','godot_validation/validate_demo.gd']]
assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest for name,digest in rig['original_sha256'].items())
archive_path=ROOT/'Horde_Braker_Vanguard_v01_entrega.zip'
with zipfile.ZipFile(archive_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in files:archive.write(p,p.relative_to(ROOT))
with zipfile.ZipFile(archive_path) as archive:assert archive.testzip() is None
print('VANGUARD DELIVERY',len(files),'files',archive_path.stat().st_size,'bytes',flush=True)
