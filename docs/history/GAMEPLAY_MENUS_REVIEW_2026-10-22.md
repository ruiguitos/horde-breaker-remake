# Jogabilidade, menus e direção artística — 22 de outubro de 2026

## Parecer

Os menus têm uma identidade visual mais consolidada do que o cenário de
combate observado. A base de jogo é coerente: deslocação, Breaker,
disparo automático, objetivos por ilha e escolhas de build. O próximo
investimento deve tornar estas regras fáceis de perceber e dar ao combate
o mesmo cuidado de apresentação que já existe no título e no Armory.

Não recomendo um redesenho geral dos menus nem mais sistemas nesta fase.
Recomendo uma passagem de clareza de regras e textos, seguida de uma área
de combate com acabamento consistente e playtest com pessoas novas.

## Método e limites

- Estado local sobre `a79ae70`, com alterações em curso nos mapas e na
  simulação. Esta revisão descreve esse estado, não uma versão publicada.
- Inspeção do código, dados de armas/cartas/perks, decisões e documentação.
  Decisões recentes prevaleceram sobre propostas antigas do GDD.
- Capturas novas no Godot 4.7.2, Forward+, RTX 5060, 1600×900. Os ensaios
  isolados usam uma área lógica de interface de 1152×648, ampliada para
  essa resolução. Foram vistos título, Armory, armas, perks, rotas,
  trânsito, definições, arquivo, debrief, cartas, pausa e três câmaras.
- Perfis e estatísticas das capturas são dados de ensaio. O cenário de
  combate é Town, seed 7, com 24 inimigos colocados para comparar a leitura
  das silhuetas; a simulação foi congelada. Não representa uma onda real.
- Não houve playtest humano, audição crítica, comando físico, medição de
  desempenho com 150 inimigos ou validação de todas as ilhas. Não atribuo
  uma nota numérica à diversão ou ao equilíbrio com base em imagens.
- Não foram alteradas regras, modelos, menus, TODO ou DECISIONS. Não foi
  repetida a suite: esta entrega é uma análise e documentação.

Capturas preservadas em
[`docs/design/gameplay_menus_review_20261022/`](../design/gameplay_menus_review_20261022/).
Erros iniciais das ferramentas de captura foram corrigidos nos auxiliares
temporários; não foram classificados como defeitos do jogo. As capturas
de pausa e de fluxo aqui usadas são das execuções corrigidas.

## O que conservar

| Área | Qualidade existente | Razão para conservar |
|---|---|---|
| Título | Ação principal evidente, ilustração forte, paleta coerente | Comunica expedição marítima e cria uma entrada reconhecível |
| Armory | Personagem em cenário 3D, equipamento fixo à direita, Start Run visível | Liga a escolha de equipamento à fantasia do jogo |
| Estados da interface | Foco com cantoneiras, seleção com visto, bloqueio com cadeado/tracejado | A distinção não depende só de cor |
| Combate | Breaker, sprint e habilidades com papéis diferentes; silhuetas grandes de Brute/Bloater | Há decisões de posição e ameaças com formas reconhecíveis |
| Progressão e saída | Cartas pausam a ação; debrief separa ilhas e Intel e mostra compras possíveis | Ajuda a ligar uma run à seguinte e reduz a punição de morrer |

## Cinco prioridades

### 1. P1 — Ensinar o contrato do disparo e das câmaras

**Observado no código:** a câmara fixa usa um cone de ±50° e seleção
automática por orientação/distância. Primeira e terceira pessoa selecionam
um corpo próximo do raio da mira, com margem angular de 6° além da
silhueta; o tiro segue o ponto escolhido no alvo. Não é simplesmente um
tiro manual que sai sempre pela cruz. Headshots também usam regras
diferentes entre esses modos. As três câmaras são uma decisão aprovada.

**Observado na interface:** há a indicação AUTO-FIRE no HUD e ajudas das
habilidades, mas as dicas de loading vistas são aleatórias e não ensinam
esta diferença de forma garantida. A apresentação de arma tática em
primeira pessoa pode criar a expectativa habitual de disparar com clique.
Isto é um risco de aprendizagem, não uma falha reproduzida com jogadores.

**Proposta:** uma introdução curta e contextual na primeira ilha: orientar
para um alvo e ver o disparo automático; usar o Breaker para abrir espaço;
identificar o objetivo. Mostrar uma ajuda de uma linha ao mudar de câmara.
Dar feedback discreto de alvo elegível para o disparo sem encher o ecrã
com etiquetas nem contrariar a cruz oculta da AR durante ADS.

**Critério proposto:** pelo menos 4 de 5 pessoas novas explicam como se
dispara, usam o Breaker e identificam o próximo objetivo nos primeiros
90 segundos, sem instruções verbais do autor. É uma meta de playtest,
não um resultado desta revisão.

**Fontes:** `game/core/game_input.gd:18`, `game/data/game_data.gd:172`,
`game/world/island_run.gd:2025`, `:2365`, `:2522`, `:2559`;
`game/ui/loading_screen.gd:256`; `game/data/dialogue/radio.dialogue:245`.

