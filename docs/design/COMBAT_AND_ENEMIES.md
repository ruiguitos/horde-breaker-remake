# Combate e inimigos

Proposta de design (2026-10-05). Parte de `DECISIONS.md` (câmara média) e das
respostas do utilizador em `BRAINSTORM.md` §10 (auto-fire normal, headshots
mantêm-se, breaker comum sem sprint, 80–150 inimigos, Grabber no slice, humor
DRG). **Nada aqui é decisão**: ver "Decisões propostas" no fim.

Todos os números são **hipóteses de playtest**: servem para ter um ponto de
partida mensurável, não para serem defendidos. Unidades: m, m/s, s, HP.

Pilar servido por cada secção: **P1 Romper a horda**, **P2 Cada ilha é uma
decisão**, **P3 Builds que mudam a forma de jogar**.

---

## 1. Modelo de disparo: auto-fire com câmara média (P1)

### 1.1 Ideia central

A arma escolhe **quando** dispara; o jogador escolhe **para onde** a arma olha
e **onde** está. Com auto-fire, a habilidade deixa de estar no clique e passa
para três coisas: posicionamento, foco e gestão das armas especiais.

O problema do original (BRAINSTORM §0.2) era auto-fire + munição escassa +
headshots que não importavam. A resposta aqui:

- A arma base tem **munição infinita** (só recarrega) → o auto-fire nunca
  desperdiça algo escasso.
- As armas especiais (munição limitada) são **disparadas pelo jogador**.
- O headshot é uma **consequência do posicionamento e do foco**, não da
  pontaria fina (ver 1.4).

### 1.2 O que o jogador controla

| Controlo | Teclado/rato | Comando | Função |
|---|---|---|---|
| Movimento | WASD | stick esquerdo | posição, kiting, alinhar headshots |
| Foco (direção) | posição do rato no chão | stick direito | cone de prioridade da arma base |
| Breaker | Espaço | A / Cruz | investida (secção 2) |
| Arma especial | botão esquerdo | RT | dispara a especial para o foco |
| Habilidade de classe | Q | LB | granada/torreta/cura (fora deste doc) |
| Trocar especial | roda / 1–2 | RB | se houver duas especiais |
| Interagir | F | X | objetivos, pickups |

Sem sprint, sem salto, sem agachar (cortes intencionais: menos animação,
menos estados, o breaker é o único verbo de mobilidade).

### 1.3 Seleção de alvo

Cada arma base tem um **alcance** e um **cone de foco** (por defeito 70°,
centrado na direção do rato/stick). A cada 0,1 s (não a cada frame, por
custo: consulta ao spatial hash) escolhe-se o alvo com **maior pontuação**
entre os inimigos dentro do alcance e com linha de tiro:

```
score = prioridade_tipo
      + 2,0 × (dentro do cone de foco ? 1 : 0)
      + 1,5 × (1 - distância / alcance)
      + 1,0 × (é o alvo atual ? 1 : 0)        # histerese: evita saltar de alvo
      + 3,0 × (está a agarrar/atacar o jogador ? 1 : 0)
```

`prioridade_tipo` (hipótese): Screamer 3, Grabber a agarrar 3, Spitter 2,
Bloater 1 (só se > 4 m; perto, **não** é alvo automático para não rebentar
na cara do jogador), restantes 0.

Regras:

- **Fora do cone, a arma só dispara se não houver nada dentro do cone.**
  Assim o foco tem significado sem obrigar a mirar.
- O corpo roda para o alvo (como no original); a câmara **não** roda.
- **Marcar alvo (override suave):** clicar com o botão do meio / L3 num
  inimigo força-o como alvo durante 3 s se estiver no alcance. Útil para
  especiais escondidos na multidão.
- **Override manual completo:** não existe no modo normal (ver decisão D2).
  Proposta: opção "disparo manual" nas definições, para testar em playtest se
  alguém o prefere; não se equilibra o jogo para ela.

### 1.4 Headshots e body shots com auto-fire

