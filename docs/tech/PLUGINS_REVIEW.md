# Plugins instalados: análise do Codex (2026-10-11)

Análise para o utilizador decidir; nada foi alterado. Feita pelo Codex a ler o código e os LICENSE.

**Recomendo melhorar o carregamento e aproveitar Dialogue Manager/YARD já integrados. Co-op seria uma reformulação grande.**

Verifiquei regras, configuração, READMEs, código e licenças locais. Não alterei ficheiros nem executei Godot. Compatibilidade efetiva com 4.7, desempenho e aspeto visual ficam por testar; os riscos e estimativas abaixo são inferências. JEV não estava disponível.

[project.godot:43](C:/Users/Rui/code/horde-breaker-remake/project.godot:43) confirma os autoloads; linha 54 confirma os plugins de editor indicados. **Boot Splash Plus funciona apesar de estar desligado no editor**, porque continua como autoload.

Na tabela, “instalado” significa ausência de referências nas pesquisas em `game/`, `tests/`, `tools/` e `spikes/`. As licenças foram lidas nos respetivos ficheiros; Color Grading usa `LICENSE.txt` da raiz.

| Plugin | Função e licença | Uso atual: evidência | Riscos / veredicto |
|---|---|---|---|
| Color Grading | Correção cromática por compositor; MIT | Sim: `game/world/grading.gd:24` | GPU; omitido sem RenderingDevice e desativado em Low/Medium. **Manter**. |
| GD-Sync | Multiplayer cloud, lobbies, replicação e contas; licença própria | Instalado: `addons/GD-Sync/plugin.cfg:3` | Serviço externo; licença fora da lista aceite. **Não compensa agora**. |
| Asset Placer | Colocação e gestão de objetos 3D; MIT | Instalado: `addons/asset_placer/asset_placer_plugin.gd:225` | Ferramenta de editor; objetos colocados podem aumentar draw calls. **Usar** na decoração. |
| Boot Splash Plus | Overlay de arranque e loader opcional; MIT | Autoload: `project.godot:43` | Temporizadores; sem exclusão headless explícita. **Manter** apenas no arranque. |
| Dialogue Manager | Diálogos ramificados; MIT | `game/states/boat.gd:758`, `debrief.gd:67` | Importação `.dialogue` e autoload nos testes. **Manter**. |
| G.U.I.D.E. | Input, remapeamento e ícones; MIT | `game/ui/input_icons.gd:79`, `settings_panel.gd:189` | Dependências de autoload/editor em testes isolados. **Manter**. |
| Lit | Iluminação e efeitos **2D**; MIT | Instalado: `addons/lit/README.md:3` | Exige Forward+, Godot 4.4+; GPU, sem benefício nas ilhas 3D. **Remover**. |
| NAP Map Generator | Produz imagem superior do mundo; **licença ausente** | Só editor: `addons/nap_map_generator/plugin.gd:6` | Captura com viewports; lenta, não headless. Não registado em `assets/LICENSES.md`. **Remover até esclarecer**. |
| Phantom Camera | Seguimento e transições de câmara; MIT | `game/world/island.gd:1103` | Damping pode separar mira e imagem; integração já o desativa. **Manter**. |
| RoadGenerator | Estradas curvas e tráfego; MIT | `game/world/island_roads.gd:68` | Geração de malhas; manter coerência com grelha. **Usar seletivamente**. |
| Sky3D | Céu, nuvens, sol/lua e relógio; MIT **com texturas CC BY 4.0** | `game/world/island.gd:615` | Custo gráfico; texturas fora da lista aceite. **Manter após resolver licenças**. |
| Terrain3D | Terreno editável com LOD, C++; MIT | `game/world/island_terrain.gd:50` e cenas handmade | Binários GDExtension; relevo deve corresponder à navegação. **Manter**. |
| YARD | Registos de Resources e edição em tabela; MIT | `game/data/game_data.gd:351` | Carregamento bloqueante; índices podem ficar desatualizados. **Manter**. |
| Heightmap Terrain | Terreno por heightmap; MIT | Instalado: `addons/zylann.hterrain/plugin.cfg:3` | Duplica Terrain3D; shaders/editor por validar. **Remover**. |
| **TerraBrush** — adicional | Terreno pintável, GDExtension; MIT | Sem uso encontrado; `terrabrush.gdextension:9` | Duplica Terrain3D; binários exigem validação. **Remover**. |
| **Orchestrator** — adicional | Programação visual, GDExtension; **Apache 2.0** | Sem uso encontrado; `README.md:8` | Fora da lista aceite; outra linguagem e binários. Build declara mínimo 4.7. **Remover**. |

Apache 2.0 e CC BY são licenças livres, mas não constam da lista específica permitida pelo projeto. Em Sky3D, `src/SkyDome.gd:16` e `:17` carregam explicitamente Milkyway/StarField; não basta registar “Sky3D MIT”. Substituir essas imagens por alternativas permitidas evita mudar a regra.

