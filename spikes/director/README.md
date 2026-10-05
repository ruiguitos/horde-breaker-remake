# Spike: diretor de horda (headless)

Pergunta do spike: **um diretor à Left 4 Dead (intensidade → crescer / pico /
alívio) dá um ritmo melhor do que o diretor original, que só escalava com o
tempo?** Serve o ponto 3 do `docs/design/BRAINSTORM.md` ("Diretor à Left 4
Dead"). Não há cena visual: é uma simulação numérica de uma run de 25 minutos.

## Como correr

```bash
godot --headless --path . --import
godot --headless --path . --script res://spikes/director/run_simulation.gd      # CSV + tabelas
godot --headless --path . --script res://spikes/director/tests/test_director.gd # testes
```

Os CSV ficam em `spikes/director/output/<diretor>_<perfil>.csv` com as colunas
`time,intensity,phase,active,budget,spawns,near,hp,deaths,events`
(um registo a cada 0,5 s → 3000 linhas). Abrem diretamente no Excel/LibreOffice
para fazer gráficos.

## Ficheiros

| Ficheiro | O quê |
|---|---|
| `horde_director.gd` | diretor novo (intensidade, fases, orçamento, composição, eventos) |
| `legacy_director.gd` | diretor original (nível por tempo, teto 90) |
| `sim_player.gd` | jogador simulado (DPS, mitigação, vida, regeneração) |
| `enemy_types.gd` | estatísticas abstratas dos inimigos (HP do GDD original) |
| `director_sim.gd` | ciclo da simulação (passo de 0,5 s) e exportação CSV |
| `run_simulation.gd` | corre 2 diretores × 3 perfis, escreve CSV e imprime resumos |
| `tests/test_director.gd` | testes headless |

## O modelo

### Mundo abstrato
Não há física nem mapa. Cada inimigo é `{tipo, hp, eta}`, em que `eta` são os
segundos até chegar ao jogador (nasce a ≥ 12 m: 4,5 s para Runner, 8 s Normal,
10 s Brute, 12 s The Breaker). Com `eta <= 0` está "perto" e causa dano por
segundo; com `eta <= 3` já pode ser alvejado.

### Jogador simulado
| Perfil | DPS | Mitigação (esquivas/kiting) |
|---|---|---|
| fraco | 260 | 0 % |
| médio | 380 | 30 % |
| forte | 540 | 55 % |

Dispara sempre no inimigo mais próximo; 100 HP; regenera 8 HP/s após 3 s sem
levar dano. Se morre, renasce de imediato (e a pressão local é limpa) para
que todas as runs durem os 25 minutos e sejam comparáveis; as mortes contam-se.

### Intensidade (0–100), como no L4D
Por passo:
- `+2,5` por cada HP perdido (o sinal mais forte: o jogador está a sofrer);
- `+0,12/s` por cada inimigo perto;
- `+0,02/s × segundos seguidos em combate` (tempo sem pausa);
- `−6/s` quando há menos de 3 inimigos perto e não houve dano.

### Fases
```
BUILD_UP --(intensidade >= 60  ou  90 s sem pico)--> PEAK
PEAK     --(3 s)-------------------------------------> RELAX
RELAX    --(intensidade <= 20 e >= 10 s, ou 35 s)----> BUILD_UP
```
- **Build-up**: spawns de 1,2/s (minuto 0) a 4,0/s (minuto 25), a crescer até
  ×2 dentro da própria fase (60 s para duplicar).
- **Peak**: mantém o ritmo durante 3 s e depois corta.
- **Relax**: quase sem spawns (0,15/s) e *culling* dos inimigos ainda a
  caminho (`eta > 3`), como o L4D faz a infetados fora de vista. Eventos
  especiais esperam pelo fim do alívio.
- O pico forçado aos 90 s garante que um jogador forte também tem ciclos, só
  que mais longos.

### Orçamento e composição
- Orçamento de inimigos ativos cresce linearmente de **80 (início) a 150 (fim)**;
  o diretor nunca pede mais do que `orçamento − ativos` (testado).
- Composição por tempo: Normal 75 % → 40 %, Runner 15 → 25 %, Spitter 7 → 18 %,
  Brute 3 → 17 %; no pico os Runners pesam ×1,5.
- Eventos: **rush** de 30 inimigos a cada 4 min (tipo Screamer) e **The
  Breaker** a cada 6 min 15 s. Aparecem na coluna `events`.

### Diretor original (comparação)
Segundo `docs/legacy/GDD.md`: nível dura 110 s no nível 1 e converge para 75 s
no nível 5; alvo de ativos `min(90, 20 + 8 × nível)`; ritmo `1 + 0,35 × nível`
spawns/s; tipos mais pesados com o nível; boss a cada 5 níveis; teto 90. Não
mede o jogador: a coluna `intensity` é calculada com a mesma fórmula só para
comparar.

## Resultados

Ambiente: sessão cloud headless, Godot 4.7 stable, seed fixa 7 (determinístico).
As 6 runs (18 000 passos) correm em ~1 s.

| director | profile | relax periods | relax s | calm s (0 near) | avg active | max active | avg intensity | deaths |
|---|---|---|---|---|---|---|---|---|
| l4d | weak | 31 | 523 | 1158 | 14.3 | 67 | 32.2 | 23 |
| l4d | medium | 24 | 416 | 1220 | 15.9 | 63 | 24.3 | 10 |
| l4d | strong | 17 | 259 | 1338 | 18.1 | 80 | 12.9 | 3 |
| legacy | weak | 0 | 0 | 1012 | 27.0 | 88 | 52.5 | 56 |
| legacy | medium | 0 | 0 | 1109 | 26.9 | 90 | 38.3 | 36 |
| legacy | strong | 0 | 0 | 1160 | 26.4 | 90 | 26.9 | 21 |

"calm s" = segundos com 0 inimigos perto. "relax periods" só existe no diretor novo.

### Leitura
- **Adaptação ao jogador funciona**: o fraco recebe 31 alívios (≈ 520 s), o
  forte 17 (≈ 260 s). O diretor original trata todos por igual.
- **Mortes caem para menos de metade** com o diretor novo (fraco 56 → 23,
  médio 36 → 10, forte 21 → 3). O original esmaga o fraco a partir do minuto 6
  (intensidade média ~70 até ao fim, sem pausa).
- **A intensidade média segue o perfil** em vez de subir sempre: fraco 32,
  forte 13. Para o forte isto é *demasiado* fácil (ver recomendações).
- **O orçamento 80–150 nunca chega a ser o limite**: a média de ativos fica em
  14–18 e o máximo em 63–80. Com estes DPS, o jogador mata mais depressa do que o
  diretor faz spawn. É o resultado mais importante do spike: o teto só é útil
  se o ritmo de spawn e o HP/DPS forem dimensionados para o atingir.

### Gráfico por minuto (perfil médio, diretor novo)
`#` = 10 inimigos ativos (média do minuto), `*` = 10 de intensidade; a fase
mostrada é a mais frequente no minuto (os ciclos são mais curtos do que 1 min,
por isso o alívio aparece pouco aqui; ver o zoom abaixo).

```
l4d / medium  (# = 10 active, * = 10 intensity; phase = most frequent)
 0 build_up  #               |             8/ 0
 1 build_up  #               |             8/ 0
 2 build_up  #               |            12/ 0
 3 build_up  #               |             9/ 0
 4 build_up  #               |***         13/32
 5 build_up  ##              |            18/ 0
 6 build_up  #               |            12/ 0
 7 build_up  ##              |*           20/15
 8 build_up  #               |***         12/34
 9 build_up  ##              |*           24/15
10 build_up  #               |**          11/18
11 build_up  ##              |***         18/26
12 build_up  ##              |**          21/25
13 build_up  ##              |***         15/32
14 build_up  #               |***         15/32
15 build_up  ##              |***         18/28
16 build_up  ##              |***         25/27
17 build_up  ##              |*****       19/46
18 relax     #               |****        15/43
19 build_up  #               |****        13/37
20 build_up  ###             |***         25/31
21 build_up  ##              |****        17/43
22 relax     #               |****        13/38
23 build_up  ##              |*****       21/47
24 relax     ##              |****        17/37

```

O diretor original, pelo contrário, é uma rampa monótona (perfil fraco):
intensidade 0 até ao min 5, depois ~70 sem descanso até ao min 25; ativos de
6 para 46. Corre `run_simulation.gd` para ver os seis gráficos.

### Zoom de um ciclo (fraco, 241–300 s)
`tempo intensidade fase ativos perto vida` — rush aos 240 s, pico, morte,
alívio com culling (ativos 38 → 0), regresso lento ao build-up:

```
241.5   0.0 build_up  51   0 100.0
243.5   0.0 build_up  51   0  99.7
245.5  20.2 build_up  49   5  90.0
247.5  45.0 build_up  51   6  74.7
249.5 100.0 peak      48  26  41.1
251.5 100.0 relax     38  30 100.0
253.5  91.0 relax      0   0 100.0
255.5  79.0 relax      0   0 100.0
257.5  67.0 relax      1   0 100.0
259.5  55.0 relax      1   0 100.0
261.5  43.0 relax      1   0 100.0
263.5  31.0 relax      2   0 100.0
265.5  19.0 build_up   2   0 100.0
267.5   7.0 build_up   5   0 100.0
269.5   0.0 build_up   7   0 100.0
271.5   0.0 build_up   8   0 100.0
273.5   0.0 build_up  10   0 100.0
275.5   0.0 build_up  11   0 100.0
277.5   0.0 build_up  13   0 100.0
279.5   0.0 build_up  14   0 100.0
```

## Testes (`tests/test_director.gd`)
1. As fases alternam sempre na ordem build_up → peak → relax → build_up, com
   ≥ 5 alívios por run, nos três perfis.
2. `ativos <= orçamento` em todos os passos e orçamento dentro de 80–150.
3. O perfil fraco tem mais períodos de alívio do que o forte (31 > 17).
4. O diretor original nunca passa do teto 90.

## Limites da medição
- Modelo abstrato: sem geometria, sem pontos de spawn, sem fuga/kiting real,
  sem área de efeito das armas (o DPS é "single target" efetivo). Os números
  absolutos (mortes, ativos) **não** são previsões do jogo; as comparações
  entre diretores e perfis é que contam.
- A "skill" é só DPS + mitigação fixos; um jogador real melhora durante a run
  (cartas, evoluções), o que favorece ainda mais o diretor adaptativo.
- Uma só seed; os resultados qualitativos mantiveram-se ao afinar parâmetros,
  mas não foi feita varredura de seeds.
- O culling no alívio é uma escolha do spike e não foi medido isoladamente
  (`cull_far_on_relax = false` para comparar).

## Recomendações de parâmetros
1. **Usar o diretor por intensidade** (BUILD_UP/PEAK/RELAX); o original não
   distingue jogadores e não dá respiro.
2. **Dimensionar o spawn para o orçamento**: para chegar a 80–150 ativos no
   jogo real, o ritmo de build-up tem de ser ~3–5× maior (≈ 4/s → 15/s no fim)
   *ou* as armas têm de ser AoE/penetração (que é o pilar de combate) com
   inimigos mais frágeis individualmente. Medir no protótipo jogável, não aqui.
3. Começar com: `peak_threshold 60`, `intensity_from_damage 2,5`,
   `peak_hold 3 s`, `relax_min 10 s`, `relax_max 35 s`, `max_build_up 90 s`.
4. **Baixar `max_build_up` para ~60 s** se o forte parecer aborrecido: hoje
   tem intensidade média 13 e passa minutos sem estar sob pressão.
5. Manter o culling no início do alívio (só inimigos fora de alcance).
6. Eventos especiais nunca durante o alívio (já é assim).

## Decisões propostas
- D-?: o remake usa um diretor por intensidade com três fases, em vez de
  escalada por tempo. (Para o utilizador decidir; não editado em DECISIONS.md.)
- D-?: o orçamento de ativos é um teto de segurança (80 → 150); a dificuldade
  por tempo vem da composição e do ritmo, não só da quantidade.
