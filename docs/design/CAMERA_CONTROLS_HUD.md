# Câmara, controlos e HUD

Proposta de design (2026-10-05). Parte da decisão fechada **câmara média**
(`docs/DECISIONS.md`) e da discussão em `BRAINSTORM.md` §6–§7. O que aqui está
é proposta: as decisões finais ficam na secção 6 e só o utilizador as fecha.

Restrições assumidas:

- **Headshots (×2) e body shots mantêm-se.** A mira tem de permitir escolher
  cabeça ou corpo de forma intencional — isto condiciona câmara, retícula e
  auto-fire.
- **Breaker** = investida/empurrão com cooldown, **comum a todas as classes**,
  que abre caminho na horda. ~~Não há sprint~~ — desatualizado: o sprint
  existe desde 2026-10-05 (Shift / L3) e dispara desde 2026-10-14 (ver
  `DECISIONS.md`). O breaker continua a ser o verbo de mobilidade especial.
- Cada classe tem **uma habilidade ativa** (granada, torreta, cura em área…).
- Lição do original: a interface compensava uma câmara que não mostrava a
  horda (radar, arcos, alertas). Aqui a câmara faz o trabalho primeiro e o HUD
  só cobre o que ela não consegue mostrar.

> Nota: o `BRAINSTORM.md` atual tem secções 0–9; não existe secção 10.
> Usei §6 (UX e HUD) e §7 (Câmara).

---

## 1. Câmara média

### 1.1 Estrutura (como se monta em Godot)

```
Player (CharacterBody3D)
└── CameraRig (Node3D)            ← segue a posição do jogador com suavização
    └── YawPivot (Node3D)         ← rotação horizontal (yaw)
        └── PitchPivot (Node3D)   ← inclinação fixa do preset (+ pequeno ajuste)
            └── SpringArm3D       ← distância e colisão
                └── Camera3D      ← FOV, offset lateral (h_offset)
```

Porquê: separar yaw, pitch e distância permite mudar de preset interpolando
três números, e o `SpringArm3D` resolve a colisão sem código próprio. O
`CameraRig` **não** é filho rígido do corpo para não herdar a rotação nem os
solavancos do knockback.

### 1.2 Presets

Pontos de partida para o spike `camera_medium` (valores do brainstorm,
completados com parâmetros que o spike tem de afinar):

| Parâmetro | Ombro afastado | **Média** (alvo) | Alta leve |
|---|---|---|---|
| Inclinação (pitch) | 25° | **35°** | 45° |
| Distância ao pivô | 7 m | **10 m** | 13 m |
| Altura do pivô (acima dos pés) | 1,6 m | **1,4 m** | 1,2 m |
| Offset lateral | 0,8 m | **0,4 m** | 0 m |
| FOV vertical | 65° | **60°** | 55° |
| Terreno visível à frente (estimado) | ~25 m | **~22 m** | ~18 m |
| Terreno visível atrás (estimado) | ~2 m | **~4 m** | ~7 m |
| Suavização de seguimento | 12 /s | **10 /s** | 8 /s |
| Look-ahead na direção da mira | 0,5 m | **1,5 m** | 2,5 m |
| Ajuste de pitch pelo jogador | ±8° | **±5°** | ±3° |

"Visível atrás" é o número que mais importa para uma horda de 360°: é quanto
da horda nas costas o jogador vê sem rodar. As estimativas acima são
geométricas e têm de ser **medidas na cena** (projetar os cantos do ecrã ao
plano do chão e imprimir os metros), não assumidas.

**Look-ahead:** o pivô desloca-se ligeiramente para onde o jogador aponta.
Dá mais ecrã útil à frente sem afastar a câmara. Limitado e suavizado para não
enjoar.

### 1.3 Yaw livre vs fixo

| | Yaw livre (rato/stick direito rodam a câmara) | Yaw fixo (norte sempre para cima) |
|---|---|---|
| Mira | retícula ao centro-ligeiramente-acima; rodar = apontar | cursor livre no ecrã (twin-stick) |
| Headshots | naturais: a retícula passa pela cabeça | difíceis a 35°: cabeças sobrepõem-se a corpos vistos de cima |
| Ver atrás | roda-se a câmara | nunca se vê atrás de obstáculos altos |
| Comando | stick direito roda e aponta (familiar) | stick direito aponta direção, sem rodar |
| Oclusão | resolve-se rodando | precisa de recorte/fade sempre |
| Enjoo/orientação | mais risco | nenhum |
| Mapas/indicadores | relativos à câmara | absolutos, mais simples |

