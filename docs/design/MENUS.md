# Menus — referência tática aprovada

A implementação segue a imagem aprovada pelo utilizador: equipamento militar
sóbrio, painéis escuros, tipografia condensada, contornos finos e destaque âmbar.
O texto do jogo continua em inglês.

## Os quatro ecrãs

| Ecrã | Ação principal | Dados reais |
|---|---|---|
| Título | Deploy → Armory | Estatísticas do perfil; definições e arquivo |
| Armory | Start Run | Classes, armas, Intel, Threat e slots/perks |
| Barco / rotas | Confirm Route | Mantimento, bioma, missão e modificador sorteados |
| Pausa | Resume | Jogo atual desfocado; definições, controlos e abandono |

Os botões são Control/Button do Godot: funcionam com rato, teclado e ações
de comando registadas no InputMap. Os estados indisponíveis ficam desativados;
a rota selecionada tem texto e contorno além da cor. A run só começa a ilha
depois de escolher um mantimento e uma rota. Um mantimento aplica-se uma vez.

O Armory conserva a economia de Profile e grava cada compra/seleção. Os
painéis de definições e arquivo são modais: o foco circula dentro deles,
Esc/B fecha-os e devolve o foco ao botão anterior. Abrir definições na pausa
mantém a simulação parada e bloqueia os atalhos por baixo, incluindo Q.

## Apresentação e limites

A base lógica é 1152 × 648, com canvas_items e proporção preservada. Os
ecrãs foram vistos em Forward+ a 1152 × 648 e 960 × 540. Listas de armas,
perks e ficheiros têm scroll; o botão Start Run fica sempre fora do scroll.

O porto do título, o logótipo e o retrato são imagens estáticas geradas para
esta referência, em game/ui/art. O retrato é comum às três classes; a classe
e os efeitos apresentados mudam com o perfil. Não representa um modelo 3D
equipável. O mapa é um esquema decorativo das duas rotas, sem coordenadas
reais do terreno. As miniaturas dos biomas são ilustrações simples desenhadas
em Godot. A pausa desfoca o jogo real em vez de usar uma imagem de fundo.

O tema está em game/ui/ui_theme.gd; os modais em game/ui/menu_dialog.gd.
SettingsPanel herda o comportamento modal e conserva os três volumes em
percentagem (Master, Sound effects e Music), com slider e campo editável.
A integração preserva o céu Sky3D e o áudio gravado existentes.

## Redesenho de outubro de 2026 (escolhido pelo utilizador)

A 2026-10-10 o utilizador escolheu, a partir das maquetes da tela "Horde
Breaker UI Proposals", as 7 propostas abaixo. A decisão foi registada em
`docs/DECISIONS.md` a 2026-10-11, por pedido explícito do utilizador.

1. **Paleta B, "Atlântico e azulejo":**

   | Papel | Cor |
   |---|---|
   | Fundo basalto | `#0D1216` |
   | Painel | `#0F2830` |
   | Painel elevado | `#143540` |
   | Linhas | `#2A5662` |
   | Texto cal | `#ECE6D3` |
   | Texto secundário | `#9AB0B2` |
   | Âmbar, só para ações e foco | `#F2B23A` |
   | Perigo | `#E8705A` |
   | Objetivos e informação | `#6FA6E6` |
   | Sucesso | `#7FC8B8` |

   - Fontes OFL incluídas no jogo: Barlow Condensed nos títulos, Barlow no
     corpo, IBM Plex Mono nos números e nas teclas.
   - Os estados distinguem-se pela forma e não só pela cor:
     - **foco** são cantoneiras à volta, tipo mira;
     - **escolhido** leva um visto;
     - **indisponível** é tracejado, com cadeado ou com o motivo escrito.
2. **Título:**
   - as estatísticas e as ajudas ficam numa barra no fundo da arte, sem
     sobreposição;
   - novo botão QUICK REDEPLOY, que repete a última corrida;
   - o TEST ISLAND fica discreto;
   - o lema deixa de sair do ecrã.
3. **Barco num só ecrã, sem janela por cima:**
   - rotas e mantimentos lado a lado;
   - a missão fica escrita no cartão da rota, com os modificadores e o
     hazard pay;
   - os mantimentos sem efeito ficam desativados, com o motivo;
   - o botão diz o destino ("DEPLOY TO JUNGLE").
   - O acampamento da expedição usa o mesmo esquema.
   - **Esc / B** ou o botão **BACK** abrem uma janela com KEEP PLAYING,
     RETURN TO ARMORY / CLASSES e MAIN MENU. Não movem apenas o foco.
   - Sair termina a run: conserva o Intel e os ficheiros recuperados nas
     partes/ilhas concluídas, sem o bónus de extração. Antes do primeiro
     desembarque, cancela a preparação sem contar uma run vazia.
   - KEEP PLAYING ou Esc / B fecham a janela e devolvem o foco ao ecrã
     anterior. Mantimentos, rerolls e desembarque ficam bloqueados enquanto
     a janela está aberta; escolher sair só contabiliza a run uma vez.
