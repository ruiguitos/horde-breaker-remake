# Horde Breaker — Game Design Document

## Armory — revisão de interface (2026-09-08)

Coleção à esquerda, arma em destaque ao centro e comparação com o slot escolhido
à direita. Slots PRIMARY/SECONDARY selecionam o alvo; compra por Credits exige
confirmação, depois equipamento explícito. Estados e requisitos visíveis. Stats
base (dano por disparo, cadência, carregador, recarga), sem bónus da personagem.
Regras/preços anteriores e evoluções por mortes preservados; imagens reutilizadas.

## Recruit expandido jogável — 2026-09-08

Recruit → SKILLS abre diretamente os 36 nós de Marksman,
Sustained Fire e Fieldcraft à próxima run. Limite de 30 pontos ativos, níveis
2/6/12/20/30/40/50 e uma especialização final por build. Respec gratuito fora
de runs ativas/suspensas; primeira conversão explícita guarda backup do perfil.
Renegade e Medic mantêm as árvores anteriores. Esta integração substitui as
notas históricas de preview isolado abaixo. Valores ainda sujeitos a playtest.
Guia: [RECRUIT_SKILL_TREE_TESTING.md](RECRUIT_SKILL_TREE_TESTING.md).

## Estado

Visão revista a 2026-09-06. As secções de sistemas incluem funcionalidades
herdadas da arena; nem todas estão integradas na expedição. Consultar
[PROJECT_AUDIT.md](PROJECT_AUDIT.md) para estado, lacunas e prioridades atuais.
O histórico detalhado vive em `docs/PROGRESS.md`.

## Visão do jogo

Horde shooter 3D na terceira pessoa, single-player, para Windows. O jogador
explora um **arquipélago de sete ilhas, 768 × 768 m**, enquanto uma **horda
contínua** nasce à sua volta e escala com o tempo. Dawn Beach é o hub inicial;
o posto Dawn Supplies permite depositar Scrap e comprar munição/tratamento.
Melhorias da base continuam na arena anterior. Todo o texto do
jogo está em **inglês**; a documentação em português.

## Core loop

`Explorar ilhas → combater e recolher recursos → cumprir missões e desbloquear
rotas → melhorar progressão/equipamento → enfrentar Volcano Peak → extrair ou
morrer → recomeçar com progressão permanente.`

Não há rondas convencionais: a ameaça cresce durante a expedição. Existe
vitória por extração após o final do vulcão, além de derrota por morte. A
progressão permanente (XP, skill tree, mastery, Credits) transita entre partidas.

## Personagens

Três classes com loadout primário/secundário (`1`/`2`) e passivos:

- **Recruit** (Assault): Assault Rifle + Pistol; recarrega 30% mais rápido.
- **Renegade** (Vanguard): Shotgun + SMG; 150 de vida. Desbloqueio: 500 Credits.
- **Medic** (Support): Pistol + SMG; regenera 3 HP/s após 4 s sem dano.
  Desbloqueio: 750 Credits.

Movimento: andar 4 m/s, correr 7 m/s (`Shift`), salto (`Space`), agachar
(`Ctrl`), interação (`F`), vista frontal (`C`), mira sobre o ombro (botão
direito), mapa tático (`Tab`).

## Combate

- O corpo acompanha suavemente o alvo horizontal do disparo automático ou manual;
  a câmara não é rodada pelo auto-aim. Sem alvo, mantém a orientação anterior
  pela câmara/movimento. Mira vertical do rig e strafe dedicado ainda pendentes.

- **Hitscan** com dano por zonas: corpo 1×, cabeça 2×.
- **Disparo automático por proximidade**: armas de fogo disparam sozinhas contra
  um alvo próximo com linha de tiro. Alcances das cenas base: AR **12 m**,
  Pistol **10 m**, Shotgun **8 m**, SMG **13 m**. Os 6 m são o default do script,
  não o alcance uniforme do arsenal. O ataque manual tem prioridade quando
  pedido e permitido; há recarga automática quando o carregador esvazia.
