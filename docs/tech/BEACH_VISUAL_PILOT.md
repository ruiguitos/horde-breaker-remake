# Piloto visual beach_01

Implementado a 2026-11-14 por Codex, com planeamento e revisão só de leitura
do Claude Code. O utilizador escolheu concluir a praia antes das restantes ilhas.
Estado: implementado e validado automaticamente; falta avaliação visual a jogar.
Lista ativa: `TODO.md`. Não foi editado `docs/DECISIONS.md`.

## Resultado

![Antes](../design/beach_pilot_20261114/before_village_third.png)

![Depois](../design/beach_pilot_20261114/after_village_third.png)

- Seis casas com reboco e telhas PBR; portas, portadas, candeeiros e chaminés.
  Toldos em duas casas, placa de taberna e varanda ornamental na torre.
- Torre em pedra, ponte/guardas em madeira e caminho com material de terra/pedra.
- Terreno com quatro camadas: areia costeira, falésia, vegetação rasteira e trilho.
  A cor distingue a faixa molhada; o declive usa as mesmas alturas e `max_step`
  do mapa de jogo. As alturas do Terrain3D foram preservadas.
- Oito afloramentos costeiros fotogramétricos preparados a partir de Boulder 01.
  As vinte rochas que já bloqueavam o jogo mantêm a geometria e a visibilidade,
  agora com material PBR. Não existem substitutas minúsculas de obstáculos grandes.
- Casco encalhado, dois troncos, rede e dois postes. Três árvores mortas visíveis
  apenas no preset horror. Novos sólidos costeiros ficam em células já bloqueadas,
  fora de caminhos e afastados dos marcadores. As bases seguem o chão real;
  afloramentos ficam parcialmente enterrados para assentar a malha digitalizada.
- Erva em lâminas afuniladas em vez de cartões retangulares opacos, só no piloto;
  conservam-se o orçamento de 400 instâncias, distância e regras da qualidade Low.

Foram usados 12 dos 13 tipos do kit original. A escada exterior ficou de fora
porque sugeriria um acesso que a navegação atual não oferece. Não foram instalados
plugins novos nem modificadas regras de combate, objetivos ou progressão.

## Organização e edição

`game/world/handmade/islands/beach_01.tscn` continua a ser a ilha da rota normal.
Instancia `Decor/Dressing`, guardado em
`game/world/handmade/dressing/beach_01_dressing.tscn`. Este ficheiro fica fora de
`islands/` para não ser descoberto como outra ilha jogável.

O dressing é conteúdo persistente, sem gerador a correr durante a partida.
Os adereços não são filhos de `Buildings`: isso alargaria as caixas usadas para
bloquear células. A câmara recebe caixas individuais dos adereços visíveis, sem
alterar a grelha. O estado horror é aplicado pelo contexto real da run.

**O gerador é dono do conteúdo de Dressing.** Para conservar mudanças após
reaplicar, editar `tools/dev/beach_dressing.gd`. Mover peças diretamente na cena
gerada é possível, mas essas mudanças serão substituídas na próxima aplicação.
O terreno pintado também é recalculado pela ferramenta; guardar trabalho manual
antes de a executar. A ilha atual foi atualizada sem reconstruir o layout.

Reaplicar apenas esta passagem visual, na raiz do projeto:

```powershell
$godot = 'C:/Users/Rui/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/dev/apply_beach_dressing.gd
& $godot --headless --path . --script res://tests/test_beach_dressing.gd
```

`tools/dev/build_islands.gd -- beach` também aplica o dressing, mas reconstrói
a ilha inteira e pode perder alterações manuais de layout/marcadores. Não é o
comando de manutenção deste piloto. O ramo experimental `--roadgen` não o aplica.

## Assets e reprodução

