# Assets e addons de terceiros

Só entram assets com licença que permita usá-los num jogo (CC0, MIT, OFL ou
royalty-free comercial). Cada entrada indica a origem e a licença. Exceção
aceite pelo utilizador: os dados do OpenStreetMap (ODbL) da Berlenga, e o céu noturno do Sky3D (CC BY 4.0). O ecrã **CREDITS** no título
mostra "© OpenStreetMap contributors" e a atribuição da Via Láctea,
incluindo fontes, licenças e indicação das modificações. Ver
`docs/tech/CREDITS.md`.

| Caminho | O quê | Autor / origem | Licença |
|---|---|---|---|
| `addons/terrain_3d/` | Terrain3D 1.0.2 (terreno por heightmap, GDExtension) | Cory Petkovsek & Roope Palmroos | MIT (`LICENSE.txt`) |
| `addons/sky_3d/` | Sky3D 2.1 (céu e ciclo dia/noite) | Cory Petkovsek, J. Cuéllar e contribuidores | MIT (`LICENSE.txt`) |
| `addons/sky_3d/assets/thirdparty/textures/milkyway/` (`Milkyway.jpg`, `StarField.jpg`) | Céu noturno do Sky3D: "The Milky Way panorama"; `StarField.jpg` é uma versão modificada | ESO/S. Brunier | **CC BY 4.0**: exceção aceite pelo utilizador a 2026-10-11. Os créditos do jogo têm de mostrar: "The Milky Way panorama by ESO/S. Brunier, licensed under CC BY 4.0 and used in original and modified forms." |
| `addons/phantom_camera/` | Phantom Camera 0.11 (transições de câmara) | Marcus Skov | MIT (`LICENSE`) |
| `assets/animations/AnimationLibrary_Godot_Standard.glb` | Universal Animation Library (animações humanoides) | Quaternius | CC0 (`QUATERNIUS_LICENSE.txt`) |
| `assets/models/characters/recruit/recruit.glb` (original: `Horde_Braker_Recruit_v02_escala_jogo.glb`) | Horde Breaker Recruit v02 (personagem da classe Recruit, com espingarda de assalto) | o utilizador (gerado com uma ferramenta de IA, provavelmente o Codex) | propriedade do utilizador (output de IA); nenhuma fonte de terceiros conhecida (o glTF só indica "Khronos glTF Blender I/O v5.2.40", sem texturas) |
| `assets/models/characters/recruit/recruit_v03.glb`, `recruit_rifle_hold.json` | Recruit v03 com rig e pose de empunhadura; entrega gerada noutro ChatGPT a pedido do utilizador | Utilizador; modelo e pose fornecidos para este jogo | Output de IA do utilizador; sem novas fontes de terceiros identificadas no modelo |
| `assets/models/characters/recruit/recruit_animations.tres` | 46 clips UAL adaptados às proporções do Recruit v03 | Quaternius; adaptação incluída na entrega do utilizador | CC0 (`assets/animations/QUATERNIUS_LICENSE.txt`) |
| `assets/models/characters/vanguard/vanguard_v01.glb`, `vanguard_rifle_hold.json` | Vanguard v01 com rig, armadura verde-oliva e pose de empunhadura; entrega gerada noutro ChatGPT a pedido do utilizador | Utilizador; modelo derivado do Recruit e pose fornecidos para este jogo | Output de IA do utilizador; sem novas fontes de terceiros identificadas no modelo |
| `assets/models/characters/vanguard/vanguard_animations.tres` | 46 clips UAL adaptados ao Vanguard v01 | Quaternius; adaptação incluída na entrega do utilizador | CC0 (`assets/animations/QUATERNIUS_LICENSE.txt`) |
| `assets/models/characters/crawler_original/` | Crawler sem pernas, oito peças com pivôs, seis materiais sem texturas, script Blender e previews; geometria inteiramente original | Criado nesta sessão a pedido do utilizador; anatomia OpenStax consultada apenas como bibliografia, sem imagens ou malhas copiadas | CC0-1.0; ver `NOTES.md` na pasta |
| `assets/models/characters/arms_firstperson_original/` | Dois antebraços e mãos de primeira pessoa, rig Arms com oito ossos, três materiais sem texturas, script Blender e previews; geometria inteiramente original | Criado nesta sessão a pedido do utilizador; anatomia OpenStax apenas bibliográfica; espingarda original do projeto usada apenas num preview | CC0-1.0; ver `NOTES.md` na pasta |
| `assets/models/characters/weapon_grips_original/`, `docs/design/weapon_grips/` | Cinco variantes originais de mãos/braços, ajustadas às pegas das cinco armas existentes; clips `reload_mag_smg`/`reload_mag_mg` e morph targets de abertura dos dedos; fontes Blender, scripts, relatórios e capturas Godot | Criado nesta sessão; reutiliza o construtor original dos braços e as armas originais do próprio projeto como gabarito; sem novas malhas de terceiros | CC0-1.0; ver `NOTES.md` na pasta |
| `assets/models/weapons/assault_rifle_realistic/` | Assault rifle realista, para teste visual no sandbox DEV: GLB com 7 482 triângulos, quatro materiais PBR com texturas embebidas (2K, 1K e 256 px), as mesmas peças e o `Muzzle` da arma atual; `textures/` tem as mesmas texturas em PNG. Geometria derivada de `assets/models/weapons/tactical_original/assault_rifle.glb` (erro de superfície 0). A fonte Blender, os scripts que a constroem, o `validation.json` (SHA-256 do GLB `42bce673…`) e as capturas estão nesta pasta (`source/`, `renders/`). | Codex (trabalho original, 2026-10-23); base `tactical_original`, criada no projeto, CC0-1.0 segundo a sua `NOTES.md` | CC0-1.0 |
| `assets/models/environment/scenery_kit/` | Kit de cenário original com 13 peças, para o preset horror e a vila: árvore morta, tronco, casco encalhado, poste torto e rede caída (praia); janela com portadas, porta, toldo, varanda, escada, placa, candeeiro e chaminé (fachada). GLB em metros, pivô na base ou na face de encosto, atlas PBR de 1K partilhado; `textures/` tem as três imagens uma só vez. Fonte Blender, scripts, renders e pareceres JEV em `assets/models/environment/original_scenery_kit/` (isolada com `.gdignore`). | Codex (trabalho original, 2026-10-24); sem assets, texturas ou fontes descarregados | CC0-1.0 (`LICENSE.txt` na pasta) |
| `assets/models/nature_megakit/` | Stylized Nature MegaKit (versão grátis, glTF): árvores, rochas, relva, flores | Quaternius | CC0 (`License_Standard.txt`) |
| `assets/models/polyhaven/portable_generator/` | Gerador portátil, glTF oficial com texturas de 1K | James Ray Cock / [Poly Haven](https://polyhaven.com/a/portable_generator) | CC0 (`assets/models/polyhaven/LICENSE.txt`) |
| `assets/models/polyhaven/metal_jerrycan_green/` | Bidão de combustível, glTF oficial com texturas de 1K | Ulan Cabanilla / [Poly Haven](https://polyhaven.com/a/metal_jerrycan_green) | CC0 (`assets/models/polyhaven/LICENSE.txt`) |
| `assets/models/polyhaven/wooden_crate_02/` | Caixote de madeira, glTF oficial com texturas de 1K | James Ray Cock e Jurita Burger / [Poly Haven](https://polyhaven.com/a/wooden_crate_02) | CC0 (`assets/models/polyhaven/LICENSE.txt`) |
| `assets/models/polyhaven/concrete_road_barrier_02/` | Barricada de betão, glTF oficial com texturas de 1K | Amal Kumar / [Poly Haven](https://polyhaven.com/a/concrete_road_barrier_02) | CC0 (`assets/models/polyhaven/LICENSE.txt`) |
| `addons/road-generator/` + `road_demos/` | Road Generator 0.9.4 (estradas 3D) | Moo-Ack! Productions | MIT (`LICENSE`) |
| `addons/guide/` + `guide_examples/` | G.U.I.D.E 0.14 (input e ícones de comandos) | Jan Thomä | MIT (`LICENSE.md`) |
| `addons/boot_splash_plus/` | Boot Splash Plus 0.4.5 | GamingFirstOne | MIT (`LICENSE`) |
| `addons/Color grading/` + `Compositor/` | Color Grading (efeitos de compositor) | Rytelier | MIT (`LICENSE.txt` na raiz) |
| `addons/yard/` | YARD 1.3 (registos de Resources) | Elliot Fontaine e contribuidores | MIT (`LICENSE`) |
| `addons/dialogue_manager/` | Dialogue Manager 4.1 | Nathan Hoad | MIT (`LICENSE`) |
| `addons/GD-Sync/` | GD-Sync 1.0.2 (multiplayer na cloud) | GD-Sync | BSD-style para o código; o **serviço** tem termos próprios (contas/planos em gd-sync.com) |
| `PlayerCharacter/`, `Map/`, `Arts/` | Third Person Controller (cena de exemplo, *plush* do Godot, fontes) | Jeh3no | MIT (`LICENSE` na raiz) |
| `assets/textures/polyhaven/` | Texturas das ilhas reais, empacotadas e comprimidas por `tools/real_island/build.gd`. Berlenga: aerial_grass_rock, rock_face_03, coast_sand_rocks_02, rocky_trail; casas e caminhos do bairro: white_plaster_02, clay_roof_tiles_02, stone_wall_02. Construções das duas ilhas (2026-10-11): stone_wall_04 (granito do forte e dos muros), weathered_planks (ponte de madeira, santuário, torii), rusty_metal_04 (ferro pintado: gradeamentos, lanterna e cúpula do farol, tapete transportador), dirty_concrete (cais, pontes de betão, lajes e paredões) | Poly Haven (polyhaven.com) | CC0 |
| `assets/textures/polyhaven/` (zombies e armas, 2026-10-14) | Mapas diffuse/nor_gl/rough empacotados por `tools/art/pack_textures.gd` (descarregados por `tools/art/fetch_polyhaven_textures.py`). Zombies, a 512 px: leather_white (pele), cotton_jersey (T-shirts, calças caqui), denim_fabric_06 (jeans), fabric_leather_02 (casaco, cinto, botas, cabelo), rough_linen (camisa de trabalho). Armas, a 1k: blue_metal_plate (aço/gunmetal; diffuse convertido para cinzento), rubberized_track (polímero; diffuse convertido para cinzento), american_walnut_veneer (coronhas de nogueira); reutiliza rusty_metal_04. Sangue e feridas são procedimentais (`game/world/zombie.gdshader`), sem texturas | Poly Haven (polyhaven.com) | CC0 |
| `game/world/handmade/islands/beach_berlenga*` | Costa, caminhos, pontes, edifícios (plantas e alturas), paredões, farol e cais da Berlenga Grande | © OpenStreetMap contributors | **ODbL 1.0** (aceite pelo utilizador a 2026-10-07; atribuição obrigatória, e quem partilhar a base de dados derivada tem de a partilhar com a mesma licença) |
| `game/world/handmade/islands/*_berlenga_data/`, `*_berlenga_data/` | Relevo | AWS Terrain Tiles (Mapzen; fontes SRTM, EU-DEM e outras) | Dados abertos com atribuição às fontes |
| `assets/audio/ovani_sfx_starter_vol1/` | Sound FX Starter Pack Vol. 1 (só os 21 sons usados; o resto foi retirado, recuperável no histórico) | Ovani Sound | Royalty-free (`Royalty-Free License (Link).pdf`; https://ovanisound.com/policies/terms-of-service) |
| `assets/fonts/barlow_condensed/`, `assets/fonts/barlow/` | Barlow Condensed (SemiBold, Bold, ExtraBold) e Barlow (Regular, Medium, SemiBold): títulos e corpo dos menus e do HUD | The Barlow Project Authors (Jeremy Tribby), via github.com/google/fonts | OFL 1.1 (`OFL.txt` em cada pasta) |
| `assets/fonts/ibm_plex_mono/` | IBM Plex Mono (Regular, SemiBold): números e teclas | IBM Corp., via github.com/google/fonts | OFL 1.1 (`OFL.txt`) |

Removidos na integração (não servem ao jogo): versões Unity/Unreal da
biblioteca de animações, a demo do Terrain3D, ficheiros `__MACOSX` e, do
Nature MegaKit, as cópias FBX / FBX (Unity) / OBJ / `Textures/` e as imagens
de preview (o glTF tem tudo; os OBJ/FBX apontavam para texturas em `C:/` e
enchiam o import de erros). Recuperáveis no histórico do git (commit
`d4f070c`). Avaliação de cada addon: `docs/tech/ASSETS.md`.
