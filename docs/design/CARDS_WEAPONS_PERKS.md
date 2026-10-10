# Cartas, armas e perks: proposta do Codex (2026-10-10)

Proposta de design para o utilizador decidir; nada disto está implementado.
Feita pelo Codex a ler o código; os valores são hipóteses de playtest.
Complementa `PROGRESSION_AND_ECONOMY.md` §1.6 (P9).

Proposta para decisão: **48 cartas, Assault Rifle como arma principal recomendada e árvore de melhorias que conserva os perks em slots**. Valores novos são hipóteses para playtest.

Inspeção estática apenas; sem alterações nem execução do Godot. JEV indisponível. Referências abreviadas: `C/` = `game/data/cards/`; `W/` = `game/data/weapons/`; `P/` = `game/data/perks/`; `I` = `game/world/island_run.gd`.

**A. Cartas atuais**

Todas podem aparecer para ambas as classes; a dependência abaixo indica onde têm efeito. Os 12 recursos totalizam 22 ranks.

| ID | Nome | Efeito por rank | Máx. | Dependência | Evidência |
|---|---|---|---:|---|---|
| hollow_points | Hollow Points | +25% dano | 3 | Todas as armas | C/hollow_points.tres:7; I:799 |
| fast_hands | Fast Hands | +20% cadência | 3 | Todas as armas | C/fast_hands.tres:7; I:653 |
| ricochet | Ricochet | Cada 4.º tiro: acerto adicional, dano base, ≤6 m | 1 | Todas as armas | C/ricochet.tres:7; I:815 |
| explosive_heads | Pop Goes the Head | Abate por headshot: explosão, 30 dano/3 m | 1 | Headshots | C/explosive_heads.tres:7; I:859 |
| vampire | Field Medic | Abate por headshot: cura 2 HP | 2 | Headshots | C/vampire.tres:7; I:857 |
| magnet | XP Magnet | Raio de atração ×2: 3→6 m | 1 | Geral | C/magnet.tres:7; I:899 |
| quick_breaker | Hair Trigger | Cooldown ×0,7 por rank | 2 | Breaker | C/quick_breaker.tres:7; I:473 |
| shockwave | Shockwave Breaker | +30 dano; raio ×2 desde rank 1 | 2 | Breaker | C/shockwave.tres:7; I:616,645 |
| adrenaline | Adrenaline | Cada abate retira 0,3 s ao cooldown | 1 | Breaker | C/adrenaline.tres:7; I:841 |
| executioner | Executioner | +60% dano contra atordoados | 2 | Qualquer dano | C/executioner.tres:7; I:834 |
| bigger_mags | Bigger Mags | +30% capacidade, truncada para inteiro | 2 | Armas com munição finita | C/bigger_mags.tres:7; I:275 |
| grenadier | Grenadier | Cooldown da granada ×0,8 por rank | 2 | Recruit | C/grenadier.tres:7; I:291 |

Ricochet promete o inimigo mais próximo, mas escolhe o primeiro elegível devolvido pela pesquisa. Bigger Mags aumenta capacidade; não repõe munição.

**B. Cartas noutros jogos**

Síntese de conhecimento, sem consulta externa neste trabalho; não pretende descrever patches atuais. VS = Vampire Survivors; DRGS = Deep Rock Galactic: Survivor; RoR2 = Risk of Rain 2.

| Mecânica | Referências seguras |
|---|---|
| Efeitos por acerto | RoR2: mísseis, hemorragia; Brotato: roubo de vida |
| Elementos/estados | 20 Minutes Till Dawn: fogo, gelo, relâmpagos; DRGS: melhorias elementais; Halls of Torment: queimadura/eletrificação |
| Proteção | RoR2: escudo recarregável e barreira temporária; Halls of Torment: bloqueio |
| Recuperação | Brotato: regeneração/roubo de vida; VS: cura e Bloody Tear |
| Mobilidade | Hades: melhorias do dash; Brotato: velocidade/esquiva |
| XP/recolha | VS: Attractorb/Crown; DRGS: alcance de recolha e XP |
| Críticos | Brotato, Halls of Torment, RoR2: probabilidade e/ou multiplicador |
| Correntes/perfuração/ricochete | RoR2: Ukulele; 20 Minutes: penetração/ricochete |
| Evoluções | VS: arma melhorada + requisito; DRGS: overclocks transformadores |
| Sinergias/duos | Hades: bênçãos dos deuses e duos com pré-requisitos; 20 Minutes: melhorias combinadas |
| Maldições/trocas | VS: Curse; Hades: Chaos; RoR2: Shaped Glass; DRGS: overclocks com penalizações |

Em Hades, Chill, Hangover e relâmpagos são comportamentos distintos; não constituem uma grelha universal de elementos. Megabonk/Hades II ficam fora: confiança insuficiente nos detalhes.

**C. Proposta de catálogo**

**48 cartas, incluindo as 12 atuais.** Preservar IDs; os valores seguintes substituem os atuais quando aprovados. `r` = rank; percentagens acumulam aditivamente salvo indicação. † = sistema novo.

