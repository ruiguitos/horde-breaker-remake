# Spike: camera_medium

Objetivo: responder às perguntas da secção 7 do `docs/design/BRAINSTORM.md`
(câmara média — decisão de 2026-10-05 em `docs/DECISIONS.md`): que preset
usar, yaw com rato ou fixo, como mirar, e quanta horda fica fora do ecrã.

## Ficheiros

| Ficheiro | O quê |
|---|---|
| `camera_medium.tscn` | Cena: chão 120×120 m, luz, jogador cápsula, rig de câmara, overlay. |
| `camera_medium.gd` | Constrói os 10 obstáculos e os 40 zombies em `_ready()` (layout fixo, seed fixa), movimento, mira, oclusão, overlay. |
| `camera_rig.gd` | `CameraMediumRig`: presets, transição suave, yaw. Todos os parâmetros são `@export`. |
| `tests/test_camera_medium.gd` | Testes headless. |

Os obstáculos e zombies são criados por código (e não na `.tscn`) para o
layout ser fácil de ler e de alterar numa lista. Por isso, no editor, só os
vê ao correr a cena.

## Como testar no editor (Windows)

1. Abrir o projeto no Godot 4.7, abrir `spikes/camera_medium/camera_medium.tscn`.
2. **F6** (correr a cena atual).
3. Controlos:
   - **WASD** / analógico esquerdo — mover (relativo à câmara).
   - **1 / 2 / 3** — preset ombro afastado / média / alta leve.
   - **Botão direito + rato** ou **analógico direito** — rodar a câmara (yaw).
   - **T** — alternar entre "rato roda sempre" e "só com botão direito"
     (também em `mouse_yaw_always` no nó `CameraRig`).
   - **Rato** — move a retícula `+`; a linha vermelha vai do jogador ao ponto
     onde o raio da retícula cruza o plano horizontal a 1 m acima dos pés.
   - **R** — voltar a espalhar a horda.
4. Para afinar valores: selecionar `CameraRig` no inspetor (grupo *Presets*,
   índices 0/1/2) e `CameraMedium` (velocidades, nº de zombies, alpha da oclusão).

| Preset | Inclinação | Distância | Offset | FOV |
|---|---|---|---|---|
| 1 Ombro afastado | 25° | 7 m | 0,8 m | 65° |
| 2 **Média** (inicial) | 35° | 10 m | 0,4 m | 60° |
| 3 Alta leve | 45° | 13 m | 0 m | 55° |

## O que observar

- **Em cada preset:** o contador "zombies in frustum" no overlay. Ficar parado
  e deixar a horda aproximar-se: quantos dos 40 continuam fora do ecrã (atrás)?
  É o número que diz que pistas (som, setas na borda) vão ser precisas.
- **Preset 1:** imersão e "parede de zombies" no horizonte; o offset tapa
  menos o centro; mas a horda atrás é invisível.
- **Preset 2:** equilíbrio — verificar se se vê o suficiente em volta sem
  rodar a câmara.
- **Preset 3:** quase 360° útil; perde-se horizonte.
- **Transição** 1↔3: deve ser suave (~0,5 s), sem saltos nem enjoo.
- **Yaw:** comparar "só botão direito" com "sempre" (T). Com "sempre" a
  retícula e a câmara mexem-se ao mesmo tempo — vale a pena sentir se isso
  incomoda.
- **Mira:** com a câmara mais baixa (preset 1), a retícula perto do horizonte
  aponta muito longe; ver se mirar no plano do jogador é natural ou se mirar
  "ao inimigo" (raycast aos corpos) seria melhor.
- **Oclusão:** passar por trás da torre alta em (-30, -25) ou da "casa" em
  (-20, 20): o bloco entre a câmara e o jogador fica semitransparente.
  Note-se que os muros baixos (≤ 4 m) quase nunca tapam o jogador nos
  presets 2 e 3 — a câmara já passa por cima.

## Testes headless

```bash
godot --headless --path . --import
godot --headless --path . --script res://spikes/camera_medium/tests/test_camera_medium.gd
```

Cobrem (19 verificações): a cena carrega (40 zombies, 10 obstáculos); cada
preset aplica pitch/distância/offset/FOV e a geometria resultante da câmara
bate certo; a transição é gradual e converge; a contagem no frustum (10 à
frente, 15 atrás → 10; rodar 180° → 15); o raio de mira acerta no plano e
reprojeta no mesmo píxel, e devolve `null` acima do horizonte; a oclusão
esbate a torre quando está entre câmara e jogador e não esbate nada com linha
de visão livre.

## Limites desta medição

- **Sem verificação visual:** feito numa sessão cloud (Linux, sem GPU, só
  `--headless`, Godot 4.7.stable). Não vi a cena renderizada; o aspeto, o
  conforto da transição e a legibilidade têm de ser avaliados no editor.
- O viewport headless é 64×64 (quadrado); os números do frustum nos testes
  não representam o ecrã 16:9 real. No editor o overlay dá o número real.
- A contagem usa só o centro de cada zombie e ignora oclusão.
- A oclusão usa dois raios (pés e cabeça) e só esbate o material inteiro do
  bloco; um jogo real precisaria de shader de recorte (BRAINSTORM §7).
- Zombies andam em linha reta e atravessam obstáculos (sem navegação, de propósito).
- Mira por comando (analógico) não implementada: a retícula segue o rato.
- Os teclados são lidos diretamente (sem Input Map), para não editar o
  `project.godot` fora do âmbito do spike.

## Decisões propostas

- Começar com o preset **Média** como predefinição, e decidir depois de
  jogar se o preset 1 fica como opção "imersiva".
- Yaw **só com botão direito** como predefinição até o teste mostrar o contrário.
