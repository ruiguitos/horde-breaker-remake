# Objetivos por mapa: proposta do Codex (2026-10-11)

Proposta para o utilizador decidir; nada implementado. Pedido do utilizador: cada mapa com objetivos próprios, não só "aterrar, salvar e fugir".

**Recomendação:** dar a cada mapa uma pequena família de objetivos ligada ao seu percurso. Começar por **defesa em sequência, transporte e destruição de ninhos**: acrescentam movimento, logística e ataque.

**Verificação:** li os documentos pedidos, as regras das missões, os recursos, os marcadores e os testes existentes. Não executei Godot nem testes, não alterei ficheiros e não confirmei visualmente as cenas binárias `.scn`. As propostas abaixo precisam de decisão e playtest.

**1. O que existe hoje**

| Missão | Como funciona no código | Utilização |
|---|---|---|
| Activate | Três geradores, **8 s** de proximidade cada; afastar pausa, dano não interrompe; cada início provoca um pico. | Arquipélago; Berlenga P2. [Código:1841](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:1841) |
| Rescue | Encontrar sobrevivente; segue o jogador pelo flow field e sofre dano por contacto. Tem de chegar à saída; se morrer, a extração continua possível, sem recompensa de resgate. | Arquipélago; Berlenga P1. [Escolta:1813](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:1813), [extração:1777](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:1777) |
| Defend | Permanecer num raio de 6 m durante **75 s acumulados**; sair pausa. Picos periódicos, sem equipamento com vida para proteger. | Arquipélago; Berlenga P3. [Código:1801](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:1801) |
| Holdout | Reutiliza Defend durante **90 s**; depois chama o barco, espera **20 s** e permite embarcar. Sem boss. | Berlenga P4; excluído do sorteio. [Tempos:233](/C:/Users/Rui/code/horde-breaker-remake/game/data/game_data.gd:233), [recurso:9](/C:/Users/Rui/code/horde-breaker-remake/game/data/missions/holdout.tres:9) |

No arquipélago, Beach, Coastal Town, Jungle e Industrial Port podem receber Activate/Defend/Rescue; Volcano recebe também uma dessas missões, seguida do Behemoth. Missão e bioma são sorteados separadamente, permitindo repetições consecutivas. [boat.gd:78](/C:/Users/Rui/code/horde-breaker-remake/game/states/boat.gd:78)

As ilhas manuais são escolhidas pelo prefixo do bioma; Hashima entra como Port, sem objetivo próprio. Berlenga tem a sequência fixa Rescue → Activate → Defend → Holdout. [Seleção:206](/C:/Users/Rui/code/horde-breaker-remake/game/world/handmade/handmade_island.gd:206), [expeditions.gd:13](/C:/Users/Rui/code/horde-breaker-remake/game/data/expeditions.gd:13)

**Porque parecem semelhantes:** Rescue/Defend usam o gerador mais distante do barco quando falta um marcador específico; Defend/Holdout partilham a mesma lógica; todos convergem para objetivo → possível boss → saída. Os marcadores `Choke_*` e `Arena_*` existentes não alimentam objetivos. [Local:545](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:545), [fases:1734](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:1734), [marcadores:149](/C:/Users/Rui/code/horde-breaker-remake/game/world/handmade/handmade_island.gd:149)

Os documentos antigos propõem Forest/Cliffs e outros templates; não descrevem o catálogo atual. Activate documentado exige 20 s e interrupção por dano, divergindo da implementação. [Design:205](/C:/Users/Rui/code/horde-breaker-remake/docs/design/WORLD_AND_MISSIONS.md:205)

**2. Catálogo proposto**

Custos relativos: **S** extensão pequena; **M** sistema reutilizável; **L** navegação/combate/arte adicionais. Pilares aprovados: **H** romper a horda; **I** cada ilha é uma decisão; **B** builds que mudam a forma de jogar. [DECISIONS:25](/C:/Users/Rui/code/horde-breaker-remake/docs/DECISIONS.md:25)

