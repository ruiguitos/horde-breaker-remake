# Assets e addons: o que usamos, o que fica para depois e o que não foi feito

Avaliação dos addons e assets adicionados ao projeto e registo do que
**não** foi implementado (com o porquê e, quando faz sentido, como o fazes à
mão no editor). Licenças: `assets/LICENSES.md`.

## Resumo

| Asset | Veredicto | Estado |
|---|---|---|
| Terrain3D | **Usar** | Chão das ilhas (`world/island_terrain.gd`) |
| Sky3D | **Usar** | Céu e hora do dia |
| Road Generator | **Usar** | Estradas do cais aos objetivos (`world/island_roads.gd`) |
| Stylized Nature MegaKit (Quaternius) | **Usar** | Árvores, rochas e vegetação (`world/nature_kit.gd`) |
| Third Person Controller | **Usar a ideia, não o código** | Câmara de 3.ª pessoa própria (V alterna) |
| G.U.I.D.E | **Usar** | Separador CONTROLS: ícones de teclas/comando e remapeamento |
| Controller Icons | Usar mais tarde | **Não está no repositório** (falta o push) |
| Boot Splash Plus | **Usar** | Ecrã de arranque (porto + logótipo + barra) |
| Color Grading | **Usar** | Cor por bioma em High/Ultra (`world/grading.gd`; só Forward+) |
| Dialogue Manager | **Usar** | Briefing no barco com escolhas (`data/dialogue/briefing.dialogue`) |
| GD-Sync | Avaliar | Ver `docs/tech/MULTIPLAYER.md` |
| Lit | **Não serve** | Só ilumina 2D |
| HTerrain | **Não usar** | Duplica o Terrain3D |
| TerraBrush | **Não usar** | Duplica o Terrain3D |
| Godot Asset Placer | Opcional (editor) | Só ajuda a colocar à mão; as ilhas são geradas |
| Orchestrator | **Não usar** | Visual scripting; o projeto é GDScript tipado |

## Usados agora

### Terrain3D
O chão é gerado a partir do mapa: terra plana a 0 m (o jogo corre numa
grelha 2D) e costa a descer suavemente para o mar. As cores vêm do *color
map*. Próximo passo: texturas reais (areia, relva, rocha) como
`Terrain3DTextureAsset` e relevo fora da zona jogável (dunas, o cone do
vulcão).

### Road Generator
`IslandRoads.plan()` procura um caminho na grelha desde o cais até cada
gerador (ou cache), dando preferência a células com espaço à volta, e cria
`RoadPoint`s ligados num `RoadContainer`. O addon gera a malha curva com as
marcas das faixas. Ao longo das estradas há candeeiros com `OmniLight3D`.

As estradas são decoração: não mudam a navegação dos inimigos.

**Fazer à mão no editor** (se quiseres estradas desenhadas por ti numa cena):
1. Projeto → Definições → Plugins: ativa **RoadGenerator**.
2. Na cena 3D, adiciona um nó **RoadManager** e, dentro dele, um **RoadContainer**.
3. Com o RoadContainer selecionado, usa a barra de ferramentas *Road* para
   clicar no chão e criar `RoadPoint`s (Ctrl+clique continua a estrada).
4. Em cada `RoadPoint` mudas as faixas (`lanes`), a largura (`lane_width`) e
   as bermas.
5. Exemplos: abre `road_demos/demo_menu.tscn` (o *Museum* é o melhor ponto de
   partida).

### Stylized Nature MegaKit (Quaternius, CC0)
Os modelos ficam em `assets/models/nature_megakit/`, só em glTF. Por bioma:
- **Town:** CommonTree.
- **Jungle:** CommonTree e Pine.
- **Volcano:** DeadTree.
- **Todos:** Rock_Medium como rochas; relva, fetos, flores ou seixos espalhados
  pelo chão (só decoração).

As árvores TwistedTree são vermelhas (outonais) e ficaram de fora. A praia e o
porto mantêm as palmeiras feitas em código, porque a versão grátis do kit não
tem palmeiras (a PRO tem 116 modelos). Cada variante desenha-se com um
`MultiMesh`, o que dá poucas *draw calls* mesmo com centenas de plantas.

### Third Person Controller → câmara de 3.ª pessoa
O controller do asset é um `CharacterBody3D` com física, máquina de estados
e animações do *plush* do Godot. O jogador do Horde Breaker é um ponto na
grelha da simulação (`IslandRun`), e é isso que permite centenas de inimigos
e testes sem GPU. Trocar pelo `CharacterBody3D` partiria a simulação e os
testes.

Por isso ficou o **comportamento** da câmara do asset, implementado na
câmara do jogo:
- câmara atrás do ombro direito, que se aproxima quando há um edifício no
  caminho;
- rato capturado roda a vista, ou o stick direito no comando;
- WASD relativo à câmara;
- mira-se ao centro do ecrã (cruz);
- **V** (ou Back/Select) alterna para a vista de cima antiga. A escolha
  fica gravada no perfil.

Os valores ajustam-se no inspetor de `island.tscn`, grupo *Third-person
camera*: distância, altura, ombro e limites do pitch.

As pastas `PlayerCharacter/`, `Map/` e `Arts/` continuam na raiz, porque as
cenas do asset referem esses caminhos. Podes abrir
`Map/test_map_scene.tscn` para o experimentar.