A arma aponta sempre ao **centro de massa** do alvo. Cada tiro tem uma
probabilidade de acertar na cabeça que o jogador **influencia**:

```
p_cabeça = base_arma
         × (alvo dentro do cone de foco ? 1,0 : 0,4)
         × (jogador parado ou a andar devagar ? 1,0 : 0,6)
         × (alvo de frente para o jogador ? 1,0 : 0,7)
         + bónus de cartas/perks
```

- Body shot = 1×; headshot = 2× e **efeito extra** (stagger garantido,
  hipótese de desmembramento da cabeça, som próprio). O efeito é o que se
  sente; o 2× é o que se mede.
- Isto cria uma escolha contínua: **parar e focar** (mais headshots, mais
  risco) vs **mexer-se** (seguro, menos dano). É a tensão do pilar P1.
- Atirar de verdade ao osso da cabeça (raycast à esfera da cabeça desviado
  aleatoriamente pelo spread) em vez de rolar um dado: o resultado é o mesmo
  em média mas o desmembramento bate certo com a física. Recomendo o raycast
  com spread, porque o spread já existe e não há duas regras.
- **Pontos fracos dos especiais** somam-se (Bloater: saco; Armored: costas;
  Brute: cabeça exposta após stagger) — o foco e o posicionamento é que os
  expõem.
- Armas especiais disparadas à mão vão **onde o jogador aponta** (raycast do
  rato ao plano do inimigo); aí a pontaria manual conta de verdade.

### 1.5 Perguntas para o spike `camera_medium`

- O cone de 70° é legível? Precisa de ser desenhado no chão (decal subtil)?
- O rato no chão com a câmara a 35° tem paralaxe incómoda em inimigos altos?
- 0,1 s de reavaliação de alvo parece "lento"?

---

## 2. O verbo breaker (P1)

### 2.1 Base comum

Investida curta em linha reta na direção do movimento (ou do foco, se parado).

| Parâmetro | Hipótese |
|---|---|
| Distância | 6 m em 0,3 s (20 m/s) |
| Cargas | 2 |
| Recarga | 6 s por carga |
| Invulnerável | sim, durante a investida (i-frames) |
| Contra inimigos leves | empurra para os lados 2–3 m e derruba 1 s; 20 dano |
| Contra pesados (Brute, Armored) | **para** o jogador e ele fica atordoado 0,4 s |
| Agarrado (Grabber) | breaker solta sempre, gasta 1 carga |

Porque cargas e não só cooldown: duas cargas permitem "entrar e sair",
que é o risco/recompensa interessante; uma carga só é usada para fugir.

### 2.2 Risco / recompensa

- **Recompensa:** abrir caminho, derrubar (inimigos derrubados levam
  headshot garantido durante 1 s → combina com 1.4), soltar-se do Grabber,
  chegar a objetivos.
- **Risco:** acabar no meio da horda sem carga; bater num pesado e ficar
  atordoado; investir para um Bloater perto (rebenta-o, ácido em área).
- Regra de design: o breaker **nunca** deve ser a melhor forma de matar.
  Serve para posicionar. Se em playtest o jogador o usar só para dano,
  baixar o dano.

### 2.3 Variantes (escolhidas por perk em slot, uma de cada vez)

| Variante | Mudança | Custo |
|---|---|---|
| **Shoulder Charge** (padrão) | descrito acima | — |
| **Ram** | 4 m, mais lenta (0,4 s), atravessa pesados e derruba-os; 1 carga, 8 s | perde mobilidade de fuga |
| **Shockwave Stop** | no fim da investida, onda radial 3 m que empurra tudo 4 m; 0 dano | não derruba no caminho |
| **Blink Slide** (opcional, mais tarde) | 8 m, atravessa inimigos sem os tocar, 3 cargas, 5 s | não abre caminho para aliados/objetivo |

Para o slice, só a Shoulder Charge. As outras testam P3 depois.

### 2.4 Bull Rush do Renegade — proposta

O Bull Rush deixa de ser um movimento exclusivo (agora todos investem). Passa
a ser uma **modificação do breaker** própria da classe, ou a sua habilidade
ativa:

