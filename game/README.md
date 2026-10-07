# Vertical slice — Dawn Beach

Grey-box jogável (só primitivas Godot): uma run de **3 ilhas** (layout
diferente em cada uma), 1 classe (Recruit), 3 armas, 4 inimigos, missão
"Activate 3" e regresso ao barco. Entre ilhas, o barco oferece "escolhe 1 de 3".
O Intel ganho fica gravado no perfil, mesmo quando se morre.

## Como correr no Godot (Windows)

1. Instalar o **Godot 4.7 stable** (versão "Standard", não ".NET"), de
   godotengine.org. É um `.exe` sem instalação.
2. Ter o repositório no PC: `git clone https://github.com/ruiguitos/horde-breaker-remake`
   (ou, se já existe, `git pull` na pasta).
3. Abrir o Godot → **Import** → escolher o ficheiro `project.godot` na raiz
   do repositório → **Import & Edit**. Na primeira vez demora uns segundos a
   importar.
4. Carregar em **F5** (ou no ▶ do canto superior direito). A cena principal
   é `game/main.tscn`.

Para correr só um spike: abrir a cena (`spikes/<nome>/*.tscn`) e **F6**.

## Controlos

| Ação | Teclado/rato | Comando |
|---|---|---|
| Mover (relativo à câmara em 3.ª pessoa) | WASD / setas | stick esquerdo |
| Olhar / apontar (o auto-fire dispara para onde olhas) | rato | stick direito |
| Câmara: 3.ª pessoa ↔ vista de cima | V | Back / Select |
| Breaker (investida) | Espaço ou botão direito | A ou RB |
| Sprint (não dispara enquanto corre) | Shift | L3 (clicar stick esquerdo) |
| Granada (lança para o rato) | G ou botão do meio | LB |
| Trocar arma | 1–5 | D-pad ← ↑ →, ↓ roda |
| Escolher carta | 1 / 2 / 3 ou clique | X / Y / B |
| Continuar no fim da ilha | Enter / R | A / Start |
| Pausa (Q na pausa abandona) | Esc | Start |
| Painel de debug | F3 | — |
| Ecrã inteiro | F11 | — |

**Settings** (no título e na pausa), em três separadores; tudo se aplica na
hora e fica gravado no perfil (`core/graphics_settings.gd` aplica ecrã e
gráficos):
- **Display:** modo de janela (janela, ecrã inteiro sem bordas, ecrã inteiro
  exclusivo), resolução (em janela), VSync e limite de FPS.
  Também tem **HUD size** (60–100 %), que encolhe os painéis do HUD e os
  mantém encostados aos cantos.
- **Graphics:** preset Low / Medium / High / Ultra, que muda de facto o jogo:
  - **Low:** sem sombras, bloom nem SSAO, e menos detalhe ao longe.
  - **Medium:** sombras do sol com 2 divisões e bloom.
  - **High:** sombras suaves com 4 divisões, bloom e SSAO.
  - **Ultra:** sombras mais nítidas e ao longe, e luz indireta (SSIL).

  Também tem a escala do render 3D (50–100 %: menos píxeis 3D, mais FPS) e o
  anti-aliasing (FXAA, MSAA 2x/4x, TAA).
- **Controls:** a tecla e o botão do comando de cada ação, com ícones
  (G.U.I.D.E), **REBIND** para trocar a tecla (Esc cancela), sensibilidade
  do rato e "Reset default keys".
- **Audio:** volumes Master, Sound effects e Music, cada um com slider e campo
  editável em percentagem. Os sons vão para os buses SFX e Music.

## Como se joga

- A arma **dispara sozinha** contra um inimigo dentro de um cone de 50° à tua
  frente. Ganha o que tiver menor "distância + 0,4 m por grau de desvio",
  por isso **virar-te para um inimigo torna-o o alvo**, mesmo que haja outros
  mais perto de lado. Exceção: quem estiver a menos de 2,5 m é sempre
  alvejado primeiro. Se o alvo estiver quase exatamente onde olhas (±9°),
  é **headshot** (dano ×2,5). Ou seja: mira-se com o corpo. A **mira laser**
  liga a arma ao alvo atual e fica vermelha quando o próximo tiro é headshot.
- **Breaker**: investida de 5 m que empurra e atordoa tudo no caminho, dá dano
  no fim e solta-te de um Grabber. Cooldown de 6 s (barra amarela).
