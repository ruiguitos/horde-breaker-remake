# Pedido ao Codex: modelo do Crawler (2026-10-17)

Para colar na janela do Codex (ele trabalha no Blender; o código de integração é do Claude).

```text
Task: model one realistic-blocky CRAWLER zombie in Blender 5.x and export it as GLB for a Godot 4.7 horde shooter.

Look and proportions:
- Blocky, voxel-like shapes (the same language as the player models), with realistic materials. Not organic sculpt.
- A human zombie with BOTH LEGS MISSING at the hips. It drags itself forward on its arms.
- Body low to the ground: the torso is about 0.44 m above the ground (chest), the head about 0.69 m above the ground, looking forward and slightly up.
- Arms bent at the elbows, forearms and hands flat on the ground, reaching forward.
- Two hip stumps: short torn stubs of trousers, with flesh and a pale bone tip. Clearly readable.
- Strong gore: open wounds on the back and torso, dried and fresh blood, torn shirt, exposed rib cage on one side, missing fingers on one hand. Keep the shapes blocky.
- Overall length about 1.3 m from head to stumps, width about 0.6 m.

Export contract (must match exactly):
- File name: crawler.glb.
- Godot axes: +Y up, forward = -Z.
- Origin on the ground, centred under the hips, identity transform on export.
- Real-world metres, applied transforms.
- No cameras, lights, armatures, animations or embedded textures.
- Named nodes, exactly: Head, Torso, Arm_Left, Arm_Right, Hip_Stump_Left, Hip_Stump_Right, Hand_Left, Hand_Right. Each part is a separate mesh with its pivot at its joint (Arm pivot at the shoulder, Head pivot at the neck, Hip stump pivot at the hip).
- Triangles: 2 000 to 5 000 total. Report the exact count.

Materials (one PBR material each, named exactly):
- skin_rot (rotting grey-green skin, base colour, roughness high)
- cloth_shirt (torn shirt, dark, fabric)
- cloth_trousers (torn trousers, dark, fabric)
- flesh_wound (dark red, slightly glossy)
- bone (off-white, rough)
- hair_dark
- Set base colour, metallic (0 for all) and roughness. No textures in the file; the game applies its own texture maps.

UVs: one non-overlapping UV layout in 0 to 1 for each mesh, with an even texel density, so textures can be applied later. Export normals and tangents.

Realism checks before exporting:
- Each part is a closed solid with positive volume and no degenerate faces.
- The head and the hands touch the ground line at the right heights (head 0.69 m, chest 0.44 m).
- No part passes through the ground by more than 2 cm.

Deliverables:
- crawler.glb, crawler.blend, the Python build script that makes it (Blender built-in modules only, runnable headless: blender --background --factory-startup --python build_crawler.py).
- Front, side and three-quarter preview PNGs on a grey background.
- validation.json: head and chest height above the ground, total length and width, triangle count, node names, material names, origin check, UV check, normals and tangents check.
- NOTES.md: the reference used for the proportions (public anatomy or a public zombie-style reference, no copied meshes) and any simplifications.
```

Quando o Codex terminar, traz o zip. Eu confiro as medidas, os nomes dos nós e a pose no Godot.
