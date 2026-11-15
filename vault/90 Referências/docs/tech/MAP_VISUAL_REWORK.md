---
titulo: "docs/tech/MAP_VISUAL_REWORK.md"
tipo: "referencia"
estado: "referencia_a_confrontar"
atualizado: "2026-11-15"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/tech/MAP_VISUAL_REWORK.md"]
---

# docs/tech/MAP_VISUAL_REWORK.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original.

Fonte: `docs/tech/MAP_VISUAL_REWORK.md` · SHA-256: `0d02cc17e944b755c9408b888b3e2f8c497f8449e28c87c3991edcb0acf291bc`

# Ilhas — renovação visual com assets e ferramentas do editor

Avaliação de 2026-11-14, seguida de implementação do **piloto visual beach_01**
a pedido do utilizador. O inventário e as alternativas abaixo descrevem a pesquisa
inicial; o estado implementado, os dois downloads CC0, capturas e validação estão
em [[90 Referências/docs/tech/BEACH_VISUAL_PILOT|BEACH_VISUAL_PILOT.md]]. Não foram instalados plugins novos.
As outras quatro ilhas continuam por renovar; a lista ativa é `TODO.md`.
Não foi alterado `docs/DECISIONS.md`.

## O que podemos fazer

É viável substituir o aspeto de grey-box por cenário natural e construções
com detalhe. O Assets2Godot facilita procurar e importar conteúdo; não desenha
as ilhas, resolve a navegação ou garante desempenho. A composição, preparação
dos modelos e validação em jogo continuam a ser trabalho do projeto.

Recomendo um primeiro ensaio da praia, conservando objetivos, passagens e
regras. Só depois de avaliar esse resultado se deve alterar a geometria das
rotas e repetir a direção visual nas restantes ilhas.

## O que já existe no projeto

| Conjunto | Estado observado | Aplicação |
|---|---|---|
| `assets/models/environment/scenery_kit/` | 13 GLB CC0-1.0, atlas PBR de 1K partilhado; piloto beach_01 usa 12 tipos (sem escada exterior) | 5 peças de praia e 7 peças de fachada |
| `assets/models/polyhaven/` | Manifesto com gerador, bidão, caixote e barricada em glTF 1K; usados por `IslandProps` | Objetivos e decoração já integrada |
| `assets/source/polyhaven/` | Originais locais, isolados da importação; além dos quatro modelos acima há barril, carrinho, braseiro, rádio, boia, cais, forte e barco Venus | Preparar versões para jogo antes de procurar substitutos |
| `assets/textures/polyhaven/` | Já contém areia/rocha costeira, rocha de falésia, chão com relva, reboco branco, telhas, pedra, madeira e metal enferrujado | Misturar melhor materiais existentes, evitando descarregar duplicados |
| `assets/models/nature_megakit/` | Kit estilizado CC0 já documentado e utilizado | Vegetação provisória e variação; harmonizar com os novos materiais |

O kit de praia inclui árvore morta, tronco de deriva, casco encalhado, poste
torto e rede caída. O de fachada inclui janela/portadas, porta, toldo, varanda,
escada, placa, candeeiro e chaminé. São peças próprias do projeto, não modelos
fotogramétricos: não se deve prometer o mesmo acabamento sem inspeção visual.

Fontes locais: `assets/LICENSES.md`, `docs/tech/REALISTIC_PROPS.md`,
`game/world/island_props.gd`, `game/world/scenery_kit.gd` e os manifestos.
`docs/tech/MAPS_HANDOFF.md` contém informação histórica que já foi substituída
(por exemplo, Hashima e créditos pendentes); não o tratar como lista atual.

## Mais assets confirmados

