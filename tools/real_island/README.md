# Ilha real: Berlenga Grande

Constrói a ilha jogável `game/world/handmade/islands/beach_berlenga.scn` a
partir de dados reais e abertos. Começou como spike (`spikes/real_island`,
retirado; ver o histórico do git) e passou a ferramenta quando a ilha entrou
no jogo.

## Como correr

```bash
python tools/real_island/fetch_data.py
godot --headless --path . --script res://tools/real_island/build.gd
```

1. `fetch_data.py` descarrega uma vez para `data/`, que fica fora do git:
   - relevo dos AWS Terrain Tiles;
   - OpenStreetMap através da API Overpass;
   - 4 texturas CC0 do Poly Haven.

   Só usa a biblioteca padrão do Python.
2. `build.gd` constrói a cena e grava:
   - a cena `beach_berlenga.scn` e o terreno `beach_berlenga_data/`;
   - as texturas do chão `beach_berlenga_ground.res`, comprimidas em
     `assets/textures/polyhaven/`;
   - a imagem da grelha `beach_berlenga_grid.png`;
   - `data/reach.png`, uma imagem de diagnóstico: verde é alcançável,
     amarelo são caminhos e vermelho são caminhos bloqueados.

   Acaba com código 1 se a ilha tiver problemas.

Correr outra vez **substitui** a ilha. Para mudar alguma coisa à mão, faz-o
depois de a construir, ou muda o script.

## O que faz e porquê

- **Recorte:** fica só a Berlenga Grande e 24 m de mar à volta, num quadrado
  de 1466 m, com uma célula de 1 m por metro. Os ilhéus fora do quadrado são
  descartados.
- **Relevo:** os dados reais têm 25 a 30 m de resolução. São suavizados até
  1 m e é-lhes acrescentado ruído fino para a rocha. Onde a terra encontra o
  mar há falésias de 4 m de largura; na areia, uma praia suave.
- **Caminhos escavados:** é a parte mais importante. Com dados de 30 m, os
  degraus para o forte e a estrada da praia ficavam mais íngremes do que a
  grelha aceita (0,9 m por metro), e meia ilha ficava inacessível. Por isso
  cada caminho, com 2 m de berma, é um corredor cujo chão sobe no máximo
  0,55 m por metro. Onde o terreno real é mais íngreme, o caminho é cortado
  na encosta, nunca aterrado. A areia da praia entra no mesmo corredor, e
  assim a estrada desce até ela.
- **Pontes:** cada vão é um tabuleiro no grupo `Bridges/`, que a grelha
  atravessa. O tabuleiro entra 2 m em cada margem, à altura do chão, porque a
  borda de cada margem é uma falésia e um tabuleiro que só continuasse a
  inclinação acabava abaixo da margem ou dentro de água.
- **Objetos:**
  - os 22 edifícios reais estão em `Buildings/`, um nó cada, e bloqueiam a
    sua planta;
  - o farol também está em `Buildings/`;
  - 800 rochas nas bordas das falésias, em `Rocks/`, com um nó `Scatter` por
    bloco de 128 m; cada cópia bloqueia;
  - 180 mil tufos de erva em `Decor/`, que não bloqueiam e só se desenham
    perto da câmara.
- **Marcadores:**
  - **Barco:** na areia do Carreiro do Mosteiro.
  - **Geradores:** no Bairro dos Pescadores, junto ao farol e no ilhéu do
    forte de São João Baptista, ao fim do Caminho do Forte. Cada gerador
    tem 4 m livres à volta.
  - **Caixas:** 6, nas pontas da ilha, o mais longe possível de tudo.

## Medições

Ambiente: Windows 11, Godot 4.7.2, AMD Ryzen 5 5600, NVIDIA RTX 5060.

| O quê | Resultado |
|---|---|
| Construir a ilha (headless) | cerca de 18 s |
| Converter a cena para a grelha (`build_map`, 2,1 M células) | 0,75 a 1,2 s |
| Células transitáveis / alcançáveis do desembarque | 760 mil / 726 mil |
| Rota Activate pela grelha (desembarque, bairro, farol, forte, barco) | cerca de 2,4 km: 233 + 426 + 699 + 1028 m |
| Passo da simulação com a horda (bot, 43 a 47 vivos) | 1,1 a 1,3 ms em média, pior 8 ms |
| Frame em jogo a 1920 × 1080 (Ultra, horda a chegar) | 4,6 a 6,2 ms (160 a 215 fps) |
| Bot invencível, Threat 2 | Activate 6 min, Defend 4,5 min, Rescue 3,5 min |

## Limites

- O relevo fino (rochedos, grutas, a escadaria do bairro) é inventado. Dados
  LiDAR de 1 a 2 m dariam outro resultado.
- A altura dos edifícios é estimada, porque o OSM quase não a tem. O farol é
  uma caixa e um cilindro, e o forte não está mapeado como edifício: o
  gerador marca o sítio.
- As falésias vistas de perto mostram os veios verticais da textura de rocha.

## Licenças

- **OpenStreetMap:** licença ODbL, aceite pelo utilizador a 2026-10-07. A
  atribuição é "© OpenStreetMap contributors". Quem partilhar a base de
  dados derivada (a costa, os caminhos e os edifícios da ilha) tem de a
  partilhar com a mesma licença. Ver `assets/LICENSES.md`.
- **AWS Terrain Tiles:** dados abertos com atribuição às fontes (SRTM,
  EU-DEM e outras; ver "Mapzen terrain tiles attribution").
- **Poly Haven:** CC0.