- O arsenal jogável é exclusivamente de armas de fogo; as armas melee foram
  retiradas do catálogo, pickups, evoluções e loadouts.
- Feedback: números de dano, flash no inimigo, HitReact, samples de áudio com
  fallback sintetizado, hit-marker, arcos de direção de dano e knockback ao
  jogador (Brute/Boss). O HUD já avisa de carregador baixo e mostra recarga.

## Inimigos

Perseguem o alvo ativo mais próximo: o jogador está sempre disponível e as
torres defensivas entram temporariamente no grupo de alvos quando são
construídas. Núcleo, muralhas e restantes estruturas continuam ignorados; a
destruição de uma torre não termina a run.

| Inimigo | Papel | Notas |
|---|---|---|
| Normal Zombie | base | 100 HP |
| Runner | rápido | 60 HP, 4,5 m/s |
| Brute | tanque | 320 HP, knockback forte |
| Spitter | à distância | mantém distância, projétil de ácido |
| The Breaker (boss) | clímax | 1200 HP, knockback, invoca minions |

**Diretor de horda contínuo**: spawns em lotes nos pontos mais próximos do
jogador (≥ 12 m), níveis iniciais mais longos (110 s no primeiro, convergindo
para 75 s no quinto; não inclui preparação inicial), com mais inimigos, tipos mais
pesados e intervalos mais curtos; boss a cada 5 níveis. O orçamento global é de
90 inimigos ativos, partilhado por horda, boss, emboscadas e POIs, com uma
barreira absoluta de 120. A fila reserva no máximo 12 spawns e instancia apenas
2 por frame de física; acima do teto, a dificuldade cresce pela composição e
não pela quantidade. Um "ciclo" = 3 níveis de ameaça (recompensa 100 Credits,
reposição de loot dos POIs, re-arme das emboscadas). Ao morrer, o inimigo toca
a animação de morte e o cadáver desaparece pouco depois.

## Mundo: distinguir a arena anterior da expedição

### Arena anterior — sistemas disponíveis, não a run iniciada pelo menu

Os pontos seguintes descrevem o antigo mundo de setores. Persistência de
setores, POIs e construção não comprovam integração nas ilhas atuais.

- Grelha 8 × 8 de setores 64 × 64 m sobre um Terrain3D contínuo. O acampamento
  persistente ocupa `(-1,-1)`; os restantes setores carregam conteúdo por seed
  em worker threads.
- O protótipo atual assume uma ilha grande: costa irregular, água a `Y = -3 m`,
  fundo marinho a `Y = -6 m`, um anel interior, um anel costeiro e três ligações
  entre ambos. Twin Ridge, Red Plateau, West Rise e South Cape funcionam como
  landmarks terrain-native. Spawns, loot e navegação são excluídos das zonas
  submersas. As alternativas e critérios estão em `docs/TERRAIN_MAP_OPTIONS.md`.
- Uma barreira física invisível e persistente segue a forma da ilha **24 m para
  dentro do mar**. A praia e o início da água ficam livres; a parede só funciona
  como último backstop antes do fim dos dados Terrain3D e estende-se abaixo do
  fundo marinho. Substitui as antigas paredes quadradas geradas por setor.
- **O seed do mundo é fixo por perfil** (guardado no save): o layout mantém-se
  entre partidas. Loot volta a cada partida — decisão de design: mundo familiar,
  exploração sempre recompensada.
- Nesta passagem o exterior do acampamento mostra **apenas terreno e água**,
  incluindo caminhos de terra, praia com espuma e variação de relva, floresta,
  zona seca e rocha. Casas, estradas, props e POIs autorados continuam retirados;
  caches, munições, caixas de arma e spawns permanecem ativos.
- **Emboscadas por setor** ao aproximar, re-armadas a cada ciclo.
- Setores **visitados persistem no save** (memória do mapa tático).
- Os POIs antigos (hospital, armazém, posto militar, combustível e variantes)
  estão temporariamente fora da arena até existir um passe terrain-native.
### Expedição atual — Destiny Archipelago