| Objetivo | Como se joga | Marcadores necessários | Sistemas novos | Custo / pilar |
|---|---|---|---|---|
| Segurar pontos em sequência | Defender brevemente A→B→C; atravessar a horda entre posições. | `HoldPoint_*`, ordem | Fases, progresso por ponto | S / H |
| Transportar combustível | Levar bidões de locais dispersos ao barco; largar para combater. | `Cargo_*`, `Delivery` | Carga, entrega, penalização ligeira de movimento | M / I,H |
| Destruir ninhos | Escolher a ordem; cada ninho vivo alimenta a horda. | `Nest_*`, saídas de spawn | Alvos estáticos com vida, integração com armas e diretor | M / H,B |
| Escoltar por percurso | Sobrevivente/carrinho avança por etapas; jogador abre caminho e protege paragens. | `EscortRoute_*`, `EscortStop_*` | Navegação entre destinos, dano e bloqueio | M sobrevivente; L carrinho / H |
| Acender sinais/farol | Obter alimentação e ligar um sinal que ilumina/orienta a zona seguinte. | `Signal_*`, `Fuel_*` | Dependências, efeitos de luz e estado | M / I |
| Procurar Intel | Escolher edifícios a pesquisar antes de terminar o tempo; recompensa parcial. | `Search_*`, `IntelDrop` | Locais sorteados, temporizador, resultados | S nas entradas; L interiores / I |
| Sabotar/reparar indústria | Cortar alimentação num extremo e intervir no motor no outro. | `PowerSwitch`, `Machine`, `RepairPart_*` | Cadeia de estados e reação da horda | M / I,H |
| Cobrir barco em aproximação | Combater no cais enquanto o barco percorre uma rota automática. | `BoatRoute_*`, `PierDefense_*` | Vida do casco, ataques à distância, rota | M–L / H,B |
| Alcançar altura e extrair | Abrir caminho pelas rampas, preparar ancoragem e resistir até subir a corda. | `Ascent_*`, `RopeExit` | Extração alternativa e animação simples | M / H |
| Sobreviver com luz limitada | Circular entre zonas iluminadas e recuperar combustível para manter sinais. | `LightZone_*`, `Fuel_*` | Luz como recurso; legibilidade nas três câmaras | M–L / I,H |
| Caçar boss com pistas | Seguir rastos entre zonas; encontrar e enfrentar o alvo numa arena adequada. | `Track_*`, `BossArena_*` | Pistas, fases de localização e encontro | M / H,B |

Ninhos exigem trabalho real: a seleção de alvos atual consulta inimigos da horda. [island_run.gd:1061](/C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:1061)

**3. Distribuição proposta por mapa**

| Mapa | Objetivos que aproveitam o lugar |
|---|---|
| Beach | Transportar combustível da aldeia/dunas ao barco; alternativa: acender sinal junto da torre elevada. |
| Coastal Town | Procurar Intel nas entradas das casas/mercado → transmitir na praça ou igreja. |
| Jungle | Destruir ninhos junto das ruínas e clareira; alternativa: caçar elite através do circuito ponte–templo. |
| Industrial Port | Escoltar carrinho entre armazéns/contentores → entrega no cais; alternativa: recolher peças e reparar maquinaria. |
| Volcano | Destruir ninhos junto das lagoas de lava → enfrentar Behemoth numa arena afastada delas. |
| Hashima | Sabotar alimentação e motor do tapete transportador → retirada pelo percurso costeiro junto ao paredão até Dolphin Pier; alternativa: pesquisar entradas dos blocos usando escadas entre níveis. |
| Berlenga P1 — Carreiro/Bairro | Procurar equipamento no Bairro dos Pescadores → escoltar sobrevivente com paragens no caminho de subida. |
| Berlenga P2 — Farol | Transportar alimentação das casas dos faroleiros → acender o farol, com combate no exterior. |
| Berlenga P3 — Costa Sudoeste | Segurar dois pontos de observação em sequência → acender sinal costeiro e seguir a pé para o forte. |
| Berlenga P4 — Forte | Defender pátio para chamar resgate → cobrir aproximação do barco desde posições junto das escadas/cais. |

As quatro cenas manuais do arquipélago são mapas de teste; não confirmei nelas geografia real. Hashima e Berlenga têm traçado baseado em dados reais. Os pontos das propostas terão de respeitar a grelha existente. O tapete transportador está elevado; os edifícios não têm interiores jogáveis confirmados. [Hashima:109](/C:/Users/Rui/code/horde-breaker-remake/tools/real_island/build.gd:109), [limites:309](/C:/Users/Rui/code/horde-breaker-remake/tools/real_island/README.md:309)

**4. Regras de variedade**

- Selecionar primeiro o mapa; depois objetivos compatíveis com os seus marcadores. Impedir repetição consecutiva, incluindo famílias equivalentes como Defend/Holdout.
- Anunciar objetivo, modificador e recompensa antes da escolha. Seed determina locais, variantes e ordem permitida.
- Fazer modificadores interagir: nevoeiro valoriza sinais; escassez aumenta o valor de transporte; elites complicam escoltas. Noite seria novidade.
- Acrescentar um desvio opcional: cache, ninho extra ou sobrevivente secundário; recompensa em Intel, munições ou power-up recolhível.
- Garantir recuo nos gargalos e falha recuperável, sem bloquear transições da Berlenga. Manter transporte, investigação e combate legíveis nas três câmaras.

