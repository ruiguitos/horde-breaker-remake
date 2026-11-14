# Arena modular de teste — extração

Entrega original CC0, em metros, produzida com Blender 5.2.2 LTS. Esta pasta
está isolada por `.gdignore`: não integra o jogo. Não foi executado Godot,
alterado código do jogo ou feito commit durante esta tarefa.

## Peças

As dimensões abaixo seguem **X × Y × Z**, com **Y para cima**. Todos os GLB
têm uma cena, uma malha, uma primitiva e transformação identidade. Não contêm
luzes, câmaras, esqueletos ou animações. Plataforma e rampa são peças separadas.

| Peça / GLB | Dimensões (m) | Triângulos | Pivô local |
|---|---|---:|---|
| [Parede de betão](modules/concrete_wall/concrete_wall.glb) | 4 × 2,4 × 0,4 | 144 | Canto inferior esquerdo da face traseira de encosto |
| [Cobertura baixa](modules/low_cover/low_cover.glb) | 4 × 1,1 × 0,4 | 144 | Igual à parede |
| [Contentor](modules/shipping_container/shipping_container.glb) | 6 × 2,6 × 2,4 | 2 972 | Canto sudoeste da base |
| [Plataforma](modules/platform/platform.glb) | 8 × 1,2 × 8 | 116 | Canto sudoeste da base |
| [Rampa](modules/ramp/ramp.glb) | 8 × 1,2 × 4 | 8 | Canto esquerdo da extremidade baixa |
| [Pilar](modules/landmark_pillar/landmark_pillar.glb) | 1,2 × 6 × 1,2 | 364 | Canto sudoeste da base |
| [Beacon](modules/extraction_beacon/extraction_beacon.glb) | 2 × 3,5 × 2 | 784 | Centro da base, ao nível do chão |
| [Cais](modules/dock/dock.glb) | 10 × 1,5 × 3 | 1 816 | Canto sudoeste da base |

Nas paredes, X percorre a largura e +Z sai da face de encosto. Nas restantes
peças de canto, a geometria ocupa X/Z positivos. A rampa sobe para +Z: chega
a Y=1,2 em Z=4. O beacon é a exceção centrada, com base X/Z de −1 a +1.
O cais tem convés a Y=0,30 e postes até Y=1,50.

O contentor inclui portas, barras, dobradiças, nervuras e ferrugem. O beacon
inclui tripé de aço, escada e conjunto ótico; o nó vazio `LightMount` está em
(0; 3,2; 0). A luz e a rotação não estão implementadas: ficam para código do
jogo. As bases fechadas do beacon, cais e plataforma tornam a projeção em
planta sólida, sem vãos interpretáveis como passagens pela colisão.

## Materiais e licença

Todas as peças usam `Extraction_arena_PBR_1K`, com um atlas original de
1024 × 1024: [albedo sRGB](textures/arena_albedo.png),
[normal tangente](textures/arena_normal.png) e
[ORM linear](textures/arena_orm.png), R=1, G=roughness, B=metallic.
As imagens também estão embebidas em cada GLB. O material é opaco.

As regiões do atlas representam betão, pintura verde-azulada, aço, ferrugem,
madeira, ótica âmbar, sinalização e borracha. As UV reutilizam estas regiões
intencionalmente; não constituem um atlas exclusivo para baking. Normais e
tangentes estão exportadas. Geometria, texturas, scripts, layout e renders são
originais, sem modelos ou imagens descarregados: [licença CC0](LICENSE.txt).

## Layout

[layout.json](layout.json) é uma lista de **668 colocações**, apenas com
`module`, `x`, `z` e `rotation_deg`. `module` corresponde ao nome da peça na
tabela. Coordenadas inteiras em metros desde o canto sudoeste da ilha
256 × 256: X para leste, Z para norte. As rotações são 0/90/180/270 graus,
aplicadas ao pivô, segundo:

```text
x_mundo = x_pivô + cos(a) × x_local + sin(a) × z_local
z_mundo = z_pivô − sin(a) × x_local + cos(a) × z_local
y_mundo = y_local
```

1. Arena centrada em (128; 128), com disco de referência de 80 m de diâmetro
   e envolvente quadrada com cerca de 83,2 m livres entre paredes. Doze
   coberturas baixas, em quatro grupos, são as obstruções deliberadas dentro
   da área aberta. Quatro pilares marcam os cantos exteriores ao disco.
2. Quatro entradas cardinais em funil escalonado: as aberturas sucessivas
   medem 24, 16, 12 e **4 m** até à arena. Os funis são feitos com módulos
   ortogonais; não têm paredes diagonais contínuas.
3. Três laços quadrados fechados rodeiam a arena. Cada segmento reserva uma
   faixa contínua de **8 m**, quatro de cada lado da linha central. A área
   disponível pode ser maior; 8 m é a faixa garantida pelo teste geométrico.
