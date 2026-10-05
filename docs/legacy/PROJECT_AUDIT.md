# Horde Breaker — Auditoria de documentação e prioridades

Data: **2026-09-06**. Repositório: `C:\Users\Rui\code\horde-breaker`.
Base analisada: `22277fa`, branch `feat-unity-migration`, mais a alteração de
recursos descrita abaixo. Foram lidos os **14 documentos existentes em `docs/`**
e confrontadas com o código as principais afirmações de estado e lacunas.
Isto não constitui uma auditoria integral de todas as linhas de código nem um
playtest. As propostas de conteúdo não foram implementadas nesta etapa.

## 1. O que existe realmente

- O menu inicia `destiny_archipelago_prototype.tscn`, não a arena antiga.
  O arquipélago tem 768 × 768 m, sete ilhas, sete rotas e três ferries automáticos.
  Nove regiões Terrain3D são carregadas de forma persistente: não confundir
  isto com o streaming de setores da arena anterior.
- Dawn Beach, Shadow Forest, High Cliffs e Volcano Peak têm progressão de
  missões; Ironworks acrescenta uma missão opcional. Mourning Isle e Shipwreck
  Rocks têm caches, mas ainda não missões próprias equivalentes.
- Os bloqueios de rota, nevoeiro ligado ao desbloqueio, orientação de objetivos,
  minimapa e mapa tático já existem. Ainda precisam de playtest, legibilidade
  e navegação; não são funcionalidades a começar do zero.
- Volcano Peak já liga selos, boss, horda final, beacon e extração ao
  `RunObjective`. A afirmação antiga de que não fecha a run está ultrapassada.
- Há três classes selecionáveis: Recruit, Renegade e Medic. O Medic exige
  desbloqueio; não está desativado. São nove armas no catálogo jogável, apenas
  armas de fogo, e 54 nós de skill distribuídos pelas três classes.
- Música de menu/combate e bindings de gamepad existem. Música reativa à
  ameaça e validação com comando físico continuam a ser trabalho diferente.
- `RESUME RUN` conserva a instância em memória ao voltar ao menu. Não permite
  continuar depois de fechar o processo ou desligar o computador.

Evidência principal: [GameManager](../autoload/game_manager.gd),
[cena da expedição](../scenes/world/destiny_archipelago_prototype.tscn),
[hub inicial](../scripts/systems/dawn_beach_hub.gd),
[SaveManager](../autoload/save_manager.gd) e recursos em `data/characters/`.

## 2. Revisão dos 14 documentos

| Documento | Resultado da revisão / como usar |
|---|---|
| `GDD.md` | A visão inicial ainda descrevia 512 m, acampamento funcional e ausência de vitória. Corrigida a distinção entre expedição atual e sistemas herdados; não assumir que toda a arena foi integrada. |
| `ARCHITECTURE.md` | Útil para contratos locais, autoloads, limites e colisões. Mistura a arena de setores com o Terrain3D persistente; os sistemas da arena não demonstram integração no arquipélago. |
| `ROADMAP.md` | Preservar milestones como histórico. Música, gamepad e minimapa não devem continuar tratados como inexistentes; prioridades atuais são as secções 4–6 desta auditoria. |
| `PROGRESS.md` | Registo histórico detalhado de implementações e medições. Resultados de datas/cenas/GPU diferentes não são uma única baseline de performance; notas antigas não anulam alterações posteriores. |
| `TODO.md` | Corrigidos os itens antigos de Volcano e grounding. Navegação, identidade de StormRifle e persistência continuam relevantes. Itens parqueados não ficam automaticamente reativados. |
| `ARCHIPELAGO_GAMEPLAY_PLAN.md` | Boa direção para rotas, missões e outposts; comparar cada proposta com os hubs atuais. Field Outposts e base funcional ainda não estão entregues na expedição. |
| `CONTENT_EXPANSION_PLAN.md` | Corrigidas a disponibilidade do Medic, a falsa duplicação de loadout e a referência a 36 skills comuns. Classes novas dependem de catálogo/save/UI genéricos; não são a próxima prioridade. |
| `INSPIRATIONS.md` | Referências úteis, mas algumas contagens e ligações são históricas/comunitárias. A secção 5 abaixo acrescenta fontes primárias e adaptações pequenas, sem copiar conteúdo. |
| `MAP_DESIGN.md` | Design da grelha e POIs da arena anterior. Reutilizar princípios de legibilidade e landmarks, não coordenadas, dimensões ou streaming como descrição do mapa atual. |
| `TERRAIN_MAP_OPTIONS.md` | Comparação de opções e investigação histórica. Terrain3D já foi escolhido/integrado; não há motivo nesta tarefa para trocar motor, addon ou formato de terreno. |
| `IMPLEMENTATION-PLAN.md` | Plano histórico desde o protótipo inicial. Não executar sequencialmente tarefas já substituídas por horda contínua, armas de fogo e arquipélago. |
| `PLANO-DE-TRABALHO.md` | Sequência histórica útil para perceber decisões; não é uma segunda lista de prioridades atual. Confrontar com PROGRESS e esta auditoria antes de implementar. |
| `OVERVIEW.md` | Retrato anterior; referências a master e ao mapa antigo não identificam a branch/cena atuais. Utilizar como contexto, não como estado presente. |
| `PROJECT_REFERENCE.md` | Snapshot técnico anterior, com números e ilhas desatualizados. Consultar caminhos/contratos com confirmação no código, não reutilizar os números sem medição. |