### 2. P1 — Corrigir expectativas nos textos e comparações

| Caso confirmado | Consequência provável | Proposta de apresentação |
|---|---|---|
| Shotgun: linha principal «9 DAMAGE»; oito projéteis só na descrição | Comparação enganadora com os 12 da AR | «8 × 9 DAMAGE», alcance e dispersão; 72 é apenas o máximo teórico se todos acertarem, não dano garantido |
| Bigger Mags aumenta a reserva finita, não o carregador | O nome promete uma alteração diferente da que ocorre | Renomear para algo como «Ammo Reserves», mantendo o efeito atual |
| Head Hunter mostra «Headshot cone …°» também no equipamento usado em FPS | A unidade sugere um cone real onde o código amplia um raio de tolerância | Explicar a tolerância de headshot por modo ou usar uma descrição comum com detalhe contextual |
| Debrief diz «Lost on death: … Intel», referindo-se ao bónus de extração | Pode parecer que foi retirada moeda já ganha | «Extraction bonus not earned», junto de «Intel kept» |

Na lista de armas, separar principais e secundárias e facilitar a
comparação com a arma equipada. Hoje duas cartas grandes ocupam quase a
lista visível e as categorias aparecem intercaladas. Manter dano,
cadência e alcance, mas dar igual clareza a recarga, reserva e mobilidade.
Na escolha de classe, pôr as diferenças decisivas à vista: +40 HP e
Breaker com cooldown menor no Vanguard, em vez de depender só do texto
«Tough frontline» ou de tooltip.

**Critério proposto:** uma pessoa consegue distinguir carregador de
reserva, explicar o que perde ao morrer e justificar a escolha de arma
sem abrir documentação externa. As fórmulas e a economia não precisam
de mudar para corrigir estes textos.

**Evidência:** [armas](../design/gameplay_menus_review_20261022/weapons.png),
[cartas](../design/gameplay_menus_review_20261022/gameplay_cards.png),
[perks](../design/gameplay_menus_review_20261022/perks.png) e
[debrief](../design/gameplay_menus_review_20261022/debrief.png).
Fontes: `game/states/armory.gd:532`, `game/data/weapons/shotgun.tres`,
`game/data/cards/bigger_mags.tres`, `game/world/island_run.gd:547`,
`:2522`, `game/states/debrief.gd:440`.

### 3. P1 — Aproximar o acabamento do combate do nível dos menus

**Parecer artístico:** o porto ilustrado e o abrigo do Armory têm
composição, materiais e iluminação mais resolvidos. No Town observado,
as fachadas repetidas sem aberturas, grandes superfícies uniformes e
poucos elementos de escala fazem o cenário parecer menos acabado.
Armas e personagens têm muito mais detalhe de superfície do que essas
fachadas. Isto não demonstra o mesmo problema em todos os biomas.

Manter as formas em blocos e os materiais realistas aprovados. Trabalhar
primeiro formas grandes, contraste e hierarquia; depois acrescentar
detalhe. Escolher uma área representativa com desembarque, percurso,
objetivo e saída. Usar portas/janelas, limites de percurso, variação de
volumes e um landmark que permita orientar-se sem olhar sempre para o mapa.
Evitar resolver a diferença apenas com mais texturas, nevoeiro ou props.

As formas de Brute e Bloater já são distinguíveis. Preservá-las e testar
Runner/Grabber/Screamer em movimento, de frente e de costas. A quantidade
de gore não deve substituir a silhueta que permite reconhecer a ameaça.

**Critério proposto:** reconhecer inimigos e direção do objetivo a
distâncias de combate nas três câmaras; uma área consistente em luz,
escala, colisões e materiais antes de estender o acabamento às restantes.

**Evidência:** [Armory](../design/gameplay_menus_review_20261022/armory.png),
[primeira pessoa](../design/gameplay_menus_review_20261022/gameplay_first_person.png)
e [terceira pessoa](../design/gameplay_menus_review_20261022/gameplay_third_person.png).

### 4. P2 — Dar ao HUD a mesma hierarquia dos menus

**Parecer visual:** a interface de campo mantém o cenário visível, mas
muitos textos usam contornos espessos, maiúsculas e peso semelhante.
Vida, escudo vazio, XP, estatísticas, rádio e legenda do minimapa disputam
atenção. Em FPS, a arma e a manga também ocupam parte considerável do
quadrante inferior direito. Isso merece uma revisão conjunta de
enquadramento e HUD, sem reduzir a arma separadamente das mãos.

Conservar vida, munição, objetivo e habilidades como informação principal.
Dar menos peso à estatística contínua e ao escudo quando vazio; reforçar
apenas os estados urgentes. Usar contorno mais leve nos textos secundários
e uma escala tipográfica mais consistente. Não repor painéis opacos no
HUD ou na pausa: a transparência é uma decisão do utilizador.

Há já LOW HEALTH, indicação de impacto e áudio de perigo. A proposta é
melhorar a prioridade desses sinais, não afirmar que estão ausentes.
As cartas já têm bom foco e categorias; a área inferior pode mostrar
melhor o antes/depois da escolha, em vez de só uma descrição da fórmula.

