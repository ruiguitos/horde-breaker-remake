# Ilhas reais

Constrói ilhas jogáveis a partir de dados reais e abertos. Cada sítio é uma
predefinição: `PLACES` em `fetch_data.py` diz o que descarregar e `PLACES`
em `build.gd` diz como construir.

| Sítio | Ilha no jogo | Rota |
|---|---|---|
| `berlenga`: Berlenga Grande (Portugal) | `islands/beach_berlenga.scn`, 1,5 km | Beach |
| `hashima`: Hashima ou Gunkanjima (Japão) | `islands/port_hashima.scn`, 0,5 km | Industrial Port |

Começou como spike (`spikes/real_island`, retirado; ver o histórico do git)
e passou a ferramenta quando a Berlenga entrou no jogo.

## Como correr

```bash
python tools/real_island/fetch_data.py hashima
godot --headless --path . --script res://tools/real_island/build.gd -- hashima
```

1. `fetch_data.py` descarrega uma vez para `data/<sítio>/`, que fica fora do
   git:
   - relevo dos AWS Terrain Tiles;
   - OpenStreetMap através da API Overpass, com servidores alternativos
     quando um está ocupado;
   - as texturas CC0 do Poly Haven do sítio.

   Repete os pedidos quando um servidor falha. Só usa a biblioteca padrão do
   Python.
2. `build.gd` constrói a cena e grava:
   - a cena `<bioma>_<sítio>.scn` e o terreno `<bioma>_<sítio>_data/`;
   - as texturas `<bioma>_<sítio>_ground.res`, comprimidas em
     `assets/textures/polyhaven/`;
   - a imagem da grelha `<bioma>_<sítio>_grid.png`;
   - `data/<sítio>/reach.png`, uma imagem de diagnóstico: verde é
     alcançável, amarelo são caminhos e vermelho são caminhos bloqueados.

   Acaba com código 1 se a ilha tiver problemas.

Correr outra vez **substitui** a ilha. Para mudar alguma coisa à mão, faz-o
depois de a construir, ou muda o script.

## O que faz e porquê

- **Recorte:** fica só a ilha principal com 24 m de mar à volta, num quadrado
  com uma célula de 1 m. Ao terreno junta-se fundo de mar até completar as
  regiões do Terrain3D, porque uma região importada só em parte fica a 0 m
  e aparece como uma faixa acima da água.
- **Relevo:** os dados reais têm 25 a 30 m de resolução. São suavizados até
  1 m e é-lhes acrescentado ruído:
  - na **Berlenga**, 3 m para dar textura à rocha;
  - em **Hashima**, 0,4 m, porque é betão;
  - em Hashima o chão fica a pelo menos 5 m, porque é terreno conquistado ao
    mar atrás de um paredão.

  Onde a terra encontra o mar há falésias, ou paredão, de 4 m de largura; na
  areia, uma praia suave.
- **Caminhos escavados:** é a parte mais importante. Com dados de 30 m, os
  degraus para o forte e a estrada da praia na Berlenga ficavam mais
  íngremes do que a grelha aceita (0,9 m por metro), e meia ilha ficava
  inacessível. Por isso:
  - cada caminho, com 2 m de berma, é um corredor cujo chão sobe no máximo
    0,55 m por metro;
  - onde o terreno real é mais íngreme, o caminho é cortado na encosta,
    nunca aterrado;
  - a areia da praia entra no mesmo corredor, e assim a estrada desce até
    ela.
- **Pontes:** cada vão é um tabuleiro no grupo `Bridges/`, que a grelha
  atravessa. O tabuleiro entra 2 m em cada margem, à altura do chão, porque a
  borda de cada margem é uma falésia e um tabuleiro que só continuasse a
  inclinação acabava abaixo da margem ou dentro de água.
- **Edifícios:** usam as plantas e alturas reais do OSM e ficam em
  `Buildings/`, um nó cada, a bloquear a planta.
  - **Berlenga:** paredes caiadas e telhado de quatro águas.
  - **Hashima:** betão com telhado plano e platibanda. A fachada é uma
    textura do Poly Haven com uma janela desenhada a cada 3 m, mais ou menos
    um andar. Os 66 edifícios têm a altura do OSM; o Bloco 65 tem 27 m.
- **Mais detalhe dos edifícios em Hashima:** acrescentado na revisão com o
  Codex.
  - Os blocos de habitação (`号棟`) têm galerias abertas a cada andar, como
    as reais. Ficam em `Decor/` para não fecharem as vielas na grelha.
  - O `roof:shape` do OSM sobrepõe-se ao estilo do sítio: o Poço 4 tem
    telhado inclinado.
  - O farol é uma só torre, com os 10 m do OSM.
  - A orientação das paredes vem do sentido do polígono, para que as plantas
    em L e em U fiquem com as paredes viradas para fora.