- **Opção A (recomendada): passivo de classe "Bull"** — o breaker do
  Renegade **não para em pesados** (derruba-os como a Ram) e dispara a
  shotgun automaticamente no fim da investida (cone 90°, 1 rajada grátis).
  Identidade clara ("entra e rebenta"), zero botões novos.
- Opção B: habilidade ativa "Bull Rush" — investida longa (12 m) que arrasta
  inimigos à frente, 20 s de cooldown. Mais espetacular, mas é um segundo
  breaker e confunde o papel do verbo comum.

---

## 3. Arsenal inicial (P3)

Duas categorias: **base** (munição infinita, auto-fire, uma por classe) e
**especial** (munição limitada, disparo manual, encontrada/escolhida na run).
Todos os disparos instantâneos são hitscan contra o spatial hash.

| # | Arma | Tipo | Comportamento | Alcance | Munição | Papel | Sinergias |
|---|---|---|---|---|---|---|---|
| 1 | **Assault Rifle** | base (Recruit) | tiro a tiro rápido, spread baixo, 3.ª bala seguida no mesmo alvo +50% p_cabeça | 14 m | ∞, carregador 30, recarga 1,6 s | todo-o-terreno, premeia ficar focado | cartas de headshot, Marcar alvo |
| 2 | **Shotgun** | base (Renegade) | 8 pellets, cone 25°, **empurra** inimigos 1 m; dano cai a partir de 5 m | 8 m | ∞, 6, recarga por cartucho | linha da frente, abre espaço | breaker (derrubados), Bull |
| 3 | **SMG** | base (Medic/alternativa) | muito rápida, pouco dano, **troca de alvo instantânea** (sem histerese) | 11 m | ∞, 40, 1,4 s | limpar leves, ignora o foco | cartas "on hit" (cura, fogo) |
| 4 | **Pistol** | base de recurso | lenta, precisa, headshot base alto, **penetra 1** | 12 m | ∞, 12, 1,0 s | segura quando nada mais tem munição | cartas de penetração |
| 5 | **Grenade Launcher** | especial | projétil em arco, explode raio 3 m, empurra | 4–18 m (manual) | 8 granadas | limpar grupos, matar Armored | Bloater (cadeia), fogo |
| 6 | **Flamethrower** | especial | cone contínuo 6 m, **incendeia** (DoT 3 s) e cria chão em chamas | 6 m | 100 de combustível (≈10 s) | segurar corredores, zonas de missão | breaker "deixa fogo", Hold Zone |
| 7 | **Ricochet Rifle** | especial | cada bala salta para 2 inimigos a < 4 m (dano −30% por salto) | 16 m | 40 balas | multidões densas | spatial hash denso = mais valor |
| 8 | **Railgun** | especial | carrega 0,6 s, **penetra tudo** numa linha, headshot garantido no 1.º | 25 m | 6 tiros | matar Brutes/especiais longe, linhas de horda | breaker para alinhar a fila |

Notas:

- O slice precisa de **3 armas**: Assault Rifle, Pistol, Grenade Launcher
  (base, recurso e uma especial).
- Munição das especiais: caixas no mapa e "escolhe 1 de 3" no barco. Sem
  reserva para as base (o "carregador de reserva" do original morre).
- Comportamento primeiro, stats depois: se duas armas só se distinguem por
  números, uma sai.

---

## 4. Bestiário (P1, P2)

Silhuetas pensadas para a câmara média (~35°, ~10 m): de cima lê-se sobretudo
**largura, altura, cor e postura**, não detalhe da cara. Tudo com primitivas
(cápsulas, caixas, esferas). Cor = função: cinza comum, verde ácido,
vermelho perigo, amarelo especial a matar primeiro.

