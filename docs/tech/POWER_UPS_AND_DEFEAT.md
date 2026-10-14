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

### Recolha obrigatória — 2026-10-11

**Um power-up só tem efeito quando é apanhado a até 1,4 m.** Se os 25 s
acabarem ou o jogador sair da ilha/parte sem o recolher, perde-se: não
concede efeitos, munição, escudo, rerolls, XP ou Intel, não mostra aviso de
utilização e não conta como recolha na telemetria. A recolha automática de
XP a partir do nível 30 não recolhe power-ups.

O ciclo normal já descartava os drops ao expirar. Foi reforçada a validação
da recolha para recusar um item cujo tempo terminou mesmo antes da limpeza
dos temporizadores. Restaurar o estado entre ilhas também limpa qualquer
objeto no chão que reste numa instância reutilizada. O efeito de um item
recolhido continua a funcionar normalmente, incluindo a continuidade dos
bónus ativos entre ilhas.

Os testes percorrem os sete tipos: distância, perda por expiração, saída
da ilha, recolha válida e consumo único. Cobrem ainda a chegada no instante
de expiração e o HUD: um drop no minimapa não aparece como bónus ativo;
quando se perde, desaparece sem aviso de recolha.

| Power-up | Efeito atual |
|---|---|
| Insta-Kill | 25 s: qualquer tiro direto mata qualquer inimigo, elites, especiais e chefe incluídos (aplica-se depois da armadura frontal, que já não o trava). Não transforma breaker ou dano secundário em abates instantâneos. |
| Double XP / Intel | 25 s: XP duplica ao apanhar orbes; duplica o Intel novo de abates, caixas e objetivos. O bónus já ganho fica após o efeito terminar. |
| Nuke | Mata todos os inimigos vivos em todo o mapa, chefe incluído, sem raio nem linha de visão. Cada abate conta (abates, orbe de XP, Intel); o objetivo do chefe vê-o morto na atualização seguinte e segue para a extração, como num abate normal. Os abates da Nuke **não** sorteiam novos power-ups (nem gastam RNG ou mexem na garantia) e os Bloaters não explodem sobre o jogador. Suspende spawns do diretor e invocações do chefe por 5 s. |
| Full Power | Breaker e habilidade de classe ficam prontos. |
| Max Shield | Enche o escudo até ao máximo. (Antes chamava-se Max Armor.) |
| Extra Reroll | +1 reroll no **próximo** ecrã de cartas de level-up (que abre com 1 + 1); não se acumula para além desse ecrã e passa para a ilha seguinte se ainda não houve level-up (`bonus_rerolls`; regra decidida pelo utilizador em 2026-10-14). (Antes chamava-se Fire Sale.) |
| Max Ammo | Repõe as armas especiais que a run tem, até à capacidade modificada por cartas/perks/rota. A arma infinita mantém-se infinita. Não entra no sorteio sem armas de munição finita. |

Há avisos curtos ao apanhar (`MAX SHIELD!`, `EXTRA REROLL!`, etc.) e temporizadores com
ícone e segundos para os dois efeitos de duração. O escudo começa vazio,
tem capacidade base de 100 e absorve dano antes da vida; o excedente
passa para a vida. A barra e o valor numérico seguem o HUD sem painéis escuros.
Não regenera automaticamente; `add_shield()` prepara as futuras cartas.

Os ids internos passaram a `max_shield` e `extra_reroll`. Os antigos
(`max_armor`, `fire_sale`) só existiam na telemetria das runs; o
campo `legacy_ids` de cada `.tres` traduz-nos (`GameData.power_up_id()`),
por isso saves antigos não partem.

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

As **regras de drop** (iguais para todos os power-ups) estão em
`game/data/game_data.gd`; os **valores de cada power-up** estão num
`.tres` próprio (ver a secção seguinte).

- Probabilidade por abate elegível: **1,5%** em Walker/Runner, **5%** nos
  especiais/chefe. Os sete tipos têm o mesmo peso (`weight = 1`) no sorteio.
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

## Afinar cada power-up no editor (YARD)

Cada power-up é um ficheiro em `game/data/power_ups/` (`nuke.tres`,
`max_shield.tres`…), do tipo `PowerUpData`
(`game/data/resources/power_up_data.gd`). O registo YARD
`game/data/power_ups.tres` lista-os, tal como já acontece com armas,
cartas e perks. Para mudar valores:

1. No editor Godot, abre o separador **Registry** (YARD), no topo.
2. Escolhe `game/data/power_ups.tres`.
3. Edita as colunas na tabela (ou clica numa linha e usa o Inspector).
4. Guarda (Ctrl+S). Não é preciso mexer em código.

O que cada coluna faz:

| Campo | Para quê |
|---|---|
| `display_name` | Nome no chão, no aviso e no relatório da ilha. |
| `glyph` | Símbolo no chão, nos temporizadores e no relatório. |
| `color` | Cor do anel e do símbolo no chão. |
| `weight` | Peso no sorteio de *qual* power-up cai (0 = nunca cai). Todos iguais = sorteio uniforme, exatamente como antes. |
| `requires_finite_weapon` | Só cai com uma arma de munição finita (Max Ammo). |
| `duration` | Segundos ativos (Insta-Kill, Double XP / Intel). |
| `spawn_delay` | Segundos sem novos inimigos depois da Nuke. |
| `reroll_amount` | Rerolls extra que o Extra Reroll dá ao próximo ecrã de level-up. |
| `shield_fill` | Fração do escudo máximo que o Max Shield enche (1 = cheio). |
| `legacy_ids` | Ids antigos que apontam para este power-up. |
| `order` | Ordem no registo (e no sorteio). |

Os campos de efeito só contam no power-up a que dizem respeito (por
exemplo, `spawn_delay` só é lido na Nuke). Full Power e Max Ammo não têm
números: recarregam tudo. A **probabilidade de haver drop**, a garantia,
o cooldown, o tempo no chão e o piscar são regras globais e ficam em
`GameData` (`POWER_UP_*`), porque valem para todos.

Um power-up novo precisa de código em `IslandRun.apply_power_up()` para
o efeito; os dados sozinhos não chegam. `tests/test_power_ups.gd`
confirma que o registo tem os sete e os valores atuais.

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

Na atualização de 2026-10-11, os novos testes da recolha obrigatória e do
HUD passaram, juntamente com os restantes: **27/27 scripts**. Os dois casos
de estado residual falharam antes das proteções e passaram depois. Uma
alteração temporária que aceitava um drop com tempo zero voltou a fazer
falhar o teste; o código correto foi restaurado e o teste voltou a passar.
Os resultados completos desta atualização estão no
[catálogo de combate](COMBAT_CATALOG.md#7-fontes-e-verificação).

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

Resultado da implementação inicial: **26/26 testes** (23 do jogo e três dos spikes), sem
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