Regra de manutenção proposta: GDD guarda intenção, ARCHITECTURE contratos,
ROADMAP prioridades e PROGRESS resultados datados. Os planos antigos ficam
como histórico, em vez de acumular listas concorrentes de funcionalidades.

## 3. Recursos: alteração implementada nesta etapa

O Normal tem 100 HP e a Assault Rifle causa 30 de dano corporal: quatro tiros
certeiros por eliminação. Antes, o drop devolvia apenas 1,12 munições por
eliminação, em média, no nível de ameaça 1.

| Inimigo | Munição anterior: probabilidade × caixa | Nova munição | Média anterior → nova | Scrap anterior → novo |
|---|---|---|---|---|
| Normal | 14% × 8 | 30% × 24 | 1,12 → 7,20 | 1–2 → 2–4 |
| Runner | 16% × 8 | 35% × 20 | 1,28 → 7,00 | 1–2 → 2–4 |
| Spitter | 30% × 14 | 50% × 28 | 4,20 → 14,00 | 2–3 → 4–6 |
| Brute | 50% × 20 | 65% × 40 | 10,00 → 26,00 | 4–6 → 8–12 |
| Boss | 100% × 60 | 100% × 100 | 60,00 → 100,00 | 15–20 → 30–40 |

As probabilidades de Scrap mantêm-se: 15%, 20%, 30%, 60% e 100%, respetivamente.
XP, Credits, dano e capacidade das armas não mudaram. As caixas continuam a
escalar com ameaça, até quatro vezes a quantidade base.

- Corrigido o desperdício: uma arma ativa quase cheia já não consome a caixa
  toda. O excedente passa à outra arma; o que não cabe fica na caixa.
- Uma caixa parcialmente recolhida fixa a quantidade restante. A subida de
  ameaça não pode regenerar o conteúdo já recolhido.
- Mantidos os limites de 30 caixas de munição, 40 drops de Scrap e 25 segundos
  de vida dos drops de inimigos. Corrigida a remoção de caixas antigas quando
  muitas mortes acontecem no mesmo frame; não foi aumentado o teto da horda.
- A 65% de precisão, a rifle consome cerca de 6,15 tiros por Normal. Os 7,2 de
  retorno médio dão margem pequena para caixas perdidas. A SMG consome mais:
  isto não garante munição infinita nem elimina períodos sem drops por acaso.
- O resto de uma caixa mantém-se na instância em execução; não foi criado
  save de quantidades parciais ao descarregar setores da arena antiga.

### Validação e limite da medição

`test_enemy_resource_economy.gd`: **55/55**, incluindo cenas reais, capacidade
dos dois slots, recolha parcial, escala de ameaça, distribuição em 1 000
sorteios e 65 tentativas de drop no mesmo frame. A seed usada produziu 300
drops em 1 000 tentativas. Isto é um teste de recursos, não um benchmark de FPS
nem uma simulação completa de partidas.

Regressões: `test_horde_and_pickups` 27/27, `test_balance_and_weapons` 53/53,
`test_weapon_rig` 27/27, `test_expedition_guidance` 59/59. Total: **221
verificações, zero falhas de asserção**, processos com saída 0. Os logs não
estão todos limpos: o fixture antigo de magnetismo usa um `camp_economy` sem
método de recolha e emite erros; a expedição apresenta a depreciação Terrain3D
e, ao sair, quatro ObjectDB e dois recursos ainda em uso. Não foram corrigidos
nem escondidos nesta etapa e não demonstram que os crashes estejam resolvidos.

A importação `--headless --editor --quit` terminou com saída 0, sem erros de
parsing reportados, mas falhou a cópia/carregamento da DLL de Terrain3D e
reportou RIDs/recursos por libertar. Havia outro processo Godot aberto; não foi
encerrado nem foi alterado o addon. A causa da falha de DLL não foi determinada.
Repetir esta validação com o editor do projeto fechado. Os testes acima usaram
o executável existente Godot 4.7 stable mono, sem atualização de versão.