4. **Cartas de nível:**
   - cada carta tem categoria (cor e forma), ícone, nome, efeito, rank em
     pips, etiqueta NEW/UPGRADE e a sinergia com outras cartas;
   - escolhe-se com o foco e confirma-se com A/Enter, deixando de usar 1–3,
     que também trocam de arma;
   - os botões só respondem 0,4 s depois de as cartas abrirem;
   - a build atual aparece em baixo;
   - há REROLL. A quantidade de rerolls é uma proposta por decidir.
   - O baralho tem de crescer muito ("mais e mais cartas"). Fica para uma
     proposta de design própria.
5. **HUD sem fundos escuros:**
   - texto com sombra diretamente sobre o jogo;
   - o marcador do gerador e os outros marcadores do mundo mantêm a sua
     pastilha;
   - letra maior (a vida a 22 px);
   - o minimapa fica como está, só sem o fundo escuro, com a legenda certa
     para os marcadores que já desenha;
   - habilidades com o tempo de recarga em anel e as teclas reais;
   - slots de arma com munição;
   - seta na borda do ecrã para inimigos fora da vista.
6. **Pausa com a build**, tal como a confirmação de abandono, **sem painel
   escuro**:
   - o jogo desfocado fica visível;
   - o texto leva sombra;
   - os botões e as caixas ficam translúcidos.

   Outros pormenores:
   - mostra as armas, as cartas com rank e o Intel guardado e em risco;
   - ABANDON RUN abre uma confirmação: KEEP FIGHTING fica com o foco e é
     preciso segurar 1 s para abandonar;
   - o Q deixa de abandonar.
7. **Debrief:**
   - resumo por ilha e decomposição do Intel;
   - mostra o que já se pode comprar na armaria;
   - os números sobem a contar;
   - os botões só respondem 0,6 s depois de o ecrã abrir;
   - BACK TO ARMORY e QUICK REDEPLOY.

### Como ficou implementado

O que se afasta das maquetes, ou o que elas não diziam:

- **Barco:**
  - a rota A e o primeiro mantimento útil vêm pré-escolhidos, por isso
    DEPLOY nunca fica desativado;
  - o mantimento só se aplica ao carregar em DEPLOY, e pode-se mudar de
    ideias sem custo;
  - o hazard pay não aparece no cartão da rota: é igual em todas as rotas
    e só se aceita no briefing, ao desembarcar.
- **Pausa e abandono:**
  - morrer ou abandonar guarda o Intel (decisão de 2026-10-05);
  - o que se perde é o bónus de extração ×1,5, e é esse o número de
    "YOU LOSE".
- **Cartas:**
  - a categoria é provisória, tirada do id da carta
    (`GameData.CARD_CATEGORIES`), até haver dados de categoria (P9);
  - as regras do reroll são as constantes provisórias `GameData.REROLLS_*`;
  - R ou Y troca as cartas.
- **Título:** o lema não está em itálico, porque não incluímos a fonte
  itálica.
- **Fim de ilha ou de parte** (`game/ui/island_end_panel.gd`): tem o mesmo
  vidro da pausa e da derrota.
  - O cabeçalho tem visto e cor de sucesso: ISLAND CLEARED, PART CLEARED ou
    EXTRACTED na última.
  - Os números grandes são só desta ilha. Os totais da corrida ficam numa
    linha pequena com a etiqueta RUN TOTAL, para não se confundirem.
  - Mostra as cartas e os power-ups apanhados aqui.
  - A linha NEXT diz para onde vai o CONTINUE.
  - O CONTINUE ignora toques nos primeiros 0,6 s, porque o A do comando
    também é o Breaker.

Testes novos:
- `tests/test_title_debrief_redesign.gd`
- `tests/test_boat_redesign.gd`
- `tests/test_hud_redesign.gd`
- `tests/test_island_end_panel.gd`

## Ecrã de carregamento e diálogos (2026-10-11)

**Ecrã de carregamento** (`game/ui/loading_screen.gd`). O Boot Splash Plus
fica só para o arranque; entre o DEPLOY e a ilha, e entre duas partes da
expedição, aparece o nosso ecrã:

- mostra a corrida e a parte ("BERLENGA EXPEDITION / PART 2 OF 4"), o nome
  do sítio, a missão com o objetivo numa linha, o Threat e o hazard pay;
- traz uma linha de rádio do Director Hale, com retrato;
- a barra é real: primeiro o carregamento em thread
  (`ResourceLoader.load_threaded_request` / `load_threaded_get_status`),
  depois a fase "BUILDING THE ISLAND", quando a ilha é instanciada.

