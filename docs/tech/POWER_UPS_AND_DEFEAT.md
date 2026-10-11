# Power-ups de abate e ecrã de derrota — 2026-10-10

Implementação da tarefa 2 de `CODEX_HANDOFF.md` e do pedido de melhorar
o menu de morte. A tarefa 1 (39 cartas) está descrita em
[CARDS_IMPLEMENTATION.md](CARDS_IMPLEMENTATION.md). Sem commit nesta fase.

## O que está feito

Os abates podem largar um dos sete power-ups em **todas as missões**:
activate, defend, rescue e holdout, incluindo as partes das expedições.
Um ícone grande flutua sobre um anel luminoso e acompanha o relevo e as
pontes. O minimapa usa um círculo com cruz e a legenda `POWER-UP`.
O jogador apanha-o ao aproximar-se; não precisa de premir uma tecla.

| Power-up | Efeito atual |
|---|---|
| Insta-Kill | 25 s: qualquer tiro direto mata qualquer inimigo, elites, especiais e chefe incluídos (aplica-se depois da armadura frontal, que já não o trava). Não transforma breaker ou dano secundário em abates instantâneos. |
| Double XP / Intel | 25 s: XP duplica ao apanhar orbes; duplica o Intel novo de abates, caixas e objetivos. O bónus já ganho fica após o efeito terminar. |
| Nuke | Mata todos os inimigos vivos em todo o mapa, chefe incluído, sem raio nem linha de visão. Cada abate conta (abates, orbe de XP, Intel); o objetivo do chefe vê-o morto na atualização seguinte e segue para a extração, como num abate normal. Os abates da Nuke **não** sorteiam novos power-ups (nem gastam RNG ou mexem na garantia) e os Bloaters não explodem sobre o jogador. Suspende spawns do diretor e invocações do chefe por 5 s. |
| Full Power | Breaker e habilidade de classe ficam prontos. |
| Max Shield | Enche o escudo até ao máximo. (Antes chamava-se Max Armor.) |
| Extra Reroll | +1 reroll, até ao máximo existente de 3. (Antes chamava-se Fire Sale.) |
| Max Ammo | Repõe as armas especiais que a run tem, até à capacidade modificada por cartas/perks/rota. A arma infinita mantém-se infinita. Não entra no sorteio sem armas de munição finita. |

Há avisos curtos ao apanhar (`MAX SHIELD!`, `EXTRA REROLL!`, etc.) e temporizadores com
ícone e segundos para os dois efeitos de duração. O escudo começa vazio,
tem capacidade base de 100 e absorve dano antes da vida; o excedente
passa para a vida. A barra e o valor numérico seguem o HUD sem painéis escuros.
Não regenera automaticamente; `add_shield()` prepara as futuras cartas.

Os ids internos passaram a `max_shield` e `extra_reroll`. Os antigos
(`max_armor`, `fire_sale`) só existiam na telemetria das runs; o
`GameData.POWER_UP_LEGACY_IDS` traduz-nos, por isso saves antigos não partem.

### Carregador da Assault Rifle (2026-10-11)

A espingarda continua com munição total infinita, mas tem um carregador de
**30 balas** (`magazine = 30` em `game/data/weapons/rifle.tres`). O HUD
mostra `30 / ∞` (carregador / reserva) e desce a cada tiro. Por agora
**não há recarga**: ao chegar a 0 o carregador volta a 30 no mesmo tiro,
sem pausa nem animação. O gancho já existe: `GameData.RELOAD_SECONDS`
(0 por agora) e `IslandRun._reload()` com um `TODO(reload)`; com um valor
maior que 0, o `_auto_fire` espera `reload_left` e o HUD mostra
`RELOADING`. O tamanho vem de `IslandRun.magazine_size()`, o único sítio
que uma futura carta mudaria. A Bigger Mags só aumenta a reserva das armas
finitas e não toca no carregador. As outras armas mostram a munição como
antes.

O novo ecrã **CONTRACT TERMINATED** apresenta abates, headshots e tempo
total da run, local/classe/nível, Intel conservado (ilhas anteriores +
ilha atual) e o valor exato do bónus ×1,5 perdido. Inclui comentário seco
da empresa e texto específico quando se perde o sobrevivente.
O botão **CONTINUE TO DEBRIEF** recebe o foco; teclado, rato e comando
funcionam com proteção inicial de 0,6 s e apenas uma continuação, para
não depositar Intel duas vezes. Uma ilha em F6 mostra **RESTART FIELD
TEST**. O painel de vitória mantém o comportamento anterior.

A pausa tem **RESUME**, **SETTINGS** e **ABANDON RUN**. O atalho separado
**CONTROLS** foi removido a pedido do utilizador; os controlos continuam
acessíveis em **Settings → Controls**, sem duplicar a entrada.

## Valores provisórios para playtest

Todos os valores de equilíbrio estão em `game/data/game_data.gd`:

- Probabilidade por abate elegível: **1,5%** em Walker/Runner, **5%** nos
  especiais/chefe. Os sete tipos têm o mesmo peso no sorteio.