| # | Inimigo | Papel | Silhueta (primitivas) | Comportamento | Contra do jogador | HP | Vel. m/s | Dano |
|---|---|---|---|---|---|---|---|---|
| 1 | **Shambler** | massa, terreno móvel | cápsula cinza 1,8 m, braços à frente | anda direto (flow field), ataque corpo-a-corpo 1 s | qualquer arma; headshots | 60 | 2,2 | 8 / golpe |
| 2 | **Runner** | pressão, pune parar | cápsula fina, inclinada à frente, mais baixa | corre em zigue-zague, ataques rápidos | Shotgun, breaker de lado | 35 | 5,0 | 5 / golpe (0,5 s) |
| 3 | **Brute** | parede, quebra o breaker | caixa larga 2,4 m, ombros enormes | anda devagar, carga em linha a cada 6 s (aviso 0,8 s) | desviar a carga; stagger expõe cabeça | 450 | 1,8 (carga 9) | 25 + knockback |
| 4 | **Grabber** (slice) | punição de isolamento | cápsula alta e magra, braços longos (cilindros) roxos | aproxima-se pelos flancos, agarra a 2 m: imobiliza e puxa 1 m/s para a horda | **breaker solta**; matar antes de chegar (prioridade auto-fire 3 ao agarrar) | 120 | 3,5 | 4/s enquanto agarra |
| 5 | **Spitter** | zona à distância | cápsula com esfera verde no peito | mantém 8–12 m, cospe ácido em arco que deixa poça 3 s | fechar distância com breaker; foco | 70 | 2,8 | 12 impacto + 6/s na poça |
| 6 | **Bloater** | perigo de área / ferramenta | esfera grande verde sobre cápsula curta | lento; explode ao morrer: raio 3,5 m, empurra e dá dano **a todos** | matar longe ou **usar** perto da horda | 90 | 1,6 | 30 explosão (inimigos também) |
| 7 | **Screamer** | amplificador (chama horda) | cápsula amarela com cone (boca) para cima | foge do jogador; ao fim de 3 s com linha de visão grita → diretor faz pico | matar primeiro (prioridade auto-fire 3) | 50 | 3,0 | 0 |
| 8 | **Armored** | exige posicionamento | cápsula com caixa-escudo frontal cinza-escura | frente imune a balas (−90%); roda devagar para o jogador | atirar por trás/lado, explosivos, Railgun | 200 | 2,0 | 15 |
| 9 | **Crawler** | ameaça baixa, esconde-se | cápsula deitada, rente ao chão | rasteja por baixo da multidão, morde pernas (lento 30% 2 s) | Shotgun, chamas; difícil de ver → linha de luz no chão | 30 | 3,0 | 6 + lentidão |
| 10 | **The Breaker** (boss) | clímax de ilha | Brute ×1,5 com espinhos (cones) vermelhos | fases: cargas, pisões em área, invoca Shamblers | combina tudo; pontos fracos nas costas | 3000 | 2,0 | 35 / 20 área |

Vertical slice: **Shambler, Runner, Brute, Grabber** (+ o boss só se sobrar
tempo). O Grabber é o teste do breaker: se soltar não for satisfatório, o
breaker está mal.

Leitura de especiais fora de vista: indicador na borda do ecrã só para
Screamer, Grabber, Brute em carga e boss (máx. 4 setas), mais um som
característico por especial.

---

## 5. Diretor de horda (P1, P2)

### 5.1 Métrica de intensidade

Um valor `I` de 0 a 100 por jogador, inspirado em L4D:

```
I += dano_recebido × 2
I += 1 por inimigo morto a < 4 m
I += 15 ao ser agarrado; +10 com < 30% de vida
I -= 4 por segundo sem dano e sem inimigos a < 6 m (decai)
I = clamp(I, 0, 100)
```

### 5.2 Fases

| Fase | Entrada | Comportamento | Duração típica |
|---|---|---|---|
| **Crescer** | após alívio | spawns sobem até o orçamento-alvo; especiais 1 a cada 20 s | 60–90 s |
| **Pico** | `I ≥ 70` ou Screamer/evento de missão | spawns mantêm-se no máximo; sem especiais novos se `I ≥ 90` | 15–30 s, máx. 40 s |
| **Alívio** | fim do pico | **sem spawns novos**; restantes continuam; deixa recolher, curar, explorar | 20–35 s, até `I < 25` |

