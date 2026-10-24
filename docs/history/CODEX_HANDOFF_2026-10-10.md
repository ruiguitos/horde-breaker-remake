# Tarefas para o Codex (2026-10-10)

## Recargas SMG e Machine Gun — validação de 2026-10-21

Clips e fontes Blender atualizados; suite retomada com **65/65 scripts
aprovados**, incluindo testes novos/alterados repetidos após a importação.
Auditorias geométricas, comparação com o repouso original e rebuilds limpos
aprovados dentro dos limites documentados. Sem commit nem push.
Estado, limites, comandos e prompt de passagem ao Claude:
[RELOAD_ARM_CLIPS_RESUME_2026-10-21.md](RELOAD_ARM_CLIPS_RESUME_2026-10-21.md).

O utilizador passou estas tarefas do Claude para o Codex, para poupar
créditos. Fazê-las **por esta ordem, uma de cada vez**. No fim de cada uma:
correr todos os `tests/test_*.gd`, mostrar ao utilizador o que mudou e só
fazer commit quando ele pedir. Regras do projeto: `AGENTS.md` e `CLAUDE.md`.

**Fora de âmbito na entrega original (2026-10-10)**, por falta de decisão:
- remover armas;
- a escolha de arma principal ou secundária;
- a árvore de perks;
- ~~a carta "Run and Gun" (contradiz o `DECISIONS.md`: o sprint não dispara).~~
  Resolvido a 2026-10-14: o sprint dispara para todos e a carta foi retirada.

**Atualização de 2026-10-11:** o utilizador aprovou a opção B das armas,
entretanto implementada: principal/secundária escolhidas, Machine Gun,
SMG com mobilidade/proximidade e remoção da Heavy Pistol. Saves antigos
trocam a seleção da pistola pela Shotgun, sem reembolso. Estado e valores:
[COMBAT_CATALOG.md](COMBAT_CATALOG.md). A árvore de perks foi depois
implementada pelo Claude (secção «Árvore de perks» abaixo).

Também estão implementados os pedidos de Settings com tamanho comum e
ícones por plataforma ([SETTINGS_INPUT.md](SETTINGS_INPUT.md)) e o ecrã
de créditos com atribuições de OpenStreetMap e Via Láctea
([CREDITS.md](CREDITS.md)).

## Passagem ao Claude — Settings, armas e créditos (2026-10-11)

Os três pedidos estão implementados e documentados nas fontes acima.
Na verificação deste registo, Settings está no commit `e3ae8f8`; armas
e créditos estão no diretório de trabalho, com comandos de commit
entregues ao utilizador. Confirmar `git status` e `git log` antes de
continuar: esta indicação descreve o momento da passagem.

A validação anterior passou **31/31 scripts**, incluindo duas runs do
bot com extração nas seis ilhas. Capturas reais foram verificadas em
Forward+. Limitações do encerramento do Godot no Windows e da revisão
JEV estão registadas em [CREDITS.md](CREDITS.md).

Ao integrar a árvore de perks, preservar estes contratos:

1. **Perfil versão 6:** `selected_primary`, `selected_secondary`,
   propriedade das armas e as armas de Quick Redeploy.
   Seleções antigas da pistola passam para Shotgun, sem reembolso.
2. **Run com dois espaços:** AR/SMG/Machine Gun na principal e
   Shotgun/Marksman na secundária. `RunContext.weapons` contém as armas
   equipadas; desbloquear não acrescenta espaços à run.
3. **Cartas:** categoria `primary_weapon` e filtros para as três
   principais; efeitos de principal e elementos não atuam na secundária.
4. **Combate:** recargas independentes, modificador de movimento da arma
   e munição da secundária entre ilhas. Os valores novos são provisórios
   para playtest; consultar o catálogo antes de alterar números.
5. **Interface:** manter a moldura comum das Settings, ícones por
   plataforma e créditos com as atribuições completas e links.

Retomar a árvore de perks sobre este estado, conciliando alterações nos
ficheiros partilhados (`profile.gd`, `armory.gd`, `game_data.gd` e
`island_run.gd`). Depois de alterações de código, correr a suite completa,
incluindo `test_weapon_loadout`, `test_settings` e `test_credits`, e
documentar os resultados. Mostrar alterações antes de commit; commit e
push só quando o utilizador pedir.

## Árvore de perks (Claude, 2026-10-11, sem commit)

Implementada a árvore aprovada (§F2 de
[CARDS_WEAPONS_PERKS.md](../design/CARDS_WEAPONS_PERKS.md), com o estado e
as pequenas escolhas no fim da secção). Resumo:

- **Dados:** 20 alternativas em `game/data/perks/` (9 nós × A/B + variantes
  Vanguard de Breaker III); valores por rank nos `.tres`, custos e tempos
  em `GameData`. IDs antigos conservados como alternativa A.
- **Perfil v7:** `perk_ranks`, `perk_options`, `perk_use_ranks`,
  `equipped_perks`; migração v6→v7 versionada e idempotente (perks antigos
  → rank III em A, antecessores → rank I, Intel/slots intactos;
  Demolitions num Vanguard sai do equipamento com aviso). Campos de armas
  e comandos da versão 6 mantêm-se.
- **Run:** `RunContext` leva ids e ranks; Quick Redeploy guarda e repõe
  perks, A/B e ranks (ranks acima do comprado são limitados). Efeitos e
  contrapartidas em `island_run.gd`; Pack Rat só nas secundárias; Body
  Count tira as cartas de headshot das ofertas (`card_offers.gd`, também no
  barco/acampamento); Kill Chain só com abates diretos da principal;
  Skirmisher não permite disparar em sprint.
- **Armory:** separador PERKS com três colunas ligadas, A/B, pips, estados
  OWNED/EQUIPPED/NEW/LOCKED e painel de detalhe (▲/▼, rank → seguinte,
  UPGRADE, EQUIP/REMOVE, USE RANK). D-pad navega, LB/RB (Q/E) troca A/B,
  A abre as ações, B volta à grelha; dicas com ícones do `InputIcons`.

Validação: **32/32 scripts** (29 do jogo, incluindo o novo
`tests/test_perk_tree.gd` com 139 verificações, e 3 dos spikes), sem
`TEST FAIL`, `SCRIPT ERROR` nem erros de parsing; o bot extraiu nas seis
ilhas das duas runs. Mantém-se o código de saída nativo do Godot no
Windows (`-1073741819`). Capturas reais (Forward+) do separador PERKS a
1152×648 e 1920×1080 verificadas.

## Props Poly Haven — primeiro conjunto (2026-10-11)

Gerador, bidão, caixote e barricada integrados com glTFs oficiais de 1K,
sem instalar Blender. Comparação com primitivas disponível no editor.
Estado, validação, reversão e restantes oito modelos para o Claude:
[REALISTIC_PROPS.md](REALISTIC_PROPS.md).

## Vanguard v01 — integração adicional (2026-10-11)

Vanguard v01 com rig e Idle/Walk/Sprint aplicado ao Armory e ao jogo,
sem Blender. Estado, assets, testes e continuação:
[VANGUARD_MODEL.md](VANGUARD_MODEL.md).

Etapa escolhida pelo utilizador e entretanto implementada: Armory
**Abrigo 3D** e perks **Três ramos**, mantendo as regras atuais.
Ver [ARMORY_REDESIGN.md](ARMORY_REDESIGN.md).

## Armory e perks — redesenho visual (Codex, 2026-10-11)

Abrigo costeiro em 3D, rig jogável e retratos das classes, resumo fixo com
armas/slots/Threat, três ramos de perks com A/B lado a lado, detalhe do
efeito atual e do próximo rank, fila de perks equipados. Navegação e
compras continuam a usar Profile e InputIcons. Não altera saves ou valores.

Validação: **36/36 scripts** do jogo e dos spikes, incluindo 96 verificações
do novo layout; duas runs do bot extraídas nas seis ilhas. Capturas reais
em Forward+ a 1152×648 e Full HD e eventos de comando simulados verificados.

Ficheiros, capturas reais, testes e prompt de continuação para o Claude:
[ARMORY_REDESIGN.md](ARMORY_REDESIGN.md). Mostrar alterações antes de commit;
commit/push só quando o utilizador pedir.

## Recruit v03 — integração adicional (2026-10-11)

Recruit v03 com rig e locomoção
Idle/Walk/Sprint aplicado ao jogo. Estado, assets e pontos a preservar
para o Claude: [RECRUIT_MODEL.md](RECRUIT_MODEL.md).

## 1. Cartas (pedido do utilizador)

**Concluída em 2026-10-10, sem commit.** Catálogo de 39 cartas, incluindo
as quatro melhorias elementais e as combinações. Passaram os 21 testes do
jogo e os três dos spikes; duas runs completas terminaram com extração.
Detalhes e escolhas de implementação: [CARDS_IMPLEMENTATION.md](CARDS_IMPLEMENTATION.md).

Atualização: cartas no rank máximo ficam excluídas de level-ups,
mantimentos e rerolls; a partir do nível 30 toda a XP no chão é recolhida
automaticamente, incluindo ao atingir esse nível. Revalidação completa:
**26/26 testes**, com duas runs do bot extraídas; sem commit.