- Inimigos:
  - **Walker** (verde): o comum.
  - **Runner** (amarelo): rápido e frágil.
  - **Brute** (vermelho escuro, grande): blindado à frente (−75 % de dano);
    acerta-lhe de lado ou por trás, ou com o breaker.
  - **Bloater** (verde-oliva, gordo e lento): explode ao morrer (3,5 m) e
    fere toda a gente, também os zombies. Mata-o no meio da horda.
  - **Screamer** (amarelo-pálido): foge de ti. Se te vir durante 3 s, grita e
    o diretor manda um pico de horda. O HUD avisa: mata-o primeiro.
  - **Grabber** (roxo): agarra-te e não te deixa andar até o matares ou usares
    o breaker.
- Mortes largam **orbes de XP** (azuis). Ao subir de nível o jogo pausa e
  escolhes 1 de 3 cartas. A maioria muda comportamentos (breaker com onda de
  choque, ricochete, headshots que explodem).
- Armas: Assault Rifle (infinita), Shotgun e Heavy Pistol (munição limitada,
  atravessam inimigos). Cada gerador ligado repõe metade da munição.
- **Missão**: segue o marcador amarelo até cada gerador e fica dentro do anel
  8 s. Ao começares, a horda entra em pico. Com os 3 ligados, volta ao barco
  (anel verde).
- **Caixas de mantimentos** (azul-claro, também no minimapa): 4 por ilha,
  longe do caminho. Ficas 1,5 s junto de uma e recebes cura (+30), munição,
  XP ou +10 de Intel. São desvios opcionais: vale a pena o risco?
- O **diretor** alterna calma → crescer → pico (ver F3). O máximo é de 150
  inimigos vivos.

## Briefing no barco

Depois de escolher a rota, o Director Hale faz o briefing (Dialogue Manager,
`data/dialogue/briefing.dialogue`). Podes perguntar pela ilha ou pedir
conselhos, ou aceitar **hazard pay**: +25 % de Intel e +25 % de inimigos, só
na ilha seguinte.

## HUD tático

Painéis escuros, títulos condensados e apontamentos âmbar, a combinar com os
menus. O centro do ecrã fica disponível para o combate.

- **Em baixo**: vida numérica e XP à esquerda; Breaker, habilidade da classe e
  estamina ao centro; arma e munição à direita. Recargas mostram segundos ou
  `READY`; correr mostra `SPRINTING` e uma arma vazia mostra `NO AMMO`.
- **Em cima**: objetivo, progresso e modificador da rota; vida do sobrevivente
  durante a escolta ou barra do Behemoth com indicação da fase 2. Minimapa à
  direita, com grelha discreta e barco em forma de losango âmbar.
- **Avisos**: pouca vida, Grabber, Screamer, perda do sobrevivente e War Cry
  mantêm-se visíveis. As legendas de Hale aparecem acima da vida. Dano
  direcional, números de dano, cartas e pausa mantêm o funcionamento anterior.
- **Controlos**: os atalhos mudam com o último dispositivo usado (teclado ou
  comando). F3 mostra o diagnóstico, escondido por omissão. Os painéis de
  combate deixam passar o rato para a mira.

`tests/test_hud.gd` verifica os estados e o encaixe em 960×540, 1152×648 e
1920×1080. `tools/dev/hud_preview.gd` captura o HUD real, com perfil temporário
em memória, nos estados `normal`, `danger`, `boss` ou `third_person`:

```bash
godot --path . --resolution 1152x648 --windowed --script res://tools/dev/hud_preview.gd -- <caminho-absoluto.png> normal
```

## Mapas (ilhas)

Cada ilha é gerada a partir de uma *seed*, sem cenas feitas à mão.

| Ficheiro | O que faz |
|---|---|
| `world/island_map.gd` | **Geração do mapa**: costa, cais, geradores, caches, edifícios por bioma, árvores, rochas, lava. `SIZE` é o tamanho |
| `horde/flow_field.gd` | Grelha de navegação (células livres/bloqueadas) e caminhos da horda |
| `world/island_run.gd` | Regras: onde o jogador começa, missões, spawns (usa o mapa) |
| `world/island.gd` | Constrói o mundo 3D a partir do mapa (edifícios, props, mar, luz, câmara) |
| `world/island_terrain.gd` | Chão com Terrain3D (costa em declive, cores) |
| `world/island_roads.gd` | Estradas com o Road Generator e candeeiros |
| `world/nature_kit.gd` | Árvores, rochas e vegetação da Quaternius por bioma |
| `world/director.gd` | Quantos inimigos aparecem e quando |
| `ui/minimap.gd` | Minimapa |
| `data/biomes/*.tres` | Cores, nevoeiro e palmeiras de cada bioma (YARD) |