Todos os candidatos seguintes são Poly Haven **CC0-1.0**, segundo a
[licença oficial](https://polyhaven.com/license). Usos abaixo são propostas
artísticas minhas, não garantias do fornecedor.

Tamanhos em **MB decimais**, calculados a partir de `/files/<id>` da API,
consultada a 2026-11-14. Nos modelos: glTF 1K e dependências declaradas. Nas
texturas: apenas JPG 1K de diffuse, normal OpenGL e ARM. Não são tamanhos
de VRAM, versões reduzidas já validadas nem valores de um pacote ZIP.

| Asset e fonte | Autores | Tipo / tamanho escolhido | Uso proposto |
|---|---|---|---|
| [Boulder 01](https://polyhaven.com/a/boulder_01) | Rico Cilliers | Modelo, 5,77 MB | Substituir rochas isoladas geométricas; escolher geometria adequada à distância |
| [Coast Rocks 01](https://polyhaven.com/a/coast_rocks_01) | Rob Tuytel, Rico Cilliers | Modelo, 21,68 MB | Compor costa rochosa e esconder transições do terreno; preparação e redução antes de repetir |
| [Fern 02](https://polyhaven.com/a/fern_02) | Rob Tuytel, Rico Cilliers | Modelo, 1,15 MB | Fetos em zonas sombrias/húmidas da selva e da vila, fora das passagens |
| [Forest Ground 04](https://polyhaven.com/a/forest_ground_04) | Rob Tuytel, Rico Cilliers | 3 mapas, 3,32 MB | Variação de chão seco, terra e pedras nos caminhos florestais |
| [Concrete Floor 02](https://polyhaven.com/a/concrete_floor_02) | Rob Tuytel | 3 mapas, 1,12 MB | Pavimentos gastos do porto e pátios industriais |

Alternativas para uma fase posterior:

- [Rocky Terrain 02](https://polyhaven.com/a/rocky_terrain_02): 3 mapas 1K,
  2,36 MB; variação de terreno com pedra/erva. Não é uma textura de lava.
- [Coastal Cliff 01](https://polyhaven.com/a/coastal_cliff_01): glTF 1K e
  dependências, 15,38 MB; interessante para falésias. A página apresenta
  cerca de 866 mil triângulos na geometria anunciada e 92 m de largura.
  Não foi verificada a contagem de triângulos do glTF escolhido.
- [Grass Medium 01](https://polyhaven.com/a/grass_medium_01): glTF 1K e
  dependências, 3,07 MB; selecionar tufos/LODs apropriados. A geometria
  anunciada da coleção é muito densa; não equivale ao custo de um tufo.

**Texturas a 1K não reduzem a geometria.** Antes de integrar modelos: medir
malhas, selecionar ou produzir LODs, confirmar transparência, escala, origem,
materiais e custo. Texturas de 2K podem justificar-se em superfícies próximas
ou grandes; não é necessário reimportar todos os originais de 4K.

Metadados brutos desta consulta ficam localmente em
`.scratch/map_visual_research_20261114/polyhaven_metadata.json`; não foram
descarregadas malhas ou imagens durante a pesquisa. Na implementação posterior foram
descarregados Boulder 01 e Coast Sand 01; ver os manifestos e o relatório do piloto.

## Ferramentas do editor

| Ferramenta | Estado local / licença | Benefício e recomendação |
|---|---|---|
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | 1.0.2, ativo, MIT | Prioridade alta: relevo, mistura de materiais e pintura de vegetação. Aproveitar a instalação existente |
| [Sky3D](https://github.com/TokisanGames/Sky3D) | 2.1, ativo, MIT; céu noturno tem atribuição própria já documentada | Afinar céu, exposição, hora e atmosfera por bioma, preservando leitura dos inimigos |
| [Road Generator](https://github.com/TheDuckCow/godot-road-generator) | 0.9.4, ativo, MIT | Útil nas ruas da vila e porto; o ensaio local documenta interseções do asfalto com o relevo. Não reconstruir todas as estradas sem resolver isso |
| Color Grading | 1.0, ativo, MIT, registo em `assets/LICENSES.md` | Já existe integração por bioma em `game/world/grading.gd`. Afinar depois dos materiais/luz; investigar os erros do compositor observados na integração anterior antes de depender de mais efeitos |
| [ProtonScatter](https://store.godotengine.org/asset/hungryproton/protonscatter/) | Não instalado nesta avaliação; MIT no addon | Candidato para distribuir grupos de objetos por regras e excluir caminhos. A listagem atual marca a versão como instável; compatibilidade local com Godot 4.7 ainda não testada |

ProtonScatter não é necessário para começar: Terrain3D já oferece pintura de
instâncias. Se houver um ensaio futuro, usar apenas o addon e assets próprios
ou CC0. As texturas da demonstração têm condições adicionais de Textures.com,
segundo o [README do autor](https://github.com/HungryProton/scatter).

Na documentação da **versão instalada** do
[Terrain3D 1.0.2](https://raw.githubusercontent.com/TokisanGames/Terrain3D/v1.0.2-stable/doc/docs/instancer.md),
o instancer não cria colisões e trabalha com uma malha por instância; cenas
com tronco/folhas separados precisam de preparação ou outro método de
colocação. Não extrapolar automaticamente capacidades da documentação mais
recente para esta instalação.

Também usaria [Decal nativo do Godot](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html):
humidade, sujidade e manchas quebram a repetição dos materiais sem um addon
extra. São suportados pelo Forward+ do projeto. Névoa e outros efeitos devem
ser avaliados com inimigos presentes, não só numa cena vazia.

## Direção proposta por ilha

| Ilha | Alvo visual |
|---|---|
| Beach | Costa menos regular, rochas em grupos, transição areia seca/molhada, madeira de deriva, redes e pequeno cais; peças mortas/conteúdo sinistro apenas onde combina com o preset horror |
| Coastal Town | Casas caiadas com telhas, portas/portadas, toldos, varandas, sinais de abandono e pátios legíveis |
| Jungle | Vegetação organizada em massas, zonas de terra/pedra, fetos e clareiras para combate; não encher caminhos de plantas altas |
| Industrial Port | Pavimento de betão gasto, metal com ferrugem, barris, caixotes, estruturas de cais e contentores que precisam ainda de modelos adequados |
| Volcano | Silhuetas de rocha escura, terreno queimado e leitura clara da lava e da arena do boss; não usar um terreno com erva como substituto de material vulcânico |

Na Berlenga, respeitar a expedição em quatro partes e os dados de origem:
o forte e cais locais são candidatos de preparação, sem transformar o
relevo/rota real numa ilha genérica. Casas, contentores, pontes e barco de
extração continuam a precisar de uma escolha/preparação visual própria.

## Como evitar estragar a jogabilidade

`HandmadeIsland` lê `Buildings/`, `Rocks/`, `Trees/`, `Bridges/`, `Decor/` e
`Markers/` para produzir a grelha da simulação. Colisão física de um plugin
não atualiza automaticamente essa grelha. Decoração que aparenta bloquear
não pode ficar atravessável para a simulação; vegetação visual não deve
ocultar objetivos ou inimigos. O `Scatter` do projeto também não equivale
automaticamente ao `ProtonScatter` de terceiros.

Um piloto pode viver numa cópia de ensaio da praia em `trials/`, conservando
a cena atual para comparação. Medir grelha/passagens, objetivos e enquadramento
nas três câmaras; comparar CPU/GPU e memória com a mesma horda e definição
gráfica. Não prometer um FPS com base apenas no tamanho dos downloads.

`tools/dev/build_islands.gd` avisa que reconstruir as ilhas sobrescreve as
cenas. O acabamento final tem de sobreviver a esse fluxo: manter a autoria
dos visuais numa cena própria e/ou atualizar deliberadamente o gerador.
Não executar uma reconstrução em massa sobre alterações manuais.

## Verificação desta avaliação

Inspeção local e pesquisa de fontes oficiais; nenhuma execução do Godot nem
medição visual/desempenho nesta tarefa. Os 88 testes passados na integração
anterior pertencem àquela integração, não a mapas refeitos.

O JEV confirmou as duas afirmações documentais sobre limites do Terrain3D e
estado/licenças do ProtonScatter. Parecer consultivo em
`vault/99 Ferramentas/JEV/06_mapas_assets_plugins.json`; não demonstra que os
plugins ou candidatos funcionam neste projeto.
