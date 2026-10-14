# Arte dos zombies comuns e das armas

Estado a 2026-10-14. Decisão do utilizador: zombies comuns e armas no
**mesmo estilo blocky** do Recruit/Vanguard, mas com **materiais realistas**
(PBR) e **gore forte** nos zombies. Só os zombies comuns (o Walker, o
"Zombie normal" do GDD); especiais, Behemoth e sobrevivente ficam para depois.

Capturas (Godot com janela, GPU): `docs/design/art/`
(`zombie_lineup`, `zombie_closeup`, `zombie_back`, `zombie_walk`,
`zombie_corpses`, `zombie_bench`, `weapons`, `weapons_in_hands`, `fp_*`).
Geradas com `tools/dev/zombie_preview.gd`:

```bash
godot --path . --script res://tools/dev/zombie_preview.gd -- <png absoluto> lineup
# planos: lineup, back, walk, closeup, corpses, weapons, hands, fp_<arma>, bench, bench_empty
```

## Zombie: abordagem

- **Modelo em código** (`game/world/zombie_model.gd`): caixas, como o
  Recruit, ~1,95 m (o Recruit tem 2,03 m com capacete). Cada caixa sabe a que
  **parte** pertence (bacia, tronco, cabeça, braço/antebraço, coxa/canela),
  quanto **gore** tem e a sua cor. Um `ArrayMesh` por variante, com uma
  superfície por material.
- **4 variantes**: civil (T-shirt e jeans), trabalhador (camisa de linho;
  **falta-lhe o antebraço esquerdo**, coto com osso), casaco de cabedal
  (**sem maxilar inferior**: dentes, língua, carne), sem camisa (flanco
  aberto com costelas, perna das calças arrancada, descalço). A variante sai
  da velocidade-base sorteada de cada inimigo (`Horde.speeds`), que viaja com
  ele quando a horda compacta os arrays: é sempre a mesma para o mesmo
  zombie, sem mexer na `Horde`.
- **Animação procedimental na GPU** (`game/world/zombie.gdshader`): o
  esqueleto são pivôs fixos (anca, joelho, cintura, pescoço, ombro,
  cotovelo), como os pivôs do soldado antigo, mas calculados no *vertex
  shader*. Por instância só vão 4 números: fase do passo, quanto anda,
  investida (ou cambalear, se atordoado) e recuo do golpe / queda. Daí saem
  o andar arrastado (uma perna arrasta), braços esticados, cabeça a
  balançar, investida ao atacar, recuo ao levar um tiro e a queda para trás.
- **Porquê não esqueleto + UAL**: 150 `Skeleton3D` com `AnimationPlayer`
  custariam CPU por osso e por zombie todos os frames. Assim, a horda inteira
  é **um MultiMesh por variante** (4 + sombras), preenchido com um único
  `buffer` por frame (`game/world/zombie_horde_view.gd`).
- **Cadáveres**: quando um zombie morre, o `ZombieHordeView` cria um corpo
  com a mesma variante (procura-o onde foi desenhado no frame anterior), que
  cai para trás (longe do jogador), fica no chão ~4 s e afunda. Com
  *headshot* cai sem cabeça (a cabeça voa como antes, nos destroços).
- **Estado**: queimadura, veneno, frio, congelado, *flash* de impacto e
  atordoado tingem o zombie (cor da instância), como tingiam a cápsula.
- **Só visual**: posições, velocidades, *hitbox*, altura e *headshot* não
  mudaram. A cabeça em repouso fica a 1,80 m e a lógica aponta a 1,78 m
  (`IslandRun.enemy_head`); a andar desvia no máximo 0,24 m; para os lados e
  em altura nunca mais de 0,2 m (o raio de *headshot* da mira é 0,4 m). Na
  investida a cabeça avança até 0,7 m, mas na direção do jogador, isto é,
  ao longo do raio de mira.

## Gore (procedimental, sem downloads)

Tudo no *fragment shader*, com ruído 3D (*value noise* + fbm) na posição de
repouso (o sangue não "escorrega" quando o zombie anda):

- feridas abertas (carne vermelha húmida) cujo tamanho cresce com o gore da
  caixa; nas mais fortes aparece **osso**;
- **sangue fresco** (vermelho, brilhante) e **seco** (castanho-escuro, baço),
  escorridos verticais por baixo das feridas, salpicos e grandes manchas
  embebidas;
- **roupa rasgada**: nos materiais de tecido a ferida rasga o pano e mostra
  pele cinzenta com o bordo encharcado;
- pele morta: manchas esverdeadas, nódoas negras, veias, sujidade (mais
  forte nos pés);
- partes que faltam são geometria (coto, maxilar, flanco aberto), com caixas
  de carne/osso.

## Armas

- `game/world/weapon_model.gd`: as 5 armas em caixas com materiais Poly
  Haven (aço/gunmetal, polímero, nogueira, ferrugem). Origem no punho (mão
  direita), cano para -Z, nó `Muzzle` na ponta. Comprimentos reais: SMG
  0,74 m, espingarda de assalto 0,96 m, metralhadora e caçadeira 1,04 m,
  marksman 1,12 m.
- A espingarda de assalto **copia peça a peça** a espingarda entregue no
  `recruit_v03.glb`; a ponta coincide com o `Muzzle` do GLB (testado), por
  isso as outras armas usam o mesmo ponto de pega na mão.