**1. Boot Splash Plus e entrada nos mapas**

O autoload mostra o splash uma vez e destrói-se (`boot_splash_plus_runtime.gd:430`). A barra normal avança por tempo (`:237`), não pelo carregamento. O loader opcional usa `load_threaded_request` (`boot_splash_plus_scene_loader.gd:24`) e substitui a cena principal inteira: não preserva automaticamente `RunContext` nem o fluxo atual.

**Não encontrei o alegado loader entre partes.** Existe o acampamento (`game/states/camp.gd:1`) e o relatório no HUD. [main.gd:107](C:/Users/Rui/code/horde-breaker-remake/game/main.gd:107) usa `load()` síncrono para ilha/parte.

Plano recomendado:

1. Criar `game/ui/loading_screen.gd`, com `UiTheme`, nome da ilha e objetivo.
2. Em `main.gd`, mostrar o overlay e deixar desenhar um frame; carregar recursos em background, com erro recuperável.
3. Mostrar fases separadas para instanciação/construção do mapa; repartir trabalho pesado entre frames. Fechar só quando a ilha estiver pronta.
4. Em headless, dispensar animações/esperas visuais. Validar posteriormente transições, contexto e falhas de carregamento.

**2. Dialogue Manager**

Já existem briefings ramificados, condições e consequências: `briefing.dialogue:5` condiciona hazard pay; `briefing.gd:65` altera o contexto. Há também final ramificado em `debrief.gd:67`.

**O rádio de combate não usa Dialogue Manager:** `story.gd:10` contém as falas; `hud.gd:1734` escolhe-as e apresenta-as.

Melhorias concretas:

- Expor parte, ameaça e resultados anteriores em `briefing.gd`; escrever condições em `briefing.dialogue`. O acampamento atualmente dispensa briefing.
- Em `dialogue_box.gd:47`, substituir “H” por retratos livres registados; acrescentar revelação gradual e pequenos sons, com opção de os desligar.
- Permitir revelar/avançar texto e saltar conversa, preservando escolhas e efeitos já aplicados.
- A extração POT já existe (`project.godot:58`); incluir textos interpolados de `briefing.gd` e rádio de `story.gd`. Usar IDs estáveis/tradução e manter texto original inglês.

**3. YARD**

**Já está adotado**, incluindo armas, cartas, perks, inimigos, classes, biomas, missões e modificadores. `weapons.tres:8` aponta para a pasta de Resources; `game_data.gd:351` carrega o registo.

YARD **indexa os `.tres`**, não substitui Resources nem implementa efeitos. Para aprender: abrir o separador **Registry**, escolher `game/data/weapons.tres`, editar colunas como Damage/Fire Rate e guardar. Cada linha continua a ser um ficheiro editável no Inspector. Ao mudar propriedades indexadas, reindexar e validar.

Power-ups ainda têm tabelas/constantes (`game_data.gd:243`). Um `PowerUpData` seria útil para valores individuais; as regras continuam em `power_ups.gd`/`island_run.gd`. Recomendo continuar a adoção existente, sem migração geral.

**4. GD-Sync e co-op**

O código confirma ligação a servidores, contas e modo local; este dispensa conta/chaves e perde funcionalidades cloud (`MultiplayerClient.gd:330`). **Preços, plano gratuito, limites atuais e mecanismo exato de relay não são verificáveis neste projeto**; não consultei serviços externos.

`IslandRun` é um **RefCounted**, não um nó (`island_run.gd:2`), com estado de um jogador. A horda usa arrays e remove por troca de índices (`horde.gd:80`); MultiMesh apenas desenha.

Proposta técnica, se co-op for decidido:

1. Separar estado por jogador: vida, armas, cartas, XP e contexto.
2. Host autoritativo para movimento validado, auto-fire, dano, spawns e objetivos.
3. IDs estáveis dos inimigos; snapshots compactos/interpolação, sem sincronizar nós por inimigo nem assumir determinismo.
4. Decidir pausa/level-ups, loot, morte, reviver, progressão e transições.
5. Lobbies, HUD por jogador, desconexões e testes headless com latência/perda.

**Esforço grande: vários meses a solo**, estimativa inferida, não compromisso. Contraria a decisão single-player (`DECISIONS.md:14`); a pergunta em `PROGRESSION_AND_ECONOMY.md:417` não a revoga.

**5. Ilhas reais e prioridades**

Color Grading ajuda a identidade visual; Asset Placer ajuda a decoração. RoadGenerator serve ruas de Hashima melhor que caminhos irregulares da Berlenga. NAP só justificaria mapas ilustrados pré-gerados após resolver a licença. Lit não ajuda o 3D; Heightmap Terrain duplica ferramentas.

Ordem: **resolver licenças → loader próprio → diálogo/acessibilidade → equilíbrio no YARD → decoração medida**. Não iniciar multiplayer nem acrescentar outro sistema de terreno agora.


