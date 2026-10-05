# Horde Breaker — Roadmap

## Estabilidade — atualização de 2026-09-11

Soak renderizado de 900 s continua pendente: o utilizador confirmou que encerrou
o Godot depois do último registo aos 630 s. Não contar esta interrupção como crash.
Telemetria parcial preservada; tracer corrigido na build 2026.09.11.4 com teste
isolado. Protocolo em STABILITY_BENCHMARK.md e resultados em PROGRESS.md.
Completar o teste longo noutra ocasião; a interrupção não bloqueia pequenas
implementações, mas os dados parciais não aprovam estabilidade geral.

## Armory — interface (2026-09-08)

- [x] Coleção, imagem ampliada, slots selecionáveis e comparação de stats base.
- [x] Requisitos explícitos, confirmação de compra e preservação das regras atuais.
- [x] Testes de compra/equipamento/persistência e layout em três resoluções.
- [ ] Playtest humano de navegação; pré-visualização 3D fica para uma etapa futura.

## Etapa atual — expansão da skill tree (2026-09-08)

- [x] Esboço de 36 nós do Recruit e pré-visualização interativa no Godot.
- [x] Melhorar leitura visual, requisitos, seleção, scroll e simulação de pontos.
- [x] Respec gratuito da árvore atual do Recruit, backup e compras transacionais;
  impedir alterações de skills durante runs ativas/suspensas.
- [x] Converter a proposta em árvore jogável com backup, migração e respec.
- [x] Integrar efeitos por ramo, testar variantes/cartas/troca de arma/Resume Run.
- [ ] Playtest humano das builds e benchmark prolongado de combate/estabilidade.
- [ ] Expandir Renegade/Medic após validação do Recruit; gadgets de Scrap depois.

SKILLS abre a árvore completa do Recruit e aplica a build após confirmação; a simulação continua
isolado nos testes. Guia de utilização: RECRUIT_SKILL_TREE_TESTING.md.

Milestones preservados como histórico, com correções a 2026-09-06. Consultar
[PROJECT_AUDIT.md](PROJECT_AUDIT.md) para as prioridades verificadas da expedição
atual; funcionalidades concluídas na arena não estão todas integradas no hub.

## Próximas entregas — revisão de código/gameplay/HUD de 2026-09-06

Atualização posterior de 2026-09-07: removido o painel adicional dos dois slots
a pedido do utilizador. Entregue Dawn Supplies: depósito, munição para a arma
ativa e tratamento por Scrap; falta playtest de preços e expansão por melhorias.

Atualização 2026-09-07: entregues os dois slots/avisos de reserva, alvo partilhado
HUD-radar, prioridade de especiais, cartas sem prazo com correção de ofertas em
fila (C2), debrief contextual e missões finitas em Mourning/Shipwreck.
Ver [HUD_AND_OUTER_MISSIONS.md](HUD_AND_OUTER_MISSIONS.md) para âmbito e testes.
Não equivale a concluir H1–H5 na íntegra: navegação, resupply, sinergias, seleção
de recompensas e diagnóstico prolongado dos crashes continuam pendentes.