**5. Primeiro passo e sequência**

1. **Defesa sequencial (S):** experimentar na Costa Sudoeste; validar ordem, pausa e extração bloqueada até conclusão.
2. **Transporte (M):** combustível na Beach; validar recolha, largada em terreno transitável, entrega única e recompensa.
3. **Ninhos (M):** Jungle; validar mira automática/crosshair, dano, spawns locais e conclusão.

Alterações: `island_map.gd`, `handmade_island.gd`, `island_run.gd`, recursos `missions*`, `game_data.gd`, apresentação em `island.gd`/HUD/minimapa e seleção em `boat.gd`. Para Berlenga, atualizar também `expeditions.gd` e os presets de `tools/real_island/build.gd`; não editar `DECISIONS.md`.

Depois: pesquisa/sinais → sabotagem Hashima → escolta por percurso → caça → barco/corda/noite.

Alargar `test_island_run.gd`, `test_handmade.gd`, `test_data.gd`, `test_expedition_missions.gd`, `test_expedition.gd` e `test_power_ups.gd`; acrescentar testes de seleção determinística e compatibilidade. O teste antigo do forte aponta para uma cena retirada: corrigir esse caminho para evitar um *skip* enganador. [Teste:332](/C:/Users/Rui/code/horde-breaker-remake/tests/test_expedition_missions.gd:332)

JEV não estava disponível; esta avaliação resulta da inspeção local.



## Escolha do utilizador (2026-10-11)

O utilizador aprovou o catálogo, a distribuição por mapa e o primeiro passo: segurar pontos em sequência, depois transportar combustível, depois destruir ninhos. Pediu também que os elementos do mundo (casas, barcos, carrinhos, etc.) sejam realistas.

## Estado (2026-10-11)

**Passo 1 feito: Hold Sequence** (`game/data/missions/hold_sequence.tres`:
3 pontos, 20 s cada, raio 5 m). Os pontos seguram-se por ordem; sair pausa o
ponto; cada ponto começa com um pico da horda; a extração só abre no fim.
Marcadores `HoldPoint_1..` (ordem pelo número); sem eles, o jogo escolhe
pontos alcançáveis e afastados, fixos por seed. Entra no sorteio do barco,
que já não repete a missão anterior (Defend e Holdout contam como a mesma
família). A Berlenga P3 (Costa Sudoeste) usa-a com três marcadores reais.
Testes: `tests/test_hold_sequence.gd`.

**Passo 2 feito: Fuel Run** (`game/data/missions/fuel_run.tres`). Números
(todos no `.tres`, para afinar em playtest):

| Valor | Número | Porquê |
|---|---|---|
| Bidões | 3 | Igual aos geradores e aos pontos: três idas e voltas. |
| Raio de recolha | 1,8 m | Apanha-se ao passar por cima, sem apanhar por acidente do outro lado de uma parede. |
| Raio de entrega | 6 m | Maior do que o anel do barco (4 m): entrega-se ao chegar, a extração pede mais um passo. |
| Velocidade com bidão | ×0,8, sem sprint | Penalização ligeira: a horda apanha-te se não limpares o caminho. |
| Pico ao pegar | 20 s | Só na primeira vez de cada bidão; pegar de novo não chama a horda. |
| Sorteio | peso 3 na Beach, 1 nas outras | Na Beach sai em cerca de 43 % das rotas (3 em 7), nas outras 20 % (com os Nests no sorteio: 38 %, 3 em 8, e 17 %). |