- **Terceira pessoa e Armory**: `SoldierModel.set_weapon` põe a
  `WeaponModel` no `WeaponMount` da mão; a espingarda original do GLB fica
  escondida.
- **Primeira pessoa**: `ViewModel` usa a mesma `WeaponModel`, sem sombras, a
  50 % (antes 60 %; com a coronha real ficava grande demais). A marksman
  chega a 0,85 m à frente do olho.
- As silhuetas da Armory desenhadas em código (`armory_art.gd`) não mudaram.

## Texturas (Poly Haven, CC0)

`tools/art/fetch_polyhaven_textures.py` descarrega (só da API da Poly Haven)
e `tools/art/pack_textures.gd` empacota no formato das texturas das ilhas
(`assets/textures/polyhaven/<id>_diffuse|_nor_gl|_rough.res`: RGBA8 →
mipmaps → S3TC, `ImageTexture`). Registadas em `assets/LICENSES.md`.

| Id | Uso | Tamanho | Disco |
|---|---|---|---|
| leather_white | pele (tingida de cinzento-verde) | 512 | 3 × 171 KB |
| cotton_jersey | T-shirts, calças caqui | 512 | 3 × 171 KB |
| denim_fabric_06 | jeans | 512 | 3 × 171 KB |
| fabric_leather_02 | casaco, cinto, botas, cabelo | 512 | 3 × 171 KB |
| rough_linen | camisa de trabalho | 512 | 3 × 171 KB |
| blue_metal_plate | aço/gunmetal (diffuse em cinzento) | 1k | 3 × 683 KB |
| rubberized_track | polímero (diffuse em cinzento) | 1k | 3 × 683 KB |
| american_walnut_veneer | coronhas de nogueira | 1k | 3 × 683 KB |
| rusty_metal_04 | (já existia) cobertura do cano da metralhadora | — | 0 |

Total novo: **≈ 8,9 MB** (2,6 MB zombies + 6,3 MB armas). Os zombies usam
512 px porque são pequenos no ecrã; as armas 1k porque a primeira pessoa as
mostra de perto.

## Desempenho (medido)

Ambiente: Windows 11, RTX 5060, Godot 4.7.2, 1600×900, Forward+, sombras do
sol ligadas, vsync desligado (`zombie_preview.gd bench` vs `bench_empty`,
500 frames).

| Medida | Valor |
|---|---|
| 150 zombies a andar, GPU | +0,43 ms (0,56 → 0,99 ms) |
| 150 zombies, CPU de render | +0,09 ms (0,17 → 0,26 ms) |
| `ZombieHordeView.draw` (GDScript, 150) | 0,39 ms com janela; ~0,5 ms headless |
| caminho antigo (cápsula+cabeça+2 braços), headless | ~0,3 ms (sem custo real do RenderingServer) |
| construir as 4 malhas | ~7–9 ms, uma vez por sessão |

Limites: o caminho antigo só foi medido headless (o RenderingServer falso
não custa nada, por isso subestima-o); a GPU mediu-se numa planície vazia,
não numa ilha. Não há LOD: cada zombie tem ~600 vértices, 150 dão ~90 mil,
pouco para qualquer GPU com Forward+.

## Ligações ao resto do jogo

Edições mínimas fora dos ficheiros novos:

- `game/world/island.gd`: cria `_zombies` (`ZombieHordeView`); em
  `_draw_enemies` chama `_zombies.draw(...)` e esconde as cápsulas dos tipos
  que ele desenha; no ciclo de mortes chama `_zombies.on_death(...)` e os
  destroços de zombies comuns passam a cor de carne/pele.
- `game/world/soldier_model.gd`: `set_weapon` usa `WeaponModel`.
- `game/world/view_model.gd`: `set_weapon` usa `WeaponModel`; escala 50 %.
- Testes: `tests/test_zombie_model.gd`, `tests/test_weapon_models.gd`
  (novos); `tests/test_recruit_animation.gd` (a espingarda do GLB fica
  sempre escondida; as 104 peças contam-se sem as da arma).

## Como acrescentar inimigos especiais depois

1. Em `ZombieModel.boxes()` (ou num novo modelo com a mesma convenção de
   CUSTOM0/CUSTOM1), desenhar o especial em caixas com as mesmas partes e
   pivôs; se as proporções mudarem muito (Brute, Behemoth), escalar pela
   altura do `EnemyType` como hoje, ou criar pivôs próprios num shader
   irmão.
2. Juntar o tipo a `ZombieHordeView.KINDS` (ou a uma segunda vista com outro
   conjunto de malhas): a ilha deixa logo de desenhar a cápsula desse tipo.
3. Poses próprias (cuspir, agarrar, explodir) entram como novos estados no
   4.º número da instância (`INSTANCE_CUSTOM.w`).
4. O Runner ainda é cápsula de propósito: no GDD é um inimigo distinto do
   zombie normal e precisa de silhueta própria (mais baixo, inclinado).

## Decisões propostas

- Juntar o Runner aos zombies comuns com uma 5.ª variante magra e inclinada,
  ou dar-lhe um modelo próprio.
- Variação de tom de pele/roupa por instância (hoje cada variante tem cores
  fixas; numa multidão de 150 nota-se a repetição de 4 roupas).
