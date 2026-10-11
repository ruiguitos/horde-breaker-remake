# Assets e addons de terceiros

Só entram assets com licença que permita usá-los num jogo (CC0, MIT, OFL ou
royalty-free comercial). Cada entrada indica a origem e a licença. Exceção
aceite pelo utilizador: os dados do OpenStreetMap (ODbL) da Berlenga e de
Hashima, e o céu noturno do Sky3D (CC BY 4.0). O ecrã **CREDITS** no título
mostra "© OpenStreetMap contributors" e a atribuição da Via Láctea,
incluindo fontes, licenças e indicação das modificações. Ver
`docs/tech/CREDITS.md`.

| Caminho | O quê | Autor / origem | Licença |
|---|---|---|---|
| `addons/terrain_3d/` | Terrain3D 1.0.2 (terreno por heightmap, GDExtension) | Cory Petkovsek & Roope Palmroos | MIT (`LICENSE.txt`) |
| `addons/terrabrush/` | TerraBrush (terreno pintável, GDExtension) | spimort | MIT (`LICENSE`) |
| `addons/sky_3d/` | Sky3D 2.1 (céu e ciclo dia/noite) | Cory Petkovsek, J. Cuéllar e contribuidores | MIT (`LICENSE.txt`) |
| `addons/sky_3d/assets/thirdparty/textures/milkyway/` (`Milkyway.jpg`, `StarField.jpg`) | Céu noturno do Sky3D: "The Milky Way panorama"; `StarField.jpg` é uma versão modificada | ESO/S. Brunier | **CC BY 4.0**: exceção aceite pelo utilizador a 2026-10-11. Os créditos do jogo têm de mostrar: "The Milky Way panorama by ESO/S. Brunier, licensed under CC BY 4.0 and used in original and modified forms." |
| `addons/phantom_camera/` | Phantom Camera 0.11 (transições de câmara) | Marcus Skov | MIT (`LICENSE`) |
| `assets/animations/AnimationLibrary_Godot_Standard.glb` | Universal Animation Library (animações humanoides) | Quaternius | CC0 (`QUATERNIUS_LICENSE.txt`) |
| `assets/models/characters/recruit/recruit.glb` (original: `Horde_Braker_Recruit_v02_escala_jogo.glb`) | Horde Breaker Recruit v02 (personagem da classe Recruit, com espingarda de assalto) | o utilizador (gerado com uma ferramenta de IA, provavelmente o Codex) | propriedade do utilizador (output de IA); nenhuma fonte de terceiros conhecida (o glTF só indica "Khronos glTF Blender I/O v5.2.40", sem texturas) |
| `assets/models/nature_megakit/` | Stylized Nature MegaKit (versão grátis, glTF): árvores, rochas, relva, flores | Quaternius | CC0 (`License_Standard.txt`) |
| `addons/road-generator/` + `road_demos/` | Road Generator 0.9.4 (estradas 3D) | Moo-Ack! Productions | MIT (`LICENSE`) |
| `addons/lit/` | Lit 1.1.6 (luz **2D**; não usado no 3D) | Shawn Deprey | MIT (`LICENSE`) |
| `addons/guide/` + `guide_examples/` | G.U.I.D.E 0.14 (input e ícones de comandos) | Jan Thomä | MIT (`LICENSE.md`) |
| `addons/boot_splash_plus/` | Boot Splash Plus 0.4.5 | GamingFirstOne | MIT (`LICENSE`) |
| `addons/asset_placer/` | Godot Asset Placer 1.6 (ferramenta de editor) | Roman Levinzon | MIT (`LICENSE`) |
| `addons/orchestrator/` | Orchestrator (visual scripting, GDExtension, 170 MB) | CraterCrash e contribuidores (`AUTHORS.md`) | Apache 2.0 (`LICENSE`) |
| `addons/zylann.hterrain/` | HTerrain 1.8 (terreno por heightmap) | Marc Gilleron | MIT (`LICENSE.md`) |
| `addons/Color grading/` + `Compositor/` | Color Grading (efeitos de compositor) | Rytelier | MIT (`LICENSE.txt` na raiz) |
| `addons/yard/` | YARD 1.3 (registos de Resources) | Elliot Fontaine e contribuidores | MIT (`LICENSE`) |
| `addons/dialogue_manager/` | Dialogue Manager 4.1 | Nathan Hoad | MIT (`LICENSE`) |
| `addons/GD-Sync/` | GD-Sync 1.0.2 (multiplayer na cloud) | GD-Sync | BSD-style para o código; o **serviço** tem termos próprios (contas/planos em gd-sync.com) |
| `PlayerCharacter/`, `Map/`, `Arts/` | Third Person Controller (cena de exemplo, *plush* do Godot, fontes) | Jeh3no | MIT (`LICENSE` na raiz) |
| `assets/textures/polyhaven/` | Texturas das ilhas reais, empacotadas e comprimidas por `tools/real_island/build.gd`. Berlenga: aerial_grass_rock, rock_face_03, coast_sand_rocks_02, rocky_trail; casas e caminhos do bairro: white_plaster_02, clay_roof_tiles_02, stone_wall_02. Hashima: cracked_concrete, concrete_wall_006, dark_rock, concrete_pavement_03, concrete_wall_008 (fachada, com janelas desenhadas, e o seu relevo). Construções das duas ilhas (2026-10-11): stone_wall_04 (granito do forte e dos muros), weathered_planks (ponte de madeira, santuário, torii), rusty_metal_04 (ferro pintado: gradeamentos, lanterna e cúpula do farol, tapete transportador), dirty_concrete (cais, pontes de betão, lajes, galerias e paredão de Hashima), rusty_corrugated_iron (chapa ondulada em Hashima) | Poly Haven (polyhaven.com) | CC0 |
| `game/world/handmade/islands/beach_berlenga*`, `port_hashima*` | Costa, caminhos, pontes, edifícios (plantas e alturas), paredões, farol e cais da Berlenga Grande e de Hashima | © OpenStreetMap contributors | **ODbL 1.0** (aceite pelo utilizador a 2026-10-07; atribuição obrigatória, e quem partilhar a base de dados derivada tem de a partilhar com a mesma licença) |
| `game/world/handmade/islands/*_berlenga_data/`, `port_hashima_data/` | Relevo | AWS Terrain Tiles (Mapzen; fontes SRTM, EU-DEM e outras) | Dados abertos com atribuição às fontes |
| `assets/audio/ovani_sfx_starter_vol1/` | Sound FX Starter Pack Vol. 1 (só os 21 sons usados; o resto foi retirado, recuperável no histórico) | Ovani Sound | Royalty-free (`Royalty-Free License (Link).pdf`; https://ovanisound.com/policies/terms-of-service) |
| `assets/fonts/barlow_condensed/`, `assets/fonts/barlow/` | Barlow Condensed (SemiBold, Bold, ExtraBold) e Barlow (Regular, Medium, SemiBold): títulos e corpo dos menus e do HUD | The Barlow Project Authors (Jeremy Tribby), via github.com/google/fonts | OFL 1.1 (`OFL.txt` em cada pasta) |
| `assets/fonts/ibm_plex_mono/` | IBM Plex Mono (Regular, SemiBold): números e teclas | IBM Corp., via github.com/google/fonts | OFL 1.1 (`OFL.txt`) |

Removidos na integração (não servem ao jogo): versões Unity/Unreal da
biblioteca de animações, a demo do Terrain3D, ficheiros `__MACOSX` e, do
Nature MegaKit, as cópias FBX / FBX (Unity) / OBJ / `Textures/` e as imagens
de preview (o glTF tem tudo; os OBJ/FBX apontavam para texturas em `C:/` e
enchiam o import de erros). Recuperáveis no histórico do git (commit
`d4f070c`). Avaliação de cada addon: `docs/tech/ASSETS.md`.