**Critério proposto:** identificar vida, munição e Breaker disponível
numa consulta rápida, em combate e sobre fundos claros/escuros, a 720p
e 1080p. Testar também 60% e 100% de HUD; encolher tudo não substitui
reorganizar a informação.

**Evidência:** [perigo](../design/gameplay_menus_review_20261022/gameplay_danger.png),
[pausa](../design/gameplay_menus_review_20261022/gameplay_pause.png).
Fontes: `game/ui/hud.gd:541`, `:1604`, `:2099`.

### 5. P2 — Melhorar decisões rápidas nos menus sem os reconstruir

| Ecrã | Intervenção recomendada |
|---|---|
| Rotas | Recapturar miniaturas que ainda mostram a cruz da mira e escolher enquadramentos que identifiquem Town/Port/Jungle; a imagem do Port observada comunica sobretudo uma estrada |
| Trânsito | Manter a partida automática de 5 s aprovada. Dar protagonismo ao mantimento escolhido e ao resumo do que será aplicado. Tornar explícito que Esc/B suspende a contagem enquanto abre as opções de saída |
| Perks | Conservar três ramos e painel de detalhe. Reduzir a competição entre alternativas, ranks, tier, cadeados e ações; pôr benefício, custo e estado equipado antes das operações de gestão |
| Controls | Manter rebind, sensibilidade e dead zone. Rever a densidade: na captura só duas linhas de ações cabem abaixo dos ajustes. Tornar ações de combate mais fáceis de encontrar |
| Acessibilidade | Acrescentar propostas de controlo de tremor/bob e ADS por manter/alternar; separar escala de texto da redução global do HUD. Estas opções não foram encontradas nas definições inspecionadas |

Alterar a duração da contagem, o sistema de perks ou os três modos de
câmara exigiria uma nova decisão; não são correções automaticamente
autorizadas por esta análise. Arquivo e Settings já têm uma base modal
coerente. O debrief já mostra compras possíveis: conservar esse incentivo.

**Evidência:** [trânsito](../design/gameplay_menus_review_20261022/transit.png),
[Controls](../design/gameplay_menus_review_20261022/controls.png).
Fontes: `game/states/boat.gd:179`, `game/ui/settings_panel.gd:173`,
`game/ui/menu_dialog.gd:50`, `tools/dev/route_pictures.gd:36`.

## Equilíbrio e ritmo: hipóteses a testar, não conclusões

O diretor já alterna crescimento, pico e alívio; não recomendo acrescentar
outro sistema de ondas. O alívio pára novos spawns, mas não elimina a
horda existente. Medir se o jogador sente mesmo espaço para recuperar,
sobretudo quando eventos da missão forçam picos.

A velocidade base é 6 m/s; a dos Runners varia entre 4,6 e 5,4 m/s. A
Machine Gun reduz a deslocação para 4,8 m/s, a SMG aumenta-a para 6,9 m/s.
Isto cria papéis de mobilidade diferentes e torna relevante testar se
correr em círculos em áreas abertas elimina demasiada pressão. Não
prova que a horda seja fácil: terreno, objetivos, especiais e recargas
mudam o resultado.

Para comparação inicial, sem upgrades, headshots, falhas ou interrupções:

| Principal | Dano/s durante disparo | Dano/s médio teórico com recarga |
|---|---:|---:|
| AR | 108 | 108 — recarga atual instantânea |
| SMG | 128; 160 até 6 m | ~89; ~111 até 6 m |
| Machine Gun | 216 | ~151 |

A média usa `dano × carregador / (carregador / cadência + recarga)`.
É uma aproximação contínua, não uma medição de DPS real ou uma conclusão
de que uma arma seja melhor. Mostra por que a cadência isolada do menu
não explica o papel de cada arma. A decisão sobre recarga da AR continua
em aberto no TODO; não a alterei.

## Próxima ronda recomendada

1. Corrigir os textos ambíguos e tornar explícito o disparo automático.
2. Polir uma área de combate, HUD e leitura de ameaças em conjunto.
3. Fazer cinco primeiras sessões observadas, antes de alterar números.

Registar: tempo até perceber o disparo; primeiro Breaker; tempo até o
objetivo; mortes e causa percebida; escolhas de carta; uso da secundária;
tempo parado a ler; pontos em que o jogador procura o minimapa; e vontade
de iniciar outra run. Testar teclado/rato e comando físico, e comparar
as três câmaras. Medir frametimes p95 com 150 inimigos em jogo completo
num ensaio separado. Não usar os bots com vida reposta como prova de
equilíbrio humano.

## Verificação consultiva

O JEV recebeu apenas notas sanitizadas sobre a apresentação do dano, o
nome/efeito da carta de reserva e os limites desta avaliação; não recebeu
código, ficheiros ou imagens. As três alegações foram consideradas
suportadas pelas notas, sem contradições. Isto verifica coerência do
resumo, não substitui a inspeção local nem valida diversão, acessibilidade
ou equilíbrio com pessoas.