A dificuldade (Hazard) muda os tempos, o orçamento e a cadência de
especiais, não a curva.

Eventos de missão (Hold Zone, Defend the Boat) **forçam** pico: o diretor
deixa de decidir e o template de missão manda.

### 5.3 Orçamento

- **Ativos:** alvo 80 (Hazard 1) → 150 (Hazard 5); barreira absoluta = alvo
  + 20. Número final pelo spike S2 (medir FPS na RX 590).
- **Custo por tipo** em "pontos" (Shambler 1, Runner 1, Crawler 1, Spitter 3,
  Bloater 3, Grabber 4, Armored 5, Screamer 5, Brute 8): o diretor gasta
  pontos, não cabeças. Máximo simultâneo de especiais: 4–8.
- Spawns em fila: máx. 4 por frame de física (pooling obrigatório).
- Inimigos a > 40 m do jogador e fora de vista há > 10 s são **reciclados**
  (devolvidos ao pool e o orçamento reembolsado).

### 5.4 Spawn fora do campo de visão da câmara média

Com câmara a ~35°/~10 m, o terreno visível ronda um trapézio de ~20 m à
frente e ~8 m atrás (o spike medirá). Regras:

1. Candidatos = pontos de spawn autorados + pontos amostrados no navmesh/flow
   field a 18–35 m do jogador.
2. Rejeitar o ponto se **projetado no ecrã** (`Camera3D.is_position_in_frustum`
   com margem de 2 m) — teste ao frustum, não à distância.
