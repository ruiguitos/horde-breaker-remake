# Spike: horde_flowfield

Pergunta: **quantos inimigos ativos aguenta uma horda "como dados" em GDScript
puro**, com flow field, separação, colisão com paredes e hitscan, sem nós nem
physics bodies? (BRAINSTORM §8 — alvo de design ~80–150 ativos.)

## Como correr

```bash
godot --headless --path . --import
godot --headless --path . --script res://spikes/horde_flowfield/tests/test_horde.gd
godot --headless --path . --script res://spikes/horde_flowfield/tests/bench_horde.gd
```

No editor (Windows): abrir `spikes/horde_flowfield/horde_demo.tscn` e F6.
WASD/setas movem o jogador (caixa vermelha), clique esquerdo dispara um
hitscan do jogador para o rato (o agente atingido reaparece na borda). O canto
superior mostra ms de simulação e FPS. `agent_count` é exportado no nó raiz.

## Ficheiros

| Ficheiro | O quê |
|---|---|
| `flow_field.gd` (`HordeFlowField`) | Grelha 1 m, BFS a partir da célula do jogador, direção por célula (8 vizinhos, sem cortar cantos). Rebuild síncrono ou numa thread do `WorkerThreadPool` com double buffer (`request_target` + `poll`). |
| `horde_sim.gd` (`HordeSim`) | Agentes em `PackedVector3Array`/`PackedFloat32Array`. Spatial hash (listas ligadas por célula, O(N)), separação 3×3, movimento por eixo contra células bloqueadas, `hitscan()`. |
| `horde_maps.gd` (`HordeMaps`) | Arena 150×150 m determinística (muros com aberturas + ~200 caixas) e spawn em anel. |
| `horde_demo.gd/.tscn` | Render com `MultiMeshInstance3D` (cápsulas para agentes, caixas para paredes). |
| `tests/test_horde.gd` | Contornar obstáculo e chegar; nenhum agente em parede (mapa pequeno e arena com 1000 agentes); rebuild em thread == síncrono; hitscan devolve o mais próximo, respeita distância, paredes bloqueiam; a cena demo arranca. |
| `tests/bench_horde.gd` | Tabela de tempos (ver abaixo). |

## Porquê estas escolhas

- **Flow field em vez de pathfinding por agente**: um BFS serve todos os
  agentes; cada agente só lê a seta da sua célula (custo O(1)).
- **Dados em arrays, não nós**: 1000 `CharacterBody3D` custariam física e
  árvore de cena; aqui um agente são 3 valores num array.
- **Spatial hash com listas ligadas**: a primeira versão (counting sort sobre as
  22 500 células) custava ~3 ms fixos mesmo com 100 agentes; limpar só as
  células usadas baixou 100 agentes para ~0,5 ms.
- **Paredes sem física**: o movimento é feito eixo a eixo e o "bordo" do
  agente (centro + raio, raio < célula) tem de ficar numa célula livre, logo o
  centro nunca entra numa parede. Os agentes deslizam ao longo das paredes.
- **Rebuild fora do frame**: o BFS em GDScript demora ~50 ms (ver abaixo), por
  isso corre numa thread; o frame só paga a troca de buffers (~1 ms).

## Resultados medidos

Ambiente: sessão cloud, **Intel Xeon @ 2.80 GHz, 4 threads**, Godot
4.7-stable, `--headless`, **sem GPU** (renderer dummy). Só mede CPU da
simulação. Arena 150×150, agentes a 20–70 m do alvo, velocidades 2,5–5 m/s,
dt = 1/60, 30 ticks de aquecimento + 300 medidos. Três corridas (os números
variam ~±30 % entre corridas: CPU partilhado da cloud).

### Simulação por tick (ms) — corrida 3 (as outras duas na mesma ordem de grandeza)

| agentes | média | p95 | p99 | máx | % de 16,7 ms (média) |
|-------:|------:|----:|----:|----:|---:|
| 100 | 0,45 | 0,63 | 0,77 | 1,00 | 2,7 % |
| 150 | 0,99 | 1,21 | 1,25 | 1,33 | 6,0 % |
| 300 | 1,42 | 2,39 | 2,49 | 5,13 | 8,5 % |
| 500 | 2,33 | 3,36 | 3,95 | 4,36 | 14,0 % |
| 1000 | 5,69 | 8,91 | 9,62 | 12,4 | 34,1 % |
| 2000 | 12,7 | 18,4 | 20,3 | 21,1 | 76,4 % |

Intervalo das três corridas (média): 150 → 0,96–1,15 ms; 500 → 2,3–3,4 ms;
1000 → 5,7–6,3 ms; 2000 → 12,7–16,9 ms (p95 até 32 ms).

O custo cresce mais que linearmente: quando a horda se junta à volta do alvo,
cada célula do hash tem mais vizinhos para a separação.

### Flow field 150×150 (40 alvos aleatórios)

| rebuild | média | p95 | máx |
|---|---:|---:|---:|
| síncrono (bloqueia o frame) | 42–57 ms | 66–73 ms | 69–81 ms |
| em thread: latência até à troca | 50–57 ms | 70–75 ms | 72–86 ms |
| em thread: custo no thread principal | 0,8–0,9 ms | 1,2–1,4 ms | 1,4–1,8 ms |

Ou seja: com a thread, o campo chega ~3–4 frames depois de o jogador mudar de
célula; os agentes seguem o campo antigo entretanto (aceitável a 1 m/célula).

### Hitscan

500 agentes, raios de 60 m: **~0,11 ms por raio**. Uma arma automática
(10–20 raios/s) é irrelevante; uma caçadeira com 10 bagos num frame ≈ 1 ms.

## Conclusão

Para o alvo de design (~80–150 ativos) a simulação custa **~1 ms/tick** neste
CPU — folga de sobra. **500 ativos** cabem num frame de 60 FPS (~2–3 ms) e
1000 é possível (~6 ms, p95 ~9–11 ms) mas já come um terço do frame.
2000 não cabe em GDScript.

Número proposto: **orçamento de 300 agentes simulados** (≈2 ms p95 aqui),
dos quais ~150 "ativos" a perseguir; margem para picos e para o resto do jogo.

## Limites da medição / o que fica por medir no PC do utilizador

- **Render e GPU não medidos** (cloud sem GPU). Medir na RX 590 com a cena
  demo: FPS com 150/300/500/1000 cápsulas em `MultiMesh`, custo de
  `set_instance_transform` por agente (é GDScript, por frame) — alternativa:
  escrever o `PackedFloat32Array` inteiro com `MultiMesh.buffer`.
- CPU do utilizador (provavelmente mais rápido que este Xeon partilhado).
- Sem animação (VAT), sem IA de ataque, sem morte/pooling, sem LOD.
- O BFS é sempre completo; não há rebuild incremental "verdadeiro"
  (só reaproveita a thread e descarta pedidos intermédios). Se 50 ms de
  latência incomodar: BFS limitado a um raio, grelha de 2 m, ou portar o
  BFS para C++/GDExtension.
- Direções a 8 vizinhos calculadas sobre distâncias de 4
  vizinhos dá caminhos a 45°/90°, não perfeitamente retos.

## Decisões propostas

1. Adotar flow field + agentes como dados + spatial hash para a horda.
2. Orçamento inicial: 300 agentes simulados, ~150 ativos.
3. Rebuild do flow field sempre em thread; nunca síncrono no frame.
4. Antes de fechar o número, medir o render da cena demo no PC (RX 590).