- **Destiny Archipelago é a run atual:** uma zona de 768 × 768 m em nove regiões
  Terrain3D, com sete ilhas e sete rotas. Dawn Beach abre a escolha principal;
  Shadow Forest e High Cliffs convergem em Volcano Peak. Mourning Isle,
  Ironworks e Shipwreck Rocks são desvios opcionais ligados por três ferries.
- Volcano Peak fecha a run: três selos abrem a arena, The Breaker inicia a horda
  finita ao morrer e a extração só termina depois de limpar o mapa, ativar o
  beacon e entrar na sua zona. O relógio isolado não conclui a expedição.
- Ironworks, Mourning Isle e Shipwreck Rocks já têm relevo, silhueta, dressing,
  spawns, mapa tático e caches de Scrap. Ironworks tem uma missão completa:
  restaurar três disjuntores sob ataques de Brutes abre a cache e o ferry para
  Shipwreck Rocks; até lá, uma barreira física contínua impede contornar o
  objetivo pelo mar. Mourning Isle tem três altares de purificação (8 s/8 m,
  encontros de Runners); Shipwreck Rocks tem três gravadores (12 s/5 m,
  encontros de Spitters). Afastar-se pausa o trabalho. Só depois dos três
  locais se pode recolher a cache: Scrap, um carregador de reserva por arma
  até ao limite e 25 run XP. Ferries de regresso não são bloqueados por estas
  missões opcionais. A descoberta destas ilhas dura a run, mas não persiste
  entre runs.
- Cada uma das sete rotas começa atrás de um banco de nevoeiro sobre o mar. O
  nevoeiro da rota escolhida ou concluída dissolve-se quando o destino fica
  acessível; ferries sem missão própria abrem-no ao iniciar a primeira viagem.
  É uma ocultação visual sem colisão, separada das barreiras físicas de missão.
- O transporte marítimo é automático: durante a travessia o diretor de horda
  pausa e o mesmo jogador conserva vida, armas e upgrades. Barco controlável,
  física naval e streaming de zonas marítimas distantes continuam no backlog.

## Acampamento

**Estado de integração:** os serviços funcionais abaixo pertencem à arena
anterior. Dawn Beach contém o RoutePowerCore de missão, mas ainda não o
CampCore de resupply/depósito nem os seus pedestais e torres funcionais. Primeiro
integrar um serviço mínimo; expansão por tiers continua proposta.

- **Zona de reabastecimento**: perto do núcleo cura e repõe munição por segundo.
- **Depósito**: `F` no núcleo guarda o Scrap transportado; Scrap armazenado
  compra reparações e melhorias.
- **Melhorias da base** (por partida, compradas nos pedestais junto ao núcleo):
  Resupply Rate, Resupply Range e Scavenging (+% Scrap), 3 níveis cada.
- **Expansão física por tiers planeada para Dawn Beach**: a run começa apenas
  com o núcleo e serviços mínimos; upgrades aumentam o perímetro, abrem zonas
  funcionais e acrescentam sockets defensivos até chegar a uma fortaleza ampla.
  O layout final segue a referência visual aprovada em 2026-08-02, mantendo um
  pátio central livre e estações junto da muralha. Custos e conteúdo interior
  ainda precisam de discussão e playtest antes da implementação.
- **3 torres defensivas exteriores**, junto aos acessos norte, oeste e este.
  São opcionais, disparam automaticamente e podem receber dano, ser reparadas
  ou reconstruídas com Scrap armazenado.
- Os quatro acessos têm estrada danificada e sinalização própria. Norte, oeste
  e este incluem cobertura lateral sem fechar o corredor central; torre de
  água, camião blindado, sinal urbano e bandeiras distinguem as direções.
- Cada torre tem 3 níveis ligados à progressão da run: LV1 custa 45 Scrap no
  nível 1 da run; LV2 custa 90 no nível 5; LV3 custa 150 no nível 10. Vida,
  dano, alcance e cadência sobem em cada nível.

## Progressão

### Temporária da expedição — já implementada

