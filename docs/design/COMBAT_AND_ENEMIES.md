# Combate e inimigos

Documento de design do remake, escrito a 2026-10-05. **Isto é uma proposta**:
as decisões fechadas vivem em `docs/DECISIONS.md` e prevalecem. Todos os
números são **hipóteses de playtest**, não valores afinados; servem para o
primeiro protótipo ter um ponto de partida coerente.

Base: `docs/DECISIONS.md` (câmara média), `docs/design/BRAINSTORM.md` e os
documentos do original em `docs/legacy/` (GDD, INSPIRATIONS,
CONTENT_EXPANSION_PLAN, PROJECT_AUDIT).

## 0. Ponto de partida: o que a câmara média vê

Quase todas as escolhas deste documento dependem de uma pergunta geométrica:
o que cabe no ecrã. Fiz a conta para o preset **Média** do brainstorm
(inclinação 35°, 10 m de distância, FOV vertical 60°, ecrã 16:9, câmara a
olhar para o peito do jogador a 1,2 m, terreno plano):

| Preset | Atrás do jogador | Largura à altura do jogador | À frente |
|---|---|---|---|
| Ombro afastado (25°, 7 m) | ~3,7 m | ~16 m | até ao horizonte |
| **Média (35°, 10 m)** | **~5 m** | **~20 m** | **~70 m (o nevoeiro corta antes)** |
| Alta leve (45°, 13 m) | ~6 m | ~24 m | ~24 m |

Conclusões que o resto do documento usa:

1. **A câmara média é direcional.** Vê muito à frente e aos lados, mas só
   ~5 m para trás. Um zombie a 8 m atrás do jogador está fora do ecrã.
2. Por isso, **"fora do ecrã" não chega como regra de spawn**: tem de haver
   também uma distância mínima (secção 5).
3. Mirar "para baixo no ecrã" (para trás do jogador) mostra pouco terreno.
   Isto favorece uma câmara cujo yaw acompanha a mira, mas essa escolha é do
   spike `camera_medium` e do documento de câmara/HUD; aqui só assinalo a
   dependência.
4. A ~10 m, uma cabeça de zombie (~25 cm) ocupa ~20–25 px de altura num ecrã
   1080p, e numa multidão sobrepõe-se ao corpo de quem está atrás. Isto pesa
   na decisão sobre headshots (secção 1.3).

São contas, não medições: o spike `camera_medium` deve confirmar estes
valores na cena real (com relevo e nevoeiro).

---

## 1. Modelo de mira

### 1.1 As três opções

| | Mira manual | Mira assistida (magnetismo) | Auto-fire opcional |
|---|---|---|---|
| Como funciona | O cursor (rato) ou o stick direito define a direção; as balas vão para onde se aponta | Igual à manual, mais ajudas discretas: a bala "curva" para o inimigo mais próximo do eixo dentro de um cone pequeno, e a mira abranda ao passar sobre um alvo | A arma escolhe o alvo mais próximo com linha de tiro e dispara sozinha; o jogador só se move |
| Prós | Máxima expressão de habilidade; pontos fracos fazem sentido; nada a afinar | Mantém a intenção do jogador; dá paridade entre rato e comando; perdoa a imprecisão de uma horda a 360° | Carga de controlo mínima; acessível; foco no movimento e nas escolhas |
| Contras | No comando, mirar com stick numa horda densa cansa; mirar para trás com a câmara média é difícil | Exige afinação (cones, forças); demasiado forte parece que "o jogo joga por mim" | **Já falhou no original**: auto-fire a gastar munição escassa frustra, e torna headshots e armas de precisão irrelevantes |
| Encaixa em | Direção B (shooter tático) | Mistura A+B (a que a câmara média sugere) | Direção A (survivors) |

### 1.2 Recomendação: mira assistida

**Mira manual com magnetismo, com força diferente por dispositivo:**

- **Rato:** cone de magnetismo pequeno (~3°), sem abrandamento da mira. O
  rato já é preciso; a ajuda só evita "falhar por um píxel" numa multidão.
- **Comando:** cone maior (~8°), abrandamento da mira (~40 %) sobre alvos e
  seleção do alvo mais próximo do eixo do stick, não do jogador.
- O magnetismo **aponta ao centro de massa**, nunca a pontos fracos: acertar
  no ponto fraco continua a ser mérito do jogador.