**Recomendação: yaw livre**, com pitch do preset fixo (só um ajuste pequeno).
Com a câmara média a 35°, só o yaw livre mantém os headshots com sentido;
yaw fixo empurra o jogo para a direção A (twin-stick) e trata cabeça e corpo
quase como o mesmo alvo. Manter **yaw fixo como variante de teste** no spike,
porque é barato (desligar uma rotação) e responde à pergunta de forma medida.

Regras do yaw livre:

- O rato roda a câmara **sempre** (sem ter de premir botão).
- O corpo do personagem roda para a direção da mira; o movimento é relativo à
  câmara (W = para onde a câmara olha). Strafe e andar para trás a disparar são
  normais — é um jogo de horda.
- Sensibilidade separada para rato e comando; inverter Y apenas no ajuste
  de pitch.
- **Sem auto-rotação** da câmara pelo auto-aim ou pelo movimento (lição do
  original: o corpo seguia o alvo e a câmara não; manter isso).

### 1.4 Mira com a câmara média

Retícula no ecrã, ligeiramente acima do centro (~45% da altura, para deixar
mais chão visível à frente). Cada frame:

1. Raycast da câmara pela retícula → ponto de impacto P no mundo (inimigos,
   cenário, chão).
2. O disparo sai da arma do personagem em direção a P (não da câmara). Se a
   linha arma→P for bloqueada antes de P, a retícula mostra um indicador de
   "bloqueado" (ponto vazio) — evita a frustração de acertar na parede ao lado.
3. Hit em inimigo distingue **colisor da cabeça** e **do corpo**; o hit-marker
   muda (ver 3.4).
4. Se o raio da câmara não acerta em nada (céu), apontar a uma distância
   máxima ao longo do raio.

Altura: a câmara a 35° vê os inimigos de cima, por isso as cabeças projetam-se
**acima** dos corpos no ecrã com separação suficiente — é isto que o spike
deve confirmar medindo, a 10 e 20 m, quantos píxeis separam cabeça e tronco a
1152×648 (alvo: cabeça ≥ 10 px de altura a 15 m).

Mira fina (botão direito / LT): **aproxima** a câmara do preset atual
(distância −30%, FOV −10°, offset lateral +0,3 m) em 0,15 s, reduz a
sensibilidade e o spread. Não é ADS em 1ª pessoa: o jogador continua a ver à
volta. Serve para headshots a distância.

### 1.5 Colisão e oclusão

Dois problemas diferentes:

1. **A câmara entra em geometria** (falésia atrás do jogador) → `SpringArm3D`
   com forma esférica (raio 0,3 m), máscara só de cenário estático (nunca
   inimigos, que fariam a câmara saltar). Recolher rápido (≤ 0,05 s), voltar
   devagar (~0,4 s) para não "bombear".
2. **Algo tapa o jogador** (árvore, telhado) sem colidir com a câmara →
   - Raycasts/shape-cast câmara→jogador (cabeça e pés); objetos marcados como
     `occluder` no caminho passam a **fade/dither** (alpha ~0,3), em vez de
     desaparecer.
   - Telhados de interiores: ocultar o "andar de cima" ao entrar num volume.
   - **Silhueta** do jogador (e de especiais próximos) através de paredes,
     com um material de passagem extra `depth_test` invertido. Barato e resolve
     o caso que o fade não apanha.
   - Folhagem baixa nunca é occluder (custo de testes por instância).

A câmara mais afastada do que o original torna a oclusão mais frequente; o
spike tem de medir com que frequência o jogador fica tapado num percurso
típico.

### 1.6 Zoom dinâmico em picos de horda

Quando o diretor de horda entra em **pico**, ou há muitos inimigos perto, a
câmara afasta-se um pouco para mostrar a ameaça.

