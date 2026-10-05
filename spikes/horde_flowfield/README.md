# Spike: horda com flow field

Pergunta: **quantos inimigos ativos aguenta o Godot 4.7 em GDScript puro**, com
a arquitetura do BRAINSTORM §8 (flow field por ilha, zombies como dados +
spatial hash, render com MultiMesh, hitscan contra o spatial hash)?

Alvo de design: ~80–150 inimigos ativos.

## Resposta curta

Na CPU da cloud, a simulação de **150 agentes custa ~1,2–1,5 ms por tick** (interpolado entre 100 e 300)
(60 Hz), ou seja, <10 % de um frame de 16,6 ms. O alvo de 80–150 cabe com
folga. O limite prático em GDScript, com um orçamento de ~4 ms de CPU para a
horda, anda pelos **300–500 agentes**. A partir de ~1000 o p99 passa os 13 ms
e deixa de caber num frame com o resto do jogo.

**Proposta de número final:** desenhar para **150 ativos** (orçamento
da horda ≤ 2 ms) e travar o spawner nos **300**. Acima disso só com GDExtension
(C++) ou threads, e só se o design o pedir. Ver "Decisões propostas".

## Como funciona

| Ficheiro | O que faz |
|---|---|
| `flow_field.gd` (`HordeFlowField`) | Grelha de células de 1 m. BFS de 4 vizinhos a partir da célula do jogador dá a distância de cada célula; a direção de cada célula (8 vizinhos, sem cortar esquinas) é calculada só quando um agente lá passa e fica em cache. |
| `horde_sim.gd` (`HordeSim`) | Agentes como dados: `PackedVector3Array` de posições/velocidades, `PackedFloat32Array` de velocidades máximas (2–5 m/s). Spatial hash por célula (listas ligadas em dois `PackedInt32Array`). Separação, colisão com paredes e hitscan. |
| `horde_map.gd` (`HordeMap`) | Mapa determinístico 150×150 com bordas e 70 obstáculos retangulares. |
| `horde_demo.tscn` / `.gd` | Demo visual: `MultiMeshInstance3D` de cápsulas (agentes) e de caixas (paredes). |
| `tests/test_horde.gd` | Testes headless. |
| `tests/bench_horde.gd` | Benchmark headless; imprime a tabela abaixo. |

Porquê estas escolhas:

- **Recalculo incremental, fora do frame.** Quando o jogador muda de célula
  começa um BFS novo num *buffer* de reserva; cada tick expande no máximo
  `field_budget` células (2000 ≈ 0,6–0,8 ms). Quando acaba, os buffers trocam.
  Os agentes continuam a seguir o campo antigo durante ~10 ticks (0,17 s),
  o que não se nota porque perto do jogador eles vão direto a ele. O recálculo
  completo de uma vez custa ~7 ms, o que daria um pico visível.
- **Agentes miram o centro da célula seguinte**, não a direção crua da grelha.
  Sem isto, um agente encostado a uma esquina ficava preso (o teste do
  obstáculo apanhou-o).
- **Paredes:** movimento separado por eixo (x, depois z) contra a grelha, com
  o quadrado do agente (raio 0,35 m) e passo máximo de meia célula por tick.
  Se um eixo bate, o agente desliza no outro. É exato: o teste com 500 agentes
  verifica todos os ticks que nenhum toca numa parede.
- **Spatial hash = a própria grelha.** `_head.fill(-1)` é nativo e rápido;
  inserir é O(1) por agente. A separação vê as 3×3 células à volta.
- **Hitscan** percorre as células do raio (Amanatides–Woo) e testa
  raio-vs-círculo nos agentes das 3×3 células à volta de cada uma; pára na
  primeira parede ou quando já passou o melhor acerto. Sem physics bodies.

## Números medidos

Ambiente: sessão na cloud, `Intel(R) Xeon(R) Processor @ 2.10GHz`, 4 threads,
Godot 4.7-stable oficial, `--headless` (sem GPU, sem render), GDScript
single-thread. Mapa 150×150 (19 209 células livres). 120 ticks de aquecimento
+ 600 medidos a 60 Hz; o jogador anda em círculo (força recálculos do campo
durante a medição, incluídos no tempo do tick). Duas corridas; valores da
segunda (a primeira deu números dentro de ±15 %).