- **Auto-fire existe apenas como opção de acessibilidade**, desligada por
  defeito, e só para a arma base de munição infinita. Nunca gasta munição
  limitada.

Porquê: o pilar provável "romper a horda" pede que o jogador escolha **onde**
abrir caminho. Com auto-fire, essa escolha desaparece. Com mira manual pura,
o comando fica em desvantagem e a horda a 360° torna-se cansativa. A mira
assistida é o meio-termo usado por quase todos os shooters de consola.

**Como se implementa (para o spike):** o cursor/retícula projeta um raio a
partir da câmara. Se o raio tocar num inimigo, esse é o ponto de mira; se
não, usa-se a interseção com um plano horizontal à altura do peito (1,2 m).
O disparo sai da arma em direção a esse ponto. O magnetismo corrige a direção
final para o inimigo dentro do cone com menor ângulo ao eixo. O hitscan é
testado contra o spatial hash da horda (ver brainstorm, secção 8), não contra
colisores de física.

### 1.3 Headshots e pontos fracos

O original tinha headshot ×2 em todos os inimigos. Com a câmara média isto
deixa de funcionar bem: cabeças pequenas, sobrepostas e vistas de cima.

| Opção | Prós | Contras |
|---|---|---|
| A — Sem headshots; **pontos fracos só nos especiais** | Legível de cima; cada ponto fraco é desenhado para ser visto; recompensa precisão onde importa | Perde-se a micro-recompensa em cada zombie comum |
| B — Headshot ×1,5 nos comuns + pontos fracos nos especiais | Mantém algum "clique satisfatório" | Na prática, é sorte numa multidão; duas regras de dano para ensinar |
| C — Headshot ×2 como no original | Familiar | Pensado para câmara ao ombro; com magnetismo ao centro de massa quase nunca acontece |

**Recomendo A.** Os comuns morrem em 2–4 tiros da arma base; o que pede
precisão são os especiais. Cada especial tem um ponto fraco **brilhante, no
topo ou nas costas** (onde a câmara o vê), que recebe ×2,5 de dano e, em
alguns casos, provoca um efeito (secção 4). A arma Lance (secção 3) é a
escolha natural de quem gosta de precisão.

---

## 2. O verbo "breaker"

O título dá o verbo: o jogador **rompe** a horda. O breaker é um movimento
físico com cooldown que empurra inimigos e abre caminho. Para funcionar,
cada inimigo pertence a uma **classe de massa**:

- **Leve** (Walker, Runner, Crawler, Screamer): é projetado.
- **Média** (Spitter, Bloater, Grabber): é atordoado e empurrado pouco.
- **Pesada** (Brute, Shieldback pela frente, boss): trava o breaker.

### 2.1 Variantes

| | A — Investida (Charge) | B — Empurrão (Shove) | C — Impacto (Slam) |
|---|---|---|---|
| O que faz | Avança 6 m em 0,25 s; leves são projetados para os lados (efeito cunha), médios atordoados 0,6 s | Sem deslocação; cone de 100° e 3 m à frente; leves recuam 4 m, médios 2 m, pesados vacilam 0,3 s | Salto curto de 4 m; ao aterrar, onda radial de 4 m com 30 de dano e knockback |
| Cooldown | 5 s | 2,5 s | 9 s |
| Risco | Termina **dentro** da horda; se bater num pesado, ressalta e fica atordoado 0,3 s | Não tira o jogador do sítio: se o cerco for total, não salva | 0,4 s vulnerável ao aterrar; cooldown longo |
| Recompensa | Fuga de cercos, atravessar a horda até ao objetivo, reposicionamento ofensivo | Espaço imediato, barato, interrompe Runners e Grabbers | Controlo radial quando se está cercado |
| Sensação | "Atravesso a parede de zombies" | "Afasto-os de mim" | "Esmago o círculo à minha volta" |

Regras comuns:

- **Invulnerabilidade só no arranque** (primeiros 0,15 s da Investida). Se
  fosse invulnerável durante todo o movimento, deixava de haver risco.
- **Efeito bowling:** um inimigo projetado que colide com outro causa 10 de
  dano a ambos. Investir contra um grupo denso compensa mais do que contra
  um isolado.
- **Kills reduzem o cooldown** (−0,2 s por kill, mínimo 2 s). Jogar de forma
  agressiva recarrega o verbo agressivo.
- **Liberta de agarrões** (Grabber): usar o breaker enquanto se está preso
  solta o jogador. É um contra claro, mas gasta o cooldown, que depois não
  está disponível para fugir.
