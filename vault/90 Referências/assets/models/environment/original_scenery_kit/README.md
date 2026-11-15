---
titulo: "assets/models/environment/original_scenery_kit/README.md"
tipo: "referencia"
estado: "referencia_a_confrontar"
atualizado: "2026-11-15"
tags: ["horde-breaker", "referencia"]
fontes: ["assets/models/environment/original_scenery_kit/README.md"]
---

# assets/models/environment/original_scenery_kit/README.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original.

Fonte: `assets/models/environment/original_scenery_kit/README.md` · SHA-256: `08d557c554958999ebc2945de1c0350881a7b7c1854b713b1264a740e66ebfbc`

# Kits de cenário originais — CC0

## Ficheiros e renders

| Praia | Triângulos | Render |
|---|---:|---|
| Árvore morta (`assets/models/environment/original_scenery_kit/beach_horror/dead_tree.glb`), altura 4,30 m | 570 | PNG (`assets/models/environment/original_scenery_kit/beach_horror/renders/dead_tree.png`) |
| Tronco de deriva (`assets/models/environment/original_scenery_kit/beach_horror/driftwood.glb`) | 302 | PNG (`assets/models/environment/original_scenery_kit/beach_horror/renders/driftwood.png`) |
| Casco encalhado (`assets/models/environment/original_scenery_kit/beach_horror/stranded_hull.glb`), comprimento 5,27 m | 1 794 | PNG (`assets/models/environment/original_scenery_kit/beach_horror/renders/stranded_hull.png`) |
| Poste de cais torto (`assets/models/environment/original_scenery_kit/beach_horror/crooked_dock_post.glb`) | 638 | PNG (`assets/models/environment/original_scenery_kit/beach_horror/renders/crooked_dock_post.png`) |
| Rede caída (`assets/models/environment/original_scenery_kit/beach_horror/fallen_fishing_net.glb`) | 1 828 | PNG (`assets/models/environment/original_scenery_kit/beach_horror/renders/fallen_fishing_net.png`) |

| Fachada | Triângulos |
|---|---:|
| Janela, caixilho e portadas (`assets/models/environment/original_scenery_kit/coastal_facade/window_shutters.glb`) | 448 |
| Porta e batente (`assets/models/environment/original_scenery_kit/coastal_facade/door_frame.glb`) | 512 |
| Toldo de lona (`assets/models/environment/original_scenery_kit/coastal_facade/canvas_awning.glb`) | 300 |
| Varanda pequena (`assets/models/environment/original_scenery_kit/coastal_facade/small_balcony.glb`) | 612 |
| Escada exterior (`assets/models/environment/original_scenery_kit/coastal_facade/exterior_stair.glb`) | 508 |
| Placa de taberna (`assets/models/environment/original_scenery_kit/coastal_facade/tavern_sign.glb`) | 210 |
| Candeeiro de parede (`assets/models/environment/original_scenery_kit/coastal_facade/wall_lantern.glb`) | 178 |
| Chaminé (`assets/models/environment/original_scenery_kit/coastal_facade/chimney.glb`) | 296 |

Render da fachada montada na parede de teste (`assets/models/environment/original_scenery_kit/coastal_facade/renders/facade_assembly.png`).

## Conteúdo e utilização

1. `beach_horror/`: cinco GLB, um PNG por modelo e `validation.json`.
2. `coastal_facade/`: oito GLB, um PNG do conjunto numa parede de teste e
   `validation.json`.
3. `source/scenery_kit.blend`: fonte editável, uma coleção por modelo. Só a
   árvore está visível por defeito; ativar a coleção da peça a editar.

Os GLB usam metros e Y para cima. Na praia, a origem fica no centro da base
dos limites da geometria, em Y=0, e a frente é −Z. Nas fachadas, a origem é o
centro dos pontos da face traseira, em Z=0; a peça projeta-se para +Z.

Cada modelo tem uma malha, uma primitiva e um material. O atlas original de
1024 × 1024 contém albedo sRGB, normal tangente e ORM linear: R=1,
G=roughness, B=metallic. Vidros são opacos e embaciados; o candeeiro não
contém uma luz. O casco tem tábuas em falta e cavernas expostas; a rede tem
aberturas em geometria. Não há esqueletos, animações, câmaras ou luzes nos GLB.

Reprodução com Blender 5.2: executar `build_kit.py` em modo background com
`--factory-startup --python-exit-code 1 --python`; depois executar
`validate_kit.py` da mesma forma. O gerador recria os ficheiros nesta pasta.
Os renders são feitos a partir de novas importações dos GLB entregues.

O `validation.json` geral regista dimensões, triângulos, pivôs, texturas,
hashes e limites dos testes. Os JSON de cada kit repetem o respetivo conjunto.
A validação não executa Godot nem mede desempenho, colisões ou interseções
contínuas. As respostas JEV e a tentativa bloqueada estão indexadas em
[[90 Referências/assets/models/environment/original_scenery_kit/jev/README|`jev/README.md`]]; os pareceres são consultivos.

Esta pasta está isolada por `.gdignore`; não integra nem altera o jogo.
Uma integração futura terá de copiar as peças escolhidas para uma pasta
importável, fora deste isolamento. A parede e a iluminação dos previews não
fazem parte dos GLB. Licença em `LICENSE.txt`: trabalho original CC0-1.0,
sem assets, texturas ou fontes descarregados.