- Entrada: valor de pressão 0–1 (do diretor ou contagem de inimigos num raio
  de 12 m, o que o spike achar mais estável).
- Efeito: distância até **+20%** e FOV até **+5°** sobre o preset; nunca
  muda a inclinação (mudaria a mira).
- Suave: subir em ~1,5 s, descer em ~3 s, com histerese (só volta abaixo de
  0,4 depois de ter passado 0,7) para não oscilar.
- **Suspenso** durante mira fina.
- Opção de acessibilidade: desligar.

### 1.7 Câmara em eventos

Princípio: **nunca tirar o controlo da mira em combate.** Eventos ajustam o
enquadramento, não fazem cutscenes durante a luta.

| Evento | Comportamento |
|---|---|
| **Desembarque** (chegada à ilha) | 2–3 s de plano do barco/praia e da direção do objetivo **antes** de haver inimigos ativos; depois interpola para o preset. Saltável com qualquer input. |
| **Entrada de boss** | Plano curto (≤ 2 s) do boss com nome, com o mundo em câmara lenta ou pausado; regressa ao preset. Mostra-se uma vez por run. |
| **Combate com boss** | Preset + afastamento fixo (+15%) enquanto a arena estiver ativa; indicador de borda do boss sempre visível se fora de vista. Opcional: "soft-lock" que mantém o boss no enquadramento ao alternar uma tecla (a testar). |
| **Defend the Boat / Hold Zone** | Afastamento ligeiro (+10%) enquanto dentro da zona. |
| **Embarque/extração** | Plano de saída depois de o jogador perder o controlo (o combate acabou). |
| **Grabber prende o jogador** | Pequeno zoom-in (−10%) e shake leve para comunicar "estás preso → breaker". |

---

## 2. Controlos

Princípios: o breaker e a habilidade são os dois botões de decisão, por isso
ficam nos dedos mais rápidos; nada é crítico atrás de um modificador. Todos
os bindings são remapeáveis (Input Map do Godot + ecrã de remapeamento).

### 2.1 Tabela de bindings

| Ação | Teclado/rato | Comando (Xbox / PlayStation) | Notas |
|---|---|---|---|
| Mover | WASD | Stick esquerdo | relativo à câmara |
| Rodar câmara / apontar | Rato | Stick direito | yaw livre; pitch ±5° |
| Disparar | Botão esquerdo | RT / R2 | manter = automático da arma |
| Mira fina | Botão direito (manter; opção alternar) | LT / L2 | ver 1.4 |
| **Breaker** | Espaço | A / ✕ | investida na direção do movimento (ou da mira, se parado) |
| Habilidade de classe | Q | LB / L1 | mantém = pré-visualizar alvo (granada, torreta), larga = usar |
| Recarregar | R | X / □ | |
| Interagir | E (manter para ações longas) | Y / △ (manter) | terminais, caches, barco |
| Trocar arma (alternar) | Roda do rato / Tab | RB / R1 | alterna slots 1↔2 |
| Arma 1 / Arma 2 | 1 / 2 | — | |
| Ping / marcar | Botão do meio | D-pad cima | marca inimigo/objetivo; útil se houver co-op |
| Mapa da ilha | M | Botão View / Touchpad | não pausa (como o original) |
| Pausa | Esc | Menu / Options | |
| Recentrar câmara atrás do jogador | C | Clique stick direito (R3) | |
| Sprint (dispara desde 2026-10-14) | Shift | Clique stick esquerdo (L3) | |
| (livre) | Ctrl, F | D-pad | reservado: sem agachar, sem salto por agora |

Porquê Espaço para o breaker: é o maior botão e o mais rápido de premir
sem tirar os dedos de WASD; num jogo sem salto, é natural. No comando, A/✕ é
o botão do polegar direito mais acessível sem largar o stick… durante um
instante — por isso a mira tem tolerância durante a investida (ver abaixo).

Porquê Tab para trocar arma (e não para o mapa como no original): trocar é
frequente em combate; o mapa não. Propor para playtest.

### 2.2 Breaker — regras de input

