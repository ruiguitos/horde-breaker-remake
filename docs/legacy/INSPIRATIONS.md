# Horde Breaker — Referências e ideias

Pesquisa iniciada em 2026-07-17 e atualizada em 2026-07-18. Estas referências servem para identificar
padrões de design; não autorizam copiar assets, código ou conteúdo protegido.

## Comparação atual de gameplay e HUD (2026-09-06)

Base: leitura da cena da expedição, controlador/armas hitscan, skills,
progressão/cartas de run, HUD, radar, mapa tático, painel/tracker de objetivos,
pausa e resultado. Fontes primárias consultadas nesta revisão. Não foi feita
uma análise visual lado a lado nem jogadas sessões dos jogos de referência;
as propostas de HUD abaixo são conclusões de design, não cópias dos seus layouts.

### Identidade a preservar

**Shooter de expedição em terceira pessoa com combate assistido e escolhas de
build.** A combinação diferenciadora é missão por ilha + escolha de rota +
logística de munição + extração física. Não tentar ser simultaneamente um
survivor de uma única arena, um simulador de construção e um shooter cooperativo.
Esta é a direção recomendada para playtest, não uma mudança já aplicada.

### Comparação com os seis jogos já apresentados nos documentos

| Referência / facto suportado pela fonte | Situação em Horde Breaker | Adaptação proposta e critério de teste |
|---|---|---|
| [Yet Another Zombie Survivors — estúdio](https://yazs.awesomegamesstudio.com/): sinergias entre armas/abilities e equipa até três | Há auto-fire, 11 cartas e variantes; a maioria das cartas altera atributos | Duas cartas de comportamento, uma de recarga e outra de troca de arma. O jogador deve conseguir explicar o que passou a fazer de forma diferente; não implementar aliados com IA |
| [Deep Rock Galactic: Survivor — página do jogo](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/): auto-shooter, recursos, objetivos e retorno à extração | Objetivos e extração existem; resupply do hub não está integrado e duas ilhas opcionais oferecem sobretudo caches | Um desvio com recompensa anunciada antes da escolha; objetivo, risco e regresso ao ferry legíveis. Medir quantos jogadores escolhem o desvio e o seu custo em tempo/munição |
| [Risk of Rain 2 — página do jogo](https://store.steampowered.com/app/632360/Risk_of_Rain_2/): itens combináveis, dificuldade crescente e modificadores | Há raridades fixas e ranks, mas pouco comportamento emergente; a expedição desativa prolongamento da run | Um modificador por ilha e uma escolha entre duas recompensas. Comparar duas runs no mesmo mapa; não assumir que PUSH ON já funciona nesta cena |
| [Killing Floor 2 — visão oficial](https://killingfloor2.com/overview/): perks com habilidades/armas e vagas até ao boss; cenários com identidades distintas | Horda contínua com início mais lento, especiais e boss; faltam pausas logísticas funcionais no hub | Criar um intervalo local de preparação após missão, sem regressar a rondas globais. Brute e Spitter devem exigir respostas diferentes, não apenas mais disparos |
| [World War Z: Aftermath — editor](https://www.focus-entmt.com/en/games/world-war-z): episódios, classes/perks e missões com modificadores | Existem missões de ativação/recolha e defesa, mas radar trata inimigos como pontos semelhantes | Introduzir encontro de defesa com fases anunciadas e identificação prioritária de especiais. Avaliar mortes sem perceber a ameaça; não copiar centenas de NPCs |
| [Vermintide 2 — criador](https://www.vermintide.com/game-info): carreiras com árvores, abilities ativas/passivas e equipamento próprios | Variantes reutilizam os modelos, mas sobretudo alteram valores; não existe ability ativa geral de classe | Melhorar uma variante existente antes de criar outra personagem. Explicitar gatilho, efeito, duração e cooldown; só desenhar indicador de ability quando o sistema existir |

Não usar as contagens antigas de carreiras, armas ou talentos como alvos. A
página-base de Vermintide descreve as carreiras do lançamento, não um inventário
atualizado de todos os DLCs. As seis fontes suportam os padrões gerais acima;
detalhes de tiers/overclocks nas notas antigas precisam de confirmação própria.

### O que o código revela sobre a experiência atual

1. **Combate híbrido já existe.** O ataque manual tem prioridade quando pedido;
   sem ele, o sistema procura alvo de proximidade com linha de tiro. Auto-reload
   inicia quando o carregador esvazia. Alcances reais: AR 12 m, Pistol 10 m,
   Shotgun 8 m, SMG 13 m; os 6 m no GDD antigo eram o default do script.
2. **Escolhas não são só multiplicadores ilimitados.** São 11 cartas, cinco
   raridades, três ofertas distintas e limite de cinco níveis (lifesteal: três).
   Porém, só lifesteal acrescenta um gatilho de combate; o resto é sobretudo
   atributo. Priorizar consistência na troca de arma antes de novas sinergias.
3. **A decisão tem um prazo oculto ao planeamento antigo.** O painel pausa o
   mundo mas escolhe aleatoriamente ao fim de 10 s; Esc não abre a pausa normal
   enquanto a árvore já está pausada. Recomenda-se testar escolha sem prazo por
   defeito, com opção temporizada futura. Não foi alterado nesta tarefa.
4. **O radar não é um mapa navegável.** Raio 70 m, atualização 0,08 s, máximo
   40 inimigos, direção baseada no VisualRoot; não desenha costa, terreno ou
   gates. O objetivo intermédio vive noutro painel; o radar só consulta extração.
5. **Informação de munição incompleta.** O HUD principal mostra só a arma ativa.
   O aviso pulsa abaixo de 25% do carregador, independentemente da reserva;
   um carregador cheio com reserva zero não recebe esse aviso de escassez.
6. **Orientação usa referências diferentes.** A seta da missão é relativa à
   câmara; o radar roda pelo corpo. Quando divergirem, o jogador precisa de
   fazer conversão mental. Testar uma orientação consistente, incluindo C/aim.
7. **Pausa e resultado já têm valor.** A pausa lista cartas/níveis/raridades;
   o resultado mostra duração, kills, nível, Scrap e Credits. Melhorar estes
   resumos em vez de acrescentar outro ecrã redundante.

### Propostas de HUD, com âmbito controlado

| Prioridade | Melhorar | Não fazer | Aceitação proposta |
|---|---|---|---|
| H1 | Mostrar slots 1/2, carregador e reserva; distinguir LOW MAG, LOW RESERVE e EMPTY; sugerir troca se o outro slot puder disparar | Troca automática não pedida ou alerta sonoro por frame | Valores corretos em disparo, recarga, pickup parcial e troca; aviso legível sem depender só da cor |
| H2 | Ligar o radar ao objetivo do tracker; destacar target e especiais; orientação consistente | Duplicar estado de missão no HUD ou desenhar um caminho seguro inexistente | Objetivo e radar concordam em todas as sete ilhas, ferries e revisitas; alvo libertado não causa erro |
| H3 | Hierarquia: sobrevivência/arma, uma missão, radar, feedback; agregar ganhos repetidos e reservar mensagens críticas | Novas faixas permanentes e texto sobre a mira | Sem sobreposição a 1152×648/1920×1080; foco teclado/comando; texto comprido continua utilizável |
| H4 | Cartas mostram efeito atual → seguinte, contexto do loadout e resumo da build | Copiar um inventário extenso ou apresentar dano/cadência como DPS medido | O jogador consegue comparar duas escolhas sem abrir outro ecrã; testar a remoção opcional do timer |
| H5 | Resultado: ilhas/missões concluídas, build usada e indicação clara de ganhos permanentes versus recursos perdidos | Inventar causa da morte ou precisão sem recolha de eventos | Totais conciliam com save e run; voltar ao menu não concede recompensa duas vezes |

O contador HOSTILES atual vem do diretor, não é uma contagem local dos pontos
visíveis no radar. Explicitar esse significado ou mostrar a pressão local como
indicador diferente. O mapa Tab não pausa: não colocar nele decisões demoradas
sem testar a segurança e o controlo do jogador.

### Mapas: variedade de decisões antes de extensão

- **Mourning Isle:** combinar a cache existente com um encontro curto em torno
  de sinos; abrir linhas de fuga e sinalizar o ferry de regresso.
- **Shipwreck Rocks:** expandir a recuperação da caixa negra existente com
  salvamento/defesa finitos; não introduzir um segundo objetivo com o mesmo nome.
- **Fort Breaker:** arsenal, pátio e posição elevada; duas saídas e preparação
  antes de defender o portão. **Quarantine Key:** enfermaria/bombagem e rota em
  crescente; Spitters e zonas perigosas legíveis. Ambas continuam propostas.
- Variar largura, cobertura, visibilidade, composição e recompensa, não só a
  textura do terreno. Não aumentar área residente antes de resolver navegação
  e medir custos de regiões, sombras, colisões e encontros distantes.

### Experiências de playtest (ainda não executadas)

Comparar runs com o mesmo perfil/loadout, rota, renderer e definições. Controlar
as seeds quando existir suporte; caso contrário repetir e registar a variabilidade.
Não comparar um perfil com skills completas com outro acabado de criar.

1. **Primeiros cinco minutos:** tempo até perceber o objetivo, primeira carta,
   primeira falta de munição e escolha de rota. Separar auto-fire e uso manual.
2. **Escolha de build:** versão atual de 10 s versus protótipo sem timer;
   medir escolhas expiradas, tempo de leitura e compreensão do efeito.
3. **Leitura em combate:** HUD atual versus H1/H2; pedir ao jogador que identifique
   reserva disponível, arma alternativa e direção do objetivo sem parar.
4. **Expedição 15–30 min:** missão opcional, ferry, boss/extração, pausa/retoma,
   FPS p50/p95/p99 e memória. O benchmark atual injeta munição: não serve para
   medir escassez. Não usar apenas FPS médio ou headless como prova visual.

Ordem de execução em [ROADMAP.md](ROADMAP.md); riscos/contratos em
[ARCHITECTURE.md](ARCHITECTURE.md). Não foram implementadas as propostas acima.

## Notas históricas de pesquisa — não representam o estado atual

As secções seguintes conservam a investigação anterior. Referências a 36 nós,
13 armas, rondas e falta de modelos não são o inventário nem o backlog atual.

## Jogos próximos

### World War Z: Aftermath

A página oficial destaca grandes hordas, progressão de herói e oito classes com
perks próprios. É a referência mais próxima para pressão de zombies num shooter
em terceira pessoa.

Fonte: [World War Z: Aftermath — Focus Entertainment](https://www.focus-entmt.com/en/games/world-war-z)

Ideias úteis:

- identidade de classe imediatamente percetível;
- inimigos especiais que obrigam a mudar de posicionamento;
- progressão da classe sem depender apenas do dano da arma.

### Killing Floor 2

O jogo associa perks a habilidades, poderes e conjuntos de armas, usando rondas
que terminam num boss.

Fontes: [visão geral oficial](https://www.killingfloor2.com/overview/) e
[galeria oficial de armas](https://killingfloor2.com/overview/weapons.html).

Ideias úteis:

- cada classe deve ter uma vantagem numérica simples e verificável;
- introduzir tipos de inimigo por função, não apenas por quantidade;
- reservar uma ronda final para um boss com leitura clara.

### Deep Rock Galactic: Survivor

As classes começam com armas próprias, desbloqueiam novos equipamentos por nível
e combinam melhorias temporárias da missão com progressão permanente.

Fontes: [armas por classe](https://deeprockgalactic.wiki.gg/wiki/Survivor%3AWeapons),
[equipamento e melhorias](https://deeprockgalactic.wiki.gg/wiki/Survivor%3AEquipment)
e [milestones](https://deeprockgalactic.wiki.gg/wiki/Survivor%3AMilestones).

Ideias úteis:

- apresentar sempre os dois slots do loadout;
- desbloquear alternativas através do nível específico da classe;
- usar objetivos pequenos para desbloquear armas ou variantes.

### Risk of Rain 2

Survivors diferentes têm mecânicas e estilos próprios, enquanto itens encontrados
durante a partida criam combinações variáveis e a dificuldade aumenta ao longo da
sessão.

Fontes: [Survivors of the Void](https://www.gearboxpublishing.com/press_release/risk-of-rain-2s-first-ever-expansion-survivors-of-the-void-launches-today/)
e [Railgunner](https://www.gearboxpublishing.com/press_release/risk-of-rain-2-survivors-of-the-void-introduces-its-first-new-survivor-railgunner/).

Ideias úteis:

- melhorias temporárias que criem sinergias com o passivo da classe;
- variantes de habilidade em vez de aumentos lineares infinitos;
- modificadores de arena para variar partidas sem criar mapas completos novos.

### Yet Another Zombie Survivors

Combina personagens, armas, habilidades, árvore permanente e objetivos de
progressão num formato centrado em hordas de zombies.

Fontes: [página oficial na Steam](https://store.steampowered.com/app/2163330/Yet_Another_Zombie_Survivors/)
e [descrição oficial](https://yetanotherzombie.wiki.gg/wiki/Yet_Another_Zombie_Survivors).

Ideias úteis:

- objetivos de mastery por personagem;
- evolução de armas após cumprir condições claras;
- autoapontar e disparar para reduzir a carga de controlo, preservando provisoriamente uma opção manual;
- modos ou modificadores adicionais apenas depois do core loop estar afinado.

## Segunda ronda de pesquisa (2026-08-01) — classes, armas e árvores

Feita para responder a "mais classes, armas e skill trees". O padrão útil não foi
o que os jogos põem nas árvores, foi **como estruturam a escolha**.

### Killing Floor 2 — a árvore mais simples que funciona

Cada perk sobe até ao nível 25 e, **a cada cinco níveis, escolhe-se entre duas
habilidades**. Só uma fica equipada por patamar, e as escolhas podem ser trocadas
antes ou até a meio da partida.

Fonte: [Perks (Killing Floor 2)](http://www.wiki.killingfloor2.com/index.php?title=Perks_%28Killing_Floor_2%29)

Ideias úteis:

- cinco patamares de "isto **ou** aquilo" leem-se melhor do que 36 nós;
- poder trocar sem penalização transforma a árvore num **loadout**, não num
  compromisso permanente — e remove o medo de estragar a personagem;
- a última escolha é a que define a classe, não a que soma mais dano.

### Deep Rock Galactic: Survivor — progressão dupla

Overclocks escolhem-se aos níveis 6, 12 e 18 **da arma**, não da personagem. As
*milestones* desbloqueiam classes, subclasses e armas; as *meta upgrades* são
melhorias permanentes partilhadas por todas as classes.

Fontes: [Overclocks](https://deeprockgalactic.wiki.gg/wiki/Survivor:Overclocks) ·
[Class Mods](https://deeprockgalactic.wiki.gg/wiki/Survivor:Class_Mods) ·
[Meta Upgrades](https://deeprockgalactic.wiki.gg/wiki/Survivor:Meta_Upgrades)

Ideias úteis:

- separar o que é **da classe** do que é **partilhado** (temos as duas coisas
  misturadas numa árvore só);
- subclasses são conteúdo barato: o Tinkerer é "usa todas as armas e ganha mais
  XP", não um corpo novo;
- desbloquear por objetivo cumprido em vez de por moeda.

### Vermintide 2 — o padrão que o nosso orçamento de arte permite

Cinco personagens, até **19 carreiras**. Uma carreira muda passivo, habilidade e
conjunto de armas — **sobre o mesmo corpo**.

Ideias úteis:

- é o único padrão dos quatro que dá "mais classes" **sem modelos novos**;
- é o que já fazemos com as variantes de mastery (VETERAN/BERSERKER), por isso o
  sistema existe e está a metade do caminho.

### O que a pesquisa não resolve: só há três corpos e três armas

O que decide o que é possível aqui não é design, são os assets:

| Recurso | O que existe | Consequência |
|---|---|---|
| Rigs de personagem | **3** (Lis, Matt, Sam) | já usados por Recruit/Renegade/Medic — não há corpo para uma 4ª classe |
| Modelos de arma | **3** (Pistol, Rifle, Shotgun) + malhas embutidas | armas novas têm de reutilizar malhas, como as 13 atuais já fazem |
| Árvore de skills | 1 partilhada, 36 nós | o save **já guarda `skill_nodes` por personagem** — árvores por classe não precisam de arte nenhuma |

Conclusão: **as árvores por classe são o único dos três pedidos que não esbarra
em arte.** "Mais classes" só é possível como carreiras sobre os corpos que há (o
padrão Vermintide), e "mais armas" como variantes de comportamento sobre as
malhas que há (o padrão overclock).

## Ideias recomendadas para Horde Breaker

Ordem sugerida, mantendo etapas pequenas:

1. escolha de uma melhoria entre rondas;
2. um inimigo especial que force reposicionamento;
3. objetivo de mastery simples para cada classe;
4. primeira arma alternativa por slot;
5. quinta ronda com boss;
6. modificadores opcionais de arena.

Não é recomendado nesta fase aumentar muito o número de personagens, criar
multiplayer ou construir árvores de talentos extensas. Primeiro devem ser
playtestados os três passivos e os quatro tipos de arma atuais.
