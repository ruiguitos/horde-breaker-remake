# Spike: ilha real (Berlenga Grande)

**Teste**, pedido pelo utilizador: como fica uma ilha baseada num sítio real,
com dados abertos, e quanto custa. Não toca no jogo (`game/`) nem noutros
spikes. Para voltar atrás chega reverter o commit e apagar esta pasta.

## O que faz

1. `fetch_data.py` descarrega para `data/` (fora do git):
   - **relevo:** AWS Terrain Tiles (formato "terrarium", zoom 15, 3,7 m por
     píxel; os dados de origem têm 25 a 30 m);
   - **OpenStreetMap** (Overpass API): linha de costa, caminhos, escadas,
     pontes, edifícios, farol, cais, praias;
   - **4 texturas CC0 do Poly Haven** (1k): erva com rocha, falésia, costa e
     gravilha dos caminhos.
2. `build.gd` constrói `out/real_island.scn` (também fora do git):
   - relevo real suavizado (redimensionamento cúbico), com ruído fino para
     dar textura à rocha;
   - a costa exata do OSM, com falésias onde encontra o mar e declives suaves
     nas praias mapeadas;
   - texturas por vértice no Terrain3D, conforme o declive, a distância à
     costa e os caminhos; projeção lateral nas falésias;
   - caminhos de gravilha (só textura), escadas e estrada de betão (malhas),
     ponte de pedra, edifícios a partir das plantas reais (paredes caiadas,
     telhado de telha), farol e cais;
   - 196 mil tufos de erva e arbustos e 900 rochas, em blocos de 128 m que só
     se desenham perto da câmara;
   - mar, céu do Sky3D às 15h e, na câmara, o color grading.
3. `view.gd` tira fotografias de 6 pontos de vista (`out/shots/`) e mede o
   tempo por frame, com o vsync desligado, numa volta lenta sobre a ilha.

## Como correr (Windows, com GPU)

```bash
python spikes/real_island/fetch_data.py
godot --headless --path . --script res://spikes/real_island/build.gd
godot --path . --resolution 1920x1080 --script res://spikes/real_island/view.gd
```

Para passear: abre `spikes/real_island/out/real_island.scn` no editor e
carrega em **F6**. Controlos: **WASD** para andar, **Q/E** para descer e
subir, **botão direito** para olhar, **Shift** para ir mais depressa e
**roda do rato** para mudar a velocidade.

Teste: `godot --headless --path . --script res://spikes/real_island/tests/test_real_island.gd`
(passa sem fazer nada se ainda não houver dados).

## Medições

Ambiente: Windows 11, Godot 4.7.2, AMD Ryzen 5 5600, NVIDIA RTX 5060.
Mapa de 2048 × 2048 m (1 vértice por metro), Forward+.

| O quê | Resultado |
|---|---|
| Construir a ilha (headless) | ~14 s: costa 3 s, relevo 2 s, terreno e texturas 7 s, vegetação 1 s |
| Carregar a cena | 0,3 a 1,7 s |
| Frame a 1920 × 1080 (volta a 600 m) | **3,4 ms em média (~294 fps)**, percentil 95 de 4,0 ms |
| Frame a 1280 × 720 | 2,4 ms (~419 fps) |
| Grelha da horda (células de 1 m) | 4,2 M de células, 776 mil transitáveis, 730 mil alcançáveis |
| Uma busca completa do campo de fluxo (GDScript) | **~0,5 s** |

Erro meu durante o teste: na primeira versão toda a vegetação se desenhava
em toda a ilha e o frame custava 28,5 ms (35 fps a 720p). Os blocos com
distância de desenho resolveram isso.

## Limites

- **Relevo:** os dados de origem têm 25 a 30 m. O planalto e as falésias
  estão no sítio certo, mas os pormenores (rochedos, grutas, a escadaria do
  bairro) são inventados. Dados LiDAR de 1 a 2 m dariam outro resultado.
- **Edifícios:** a forma em planta é real, a altura é estimada (o OSM quase
  não a tem). O farol é uma caixa e um cilindro, não o modelo real. O forte
  de São João Baptista não está mapeado como edifício.
- **Não é jogável:** a cena não é uma `HandmadeIsland` e não tem marcadores.
  E a horda, com 0,5 s por busca, teria de ser calculada por zonas ou em
  várias frames.
- As medições são de uma só máquina e de uma volta de câmara, sem horda,
  jogador nem efeitos.

## Licenças

- **OpenStreetMap:** licença **ODbL** (atribuição: "© OpenStreetMap
  contributors"; quem partilha a base de dados derivada tem de a partilhar
  com a mesma licença). Não está na lista de licenças do `CLAUDE.md`, por
  isso os dados e a cena gerada **não vão para o git**.
- **AWS Terrain Tiles:** dados abertos com atribuição às fontes (SRTM,
  EU-DEM e outras; ver "Mapzen terrain tiles attribution").
- **Poly Haven:** CC0. Estão só em `data/`; se ficarem no jogo, passam para
  `assets/` e entram em `assets/LICENSES.md`.

## Decisões propostas (o utilizador decide)

1. Aceitar ou recusar a ODbL para os dados do OSM (atribuição nos créditos).
2. Se gostares: transformar a cena numa `HandmadeIsland` jogável (marcadores,
   grelha) e dividir o campo de fluxo por zonas antes de usar mapas de 1 km
   ou mais.
3. Texturas reais (Poly Haven) também nas ilhas feitas à mão atuais: é o que
   mais muda o aspeto, mesmo sem dados reais.