- Direção: input de movimento atual; sem movimento, direção da mira.
- Buffer de 0,15 s: premir pouco antes do fim do cooldown ainda conta.
- Durante a investida (~0,3 s) pode-se continuar a apontar e, se a classe/carta
  o permitir, disparar.
- Cooldown visível junto à retícula (anel) e no HUD.
- Solta o jogador de um Grabber (contra claro do brainstorm).

### 2.3 Assistências de mira

| Assistência | Rato | Comando |
|---|---|---|
| Aim slowdown (sensibilidade baixa sobre inimigos) | não | sim, por omissão |
| Magnetismo leve (puxa para o **corpo**) | não | opção |
| Auto-fire | opção (ver §4) | opção |

A magnetismo puxa para o centro do corpo, **nunca para a cabeça**: o
headshot continua a ser habilidade do jogador.

---

## 3. HUD

### 3.1 Mundo primeiro, HUD depois

| No mundo (diegético / sobre o mundo) | No HUD (ecrã) |
|---|---|
| Especiais com silhueta/cor distinta e som próprio | Vida, escudo |
| Telegraph de ataques (círculos no chão do Bloater, ácido do Spitter) | Arma ativa, carregador/reserva, slot 2 |
| Barras de vida só de **especiais e boss** sobre o modelo | Cooldown de breaker e habilidade |
| Objetivo: luz/fumo/feixe visível à distância | Objetivo atual (1 linha) e progresso |
| Pickups com brilho por tipo | Indicadores de borda (fora de vista) |
| Zona de Hold Zone marcada no chão | Barra do boss (topo) |
| Números de dano (opção, pequenos) | XP de run, Scrap, relógio da expedição |

**Sem radar circular por omissão.** A câmara média + indicadores de borda +
som devem chegar. O radar fica como opção de acessibilidade/teste se o
playtest mostrar mortes "sem perceber de onde veio".

### 3.2 Layout por zonas

```
┌──────────────────────────────────────────────────────────────────────┐
│ [A] Objetivo            [B]  ═══ THE BREAKER ════════════   [C] 12:40│
│ Mourning Isle                                                Scrap 85│
│ Ring the bells  2/3                                           Lv 7 ▮▮▯│
│                                                                      │
│◄!                                                                  ▲ │← [E] borda
│ (Screamer)                     ·                                     │
│                              ╭ + ╮  ← retícula + anel do breaker     │
│                              ╰───╯                                   │
│                                ☺  ← jogador                          │
│                                                                      │
│ [F] feed (máx 3)                                                     │
│ +25 XP  Cache opened                                                 │
│                                                                      │
│ [D] ♥ ██████████░░ 82    [Q] ◔ GRENADE  [␣] ● BREAKER    AR  24/120 │
│                                                          SMG  ·/180 │
└──────────────────────────────────────────────────────────────────────┘
```

| Zona | Conteúdo | Prioridade |
|---|---|---|
| A — canto sup. esq. | ilha, objetivo (1 linha), progresso | média |
| B — topo centro | barra do boss / evento (só quando existe) | alta em evento |
| C — canto sup. dir. | relógio, Scrap, nível/XP de run | baixa |
| D — inferior | vida (esq.), habilidade + breaker (centro-esq.), armas e munição (dir.) | **alta** |
| E — bordas | indicadores de ameaças e objetivo fora de vista | alta |
| F — esq., meio-baixo | feed de mensagens, máx. 3, agregadas ("+75 Scrap" em vez de 3×25) | baixa; críticas têm faixa própria |
| Centro | retícula, anel do breaker, hit-marker. **Nada de texto** (regra H3 do original) | — |

Avisos críticos (LOW RESERVE, EMPTY, "Grabbed!") aparecem junto à zona D,
nunca no feed — não podem ser empurrados por mensagens de loot (lição do
original).

### 3.3 Indicadores de borda

- Aparecem para: **especiais** fora do ecrã a menos de ~25 m, **boss**,
  **objetivo** (dourado), **ataque recebido** (arco vermelho a apontar a
  origem, 1 s).
- Seta na borda do ecrã na direção projetada, com ícone por tipo
  (forma + cor, nunca só cor). Tamanho/opacidade crescem com a proximidade.
