# Kits de cenário originais — CC0

## Ficheiros e renders

| Praia | Triângulos | Render |
|---|---:|---|
| [Árvore morta](beach_horror/dead_tree.glb), altura 4,30 m | 570 | [PNG](beach_horror/renders/dead_tree.png) |
| [Tronco de deriva](beach_horror/driftwood.glb) | 302 | [PNG](beach_horror/renders/driftwood.png) |
| [Casco encalhado](beach_horror/stranded_hull.glb), comprimento 5,27 m | 1 794 | [PNG](beach_horror/renders/stranded_hull.png) |
| [Poste de cais torto](beach_horror/crooked_dock_post.glb) | 638 | [PNG](beach_horror/renders/crooked_dock_post.png) |
| [Rede caída](beach_horror/fallen_fishing_net.glb) | 1 828 | [PNG](beach_horror/renders/fallen_fishing_net.png) |

| Fachada | Triângulos |
|---|---:|
| [Janela, caixilho e portadas](coastal_facade/window_shutters.glb) | 448 |
| [Porta e batente](coastal_facade/door_frame.glb) | 512 |
| [Toldo de lona](coastal_facade/canvas_awning.glb) | 300 |
| [Varanda pequena](coastal_facade/small_balcony.glb) | 612 |
| [Escada exterior](coastal_facade/exterior_stair.glb) | 508 |
| [Placa de taberna](coastal_facade/tavern_sign.glb) | 210 |
| [Candeeiro de parede](coastal_facade/wall_lantern.glb) | 178 |
| [Chaminé](coastal_facade/chimney.glb) | 296 |

[Render da fachada montada na parede de teste](coastal_facade/renders/facade_assembly.png).

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
[`jev/README.md`](jev/README.md); os pareceres são consultivos.

Esta pasta está isolada por `.gdignore`; não integra nem altera o jogo.
Uma integração futura terá de copiar as peças escolhidas para uma pasta
importável, fora deste isolamento. A parede e a iluminação dos previews não
fazem parte dos GLB. Licença em `LICENSE.txt`: trabalho original CC0-1.0,
sem assets, texturas ou fontes descarregados.