- **Bloater:** investir contra um Bloater rebenta-o **em cima do jogador**.
  É o "não faças isto" que ensina a ler a horda antes de investir.
- **Sem dano próprio** das armas, mas a explosão do Bloater fere o jogador.

### 2.2 Recomendação

**Investida (A) como breaker base de todas as classes.** É a única variante
que entrega a fantasia do título (atravessar a horda) e cria a decisão de
risco mais interessante: "consigo chegar ao outro lado?". Empurrão e Impacto
ficam como **variantes de classe ou cartas** que substituem ou modificam a
Investida (por exemplo, uma carta "a Investida termina num Impacto"), em vez
de três botões ao mesmo tempo.

Sem corrida (sprint): o breaker é o verbo de mobilidade. Ter os dois diluía-o.
Velocidade base proposta do jogador: **5 m/s** (o original tinha 4 a andar e
7 a correr).

---

## 3. Arsenal inicial

Princípios:

1. **Cada arma muda a forma de jogar**, não só os números. A pergunta de
   teste é: "o jogador consegue explicar o que faz de diferente com ela?"
2. **Dois slots:** arma base (munição **infinita**, com carregador e
   recarga) + arma especial (munição **limitada**, sem recarga infinita;
   repõe-se com pickups ou no barco). Isto segue Helldivers 1 e Enter the
   Gungeon: o jogador nunca fica sem forma de lutar, e a munição limitada é
   uma escolha de quando gastar, não ansiedade.
3. **Etiquetas de comportamento** que cartas e sinergias usam: Penetração,
   Ricochete, Fogo, Explosivo, Elétrico, Impacto.
4. Só armas de fogo (decisão herdada do original: sem melee).

### 3.1 Catálogo (8 armas)

| Arma | Slot / munição | Papel | Alcance | Comportamento | Valores iniciais |
|---|---|---|---|---|---|
| **Service Rifle** | Base, infinita | Generalista | 30 m | Cada bala **penetra 1 inimigo** (o segundo recebe 50 %). Recompensa alinhar a horda num corredor | 18 dano, 7 tiros/s, carregador 30, recarga 1,5 s |
| **Scattergun** | Base (classe alternativa), infinita | Curta distância, controlo | 8 m efetivos | Cone de 8 chumbos; cada chumbo dá **knockback**; recarga cartucho a cartucho (pode disparar a meio) | 8 × 9 dano, 1,2 tiros/s, 6 cartuchos, 0,4 s por cartucho |
| **Bouncer** | Especial, 240 balas | Multidões dispersas | 15 m | SMG cujas balas **ricocheteiam 1×** para o inimigo mais próximo a ≤ 6 m | 10 dano, 12 tiros/s |
| **Lance** | Especial, 24 tiros | Precisão, especiais | 40 m | Carrega 0,6 s; raio que **perfura tudo** em linha; ×2,5 em pontos fracos (como todas), atravessa o escudo do Shieldback | 150 dano |
| **Thumper** | Especial, 18 granadas | Área, controlo | 4–20 m (arco) | Lança-granadas: aponta-se a um **ponto no chão** (encaixa bem no cursor projetado). Explosão radial com knockback para fora | 80 dano, raio 3,5 m, 1,2 tiros/s |
| **Flamer** | Especial, 10 s de combustível | Negação de área | 6 m (cone) | Incendeia; **queimados espalham fogo** a vizinhos por contacto; deixa o chão a arder 4 s | 40 dano/s + queimadura 10/s durante 3 s |
| **Arc Coil** | Especial, bateria que regenera | Corrente, atordoar | 12 m | Raio que **salta para 4 alvos**, atordoa 0,3 s. Bateria de 100 regenera 8/s quando não dispara: munição "renovável", um terceiro modelo entre infinito e limitado | 25 dano por alvo, gasta 20/s |
| **Shredder** | Especial, 400 balas | Supressão | 20 m | Minigun: **aquece 0,8 s** antes de disparar; o jogador anda a −40 % enquanto dispara. Força a escolher posição antes de abrir fogo | 12 dano, 20 tiros/s |

DPS sustentado aproximado da Service Rifle: 18 × 7 × (30 / 7) / (30 / 7 + 1,5)
≈ 93 de dano por segundo, ou seja, ~2 Walkers por segundo com boa mira. Este
número é a régua para o resto dos valores.