- Normais fora de vista: **não** têm indicador individual; uma vinheta suave
  na borda de onde vem a massa (densidade) — evita 40 setas.
- Limite: 6 indicadores simultâneos, prioridade boss > especial perto >
  objetivo > especial longe.
- Referência única de orientação: **a câmara** (o original misturava câmara e
  corpo e obrigava a conversão mental).

### 3.4 Retícula e feedback de tiro

- Retícula pequena, branca com contorno escuro; abre com o spread.
- Hit-marker: corpo = marcador branco; **cabeça = marcador maior, amarelo,
  com som distinto**; kill = cruz breve. Forma diferente para não depender
  da cor.
- Ponto vazio quando a linha arma→alvo está bloqueada.

### 3.5 Legibilidade a 1152×648 e 1920×1080

- Desenhar o HUD para **1152×648** (resolução base do projeto) com
  `stretch mode = canvas_items`, `aspect = expand`; a 1920×1080 escala 1,67×.
- Âncoras por zona (Containers com margens de 3% do lado menor), nada em
  coordenadas absolutas; margem segura de 5% para TVs.
- Texto mínimo a 1152×648: **16 px** corpo, **20 px** números críticos
  (vida, munição), **14 px** só para informação secundária. Contorno de 2 px
  ou fundo semitransparente em todo o texto sobre o mundo.
- Ultrawide: a zona D não estica; fica ancorada às bordas 16:9 centrais.
- Teste automático (headless) possível: instanciar o HUD nas duas resoluções e
  verificar que os `Rect2` das zonas não se sobrepõem nem saem do ecrã. A
  leitura visual valida-se no editor em Windows.

---

## 4. Acessibilidade

### 4.1 Auto-fire: modo por omissão vs opção

Como funcionaria: com auto-fire ligado, a arma dispara sozinha quando a
retícula está sobre um inimigo (ou, numa versão mais forte, contra o inimigo
mais próximo com linha de tiro, como no original: 8–13 m).

| | Auto-fire **por omissão** | Auto-fire **como opção** (desligado por omissão) |
|---|---|---|
| Identidade | puxa para survivors (direção A) | mantém o shooter com mira (A+B) |
| Headshots | perdem valor (a arma escolhe o alvo, normalmente o corpo) | continuam a ser a habilidade central |
| Munição limitada | dispara em alvos irrelevantes → frustração (diagnóstico do original) | o jogador decide onde gasta |
| Acessibilidade | ótima | ótima para quem a ativa |
| Balanceamento | todo o jogo calibrado para dano automático | calibrar para mira manual; a opção aceita perder eficiência |
| Comando | resolve a dificuldade de mirar com stick | aim slowdown + magnetismo cobrem a maior parte |

**Recomendação: opção, desligada por omissão**, em dois níveis:

1. **"Auto-fire na retícula"** — dispara quando a retícula está sobre um
   inimigo. A mira continua do jogador, por isso um headshot continua a ser
   possível e recompensado. Este é o nível que se recomenda divulgar.
2. **"Auto-fire assistido"** — escolhe o alvo mais próximo com linha de tiro
   e aponta ao corpo. Para quem não consegue mirar; aceita-se que dê menos
   dano (sem headshots).

Em ambos: a arma base (munição infinita) dispara automaticamente; **armas
especiais com munição limitada nunca disparam sozinhas** — resolve o conflito
auto-fire × escassez do original. O disparo manual tem sempre prioridade.

Se o utilizador quiser auto-fire por omissão, a consequência é clara: o jogo
vai para a direção A e os headshots deixam de ser pilar; seria melhor decidir
isso explicitamente em DECISIONS (pergunta 2 em aberto).

### 4.2 Outras opções

| Opção | Proposta |
|---|---|
| Tamanho de texto/HUD | escala do HUD 80–150% (passos de 10%), separada da escala de texto dos menus |
| Daltonismo | cada estado tem **forma + cor** (especiais, hit-marker de cabeça, indicadores); paletas Deuteranopia/Protanopia/Tritanopia trocam só as cores dos tokens; testar com filtro de simulação |
| Shake reduzido | slider 0–100% para shake de câmara; 0% também desliga o micro-zoom do Grabber; hit-stop separado (on/off) |
| Flashes | reduzir flashes de explosão e vinheta de dano |
| Zoom dinâmico | on/off (§1.6) |
| Mira fina | manter ou alternar |
| Sensibilidade | rato e comando separados; curva de resposta do stick; inverter eixo Y |
| Radar | opção desligada por omissão (§3.1) |
| Legendas | para falas e sons críticos ("Screamer — left") |
| Remapeamento | completo, teclado e comando |