Especificação: `docs/design/CARDS_WEAPONS_PERKS.md`, secções A, C e D, e
`docs/design/PROGRESSION_AND_ECONOMY.md` §1.6. O ecrã de cartas já existe
(`game/ui/hud.gd`); as cartas estão em `game/data/cards*`
(`resources/card_data.gd`) e os efeitos em `game/world/island_run.gd`
(`stacks(...)`).

1. **Dados de cada carta:**
   - categoria (Assault Rifle, Elements, Defense, Sustain, Utility, Breaker,
     Class Recruit, Class Vanguard), ícone, etiquetas, filtro de classe,
     filtro de arma, pré-requisitos e rank máximo;
   - substituir o mapa provisório `GameData.CARD_CATEGORIES` por estes dados,
     mantendo `GameData.card_category()`.
2. **`game/world/card_offers.gd` (novo):**
   - aplicar os filtros **antes** do sorteio: classe, armas que o jogador
     tem, pré-requisitos e rank máximo;
   - sem duplicados;
   - uma carta nova e uma melhoria garantidas, quando existam;
   - a terceira carta ponderada: melhoria ×1,5, etiqueta em comum ×1,25;
   - RNG próprio, determinista por seed;
   - sem cartas elegíveis, mantém-se a cura de 20 HP;
   - usar estas regras no level-up **e** no mantimento "Card:" do barco e do
     acampamento.
3. **Catálogo:**
   - reequilibrar as 12 cartas atuais, mantendo os ids;
   - acrescentar as cartas sem † da secção C.
   - **Nunca** oferecer cartas de granada ao Vanguard nem cartas do War Cry ao
     Recruit.
4. **Elementos (†):** o utilizador pediu-os.
   - Fire (queimadura), Frost (lentidão e, ao fim de 3 aplicações, congela;
     o chefe nunca congela), Storm (salta para um vizinho), Toxic (veneno).
   - Aplicar as regras de estado da secção C. Atenção aos índices da horda,
     que se trocam ao remover um inimigo (`game/horde/horde.gd`).
   - Se houver tempo: Wildfire, Deep Freeze, Chain Lightning, Toxic Cloud e,
     por fim, as combinações.
5. **Ficam para depois:**
   - as cartas de escudo, que precisam do escudo da tarefa 2;
   - críticos, Lucky Find, Blood Draw e Last Stand.
6. **Testes** (`tests/test_cards_catalog.gd`):
   - filtros de classe e de arma, pré-requisitos e ranks;
   - garantias da oferta e determinismo;
   - um teste por carta, a confirmar o efeito que promete;
   - regras dos estados;
   - o mantimento "Card:".

## 2. Power-ups de abate (aprovados pelo utilizador)

**Concluída em 2026-10-10, sem commit.** Sete power-ups em todas as
missões, escudo, ícones no chão/minimapa, avisos e temporizadores.
O pedido adicional de melhorar a derrota também está implementado.
Passaram **26/26 testes** (23 do jogo e três dos spikes); o bot extraiu
nas seis ilhas das duas runs. Capturas verificadas no Godot com Forward+.
Detalhes, valores provisórios e como testar:
[POWER_UPS_AND_DEFEAT.md](POWER_UPS_AND_DEFEAT.md).

Especificação: `docs/design/COMBAT_AND_ENEMIES.md` §6b. Aparecem em
**todas** as missões, incluindo as partes da Berlenga.

1. **`game/world/power_ups.gd` (novo):**
   - probabilidade por abate, com garantia (pity) e maior nas elites;
   - no máximo um a cada 30–45 s e só um no chão de cada vez;
   - RNG próprio;
   - só caem em sítios alcançáveis e dentro da área de jogo;
   - os valores ficam em `GameData`.
2. **No chão:**
   - ícone grande e brilhante que flutua;
   - fica 25 s e pisca nos últimos 10 s;
   - marcador e legenda no minimapa.
3. **Tipos:** Insta-Kill, Double XP/Intel, Nuke, Full Power, Max Armor,
   Fire Sale e Max Ammo.
   - Nuke: mata os normais, fere os fortes e atrasa os spawns.
   - Fire Sale: +1 reroll, respeitando o máximo.
4. **Escudo do jogador:**
   - absorve dano antes da vida;
   - `add_shield()`, `shield` e `max_shield`;
   - barra no HUD, no estilo novo e sem painel escuro.

   É a base das cartas de escudo.
5. **HUD:** temporizadores ativos (ícone e segundos) e um aviso curto ao
   apanhar ("INSTA-KILL!").
