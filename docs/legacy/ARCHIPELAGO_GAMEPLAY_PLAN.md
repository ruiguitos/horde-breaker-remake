# Horde Breaker — Plano de gameplay do arquipélago

Estado: direção de design aprovada para prototipagem em 2026-08-02. Este
documento define o objetivo de cada ilha antes de aumentar a dimensão total do
mapa. Os valores de duração e distância são alvos de playtest, não regras finais.

## Estrutura da expedição

Uma run visita três ilhas, mantendo uma escolha real no hub:

```text
                         Shallow Reef
                  ┌────────────────────► Shadow Forest
                  │                              │
            Dawn Beach                    Rope Bridge
          CAMP / START HUB                       │
                  │                              ▼
                  │                        Volcano Peak
                  │                         BOSS / EXIT
                  │                              ▲
                  │                       Ancient Ruins
                  │                              │
                  └────────────────────► High Cliffs
                           Sea Cave
```

O jogador percorre Dawn Beach, escolhe Shadow Forest **ou** High Cliffs e
converge em Volcano Peak. A rota não escolhida oferece variedade numa run
seguinte sem obrigar cada expedição a atravessar as quatro ilhas.

## Regras comuns

- Cada ilha tem uma identidade de combate, um objetivo principal, pelo menos
  três landmarks e duas rotas de fuga nos encontros importantes.
- O percurso direto entre entrada e saída deve demorar 60–90 segundos; fazer
  objetivos e explorar deve ocupar 5–10 minutos por ilha.
- O alvo para uma expedição de três ilhas é 20–30 minutos. A pressão vem do
  diretor de ameaça e não de espaços vazios ou de um relógio demasiado curto.
- Só a ilha ativa mantém IA, colisão detalhada e encontros completos. Ilhas
  distantes usam apenas terreno, silhueta e dressing leve.
- O orçamento global continua limitado a 90 inimigos ativos, com a guarda
  absoluta de 120, fila máxima de 12 e duas instanciações por frame de física.
- Nenhuma rota destrutível pode criar um soft-lock. Deve existir reparação,
  reativação ou uma alternativa claramente acessível.

## Dawn Beach — hub de partida

### Papel

Introduzir a expedição, permitir preparação e apresentar uma escolha de rota
visível. É o único acampamento completo do arquipélago.

### Conteúdo

- núcleo de energia e depósito de Scrap;
- cura e reabastecimento;
- estações de Resupply Rate, Resupply Range e Scavenging;
- pontos defensivos no exterior do perímetro;
- torre de sinalização, cais e painel do arquipélago;
- duas saídas reconhecíveis: Shallow Reef e Sea Cave;
- caches e componentes distribuídos pela praia para incentivar exploração.

### Objetivo e escolha

O jogador recupera células de energia espalhadas pela ilha e regressa ao
acampamento. Com energia suficiente pode ativar uma das duas rotas:

- **Route A — Shallow Reef:** reparar o Tide Beacon e abrir o banco de areia;
- **Route B — Sea Cave:** alimentar as bombas e tornar a passagem utilizável.

A primeira versão permite apenas uma escolha por sessão. A outra rota fica
visivelmente bloqueada, mas tudo reinicia quando o protótipo volta a arrancar.

### Progressão física da base

A base de Dawn Beach não deve começar com o tamanho da fortaleza final. No
início da run existe apenas o essencial em redor do núcleo; investir Scrap e
cumprir requisitos de nível da run aumenta tanto as funções como a área física
do acampamento. Cada upgrade deve ser reconhecível no mundo, não apenas num
número ou numa barra da interface.

| Tier | Estado visual | Funções disponíveis | Defesa |
|---|---|---|---|
| **Tier 0 — Emergency Core** | núcleo, luz de sinalização e abrigo muito pequeno | depósito básico e resupply limitado | sem muralha completa; nenhum ponto automático ativo |
| **Tier 1 — Secured Camp** | primeiro perímetro curto e um acesso controlado | armazenamento e primeira melhoria de resupply | primeiro socket exterior para torre |
| **Tier 2 — Operational Base** | perímetro ampliado, dois ou três acessos e zonas funcionais legíveis | workshop, medbay/resupply melhorado e controlo das rotas | dois sockets, reparação e upgrades intermédios |
| **Tier 3 — Fortified Base** | fortaleza ampla inspirada na referência visual aprovada | todas as estações aprovadas para a run e pátio central organizado | perímetro completo, acessos defendidos e rede final de torres |