### 3.2 Sinergias (exemplos)

| Combinação | O que acontece | Porquê é interessante |
|---|---|---|
| Impacto + Breaker | Inimigos projetados pela Scattergun ou Thumper contam para o efeito bowling | Junta a arma ao verbo do título |
| Fogo + Bloater | Um Bloater a arder explode numa nova de fogo | Ler a horda e escolher quando detonar |
| Elétrico + ácido do Spitter | Poças de ácido conduzem o Arc Coil a todos os que estão nelas | Transforma uma ameaça em ferramenta |
| Penetração + Shieldback | Service Rifle e Lance ignoram parte do escudo | Dá contra ao inimigo blindado sem explosivos |
| Explosivo + Screamer | Matar o Screamer com área também limpa os que ele já chamou | Recompensa prioridade de alvo |

Evoluções de armas (arma + carta = evolução) pertencem ao documento de
progressão; este catálogo só garante que cada arma tem etiquetas onde as
cartas se possam ligar.

---

## 4. Bestiário

Leitura **de cima a ~35°**: o que se vê é a planta (forma no chão), o
tamanho, a postura, a cor e o que está no topo ou nas costas. Tudo pensado
para primitivas Godot (cápsulas, caixas, esferas) com materiais simples, e
cada especial com um **elemento emissivo** que se lê mesmo no meio da horda.

Referência do jogador: 100 HP, 5 m/s. "Custo" é o preço no orçamento do
diretor (secção 5).

| Inimigo | Papel | Silhueta a 35° | Comportamento | Contra do jogador | HP | Velocidade | Dano | Massa | Custo |
|---|---|---|---|---|---|---|---|---|---|
| **Walker** | Base, a "massa" da horda | Cápsula normal, cinzento-esverdeado, braços à frente | Segue o flow field até ao jogador e ataca corpo a corpo | Qualquer arma; manter distância | 50 | 1,8 m/s | 8 por golpe (1 s) | Leve | 1 |
| **Runner** | Pressão rápida, castiga ficar parado | Mais baixo e **inclinado para a frente** (planta alongada), pele clara | Corre em linha reta, pára 0,5 s depois de atacar | Matar cedo; Empurrão/Investida; Scattergun | 30 | 6 m/s | 6 por golpe (0,7 s) | Leve | 1,5 |
| **Crawler** | Enxame baixo, testa armas de área | Muito pequeno e **rente ao chão**, em grupos de 6 | Rasteja em bando; tem dificuldade em subir declives | Thumper, Flamer, Bouncer; difícil de acertar com mira | 12 | 4,5 m/s | 3 por golpe (0,5 s) | Leve | 0,5 cada |
| **Brute** | Tanque, bloqueia caminhos | **1,6× maior**, ombros largos (caixa sobre cápsula), espinha laranja brilhante nas costas (ponto fraco) | Avança devagar; a 8 m, prepara uma carga (0,8 s, sinal claro) a 8 m/s | Esquivar a carga com a Investida lateral; flanquear para o ponto fraco | 400 | 2,2 m/s (carga 8) | 30 + knockback forte | Pesada | 8 |
| **Spitter** | Ameaça à distância, nega zonas | Corcunda com **saco verde brilhante nas costas** | Mantém 12–16 m; cospe ácido em arco (1,0 s de aviso no chão) que deixa poça 4 s | Fechar distância com a Investida; rebentar o saco (ponto fraco) faz a poça cair à volta dele | 70 | 2,0 m/s | 15 no impacto + 5/s na poça | Média | 4 |
| **Bloater** | Perigo de proximidade, castiga o breaker cego | **Esfera grande** amarelo-esverdeada, pulsa | Lento; ao morrer ou ao ser investido explode (raio 3,5 m), ferindo jogador **e zombies** | Matar à distância, idealmente no meio de outros zombies; nunca investir | 120 | 1,4 m/s | 35 na explosão + knockback | Média | 4 |
| **Screamer** | Prioridade de alvo, acelera o diretor | Alto e magro, **braços erguidos**, anel vermelho a pulsar na cabeça | Foge do jogador; grita a cada 8 s, chamando uma onda extra (12 de custo) e acelerando os comuns 20 % durante 5 s | Matar primeiro: Lance, Rifle; segui-lo com a Investida | 80 | 3,0 m/s (foge) | Nenhum direto | Leve | 5 |
| **Grabber** | Pune o isolamento, exige o breaker | **Braços muito compridos** estendidos para a frente (planta em "T" alongado), roxo | A 4 m, lança os braços (0,5 s de aviso); prende o jogador 3 s, puxa-o e causa 10/s | Usar o breaker para se soltar; ou disparar nos braços (ponto fraco enquanto agarra) | 110 | 3,5 m/s | 10/s enquanto prende | Média | 6 |
| **Shieldback** | Blindado, obriga a flanquear | **Placa plana** à frente (caixa larga), placa com fenda laranja nas costas | Avança de frente para o jogador; roda devagar (90°/s) | Flanquear (a rotação lenta permite contorná-lo), Thumper atrás, Lance atravessa o escudo | 250 (frente: −80 % de dano) | 2,0 m/s | 15 por golpe | Pesada pela frente, média por trás | 6 |
| **The Breaker** (boss) | Clímax da run | 3× maior, placas e núcleos brilhantes nos ombros | Fases: carga em linha, ondas de impacto, invoca Walkers. Núcleos expostos depois de cada carga | Esquivar com a Investida, disparar nos núcleos na janela de exposição | 2500 | 2,5 m/s | 40 por carga | Pesada | — |

