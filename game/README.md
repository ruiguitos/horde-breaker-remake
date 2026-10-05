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
| Trocar arma | 1 / 2 / 3 | D-pad ← ↑ → |
| Escolher carta | 1 / 2 / 3 ou clique | X / Y / B |
| Continuar no fim da ilha | Enter / R | A / Start |
| Pausa (Q na pausa abandona) | Esc | Start |
| Painel de debug | F3 | — |

## Como se joga

- A arma **dispara sozinha** contra o inimigo mais próximo dentro de um cone
  de 50° à tua frente. Se o alvo estiver quase exatamente onde olhas (±9°),
  é **headshot** (dano ×2,5). Ou seja: mira-se com o corpo.
- **Breaker**: investida de 5 m que empurra e atordoa tudo no caminho, dá dano
  no fim e solta-te de um Grabber. Cooldown de 6 s (barra amarela).
- Inimigos:
  - **Walker** (verde): o comum.
  - **Runner** (amarelo): rápido e frágil.
  - **Brute** (vermelho escuro, grande): blindado à frente (−75 % de dano);
    acerta-lhe de lado ou por trás, ou com o breaker.
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
- O **diretor** alterna calma → crescer → pico (ver F3). O máximo é de 150
  inimigos vivos.

## Fluxo da run

Barco (1 de 3: cura, munição ou carta) → ilha → ilha limpa → barco → … →
3.ª ilha limpa ou morte → debrief, com o Intel total → nova run. Cada ilha é
mais dura: o HP dos inimigos sobe 30 % e há mais especiais. A vida, o nível,
as cartas e a munição passam de ilha para ilha (`core/run_context.gd`).

O perfil grava-se em `user://profile.json`. No Windows fica em
`%APPDATA%\Godot\app_userdata\Horde Breaker Remake\`. Apagar o ficheiro
recomeça o perfil.

## Feedback visual (sem animações nem assets)

- Inimigos balançam, saltitam e inclinam-se ao andar, proporcional à
  velocidade, e tremem quando atordoados.
- Tremor de câmara ao levar dano e no breaker. Usa um modelo de "trauma": o
  tremor cresce com o quadrado, por isso os toques pequenos quase não se notam.
- Flash vermelho no ecrã ao levar dano; clarão de luz na arma ao disparar.
- Hit-stop de 80 ms ao matar um Brute: o jogo congela por um instante para o
  golpe "pesar".

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
| `core/profile.gd` | Perfil gravado (Intel, runs), JSON versionado. |
| `states/boat.gd`, `states/debrief.gd` | Ecrãs do barco e do fim da run. |
| `world/island_run.gd` | **Todas as regras**, sem nós: jogador, auto-fire, breaker, cartas, missão. Testável em headless. |
| `world/island.gd` | Input, render (MultiMesh), câmara média e efeitos. |
| `world/island_map.gd` | Gera a ilha (costa irregular, edifícios, geradores, barco). |
| `world/director.gd` | Ritmo da horda (crescer/pico/relax, intensidade). |
| `horde/horde.gd`, `horde/flow_field.gd` | Horda como dados, vinda do spike `horde_flowfield`. |
| `ui/hud.gd` | HUD em código. |
| `data/game_data.gd` | Dados e valores de equilíbrio. |

Porquê separar `island_run` (regras) de `island` (cena): assim os testes
correm o jogo inteiro sem janela (`tests/test_island_run.gd` tem um bot que
joga 90 s). E qualquer bug de regras reproduz-se em headless.

## O que ainda não existe

Ver `TODO.md` na raiz.