O **Tier 3** usa como referência a imagem aérea fornecida em 2026-08-02. O alvo
visual é um perímetro largo, aproximadamente octogonal, com muralha contínua,
vários portões, núcleo ao centro, grande pátio de circulação e estações junto à
face interior da muralha. Contentores, área médica/ambulância, água, energia,
comunicações, iluminação e plataformas defensivas tornam a base final habitada
e funcional. A referência define a densidade e a leitura pretendidas; não exige
copiar literalmente cada modelo ou posição.

Regras para a expansão:

- melhorar a base aumenta o perímetro utilizável e revela novas zonas, em vez
  de colocar todos os edifícios desde o início;
- cada tier mantém corredores largos entre os portões e o núcleo para o jogador,
  zombies e navegação;
- a expansão nunca pode criar estradas elevadas, degraus invisíveis ou pés
  enterrados; o terreno é nivelado antes de colocar chão, muralhas e estações;
- colliders e blockers do tier anterior são removidos antes de ativar os novos;
- alterações ao perímetro obrigam a atualizar navegação, sockets defensivos,
  mapa tático e zonas válidas de spawn;
- o salto visual entre tiers deve ser claro à distância, mas acontecer em lotes
  com orçamento de props, luzes, sombras e draw calls medido;
- custos exatos, requisitos de nível e persistência entre ilhas/runs ficam por
  decidir depois de um playtest do Tier 0 e do Tier 1.

### Torres defensivas

O jogador pode construir torres em sockets preparados junto dos acessos e no
exterior imediato da muralha. A posição deve intercetar a horda antes de ela
entrar no acampamento sem bloquear os próprios portões.

- construção, reparação e reconstrução usam Scrap armazenado;
- cada torre recebe dano, pode ser destruída e nunca termina a run por si só;
- upgrades aumentam vida, dano, alcance e cadência, com mudança visual clara;
- os níveis da torre podem exigir simultaneamente Scrap e um nível mínimo da
  run, mantendo a progressão alinhada com a ameaça;
- as torres entram temporariamente no grupo de alvos dos zombies, mas não criam
  inimigos adicionais nem ultrapassam o orçamento global da horda;
- um socket vazio, uma torre destruída e cada nível construído precisam de
  estados visuais e prompts distintos;
- o layout final deve permitir várias combinações defensivas sem transformar o
  pátio central numa zona cheia de obstáculos.

### Discussão pendente — interior do acampamento

Antes de implementar os tiers completos é necessário decidir o que o jogador
faz dentro da base e o que cada expansão realmente acrescenta. Questões abertas:

1. quais são as estações obrigatórias: depósito, resupply, medbay, workshop,
   controlo de rotas, construção e armazenamento de armas;
2. que funções continuam apenas nos menus permanentes para não duplicar ARMORY
   e skill tree dentro da run;
3. se as estruturas aparecem em posições predefinidas por tier ou se existe uma
   combinação de expansão autorada com construção livre em sockets;
4. se sobreviventes/NPCs ocupam as novas zonas e se oferecem missões ou são
   apenas vida ambiental;
5. se o acampamento é uma zona totalmente segura ou pode sofrer ataques e
   eventos de defesa;
6. o que acontece quando muralhas, serviços ou torres são destruídos e quais
   podem ser reconstruídos durante a mesma run;
7. como funcionam resupply, depósito e upgrades quando o jogador está noutra
   ilha ou num Field Outpost;
8. quais os indicadores no HUD e no mapa para tier, integridade, sockets,
   serviços e direção dos ataques;
9. como evitar spawns dentro do perímetro e garantir corredores para hordas
   largas nos quatro acessos;
10. orçamento máximo de modelos, luzes, sombras, colisores e navegação para o
    Tier 3 em Forward+.