**Tamanho:** as ilhas têm 256 × 256 m (uma região do Terrain3D). Nas ilhas
geradas o tamanho é `const SIZE` em `world/island_map.gd`.
- Crescem com o tamanho: a costa, a posição do cais e dos geradores, e o
  número de edifícios, árvores e rochas (proporcional à área). A densidade
  mantém-se.
- Medido na cloud, a 320 m a geração passa de ~80 ms para ~0,4 s, a maior
  parte nas estradas. Para mapas maiores, gerar numa thread durante o
  barco evita a pausa.
- O número de inimigos vivos não muda (`MAX_ALIVE` em `game_data.gd`). Num
  mapa maior parecem menos: sobe-o se quiseres a mesma pressão.

**Noclip (teste):** **Mouse 4 / Mouse 5** liga/desliga. Atravessas paredes e
mar, andas 3× mais depressa (6× a correr) e não levas dano. **Espaço** sobe
e **Ctrl** desce (até 120 m; Shift sobe/desce 3× mais rápido). Ao desligar
o noclip, desces suavemente até ao chão.

## Ilhas feitas à mão

As quatro ilhas da rota já são feitas à mão, em
`game/world/handmade/islands/` (256 m cada). Só o vulcão (3.ª ilha, boss)
continua gerado.

Cada ilha tem **gargalos** (passagens estreitas onde a horda se afunila:
bom para o Breaker e a caçadeira), **arenas** (espaços abertos onde podes ser
cercado) e **duas rotas para cada objetivo**: uma curta pelo gargalo, outra
mais longa e segura. Os marcadores `Choke_*` e `Arena_*` na cena mostram
onde estão (não mudam o jogo).

| Ilha | Gargalos (rota curta) | Rota longa | Arenas |
|---|---|---|---|
| `beach_01` | Ponte estreita sobre o riacho; brecha nas dunas a este; rampa sul do farol | Vau largo a oeste pela aldeia; contornar as dunas pelo norte; rampa este do farol | Encruzilhada; praça da aldeia |
| `town_01` | Ponte do meio sobre o canal; portão da frente do pátio murado; escadas da igreja; becos de 3 m entre casas | Pontes laterais; portão de trás do pátio; rampa sudoeste da igreja | Praça sul; mercado a norte |
| `jungle_01` | Ponte de corda sobre o rio; rampa sul do templo | Vaus a oeste e a este; rampa oeste do templo | Clareira sul; topo do templo |
| `port_01` | Ponte basculante sobre a doca; brechas entre armazéns; corredores estreitos dos contentores | Contornar a doca; contornar os armazéns; avenida central | Cais sul; cruzamento central |

O script verifica as duas rotas: fecha cada gargalo à vez e confirma que o
barco, os geradores e as caches continuam acessíveis.

### Berlenga Grande (ilha real)

A rota Beach sorteia por seed entre a `beach_01` e
`islands/beach_berlenga.scn`. A Berlenga é a ilha real, com 1,5 km, feita a
partir de dados abertos: relevo, a costa e os caminhos do OpenStreetMap e
texturas do Poly Haven.
- **Missão:**
  - desembarcas na praia do Carreiro do Mosteiro;
  - os geradores estão no Bairro dos Pescadores, junto ao farol e no ilhéu do
    forte, ao fim do Caminho do Forte, com degraus e pontes;
  - há 6 caixas nas pontas da ilha.
- **Duração:** a rota completa tem cerca de 2,4 km e o bot leva 6 minutos.
- **Como foi construída:** por `tools/real_island/build.gd`; o como e o
  porquê estão no `README.md` dessa pasta. Para a testar já, arrasta-a para
  **Handmade Scene** em `world/island.tscn` e carrega em **F6**.
- **Licença:** os dados do mapa têm licença ODbL, "© OpenStreetMap
  contributors" (ver `assets/LICENSES.md`).

### Hashima (ilha real)

A rota Industrial Port sorteia por seed entre a `port_01` e
`islands/port_hashima.scn`. É Hashima (Gunkanjima), a ilha mineira
abandonada do Japão, com 0,5 km.
- **A ilha:** os 66 edifícios de betão com a altura real, o paredão e o
  rochedo central.
- **Desembarque:** no cais Dolphin.
- **Geradores:** no poço 2 da mina, no Bloco 65 (o maior prédio) e no poço 4.
- **Construção:** foi feita pela mesma ferramenta da Berlenga
  (`tools/real_island/`, sítio `hashima`).

**Mapas grandes:** com 2 milhões de células, recalcular os caminhos da
horda para a ilha toda demora 0,5 s. Por isso:
- **`horde_radius`:** este campo do `HandmadeIsland` (120 na Berlenga)
  limita o cálculo a uma zona à volta do jogador;