Arranca sozinho quando acaba, sem "carrega para começar": a corrida nunca
deve ficar à espera de um ecrã. Fica pelo menos 1,2 s, para dar tempo de
ler o objetivo; com cenas em cache, de outro modo, só piscava.

É uma camada por cima do `main.gd`, não uma troca de cena. Por isso o
`RunContext` (vida, cartas, parte da expedição) passa intacto. Se uma cena
não carrega, o ecrã diz qual foi e oferece BACK TO TITLE, em vez de o jogo
rebentar. Em headless tudo é síncrono, sem esperas nem fades, e os testes
continuam rápidos.

**Diálogos** (`game/ui/dialogue_box.gd`, `typewriter.gd`, `portrait.gd`,
`dialogue_voice.gd`):

- **Retratos:** são desenhados em código, para o Director Hale, o
  Surveyor e o Contractor; quem não é conhecido aparece como silhueta com
  estática. Para pôr arte a sério basta um PNG em
  `game/ui/art/portraits/<id>.png`.
- **Texto:** aparece letra a letra, com um "blip" de voz a cada 3 letras.
  O tom muda por personagem e a boca do retrato mexe.
  - O primeiro A/Enter completa a linha. As respostas só aparecem depois
    disso, para o mesmo toque não escolher uma resposta sem querer.
  - O segundo A/Enter avança.
  - SKIP (Esc/B, ou o botão, que não recebe foco) fecha a conversa. O que
    já foi escolhido fica aplicado (o hazard pay, por exemplo).
- **Rádio do HUD:** usa o mesmo retrato, a mesma escrita e a mesma voz,
  mais depressa, e nunca bloqueia.
- **Voz:** em Settings > Audio > "Dialogue voice", gravado no perfil.
  - O blip é um AudioStreamWAV sintetizado uma vez, como o `Sfx`.
  - Não usamos AudioStreamGenerator: um som de 50 ms não precisa de um
    stream ao vivo.
- **Condições:** o briefing vê o Threat, a expedição, a parte e o
  resultado da ilha anterior (`hurt`, `fast`, `cleared`).
  - A resposta "What do we know" avisa quando o Threat é alto e comenta a
    ilha anterior.
  - A cue `radio` dá a linha do ecrã de carregamento: uma por cada parte
    da Berlenga, depois avisos de Threat. Se não houver nenhuma, mostra uma
    dica de `radio.dialogue`.
- **Tradução:** todas as linhas têm `[ID:...]` estável.
  - As linhas do rádio passaram de `story.gd` para `radio.dialogue`, para
    a geração de POT do Godot as encontrar.
  - O inglês continua a ser a fonte.
  - Os novos `.gd` usam `tr()` e estão na lista de POT.

### Decisões propostas

- O briefing específico de cada parte da Berlenga aparece no ecrã de
  carregamento e não no acampamento. O acampamento continua sem briefing,
  como foi pedido para a viagem a pé.
- Tempo mínimo do ecrã de carregamento: 1,2 s.

## Verificação e capturas

**Correção do BACK no barco/acampamento — 2026-10-11:** o atalho antes
movia só o foco para a fila anterior. Sem rotas no acampamento, Esc numa
opção de mantimentos não fazia nada. Agora abre as opções de saída descritas
acima. `test_boat_redesign.gd` passou 50 verificações; `test_expedition.gd`
passou 77, incluindo ambos os destinos, conservação do Intel e ficheiros,
ausência de bónus de extração, cancelamento e proteção contra saída dupla.
A bateria completa passou **27/27 scripts**, sem falhas de teste/script.

A janela real foi vista no Godot Forward+ a 1280×720, com KEEP PLAYING
selecionado e todos os elementos dentro do ecrã. Inverter temporariamente a
condição dos estados autorizados a sair provocou 13 falhas; a função foi
restaurada e o teste de expedição voltou a passar. Os perfis de teste ficaram
isolados do perfil real. A revisão JEV recebeu apenas um resumo sanitizado e
foi inconclusiva; a validação assenta na inspeção local e nos testes.

- tests/test_menus.gd: compras, limite de slots, foco modal, fecho/gravação,
  mantimentos, rotas, última ilha e isolamento dos atalhos na pausa.
- tests/run_all.gd: suite do projeto e dos spikes.
- tools/dev/menu_preview.gd: captura os menus reais com um perfil de demonstração
  em memória; o perfil do jogador não é gravado por esta ferramenta.

Exemplo (substituir godot pelo caminho do executável, se necessário):

```powershell
godot --headless --path . --script res://tests/test_menus.gd
godot --path . --script res://tools/dev/menu_preview.gd -- C:/Temp/armory.png armory
```

Capturas disponíveis: title, armory, routes, supplies, pause, settings,
archive, weapons e perks.
