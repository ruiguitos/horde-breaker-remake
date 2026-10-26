# Experiência em Unreal Engine — fatia vertical (2026-10-26)

**Isto é uma experiência, não uma decisão.** O projeto continua no Godot 4.7
(`docs/DECISIONS.md`); a avaliação de mudança de motor está em
[ENGINE_MIGRATION.md](ENGINE_MIGRATION.md) e não foi alterada. Este documento
existe para se poder comparar o *feel* do combate num segundo motor sem
comprometer o jogo atual.

**Para que serve:** responder a uma pergunta concreta — a horda de 150 com
auto-fire, Breaker e leitura de 360° sente-se melhor em Unreal do que em Godot?
Se a resposta for não, a experiência fecha-se e não se perde nada.

**O que decide tudo:** o passo 3 do prompt (a horda). Se 150 inimigos com Mass
Entity ou Instanced Static Mesh não correrem a 60 fps a 1080p numa GPU média, o
resto não interessa. Medir antes de construir menus.

**Origem dos números:** `game/data/game_data.gd`, `docs/tech/COMBAT_CATALOG.md`
e `docs/DECISIONS.md`, no estado de 2026-10-26. São hipóteses de playtest, não
valores sagrados; servem para a experiência ser comparável com o jogo real.

## Prompt (copiar tal e qual)

