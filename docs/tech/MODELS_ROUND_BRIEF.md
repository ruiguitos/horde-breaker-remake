# Pedido ao Codex: acabar os modelos de armas e de inimigos (2026-11-10)

Para colar numa sessão do Codex com escrita (ele trabalha no Blender 5.2; a integração no jogo é do Claude). São dois pedidos independentes: fazer primeiro o das armas.

Estado de hoje, para contexto:

- **Armas.** Só a Assault Rifle tem versão realista (`assets/models/weapons/assault_rifle_realistic/`, 7 482 triângulos, 4 materiais com albedo, normal e ORM). A SMG, a Machine Gun, a Shotgun e a Marksman usam os modelos de `tactical_original/`, com cor lisa.
- **Inimigos.** O Walker e o Runner são malhas geradas por código (708 triângulos). O Crawler tem GLB próprio. Os especiais (Brute, Grabber, Bloater, Screamer, Behemoth) são malhas estilizadas com animação por pivôs no shader, sem esqueleto.
- **Decisão do utilizador (2026-11-10):** os inimigos não esperam pela decisão das personagens; continuam em blocos com materiais realistas e gore forte (decisão de 2026-10-14).

O que o jogo exige de cada entrega está nos contratos abaixo. Uma entrega que não os cumpra não é integrada.

## Pedido 1: quatro armas realistas

```text
Task: model realistic versions of four firearms in Blender 5.2 and export each as GLB for a Godot 4.7 first/third-person horde shooter. Match the finish of the existing assault_rifle_realistic.glb (same project, assets/models/weapons/assault_rifle_realistic/): read its source .blend, renders and validation.json first and keep the same level of detail and the same material language.

Weapons (game id, overall length, triangle budget):
- smg          0.74 m   6 000 to 8 000
- machine_gun  1.04 m   7 000 to 9 000 (belt-fed, bipod folded)
- shotgun      1.04 m   5 000 to 7 000 (pump action)
- marksman     1.12 m   7 000 to 9 000 (scoped; lens opaque)
Lengths must match within 1 mm: the grips and the first-person arms are calibrated to them (docs/tech/WEAPON_MODELS.md).

Export contract (must match exactly):
- One folder per weapon: assets/models/weapons/<id>_realistic/ with <id>_realistic.glb, source/, renders/, textures/ and validation.json in the same shape as the rifle's.
- Godot axes: +Y up, forward = -Z. Real-world metres, applied transforms, identity transform on export.
- Origin at the pistol grip, at the same point as the current tactical_original/<id>.glb (open it and copy the origin and the Muzzle position).
- An empty named exactly Muzzle at the bore's end. The game asserts on it.
- Keep the same separate moving parts and names the current GLB has (magazine, bolt or charging handle, pump on the shotgun, belt cover on the machine gun): the reload clips move them by name.
- No cameras, lights, armatures or animations.
- Materials named exactly as in the rifle where they apply: gunmetal, steel, bore, polymer. Add wood only where the weapon has it. Each with albedo, normal and ORM maps: 2K for gunmetal and polymer, 1K for steel, 256 for bore. Textures generated in Blender or from CC0 sources only; list every source.
- Licence: CC0-1.0, with a LICENSE.txt in each folder.

Deliver: the four folders, three renders per weapon (left side, three-quarter, first-person view at 60 degrees FOV), exact triangle counts, and a list of every part name.
Do not edit anything under game/.
```

## Pedido 2: inimigos comuns e especiais

```text
Task: model the common zombie and five special enemies in Blender 5.2 as GLB for a Godot 4.7 horde shooter that draws up to 300 enemies with MultiMesh. Style: blocky, voxel-like shapes with realistic PBR materials and strong gore, the same language as assets/models/characters/crawler_original/ (read its source and NOTES first). Not an organic sculpt and not a realistic human: three earlier attempts at realistic anatomy were rejected.

Models (file, height, triangle budget):
- walker.glb     1.80 m   1 500 to 2 500   (also used by the Runner, drawn leaner by the shader)
- brute.glb      2.30 m   2 500 to 4 000   (very broad; a plate of scrap armour on the chest and front: it blocks shots from the front)
- grabber.glb    1.90 m   2 000 to 3 500   (long arms, reaching hands)
- bloater.glb    1.80 m   2 500 to 4 000   (swollen belly that bursts)
- screamer.glb   1.75 m   2 000 to 3 500   (thin, jaw wide open, head thrown back)
- behemoth.glb   4.00 m   6 000 to 9 000   (the boss; heavy arms, readable weak head)

Export contract (must match exactly):
- Godot axes: +Y up, forward = -Z. Origin on the ground between the feet. Real-world metres, applied transforms, identity transform on export.
- No armatures, animations, cameras, lights or embedded textures: the game animates by pivots in a shader.
- Separate meshes with the pivot at the joint, named exactly: Head, Torso, Arm_Left, Arm_Right, Leg_Left, Leg_Right. Arm pivots at the shoulder, leg pivots at the hip, Head at the neck. The bloater adds Belly; the brute adds Armor_Front.
- The head must be a clear, separate target: headshots are aimed at it.
- At most 4 PBR materials per model, named from: skin_rot, cloth_shirt, cloth_trousers, flesh_wound, bone, scrap_metal. Base colour, roughness and normal only; shared 1K atlas per model; no transparency.
- The walker must look right with its shirt and trousers recoloured by the game: keep cloth_shirt and cloth_trousers as separate materials with neutral base colours.
- Licence: CC0-1.0, with a LICENSE.txt. No downloaded meshes; textures generated in Blender or CC0, sources listed.

Deliver in assets/models/characters/<name>_original/: the GLB, the .blend, front/side/three-quarter renders, a top-down render at the game camera's distance (16 m away, 9 m up), exact triangle counts and the pivot positions in metres.
Do not edit anything under game/.
```

## Depois da entrega (Claude)

1. Validar cada GLB contra o contrato: eixos, origem, nomes, triângulos e materiais.
2. Integrar as armas pela tabela de modelos de `game/world/weapon_model.gd` e repetir os testes de pega e de mira de `docs/tech/WEAPON_MODELS.md`.
3. Integrar os inimigos um a um, medindo o custo com 150 e com 300 vivos (`tools/dev/bench_frame.gd`). O Crawler custou +0,52 ms com 150; é a referência.
4. O utilizador confirma no editor o aspeto de cada modelo antes de ele passar a ser o modelo por omissão.