4. Entrada principal a sul, cais entre Z=0 e Z=10, beacon em (128; 250),
   a norte. Plataforma em (175; 140), rampa em (175; 136), unidas sem intervalo.

O conjunto colocado soma 121 844 triângulos. Isto não é uma medição de custo
em execução. [layout_features.json](layout_features.json) descreve grupos,
rotas, entradas e metas; não acrescenta campos à lista de colocações.

## Renders e fontes

- [Vista de cima com grelha](renders/top_grid.png), 2048 × 2048: norte para
  cima, leste para a direita, grelha de 1 m, linhas principais de 8 m e
  referências de coordenadas de 32 m. Linhas turquesa marcam os laços;
  o círculo indica o diâmetro central de 80 m.
- [Vista dentro da arena](renders/arena_eye.png), 1920 × 1080, câmara a 1,70 m
  do chão.
- [Fontes dos oito módulos](source/extraction_modules.blend), uma coleção
  por peça; apenas o beacon fica visível por defeito.
- [Layout montado em Blender](source/arena_layout.blend), com as 668 peças
  importadas dos GLB e duas bases de preview. Não contém luzes ou câmaras.

As fontes Blender usam a conversão `(X, Y, Z)_GLB → (X, −Z, Y)_Blender`.
A vista superior é um diagrama cartográfico orientado a norte; a montagem
guardada conserva o referencial dos GLB. Grelha, legendas, chão, água,
iluminação e câmaras de render não fazem parte dos módulos exportados.

## Verificação

[validation.json](validation.json) reúne dimensões, triângulos, pivôs,
materiais, imagens, hashes e verificações de cada GLB. Cada subpasta de módulo
também contém o seu `validation.json`. Foram verificados o limite de 3 000
triângulos, transformações, normais/tangentes, faces não degeneradas e
componentes fechadas com volume positivo nas fontes.

A projeção preenchida de cada peça foi verificada a partir do GLB exportado.
Com rotações cardinais, os retângulos resultantes permitem medir exatamente
distâncias e sobreposições em planta:

| Resultado | Valor |
|---|---:|
| Pares de peças analisados | 222 778 |
| Sobreposições com área positiva | 0 |
| Contactos em fronteiras de montagem | 625 |
| Menor distância positiva entre peças | 3,60 m |
| Intervalos não classificados inferiores a 3 m | 0 |
| Gargantas da arena | 4 × 4,00 m |
| Laços com faixa livre contínua | 3 × 8,00 m |

- [piece_distances.csv](piece_distances.csv): todos os pares e a respetiva
  distância mínima, contacto e área sobreposta.
- [nearest_distances.csv](nearest_distances.csv): vizinho mais próximo de
  cada colocação.
- [corridor_widths.csv](corridor_widths.csv): 32 registos, incluindo 16
  segmentos de rota e 16 secções de entrada.
- [layout_validation.json](layout_validation.json): larguras medidas,
  faixas contínuas livres e conectividade numa grelha de 1 m.

Os índices dos CSV começam em zero e correspondem à ordem de `layout.json`.
Distância zero corresponde a juntas de paredes ou à união rampa/plataforma,
não a corredores. A grelha de conectividade não aplica o raio de um agente;
as faixas livres têm uma verificação contínua separada.

## Reprodução

Na raiz desta pasta, usando Blender 5.2 com as suas dependências incluídas:

```text
blender --background --factory-startup --python-exit-code 1 --python build_arena.py
blender --background --factory-startup --python-exit-code 1 --python validate_arena.py
```

O primeiro comando recria peças, texturas, layout, fontes e renders nesta
pasta. O segundo audita os GLB e as fontes e atualiza os relatórios/CSV.
`build_layout.py` também pode ser executado com Python para regenerar apenas
o layout e a sua verificação nominal; para a auditoria contra os GLB reais,
executar depois `validate_arena.py` através de Blender.

## O que fica por fazer e limites

- Integração futura fora de `.gdignore`, colisões, navegação, pontos de
  aparecimento, lógica de extração, luz/rotação do beacon e terreno/costa.
  O chão/água dos previews são apenas apresentação.
- Testar o controlador a 6 m/s. A rampa tem inclinação geométrica de 16,70°;
  percorrer os 4 m horizontais a essa velocidade demoraria 0,667 s. Não foi
  demonstrada a travessia real. Plataforma/rampa precisam de superfícies
  caminháveis; tratá-las só como volumes bloqueantes em planta impediria
  subir, apesar de cumprirem o requisito de projeção sólida.
- Testar IA, raio/altura dos agentes, colisões físicas, visibilidade,
  equilíbrio dos funis e cobertura, LOD e desempenho no motor. A conectividade
  e as distâncias em planta não substituem esses testes.
- Os elementos montados dentro de uma peça são sólidos fechados separados,
  com contactos/interseções de montagem; não foi feita união booleana nem
  auditoria geral de autointerseções. A ausência de sobreposição reportada
  refere-se às **colocações de módulos**, em planta.

Sem execução de Godot, sem alterações de integração e sem commit.