- Garantia após **60 abates sem drop**. Acumula durante o cooldown, mas
  aguarda um abate elegível num ponto alcançável.
- Pelo menos **35 s entre drops**, também no arranque; só **um no chão**.
- O objeto dura **25 s** e pisca nos últimos **10 s**. Apanha-se a **1,4 m**.
- Efeitos repetidos renovam os 25 s; não acumulam multiplicadores.

Os pontos procuram uma célula livre até 3 m do abate: ligada ao jogador
pelo flow field, com espaço para o raio do jogador e dentro do polígono
da parte. Células desligadas, fora do mapa ou ainda não calculadas pelo
campo de navegação não recebem drops; a garantia aguarda o próximo
abate válido. Não se recomputa a navegação por abate.

## Organização e continuidade

`world/power_ups.gd` é um `RefCounted`: trata do sorteio e dos tempos,
sem nós, física ou render. Usa RNG próprio para não mudar os sorteios
das cartas, tiros ou spawns. `IslandRun` aplica os efeitos e contabiliza
as recompensas; `Island` desenha um único objeto reutilizado; `Hud` e
`Minimap` apresentam o estado.

O escudo, efeitos restantes, garantia, cooldown e estado do RNG passam
no `RunContext` entre ilhas/partes. Pausa, cartas e ecrãs de mantimentos
não gastam os tempos da simulação. Um objeto no chão não atravessa a
transição. O Intel extra pertence à ilha onde foi ganho e é depositado
uma vez, juntamente com o Intel normal. Telemetria acrescenta
`power_ups`, `power_up_intel_bonus` (antes de rota/Threat/hazard pay) e
`shield_left`. O JSON do perfil não mudou de formato.

Double Rewards guarda o aumento do Intel base durante o efeito, em vez
de multiplicar o total quando se sai da ilha. Isto evita perder o bónus
ao expirar ou duplicar os ganhos anteriores à recolha. Intel de abates
continua a ser pago em lotes de cinco; o efeito duplica o lote quando
esse pagamento acontece. Os multiplicadores de rota, Threat e hazard
pay aplicam-se ao total, e o ×1,5 de extração mantém a regra existente.

## Como experimentar

1. Corre uma ilha ou parte de expedição e abate inimigos. O primeiro drop
   exige pelo menos 35 s de combate; a garantia reduz sequências sem nada.
2. Aproxima-te do ícone. Confirma o aviso, barra de escudo ou temporizador.
3. Morre ou abandona a run na pausa. Confirma o Intel e avança para o
   debrief com Enter, A ou o botão, após a proteção inicial.

## Verificação

`tests/test_power_ups.gd` cobre limites, garantia, probabilidade maior nos
especiais, determinismo, RNG independente, expiração, cada efeito,
escudo, contabilização de Intel, pausa e continuidade. Usa também um
abate real numa ilha feita à mão restringida a uma parte da expedição.

`tests/test_defeat_power_up_hud.gd` valida o ícone em 3D, minimapa/legenda,
escudo, avisos e timers, relatório de derrota, foco, input de teclado e
comando, proteção temporal e depósito único do Intel. Verifica encaixe
a 960×540, 1152×648 e 1920×1080. `test_hud.gd` foi atualizado para verificar
o relatório que substituiu `YOU DIED`. Capturas no Godot a 1152×648
confirmaram visualmente o HUD e a derrota.

Resultado final: **26/26 testes** (23 do jogo e três dos spikes), sem
`TEST FAIL` ou `SCRIPT ERROR`. O bot extraiu nas seis ilhas de duas runs,
com os cinco biomas e o chefe. As capturas foram verificadas também com
o renderer **Forward+** do projeto, na RTX 5060 deste PC. Os perfis dos
testes ficaram numa pasta temporária isolada, sem alterar o perfil real.

Limitações: alguns processos deste Godot terminaram com erro nativo no
fecho (`-1073741819`), já conhecido neste PC; a avaliação segue os erros
de teste/script, conforme o `AGENTS.md`. Mantêm-se avisos dos assets
Terrain3D e da interpolação, sem alterar addons. O bot usa vida elevada:
prova que as runs terminam, não que a dificuldade está equilibrada.
A importação registou as classes e os `.uid`, mas emitiu erros do plugin
Dialogue Manager (`Busy` e `get_theme_icon`), também já observados antes.
Os três DLLs previstos no `AGENTS.md` foram restaurados após importar.

Uma inversão temporária da condição de garantia provocou nove falhas
de teste; foi restaurada. A revisão JEV recebeu apenas um resumo
sanitizado e foi inconclusiva, com confiança abaixo do limiar; não recebeu
o código privado. A revisão local e os testes deterministas são a base
da validação.

## Fora desta implementação

Cartas de escudo, Lucky Find, Death Machine e Zombie Blood continuam
adiadas. Não se alteraram câmara/mira, distribuição dos spawns, escolha de
armas, árvore de perks, `DECISIONS.md` ou os ficheiros próprios do utilizador.