- **inimigos deixados para trás:** os que ficam fora dessa zona e a mais de
  45 m são retirados, e o diretor faz aparecer outros perto de ti;
- **minimapa:** mostra uma janela de 320 m que acompanha o jogador. Os
  objetivos fora da janela ficam encostados à borda, a indicar a direção.

Em todas as ilhas, quando o jogador muda de célula, o cálculo em curso acaba
antes de começar o seguinte. Antes recomeçava do zero, por isso enquanto o
jogador corria nunca chegava a acabar.

O script também faz uma **auditoria**: nenhum objeto na água, num rio, numa
estrada, numa ponte, numa praça ou numa falésia; nenhum edifício em chão
irregular ou a menos de 10 m da costa; nenhuma estrada na água ou numa
falésia. A colocação e a auditoria usam a mesma regra (`_spot_problem`), por
isso o que o script põe passa sempre. Se houver um problema, o script acaba
com código 1.

**Estradas:** são malhas próprias (`Decor/Roads`), com bordas nítidas e
coladas ao terreno: asfalto com passeios e risco ao centro na cidade,
asfalto no porto, terra batida na praia e na selva. As curvas são
arredondadas e as estradas passam a direito sobre as pontes. Onde duas se
juntam, a mais recente pára 1 m dentro da outra; não se usa união de
polígonos porque as ruas da cidade formam quarteirões (buracos) e o Godot não
triangula polígonos com buracos.

**Pontes:** o rio passa por baixo (água a sério). O tabuleiro está no grupo
`Bridges/`: as células por baixo dele andam-se à altura do tabuleiro, que
sobe ou desce de uma margem à outra.

Foram construídas por `tools/dev/build_islands.gd`, que esculpe o Terrain3D e
coloca tudo a partir de um desenho escrito por bioma. Depois disso são cenas
normais: podes abri-las e mexer à mão. Atenção: correr o script outra vez
**apaga as tuas alterações** nessas ilhas.


Em vez do gerador automático, podes construir uma ilha no editor. O jogo
continua a correr numa grelha 2D (1 célula = 1 m), por isso
`HandmadeIsland.build_map()` (`world/handmade/handmade_island.gd`) lê a cena
e converte-a para a grelha.

O jogador, os zombies, os objetivos e a câmara seguem a altura do terreno
(`IslandMap.ground_y()`); a simulação continua plana na grelha, a altura é
só visual. A câmara de 3.ª pessoa encurta para não entrar nas colinas.

### Jogar uma ilha tua

- **Testar já:** abre `world/island.tscn`, seleciona o nó raiz e arrasta a
  tua cena para **Handmade Scene** no inspetor. Depois carrega em **F6**.
  Lembra-te de limpar o campo antes de fazer push.
- **Na run:** grava a cena em `game/world/handmade/islands/` com o nome
  `<bioma>_<qualquer coisa>.tscn` ou `.scn` (por exemplo `beach_01.tscn`; biomas:
  `beach`, `town`, `jungle`, `port`). Quando a rota calhar nesse bioma, a
  ilha usada é a tua em vez da gerada. Se houver várias do mesmo bioma, é
  escolhida uma por seed.
- **Problemas:** os problemas do *Check map* aparecem também como avisos
  (Debugger → Errors) quando a ilha carrega.

### Começar uma ilha nova

1. No FileSystem, duplica `game/world/handmade/island_template.tscn` para
   `game/world/handmade/islands/beach_01.tscn` (por exemplo) e abre-a.
2. Seleciona o nó **Terrain3D** e, no inspetor, muda **Data Directory** para
   uma pasta nova (por exemplo `res://game/world/handmade/islands/beach_01_data`).
   Se não mudares, vais esculpir por cima do modelo.
3. Grava a cena (Ctrl+S).

### Estrutura da cena

| Nó | O que faz na grelha |
|---|---|
| `Terrain3D` | Abaixo do mar (-0,3 m) é mar; degrau maior que 0,9 m por metro (cerca de 42°) é falésia: bloqueia |
| `Buildings/` | Cada filho bloqueia as células por baixo da sua forma real, vista de cima: os triângulos do modelo projetados no chão. Um prédio rodado ou em L deixa livres as vielas e os pátios à volta. Objetos sem forma visível de cima bloqueiam a caixa inteira |
| `Rocks/` | Igual aos edifícios. Um nó `Scatter` (muitas cópias de uma rocha) bloqueia por baixo de cada cópia |
| `Trees/` | Cada filho bloqueia só a célula do tronco (a copa não conta) |
| `Bridges/` | Cada filho é o tabuleiro de uma ponte (`MeshInstance3D`): as células por baixo andam-se à altura do tabuleiro, mesmo sobre água; os filhos (guardas) são decoração |
| `Decor/` | Nunca bloqueia: relva, flores, estradas, luzes, água de pré-visualização |
| `Markers/` | `Boat` (obrigatório; o barco fica ancorado no sentido +Z do marcador), `PlayerStart`, `Generator1..3`, `Cache1..` (nós `Marker3D`) |