| Recurso | Origem/licença | Preparação entregue |
|---|---|---|
| Boulder 01 | Rico Cilliers, [Poly Haven](https://polyhaven.com/a/boulder_01), CC0-1.0 | 66 122 → 3 984 triângulos; um material, três mapas 1K; GLB de 3 008 220 bytes; pivô no centro da base |
| Coast Sand 01 | Rob Tuytel, [Poly Haven](https://polyhaven.com/a/coast_sand_01), CC0-1.0 | Quatro JPG 1K empacotados em dois mapas RGB+A com mipmaps/S3TC DXT5, como as camadas existentes |
| Kit de cenário | Trabalho original do projeto, CC0-1.0 | Malhas partilhadas por tipo e atlas PBR de 1K partilhado; ligação ORM corrigida |
| Restantes materiais | Poly Haven CC0 já presente | Reboco, telhas, pedra, madeira, trilho e vegetação; não foram descarregados novamente |

Os dois downloads desta implementação totalizam 8 588 587 bytes de fontes.
Originais em `assets/source/polyhaven/beach_boulder_01_1k/` e
`beach_coast_sand_01_1k/`, ignorados pelo git. Manifestos entregues com URL,
tamanho e SHA-256 em `assets/models/polyhaven/boulder_01/download_manifest.json`
e `game/world/handmade/dressing/coast_sand_01_source.json`.
Licenças registadas em `assets/LICENSES.md`.

Preparação offline, com os originais locais nas pastas acima:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python tools/assets/prepare_beach_boulder.py
& $godot --headless --path . --script res://tools/assets/prepare_beach_sand.gd
& $godot --headless --path . --script res://tools/dev/apply_beach_dressing.gd
```

É necessário reaplicar o dressing após preparar novamente o boulder: a cena
cozida guarda a malha preparada. O `validation.json` do boulder indica dimensões
nos eixos Blender, triângulos, texturas e SHA-256 do GLB.

## Evidência e limites

- Suite completa: **89/89**, exit 0, 1 098 084 ms. Depois das correções finais,
  repetidos com sucesso os oito testes afetados: beach_dressing, camera_aim,
  beach_cover_handmade, handmade, horror_preset, scenery_graphics, smoke e
  objective_pools. Logs no [registo da entrega](../history/beach_pilot_20261114/).
- Fixture `tests/fixtures/beach_visual_baseline.json`, capturada antes do piloto:
  hashes de bloqueio, cobertura e alturas e coordenadas de todos os marcadores.
  `test_beach_dressing.gd` verifica correspondência, materiais após recarregar,
  bases, visibilidade das rochas, camadas compatíveis e comportamento normal/horror.
- PNG da grelha antes/depois **idêntico byte a byte**, SHA-256
  `e00c1feaa06640219054aad011bed7d719d027b33336998e53188536a34d080d`.
- Geração integral ensaiada numa cópia isolada em `.scratch`, sem reconstruir a
  ilha do utilizador: exit 0, `problems []`, gargalos com alternativa e auditoria
  sem objetos em posições estranhas. Isto não substitui validar futuros layouts.
- Capturas reais Forward+ a 1280×720, seed 7, perfis em memória, três câmaras,
  aldeia/costa/ponte/torre e normal/horror. Guardadas em
  `docs/design/beach_pilot_20261114/`. Não são imagens geradas por IA.
- Há avisos de interpolação e recursos/RIDs em uso ao encerrar. Os critérios de
  sucesso do projeto foram respeitados; não se afirma execução sem avisos.
- JEV confirmou a preservação da grelha e as verificações dos adereços, mas
  devolveu `escalate` por confiança insuficiente na revisão e não comprovou a
  cronologia dos testes com os excertos enviados. Não produziu diagnóstico
  concreto de defeito. Parecer consultivo, não aprovação automática; relatório
  completo em `vault/99 Ferramentas/JEV/07_beach_visual_pilot.json`.

### Desempenho observado

Godot 4.7.2, Forward+, GPU RTX 5060, janela 1600×900, vsync desligado,
seed 7, ameaça 3/swarm, 150 inimigos iniciais (144–149 durante as amostras),
480 frames por ensaio após aquecimento de 3 s. Mesmo código atual nas duas
cenas: snapshot pré-piloto e ilha renovada. Execuções sequenciais, editor do
utilizador aberto e outras aplicações em segundo plano.

| Câmara | Média antes/depois (ms) | p95 antes/depois (ms) | p99 antes/depois (ms) | Draw calls máximas antes/depois |
|---|---|---|---|---|
| 1.ª pessoa | 5,91 / 5,56 | 13,68 / 10,35 | 16,98 / 13,14 | 1336 / 1353 |
| 3.ª pessoa | 6,14 / 5,40 | 12,08 / 10,12 | 17,57 / 11,75 | 1341 / 1348 |
| Fixa | 5,60 / 5,81 | 12,05 / 10,96 | 15,23 / 14,21 | 1336 / 1348 |

Memória de texturas reportada pelo RenderingServer: 207 238 656 → 255 199 232
bytes (**+45,74 MiB**). É o contador global do renderer, não uma medição da
memória física da placa por asset. Não foi observado um aumento consistente de
tempo por frame; a variabilidade impede concluir que o piloto melhorou FPS.
É um ensaio parado no desembarque, não uma run humana nem um limite garantido
de desempenho em todas as zonas.

Para jogar: título → sandbox DEV → beach_01; experimentar normal/horror e as
três câmaras. Para novas capturas sem tocar no perfil pessoal:

```powershell
& $godot --path . --resolution 1280x720 --windowed --script res://tools/dev/beach_visual_review.gd -- res://game/world/handmade/islands/beach_01.tscn .scratch/beach_review normal
```

### O que continua por fazer

A costa conserva o contorno e o terreno anteriores; há transições de falésia
esticadas. Casas, torre, barco de extração e ponte ainda têm volumes simples.
A vegetação de maior porte é a existente. O horror está demasiado escuro nas
capturas; a legibilidade e iluminação devem ser afinadas a jogar.
Falta percorrer combates e cantos de fachadas/câmara manualmente, avaliar a
direção visual com o utilizador e só depois planear as restantes quatro ilhas.