Categoria/filtro: **AR** Assault Rifle; **E** Elements, apenas AR; **D** Defense/Shields; **S** Sustain; **U** Utility/XP; **B** Breaker; **R** Class: Recruit; **V** Class: Vanguard. AR/E/D/S/U/B servem ambas as classes. Melhorias dependentes exigem a carta-base; Bigger Mags exige arma finita equipada.

| Cat. | Nome | Efeito por rank | Máx. |
|---|---|---|---:|
| AR | Hollow Points | +10% dano | 5 |
| AR | Fast Hands | +8% cadência | 5 |
| AR | Ricochet | Cada 4.º tiro: r ricochetes, 60% dano | 3 |
| AR | Pop Goes the Head | Explosão de headshot: 15+15r dano/3 m | 3 |
| AR | Piercing Rounds | +1 alvo atravessado | 3 |
| AR | Deadeye † | +4 pontos percentuais de crítico | 5 |
| AR | Critical Mass † | +0,15 ao multiplicador crítico | 3 |
| AR | Steady Aim | Parado: +8% cadência | 3 |
| AR | Point Blank | +10% dano até 4 m | 3 |
| AR | Finish the Job | +15% dano contra HP <30% | 3 |
| AR | Run and Gun † | Sprint permite disparar a 60% cadência | 1 |
| E | Fire Rounds † | +5 pp de queimadura: 8 dano/s, 3 s | 5 |
| E | Frost Rounds † | +5 pp de aplicação de frio | 5 |
| E | Storm Rounds † | +5 pp de descarga: 60% dano, vizinho ≤6 m | 5 |
| E | Toxic Rounds † | +5 pp de veneno: 6 dano/s, 4 s | 5 |
| E | Wildfire † | Abate queimado transmite fogo a +1 alvo | 3 |
| E | Deep Freeze † | +0,25 s de congelamento | 3 |
| E | Chain Lightning † | Descarga salta para +1 alvo | 3 |
| E | Toxic Cloud † | Abate envenenado: nuvem 2 m, 6 dano/s, 1+r s | 3 |
| E | Wind Rounds | +0,15 m de empurrão por acerto | 5 |
| D | Kinetic Barrier † | +10 escudo; recupera 5/s após 5 s sem dano | 5 |
| D | Shield Capacitor † | +10 capacidade de escudo | 3 |
| D | Quick Recharge † | −0,5 s de espera de recarga | 3 |
| D | Thick Hide | +15 HP máximos e atuais | 5 |
| D | Last Stand † | Evita morte uma vez/run; recupera 20r HP | 3 |
| S | Field Medic | Headshot fatal cura +1 HP | 5 |
| S | Blood Draw † | Rouba 0,5% do dano direto; teto 3 HP/s | 5 |
| S | Kill Rations | Cada 10 abates cura 2r HP | 5 |
| S | Field Dressing | Cada orbe cura 0,2r HP | 5 |
| S | Catch Your Breath | Sem dano há 5 s: recupera 0,5r HP/s | 3 |
| U | XP Magnet | +40% raio de atração | 5 |
| U | Fast Learner | +5% XP recolhida | 5 |
| U | Lucky Find † | +5 pp de recompensa adicional em caches | 5 |
| U | Light Boots | +4% velocidade | 5 |
| U | Second Breath | Headshot fatal repõe 0,1r s de estamina | 3 |
| U | Bigger Mags | +15% munição máxima especial | 5 |
| B | Hair Trigger | Cooldown ×0,9 por rank | 5 |
| B | Shockwave Breaker | +15 dano; +20% raio | 5 |
| B | Adrenaline | Abate retira 0,1r s de cooldown | 3 |
| B | Executioner | +20% dano contra atordoados | 5 |
| B | Aftershock | +0,2 s de atordoamento | 3 |
| B | Crowd Splitter | +0,4 m de empurrão | 3 |
| R | Grenadier | Cooldown da granada ×0,9 por rank | 5 |
| R | Wide Blast | +0,4 m de raio | 3 |
| R | Concussion | +0,25 s de atordoamento | 3 |
| V | Rally | War Cry cura 5r HP | 5 |
| V | Intimidation | War Cry empurra +0,4 m | 3 |
| V | Battle Rhythm | War Cry dá +8r% cadência durante 3 s | 3 |

Estados: fogo/veneno renovam duração, sem acumular dano. Frio dura 4 s: cada aplicação acrescenta 15% lentidão; três aplicações congelam 1 s e consomem o frio. Chefes recebem metade da lentidão e nenhum congelamento. Descargas não repetem alvos.

Duos automáticos †: **Thermal Shock**, fogo sobre congelado causa 30 dano e descongela; **Conductive Frost**, descarga ganha um salto contra alvo com frio; **Toxic Combustion**, fogo detona nuvem tóxica por 25 dano/3 m e consome-a. Efeitos secundários não geram novos efeitos secundários.

**Run and Gun contradiz `docs/DECISIONS.md:17`; exige decisão explícita antes de implementação.**

**D. Regras**

Manter P9: oferta com uma carta nova, uma melhoria e terceira ponderada; melhorias ×1,5, etiqueta partilhada ×1,25. Aplicar filtros de classe, loadout, pré-requisitos e ranks **antes** do sorteio, incluindo barco/acampamento. Sem duplicados na oferta.