A ilha ocupa o quadrado de 0 a `size` metros em X e Z (160 por omissão;
muda no inspetor do nó raiz). Mantém tudo lá dentro.

### Relevo com o Terrain3D

Seleciona o nó `Terrain3D`; aparece uma barra de ferramentas à esquerda da
vista 3D.
- **Raise / Lower:** sobe e desce o chão (colinas, dunas). Shift suaviza.
- **Flatten:** aplana à altura que escolheres (praças, planaltos).
- **Smooth:** suaviza degraus.
- **Paint color:** pinta a cor do chão (areia, relva, terra).
- **Regras:** colinas suaves andam-se; paredes íngremes viram falésias. O mar é
  tudo o que fica abaixo de -0,3 m: desce a costa para baixo de 0 para fazer
  praia.

### Objetos

- **Modelos:** arrasta os `.gltf` de `assets/models/nature_megakit/` (árvores,
  rochas) para dentro de `Trees/` ou `Rocks/`.
- **Edifícios:** qualquer modelo ou `MeshInstance3D` dentro de `Buildings/`.
- **Estradas** (Road Generator) e **decoração:** em `Decor/`.
- **Marcadores:** adiciona um `Marker3D` em `Markers/` com o nome certo.
- **Alinhar ao chão:** com um objeto selecionado, a tecla **Page Down** no
  editor encosta-o ao terreno.

### Verificar

Seleciona o nó raiz e, no inspetor, carrega em **Check map**. Na consola
(Output) aparece um relatório: células transitáveis, número de objetos e
problemas (barco em falta, gerador inacessível, início bloqueado...). Também
grava `<cena>_grid.png` ao lado da cena, que é a grelha vista de cima:

| Cor | Significado |
|---|---|
| Azul | Mar |
| Castanho-escuro | Falésia |
| Verde a branco | Chão (mais claro = mais alto) |
| Cinzento | Edifícios e rochas |
| Verde-escuro | Árvores |
| Amarelo | Barco |
| Vermelho | Geradores |
| Ciano | Caches |

**Fotografias para revisão (Claude na cloud):** `tools/dev/screenshot.gd`
renderiza a cena por software (sem GPU) e grava uma vista de cima, quatro
vistas oblíquas e uma vista de perto de cada marcador `Choke_*` e `Arena_*`
(mais ou menos a câmara do jogo). É assim que o Claude vê as tuas ilhas: faz push e pede-lhe
para as rever.

O modelo foi criado por `tools/dev/make_handmade_template.gd`; o teste está
em `tests/test_handmade.gd`.

## Fluxo da run

**Título** → **Armory** (gastar Intel, equipar perks, escolher Threat) → barco (1 de 3: cura, munição ou carta) → ilha → ilha limpa → barco → … →
3.ª ilha limpa ou morte → debrief → Armory. Extrair (ganhar a 3.ª ilha)
multiplica o Intel da run por 1,5. Cada ilha é
mais dura: o HP dos inimigos sobe 30 % e há mais especiais. A vida, o nível,
as cartas e a munição passam de ilha para ilha (`core/run_context.gd`).