Esta tabela prevalece sobre rótulos históricos como “atual” nos milestones.
São tarefas propostas, não concluídas. Comparação dos seis jogos e critérios
H1–H5 em [INSPIRATIONS.md](INSPIRATIONS.md); evidência C1–C4 em
[ARCHITECTURE.md](ARCHITECTURE.md#lacunas-encontradas-por-análise-estática--não-corrigidas-nesta-tarefa).

| Ordem / etapa | Entrega pequena | Dependências e critério de saída |
|---|---|---|
| 0 — Baseline | Soak renderizado e diagnóstico dos crashes; distinguir logs de teardown de falhas durante a run | Mesmo hardware/perfil/rota; 15–30 min; registar frame times/memória, sem afirmar que headless prova estabilidade |
| 1 — Integridade da build | Reproduzir e corrigir C1/C2: arma encontrada conserva modificadores, ofertas em fila não desperdiçam níveis | Testes de troca repetida sem duplicar bónus e burst de XP perto dos limites; não acrescentar cartas antes disto |
| 2 — Economia legível | H1: slots 1/2 e estados de reserva; testar C3/C4, pickups em relevo e identidade da arma | Troca/recolha não cria munição grátis; HUD correto em recarga/pickup parcial; nenhuma alteração de balanceamento sem medição |
| 3 — Orientação segura | H2 e navegação por ilha: target coerente no radar, especiais prioritários, gates respeitados | Missões/ferries/revisitas com alvo removido; jogador não é guiado como se uma linha reta fosse caminho seguro |
| 4 — Ritmo e escolhas | Resupply mínimo Dawn + experiência de cartas sem prazo + H3/H4 | Custo/utilidade do Scrap claros; escolha legível e sem pausa perdida; testar em 1152×648 e 1920×1080 |
| 5 — Conteúdo significativo | Missões finitas Mourning/Shipwreck e uma escolha de recompensa por missão | Objetivo/risco/recompensa anunciados; dois caminhos de fuga, regresso possível, orçamento global mantido |
| 6 — Rejogabilidade | Duas cartas de comportamento e um modificador por ilha; H5 debrief | Efeito muda decisões, não só atributos; estatísticas suportadas por eventos; perfis comparáveis |
| 7 — Expansão medida | Um protótipo Fort Breaker OU Quarantine Key | Navegação/estabilidade aceites; medir custo das regiões e conteúdo distante antes de aumentar área residente |

Não converter esta sequência numa alteração monolítica. Começar pelos testes
de integridade e baseline; cada linha deve deixar uma versão jogável. Novas
classes, esquadrão, barcos livres, NPCs e crafting não são pré-requisitos.

## Regras

Utilização do Scrap na expedição: primeira entrega implementada, com detalhes
em [SCRAP_EXPEDITION_PLAN.md](SCRAP_EXPEDITION_PLAN.md). Primeiro posto de
abastecimento/depósito, só depois melhorias e postos secundários. Não cobrar
Scrap para desbloquear a ponte obrigatória de Forest.

### Experiência de terreno aprovada (2026-09-06)

- [x] Variante Terrain3D separada para Dawn Beach e Shadow Forest, com baía,
  relevos e vale; missões/acessos preservados e comparação com a cena original.
- [x] Testes de alturas, spawns, barreiras e travessias; capturas renderizadas
  e benchmark curto sem horda. Ver [TERRAIN_VARIANT.md](TERRAIN_VARIANT.md).
- [x] Comparação de combate de 60 s por mapa, com 90 inimigos em Shadow Forest;
  ambas concluíram, mas a variante teve quatro picos acima de 100 ms.
- [x] Reproduzir e corrigir `_show_tracer` no mapa original (2026-09-11).
- [ ] Investigar os picos de frame. Média de FPS mais alta não equivale a estabilidade aceite.
- [ ] Playtest de combate de 15–30 minutos, navegação e polimento visual ao
  nível do jogador antes de promover a variante ou redesenhar a terceira ilha.

### Regras de entrega

- Uma etapa deve estar funcional antes da seguinte.
- Cada etapa termina com teste, atualização de `PROGRESS.md` e comandos Git.
- Assets externos só com autorização explícita (downloads são do utilizador).

## Concluído (resumo)

- **M0–M9 — Núcleo jogável:** bootstrap, arena, movimento, câmara 3ª pessoa,
  hitscan, Normal Zombie, vida/derrota, rondas iniciais, HUD, múltiplas vagas.
- **M10–M14 — Progressão e classes:** save permanente (XP/Credits/armas), menus,
  Renegade melee, três classes com loadouts e passivos, modelos CC0 Quaternius.
- **M15–M17 — Survival e exploração:** núcleo/acampamento, Scrap e reparação,
  torres defensivas exteriores, POIs com interiores (hospital, armazém, posto militar, estação),
  dano por zonas, feedback de combate, tema visual próprio.
- **M18 — Mundo aberto compacto:** grelha 4×4 por seed, streaming em worker
  threads, navegação contínua, céu procedural, mapa tático.
- **M19 — Open World Sandbox:** diretor de horda contínuo (sem rondas),
  acampamento como zona de reabastecimento, jogo todo em inglês, variedade de
  inimigos (Brute/Spitter/Boss), skill tree permanente sem teto de níveis,
  armas encontráveis, POIs gerados, emboscadas por ciclo, persistência do mundo
  no save, melhorias da base, mastery, animações de ataque/dano/morte,
  orçamento de IA e métricas de streaming.

## Milestone 20 — Arsenal e progressão controlada (histórico)

Objetivo: tornar compras/loadouts utilizáveis e impedir que a skill tree seja
concluída demasiado cedo, mantendo as malhas embutidas nos rigs Quaternius.

- [x] Pontos de skill ganhos a cada dois níveis e tiers limitados aos níveis
  2/5/9/14/20, sem retirar skills de saves anteriores.
- [x] **Teto da skill tree removido:** cada nó compra-se por ranks (5/4/3/3/1 por
  tier), levando uma classe de 18 para 57 compras sem mudar a forma da árvore.
  Um rank é uma entrada repetida na lista, por isso saves antigos leem-se como
  tudo no rank 1, sem migração.
- [x] Ecrã `ARMORY` com estados comprado/comprável/bloqueado, compra com Credits
  e escolha persistente dos slots 1/2.
- [x] Spear do Medic baseada na malha embutida (implementação histórica,
  posteriormente retirada do catálogo jogável).
- [x] Primeiro passe de identidade das classes: Recruit 100 HP/recarga rápida,
  Renegade 150 HP, Medic 100 HP/regeneração 3 HP/s após 4 s.
- [x] Variantes de classe como capstone da mastery (VETERAN/BERSERKER/COMBAT
  MEDIC), alternáveis na seleção e aplicadas no arranque da partida.
- [x] Munição do chão a escalar com o nível de ameaça (base + 4/nível, teto 4×).
- [ ] Rever dano, cadência, alcance automático e regeneração após playtest das
  três classes (incluindo os números das variantes).
- [x] SMG automática (cadência 11/dano 16, carregador 35; nível 3 · 400 cr)
  comprável no ARMORY. A Fire Axe desta passagem foi depois retirada.
- [x] Armas melee retiradas do catálogo, ARMORY, pickups, loadouts, evoluções,
  HUD e animações ativas. Saves antigos migram para AR/Pistol, Shotgun/SMG e
  Pistol/SMG sem perder os contadores históricos.
- [x] Alcance de auto-fire por arma; valores atuais AR 12 m, Pistol 10 m,
  Shotgun 8 m, SMG 13 m (substituem o primeiro passe de 6/5,5/4,5/7 m).

## Milestone 24 — Terrain3D e reconstrução do mapa (em curso)

O protótipo de cidade foi retirado da arena. A base atual é um Terrain3D
contínuo e limpo; casas, estradas, props e POIs só regressam depois de o relevo,
os percursos e o desempenho estarem validados.

- [x] Terrain3D 1.0.2 autorizado e integrado sem assets externos do demo.
- [x] Nove regiões persistentes cobrem os 512 × 512 m dos 64 setores.
- [x] Plataforma nivelada do acampamento, relevo ondulado e corredor natural.
- [x] Primeira ilha integral: costa irregular, plano de água, fundo marinho e
  massas de relevo macro; opções registadas em `docs/TERRAIN_MAP_OPTIONS.md`.
- [x] Spawns, loot e navegação excluídos do mar; zombies consultam a altura real
  dos recursos Terrain3D carregados em vez de repetirem a fórmula procedural.
- [x] `MapRoads`, `MapStructures` e `MapProps` esvaziados; POIs autorados removidos.
- [x] Forward+ restaurado e colisão otimizada para hordas: jogador usa colisão
  dinâmica, zombies usam consulta de altura.
- [x] Barreira física persistente deslocada 24 m para dentro do mar; costa e
  espuma ficam livres, paredes quadradas foram removidas e a continuidade foi
  validada à superfície e abaixo do fundo marinho.
- [x] Playtest técnico automatizado cobre os dois caminhos, doze aterragens do
  jogador, declives por amostragem e contacto dos cinco tipos de inimigo.
- [x] Dois caminhos terrain-native em anel e três ligações, espuma costeira,
  cinco zonas de material e quatro landmarks de relevo.
- [x] Mapa tático recortado pela costa, com mar, caminhos e landmarks; a grelha
  de setores fica apenas como referência sobre a parte terrestre.
- [ ] Fazer o playtest humano prolongado de visibilidade, sensação dos declives,
  rotas de fuga e leitura espacial.
- [ ] Reintroduzir POIs/dressing em pequenos lotes, com orçamento de render e
  navegação medido por etapa.
- [x] Minimapa dedicado implementado; falta afinar leitura e agrupamento de marcadores.
  Estudar referências de outros jogos antes de decidir escala, orientação,
  fog of war, marcadores, filtros, zoom, objetivos e relação entre minimapa,
  bússola e mapa completo.

## Milestone 25 — Construção livre da base (implementado; requer playtest)

- [x] Data layer e catálogo para Barricade, Scrap Wall, Watch Tower, Generator e Spotlight.
- [x] Grelha de 2 m, snapping, rotação, reserva do núcleo e preview verde/vermelho.
- [x] Compra com Scrap armazenado, requisitos por upgrade e modo de construção rebindable.
- [x] Persistência de posição, rotação e vida; ocupação e navegação atualizadas após colocar/destruir.
- [x] Reparação por interação e visuais do acampamento para Resupply Rate 2 e Scavenging 1.
- [x] Movimento do jogador mantido durante o catálogo e a colocação; a câmara
  continua controlável durante o preview, e armas/interação normal ficam suspensas.
- [ ] Playtest de custos, alcance de construção, colisões e leitura visual.
- [x] UX explícita de demolição/reembolso: interação dedicada na `InteractionZone`
  da estrutura (fora do modo construção) devolve 50% do custo em Scrap armazenado.

## Milestone 26 — Survivors-like (inspiração YAZS)

Objetivo: adotar o *feel* do Yet Another Zombie Survivors no combate, mantendo o
mundo aberto, POIs e base como diferenciador.

- [x] **Fase 1:** cartas de upgrade por nível de run, orbes de XP largadas pelos
  inimigos (com íman) e feel survivors (câmara recuada + auto-fire alargado).
- [x] **Fase 2 — estrutura de run:** sobreviver 10 min até à extração, com
  relógio no HUD, avisos e recompensa de 300 Credits.
- [x] **Fim da run refeito:** o relógio deixou de terminar a partida e passou a
  decidir quando o fim começa. Cinco fases — sobreviver, janela de extração,
  last stand finito, limpar os que restam, chegar ao ponto de extração.
  Coberto por `test_five_phases` (37 verificações).
- [x] **Fase 3 — hordas massivas:** LOD de simulação (navmesh
  perto, steering direto ao médio, frames saltados ao longe) e LOD de animação
  (>42 m desliga o AnimationPlayer). O teto de gameplay é agora 90, partilhado
  por todas as origens de spawn, com guarda absoluta de 120, fila máxima de 12
  e apenas 2 novas instâncias por frame de física.
- [x] Evolução de armas por abates (4 evoluções desbloqueadas no ARMORY).
- [ ] Esquadrão de 3 personagens (controlas 1, IA segue) — o mais caro.

## Milestone 27 — Arquipélago modular (em curso)

Objetivo: transformar a ilha atual no ponto de partida de uma rede navegável de
ilhas com escalas, formas, biomas, encontros e recompensas próprias, reutilizando
os modelos CC0 que já existem no projeto.

- [x] Definir estratégia híbrida de expansão: 2–4 ilhas próximas por zona
  marítima e zonas distantes separadas — decisão de design, não streaming entregue.
- [ ] Implementar/medir ativação de IA, colisão e conteúdo por zona. Atualmente
  as nove regiões do arquipélago são persistentes; não confundir ferries com streaming.
- [x] Criar Shipwreck Rocks como ilha piloto pequena sem alterar a arena nem o
  save principal: uma região Terrain3D persistente, dois cais, destroços e cache
  exclusiva de demonstração.
- [x] Implementar transporte automático entre os dois cais com um ferry low-poly,
  antes de considerar controlo livre ou física naval.
- [x] Criar `IslandData`, `IslandRouteData` e `ArchipelagoData`, com validação do
  grafo e quatro ilhas ligadas num protótipo Terrain3D separado.
- [x] Validar duas escolhas no hub e convergência na ilha final: recife raso,
  gruta inundada, ponte destrutível e ruínas físicas.
- [x] Guardar o plano de gameplay por ilha e criar o vertical slice de Dawn
  Beach: três células de energia, acampamento de expedição, terminais A/B,
  bloqueio físico da rota não escolhida e noclip de desenvolvimento em Mouse 4.
- [ ] Implementar a expansão física do acampamento de Dawn Beach por tiers:
  começar apenas com o núcleo, ampliar perímetro e serviços com upgrades e
  terminar na fortaleza da referência visual, incluindo sockets para torres.
- [ ] Fechar as decisões do interior do acampamento — estações, segurança,
  destruição/reconstrução, NPCs, construção livre, UI e orçamento de render —
  antes de produzir todos os tiers.
- [x] Adaptar o mapa tático e o diretor de horda ao arquipélago: sete costas e
  sete rotas, oito spawns secos por ilha e pausa do diretor durante ferries.
- [ ] Persistir descoberta das ilhas entre runs; atualmente é memória da sessão.
- [x] Fechar Volcano Peak: três selos, barreira circular, The Breaker, horda
  finita, ativação do beacon e entrada na zona de extração.
- [x] Aumentar a zona atual para 768 × 768 m / nove regiões Terrain3D e sete
  ilhas, com Ironworks, Mourning Isle e Shipwreck Rocks acessíveis por ferry.
- [x] Dar a Ironworks uma missão própria: três disjuntores, encontros com Brutes,
  manifest bloqueado e acesso a Shipwreck protegido por ferry e barreira física
  até a rede elétrica ficar online.
- [x] Ocultar as travessias ainda bloqueadas com nevoeiro visual por rota, que
  dissolve ao escolher/completar a progressão correspondente sem acrescentar
  colisão nem ativar o passe global de nevoeiro volumétrico.
- [ ] Criar missões completas próprias para Mourning Isle e Shipwreck Rocks.
- [x] Reintroduzir um único kit visual no arquipélago e medir FPS/draw calls:
  64 formações costeiras reutilizam as rochas Kenney em sete `MultiMesh`.
  O benchmark Forward+ dedicado mede também primitivas, VRAM e custo das sombras.

## Milestone 21 — Ambiente e POIs finais (absorvido pelo M24)

- [x] Escolher e integrar um pack CC0 de edifícios (Quaternius Downtown MegaKit).
- [x] Substituir os POIs graybox dos setores gerados por fachadas temáticas.
- [x] Variedade de POIs gerados com três fachadas/planta visual.

## Milestone 22 — Balanceamento e sensação de jogo

- [x] Primeira proteção da curva do diretor: teto simultâneo global de 90,
  reservas em fila limitadas a 12 e instanciação limitada a 2 por frame.
- [ ] Afinar intervalo, composição e teto após playtest/profiling em Forward+.
- [x] Otimização orientada por profiling: benchmark Forward+ repetível cobre
  0–120 inimigos, ciclos Terrain3D e combate real. O soak de 60 s com 90 inimigos,
  disparos, mortes, drops e efeitos mediu 108,8 FPS / p99 17,52 ms na RX 590,
  sem erros nem novo crash do Windows.
- [ ] Fazer um soak jogável manual de 15–30 minutos e recolher um dump se o
  crash nativo reaparecer; um minuto automatizado não prova estabilidade longa.
- [ ] Decisões de playtest pendentes: alcance do auto-fire por arma e manter
  disparo manual.
- [ ] **Níveis de áudio por ouvir.** A recarga desceu para −22 dB e a horda para
  −24/−22/−30 a partir de medições de RMS, não de julgamento de ouvido; podem
  ter ficado baixos de mais.
- [ ] **Números dos ranks por jogar.** 5/4/3/3/1 por tier dá 57 pontos por
  classe, ou seja o nível 114 para encher uma árvore. Pode ser lento de mais.
- [ ] Mini-hitch do `add_child` dos setores (encaixar malhas por frames) — em
  espera a pedido do utilizador.

## Milestone 23 — Polimento e conteúdo extra (backlog)

- [x] **Som do jogo** (Milestone 28): 51 samples CC0 reais para armas, horda e
  passos, mixer com buses SFX/Música, limite de vozes e intervalo por som;
  sangue no impacto e arcos de direção do dano. Ver `docs/PROGRESS.md`.
- [x] **Música** de menu e combate com loop; falta adaptação dinâmica à ameaça.
- [x] **Bindings de gamepad**; falta playtest com comando físico e afinar os prompts.
- [ ] Mais objetivos de mastery e recompensas.
- [x] Construção livre / mais estruturas da base (entregue no M25; falta playtest).
- [ ] Salvamento de partida a meio (continuar uma run).
- [x] Retomar uma run sem fechar o jogo: `Back to Main Menu` suspende a instância
  atual e apresenta `RESUME RUN`. Não substitui o save a meio indicado acima.
- [ ] Persistência opcional de loot entre partidas (se o playtest o pedir).
- [ ] Mixamo (parqueado): só se for precisa uma animação que o Quaternius não tem.
- [x] Definir papéis e combinações não repetidas para a expansão de classes,
  armas e skills em `docs/CONTENT_EXPANSION_PLAN.md`.
- [ ] Implementar a expansão de conteúdo pela ordem aprovada, começando por uma
  classe/arma vertical slice e medindo desempenho antes da seguinte.
- [x] Remover armas melee e migrar Renegade, Medic, BERSERKER, ARMORY, pickups,
  evoluções, animações, HUD e saves antigos para alternativas de armas de fogo.
- [ ] Melhorar as animações e o encaixe das mãos nas armas: avaliar grips por
  arma, `BoneAttachment3D`, poses de mira, disparo e recarga compatíveis com o rig.
- [ ] Investigar o pipeline de arte final para personagens e mapa, comparando:
  geração procedural com Three.js e exportação para glTF/GLB; modelos existentes
  compatíveis com Godot; e criação/ajuste num modelador 3D. Avaliar licença,
  rig/animações, escala, materiais, colisões, tamanho e desempenho antes de
  autorizar qualquer download ou importação.