O benchmark de estabilidade existente reabastece munição artificialmente;
não deve servir para concluir que a economia é equilibrada. Próxima medição:
15–30 minutos por loadout, sem reabastecimento de teste, registando disparos,
eliminações, munição recolhida, caixas perdidas, minutos sem munição, FPS/frame
time, memória e erros, com o mesmo hardware, renderer e definições.

## 4. O que falta, por prioridade

### P0 — Antes de aumentar muito o mapa

1. **Estabilidade medida:** reproduzir crashes com logs/dumps e sessões longas;
   separar crash nativo, erro de script e fuga no encerramento. O teste headless
   não mede GPU, VRAM, streaming visual nem a experiência real de combate.
2. **Navegação da horda** (navmesh por ilha entregue a 2026-10-04, ver PROGRESS; falta playtest e ligações entre ilhas): não havia NavigationRegion3D no arquipélago. O caminho
   direto e grounding por altura não contornam edifícios nem garantem uso das
   rotas. Validar navegação por ilha com os gates, pontes, ferries e falésias;
   não reativar indiscriminadamente a física pesada do terreno nos zombies.
3. **Validar a nova economia em jogo:** testar Recruit e loadouts com SMG,
   risco de ficar sem munição no início, e quanto Scrap realmente tem utilidade.

### P1 — Completar a experiência das sete ilhas

1. **Dawn Beach funcional:** o `RoutePowerCore` é uma estrutura visual de
   missão, não o CampCore com depósito/resupply da arena antiga. Ligar um ponto
   simples de reabastecimento e depósito à economia existente, com custo e UI.
2. **Outposts** (entregue a 2026-10-04 em Forest e Cliffs, ver PROGRESS; falta playtest): implementar uma escolha local por run (Resupply, Recon ou
   Defense) depois de cumprir uma missão. Não transportar toda a construção
   livre da arena antiga sem validar custos, posições e navegação.
3. **Mourning Isle:** proposta de missão curta, silenciar três sinos com
   emboscadas limitadas; recompensa final e ferry de regresso sempre utilizável.
4. **Shipwreck Rocks:** proposta de recuperar a caixa negra, defender o ponto
   de salvamento durante um intervalo limitado e regressar com a recompensa.
5. **Dados por ilha:** `IslandData` ainda não define tabelas de loot, pesos de
   inimigos, cena de missão ou limites de ativação. Acrescentar só os campos
   necessários à próxima missão, com fallback para recursos antigos.
6. **Correções pequenas:** `storm_rifle.tscn` não define `weapon_id` próprio;
   descoberta de ilhas não é persistida; mapa tático precisa de agrupamento de
   marcadores. Persistir descoberta não é o mesmo que gravar uma run inteira.

### P2 — Rejogabilidade e apresentação

- Duas ou três combinações de modificadores por expedição; por exemplo, mais
  Spitters e melhor recompensa, sem exceder o orçamento global de inimigos.
- Melhorar skills existentes com efeitos percetíveis de recarga, troca,
  headshot e suporte antes de acrescentar mais multiplicadores ou classes.
- Telegraphs do boss, landmarks distintos, silhuetas dos caminhos, áudio
  reativo ao perigo e mensagens curtas de rádio em texto antes de gravações.
- Save de run em disco exige estado de missões/rotas, inventário, progressão
  temporária e compatibilidade de versões; não é apenas guardar a posição.

## 5. Jogos semelhantes: ideias concretas que cabem neste projeto

Estas são adaptações propostas, não funcionalidades já entregues nem planos
de copiar mapas, personagens ou assets. As fontes são dos criadores/editores.

