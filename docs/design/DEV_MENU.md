# Menu de desenvolvimento — proposta

Estado: **fase 1 implementada no working tree (2026-10-21), ainda não commitada.**
As decisões continuam na secção «Decisões propostas», e só se registam em
`docs/DECISIONS.md` quando o utilizador as tomar.

Na fase 1 assumi as escolhas da maqueta, que se podem trocar: F2 abre o painel;
a horda desliza até 300 com a marca de 150; as corridas com opções de dev não
gravam perfil nem telemetria; o HUD mostra as opções que mudam o equilíbrio.

Feito: invencível, munições infinitas, velocidade do tempo, limite da horda,
noclip, criar inimigo no ponto de mira, trocar de arma, +1 nível e +100 XP.
Por fazer: os botões «Saltar» (fim da ilha e boss), que precisam de código
próprio dos objetivos; a fase 2 (sandbox no título) e a fase 3 (testes
integrados no painel).

## Objetivo

Testar o jogo sem o percorrer desde o início: escolher um mapa, uma arma, a
classe e o tamanho da horda, e ver o efeito de cada regra. Também reúne os
testes automáticos num só sítio, dentro do jogo.

## O que já existe

| Peça | Onde | Notas |
|---|---|---|
| HUD de depuração (F3) | `game/ui/hud.gd`, `island.gd` | FPS, inimigos, tempo de simulação e o diretor |
| Noclip (botões laterais do rato) | `island.gd`, `island_run.gd` (`noclip`) | Sem dano e sem paredes |
| «DEV · TEST ISLAND» no título | `game/states/title.gd`, `game/main.gd` (`_test_island`) | Só em `OS.is_debug_build()`; arranca uma ilha com uma missão, sem campanha à volta |
| Teto da horda | `game/data/game_data.gd` (`MAX_ALIVE` 150, `HORDE_CAP` 300), `island_run.gd` | `director.max_alive` é calculado aqui |
| Nível e XP | `island_run.gd` (`level`, `xp`) | Já existem na corrida |

## Proposta

O menu tem três zonas. A zona 1 estende o atalho que já existe; a zona 2 é o
painel dentro da ilha; a zona 3 são os testes, já desenhados.

### Zona 1: sandbox no título (só builds de desenvolvimento)

Um painel que monta uma corrida à medida, com o mesmo caminho de `_test_island`:

- bioma e ilha manual (os ficheiros de `game/world/handmade/islands`);
- missão;
- classe (Recruit ou Vanguard) e perks equipados;
- arma primária e secundária;
- ameaça (1 a 5) e seed.

«Start» arranca a corrida. O atalho «DEV · TEST ISLAND» mantém-se como acesso rápido.

### Zona 2: painel dentro da ilha (tecla proposta: F2)

| Opção | Efeito | Implementação prevista |
|---|---|---|
| Invencível | Sem dano | verificação em `_take_player_damage` |
| Munições infinitas | Sem consumo de munições | consumo de munições em `island_run.gd` |
| Tamanho da horda | Ajusta `director.max_alive`, até ao teto | `director.max_alive`, limitado por `HORDE_CAP` |
| Velocidade do tempo | 0,1× a 2× | `Engine.time_scale`, repostas ao sair |
| Noclip | Mostra e liga o estado atual | já existe |
| Criar inimigo | Cria um tipo no ponto de mira | `horde.add` na posição do ponto de mira |
| Trocar de arma | Lista as armas da corrida | `run.switch_weapon` |
| Nível e XP | Sobe um nível ou dá XP | `run.level` e `run.xp` |
| Saltar | Vai para o fim da ilha ou para o boss | estado do objetivo em `island_run.gd` |

### Zona 3: testes

O painel de testes já desenhado: árvore de `tests/` e `spikes/`, caixas de
seleção, «Run all», resultados por teste e barra de progresso. Corre cada
teste num processo separado, com o mesmo executor que já existe.

## Regras

1. **Só em desenvolvimento.** O menu, as opções e o código de apoio só ficam
   ativos com `OS.is_debug_build()`. Uma build de release não tem o menu.
2. **Corridas de dev não gravam nada.** Perfil, Intel e telemetria ficam de
   fora, marcados com um indicador em `RunContext`. Há muitos sítios que
   chamam `profile.save()` (`main.gd`, `debrief.gd`, `island.gd`), por isso a
   proteção fica num só ponto, dentro de `Profile.save`.
3. **Modos que mudam o equilíbrio aparecem no HUD.** Invencível, munições
   infinitas e tempo alterado mostram-se sempre, para não confundir com
   medições de equilíbrio.
4. **Mudar de mapa ou de classe reinicia a corrida.** Não se muda a meio de uma
   ilha.

## Arquitetura prevista

- `game/core/dev_options.gd`: flags estáticas (invencível, munições, horda,
  tempo). Só podem ser alteradas quando `OS.is_debug_build()`; em release
  ficam sempre nos valores de origem.
- `game/ui/dev_menu.gd`: o painel dentro da ilha, numa camada própria (F2).
- `game/ui/dev_sandbox.gd`: o painel do título, que preenche um `RunContext`.
- Ganchos mínimos em `island.gd`, `island_run.gd`, `director.gd` e
  `profile.gd`, cada um com uma condição sobre `DevOptions`.

## Testes previstos

- `test_dev_options`: os valores por omissão são os de origem, e em release
  nada muda.
- `test_dev_menu`: cada opção altera o estado esperado (dano, munições, horda,
  tempo, nível).
- `test_dev_run_saves_nothing`: uma corrida de dev não escreve perfil nem
  telemetria.
- `test_run_all` e o painel de testes: continuam a classificar como hoje.

## Faseamento

1. **Zona 2** (painel dentro da ilha). É a que dá mais valor com menos
   trabalho, e a que trata das regras 1 a 3.
2. **Zona 1** (sandbox no título), reutilizando `_test_island`.
3. **Zona 3** (testes integrados).

## Riscos

- **Equilíbrio contaminado.** Se alguém ler uma medição feita com as opções
  ativas como se fosse normal. Mitigação: o indicador da regra 3.
- **Progresso estragado.** Uma corrida de dev que grave Intel ou perfil. Mitigação:
  a proteção central da regra 2 e um teste dedicado.
- **Horda acima do teto.** O teto de 300 existe por desempenho. O menu não o
  ultrapassa.
- **Efeitos colaterais do tempo alterado.** Áudio e animações podem
  desalinhar-se a velocidades diferentes de 1×. Confirmar a meio do trabalho.

## Decisões propostas

1. **Horda.** Por omissão até 150 (o valor base), com desbloqueio até 300 e um
   aviso? Ou livre até 300?
2. **Tecla dentro da ilha.** F2 (F3 já é o HUD)?
3. **Sandbox e atalho.** O sandbox convive com o «DEV · TEST ISLAND» (atalho
   rápido e painel completo), ou substitui-o?
4. **Corridas de dev.** Confirmas a regra 2 (não gravam perfil, Intel nem
   telemetria)?
5. **Indicador.** Confirmas a regra 3 (modos que mudam o equilíbrio sempre
   visíveis no HUD)?