### G.U.I.D.E (ícones e remapeamento)
O `GameInput` continua a ser a fonte das ações (InputMap). O G.U.I.D.E entra
em duas coisas:
- **Ícones:** o `GUIDEInputFormatter` desenha a tecla ou o botão do comando
  (`ui/input_icons.gd`).
- **Remapear:** o `GUIDEInputDetector` espera pela próxima tecla ou botão do
  rato.

No separador **CONTROLS** das Settings, cada ação mostra a tecla atual, o
botão do comando e um **REBIND**; o Esc cancela. Também lá estão a
sensibilidade do rato e "Reset default keys". Os remapeamentos ficam no
perfil (`key_bindings`) e mudam só a tecla principal: setas e comando
mantêm-se.

### Boot Splash Plus
Está configurado em `project.godot` (secção `application/boot_splash+`):
porto ao fundo, logótipo Horde Breaker, barra âmbar e 1,6 s. O autoload
`BootSplashPlus` faz o trabalho em runtime.

O **plugin de editor fica desligado**: na cloud faz rebentar o
`--import`, e não é preciso para o splash funcionar. Se o ativares no editor
para mexer nas opções, não faz mal, mas desliga-o antes de fazer push.

### Color Grading
Cada bioma tem um "look": tons de sombras, médios e altos, mais
vibrância. Por exemplo, a praia tem sombras azul-esverdeadas e altos
quentes, e o vulcão é vermelho-laranja. O efeito é um `CompositorEffect` na
câmara da ilha, ligado nos presets High e Ultra. Só funciona com
RenderingDevice (Forward+); no modo de compatibilidade não aparece. **Não o
consegui ver na cloud**, que não tem Vulkan: confirma no editor (F5,
Graphics: High). Os valores estão em `world/grading.gd` (`LOOKS`).

### Dialogue Manager (briefing no barco)
Ao confirmar a rota, o Director Hale faz o briefing antes de desembarcar.
As escolhas são:
- **Understood:** desembarcas logo.
- **What do we know about this island?:** lore do bioma.
- **Any advice?:** dica para a missão.
- **I want hazard pay:** só na ilha seguinte, +25 % de Intel e +25 % de
  inimigos.

O texto está em `game/data/dialogue/briefing.dialogue` e edita-se no
separador *Dialogue* do editor. Os dados e regras estão em
`game/data/briefing.gd`. A caixa de diálogo (`ui/dialogue_box.gd`) usa o
estilo da UI do jogo e aceita teclado, comando e as teclas 1–4.

## Para mais tarde

- **Controller Icons**: não está no repositório. Faz push da pasta
  `addons/controller_icons/` se o quiseres usar; o G.U.I.D.E já traz ícones,
  por isso basta um dos dois.
- **Godot Asset Placer**: útil para colocar modelos à mão em cenas fixas
  (menus, porto do título). As ilhas são geradas, por isso não ajuda lá.

## Não usar (e porquê)

- **Lit**: é um motor de luz **2D** (`PointLight2D` e afins). As ilhas são
  3D. A luz 3D vem dos candeeiros das estradas (`OmniLight3D`), do sol do
  Sky3D e do clarão dos disparos. Lit só serviria para efeitos 2D nos menus.
- **HTerrain** e **TerraBrush**: fazem o mesmo que o Terrain3D, que já
  usamos. Ter três sistemas de terreno só pesa no projeto (HTerrain 19 MB,
  TerraBrush 46 MB). **Proposta:** removê-los.
- **Orchestrator**: visual scripting de 170 MB. O projeto é GDScript tipado
  e testado headless. Ter dois paradigmas divide o código. **Proposta:**
  removê-lo.

## Pedidos desta ronda que não foram implementados

1. **Modelos de personagem descarregados** (estilo do retrato): a cloud não
   tem acesso aos sites de assets (Quaternius, Kenney e Poly Pizza estão
   bloqueados pela rede). Em vez disso há um **soldado low-poly feito em
   código** (`world/soldier_model.gd`), com variante por classe:
   - **Recruit:** farda caqui e espingarda.
   - **Vanguard:** armadura escura e pesada, viseira e caçadeira.

   Aparece no Armory a rodar e é o jogador na ilha. Para modelos reais
   recomendo, todos CC0:
   - **Quaternius – "Ultimate Modular Men"** ou **"Toon Shooter Game Kit"**:
     soldados riggados que usam a *Universal Animation Library* que já está
     em `assets/animations/`.
   - **Kenney – "Blocky Characters"**: estilo mais simples.

   Descarrega o `.glb`, põe-no em `assets/models/characters/` e faz push. Eu
   ligo-o ao `SoldierModel`, com a mesma interface `create()`/`animate()`.
2. **Lit para luz in-game**: não é possível (é 2D). Foi substituído por
   candeeiros 3D.
3. **"existir menu"** (na lista das Settings): a frase ficou incompleta e não
   percebi o que querias. Se for um menu de controlos ou de remapeamento,
   está planeado com o G.U.I.D.E.
4. **Multiplayer**: precisa de decisões tuas antes de código; ver
   `docs/tech/MULTIPLAYER.md`.

## Decisões propostas

- Remover HTerrain, TerraBrush e Orchestrator (cerca de 235 MB) e manter o
  Terrain3D como único sistema de terreno.
- Câmara de 3.ª pessoa como predefinição, com a de cima como alternativa
  (V). Muda a sensação do jogo; é preciso jogar algumas runs para confirmar.
- Escolher um pacote de personagens CC0 (ver acima) para substituir o
  soldado em código.