Flow field:

| Medida | Valor |
|---|---|
| Recalculo completo (síncrono) | média 7,4 ms, p95 9,0 ms |
| Fatia de 2000 células por tick | média 0,75 ms, máx 2,2 ms |
| Ticks por recalculo fatiado | 10 |

Simulação por tick (flow field + separação + paredes + spatial hash):

| agentes | média ms | p95 ms | p99 ms | máx ms | 10 hitscans ms | encravados |
|-------:|------:|------:|------:|------:|------:|---:|
| 100 | 0,93 | 1,54 | 1,69 | 4,46 | 0,27 | 0 |
| 300 | 2,25 | 3,65 | 5,09 | 5,30 | 0,25 | 0 |
| 500 | 3,54 | 5,70 | 7,84 | 8,79 | 0,16 | 0 |
| 1000 | 6,57 | 9,57 | 13,06 | 15,29 | 0,14 | 0 |
| 2000 | 13,32 | 20,44 | 24,85 | 31,52 | 0,16 | 0 |

"Encravados" = agentes a mais de 25 células do jogador que se moveram menos
de 0,5 m em 5 s. O custo cresce linearmente com o número de agentes
(~6,5 µs por agente por tick). Um hitscan custa ~15–30 µs.

Limites da medição:

- CPU de servidor partilhada a 2,1 GHz; um desktop moderno deve ser mais
  rápido por núcleo, mas **não medi**. Os números servem para comparar
  tamanhos de horda, não como valor absoluto do PC do utilizador.
- `max` é sensível a ruído da máquina virtual (outros processos).
- Sem render: o custo de escrever as transforms do MultiMesh (`_process` da
  demo, ~N chamadas `set_instance_transform`) e o custo de GPU **não estão
  incluídos**.

## O que fica por medir no PC do utilizador

1. Correr o benchmark no Windows para ter os números da CPU real:
   `godot --headless --path . --script res://spikes/horde_flowfield/tests/bench_horde.gd`
2. Abrir `spikes/horde_flowfield/horde_demo.tscn` no editor e correr com F6.
   WASD move, clique dispara, `+`/`-` adicionam/removem 100 agentes. O canto
   mostra FPS e o tempo da simulação. Ver na RX 590:
   - FPS com 150, 300, 500 e 1000 agentes;
   - custo do `_process` (atualizar o MultiMesh) no Profiler do Godot;
   - se a horda parece natural (filas, contornar obstáculos, empurrões).
   Não vi a demo a correr com imagem; só confirmei que carrega e corre 300
   frames em headless sem erros.

## Testes

```bash
godot --headless --path . --import
godot --headless --path . --script res://spikes/horde_flowfield/tests/test_horde.gd
godot --headless --path . --script res://spikes/horde_flowfield/tests/bench_horde.gd
```

`test_horde.gd` verifica:

- o BFS fatiado dá exatamente o mesmo campo que o completo;
- 20 agentes contornam uma parede de 25 m pela única abertura e chegam ao
  alvo (~14 s);
- 500 agentes durante 900 ticks com alvo em movimento: nenhum toca numa parede;
- hitscan devolve o agente mais próximo na linha, respeita distância máxima,
  é bloqueado por paredes, e coincide com força bruta em 500 raios aleatórios.

## Decisões propostas

(Para o utilizador decidir; não estão em `docs/DECISIONS.md`.)

1. **Orçamento da horda: 150 inimigos ativos, ≤ 2 ms de CPU por tick**, com
   teto duro de 300 no spawner. Confirmar com o benchmark no PC.
2. **Flow field com recalculo fatiado** (2000 células/tick), não síncrono.
3. **GDScript chega para o alvo**; GDExtension/threads só se o design subir
   para centenas de inimigos ativos.

Nota: o pedido referia a secção 10 do BRAINSTORM, mas o documento só tem
secções 0–9; usei a §8 (Tecnologia).