Manter 2 rerolls iniciais, +1 por etapa intermédia, reserva 3; valores já implementados em `game/data/game_data.gd:225`. Sem elegíveis: conservar cura de 20 HP.

Evoluções numa fase posterior: Fire Rounds V + Wildfire III → **Inferno Rounds**, queimadura transmite-se uma vez por segundo. Substitui a carta-base; não soma duplicadamente.

**E. Armas**

DPS teórico = dano × cadência × projéteis acertados. Exclui headshots, armadura, dispersão e interrupções; perfuração aumenta dano agregado, não dano ao mesmo alvo. Todas acessíveis às duas classes.

| Arma | Dano | Tiros/s | Alcance | Proj. | Dispersão | Alvos/proj. | Munição | Intel | DPS individual/agregado máximo | Papel/evidência |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Assault Rifle | 12 | 9 | 30 m | 1 | 2° | 1 | ∞ | 0 | 108/108 | Sustentação; W/rifle.tres:7 |
| Shotgun | 9 | 1,4 | 12 m | 8 | 22° | 2 | 40 | 0 | 100,8/201,6 | Horda próxima; W/shotgun.tres:7 |
| Heavy Pistol | 60 | 2,2 | 35 m | 1 | 0° | 4 | 60 | 0 | 132/528 | Perfuração; W/pistol.tres:7 |
| SMG | 7 | 16 | 18 m | 1 | 7° | 1 | 300 | 60 | 112/112 | Rajada/procs; W/smg.tres:7 |
| Marksman Rifle | 110 | 1,2 | 45 m | 1 | 0° | 6 | 30 | 80 | 132/792 | Linhas/elite; W/marksman.tres:7 |

Defaults omitidos nos recursos: `game/data/resources/weapon_data.gd:11`.

Recomendo AR principal; Shotgun, Pistol e Marksman secundárias. SMG é candidata a reformulação: apenas +3,7% DPS bruto, pior alcance/dispersão e 18,75 s de fogo contínuo. Nenhuma arma é estritamente inferior em todos os critérios.

Hoje, desbloquear incorpora a arma automaticamente; não existe seleção principal/secundária (`game/states/armory.gd:158`; `game/main.gd:72`). Opções: **AR fixa + secundária escolhida**, ou principais intercambiáveis. Na segunda, escolher AR troca atomicamente com a SMG selecionada, sem perder propriedade. Não remover armas nesta fase.

**F. Perks em árvore**

| Atual | Efeito | Intel | Evidência |
|---|---|---:|---|
| Thick Skin | +30 HP | 40 | P/thick_skin.tres:7 |
| Pack Rat | +50% munição de todas as armas finitas | 40 | P/pack_rat.tres:7; I:277 |
| Head Hunter | Cone de headshot 9→15° | 60 | P/head_hunter.tres:7; I:788 |
| Battering Ram | +40% distância do breaker | 50 | P/long_breaker.tres:7; I:613 |
| Demolitions | Granada: −35% cooldown, +1 m raio | 50 | P/demolitions.tres:7; I:291,362 |

Pack Rat tem descrição desatualizada. Demolitions precisa de filtro Recruit.

Árvore proposta: três ranks/nó; tier seguinte exige anterior I. **Só perks equipados produzem efeitos**, respeitando `docs/DECISIONS.md:20`.

| Tier | Combat | Survival | Breaker |
|---|---|---|---|
| I | Head Hunter: cone 11/13/15° | Thick Skin: +10/20/30 HP | Battering Ram: +13/27/40% distância |
| II | Steady Grip: −10% dispersão/rank | Pack Rat: +20/35/50% munição | Recovery: −5% cooldown/rank |
| III | Opening Volley: +10% dano/rank após breaker, 2 s | Surveyor: +15% recolha/rank | Recruit: Demolitions; Vanguard: War Cry +0,5 s/rank |

Custos incrementais: tier I 40/60/80; II 60/90/120; III 100/140/180 Intel. Migrar perks existentes para rank III gratuitamente. Conservar slots: 100/250 Intel (`game/data/game_data.gd:217`).

Em `armory.gd:173`, substituir lista por três colunas ligadas; seleção mostra rank, efeito seguinte, custo e Equip/Upgrade. Manter resumo lateral.

**G. Ordem de implementação**

1. Dados/filtros: `card_data.gd`, `game_data.gd`, recursos e novo `card_offers.gd`; testar classes, loadouts, caps e rerolls.
2. Loadout: `profile.gd`, `run_context.gd`, `main.gd`, `armory.gd`; testar migração, troca e Quick Redeploy.
3. Cartas simples e HUD: `island_run.gd`, `hud.gd`; testar valores e categorias.
4. Estados/escudos: `horde.gd`, módulo novo; centralizar dano recebido. Testar remoção por troca de índices (`horde.gd:70`), mortes únicas e recarga.
5. Duos/evoluções; depois árvore. Validar custos, slots e persistência nos testes existentes; playtest separado para equilíbrio.