Notas:

- **Limites por tipo em simultâneo** (hipótese inicial): Brute 2, Spitter 3,
  Bloater 3, Screamer 1, Grabber 1 (2 a partir da terceira ilha),
  Shieldback 2, Crawlers 3 bandos.
- **Aviso antes de dano grande:** carga do Brute, braços do Grabber, arco do
  Spitter e explosão do Bloater têm sempre um sinal visual e sonoro
  (0,5–1,0 s). Morrer sem perceber porquê é o pior resultado num jogo de
  horda.
- O vertical slice só precisa de 4 inimigos. Recomendo **Walker, Runner,
  Bloater e Grabber**: Walker e Runner testam a mira e a pressão; Bloater e
  Grabber testam o breaker pelos dois lados (quando não usar e quando é
  obrigatório). Alternativa: trocar o Grabber pelo Screamer se o spike do
  diretor precisar de ser testado mais cedo.

---

## 5. Diretor de horda

### 5.1 Ideia

O diretor do original **só escalava com o tempo** (níveis de 110 → 75 s,
mais inimigos e mais pesados). O Left 4 Dead faz outra coisa: mede o
**stress do jogador** e alterna entre crescer, pico e alívio. O alívio é
tão importante como o pico: é quando o jogador respira, apanha recursos e
decide.

### 5.2 Métrica de intensidade

Um valor `intensity` de 0 a 100, atualizado a cada 0,25 s:

| Evento | Efeito |
|---|---|
| Dano recebido | +1 por ponto de dano |
| Inimigos a ≤ 5 m | +3 por inimigo, por segundo |
| Ser agarrado ou apanhado por uma explosão | +15 |
| Kill a ≤ 3 m | +2 |
| Nenhum inimigo a ≤ 8 m há 3 s | decai 5 por segundo |

O decaimento só começa quando a ameaça imediata desaparece (como em L4D).
Assim, matar a horda à distância não sobe a intensidade, mas ser cercado
sobe depressa.

### 5.3 Fases

```
 CRESCER ──(intensity ≥ 70 ou orçamento gasto)──▶ PICO
    ▲                                              │ 3–6 s
    │                                              ▼
    └──(intensity < 25 e ≤ 10 vivos, ou 30 s)── ALÍVIO
```

| Fase | Regras | Duração típica |
|---|---|---|
| **Crescer** | Spawns em lotes de 4–8 a cada 2–4 s, até gastar o orçamento da onda. Especiais entram a meio | 40–70 s |
| **Pico** | Mantém a pressão, sem novos lotes grandes. Garante que o pico existe sem se tornar parede infinita | 3–6 s |
| **Alívio** | Sem lotes; só um Walker a cada 5 s, para o mundo não ficar vazio. Bom momento para drops de munição e para o jogador avançar no objetivo | 15–30 s |

Numa ilha de ~5 minutos isto dá 3–4 ciclos, mais os eventos da missão.
**Eventos de missão sobrepõem-se ao diretor**: por exemplo, "Hold Zone"
força uma fase de crescer com orçamento próprio e garante um alívio no fim.

### 5.4 Orçamento

