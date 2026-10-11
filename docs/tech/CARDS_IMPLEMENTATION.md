# Cartas — implementação da tarefa 1

Implementação de 2026-10-10, a partir de `CODEX_HANDOFF.md` e da secção C
de `docs/design/CARDS_WEAPONS_PERKS.md`. São **39 cartas**: as 12 existentes
reequilibradas, 19 novas sem sistemas adiados, quatro elementos e quatro
melhorias elementais. Os IDs e UIDs das 12 originais mantêm-se.

## Dados e ofertas

Cada recurso `game/data/cards/*.tres` guarda categoria, ícone, etiquetas,
filtros, pré-requisitos e rank máximo. O registo YARD continua a carregar o
catálogo; `GameData.card_category()` lê estes dados. O HUD desenha ícones
vetoriais, mostra ranks até V e permite percorrer builds maiores.

`CardOffers` aplica os filtros antes de usar o seu RNG. Uma oferta de três
garante uma carta nova e uma melhoria, quando ambas existem; os restantes
lugares usam peso ×1,5 para melhorias e ×1,25 para etiquetas partilhadas
com a build. Não há duplicados. Rerolls preferem alternativas dentro de
cada grupo, mantendo as garantias.

**Cartas no rank máximo nunca entram nas ofertas**, incluindo rerolls
e mantimentos. Se só restar uma ou duas cartas elegíveis, aparecem apenas
essas opções; não se preenchem lugares com cartas já maximizadas.

O mantimento tem **um lugar**, por isso sorteia uma carta ponderada entre
as elegíveis. O barco e o acampamento partilham o serviço e a reserva de
rerolls da run. Escolher o mantimento só concede a carta na partida, uma
vez. Sem elegíveis, oferece cura de 20 HP. O estado do RNG atravessa ilhas;
não altera os sorteios de combate ou de rotas.

Bigger Mags exige uma arma finita **entre as armas da run**, conforme o
filtro por armas possuídas do handoff. Ainda não existe seleção persistida
de arma principal/secundária no barco. A carta aumenta capacidade, sem
repor munição. Thick Hide aumenta vida máxima e atual imediatamente, também
quando vem de um mantimento. Vida máxima e XP fracionária passam de ilha
para ilha.

## Fast Learner: ganho e feedback de XP

Fast Learner mantém **+5% de XP recolhida por rank**: rank 4 dá +20% e
rank 5 dá +25%. A fração é acumulada e passa de ilha para ilha; não é
descartada por cada orbe. No rank 4, dez orbes de 1 XP dão 12 XP. Com
Double XP ativo, um orbe de 1 XP dá 2,4 XP nesse rank.

Correção de 2026-10-11: o HUD mostrava só a parte inteira, fazendo um
ganho de 1,2 XP parecer igual a 1 XP. O número e a barra agora incluem
a fração, com até duas casas decimais; aparece também `XP +20%` junto
ao escudo quando se tem a carta no rank 4. O cálculo da recompensa e
o indicador usam o mesmo bónus. Não foram alterados os valores de equilíbrio.

Os testes cobrem ranks 0–5, Double XP, continuidade entre ilhas e a
apresentação de 1,2 XP / +20% e 1,05 XP / +5% no HUD.