Regras: um bidão de cada vez; com ele não se dispara, não se corre e não se
usa a habilidade da classe (o Breaker continua: é a fuga). A tecla nova
`interact` (E / X no comando) pousa o bidão aos pés, em terreno transitável
(em noclip, no último sítio onde se pisou chão), para combater; a tecla da
habilidade também o pousa. O bidão pousado não é reapanhado ao ficar em cima
dele, só depois de te afastares (ou com E). Entrega a 6 m do barco (ou do
`Exit` numa parte de expedição, ou de um marcador `Delivery`); a extração
só abre com todos entregues, e cada entrega repõe um terço da munição.
Marcadores `Cargo_1..` e `Delivery`; sem eles, o jogo escolhe sítios como
no Hold Sequence (alcançáveis, a 30 m ou mais do barco, afastados entre si,
fixos por seed, com outra "sal" na seed para não coincidirem). Morrer com o
bidão termina a ilha como sempre; um Quick Redeploy cria a ilha de novo com
os bidões no sítio. Visual: bidão Poly Haven (ou caixa laranja sem o
modelo) com um farol enquanto está no chão, levado na mão direita do
soldado nas três câmaras; anel laranja no ponto de entrega; minimapa com
`FUEL` e `DELIVERY`; HUD `FUEL 1 / 3`. Ainda nenhuma ilha tem marcadores
`Cargo_*` (usa-se o recurso automático). Testes: `tests/test_fuel_run.gd`
(inclui um bot que completa a missão; na Beach a T2 precisou de 499 s e de
70 pousos para combater: vale a pena confirmar o ritmo em playtest).

**Passo 3 feito: Nests** (`game/data/missions/nests.tres`). Números (todos
no `.tres`, para afinar em playtest):

| Valor | Número | Porquê |
|---|---|---|
| Ninhos | 3 | Igual aos geradores, pontos e bidões. |
| Vida | 600 × escala de vida dos inimigos | Escala com a ameaça e o número da ilha como todos os inimigos (ilha 1, ameaça 1: 600; ilha 3, ameaça 3: 1344). Com a espingarda são cerca de 6 s de fogo contínuo (108 de dano/s), mais recargas. |
| Raio | 1,4 m (altura 1,8 m) | Um alvo grande, fácil de acertar nas três câmaras; é sólido para o jogador. |
| Ninhada | 2 inimigos a cada 7 s | Pressão local pequena: obriga a escolher a ordem, não inunda o mapa. |
| Limite por ninho | 6 inimigos a menos de 12 m | Um ninho ignorado não cria um exército. |
| Raio de acordar | 45 m | Só os ninhos perto de ti soltam inimigos (os de longe perder-se-iam no caminho ou seriam reciclados nas ilhas grandes). |
| Prioridade dos inimigos | 8 m | Um inimigo a menos de 8 m é sempre o alvo antes do ninho. |
| Pico ao destruir | 12 s | Curto: a ninhada à volta "entra em pânico". |
| Recompensa | um power-up | Sai sempre ao destruir um ninho, se não houver já um no chão (não substitui). Mais 15 de Intel por ninho, como cada passo das outras missões. |
| Sorteio | peso 3 na Jungle e no Vulcão, 1 nas outras | Na Jungle e no Vulcão sai em cerca de 38 % das rotas (3 em 8), nas outras 17 % (1 em 6). |

Regras: os ninhos entram no mesmo caminho de dano dos inimigos, sem um
sistema à parte. A escolha de alvo (`_pick_target`) pode devolver um ninho
(um id negativo, `nest_target(n)`); cada chumbo verifica se tem um ninho na
linha (`_pellet_nest_hit`) e pára nele se ainda lhe restar perfuração (a
espingarda, perfuração 1, acerta no inimigo à frente do ninho; a marksman,
perfuração 6, atravessa-o e acerta no ninho); a granada e o impacto do
Breaker ferem os ninhos no seu raio. Os ninhos não sofrem headshots,
elementos (fogo, gelo, veneno, choque), Insta-Kill nem Nuke: são montes, não
corpos.

Regra de prioridade (para não ficar a disparar contra o ninho enquanto te
comem): na câmara fixa, um inimigo a menos de 8 m ganha sempre; mais longe,
o ninho só ganha se tiver melhor pontuação que o melhor inimigo, com +4 m de
penalização (é preciso estar mesmo virado para ele). Nas câmaras com mira, o
ninho é o alvo quando a mira está nele, a não ser que um inimigo debaixo da
mira esteja a menos de 8 m ou à frente do ninho na mesma linha.

A ninhada usa `director.pick_kind()` e os limites globais
(`director.max_alive` e `GameData.MAX_ALIVE`), nada durante o atraso de
spawn de um Nuke, e não passa pelos spawns em anel à volta do jogador (a
regra dos sectores fica igual). O jogador não atravessa um ninho vivo. A
extração só abre com os três destruídos; morrer termina a ilha como sempre;
um Quick Redeploy (ou outra missão no mesmo `IslandRun`) repõe tudo.
Marcadores `Nest_1..`; sem eles, o jogo escolhe sítios como no Hold Sequence
(alcançáveis, a 30 m ou mais do barco, afastados, fixos por seed, outra
"sal", 4 m livres à volta, fora da lava). Visual: monte escuro com cinco
caroços e um núcleo emissivo que pulsa (mais depressa com menos vida) e
pisca a branco quando leva tiros; o monte encolhe com o dano; barra de vida
virada para a câmara (só a menos de 40 m e depois de ferido); ao morrer,
estoira em pedaços e deixa uma mancha queimada. HUD `NESTS 1 / 3`, marcador
no ninho mais próximo com a vida (`NEST 72 % · 9 m`), minimapa `NEST`.
Ainda nenhuma ilha tem marcadores `Nest_*`. Testes: `tests/test_nests.gd`
(inclui um bot que completa a missão na Jungle e no Vulcão, ameaça 2: 118 s
e 95 s).