3. Rejeitar se houver linha de visão direta do jogador a < 25 m (evita "ver
   aparecer" atrás de um muro baixo).
4. Preferir pontos **à frente da direção de movimento** (40%), laterais
   (40%), atrás (20%) — o jogador vê a horda chegar em vez de ser apanhado
   pelas costas pela câmara.
5. Grabbers e Crawlers podem spawnar atrás/lado; Screamers nunca a < 20 m.
6. Se nenhum candidato passar, o spawn espera (não força).

---

## 6. Game feel (P1)

Prioridade = impacto percebido ÷ custo. Custo para um principiante a solo,
com primitivas: **S** ≤ 1 dia, **M** 2–4 dias, **L** ≥ 1 semana.

| # | Item | Descrição | Custo |
|---|---|---|---|
| 1 | **Som de impacto** | sons distintos: corpo, cabeça (seco e "crunch"), morte, breaker. Sintetizados/gerados (sfxr) sem assets externos | S |
| 2 | **Flash de dano** | inimigo pisca branco 0,05 s (parâmetro do material/shader) | S |
| 3 | **Knockback** | vetor de empurrão nos dados do inimigo, decai em 0,2 s; shotgun e breaker fortes | S |
| 4 | **Micro hit-stop** | `Engine.time_scale` 0,05 s **só** em headshot-kill de especial, breaker que derruba ≥ 3, morte de Brute — nunca em cada tiro | S |
| 5 | **Screen shake contextual** | trauma acumulado (Squirrel Eiserloh), só explosões, cargas, breaker | S |
| 6 | **Partículas de impacto** | `GPUParticles3D` com cubos pequenos: verde-escuro corpo, mais na cabeça; poças decal no chão | M |
| 7 | **Desmembramento com primitivas** | ao morrer por headshot, a esfera da cabeça solta-se (RigidBody3D com pool de ~30, desaparece em 3 s); explosões soltam braços (cilindros). Humor DRG: cabeças que saltitam, ocasional "boing" | M |
| 8 | **Animação procedural** | balanço da cápsula ao andar, inclinação no knockback, squash & stretch ao morrer (sem rigs) | M |
| 9 | **Números de dano** | opcionais nas definições; amarelo para headshot | S |
| 10 | **Frases do personagem** | linhas de texto/voz curtas com humor ("Rock and Stone"-like próprio) em eventos | M (texto) / L (voz) |

Ordem de implementação no slice: 1–5 primeiro (uma semana somada), depois 7
(é o que torna os headshots visíveis e engraçados), depois 6 e 8.

---

## 6b. Power-ups de abate (escolhido pelo utilizador a 2026-10-10)

Inspirados nos power-ups do Call of Duty Zombies: de vez em quando um
inimigo abatido larga uma "ajuda". O utilizador aprovou a lista e decidiu
que **aparecem em todas as missões**. Se a quiser fechar, regista-a em
`DECISIONS.md`.

| Power-up | Efeito | Duração |
|---|---|---|
| Insta-Kill | Qualquer tiro mata qualquer inimigo: normais, elites, especiais e o chefe (pedido do utilizador a 2026-10-11) | ~20–30 s |
| Double XP / Intel | Duplica a XP e o Intel ganhos | ~20–30 s |
| Nuke | Mata **todos** os inimigos vivos no mapa, chefe incluído, e atrasa os spawns uns segundos. Os abates da Nuke não largam novos power-ups | instantâneo |
| Full Power | O breaker e a habilidade de classe ficam prontos | instantâneo |
| Max Shield | Enche o escudo (liga às cartas de escudo) | instantâneo |
| Extra Reroll | Um reroll grátis | instantâneo |
| Max Ammo | Enche as armas especiais. **Depende da decisão sobre as armas** | instantâneo |

Ficam para mais tarde, porque pedem sistemas novos: Death Machine (arma
temporária) e Zombie Blood (os zombies deixam de ver o jogador).

**Regras propostas** (os valores são hipóteses para playtest):
- **Probabilidade:** pequena por abate, com uma garantia (pity) para não
  passar demasiado tempo sem nada; maior nas elites e nos especiais.
- **Limites:** um drop a cada 30–45 s no máximo, e só um no chão de cada
  vez.
- **No chão:** ícone grande e brilhante que fica 25 s e pisca nos últimos
  10 s, como no CoD.
- **No HUD:** temporizadores com o ícone e os segundos que faltam.
- **Cartas:** uma carta de "sorte" aumenta a probabilidade de drops.

## 7. Decisões propostas e perguntas

### Decisões propostas (o utilizador decide)

| ID | Proposta |
|---|---|
| D1 | Arma base com **munição infinita** e auto-fire; armas especiais com munição limitada e **disparo manual**. |
| D2 | Auto-fire com **cone de foco** controlado pelo rato/stick; sem override manual no modo normal; "marcar alvo" 3 s; disparo manual só como opção a testar. |
| D3 | Headshot = raycast à cabeça com spread; probabilidade influenciada por foco, estar parado e orientação do alvo; 2× dano + efeito (stagger/desmembramento). |
| D4 | Breaker com **2 cargas**, 6 m, i-frames, para em pesados; variantes como perks. |
| D5 | Bull Rush passa a passivo "Bull" do Renegade (breaker atravessa pesados + rajada de shotgun no fim). |
| D6 | Slice: Assault Rifle, Pistol, Grenade Launcher; Shambler, Runner, Brute, Grabber. |
| D7 | Diretor com métrica de intensidade e fases crescer/pico/alívio; orçamento em pontos; spawn testado contra o frustum da câmara. |
| D8 | Game feel itens 1–5 e 7 entram no slice. |
| D9 | Cortar sprint, salto e agachar. |

### Perguntas para o utilizador

1. Preferes o foco pelo **rato no chão** (twin-stick) ou pela **direção do
   movimento** (mais simples, uma mão)? Isto muda o controlo todo.
2. Aceitas que as armas especiais sejam disparadas à mão, ou queres tudo
   automático (e as especiais também disparam sozinhas com cooldown)?
3. Bull Rush: Opção A (passivo) ou B (habilidade ativa)?
4. Breaker com i-frames (perdoa mais) ou sem (mais tático)?
5. O Bloater deve magoar o jogador e os zombies por igual (ferramenta) ou só
   o jogador (puro perigo)?
6. Humor: só visual (cabeças a saltitar) ou também frases do personagem?
7. O boss "The Breaker" fica com esse nome (confunde com o verbo breaker)?