Após a mudança de escala de XP de 2026-10-11, um Walker dá 10 XP base,
12 XP no rank IV ou 24 XP com Double XP. Os exemplos de 1 XP acima
continuam a explicar a conservação de frações; os testes também verificam
as novas recompensas reais. Custos e valores atuais estão no
[catálogo de combate](COMBAT_CATALOG.md#escala-de-xp--2026-10-11).

## Recolha automática de XP a partir do nível 30

A partir do **nível 30**, toda a XP no chão da ilha/parte atual é
recolhida automaticamente, independentemente da distância. Abrange os
orbes já existentes ao chegar a esse nível e os novos drops nos passos
seguintes da simulação. Antes do nível 30 mantém-se a recolha por
proximidade e o efeito da carta Magnet.

Quando uma recolha faz passar do nível 29 para o 30, os restantes orbes
são recolhidos antes de abrir as cartas, para a pausa da escolha não
deixar XP por apanhar. Os ganhos mantêm Double XP, Fast Learner com
XP fracionária e a cura de Field Dressing. Cada orbe só é consumido uma
vez; subir de nível e escolher cartas continuam a funcionar normalmente.
O limiar está em `GameData.XP_AUTO_COLLECT_LEVEL`.

## Estados e combinações

Os estados vivem em arrays da `Horde`; ao remover um inimigo, todos os seus
valores acompanham a troca de índice. Fogo e veneno renovam duração sem
acumular dano; o último tick só aplica dano pelo tempo ainda ativo.

- Frio dura 4 s, aplica 15% de lentidão por aplicação e congela à terceira.
  Congelamento consome o frio e impede movimento, ataques e agarres.
- O chefe nunca congela: recebe metade da lentidão, limitada a três
  aplicações (22,5%). O limite evita velocidade negativa em combates longos.
- Ricochetes e descargas escolhem o vizinho vivo mais próximo, até 6 m,
  com linha de visão e sem repetir alvos.
- Wildfire, Deep Freeze, Chain Lightning e Toxic Cloud estão implementadas.
  Também Thermal Shock, Conductive Frost e Toxic Combustion, automáticas.
- Dano secundário não gera novos efeitos secundários de cartas. Assim,
  abates por queimadura, nuvem ou descarga não criam outras nuvens ou
  propagações. As explosões próprias dos Bloaters mantêm o comportamento.

Os inimigos recebem uma cor de estado e ficam imóveis quando congelados;
nuvens tóxicas usam um único MultiMesh. O anel de aviso da granada acompanha
Wide Blast. Este feedback usa primitivas, coerentes com o grey-box atual.

## Verificação

`tests/test_cards_catalog.gd` verifica os filtros, pesos, garantias,
determinismo, esgotamento, um efeito por carta, limites dos efeitos,
estados, combinações, troca de índices, continuidade entre ilhas e
mantimentos no barco e no acampamento. Os testes antigos do catálogo e do
HUD foram atualizados para os novos ranks e para o mantimento de cura.

Os testes adicionais cobrem uma última carta ainda melhorável com o
restante catálogo no máximo, rerolls e a exclusão após escolher o último
rank. Para a XP automática verificam os níveis 29, 30 e 31, a transição
para 30, novos drops, ausência de duplicação, multiplicadores, frações,
cura e continuação dos level-ups. Mudar temporariamente o limiar para
31 provocou seis falhas; o código foi restaurado para 30.

Validação original da tarefa 1: **24/24 testes** (21 do jogo e três dos spikes), sem `TEST FAIL`
ou `SCRIPT ERROR`, conforme o critério do `AGENTS.md`. O bot extraiu nas
seis ilhas das duas runs. A inspeção visual no Godot verificou as 39 cartas
a 1152×648, sem etiquetas fora do painel. Uma alteração temporária da
probabilidade elemental foi detetada pelos testes; o código foi restaurado.

Após as regras de rank máximo e XP automática: **26/26 testes**
(23 do jogo e três dos spikes), sem `TEST FAIL` ou `SCRIPT ERROR`.
As duas runs completas do bot continuaram a extrair. A revisão JEV do
resumo sanitizado destas regras foi inconclusiva; a confirmação assenta
na inspeção local e nos testes.

Limitações da validação: o Godot deste PC terminou os processos com erro
nativo no fecho (`-1073741819`). Durante `--import` houve erros do plugin
Dialogue Manager; os recursos e a classe nova ficaram registados e os
testes de runtime passaram. Não foram alterados addons. A revisão JEV
sobre um resumo sanitizado foi inconclusiva; não recebeu o código privado.

Cartas de escudo, críticos, Lucky Find, Blood Draw, Last Stand, Run and Gun,
evoluções, escolha de armas e árvore de perks continuam fora desta tarefa.
O escudo base foi acrescentado na tarefa seguinte; ver
[power-ups e derrota](POWER_UPS_AND_DEFEAT.md).