- Orbes alimentam `RunProgression`, separado do XP permanente da personagem.
- Cada nível oferece três cartas distintas de um catálogo de **11 upgrades**,
  com cinco raridades fixas, sorteio ponderado e exclusão das cartas maxadas.
  Limite de cinco níveis por carta; VAMPIRIC ROUNDS limita a três e cura por kill.
- A exigência de XP segue `12 + 8 × (nível − 1) + round(1,35 × (nível − 1)²)`.
- O painel pausa a run até à escolha explícita, sem prazo automático. Subidas
  simultâneas ficam em fila, com ofertas recalculadas após cada escolha para
  excluir cartas entretanto maxadas. Duplo clique não concede duas cartas.
  A pausa anterior é preservada. A pausa já lista as cartas adquiridas.

### HUD e debrief — revisão de 2026-09-07

- Por pedido do utilizador, retirado o painel adicional dos dois slots. Mantido
  apenas o indicador principal da arma ativa, munição e recarga.
- Radar partilha o alvo do tracker/HUD; inimigos especiais têm prioridade e
  marcadores maiores cor-de-rosa, mantendo o limite de 40 blips. O marcador
  dourado de objetivo indica direção, não um caminho navegável.
- Resultado apresenta também ilha/objetivo, até três melhorias de maior nível
  e distinção entre Credits permanentes e recursos temporários. Não inventa
  precisão, DPS ou causa específica de morte sem telemetria.