Também: na Fuel Run, com o bidão nas mãos o espaço da habilidade no HUD diz
`DROP CAN` (com o ícone esbatido) em vez de `READY`, porque a tecla só pousa
o bidão.

**Passo 4 feito: Intel Search** (`game/data/missions/intel_search.tres`;
no catálogo, "Procurar Intel"). Números (todos no `.tres`, para afinar em
playtest):

| Valor | Número | Porquê |
|---|---|---|
| Sítios / intel | 5 sítios, 3 com intel | Oferecer mais sítios do que os precisos é o que torna a procura uma escolha: quais têm intel é sorteado pela seed e só se sabe ao procurar. Em média, encontrar as três pede 4,5 procuras. |
| Procura | 4 s a menos de 2,5 m | Curta como um gerador pequeno: dá para procurar no meio da horda, mas não a correr. Sair pausa (o progresso fica); levar dano não interrompe, como no Activate. |
| Pico ao procurar | 8 s, um por sítio | Curto, para não encadear cinco picos longos; só a primeira entrada em cada sítio chama a horda. |
| Tempo | 120 s desde o desembarque | O bot (invencível, ameaça 2) procura os cinco sítios em 85–88 s; 120 s dá cerca de 1,4× isso a quem tem de combater. Ao acabar, fica-se com a intel encontrada (recompensa parcial). |
| Transmissão | 15 s a menos de 5 m da antena, pico de 25 s | Uma segunda fase curta, ao estilo do Hold Sequence; sair pausa. A saída só abre depois. |
| Zero intel | sem transmissão | Se o tempo acaba sem nada, a saída abre logo, sem bónus: falha recuperável, nunca fica bloqueado. |
| Recompensa | 15 de Intel por intel encontrada | Igual a cada passo das outras missões (3 × 15 = 45). Conta logo ao encontrar; o painel do fim da ilha mostra-a no total `INTEL EARNED` (não tem linhas por recompensa). |
| Sorteio | peso 3 na Coastal Town, 1 nas outras | Com sete missões nas rotas, cada "casa" sai em cerca de 33 % das suas rotas (3 em 9) e 11 % nas outras; no Industrial Port, sem missão "da casa", cada uma sai em 14 % (1 em 7). Isto também baixa a Fuel Run e os Nests na Coastal Town (de 17 % para 11 %). |

Regras: o tempo só corre na fase de procura (pausa com as cartas, como
tudo); encontrar as três antes do fim passa logo à transmissão. Marcadores
`Search_1..` (ordem pelo número; idealmente à porta das casas/mercado) e
`Uplink` (praça ou igreja). Sem `Search_*`, o jogo escolhe sítios como no
Hold Sequence (alcançáveis, a 30 m ou mais do barco, afastados, fixos por
seed, outra "sal", 2 m livres) mas só a menos de 3 m de um edifício ou
rocha (os retângulos `map.buildings`, ignorando os de mais de 60 m, que são
terreno); numa ilha sem edifícios suficientes, em qualquer lado. Sem
`Uplink`, o ponto aberto (5 m livres) mais perto do meio dos sítios, a pelo
menos 10 m de cada um. Morrer termina a ilha como sempre; um Quick Redeploy
(ou outra missão no mesmo `IslandRun`) repõe tudo, com os mesmos sítios e a
mesma intel escondida. Visual: caixote Poly Haven (ou caixa castanha) com
farol violeta e anel do raio; um disco cresce com a procura; sítio vazio
fica cinzento, sítio com intel fica com disco verde; antena com prato e luz
a piscar, anel e disco de progresso na transmissão. HUD
`INTEL 1 / 3 · 1:42` (depois `TRANSMIT INTEL 2 / 3`), marcador no sítio
por procurar mais perto (`SEARCHING · 63 %` dentro dele) ou na antena
(`TRANSMITTING · 40 %`), minimapa `SEARCH` e `UPLINK`. Ainda nenhuma ilha
tem marcadores `Search_*`/`Uplink`. Testes: `tests/test_intel_search.gd`
(inclui um bot na Coastal Town e na Beach, ameaça 2: extração em 132–137 s;
a horda chega ao limite de 150 vivos durante a transmissão, a confirmar em
playtest).