- **Orçamento da onda** (pontos, ver coluna "custo" no bestiário):
  `40 × dificuldade × modificador da ilha × (1 + 0,15 × ilhas concluídas)`.
  Ondas seguintes da mesma ilha crescem +10 %.
- **Tetos de vivos** (hipótese, depende da decisão em aberto sobre escala):
  100 inimigos ativos, dos quais no máximo 4 especiais (6 a partir da
  terceira ilha). O original usava 90 ativos com barreira de 120; o spike
  `horde_flowfield` deve medir o teto real com MultiMesh.
- **Reciclagem:** um inimigo a mais de 60 m de caminho e fora do ecrã há 10 s
  é removido e devolvido ao orçamento para nascer mais perto. Mantém a
  pressão sem aumentar o teto (truque do L4D).
- Acima do teto, a dificuldade cresce pela **composição** (mais especiais,
  Brutes), não pela quantidade.

### 5.5 Regras de spawn com a câmara média

Com a câmara média só se veem ~5 m atrás do jogador (secção 0). Logo:

1. **Pontos candidatos** pré-calculados por ilha (grelha sobre o terreno
   navegável do flow field), excluindo água, zonas de missão e o barco.
2. **Fora do frustum com margem:** a caixa do inimigo (2 m de altura) é
   testada contra o frustum da câmara alargado ~15 %. A margem protege
   contra a câmara rodar no instante seguinte.
3. **Ou ocluído:** um ponto dentro do frustum é aceite se estiver a ≥ 20 m
   **e** o raio câmara→ponto for bloqueado (falésia, edifício) ou estiver
   para lá do nevoeiro (~35 m).
4. **Distância de caminho** (no flow field, não em linha reta) entre
   **18 e 45 m**. O mínimo de 18 m existe porque 8 m atrás já é "fora do
   ecrã" e seria injusto. O máximo garante que chegam em ~20 s.
5. **Distribuição por setores:** à volta do jogador há 6 setores de 60°.
   No máximo 50 % de um lote nasce nos dois setores de trás, e esses spawns
   ficam a ≥ 22 m e anunciam-se com som (gemidos) 1 s antes.
6. **Especiais** nunca a menos de 20 m e, se nascerem fora do ecrã, aparecem
   no indicador de borda do HUD.
7. **Fallback "emergência":** se não houver ponto válido (ilha pequena,
   jogador num canto), os zombies **saem do chão ou do mar** a ≥ 10 m com
   1,5 s de aviso (monte de areia, bolhas na água). É visível de propósito:
   aparecer no ecrã é aceitável quando é legível.

Isto deve ser validado no spike `director` com consultas reais à cena
(frustum, raycasts, flow field), não só com distâncias em linha reta.

---

## 6. Game feel

Prioridade = impacto na sensação de combate a dividir pelo custo. Custos
estimados em horas de trabalho para um primeiro passe com primitivas, sem
assets externos; para quem está a aprender Godot, contar com o dobro.

Uma regra transversal: com centenas de inimigos em MultiMesh, os efeitos por
inimigo têm de passar pelos **dados** (por exemplo, `instance_custom_data`
para o flash), não por nós individuais.

| # | Efeito | O que é | Custo | Porquê nesta posição |
|---|---|---|---|---|
| 1 | **Flash de impacto** | O inimigo pisca a branco 60 ms quando é atingido | 1–2 h | Confirma o acerto com custo quase nulo |
| 2 | **Som de impacto** | Som curto e forte, com variação de tom aleatória (±10 %), sintetizado em Godot no protótipo | 2–4 h | O som vende mais o impacto do que qualquer efeito visual |
| 3 | **Knockback com classes de massa** | Leves recuam, médios vacilam, pesados não mexem | 3–5 h | É a base do breaker; sem isto o verbo do título não existe |
| 4 | **Muzzle flash e traçador** | Luz curta na arma e linha visível do disparo | 2 h | Mostra para onde se está a disparar, essencial com mira assistida |
| 5 | **Hit-stop seletivo** | Pausa de 30–60 ms **só** em eventos grandes: contacto do breaker, kill de especial, explosão. Nunca em cada bala | 2 h | Em cada bala, uma horda transformava o jogo em câmara lenta |
| 6 | **Screen shake por trauma** | Shake que soma "trauma" e decai, com teto; explosões e cargas do Brute | 2 h | Barato, mas fácil de exagerar: opção para desligar |
| 7 | **Partículas de impacto** | Salpicos com `GPUParticles3D` em pool, cor por inimigo | 3 h | Ajuda a ler onde se acerta na multidão |
| 8 | **Vibração do comando** | Curta no disparo, forte no breaker | 1 h | Custo mínimo, grande ganho no comando |
| 9 | **Morte legível** | Corpo projetado na direção do tiro e afunda no chão; desmembramento simples (uma primitiva "salta" como `RigidBody3D` com vida curta) | 6–10 h | Muito satisfatório, mas é o efeito mais caro e o que mais pesa com muitas mortes por segundo |
| 10 | **Números de dano** | Opcionais, desligados por defeito | 2 h | Úteis para afinar e para jogadores de builds, mas poluem o ecrã |

