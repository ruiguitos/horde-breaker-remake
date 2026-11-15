---
titulo: "docs/history/beach_pilot_20261114/CLAUDE_REVIEW.md"
tipo: "referencia"
estado: "relatorio_historico"
atualizado: "2026-11-15"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/history/beach_pilot_20261114/CLAUDE_REVIEW.md"]
---

# docs/history/beach_pilot_20261114/CLAUDE_REVIEW.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original. Arquivo: não usar como lista de trabalho atual.

Fonte: `docs/history/beach_pilot_20261114/CLAUDE_REVIEW.md` · SHA-256: `05a5050a72c891daadf8c28e0aab760a9d107695eed8abf8b9e65d6f4afe5798`

# Revisão do piloto beach_01: dressing, writer e teste

Revisão só de leitura. Não corri o Godot, por isso as alturas e a visibilidade das rochas são inferidas dos transforms e ainda têm de ser confirmadas no editor. O hash da navegação está bem guardado. Os problemas reais estão nas rochas de substituição, na repetição das passagens e nas falhas que passam em silêncio.

## 1. ALTO: rochas trocadas por "pedrinhas" que bloqueiam como paredes invisíveis
`beach_dressing.gd:_rocks` (linhas 142–155) e `_blocked_box` (158–163).

- **Evidência:**
  - `Rock_03` tem escala 0.64 e fica a y 0.581 (`beach_01.tscn:767`). A `Surface_Rock_03` tem escala **0.177**, cerca de 0.23×0.18×0.32 m, a **y 0.378**. O topo fica a ~0.556, abaixo da base da original: provavelmente está **enterrada**.
  - `Rock_02`, `Rock_08` e `Rock_10` ficaram a ~0.25–0.28.
  - A rocha original, invisível, continua a bloquear as células e a encurtar a câmara com a sua caixa inteira (`object_boxes` e `island.gd:2374`).
- **Causas:**
  - A altura vem de `bounds.position.y`, a base do AABB, que já está enterrada.
  - A escala encolhe em `0.85^n` até a caixa caber em células inteiras (`floor`/`ceil`). Esse critério é mais estrito do que o do bloqueio, que usa centros de célula e margem de 0.25 (`_rect_of`, `_block_shape`).
- **Correção:**
  - Assentar a rocha em `map.ground_y`, usando o mínimo da pegada.
  - Validar com o mesmo critério de centros de célula.
  - Aceitar a troca só se a escala final for ≥ ~0.75× a inicial e se a pegada visível cobrir uma fração mínima das células bloqueadas. Caso contrário, manter a original visível.

## 2. ALTO: repetir a passagem pode deixar rochas invisíveis sem substituta
- `_rocks` nunca repõe `original.visible = true` antes de tentar a troca.
- O writer só acrescenta `visible = false` e nunca o retira (`apply_beach_dressing.gd:61-62`).
- Se uma segunda corrida falhar a troca (`rock.free()`, linha 155), a rocha fica escondida, sem `Surface_` e a bloquear.
- **Correção:** repor a visibilidade no início de `_rocks`. O writer deve escrever o estado real (remover ou acrescentar).

## 3. MÉDIO: a textura de falésia não segue a regra de jogo
`_ground`, linhas 227 e 235.

- O declive usa só os vizinhos −x/−z do píxel do vértice, com limiar 0.7.
- O `build_map` usa alturas no centro da célula, 4 vizinhos e `max_step` 0.9 (`handmade_island.gd:116-130`).
- Resultado: rocha pintada em rampas caminháveis de 0.7–0.9, e areia em falésias viradas a +x/+z (bloqueiam mas parecem transitáveis).
- **Correção:** derivar a classificação do próprio mapa, com a mesma regra e `island.max_step`.
- O índice `map.cover[z*width+x]` assume imagem de altura com a largura do mapa. Hoje bate certo (`region_size` 256, `build_islands.gd:98`), mas falta uma guarda.

## 4. MÉDIO: o writer pode aplicar materiais errados sem avisar
`apply_beach_dressing.gd`:

- **(a) Linha 35:** a idempotência verifica só se o `id` existe. Se a ordem de encontro mudar, um `beach_material_N` existente aponta para outro `.tres` e é reaproveitado (por exemplo, pedra trocada por reboco). Verificar o par id+path, ou derivar o id do nome do ficheiro.
- **(b) Linha 60:** o `material_rx.sub` não faz nada se o bloco não tiver `material_override` ou se o nó vier de uma subcena. Contar os nós esperados contra os substituídos e falhar se não baterem.
- **(c) Linhas 29–32:** repetem as linhas 23–27 sem a guarda de `null` nem de prefixo. Com um deck sem override há crash, e um deck com material embutido gera `path=""`. Remover.
- **(d)** Cada corrida insere `"\n"` extra. As linhas 18–19 e 24–25 da cena mostram que já correu pelo menos duas vezes.
- Os sub_resources dos materiais antigos ficam órfãos no ficheiro. É inofensivo; o editor limpa-os ao gravar.