- **Praças:** os passeios com `area=yes` no OSM (o percurso turístico de
  Hashima) são pavimento por inteiro, e não um caminho ao longo do contorno.
- **Gargalos e arenas** (`chokes`, `arenas` no preset): são marcadores
  `Choke_*` e `Arena_*`, com as posições que o Codex leu na disposição real.
  O construtor fecha cada gargalo à vez e diz se algum objetivo fica
  inacessível. Em Hashima só o cais corta o caminho para o barco: é o funil
  do desembarque.
- **Paredão:** em Hashima há um muro de 1,7 m ao longo do paredão do OSM.
  É só decoração, porque o desnível atrás dele já bloqueia.
- **Espalhados:** cada sítio tem a sua lista em `PLACES`.
  - **Berlenga:**
    - 800 rochas nas bordas das falésias, que bloqueiam;
    - 180 mil tufos de erva por toda a ilha, que não bloqueiam e só se
      desenham perto da câmara.
  - **Hashima:**
    - entulho junto aos prédios, que bloqueia;
    - erva, fetos e plantas só nas zonas verdes do OSM.
- **Marcadores:**
  - **Barco:**
    - **Berlenga:** na areia do Carreiro do Mosteiro.
    - **Hashima:** junto ao cais Dolphin, onde atracam os barcos de
      turistas.
  - **Geradores:** em sítios reais, com 4 m livres à volta.
    - **Berlenga:** no Bairro dos Pescadores, junto ao farol e no ilhéu do
      forte.
    - **Hashima:** no poço 2 da mina (第二坑捲), no Bloco 65 e no poço 4
      (四坑上家).
  - **Caixas:** nas pontas da ilha, o mais longe possível de tudo.

## Medições

Ambiente: Windows 11, Godot 4.7.2, AMD Ryzen 5 5600, NVIDIA RTX 5060.

| O quê | Berlenga | Hashima |
|---|---|---|
| Construir a ilha (headless) | cerca de 18 s | cerca de 5 s |
| Grelha | 1466 m, 2,1 M células | 495 m, 245 mil células |
| Converter para a grelha (`build_map`) | 0,75 a 1,2 s | cerca de 0,1 s |
| Células transitáveis / alcançáveis do desembarque | 761 mil / 727 mil | 50,9 mil / 50,9 mil (36,7 mil / 34,6 mil quando os edifícios bloqueavam a caixa) |
| Rota Activate pela grelha (troços) | cerca de 2,4 km: 229 + 417 + 704 + 1028 m | cerca de 0,9 km: 135 + 393 + 159 + 227 m |
| Passo da simulação (bot) | 1,1 a 1,3 ms em média, pior 8 ms | 1,6 a 1,8 ms em média (até 150 vivos), pior 8,5 ms |
| Frame em jogo a 1920 × 1080 (Ultra, horda a chegar) | 4,6 a 6,2 ms | 3,4 a 4,3 ms |
| Bot invencível, Threat 2 | Activate 6 min, Defend 4,5 min, Rescue 3,5 min | Activate 2,5 min, Defend 2,5 min, Rescue 1,5 min |

## Limites

- O relevo fino (rochedos, grutas, escadarias) é inventado. Dados LiDAR de
  1 a 2 m dariam outro resultado.
- **Berlenga:**
  - a altura dos edifícios é estimada, porque o OSM quase não a tem;
  - o farol é uma caixa e um cilindro;
  - o forte não está mapeado como edifício: o gerador marca o sítio.
- **Hashima:**
  - os prédios são caixas com janelas pintadas, sem varandas nem interiores;
  - as ruas estreitas entre prédios dependem do traçado do OSM.
- As falésias vistas de perto mostram os veios verticais da textura de rocha.

## Licenças

- **OpenStreetMap:** licença ODbL, aceite pelo utilizador a 2026-10-07. A
  atribuição é "© OpenStreetMap contributors". Quem partilhar a base de
  dados derivada (a costa, os caminhos e os edifícios das ilhas) tem de a
  partilhar com a mesma licença. Ver `assets/LICENSES.md`.
- **AWS Terrain Tiles:** dados abertos com atribuição às fontes (SRTM,
  EU-DEM e outras; ver "Mapzen terrain tiles attribution").
- **Poly Haven:** CC0.
