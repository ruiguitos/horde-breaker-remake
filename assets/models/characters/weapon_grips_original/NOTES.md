# Empunhaduras de primeira pessoa — cinco variantes

Cada arma carrega agora o seu próprio par de braços/mãos. Os cinco GLBs
partilham o rig `Arms`, os oito nomes de ossos e os três materiais originais,
mas a forma dos dedos e a posição das articulações são construídas para a
geometria da arma correspondente. Os GLBs e os `.blend` só contêm os braços.

| Arma | Triângulos | Adaptação |
|---|---:|---|
| rifle | 2 616 | Dedos fechados junto ao punho; apoio no guarda-mão circular |
| smg | 2 568 | Apoio mais próximo; dedos abaixo do tubo de armar |
| machine_gun | 2 658 | Mão mais à frente, no guarda-mão inferior, longe da caixa de munições |
| shotgun | 2 592 | Pega direita inclinada para a coronha convencional; mão esquerda no forend |
| marksman | 2 704 | Polegar direito pelo espaço da coronha; apoio sem deformar os dedos nas ranhuras |

## Construção e integração

Metros, +Y para cima, frente -Z; origem no ponto de empunhadura da arma.
`UpperArm` e `Forearm` conservam 0,30 m cada. O bind é alinhado e a pose
inicial é fletida, como na entrega original. Os ombros das armas compridas
são ajustados antes da construção para alcançar o apoio sem alongar ossos.
A mão direita fica na pose própria da arma; o IK esquerdo parte dessa pose.

Os dedos são malhas rígidas parentadas aos ossos `Hand_R`/`Hand_L`.
Mangas/palmas têm pesos rígidos e apenas a faixa do pulso usa 50/50.
Materiais: `sleeve_cloth`, `glove`, `skin`, sem texturas. Um atlas UV 0–1
sem sobreposição; normais e tangentes exportadas. SMG e Machine Gun incluem
agora um clip de recarga cada; as outras variantes continuam estáticas. Sem
luzes, câmaras ou malhas das armas. `source/` tem `.gdignore` para impedir que o
Godot importe os ficheiros Blender como modelos adicionais.

`FirstPersonArms.MODELS` referencia explicitamente os cinco GLBs. Ao trocar
de arma, `ViewModel` escolhe a variante e aplica o contacto definido em
`WeaponModel.SUPPORT_POINTS`. Os pontos foram medidos na superfície real
das armas. A metralhadora usa apoio em Z=-0,35 m; o ponto anterior estava
perto da caixa de munições. O seu enquadramento de anca fica 6 cm abaixo do
das outras armas, para deixar a extremidade da manga fora da imagem.

## Reproduzir

Na pasta deste ficheiro:

```text
blender --background --factory-startup --python build_weapon_grips.py
```

Usa apenas módulos Blender/Python incluídos e reutiliza o script original
em `../arms_firstperson_original/build_arms.py`. Os cinco GLBs de armas em
`../../weapons/tactical_original/` servem temporariamente de gabarito.
Nada é descarregado. `-- --weapon shotgun` reconstrói apenas essa variante,
conservando as outras entradas do manifesto.

Saídas: `<arma>/arms_firstperson.glb`, `source/arms_<arma>.blend`, relatórios
por variante e `grip_profiles.json`. A arma de referência é removida antes
de criar e guardar os braços, incluindo os seus dados órfãos. O construtor
original continua a produzir o asset inicial sem alterar as suas medidas.

## Clips de recarga por progresso — 2026-10-20

`smg/arms_firstperson.glb` contém exclusivamente `reload_mag_smg` e
`machine_gun/arms_firstperson.glb` exclusivamente `reload_mag_mg`. Cada clip
tem **1,000 s**. A SMG tem **567 keyframes** e a Machine Gun **549**.
Os tempos são a união de `t = i / 400 s, i = 0…400` com amostras de
0,00025 s na abertura (SMG: 0,10…0,125; MG: 0,80…0,82) e de 0,000125 s
no fecho (0,99…1,00). A lista completa está em `keyframe_times_s` dos JSON.
Esta densidade adicional evita atravessar a pega ao interpolar a abertura
dos dedos, sobretudo no regresso rápido do último 1%. O consumidor deve amostrar
`p * animation.length`; não deve deixar o relógio do AnimationPlayer comandar
a recarga. Os dois `.glb.import` usam `animation/fps=8000` para conservar as
transições curtas: é resolução de importação, não FPS do jogo. Ao importar
diretamente com `GLTFDocument`, passar a mesma precisão no segundo argumento
de `generate_scene(state, bake_fps)`; a predefinição de 30 perde os contactos
junto de p=0,89 e p=0,95. Os oito ossos, os três materiais, os buffers originais de geometria,
UV, pesos e bind e as transformações de repouso foram conservados. Abrir os
dedos temporariamente usa 24 morph targets por dedo curvado, sem novos ossos
nem triângulos; todos têm peso zero em p=0 e p=1. Os clips e os targets são
originais, **CC0-1.0**. A mão esquerda mantém a posição e orientação originais.