Estas questões são backlog de design. A referência visual aprova a direção da
base final, mas não aprova ainda custos, crafting, NPCs, novos recursos ou a
implementação integral do interior.

## Shadow Forest — controlo e sobrevivência

### Identidade

Baixa visibilidade, pântano, vegetação densa, Spitters e emboscadas curtas.

### Conteúdo e objetivo

- acampamento de guardas abandonado;
- cripta parcialmente submersa;
- estação de bombagem;
- três ninhos de zombies;
- caminhos secundários e caches escondidas.

O jogador elimina os ninhos, recupera componentes do guincho e repara a Rope
Bridge. A ponte recebe dano, mas pode sempre ser reparada para evitar soft-lock.

## High Cliffs — mobilidade e precisão

### Identidade

Verticalidade, vento, visibilidade longa e encontros onde o posicionamento tem
mais importância do que a densidade de inimigos.

### Conteúdo e objetivo

- torre de vigia;
- comboio militar acidentado;
- pedreira e gruta lateral;
- três relés em elevações diferentes;
- atalhos desbloqueáveis e futuras tirolesas.

O jogador ativa os relés, defende-os e abre a entrada das Ancient Ruins.

## Volcano Peak — boss e extração

Não existe um acampamento completo, apenas uma zona de preparação antes da
arena. A sequência final é:

1. desativar três selos ou condutas vulcânicas;
2. abrir a arena;
3. derrotar o boss;
4. impedir o diretor de criar novos inimigos;
5. eliminar todos os zombies ainda ativos;
6. ativar o ponto de extração numa localização específica;
7. chegar ao ponto para concluir a run.

O relógio e a morte do boss, isoladamente, nunca concluem a run.

## Acampamentos avançados

Shadow Forest e High Cliffs podem conter um **Field Outpost**. Depois de limpar
a zona, o jogador escolhe apenas um módulo por run:

- **Resupply Module:** cura e munição;
- **Recon Module:** revela objetivos, caches e elites;
- **Defense Module:** instala uma torre automática.

As melhorias do acampamento principal também melhoram estes postos. Não é
criada uma nova moeda nem uma quarta árvore de bónus.

## Progressão e recompensas

- XP da run continua a oferecer cartas temporárias;
- Scrap compra acampamento, outposts, reparações e passagens;
- Credits, skill tree, classes e ARMORY continuam permanentes;
- a primeira conclusão de uma ilha pode desbloquear um blueprint temático.

Recompensas candidatas, ainda não aprovadas para implementação:

- Shadow Forest: Carbine ou resistência a ácido;
- High Cliffs: DMR e progressão do Recon Scout;
- Volcano Peak: Grenade Launcher ou progressão do Demolitionist.

## Noclip de desenvolvimento

Ferramenta apenas para builds de desenvolvimento:

- `Mouse 4` ativa/desativa;
- `WASD` move relativamente à câmara;
- `Space` sobe, `Ctrl` desce e `Shift` acelera;
- colisão, gravidade, armas e interação ficam desativadas;
- o HUD apresenta `NOCLIP // DEBUG`;
- ao sair, o jogador regressa à última posição física segura se estiver dentro
  de geometria ou fora de terreno navegável;
- nunca é guardado no save nem disponibilizado numa build final.

## Ordem de implementação

1. [x] noclip de desenvolvimento e indicador no HUD;
2. [x] vertical slice de Dawn Beach com recolha, acampamento e escolha A/B;
3. [ ] playtest de distâncias, leitura e tempo de exploração;
4. [x] Shadow Forest — três ninhos abatíveis, peças de guincho e reparação da
   Rope Bridge (`shadow_forest_hub.gd`, `shadow_forest_nest.gd`);
5. [x] High Cliffs — três relés em elevações diferentes, com carga
   interrompível, a abrir a barreira das Ancient Ruins
   (`high_cliffs_hub.gd`, `high_cliffs_relay.gd`);
6. [x] Volcano Peak, fase finita e extração: três selos abrem a arena, The
   Breaker dispara a fase finita e o beacon exige ativação antes da entrada na
   zona; o relógio isolado nunca conclui a run;