Os primeiros quatro dão a maior parte da sensação e cabem num dia de
trabalho; devem entrar no vertical slice. Os indicadores de borda para
especiais fora do ecrã são essenciais, mas pertencem ao documento de
câmara/HUD.

---

## 7. Não vamos fazer (no combate)

| O quê | Porquê |
|---|---|
| Armas melee | Decisão herdada do original; o corpo a corpo é o breaker |
| Mira vertical / saltar | A câmara média e o plano de mira à altura do peito tornam-na desnecessária |
| Sistema de cobertura | Contraria "romper a horda"; a horda contorna cobertura |
| Dano próprio das armas do jogador | Complica sem acrescentar decisões; o risco vem do Bloater |
| Auto-fire com munição limitada | Foi a frustração principal do original |
| Inimigos sem sinal antes de dano grande | Mortes sem leitura são a principal causa de abandono neste género |

---

## 8. Decisões propostas

Propostas para o utilizador decidir; não alteram `docs/DECISIONS.md`.

| ID | Proposta | Alternativas | Ponto em aberto relacionado |
|---|---|---|---|
| C1 | **Mira assistida** (manual + magnetismo, mais forte no comando); auto-fire só como opção de acessibilidade na arma base | Manual pura; auto-fire por defeito | Em aberto n.º 2 (mira) |
| C2 | **Sem headshots; pontos fracos (×2,5) nos especiais**, brilhantes e visíveis de cima | Headshot ×1,5 nos comuns; headshot ×2 | Em aberto n.º 2 (headshots) |
| C3 | **Investida como breaker base**; kills reduzem o cooldown; Empurrão e Impacto como variantes de classe/cartas. Sem sprint | Empurrão como base (mais seguro); os três em botões diferentes | Pilar "romper a horda" |
| C4 | **Arma base infinita + arma especial limitada** (um slot cada) | Tudo limitado (original); tudo infinito (survivors) | — |
| C5 | **Escala: dezenas a ~100 ativos, com ≤ 4–6 especiais**, número final medido pelo spike `horde_flowfield` | 30–60 com especiais mais inteligentes (direção B); 200–500 (direção A) | Em aberto n.º 3 (escala) |
| C6 | **Diretor por intensidade** com crescer/pico/alívio e regras de spawn da secção 5.5 | Escalar só com o tempo (original) | — |
| C7 | **Vertical slice:** Service Rifle + Thumper + Lance; Walker, Runner, Bloater, Grabber | Scattergun como base; Screamer em vez do Grabber | Âmbito do slice (GDD) |

---

## 9. Perguntas para o utilizador

1. **Yaw da câmara:** preferes que a câmara rode com o rato (mais perto de
   um shooter, vê-se para onde se mira) ou que fique fixa e o cursor se
   mova livre no ecrã (mais perto de um twin-stick)? Com a câmara média,
   o segundo modo vê pouco para trás. Isto é decidido no spike da câmara,
   mas muda a sensação da mira.
2. **Headshots:** aceitas perder os headshots nos zombies comuns em troca de
   pontos fracos visíveis nos especiais?
3. **Breaker:** a Investida como verbo único chega, ou queres logo dois
   (Investida + Empurrão) em botões diferentes?
4. **Sem sprint:** concordas que o breaker substitua a corrida?
5. **Gore:** desmembramento simples (peças primitivas a saltar) é o tom
   certo, ou preferes mortes mais limpas (afundar/desfazer)?
6. **Dificuldade-alvo:** o jogo deve ser acessível a quem joga survivors
   casualmente, ou exigente como um shooter de horda (Vermintide)? Isto
   decide a força do magnetismo e os valores do bestiário.
7. **Números de dano:** ligados ou desligados por defeito?
