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
| Mover | WASD / setas | stick esquerdo |
| Orientar (o auto-fire dispara para onde olhas) | rato | stick direito |
| Breaker (investida) | Espaço ou botão direito | A ou RB |
| Sprint (não dispara enquanto corre) | Shift | L3 (clicar stick esquerdo) |
| Granada (lança para o rato) | G ou botão do meio | LB |
| Trocar arma | 1–5 | D-pad ← ↑ →, ↓ roda |
| Escolher carta | 1 / 2 / 3 ou clique | X / Y / B |
| Continuar no fim da ilha | Enter / R | A / Start |
| Pausa (Q na pausa abandona) | Esc | Start |
| Painel de debug | F3 | — |
| Ecrã inteiro | F11 | — |

**Settings** (no título, no Armory e na pausa): volumes Master, Sound effects e
Music, cada um com um slider e um campo editável em percentagem (0–100;
escrever e carregar Enter, ou mudar de campo, aplica o valor). Também tem
gráficos High/Low e ecrã inteiro. Tudo fica gravado no perfil. Os sons vão
para os buses de áudio SFX e Music, criados em código (`core/profile.gd`).

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
  atordoa a 7 m e −40 % de dano recebido durante 5 s) e Field Medic (200;
  regenera 1 HP/s; Med Kit: +35 HP).
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
- Tonemap ACES sempre ligado. **Graphics: High** (Armory) liga também bloom e
  SSAO (oclusão ambiente); **Low** desliga-os, para PCs mais fracos.
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