7. [x] aumentar a zona marítima para 768 × 768 m / nove regiões, acrescentando
   Ironworks, Mourning Isle e Shipwreck Rocks e três ferries reutilizáveis.

### Expansão marítima implementada

- o grafo passou de quatro para sete ilhas e de quatro para sete rotas;
- Ironworks usa uma prateleira industrial larga, porto inundado e corredores
  para hordas; Mourning Isle usa colina funerária, bosque e depressões húmidas;
  Shipwreck Rocks divide a silhueta por vários afloramentos com destroços;
- Ironworks exige três disjuntores distribuídos pelas suas faixas industriais;
  cada ativação tenta introduzir um Brute sem ultrapassar o orçamento global.
  O ferry, o manifest e um anel físico contínuo em redor de Shipwreck Rocks só
  abrem depois de os três estarem online;
- cada ilha opcional contém uma cache de Scrap da run;
- o diretor pausa enquanto o jogador atravessa o oceano e retoma no desembarque;
- sete bancos de nevoeiro escondem os corredores marítimos bloqueados. A escolha
  A/B, a reparação da Rope Bridge, os relays, a rede de Ironworks ou a primeira
  partida do ferry respetivo removem apenas o banco dessa progressão;
- a descoberta é mantida durante a run, mas ainda não é persistida no save;
- continuam pendentes objetivos completos próprios para Mourning Isle e
  Shipwreck Rocks, streaming por zona marítima e playtest humano de ritmo e
  leitura.

### Notas de implementação

- **Ninhos são abatidos, não interagidos.** A identidade da ilha é emboscada e
  baixa visibilidade, e um objetivo que se *limpa* assenta nisso melhor do que um
  a que se chega e se carrega em F. A ponte ao lado já usa o mesmo caminho de
  dano, portanto os objetos de mundo aqui partilham o contrato.
- **Relés carregam, não ligam.** O plano pede "ativa os relés, defende-os".
  Um relé que ficasse pronto no instante em que se lhe toca fazia da ilha
  "caminhar até três sítios"; só passa a ser "aguentar três sítios" porque a
  carga demora e pode ser interrompida por dano. Um relé já online não se perde
  — um tiro tardio não pode voltar a selar uma ilha que já foi paga.
- **O diretor de horda está ligado ao arquipélago** (2026-08-02). Oito pontos
  de spawn em anel por ilha, 32 no total, todos fora de água. A regra "só a ilha
  ativa mantém IA" sai de graça: o diretor ordena os pontos por distância ao
  jogador e fica com os mais próximos, portanto marcadores de uma ilha distante
  nunca são escolhidos. O orçamento do plano — 90 ativos, guarda 120, fila 12,
  duas instanciações por frame — está verificado por teste, não assumido.
- **O diretor vive na cena, não é construído em código.** As suas procuras `%`
  resolvem contra o próprio `owner`, que um nó criado em runtime só tem depois
  de o `add_child` já ter corrido o `_ready` — construí-lo em código deixava-o a
  segurar dois nulos.
- **Etiquetas de mundo: nunca `fixed_size` sem esconder por proximidade.** Um
  `Label3D` com `fixed_size` mantém o mesmo tamanho no ecrã a qualquer distância;
  com `no_depth_test` por cima, desenha-se ainda através do terreno. As duas
  juntas puseram todas as etiquetas de todas as ilhas em tamanho real por cima do
  jogador, empilhadas e ilegíveis. Duas mitigações são aceitáveis e o arquipélago
  usa ambas: escalar com a distância mais `visibility_range_end`, ou ficar
  escondida até o jogador chegar. `tests/test_destiny_archipelago.gd` verifica-o
  em todas as ilhas, para a próxima não repetir o erro.
- **A regra do soft-lock apanhou um bug real.** O `_collapse()` da ponte
  desativava a colisão com `set_deferred` e o `reset_bridge()` reativava-a de
  imediato: destruir e reparar dentro do mesmo frame deixava a ponte de pé, com
  bom aspeto e sem nada onde pisar. Corrigido pondo as duas a diferir.
