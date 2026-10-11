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
Testes: `tests/test_hold_sequence.gd`. Próximo passo: transporte de
combustível na Beach.
