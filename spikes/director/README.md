# Spike: diretor de horda (à Left 4 Dead)

Pergunta: um diretor que mede a **intensidade** e alterna **build-up → pico →
alívio** dá um ritmo melhor do que o diretor original (escalada só por tempo)?
Pilar servido: combate de horda legível com ritmo (BRAINSTORM §3, "Diretor à
Left 4 Dead").

Spike **totalmente headless**: não há cena, nem física, nem navegação. É um
modelo numérico para escolher a forma do diretor e os parâmetros iniciais; os
números finais terão de ser medidos no jogo real.

## Como correr

```bash
godot --headless --path . --script res://spikes/director/run_sim.gd           # gera CSVs + gráficos ASCII
godot --headless --path . --script res://spikes/director/tests/test_director.gd
```

CSVs em `spikes/director/output/<diretor>_<perfil>.csv`, uma linha por
segundo: `time, intensity, phase, active, near, budget, spawns, hp, kills,
deaths, event`. Abrem no Excel/LibreOffice para gráficos a sério.

## Ficheiros

| Ficheiro | Papel |
|---|---|
| `horde_director.gd` | diretor novo (intensidade, fases, orçamento, eventos) |
| `legacy_director.gd` | diretor original do GDD legado, para comparação |
| `enemy_types.gd` | tabela de inimigos (HP, dano, pesos por progresso) |
| `sim_player.gd` | jogador simulado + multidão de inimigos |
| `director_sim.gd` | corre uma run de 25 min (passo 0,25 s) e exporta CSV |
| `run_sim.gd` | 2 diretores × 3 perfis, resumo e gráficos ASCII |
| `tests/test_director.gd` | testes headless |

## Modelo

### Jogador simulado (`sim_player.gd`)

- Inimigos nascem longe ("approaching") e chegam ao jogador em ~8 s em média
  (probabilidade `dt/8` por inimigo por passo) — passam a "near".
- O jogador causa `220 × skill × (1 + 2 × progresso)` de dano/s (o fator de
  progresso imita upgrades de armas). Mata primeiro os "near", por prioridade:
  especiais perigosos (Screamer, Grabber), depois Runner, … , Armored, boss.
- Recebe dano de no máximo 8 inimigos ao mesmo tempo (anel corpo-a-corpo),
  `dps_do_tipo × 0,35 / skill`. Regenera 2 HP/s quando ninguém está perto.
- A 0 HP conta uma morte, volta a 100 HP e a multidão próxima é empurrada.
  (Não termina a run: queremos medir 25 min completos.)
- Perfis: **fraco** `skill = 0,6`, **médio** `1,0`, **forte** `1,5`.

### Diretor novo (`horde_director.gd`)

**Intensidade (0–100)**, atualizada a cada passo:

```
+ 0,8 × HP perdido
+ 0,15 × inimigos em contacto × dt
+ 0,12 × dt                       (fora de RELAX: "tempo sem pausa")
- 3,0 × dt                        (em RELAX)
- 1,5 × dt                        (fora de RELAX, sem dano e ninguém perto)
```

**Fases:**

| Fase | Spawns | Sai quando |
|---|---|---|
| BUILD_UP | sobe de 50 % para 100 % do orçamento em 60 s, 3 → 12 inimigos/s | intensidade ≥ 70 **ou** 100 s em build-up → PEAK |
| PEAK | até 100 % do orçamento; entrada dispara eventos | 20 s → RELAX |
| RELAX | nenhum | (intensidade ≤ 30 **e** ≥ 15 s) **ou** 45 s → BUILD_UP |

**Orçamento**: `lerp(80, 150, progresso)` inimigos ativos. É um teto duro:
o diretor nunca pede mais do que `orçamento - ativos` (há um `assert` e um
teste por passo).

**Ritmo adaptativo** (acrescentado depois da primeira medição, ver abaixo):
o diretor mede a taxa de abates do jogador (média móvel de 10 s, inferida de
`ativos_antes + spawns - ativos_agora`) e limita o ritmo de spawn a
`1,2 ×` essa taxa em build-up e `1,6 ×` em pico (mínimo 1/s).

**Composição**: cada spawn sorteia um tipo por pesos que interpolam do início
para o fim da run (`enemy_types.gd`): Normal começa a 85 % e desce para ~45 %;
Runner/Spitter/Brute crescem; especiais entram por progresso (Screamer 15 %,
Grabber 25 %, Bloater 30 %, Armored 40 %).

**Eventos especiais** (coluna `event` no CSV), na entrada de cada PEAK:
- `boss`: a cada 5 min fica um boss pendente; entra no pico seguinte (clímax
  coincide com o pico, nunca com o alívio);
- `horde_call`: rajada de 25 inimigos (o "grito do Screamer"), cortada pelo
  orçamento restante.

### Diretor original (`legacy_director.gd`)

Do `docs/legacy/GDD.md`: nível 1 dura 110 s, converge linearmente para 75 s no
nível 5; alvo de ativos `min(90, 20 + 12 × nível)`; ritmo `1 + 0,5 × nível`/s;
tipos pesados mais prováveis por nível; boss a cada 5 níveis; teto 90. Sem
intensidade nem alívio. (Fila de 12 e 2 instâncias por frame não são
modeladas: são detalhes de implementação, não de ritmo.)

## Resultados

Ambiente: sessão cloud, Godot 4.7 headless, Intel Xeon 2,8 GHz, 4 cores.
Cada run de 25 min simulados (6000 passos) demora **~110–160 ms**. Seed fixa
(7): os números são reproduzíveis, mas são **uma** amostra.

### Resumo

| diretor | perfil | intens. média | nº relax | s relax | s pico | s calma¹ | dano | mortes | abates | máx. ativos |
|---|---|---|---|---|---|---|---|---|---|---|
| novo | fraco | 47,5 | 12 | 494 | 240 | 771 | 3459 | 30 | 2560 | 69 |
| novo | médio | 30,3 | 9 | 378 | 180 | 1004 | 1604 | 12 | 3645 | 95 |
| novo | forte | 22,7 | 10 | 300 | 200 | 969 | 1147 | 7 | 5851 | 127 |
| original | fraco | — | 0 | 0 | 0 | 164 | 11410 | 112 | 2799 | 90 |
| original | médio | — | 0 | 0 | 0 | 378 | 5594 | 55 | 4277 | 90 |
| original | forte | — | 0 | 0 | 0 | 621 | 2606 | 25 | 5769 | 90 |

¹ segundos sem nenhum inimigo em contacto — medida de alívio comum aos dois
diretores.

### Gráficos ASCII (1 carácter = 30 s; 50 colunas = 25 min)

Escala ` .:-=+*#%@` (vazio → máximo). Fase: **B**uild-up, **P**eak, **R**elax;
no original, o dígito é o nível (mod 10). `active` sobre 150, `near` sobre 30.

```
== novo ==
weak   phase     |BBPRBBBPRRBBBPRPRBBBPRRRBBBBRRBBBPRPRBBBBRRPBBBBRR|
weak   intensity | :@@=.:#@#: .@@@#.  -@%@:   %*.  *@@%:  .@@%:   @#|
weak   active    | .-.   ::    - .    ::     .:    :..    .-     .: |
weak   near      | .%-   -*    +..    :=      +    =:.     -      = |
weak   hp        |@#=*@@%+=%@@%+***@@@#+**@@@@+@@@@**+*@@@%++#@@@@+*|
medium phase     |BBBPRBBBPRRBBBPRBBBPRBBBBRRBBBPRBBBBRBBBBRRBBBPRBB|
medium intensity |  :@@=  :@+   =+   =@:   @#.  +@:   #:  .@*   =%: |
medium active    | ..=.   ::    -    -    .:    -    .:   :-    -   |
medium near      |  :@=   :=    *    +     -    -.    :   .+    -.  |
medium hp        |@@#=:+@@#=-%@@+@@@@++%@@@+#@@@**@@@@*@@@@=@@@@**@@|
strong phase     |BBBPRBBBBRBBBPRRBBBPBBBPRRBBBPBBBPRRBBBPBBBBRRBBBP|
strong intensity |   *%:   +.  =@-   :. .#@=       *@=   :.  .%=   .|
strong active    |  .=.   .:  .=:    -  :+-    -  :+-    -   -=    -|
strong near      |   @+   .=   ++    -   %*        =*    :   .+    .|
strong hp        |@@@++@@@@=+@@*+@@@@#*@@=+@@@@%@@@++@@@@#*@@%+%@@@%|

== original ==
weak   phase     |11112223334445566677888990001122233444556667788899|
weak   active    |     ..:--===+++++++++++++++++++++++++++++++++++++|
weak   near      |     .-=####%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|
weak   hp        |@@@@@#*+++++=++++++++++++++++=+++=+=+=+++=+++=++++|
medium near      |              .-=*#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|
medium hp        |@@@@@@@@@@@@@#=++++=+++++=+=+=+=++==+=++=+==+==+-*|
strong near      |                     .:+%@@@@@@@@@@@@@@@@@@@@@@@@@|
strong hp        |@@@@@@@@@@@@@@@@@@@@@%=++==++++++==++++++=+=+===++|
```

### Leitura

1. **O original não tem ritmo, tem um planalto.** Depois do teto (90) chegar
   (~6 min no fraco, ~10 min no forte), `near` fica no máximo até ao fim e o
   HP oscila sempre em "+": o jogador vive a meio da barra, a morrer em ciclo.
   Para o fraco: 112 mortes em 25 min. A dificuldade só é diferente no
   *momento* em que se chega ao planalto.
2. **O novo respira.** Em todos os perfis vê-se o padrão onda → pico → vazio
   (`near` e `intensity` com buracos), o HP recupera até `@` em cada alívio.
   Mortes caem ~3–4× face ao original no mesmo perfil.
3. **O fraco recebe mais alívio** (12 relax / 494 s contra 10 / 300 s do
   forte): chega a 70 de intensidade mais cedo, logo tem picos mais
   frequentes e alívios mais longos (sai pelos 45 s em vez de pelos 15 s).
4. **O forte é desafiado pela quantidade**: só ele se aproxima do orçamento
   (máx. 127 ativos). Como raramente chega a 70, os picos dele são quase todos
   forçados pelos 100 s de build-up.

### O que a primeira versão ensinou

Sem o ritmo adaptativo (spawns só por tabela de fases), o fraco ficava com
intensidade 100 a run inteira (≈ 110 mortes, igual ao original) e o forte
nunca enchia o orçamento: matava mais depressa do que o diretor gerava. Um
ritmo fixo não serve perfis tão diferentes; amarrar o ritmo à taxa de abates
medida resolveu os dois extremos com um só mecanismo.

## Limites da medição

- Sem espaço: "perto" é um atraso aleatório, não distância nem navegação. Os
  ≥ 12 m de spawn, pontos de spawn e obstáculos não existem aqui.
- O jogador é uma fórmula: não foge, não escolhe alvos, não usa
  habilidades. Os perfis diferem só num multiplicador.
- Uma seed. Mudar a seed muda contagens de ±1–2 relax; as tendências mantêm-se
  (verificar antes de fixar valores finais).
- Os 80–150 do orçamento são um **teto**: com o ritmo adaptativo, perfis fraco
  e médio raramente o atingem. Isto é intencional, mas significa que o alvo
  "80–150 ativos" só se cumpre para jogadores fortes neste modelo.

## Recomendações de parâmetros (ponto de partida para o jogo)

| Parâmetro | Valor | Porquê |
|---|---|---|
| orçamento | 80 → 150 por progresso, teto duro | cabe no alvo; o diretor nunca o excede |
| limiar de pico | 70 | fraco chega lá em ~30–60 s, médio em ~60–90 s |
| build-up máximo | 90–100 s | garante picos ao forte (senão nunca relaxa nem sente clímax) |
| duração do pico | 15–20 s | curto o suficiente para o fraco sobreviver |
| relax mín./máx. | 15 s / 45 s | 45 s dá tempo de regenerar ~90 HP |
| saída de relax | intensidade ≤ 30 | |
| ritmo adaptativo | 1,2× abates (build) / 1,6× (pico) | é o que separa fraco de forte; **manter** |
| `horde_call` | 25, cortado pelo orçamento | |
| boss | pendente a cada 5 min, entra no pico seguinte | clímax alinhado com o pico |

## Decisões propostas

1. Adotar o diretor por intensidade com 3 fases em vez da escalada só por
   tempo do jogo original.
2. Ritmo de spawn limitado pela taxa de abates medida (diretor adaptativo).
3. O orçamento de ativos é um teto, não um alvo a preencher sempre.
4. Eventos especiais (boss, horda chamada) só na entrada de um pico.

Próximo passo sugerido: ligar este diretor a uma arena com física/navegação
real e medir `near`, dano e mortes com jogo humano nos três níveis de skill.
