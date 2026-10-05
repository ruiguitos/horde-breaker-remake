# Menus — referência tática aprovada

A implementação segue a imagem aprovada pelo utilizador: equipamento militar
sóbrio, painéis escuros, tipografia condensada, contornos finos e destaque âmbar.
O texto do jogo continua em inglês.

## Os quatro ecrãs

| Ecrã | Ação principal | Dados reais |
|---|---|---|
| Título | Deploy → Armory | Estatísticas do perfil; definições e arquivo |
| Armory | Start Run | Classes, armas, Intel, Threat e slots/perks |
| Barco / rotas | Confirm Route | Mantimento, bioma, missão e modificador sorteados |
| Pausa | Resume | Jogo atual desfocado; definições, controlos e abandono |

Os botões são Control/Button do Godot: funcionam com rato, teclado e ações
de comando registadas no InputMap. Os estados indisponíveis ficam desativados;
a rota selecionada tem texto e contorno além da cor. A run só começa a ilha
depois de escolher um mantimento e uma rota. Um mantimento aplica-se uma vez.

O Armory conserva a economia de Profile e grava cada compra/seleção. Os
painéis de definições e arquivo são modais: o foco circula dentro deles,
Esc/B fecha-os e devolve o foco ao botão anterior. Abrir definições na pausa
mantém a simulação parada e bloqueia os atalhos por baixo, incluindo Q.

## Apresentação e limites

A base lógica é 1152 × 648, com canvas_items e proporção preservada. Os
ecrãs foram vistos em Forward+ a 1152 × 648 e 960 × 540. Listas de armas,
perks e ficheiros têm scroll; o botão Start Run fica sempre fora do scroll.

O porto do título, o logótipo e o retrato são imagens estáticas geradas para
esta referência, em game/ui/art. O retrato é comum às três classes; a classe
e os efeitos apresentados mudam com o perfil. Não representa um modelo 3D
equipável. O mapa é um esquema decorativo das duas rotas, sem coordenadas
reais do terreno. As miniaturas dos biomas são ilustrações simples desenhadas
em Godot. A pausa desfoca o jogo real em vez de usar uma imagem de fundo.

O tema está em game/ui/ui_theme.gd; os modais em game/ui/menu_dialog.gd.
SettingsPanel herda o comportamento modal e conserva os três volumes em
percentagem (Master, Sound effects e Music), com slider e campo editável.
A integração preserva o céu Sky3D e o áudio gravado existentes.

## Verificação e capturas

- tests/test_menus.gd: compras, limite de slots, foco modal, fecho/gravação,
  mantimentos, rotas, última ilha e isolamento dos atalhos na pausa.
- tests/run_all.gd: suite do projeto e dos spikes.
- tools/dev/menu_preview.gd: captura os menus reais com um perfil de demonstração
  em memória; o perfil do jogador não é gravado por esta ferramenta.

Exemplo (substituir godot pelo caminho do executável, se necessário):

```powershell
godot --headless --path . --script res://tests/test_menus.gd
godot --path . --script res://tools/dev/menu_preview.gd -- C:/Temp/armory.png armory
```

Capturas disponíveis: title, armory, routes, supplies, pause, settings,
archive, weapons e perks.