| Referência e evidência | Adaptação pequena para Horde Breaker | Evitar nesta fase |
|---|---|---|
| [Deep Rock Galactic: Survivor](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/): objetivos, recursos, melhorias e regresso à extração | Desvios opcionais de loot antes do ferry; escolher uma melhoria de outpost como recompensa | Terreno todo destrutível, mineração e crafting completos |
| [Risk of Rain 2](https://store.steampowered.com/app/632360/Risk_of_Rain_2/): locais desenhados, progressão de risco, sinergias e modificadores | Modificador por ilha e duas recompensas temporárias com comportamentos combináveis | Centenas de itens ou aumentar a horda para produzir dificuldade |
| [Yet Another Zombie Survivors](https://yazs.awesomegamesstudio.com/): sinergias de armas/abilities, equipa até três e progressão | Diferenciar as três classes existentes e orientar objetivos por mensagens curtas | Esquadrão de três aliados com IA antes de resolver a navegação dos inimigos |
| [World War Z: Aftermath](https://www.focus-entmt.com/en/games/world-war-z): classes, perks e missões com modificadores | Encontros de defesa com fases legíveis e composição temática de inimigos | Usar a escala visual das hordas como alvo de contagem de NPCs |

## 6. Expansão do mapa, sem multiplicar zonas vazias

Primeiro completar Mourning e Shipwreck. Depois prototipar **uma** ilha nova
de cada vez, com geometria simples e assets já autorizados no repositório:

| Proposta | Geografia e identidade | Missão / recompensa |
|---|---|---|
| **Fort Breaker** (protótipo entregue a 2026-10-04, ver PROGRESS) | Fortaleza costeira, pátio e arsenal elevado; duas saídas do pátio e uma torre como landmark | Recuperar acesso ao arsenal, abrir portão e defender evacuação; reabastecimento e escolha de arma |
| **Quarantine Key** | Ilha em crescente, enfermaria e estação de bombagem; circuito exterior e atalho interior | Desativar focos de contaminação em ordem livre; posto de cura ou resupply como escolha |

Cada ilha deve ter 2–4 zonas distinguíveis, três landmarks e caminhos de fuga
claros. Alvos iniciais, ainda não medidos: 60–90 segundos entre decisões de
rota, 5–10 minutos por ilha principal e 20–30 minutos por expedição.

Antes de passar de sete para muitas ilhas, medir o custo de regiões residentes,
props, colisões e encontros distantes. Introduzir ativação por proximidade e
validar transporte/gates sob carga antes de expandir a área total. Ferries
automáticos podem continuar; condução livre de barcos é um sistema separado.

## 7. Ordem recomendada e âmbito desta entrega

**Entregue agora:** mais munição/Scrap, menos desperdício, proteção do orçamento
de drops, testes e esta auditoria. Não foram criadas novas ilhas, classes,
assets, plugins, saves de run ou sistemas de construção.

**Próxima etapa recomendada:** playtest medido da rota inicial e resupply mínimo
em Dawn Beach; resolver os defeitos observados de estabilidade/navegação antes
de produzir Fort Breaker. Só depois completar as duas ilhas opcionais e escolher
o próximo protótipo. Manter parqueados os trabalhos de layout da seleção,
resoluções, mini-hitch e Mixamo enquanto não houver novo âmbito para eles.

## 8. Ficheiros, teste manual e Git desta etapa

Alterados: `scripts/enemies/normal_zombie.gd`, `scripts/pickups/ammo_pickup.gd`,
`scripts/weapons/weapon_controller.gd` e as cenas Runner, Spitter, Brute e Boss
em `scenes/enemies/`. Criados: `tests/test_enemy_resource_economy.gd` e respetivo
UID, além deste relatório. Atualizados: ARCHITECTURE, CONTENT_EXPANSION_PLAN,
GDD, INSPIRATIONS, OVERVIEW, PROJECT_REFERENCE, ROADMAP, TODO e PROGRESS.

Não são necessárias alterações manuais a nós ou cenas. No Godot, abrir
`project.godot`, iniciar com **F5** e escolher uma **nova run** (uma run já
suspensa pode conservar os valores antigos). Jogar com Recruit e depois com
um loadout que tenha SMG; confirmar mais caixas e Scrap. Com uma arma quase
cheia e a outra com espaço, atravessar uma caixa e verificar a reserva dos
dois slots. Com ambas quase cheias, confirmar que o resto da caixa fica no
chão, disparar/recarregar e voltar a recolhê-lo antes de expirar.

Teste automático em PowerShell, usando o executável já instalado:

```powershell
& 'C:\Users\Rui\Downloads\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe' --headless --path . --script res://tests/test_enemy_resource_economy.gd
```

Não foi feito commit nem push nesta etapa. Comandos, a partir da pasta do projeto:

```powershell
git status
git add scripts/enemies/normal_zombie.gd scripts/pickups/ammo_pickup.gd scripts/weapons/weapon_controller.gd scenes/enemies/runner_zombie.tscn scenes/enemies/spitter_zombie.tscn scenes/enemies/brute_zombie.tscn scenes/enemies/boss_breaker.tscn tests/test_enemy_resource_economy.gd tests/test_enemy_resource_economy.gd.uid docs/ARCHITECTURE.md docs/CONTENT_EXPANSION_PLAN.md docs/GDD.md docs/INSPIRATIONS.md docs/OVERVIEW.md docs/PROJECT_REFERENCE.md docs/ROADMAP.md docs/TODO.md docs/PROGRESS.md docs/PROJECT_AUDIT.md
git commit -m "fix: improve enemy resource economy and audit expedition backlog"
```