---

## 5. Critérios de playtest para escolher o preset

Mesma ilha, loadout e seed (quando houver); cada jogador joga os três presets
por ordem aleatória, 5 minutos cada, com o mesmo pico de horda. Registar
telemetria (JSON) + 3 perguntas no fim de cada preset.

| # | Critério | Como medir | Alvo para "Média" ganhar |
|---|---|---|---|
| 1 | Leitura da horda atrás | % de danos recebidos de inimigos fora do ecrã nos 2 s anteriores | ≤ 25% |
| 2 | Headshots viáveis | % de headshots em disparos manuais; px da cabeça a 15 m | ≥ 15%; cabeça ≥ 10 px a 1152×648 |
| 3 | Mortes "injustas" | pergunta: "percebeste o que te matou?" | ≥ 80% sim |
| 4 | Oclusão | % do tempo com o jogador tapado (raycast) | ≤ 5% |
| 5 | Spawn fora de vista | % de spawns visíveis ao aparecer | 0% (corrigir o spawn mínimo pelo frustum, não por metros) |
| 6 | Imersão/escala | 1–5: "sentiste a parede de zombies?" | ≥ 4 |
| 7 | Conforto | 1–5 enjoo/cansaço; sensibilidade ajustada? | ≤ 1 queixa |
| 8 | Breaker legível | % de breakers que acertam ≥ 3 inimigos | comparar presets |
| 9 | Preferência | "qual escolhias?" | maioria |
| 10 | Desempenho | p95 de frame time com o preset (mais terreno visível = mais desenho) | dentro do orçamento definido |

Regra de decisão proposta: o preset vencedor é o que cumpre 1–5; entre os que
cumprem, decide a preferência (9). Se nenhum cumprir 1, testar um meio-termo
(p. ex. 40°, 11 m) antes de acrescentar radar.

---

## 6. Decisões propostas e perguntas

### 6.1 Decisões propostas

1. **Yaw livre** com pitch fixo por preset (±5°); yaw fixo só como variante de
   teste no spike.
2. **Preset "Média" (35°, 10 m, 0,4 m, 60°)** como ponto de partida; escolha
   final pelos critérios do §5.
3. **Mira fina** no botão direito/LT como aproximação da câmara, não ADS.
4. **Breaker no Espaço / A**; sprint em Shift / L3 (dispara, desde 2026-10-14); sem salto, sem agachar.
5. **Tab para trocar arma**, M para mapa.
6. **Sem radar por omissão**: câmara + indicadores de borda + som; radar como
   opção.
7. **Auto-fire como opção desligada por omissão**, em dois níveis; armas de
   munição limitada nunca disparam sozinhas.
8. **Magnetismo do comando aponta ao corpo**, nunca à cabeça.
9. HUD desenhado para **1152×648** com texto mínimo de 16 px e forma + cor em
   todos os estados.
10. Eventos de câmara **nunca tiram a mira em combate**; planos só antes ou
    depois do combate (desembarque, entrada do boss, extração).

### 6.2 Perguntas para o utilizador

1. Auto-fire: concordas com "opção, desligada por omissão"? Ou queres que
   seja por omissão (o que puxa o jogo para a direção A)?
2. Yaw livre com o rato a rodar sempre a câmara está bem, ou preferes rodar
   só com botão premido?
3. O breaker deve ir na direção do **movimento** ou da **mira**?
4. Radar: queres eliminá-lo por omissão, como proposto?
5. Plano curto de entrada do boss (≤ 2 s, uma vez por run): sim ou não?
6. Jogas mais com teclado/rato ou comando? Define que esquema afinar primeiro.
7. Números de dano: ligados por omissão ou opção?
8. Co-op está no horizonte? Muda ping, câmara partilhada e HUD.