**Passo 5 feito: Light the Signals** (`game/data/missions/signals.tres`,
id `signals`; no catálogo, "Acender sinais/farol"). Números (no `.tres` e,
os do transporte, no `fuel_run.tres`, para afinar em playtest):

| Valor | Número | Porquê |
|---|---|---|
| Sinais | 3, acesos por ordem | Igual às outras missões. Só o **próximo** sinal (e o seu combustível) aparece no HUD, no minimapa e no mundo; os seguintes ficam escondidos até o anterior acender. É isto que faz o sinal "orientar para a zona seguinte". |
| Combustível | 1 bidão por sinal, a 15–30 m dele | Perto o bastante para ser "o combustível daquele sinal", longe o bastante para obrigar a uma ida e volta carregado. Também a no máximo 60 m a pé (não do outro lado de uma parede) e a 15 m ou mais de qualquer outro sinal. |
| Transporte | as regras da Fuel Run | O mesmo código: um bidão de cada vez, ×0,8, sem disparar, sem sprint, sem habilidade; `interact` (E / X) ou a tecla da habilidade pousam-no; o HUD diz `DROP CAN`. Só o bidão do próximo sinal se pode apanhar. |
| Acender | 6 s a menos de 4 m, com o combustível lá dentro | Curto: o esforço está no transporte. Sair pausa (o progresso fica); levar dano não interrompe, como no Activate. Sem combustível, ficar no sinal não faz nada. O bidão é despejado ao chegar a 4 m do sinal. |
| Pico | 15 s, ao começar a acender | Apanhar o bidão não chama a horda (ao contrário da Fuel Run); acender sim: é o fogo que a atrai. Um pico por sinal. |
| Recompensa | 15 de Intel por sinal e ⅓ da munição | Como cada passo das outras missões. |
| Sorteio | peso 1 em todo o lado | Não tem bioma "da casa". Com oito missões nas rotas, sai em 10 % das primeiras ilhas nas Beach, Coastal Town, Jungle e Vulcão (onde a missão da casa tem 30 %) e em 12,5 % no Industrial Port. Baixa as outras de 11 % para 10 % (14 % para 12,5 % no Port). |

Regras: um sinal aceso fica aceso (fogo e luz), devolve um terço da munição
e revela o seguinte; a extração só abre depois do último. Morrer termina a
ilha como sempre; um Quick Redeploy (ou outra missão no mesmo `IslandRun`)
repõe tudo, com os mesmos sinais e bidões. Marcadores `Signal_1..` (ordem
pelo número), `Lighthouse` (opcional: é o último sinal, versão farol) e
`Fuel_1..` (o combustível do sinal com o mesmo número; o do farol é o
último); sem `Signal_*`, o jogo escolhe sítios como no Hold Sequence
(alcançáveis, a 30 m ou mais do barco, afastados, fixos por seed, outra
"sal", 3 m livres), ordenados pela distância a pé desde o desembarque, por
isso cada sinal fica mais para dentro do que o anterior; sem `Fuel_*`, o
bidão de cada sinal vai para o primeiro sítio da lista (alcançável, 2 m
livres) dentro da faixa de 15–30 m. Se não houver nenhum, fica o sítio mais
perto do meio da faixa; se nem isso, o próprio sinal (nunca bloqueia).

Código partilhado com a Fuel Run (refatorado, não duplicado): os bidões são
os mesmos `cargo_pos`/`cargo_state`/`carrying` do `IslandRun`;
`_update_carry()` faz o transporte e a entrega das duas missões,
`can_available()` diz que bidão se pode apanhar e `uses_cargo()` liga o
`interact`. No `IslandMap`, a procura dos candidatos dos pontos passou para
`_hold_candidates()`, usada pelo `pick_hold_points` (mesmos resultados) e
pelo `pick_signal_fuel_points`.

