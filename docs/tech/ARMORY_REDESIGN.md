# Armory — Abrigo 3D e Perks — Três ramos

Implementado em 2026-10-11, a pedido do utilizador, seguindo as maquetas
aprovadas em [MENUS.md](../design/MENUS.md). Sem commit pelo agente.

## O que mudou

- **Armory:** abrigo costeiro real num SubViewport independente, paredes
  de pedra, teto de madeira, bancada, caixotes, gerador e bidão. Luz quente
  de trabalho e luz fria exterior; mar com movimento e uma ilha/farol
  decorativos. Modelo jogável em Idle e arma principal escolhida; retratos
  3D do Recruit e Vanguard nos botões de seleção. Motivo de azulejo original
  no cabeçalho e Intel sempre visível.
- **Resumo fixo:** as duas armas, três slots (equipado/vazio/bloqueado),
  Threat, multiplicador e Start Run cabem sem scroll. Carregar num slot
  abre Perks; o catálogo de armas continua a permitir scroll e mantém as
  compras/equipamento atuais.
- **Perks:** três ramos × três tiers ligados, A/B lado a lado com ícones,
  alternativa escolhida, pips de rank e estado explícito. Painel direito
  mostra benefícios **e penalização** atuais e da próxima compra. A compra
  seguinte usa o rank comprado; selecionar um rank inferior só muda o
  efeito atual. Rank III não apresenta compra ou efeitos fictícios de IV.
- **Equipados e navegação:** três slots permanecem visíveis. Selecionar um
  equipado foca o seu nó; selecionar um slot bloqueado leva ao botão de
  compra, quando disponível. Setas/D-pad navegam; Q/E ou LB/RB trocam A/B;
  Enter/A abre ações; Esc/B regressa da ação ao nó e depois ao título.
  Start Run conserva a escolha da expedição. Dicas usam InputIcons; a
  habilidade mostra o binding atual e LB no comando.

Os custos, requisitos, slots, trocas grátis, variantes por classe, efeitos
da run e formato v7 do perfil continuam nos sistemas existentes. Este
trabalho não alterou os dados de gameplay nem `docs/DECISIONS.md`.

## Código e assets

| Ficheiro | Responsabilidade |
|---|---|
| `game/states/armory.gd` | Layout, foco, ações e chamadas a Profile |
| `game/ui/armory_shelter.gd` | Abrigo, iluminação, mar e modelo escolhido |
| `game/ui/perk_node_view.gd` | Apresentação de cada nó, sem lógica de progressão |
| `game/ui/armory_art.gd` | Símbolos SVG originais de perks/armas e azulejo |
| `game/ui/class_preview.gd` | Retratos compactos opcionais; turntable anterior conservado |
| `tools/dev/menu_preview.gd` | Perfil de demonstração v7 e espera pelo fim do splash |
| `tests/test_armory_layout.gd` | Regressões de layout, efeitos seguintes e slots |

Reutiliza apenas modelos, texturas CC0 e fontes já registados em
`assets/LICENSES.md`; não houve downloads, instalação de Blender ou novas
dependências. A arquitetura e o farol são geometria decorativa criada em
código, sem dados de mapas reais. As maquetas não são fundos do menu.
O cenário mantém uma estética simplificada; não reproduz os materiais e
detalhes fotográficos da imagem gerada.

## Validação

**36/36 scripts passaram**: 33 do jogo e 3 dos spikes, sem `TEST FAIL`,
`SCRIPT ERROR` ou erros de parsing. Inclui as 139 verificações da árvore
de perks, as 30 dos menus e as 96 do novo layout. O bot terminou duas runs
com extração nas seis ilhas e os dois bosses derrotados.

O teste novo tem **96 verificações**: limites do ecrã a 1152×648 e Full HD,
os dois rigs, alternativas lado a lado, todos os nós e ambas as opções nas
duas classes, rank máximo, rank inferior em uso, penalização da compra
seguinte, navegação dos slots, compra e aviso de migração. Teste de mutação:
substituir temporariamente o benefício seguinte pelo atual foi detetado;
o código foi restaurado byte a byte antes da suite completa.

Verificação suplementar com eventos de comando simulados no InputMap:
D-pad direita/esquerda muda de ramo, RB troca A/B sem cobrar, A abre as
ações e B devolve o foco ao nó. Passaram as cinco verificações; não depende
de um comando físico ligado.

Capturas reais em Forward+ verificadas a 1152×648 e 1920×1080:
[Armory](../design/menu_references/armory_implemented.png) e
[Perks](../design/menu_references/perks_implemented.png). O separador Weapons
foi igualmente capturado e inspecionado. Perfis de teste isolados do perfil
do jogador; nenhuma compra de demonstração foi gravada no seu save.

A revisão JEV recebeu apenas um resumo sanitizado e foi inconclusiva por
baixa confiança. A validação assenta na inspeção local, capturas e testes.
Mantêm-se os avisos de recursos de render no encerramento do Godot no
Windows e o código nativo `-1073741819`, já registado no projeto. Os
resultados foram avaliados pelos marcadores dos testes, como indicado em
AGENTS.md; o código nativo não foi contado como falha de teste.

## Prompt para o Claude

> Lê CLAUDE.md, docs/tech/ARMORY_REDESIGN.md e docs/design/MENUS.md. O Codex
> implementou os menus aprovados Armory — Abrigo 3D e Perks — Três ramos;
> as capturas reais estão em docs/design/menu_references/*_implemented.png.
> Preserva o abrigo 3D com o rig/arma escolhidos, o resumo sem scroll, os
> retratos, A/B lado a lado, os efeitos atuais/seguintes com penalizações e
> a fila de equipados. Profile continua a ser a fonte de progressão v7;
> não alterar custos, stats ou migração ao afinar o aspeto. Preserva
> InputIcons, os bindings da habilidade, foco/modal e Q/E/LB/RB/Esc/B.
> Confirma git status e git log antes de trabalhar, corre todos os testes
> após alterações e testa o layout a 1152×648 e 1920×1080. Não editar
> DECISIONS.md; não fazer commit ou push sem pedido do utilizador.