Os dois presets também desativam `optimizer/enabled` no AnimationPlayer.
A otimização predefinida introduzia deriva na mão da MG antes de p=0,80
e erro superior a 1 mm no contacto final. O teste verifica agora tanto
`GLTFDocument` como a `PackedScene` importada pelo editor, a 401 valores
de p por variante e por caminho de importação.

A SMG larga a pega a partir de p=0,10, aproxima a palma por baixo até p=0,30
e acompanha a base real do carregador até p=0,95. Regressa à pega em p=1.
O referencial é o do jogo: metros, +Y para cima e -Z para a frente. A base
central da chapa inferior é `(0, -0,148000, -0,143000)`; em p=0,50 deve
estar em **`(0, -0,268000, -0,143000)`**, com os 12 cm de queda aplicados
pelo jogo. A palma usa um ponto na superfície interior da luva, distinto do
punho/`Hand_R`. O carregador segue exatamente `ViewModel.reload_offset(p)`:
em p=0,95 ainda está 8,889 mm abaixo do encaixe, chegando ao encaixe em p=1.
Este detalhe da fórmula prevalece sobre a descrição de o encaixar em p=0,95.

Na Machine Gun a mão permanece na pega até p=0,80; abre os dedos e afasta-se
do corpo da arma, toca com a ponta do indicador a extremidade traseira do
`Charging slide`, acompanha-o entre p=0,89 e p=0,95 e volta à pega em p=1.
O contacto de referência do slide é `(0,045500, 0,106000, 0,003000)`, mais
`ViewModel.charge_offset(p)`: o recuo máximo de 3 cm ocorre em p=0,90.
A correia, o `Cocking knob` e as restantes peças fixas não são animados.

Posições medidas em espaço da arma, em metros; os JSON conservam os valores
completos e distinguem palma, punho e contacto do indicador:

| p | Palma direita SMG (X, Y, Z) | Punho direito SMG (X, Y, Z) |
|---|---|---|
| 0,00 | (0,018500; -0,025000; 0,016000) | (0,035000; -0,065000; 0,075000) |
| 0,25 | (0,095703; -0,310383; -0,143000) | (0,024608; -0,326883; -0,148141) |
| 0,50 | (0,000000; -0,268000; -0,143000) | (-0,071095; -0,284500; -0,148141) |
| 0,75 | (0,000000; -0,259111; -0,143000) | (-0,071095; -0,275611; -0,148141) |
| 1,00 | (0,018500; -0,025000; 0,016000) | (0,035000; -0,065000; 0,075000) |

Na Machine Gun, nos cinco p pedidos (0; 0,25; 0,50; 0,75; 1), a palma
direita está em `(0,018500; -0,025000; 0,016000)` e o punho em
`(0,035000; -0,065000; 0,075000)`. Contagens inalteradas: **SMG 2 568**,
**Machine Gun 2 658 triângulos**.

`build_weapon_grips.py -- --weapon smg` ou `--weapon machine_gun` reconstrói
a variante completa e acrescenta o clip automaticamente. Para acrescentar
apenas os clips aos GLBs/fontes existentes, sem reexportar geometria:

```text
blender --background --factory-startup --python reload_clips.py
blender --background --factory-startup --python validate_reload_clips.py
```

Os `.blend` guardam a ação no rig e os morph targets com drivers locais;
o frame 0 mantém a pose original. O construtor reproduz a animação a partir
destes mesmos parâmetros. `validation.json` e `grip_validation.json` de
cada variante contêm tempos, posições e resultados; `reload_validation.json`
contém a auditoria da malha deformada. A auditoria compara novas penetrações
com os contactos herdados da pega original, usando vértices, meios de arestas
e centros de triângulos. Não é uma prova contínua de todos os pares de
triângulos. Os contactos já existentes na pega não foram remodelados.
Nas peças do corpo da arma e antebraços, a tolerância para nova penetração
é 0,1 mm. Só nos pares dedo/mobília de pega já em contacto se conserva a
tolerância original de 1,5 mm para almofadas das luvas. O relatório também
expõe as sobreposições herdadas do repouso (até cerca de 7 mm em amostras
de faces); não se deve interpretar o resultado como interseção absoluta zero.