Visual: pedestal de pedra com uma taça de ferro e lenha; enquanto é o
próximo, um farol amarelo-claro por cima (fica cor de fogo quando tem o
combustível), o anel do raio e um disco que cresce ao acender. Aceso: duas
chamas emissivas que tremeluzem e uma `OmniLight3D` sem sombras (14 m de
alcance; uma por sinal, desligada até acender). O farol põe o fogo no topo
da torre do cenário (`Buildings/Lighthouse_*` a menos de 40 m do marcador)
ou, se não houver, numa torre de pedra de 9 m, com uma luz de 45 m e um
feixe de 36 m que roda. HUD `SIGNALS 1 / 3` (`FUEL TO SIGNAL 2 · [E] DROP`,
`LIGHT SIGNAL 2 · 3 OF 6 s`, `FIND THE FUEL FOR SIGNAL 2`), marcador no
bidão ou no sinal (`LIGHTING · 40 %` dentro dele), minimapa `SIGNAL`,
`FUEL` e `LIT` (os sinais acesos ficam no mapa, como um rasto).

**Berlenga P2 (Planalto do Farol) passou de Activate para Light the
Signals**, como no catálogo ("transportar alimentação das casas dos
faroleiros → acender o farol"): `Signal_1` a leste (745, 665) e `Signal_2`
a sudoeste (675, 674), onde estavam os geradores 3 e 2, e depois o
`Lighthouse` ao pé da torre real (4,6 m do centro dela; o fogo vai para o
topo da torre, 27 m acima do chão). Os três `Fuel_*` ficam à porta das casas
do conjunto do farol (4 a 5 m de cada casa), por isso cada ida atravessa o
pátio. O percurso na grelha passou de 583 m para 858 m (138 + 97 + 75 + 46 +
67 + 41 + 394): mais longo, a confirmar em playtest.

Testes: `tests/test_signals.gd` (inclui um bot na Beach, Coastal Town e
Jungle, ameaça 2: extração em 89–118 s, sinais acesos aos 19–29 s, 40–58 s e
67–83 s, sem precisar de pousar o bidão; a horda chega ao limite de 150 vivos,
a confirmar em playtest).

**Passo 6 feito: Sabotage** (`game/data/missions/sabotage.tres`, id
`sabotage`; no catálogo, "Sabotar/reparar indústria", a assinatura da
Hashima). Números (todos no `.tres`, para afinar em playtest):

| Valor | Número | Porquê |
|---|---|---|
| Fase 1: cortar a energia | 8 s a menos de 4 m do quadro, pico de 20 s | Como um gerador do Activate: o primeiro passo é ir ao quadro e aguentar lá. Sair pausa (o progresso fica); levar dano não interrompe. O pico cobre o corte e o caminho para as máquinas. |
| Fase 2: armar as cargas | 2 cargas, 5 s cada a menos de 3 m, pico de 12 s por carga | Só depois do corte (com a energia ligada, ficar na máquina não faz nada). Pela ordem que quiseres; cada uma guarda o seu progresso. Duas chegam: "alimentação e motor", como no catálogo. |
| Fase 3: rastilho | 20 s | Curto o bastante para obrigar a sair a correr, longo o bastante para sair dos 15 m mesmo com a horda à volta (a 6 m/s são 2,5 s). A saída abre logo ao armar a última carga. |
| Explosão | 15 m de cada carga, 60 % da vida máxima | Dano pesado, não morte instantânea: de vida cheia nunca mata (o escudo absorve primeiro), mas com menos de 60 % mata, e morrer termina a ilha como sempre. Mata os inimigos dentro do raio (não o Behemoth). |
| Fuga antes do fim | ganha logo | Chegar à saída antes de o rastilho acabar ganha a ilha; as cargas rebentam atrás de ti, sem dano. Nunca fica bloqueado: depois da explosão a saída continua aberta. |
| Recompensa | 15 de Intel pelo corte e 15 por carga (45), ⅓ da munição em cada passo | Igual às outras missões. |
| Sorteio | peso 3 no Industrial Port, 1 nas outras | O Port passa a ter missão "da casa". Com nove missões nas rotas todos os biomas somam 11: a missão da casa sai em 27,3 % das primeiras ilhas (3 em 11) e cada uma das outras em 9,1 % (1 em 11). Antes era 30 % / 10 %, e 12,5 % para cada missão no Port. |

Regras: as três fases correm no `IslandRun` (`sabotage_phase`: `SAB_POWER`,
`SAB_CHARGES`, `SAB_FUSE`, `SAB_BLOWN`). O rastilho conta em qualquer
objetivo (também durante o Behemoth, na última ilha). Morrer termina a ilha
como sempre; um Quick Redeploy (ou outra missão no mesmo `IslandRun`) repõe
tudo, rastilho incluído, com o mesmo quadro e as mesmas máquinas.
Marcadores `PowerSwitch`, `Machine_1..` (ordem pelo número) e `ExfilPoint`
(opcional: a saída da Sabotage; um `Exit` de expedição ganha-lhe). Sem
`PowerSwitch`, o jogo escolhe um candidato dos pontos do Hold Sequence
(alcançável, a 30 m ou mais do barco, 4 m livres, outra "sal") a pelo menos
60 % da maior distância a pé desde o desembarque: fundo na ilha, mas não
sempre o mesmo sítio. Sem `Machine_*`, as máquinas ficam a 30–60 m do quadro
e a 12 m ou mais uma da outra (se não houver, as mais perto do meio da
faixa; se nem isso, o próprio quadro). Sem `ExfilPoint`, sai-se pelo barco.
Nas ilhas geradas e nas quatro ilhas manuais de teste, as 20 + 8 máquinas
de teste ficaram todas na faixa.

**Hashima escolhida pela missão (decisão de implementação).** A missão é
sorteada no barco antes de se saber a ilha (aparece no cartão da rota e no
briefing), por isso não se muda depois. Em vez de a ilha declarar a missão
(o que obrigava a carregar todas as cenas do bioma para decidir), é a
missão que declara as ilhas: `preferred_islands = ["port_hashima"]` no
`sabotage.tres`. `HandmadeIsland.pick(bioma, seed, missão)` só escolhe entre
essas quando existem no bioma; as outras missões continuam a sortear entre
`port_01` e Hashima. Assim, uma rota Port com Sabotage leva sempre à
Hashima (cerca de 3 em cada 10 rotas Port: 72 de 234 no teste do barco,
que já exclui a missão anterior), e a Hashima continua a jogar as
outras missões (e mantém os 3 geradores do Activate).

**Hashima reconstruída** (`tools/real_island/build.gd`, preset `sabotage`):
`PowerSwitch` na subestação (変電所) junto ao poço 4, no extremo norte da
zona do carvão; `Machine_1` no chão depois do último pilar do tapete
transportador elevado; `Machine_2` à porta da sala de carregamento (詰込室).
Sem `ExfilPoint`: o `Boat` já está no cais Dolphin, e a retirada pelo
percurso junto ao paredão é o caminho natural das cargas ao barco. Percurso
na grelha: 239 m do desembarque ao quadro, 101–106 m do quadro às máquinas,
14 m entre elas, 131–136 m das máquinas ao barco. A reconstrução só alterou
o `port_hashima.scn` (mais 3 marcadores); terreno, texturas e grelha ficaram
iguais byte a byte.

Visual (primitivas): armário cinzento com alavanca e luz (verde com
energia, vermelha depois do corte), farol ciano, anel do raio e disco que
cresce. Cada máquina: caixa do motor com tambor, luz âmbar com uma
`OmniLight3D` sem sombras (9 m) que se apaga com o corte, farol vermelho,
anel e disco; a carga (bloco vermelho) aparece ao ser armada e pisca cada vez
mais depressa no rastilho, com um anel vermelho de 15 m à volta de cada
carga. Na explosão: esferas de explosão em cada carga, estilhaços, pó, as
máquinas desaparecem e fica uma mancha queimada; a câmara treme a até 60 m.
Som: o do gerador no corte e o da explosão; não há zumbido contínuo das
máquinas (não existe som para isso). HUD `CUT THE POWER` (`AT THE SWITCH ·
3 OF 8 s`), `CHARGES 1 / 2` (`PLANT ON THE MACHINE`), `GET CLEAR · 14 s`
(`BLAST 15 m · YOU ARE IN THE BLAST` / `CLEAR`), marcador
`CUTTING POWER · 40 %`, `PLANTING · 60 %` e, no rastilho, `BOAT · 80 m ·
14 s`; minimapa `SWITCH`, `MACHINE`, `CHARGE` e `EXFIL`.

Testes: `tests/test_sabotage.gd` (inclui bots invencíveis, ameaça 2:
Hashima 81 s, Port gerado 69 s, Beach 92 s, Town 88 s; energia cortada aos
28–40 s, cargas armadas aos 56–65 s; o bot nunca foi apanhado pela
explosão; a horda chega ao limite de 150 vivos, a confirmar em playtest).

Para testar no editor (Windows): TEST ISLAND → `PORT_HASHIMA` com
`MISSION: SABOTAGE`, nas três câmaras; confirmar que se vê o quadro e as
máquinas no meio dos prédios, que as luzes se apagam no corte, e se o
rastilho de 20 s e o raio de 15 m são justos com a horda a sério.

Próximo passo (do catálogo): escolta por percurso.