O perfil grava-se em `user://profile.json`. No Windows fica em
`%APPDATA%\Godot\app_userdata\Horde Breaker Remake\`. Apagar o ficheiro
recomeça o perfil.

## Biomas

Cada rota no barco mostra o bioma da próxima ilha. A 3.ª ilha é sempre o
Vulcão.

| Bioma | Layout | Particularidade |
|---|---|---|
| Beach | aberto, cabanas e palmeiras espaçadas | poucos sítios para te esconderes |
| Coastal Town | quarteirões em grelha, ruas de 5 m | corredores e esquinas |
| Jungle | palmeiras muito densas, ruínas, névoa | +40 % de especiais (mais Grabbers) |
| Industrial Port | filas de contentores coloridos | corredores estreitos |
| Volcano | cinza, árvores queimadas | poças de lava que ferem toda a gente (atrai a horda para lá) |

## História

Trabalhas para a **Salvage & Co.**, contratado para recuperar dados do
arquipélago Halvard, onde uma experiência ("Project TIDE") correu mal.
- **Rádio**: o Director Hale fala contigo no canto inferior esquerdo, com
  humor seco. Comenta a aterragem (o briefing da missão), os geradores, o
  sobrevivente, o boss, a vida baixa e os Screamers.
- **Ficheiros de Intel**: metade das caixas e todos os bosses dão uma página.
  Lês as páginas no título ou Armory (botão INTEL ARCHIVE). Juntas contam o que realmente
  aconteceu; são 10, em ordem.
- O texto está todo em `data/story.gd`: dá para reescrever sem mexer no código.

### Final

Quando vences uma run com os 10 ficheiros de Intel recuperados, o debrief
abre a conversa final com o Director Hale
(`data/dialogue/origin.dialogue`). Ele confirma que o arquipélago é um teste
e pede-te as *core logs*. Escolhes:
- **Hand over the logs:** final "The Corner Office".
- **Broadcast the logs:** final "Open Channel".

A escolha fica gravada no perfil, dá +300 Intel e só acontece uma vez.

## Missões

Cada rota mostra também a missão da ilha:
- **Activate 3**: liga os três geradores (8 s em cada).
- **Defend**: fica dentro da zona da antena (anel azul, 6 m) durante 75 s ao
  todo. O tempo pára se saíres, e a horda manda picos seguidos.
- **Rescue**: encontra o sobrevivente (cápsula laranja, também no minimapa).
  Depois ele segue-te; se muitos zombies lhe tocarem, morre. Só podes partir
  com ele no barco, ou depois de ele morrer, e aí sem o bónus de +40 de Intel.

No Vulcão, o boss aparece depois de cumprires a missão.

## Rotas (modificadores de ilha)

No barco, além do mantimento (1/2/3), escolhes a rota (4/5, ou LB/RB no
comando) entre duas ilhas sorteadas:

| Modificador | Efeito | Intel |
|---|---|---|
| Calm Waters | nenhum | ×1,0 |
| Swarm | +40 inimigos vivos | ×1,3 |
| Elite Pack | Brutes e Grabbers 2× mais comuns | ×1,3 |
| Sea Fog | nevoeiro: vês os inimigos mais tarde | ×1,2 |
| Supply Shortage | munição especial a metade | ×1,2 |

## Boss (3.ª ilha: o Vulcão)

A última ilha tem outro ambiente: cinza preta, árvores queimadas, luz
vermelha e o vulcão a norte.

Na última ilha, depois dos 3 geradores, aparece o **Behemoth**: 1800 de HP base,
blindado à frente (−50 %) e não é empurrado.
- **Golpe no chão**: quando estás a menos de 9 m, para e mostra um anel
  vermelho de 6 m, que pisca cada vez mais depressa. Ao fim de 1,2 s
  rebenta: 30 de dano se estiveres dentro. Sai do anel ou usa o breaker,
  que te torna invulnerável.
- **Chama Runners**: a cada 9 s aparecem 4 à volta dele.
- **Rochas**: se te afastas mais de 12 m, atira rochas para onde estás. Um
  anel laranja marca o sítio e caem 1,5 s depois (20 de dano). Não dá para
  fugir dele para sempre.
- **Fase 2** (abaixo de 50 % de HP): fica mais rápido, golpeia mais vezes e
  chama também um Brute.
- Matá-lo dá +20 de Intel e abre o regresso ao barco. Tem uma barra de vida
  no topo e o marcador aponta para ele.

## Telemetria

No fim de cada run grava-se `user://runs/run_<data>.json`, ao lado do
perfil. Tem, por ilha: modificador, resultado, segundos, mortes, headshots,
dano recebido, vida restante, nível, Intel, caixas abertas e cartas
escolhidas. Serve para equilibrar com números ("morri na ilha 2 com Elite
Pack ao fim de 3 min") em vez de impressões.

## Meta: Intel, perks e Threat

- **Perks** compram-se uma vez com Intel e equipam-se em slots: começas com
  1 slot, o 2.º custa 100 e o 3.º 250. São 5 perks: Thick Skin, Pack Rat,
  Head Hunter, Battering Ram e Demolitions. São bónus pequenos, para dar
  opções e não poder bruto.
- **Classes** (escolhe-se uma no Armory; a tecla G usa a habilidade):
  Recruit (grátis; Granada), Vanguard (150; +40 HP, breaker −30 %; War Cry:
  atordoa a 7 m e −40 % de dano recebido durante 5 s). O Field Medic foi
  retirado a pedido; perfis antigos com ele voltam ao Recruit.
- **Armas**: SMG (60 Intel; 16 tiros/s, 18 m) e Marksman Rifle (80 Intel;
  110 de dano, atravessa 6). Depois de compradas ficam nas teclas 4 e 5.
- **Threat 1–3**: cada nível dá +20 % de HP aos inimigos, mais 25 vivos e
  +25 % de Intel. Extrair no Threat mais alto desbloqueia o seguinte.
- **Granada**: cai onde está o rato (até 14 m), rebenta após 0,8 s (5 m,
  90 de dano) e tem 12 s de cooldown. O anel vermelho mostra a área.

## Luz e gráficos

- **Sky3D** (addon): céu físico com nuvens, sol e lua, e um relógio. Cada
  ilha começa a uma hora diferente (9h00, 16h30, 16h15 no Vulcão) e o tempo
  avança devagar (~1 hora de jogo a cada 5 min), por isso a luz muda enquanto
  jogas. As horas estão em `world/island.gd` (`ISLAND_HOURS`). Sem o addon, o
  jogo volta ao céu simples anterior.
- **Terrain3D** (addon): o chão da ilha é um terreno gerado do mapa
  (`world/island_terrain.gd`). A terra jogável fica **plana a 0 m** (o jogo
  corre numa grelha 2D, nada pode flutuar ou afundar) e a costa desce suave
  para o fundo do mar (até −3 m). A cor vem do *color map* (areia na costa,
  cor do bioma no interior) sobre uma textura clara gerada em código; mais
  tarde podem entrar texturas reais (areia, relva, rocha). Sem o addon, volta
  o chão de tiles.
- **Estradas** (addon Road Generator, `world/island_roads.gd`): do cais a
  cada objetivo, com candeeiros acesos (`OmniLight3D`). São só decoração.
- **Natureza** (Quaternius Nature MegaKit, `world/nature_kit.gd`): árvores e
  rochas reais, e relva, fetos, flores ou seixos por bioma, desenhados com
  `MultiMesh`. A praia e o porto mantêm as palmeiras feitas em código.
- **Soldado** (`world/soldier_model.gd`): o contratado low-poly, com farda e
  arma por classe (Recruit: caqui e espingarda; Vanguard: armadura pesada e
  caçadeira). Anda com pernas a balançar e aparece a rodar no Armory.
- Tonemap ACES sempre ligado. O preset de Graphics (Settings) decide
  sombras, bloom, SSAO e SSIL.
- Partículas GPU (`world/fx.gd`): faíscas nos impactos, sangue nas mortes e
  pó no breaker, a partir de emissores reutilizados.
- As capturas da cloud usam o renderer de compatibilidade (sem SSAO): o
  aspeto final vê-se no editor em Forward+.

## Feedback visual (sem animações nem assets)

- Inimigos balançam, saltitam e inclinam-se ao andar, proporcional à
  velocidade, e tremem quando atordoados.
- Desmembramento com primitivas: num headshot a cabeça salta com salpicos
  vermelhos; num tiro ao corpo sai um braço. Os pedaços rodam no ar.
- Tremor de câmara ao levar dano e no breaker. Usa um modelo de "trauma": o
  tremor cresce com o quadrado, por isso os toques pequenos quase não se notam.
- Arco vermelho à volta do centro do ecrã a indicar de onde veio o último
  golpe; números de dano nas mortes (a âmbar com "!" nos headshots).
- Flash vermelho no ecrã ao levar dano; clarão de luz na arma ao disparar.
- Edifícios entre a câmara e o jogador ficam translúcidos, para nunca o
  perderes de vista.
- Hit-stop de 80 ms ao matar um Brute: o jogo congela por um instante para o
  golpe "pesar".

## Som

- **Sons gravados** do pack Ovani (`assets/audio/ovani_sfx_starter_vol1/`):
  Heavy Pistol, Marksman, explosões, breaker, dano, level-up, gerador,
  Screamer, golpe do boss (aviso e impacto), caixas, sobrevivente,
  vitória/derrota, vida baixa e sons de UI (passar o rato/foco e clicar).
  O mapa evento → ficheiro está em `audio/sfx.gd` (`FILES`); se um ficheiro
  faltar, o jogo usa o som sintetizado.
- **Ambiente por bioma** (`audio/ambience.gd`): ondas na praia e nos menus,
  floresta na selva, vento na vila e no porto, tremor no vulcão.
- O pack não tem rajadas de espingarda: Assault Rifle, SMG e Shotgun ainda
  usam os sons sintetizados. Fica no TODO arranjar estes três.
- Volumes em `world/island.gd::_play_audio`.

**Música adaptativa** (`audio/music.gd`): dois loops sintetizados de 8 s
(lá menor, 120 BPM), um calmo (drone e acorde) e um de combate (o mesmo
drone com bombo, baixo e chimbal). Tocam sempre juntos e o volume de cada um
segue o diretor: relax → calmo, crescer → mistura, pico e boss → combate.
Como as transições são cross-fades, não há cortes.

## Onde mexer nos valores

O **conteúdo** está em ficheiros `.tres`, um por item, em `game/data/`.
Cada pasta tem um registo **YARD** com o mesmo nome (por exemplo
`game/data/enemies.tres`):

| Pasta | O quê |
|---|---|
| `weapons/` | Armas: dano, cadência, alcance, munição, preço |
| `cards/` | Cartas de level-up |
| `perks/` | Perks do Armory |
| `enemies/` | Inimigos: vida, velocidade, dano, cor, flags (`order` = `EnemyKind`, não mudar) |
| `modifiers/` | Modificadores de rota e multiplicador de Intel |
| `classes/` | Classes: nome, preço, texto da habilidade |
| `biomes/` | Biomas: cores, nevoeiro, palmeiras, se aparecem como rota |
| `missions/` | Missões: nome e texto |
- No editor, o separador **Registry** mostra cada registo como uma folha de
  cálculo: mudas o dano, o custo ou o texto sem tocar em código.
- Um ficheiro novo na pasta entra sozinho no registo.
- O `order` define a ordem: teclas das armas e listas do Armory.
- Numa arma, `unlock_cost` 0 quer dizer arma inicial e mais de 0 é o preço em
  Intel no Armory.


Todos os números de equilíbrio (HP, dano, velocidades, cooldowns, cartas)
estão em `game/data/game_data.gd`. São hipóteses para afinar a jogar. A câmara
(ângulo, distância, FOV) é exportada no nó `Island` (`game/world/island.tscn`).
Como a ilha é criada pelo `main`, para afinar a câmara podes abrir
`island.tscn` e correr com F6.

## Estrutura

| Ficheiro | O quê |
|---|---|
| `main.gd` | Máquina de estados da run: barco → ilha → debrief. |
| `core/run_context.gd` | O que passa de ilha para ilha. |
| `core/game_input.gd` | Ações de input (InputMap): teclas e botões do comando por ação. |
| `core/profile.gd` | Perfil gravado (Intel, runs), JSON versionado. |
| `states/title.gd` | Título com porto ilustrado e botões nativos. |
| `ui/ui_theme.gd` | Tema partilhado por menus e HUD (painéis, botões, cores). |
| `ui/menu_dialog.gd` | Foco e input modal; arquivo e controlos. |
| `ui/route_map.gd`, `ui/route_preview.gd` | Mapa decorativo e miniaturas das rotas. |
| `states/armory.gd`, `states/boat.gd`, `states/debrief.gd` | Ecrãs entre runs, entre ilhas e do fim da run. |
| `world/island_run.gd` | **Todas as regras**, sem nós: jogador, auto-fire, breaker, cartas, missão. Testável em headless. |
| `world/island.gd` | Input, render (MultiMesh), câmara média e efeitos. |
| `world/island_map.gd` | Gera a ilha (costa irregular, edifícios, geradores, barco). |
| `world/director.gd` | Ritmo da horda (crescer/pico/relax, intensidade). |
| `horde/horde.gd`, `horde/flow_field.gd` | Horda como dados, vinda do spike `horde_flowfield`. |
| `ui/hud.gd` | HUD em código. |
| `ui/settings_panel.gd` | Painel de definições (volumes, gráficos, ecrã inteiro). |
| `world/fx.gd`, `world/visuals.gd` | Partículas GPU; céu, pós-processamento e materiais partilhados. |
| `audio/sfx.gd`, `audio/music.gd` | Sons e música sintetizados em código. |
| `data/story.gd` | Falas do rádio e ficheiros de Intel. |
| `data/game_data.gd` | Dados e valores de equilíbrio. |

`tests/test_soak_run.gd` é um bot que joga runs completas (3 ilhas, boss
incluído, invencível) e garante que se conseguem acabar. Foi ele que mostrou
que o boss demorava 6 minutos: o auto-fire disparava nos Runners à volta.

Porquê separar `island_run` (regras) de `island` (cena): assim os testes
correm o jogo inteiro sem janela (`tests/test_island_run.gd` tem um bot que
joga 90 s). E qualquer bug de regras reproduz-se em headless.

## O que ainda não existe

Ver `TODO.md` na raiz.