6. **Testes** (`tests/test_power_ups.gd`):
   - limites, garantia e desaparecimento;
   - o efeito de cada tipo;
   - o escudo absorve antes da vida;
   - drops alcançáveis numa ilha feita à mão;
   - drops numa parte da expedição.

   `test_soak_run` tem de continuar a extrair.

## 3. Erros da câmara e da mira (encontrados pelo Codex)

**Concluída em 2026-10-11 (Claude), sem commit.** Os cinco erros estão
corrigidos: a câmara→inimigo também tem de estar livre de edifícios
(`_crosshair_visible`, que ignora as células bloqueadas onde a câmara
começa); em 1.ª/3.ª pessoa o tiro é um raio 3D da câmara para o alvo
(`_crosshair_hits`), o piercing só atravessa corpos que passam o mesmo
teste e a câmara fixa mantém o hitscan plano; o raio da mira calcula-se do
yaw/pitch atuais (já não lê a câmara do frame anterior); a granada aos pés
cai a 1,5 m, e sem chão (céu) 12 m à frente; os objetivos a menos de 12 m
atrás da câmara ficam presos à borda do ecrã. Afinação: arma da 1.ª pessoa
a 60 %, mais baixa, clarão e luz muito mais fracos; ombro da 3.ª pessoa de
1,0 para 1,6 m (encolhe junto a paredes). Testes novos em
`tests/test_camera_aim.gd`, incluindo Piercing, Ricochet, Fire Rounds e
Insta-Kill com a mira.

Revisão do Codex, corrigida: cada bago pára no primeiro obstáculo do seu
próprio caminho (`_ray_block`); a vista só é tapada por edifícios, rochas
e árvores (`sight_blocked`), não pelo mar nem por encostas (essas contam
pela altura do terreno); o Phantom Camera deixou de ter amortecimento e
transição, para a câmara mostrada ser a mesma de onde a simulação aponta.
Custo de um tiro de caçadeira com 150 inimigos: 0,26 ms (espalhados) a
0,60 ms (todos num cone de 30° à frente; o hitscan plano custa 0,47 ms aí).

Commit `9b10cf3`.

1. **Paredes:** em `island_run.gd` (~748) só se verificam edifícios no
   segmento jogador→inimigo. Verificar também câmara→inimigo.
2. **Tiro plano:** `_fire()` (~843) usa o hitscan plano em XZ depois de o
   alvo ser escolhido em 3D. Em 1.ª e 3.ª pessoa, resolver os impactos em
   3D, com oclusão; FIXED mantém o comportamento atual.
3. **Raio atrasado:** o raio da mira vem da câmara do frame anterior
   (`island.gd` ~807/966). Calcular a partir do yaw e pitch atuais, antes de
   `run.step()`.
4. **Granada aos pés:** apontada para perto dos pés, vai 8 m para a frente
   (`island.gd` ~822).
5. **Objetivos atrás:** os que estão perto mas atrás da câmara desaparecem
   (`hud.gd` ~1615). Prender a pastilha à borda do ecrã.

Afinação a fazer:
- a arma em 1.ª pessoa é demasiado grande e o clarão demasiado forte;
- a câmara de 3.ª pessoa precisa de se afastar para o lado, sobre o ombro.

## 4. Spawns sempre do mesmo lado

**Concluída em 2026-10-11 (Claude), sem commit.** `_ring_spot` junta os
pontos válidos de todos os raios em 8 setores e sorteia um setor (os que
têm menos de 4 pontos pesam menos, para uma nesga junto a uma parede não
receber uma parte inteira) e depois um ponto, com RNG próprio
(`_spawn_rng`, da seed). Na Beach 01 o setor mais usado pelo fallback
passou de 40–58 % para 16–25 %. O caminho normal (12 tentativas ao acaso)
não tinha este viés: é uniforme pela área livre (num mapa aberto, 12–13 %
por setor); só passou a usar o mesmo RNG próprio. Teste em
`tests/test_island_run.gd` (`_test_spawn_sectors`).

Diagnóstico do Codex: `_ring_spot` em `island_run.gd` (~1240–1246) aceita o
primeiro ângulo e o primeiro raio válidos.

- **Correção:** juntar os candidatos válidos de todos os raios em 8 setores,
  escolher um setor ao acaso e depois um candidato. RNG próprio.
- **Teste:** histograma de 4096 spawns num mapa aberto, sem nenhum setor
  acima de 20%.

## 5. Depois

- Maqueta do painel de fim de ilha ("ISLAND CLEARED"), que não segue o
  estilo novo, para o utilizador aprovar.
- Na imagem do acampamento, uma parte da Berlenga tem palmeiras.