- Drops de munição/Scrap foram reforçados em 2026-09-06; ver os valores e limites
  em [PROJECT_AUDIT.md](PROJECT_AUDIT.md#3-recursos-alteração-implementada-nesta-etapa).
- Lacuna de consistência: a criação de uma arma encontrada não reaplica os
  modificadores já ganhos às novas instâncias; ver revisão técnica em ARCHITECTURE.

### Permanente e economia

Atualização de 2026-09-08: RESET SKILLS devolve gratuitamente todos os ranks
do Recruit, com confirmação e backup do perfil antes do primeiro reset. Não
altera XP/Credits/armas. Compras de skills e reset são bloqueados durante runs
ativas ou suspensas; o reset pertence à árvore atual, não à proposta de 36 nós.

Pré-visualização de 2026-09-08: Recruit → SKILLS → EXPANDED PREVIEW permite
simular 36 nós e 30 pontos ativos. É apenas design interativo, identificado no
ecrã: não modifica a árvore jogável, os bónus da run ou o save descritos abaixo.
Ver [SKILL_TREE_EXPANSION_PROPOSAL.md](SKILL_TREE_EXPANSION_PROPOSAL.md).

- **Scrap**: moeda da partida (desaparece no fim).
- **Credits**: moeda permanente (ciclos e mastery) — desbloqueia classes e armas.
- **Character XP**: por classe, **sem teto de nível**; 1 skill point a cada 2 níveis.
- **Skill tree permanente** por classe: 3 categorias próprias de cada classe,
  6 nós cada — **54 nós em 5 tiers**, com pré-requisitos e níveis mínimos
  2/5/9/14/20 (dano, cadência, recarga, vida, regen, redução de dano,
  velocidade, reserva de munição, raio de recolha, +Scrap, +XP). Cada categoria
  tem a mesma forma: tronco, tronco, bifurcação, reencontro, remate.
- **Ranks:** cada nó compra-se várias vezes (5/4/3/3/1 por tier), o que dá
  **57 compras por classe**. O efeito escrito num nó é o de um rank e compõe a
  cada compra.
- **Arsenal permanente**: o ecrã `ARMORY` permite comprar armas elegíveis com
  Credits e equipá-las nos slots 1/2; nível, compatibilidade e compra ficam no save.
- **Mastery por classe** (persistente, recompensa em Credits):
  EXTERMINATOR (100 abates), STORM RIDER (nível de ameaça 5 numa partida),
  SCAVENGER (500 Scrap recolhido). Completar as três desbloqueia a **variante**
  da classe.
- **Variantes de classe** (capstone da mastery, alternáveis na seleção; não são
  personagens novos — XP/skills/mastery/armory continuam da classe base):
  **VETERAN** (Recruit: troca a recarga rápida por +15% cadência),
  **BERSERKER** (Renegade: 110 HP, todas as armas de fogo causam +20% de dano),
  **COMBAT MEDIC** (Medic: regen 1,5 HP/s após 5 s, cada abate cura 5 HP).
  Com a variante ativa o modelo ganha um brilho subtil na cor da variante.
- **Armas encontráveis**: caixas de arma nos setores substituem o slot
  secundário durante a partida; a arma trocada cai no chão e pode ser reapanhada.
- **Expansão de conteúdo**: classes novas só entram quando tiverem papel,
  passivo, combinação de loadout e skills específicas que não repitam as atuais.
  A matriz aprovada e a ordem proposta vivem em `docs/CONTENT_EXPANSION_PLAN.md`.

## Direção visual

Low-poly CC0 (Quaternius, Kenney e KayKit) + Terrain3D. O arquipélago já tem
relevo, rotas, dressing e landmarks; não é o exterior vazio descrito nas fases
anteriores da arena. A cena usa o preset `archipelago_day.tres`, sol e água,
com nevoeiro visual associado às rotas. **Decisão:** manter
Quaternius para modelos e animações (cobre todos os movimentos necessários);
Mixamo parqueado. As armas visíveis continuam a ser as malhas embutidas nos
modelos; armas externas só serão reconsideradas com `BoneAttachment3D`. O
próximo passo de arte recomendado é reforçar silhuetas, orientação e leitura de
perigo por pequenos lotes medidos, antes de aumentar a densidade de props.

## Interface

Menu principal, guia de controlos, seleção (mastery/variantes), ARMORY, skill
tree, definições, pausa com build e resultado de vitória/derrota. `RESUME RUN`
retoma apenas na mesma sessão. Estado do HUD confirmado no código:

- Vida, arma ativa e carregador/reserva, recarga, ameaça, hostiles, Scrap
  transportado, três mensagens de feedback no máximo, XP/nível de run e relógio
  de expedição. Não apresenta permanentemente as reservas dos dois slots.
- O aviso de munição considera carregador abaixo de 25%, não reserva escassa.
- Radar circular de 70 m, atualizado a cada 0,08 s, até 40 pontos de inimigos;
  mostra drops de inimigos, núcleo e extração quando aplicável. Não tem costa,
  geometria de rotas nem target de missão intermédia. Roda com o VisualRoot.
- Painel de missão: ilha, título, instrução, progresso, direção e distância
  horizontal. A seta usa a câmara; não calcula caminho seguro nem diferença de
  altura. Só se instala na run pelo menu, não no arranque de diagnóstico por F6.
- Mapa Tab representa as sete ilhas/rotas e descoberta da sessão, loot e inimigos;
  **não pausa o combate**. FPS/métricas são diagnóstico, não um objetivo do jogo.
- Noclip de desenvolvimento continua fora de builds finais.

### Evolução proposta de gameplay/HUD — ainda não implementada

1. Tornar legíveis as decisões existentes: ambos os slots, escassez de reserva,
   objetivo consistente no radar e alertas críticos que não sejam substituídos
   por mensagens de loot.
2. Corrigir a continuidade dos modificadores quando se troca de arma; depois
   testar duas cartas de comportamento e escolha sem prazo por defeito.
3. Completar resupply, missões opcionais e ritmo preparação/combate/recompensa;
   não aumentar mapa e complexidade de UI ao mesmo tempo.

Comparação dos seis jogos, critérios de HUD H1–H5 e experiências A/B em
[INSPIRATIONS.md](INSPIRATIONS.md). Ordem de entrega em ROADMAP.

## Princípios de design

1. A horda sustenta pressão; o descanso logístico no hub ainda precisa de integração.
2. Exploração recompensada: loot, armas, POIs e emboscadas dão razões para sair.
3. Progressão dupla: dentro da partida (Scrap/upgrades) e permanente (XP/skills/mastery).
4. Simplicidade técnica primeiro: primitivas e CC0 até o gameplay estar fechado.