Esta tarefa acrescenta os assets. Durante a validação surgiram alterações
paralelas em `FirstPersonArms` e `ViewModel` que ligam os clips à recarga;
foram preservadas e o respetivo `test_first_person_reload.gd` passou.
`tests/test_reload_arm_clips.gd` verifica os GLBs reais, a amostragem por p,
os contactos e os extremos, incluindo a importação nativa do editor.

## Verificações

O build verifica sólidos manifold de volume positivo, faces não degeneradas,
pesos, bind, orçamento, densidade/ausência de sobreposição UV, normais e
tangentes. `validation.json` de cada variante lê os accessors reais do GLB.
`grip_validation.json` regista o ajuste contra a geometria original da arma.

As trajetórias das falanges são construídas em redor das secções das pegas.
As ranhuras são atravessadas pelos apoios largos dos dedos; não se seguem
as superfícies interiores das cavidades. Pequenas colisões locais das
almofadas das luvas são corrigidas contra a superfície, com folga nominal
de 0,6 mm. O teste numérico admite até 1,5 mm de contacto local nos vértices;
não é uma prova exata de ausência de interseções de todos os triângulos.

`godot_validation.json` mede a palma depois de aplicar os pesos à malha
real importada: erro inferior a 0,005 mm nas cinco variantes. Os testes são
`test_first_person_arms.gd`, `test_first_person_grip_assets.gd`,
`test_view_model.gd`, `test_weapon_models.gd` e `test_weapon_grips.gd`.
Este último também verifica as mãos das duas classes em terceira pessoa.
`source_validation.json` regista a reabertura dos cinco `.blend`.

As capturas estão em `docs/design/weapon_grips/`: primeira pessoa, apoio
esquerdo, pega direita, ADS e parede. Geram-se com
`tools/dev/weapon_grip_preview.gd`, num mundo isolado do Godot 4.7.2,
Compatibility, 1280×720, Recruit, FOV 70° (52,5° em ADS). A pose de grip
destas capturas antigas fica estática; os novos clips de recarga estão
descritos acima. Não foi criada uma animação de pump.
A ótica e o enquadramento ADS das armas sem miras configuradas continuam
a usar o comportamento existente nestas capturas antigas. As alterações
paralelas às miras têm documentação própria.

Validação concluída em **2026-10-21**: **65/65 scripts headless** (jogo e
spikes), todos com saída 0 e sem marcadores de falha reais. A execução foi
retomada do checkpoint e repetiu os testes alterados/novos após a reimportação.
Os perfis de teste usaram uma pasta APPDATA isolada, resolvendo a limitação
anterior de `user://`. As auditorias dos clips passaram a 1 133 amostras na
SMG e 1 097 na MG, dentro dos limites de contacto documentados acima.
Os rebuilds limpos mantêm os buffers e metadados estáticos originais; a maior
diferença de componentes da animação foi inferior a 0,000001. As dez poses
de recarga foram vistas numa captura real do Godot 4.7.2, Compatibility.
Ver `delivery_validation.json` e [passagem/resultado](../../../../docs/tech/RELOAD_ARM_CLIPS_RESUME.md).

O JEV recebeu apenas resumos anonimizados dos testes e verificou a coerência
de duas afirmações sobre seleção de variantes, alcance e limites da evidência.
Não recebeu código, modelos ou imagens. É apoio consultivo; as verificações
de geometria e importação são as descritas acima.

Na retoma de 2026-10-21, uma nova consulta JEV foi bloqueada pela aprovação
automática por envolver informação privada do projeto. Essa consulta não
valida a entrega; os resultados desta retoma são exclusivamente locais.

## Referências e licença

Geometria e pegas: exclusivamente as armas originais do próprio projeto e
o construtor original dos braços. Referência anatómica bibliográfica:
[OpenStax — Bones of the Upper Limb](https://openstax.org/books/anatomy-and-physiology-2e/pages/8-2-bones-of-the-upper-limb).
Nenhuma imagem ou malha dessa fonte foi copiada.

Geometria, scripts e capturas originais: **CC0-1.0**. Ver `assets/LICENSES.md`.