## 5. MÉDIO: as falhas não fazem as ferramentas falhar
- Há `assert` com efeitos laterais em `beach_dressing.gd:30-31,49,64,214` e no writer, linha 21.
- Sem debugger, um assert falhado aborta a função. O writer nunca chega a `quit()` e a sessão pendura, contra a regra do projeto.
- Em `build_islands.gd:781`, `_failed` não é marcado e a cena é empacotada com o dressing a meio.
- Os asserts também desaparecem em builds de release.
- **Correção:** `apply()` devolve `Array[String]` de problemas, `build_islands` marca `_failed` e o writer faz `quit(1)`. O writer imprime "TEST:" sem ser um teste.

## 6. MÉDIO/BAIXO: adereços da costa a altura fixa
Linhas 181 e 185 usam `spec[3]`, independentemente do fundo.

- São aceites células com chão entre −1.5 e −0.15. As bases podem ficar ~1.2 m acima do fundo.
- A driftwood (−0.32), os postes (−0.4) e as árvores mortas (−0.35) ficam abaixo do mar animado, que está a −0.3 (`island.gd:350`). Podem desaparecer ou piscar com as ondas.
- `DeadTree_01` (108,152) e `DeadTree_02` (147,140.7) estão no rio junto à `Bridge_1`. O leito ronda −2 (marcador `Choke_Bridge`), por isso o tronco fica ~1.6 m acima do leito.
- **Correção:** usar `ground_y` mais um afundamento por peça.
- Para confirmar no editor: abrir `beach_01.tscn` com o mar animado e olhar à volta de (110,223) e do rio.

## 7. BAIXO: câmara
- `_building_boxes` só tem Buildings e Rocks (`island.gd:660`). O braço da 3.ª pessoa atravessa toldos (Hut_01, Hut_04), varanda, tabuleta, casco, postes e árvores mortas.
- O casco fica a (110,223) e os postes a (117,223) e (141,225). Estão perto do `PlayerStart` (128,210) e do `Boat` (128,217), que é onde a câmara olha para o mar.
- Sugestão: juntar as caixas de Shore e das peças salientes **só** à câmara, nunca à navegação.

## 8. BAIXO: partilha de recursos
- `_clone_geometry:122` duplica o `ArrayMesh` por cada peça colocada. As 3 árvores mortas têm `ArrayMesh_t07ke`, `55m3m` e `fpfdv` separados, o que explica o `.tscn` enorme. Usar uma cache por id.
- A malha e o material do boulder ficam embutidos (`ArrayMesh_m18mo`, `StandardMaterial3D` com `cull_mode = 2`, ou seja, dupla face). Correr de novo `prepare_beach_boulder.py` não se propaga sem novo bake. Referenciar o `.glb` como `ext_resource` resolveria.
- O atlas de texturas é partilhado de facto, mas o `ORMMaterial3D` é uma instância própria desta cena. É aceitável.

## 9. BAIXO: editor
- `apply()` reescreve sempre `beach_01_dressing.tscn`, os 5 `.tres` de materiais e `beach_01_ground.tres` (linhas 31, 48–49 e 213–214). Uma edição à mão perde-se no próximo `build_islands beach`, o que contradiz o comentário "ordinary, editable scene content". Documentar, ou exigir uma flag para sobrescrever.
- `_buildings` (81–98) assume fachadas viradas a +Z e caixas de 7×6 (torre 7×7). Hoje está correto: rotação identidade e `BoxMesh` 7×3.2×6. Uma casa rodada no editor ficaria com fachadas a flutuar; vale um assert.

## 10. Lacunas do teste que podem esconder defeitos reais
- **(a)** "removing the visual layer…" (`test_beach_dressing.gd:51-55`) nunca pode falhar, porque o `build_map` só lê `Decor/Roads`. Trocar por verificações úteis:
  - cada `Rocks/*` invisível tem a sua `RockSurfaces/Surface_<nome>`;
  - as caixas de RockSurfaces e HorrorOnly ficam em células bloqueadas e sem cover (o ciclo da linha 44 só percorre Shore);
  - o topo de cada superfície fica acima de `ground_y`;
  - há uma razão mínima entre pegada visível e células bloqueadas.

  Isto teria apanhado os pontos 1, 2 e 6.
- **(b)** O material só é verificado em `Hut_01/Body`. Verificar todos os Body, Roof, a torre, Bridge e Rails e `Roads/Surface` depois de recarregar do disco.
- **(c)** `get_texture_count() >= 3` passa com qualquer asset. Verificar o `resource_path` do `beach_01_ground.tres` e que as outras ilhas continuam com `ground_assets.res`.
- **(d)** Se o JSON ou a cena não carregarem, o `null` faz o teste pendurar sem `quit()` (linhas 22–23).
- **(e)** A idempotência não é testada. Correr o writer duas vezes deve dar um ficheiro idêntico byte a byte.

O hook em `build_islands` não usa o RNG nem mexe em marcadores ou alturas, por isso preserva o jogo. O que lhe falta é o tratamento de erros do ponto 5. `prepare_beach_boulder.py` está correto: pivot na base, limites de triângulos e texturas verificados.
