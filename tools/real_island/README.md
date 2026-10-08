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

Opções para testar sem mexer na ilha do jogo:
- `--out-dir res://tools/real_island/test_out/<nome>` grava numa pasta de
  teste, fora do git. O construtor recusa qualquer outra pasta.
- `--kits houses`, `--kits paths` ou `--kits none` constrói só uma parte dos
  kits de detalhe (ver abaixo).

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
- **Dois níveis em Hashima:** feito na terceira ronda, com o Codex.
  - O aterro abaixo de 17 m fica mais plano e o rochedo acima mantém a
    altura.
  - Entre os dois há uma faixa íngreme que a grelha não sobe. Só se
    atravessa pelas escadas e caminhos escavados, que são gargalos a sério.
  - Custo: o troço entre o Bloco 65 e o Poço 4 passou de 159 m para 647 m,
    porque a faixa a leste do rochedo é estreita.
- **Marcos de Hashima:**
  - **Santuário (端島神社):** salão de madeira com telhado de duas águas e um
    torii. Fica na clareira livre mais próxima do ponto do OSM, que está
    encostado ao Bloco 1. Bloqueiam o salão e os pilares; as vigas do torii
    são só decoração.
  - **Tapete transportador (ベルトコンベアー):** passadeira a 5 m de altura
    sobre pilares. Só os pilares bloqueiam.
- **Kits de detalhe (Berlenga):** feitos em paralelo por subagentes Claude
  e revistos pelo Codex. Cada kit é um ficheiro próprio, para os subagentes
  poderem trabalhar sem mexer no mesmo código.
  - **Primeira ronda:** só no retângulo `detail_area` do desembarque e do
    Bairro dos Pescadores, como teste.
  - **Segunda ronda:** a ilha toda, mais o farol e o forte.
  - **`village_houses.gd`, casas:**
    - paredes caiadas com barra pintada, azul ou ocre, e embasamento de
      pedra; beiral a cerca de 3,1 m;
    - telhado de duas águas nas plantas alongadas e de quatro águas nas
      compactas, com telha que segue cada água, cumeeira, beiral saliente e
      chaminé;
    - porta virada para o caminho mais próximo e janelas com moldura e
      peitoril, só nas paredes livres;
    - cores escolhidas a partir do id do OSM, por isso são sempre as mesmas;
    - plantas em L e em U divididas em alas, cada uma com o seu telhado de
      duas águas, que se encontram numa calha;
    - casas dos faroleiros com a mesma pintura; o edifício do ilhéu do forte
      em pedra, com telhado plano atrás de uma platibanda.

    O corpo da casa fica em `Buildings/` e bloqueia só a planta. Tudo o que
    sai dela (beirais, molduras, degraus da porta) fica em `Decor/`.
  - **`village_paths.gd`, caminhos:**
    - degraus a sério, com cobertor e espelho de 15 a 18 cm, que seguem o
      perfil escavado;
    - corrimão onde o OSM diz `handrail=yes`;
    - a estrada de betão com juntas a cada 3,5 m e bordas gastas;
    - lancis só onde o terreno cai ao lado;
    - pedras soltas nos trilhos de terra.

    É tudo decoração: o jogador e a horda andam no terreno.
    - **Curvas apertadas** (mais de 2 rad): não têm degraus, e o chão
      escavado serve de patamar.
    - **Lanços soltos:** os de menos de 1,2 m deixam-se de fora.
    - **Pontes:** os caminhos acabam onde começa o tabuleiro de uma ponte.
  - **`landmarks.gd`, farol e forte:**
    - **Farol:** torre quadrada caiada com 29 m (a altura do OSM), que
      estreita de 4,6 para 3,9 m. Tem cunhais de pedra, janelas estreitas,
      varanda com gradeamento e lanterna com cúpula vermelha. Fica dentro da
      ala norte da casa dos faroleiros.
    - **Forte de São João Baptista:** é aproximado, porque o OSM não tem a
      planta. As muralhas seguem a costa do ilhéu 2,5 m para dentro, em 9
      faces, com talude, adarve, parapeito com 21 canhoneiras e guaritas
      nos cantos. A porta, de 3,6 m, fica alinhada com a última ponte.
    - **Bloqueio:** só bloqueiam as faixas das muralhas; a porta e o pátio
      ficam abertos.
    - **Gerador 3:** fica no pátio, por isso o troço até ele passa pela
      porta (mais 28 m).
  - **Espalhados e espaço reservado:** um kit pode reservar uma área (as
    muralhas, o pátio), e o construtor tira de lá as rochas e a erva. Cada
    tentativa de colocação sorteia sempre os mesmos números, aceite ou não.
    Assim, reservar uma área não muda de sítio as rochas no resto da ilha.
  - **Verificação** (`check_kits.gd`, contra uma construção com
    `--kits none`):
    - os caminhos não mudam nenhuma célula;
    - as casas só abrem as 78 células do pátio da casa em U do farol, que o
      telhado antigo, em leque, tapava por engano;
    - o forte bloqueia as faixas das muralhas;
    - o percurso passa a ter 229, 414, 737 e 1056 m.
  - **Limites:**
    - não se usa o `step_count` do OSM: os 63 degraus de `441503017` dariam
      espelhos de 4 cm no relevo escavado;
    - nas escadas mais íngremes os lanços parecem escadotes;
    - a pedra do forte é clara e lisa, e puxa ligeiramente para o rosa;
    - as portas e janelas são painéis sobre a parede, sem recorte.
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
| Rota Activate pela grelha (troços) | cerca de 2,4 km: 229 + 414 + 737 + 1056 m | cerca de 1,3 km: 142 + 642 + 281 + 221 m |
| Passo da simulação (bot) | 1,1 a 1,3 ms em média, pior 8 ms | 1,6 a 1,8 ms em média (até 150 vivos), pior 8,5 ms |
| Frame em jogo a 1920 × 1080 (Ultra, horda a chegar) | 4,6 a 6,2 ms | 3,4 a 4,3 ms |
| Bot invencível, Threat 2 | Activate 6 min, Defend 4,5 min, Rescue 3,5 min | Activate 2,5 min, Defend 2,5 min, Rescue 1,5 min |

## Limites

- O relevo fino (rochedos, grutas, escadarias) é inventado. Dados LiDAR de
  1 a 2 m dariam outro resultado.
- **Berlenga:**
  - a altura dos edifícios é estimada, porque o OSM quase não a tem;
  - o forte é uma aproximação: segue a costa do ilhéu, não uma planta real.
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