```text
CONTEXTO
Quero construir uma fatia vertical jogável, em Unreal Engine 5.4+, de um horde
shooter de expedição. Não é um port: é uma experiência para comparar o "feel"
com uma versão que já existe noutro motor. Texto do jogo em inglês; código e
comentários em inglês.

PILARES (a decisão de design que tudo serve)
1. Romper a horda: a horda é terreno que se move; o jogador abre caminho com uma
   investida (Breaker) e ganha por posicionamento, não por pontaria fina.
2. Cada ilha é uma decisão: chegar, cumprir um objetivo, decidir quando sair.
3. Builds que mudam a forma de jogar: cartas que alteram comportamento, não +5%.

ESCOPO DA FATIA (não fazer mais do que isto)
- Uma ilha de 256 × 256 m, plana com costa suave, arena aberta com 3 laços e
  cobertura baixa. Sem mundo aberto, sem streaming.
- 3 inimigos: Walker, Runner, Brute. Um boss simples (Behemoth) opcional.
- 2 armas: Assault Rifle (principal) e Shotgun (secundária).
- Breaker, sprint, 6 cartas de level-up, HUD mínimo.
- Uma run de 5–8 minutos: desembarcar, sobreviver, extrair.

JOGADOR (números exatos)
- Velocidade 6 m/s; sprint x1,6 com 3 s de estamina e recarga de 0,75/s após
  0,8 s parado. O sprint DISPARA (run and gun).
- Câmara: terceira pessoa sobre o ombro, 1,6 m à direita, FOV 60, sem auto-rotação
  da câmara pelo auto-aim. Opção de primeira pessoa.
- Breaker: investida de 5 m em 0,18 s, 15 de dano, raio 2,2 m, atordoa 1 s,
  cooldown 6 s, 0,4 s de proteção contra corpo a corpo durante a investida,
  solta o jogador de um Grabber. Atravessa inimigos comuns, para nos pesados.
- Vida 100, escudo 0–100 (absorve antes da vida, sem regeneração).
- Mira: AUTOMÁTICA. Nas câmaras com mira, escolhe o inimigo cujo corpo está a
  menos de 6° do raio da câmara, com linha de tiro livre (do soldado e da
  câmara), e dispara; o jogador posiciona-se e olha. Headshot quando o raio passa
  perto da cabeça: dano x2,5.

COMBATE
| Arma | Dano | Tiros/s | Alcance | Pente | Recarga | Reserva |
|---|---|---|---|---|---|---|
| Assault Rifle | 12 | 9 | 30 m | 30 | instantânea | infinita |
| Shotgun | 9 x 8 bagos | 1,4 | 12 m | — | — | 40 |
Headshot x2,5. Dispersão AR 2°, Shotgun 22°. Hitscan, com perfuração 2 na
Shotgun (atravessa 2 alvos por bago).

INIMIGOS
| Inimigo | Vida | Velocidade | Dano/intervalo | XP | Nota |
|---|---|---|---|---|---|
| Walker | 30 | 1,8–2,6 | 8 / 1,0 s | 10 | horda comum |
| Runner | 18 | 4,6–5,4 | 6 / 0,7 s | 12 | rápido, frágil |
| Brute | 260 | 1,6–1,9 | 25 / 1,6 s | 100 | -75% de dano de frente; não é empurrado |
| Behemoth | 1800 | 1,7 (2,7 abaixo de 50%) | 35 / 1,4 s | 1000 | -50% de frente; slam 6 m/30; rochas 20; invoca Runners |
Ataque corpo a corpo: aviso de 0,3 s (inclina-se e levanta os braços), e o dano
só entra se o jogador ainda estiver ao alcance; se saiu, falha. Durante o aviso,
o inimigo avança a 25% da velocidade.

HORDA E DIRETOR
- Alvo de 150 inimigos vivos, teto 300.
- Diretor em fases: crescer (spawns de 0,6 a 2,5/s em 30 s), pico (4,5/s durante
  12–18 s) e alívio (sem spawns novos, 10–15 s). Picos também por evento.
- Spawn fora do frustum da câmara, a 18–35 m, preferindo a frente e os lados.
- TECH NOTE CRÍTICA: não uses um Actor/Character por inimigo nem Behavior Trees.
  Usa Mass Entity (recomendado) ou um sistema de dados próprio com
  InstancedStaticMesh + flow field numa grelha de 1 m e spatial hash para
  separação, hitscan e áreas. A animação pode ser por pivôs no material (World
  Position Offset) ou VAT; nada de 150 esqueletos animados. Isto é o ponto que
  decide se a horda é possível.

MISSÃO E RUN
- Ilha: ativar 2 geradores (8 s a menos de 4 m cada, sair pausa) e voltar ao
  barco; cada ativação chama um pico de horda.
- Extração: chegar ao barco termina a run com bónus.
- Morrer termina a run; o "Intel" ganho conserva-se.
- Cartas: ao subir de nível, escolher 1 de 3; 1 reroll grátis por ecrã.
  XP do nível n para n+1: 10 x (8 + 6n + n^2). Nível 1->2 = 150.
- Seis cartas para a fatia: +10% dano (5 ranks), +8% cadência (5), cada 4.º tiro
  ricocheteia (3), explosão em abate por headshot (3), +15 de vida máxima (5),
  cooldown do Breaker x0,9 por rank (5).

MODO EXFIL (segunda experiência, opcional nesta fatia)
- Uma ilha, sem missão, horda sem fim. Pressão sobe em degraus a cada 90 s
  (150 -> 175 -> 200 -> 225 -> 250 vivos). Aos 10:00 abre um beacon de extração no
  extremo oposto ao início; chegar lá termina a run. Morrer termina.

UI
- HUD mínimo: vida, escudo, munição, Breaker e habilidade; objetivo ou relógio
  no topo, minimapa à direita. Texto com contorno, sem painéis opacos no centro.
- Ecrã de cartas: 3 cartas com categoria, efeito e pips de rank.

APRESENTAÇÃO
- Luz de amanhecer frio, nevoeiro em camadas, céu físico. Materiais PBR simples.
- Som: passos por superfície (areia, pedra, madeira, metal), impacto, headshot,
  música adaptativa (calma vs combate) conforme o diretor.

DESEMPENHO E ACEITAÇÃO
- 150 inimigos vivos a 60 fps a 1080p numa GPU média (RTX 3060/5060), com HUD,
  sombras e efeitos.
- Critérios: (a) 5 minutos jogáveis sem falhas; (b) o auto-fire acerta no que
  está debaixo da mira e não através de paredes; (c) o Breaker abre caminho e
  solta de um Grabber; (d) subir de nível dá uma escolha de 3 cartas; (e) morrer
  e extrair produzem resultados diferentes no ecrã final.

NÃO FAZER (nesta experiência)
- Co-op, mundo aberto, streaming, save de run, Berlenga, 39 cartas, árvore de
  perks, 11 missões, loja, attachments, modo história. Nada disso decide se o
  "feel" funciona.

ORDEM DE TRABALHO
1. Projeto em branco, Enhanced Input, personagem e câmara de ombro.
2. Uma arena de 256 m e a grelha de navegação + flow field.
3. Horda de 150 com ISM/Mass, hitscan contra dados, dano e morte.
4. Auto-fire com as regras acima e feedback (impacto, hitmarker, desmembramento
   simples).
5. Breaker, sprint, vida/escudo.
6. Geradores, barco, XP e cartas.
7. Diretor, som, HUD, boss.
No fim de cada passo, mede: inimigos vivos, ms de frame e o que quebrou.
```

## Como ler o resultado

- **Se o passo 3 correr bem**, a experiência continua e comparam-se as duas
  versões com a mesma lista de perguntas: a horda lê-se? o Breaker abre espaço?
  o auto-fire recompensa posição? Não decidir nada antes de haver números.
- **Se o passo 3 falhar** (não chega aos 150 ou desce dos 60 fps), a experiência
  fecha: o problema não é o motor, mas nenhum dos dois resolve a horda de graça.
- Em qualquer dos casos, este documento não muda `docs/DECISIONS.md` nem o
  trabalho em `game/`.
