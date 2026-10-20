# Pedidos pendentes ao Codex (2026-10-20)

Cada pedido é um bloco para colar na janela do Codex. Está tudo o que ele
precisa; não é preciso ler mais nada. Quando ele entregar, o Claude integra.

## 1. Animação de recarga dos braços (SMG e Machine Gun)

Só estas duas armas têm recarga cronometrada: SMG 1,1 s e Machine Gun 3,2 s
(`game/data/weapons/*.tres`). AR, Marksman e Shotgun recarregam sem
temporizador, por isso não precisam de clip.

As cinco variantes de braços já estão aceites (`assets/models/characters/weapon_grips_original/`,
construtor `build_weapon_grips.py`, fontes em `source/arms_<arma>.blend`).

```text
Task: add two reload clips to the existing first-person arm files, sampled by
reload progress p (0 to 1), not by time. Do not change the rest pose, the
bones, the materials, the support points or the grips.

Files (same build, one clip in each):
- assets/models/characters/weapon_grips_original/smg/arms_firstperson.glb
  -> clip "reload_mag_smg"
- assets/models/characters/weapon_grips_original/machine_gun/arms_firstperson.glb
  -> clip "reload_mag_mg"
Update the sources too (source/arms_smg.blend, source/arms_machine_gun.blend)
so the rebuild reproduces the clips.

What the game moves (the code moves the gun and its parts; the hands follow it):
- SMG magazine: drops 0.12 m in gun space (straight down, -Y) over p 0.00 to
  0.30, held down to p 0.70, back into the gun by p 1.00. Formula in
  game/world/view_model.gd, reload_offset(p).
- Machine Gun charging slide: pulled 0.03 m rearward (+Z) between p 0.80 and
  1.00, then released (charge_offset(p)). The belt is not moved.

Clip requirements:
- "reload_mag_smg": at p 0.00 the right hand is on the grip, exactly the rest
  pose. From p 0.10 to 0.30 the right hand moves down to the magazine base and
  keeps it, so at p 0.50 the right palm sits on the magazine at its dropped
  position (magazine base y - 0.12 m, gun space). From p 0.70 to 0.95 the hand
  brings the new magazine up and seats it. From p 0.95 to 1.00 it returns to
  the grip. The left hand stays on the SMG support point for the whole clip.
- "reload_mag_mg": the right hand stays on the grip except p 0.80 to 0.95,
  when it pulls the charging slide 0.03 m rearward, releasing it by p 1.00.
  The left hand stays on the Machine Gun support point for the whole clip.

Constraints:
- p 0.00 and p 1.00 match the rest pose of each file exactly (the hands are
  where the grip is, within 0.1 mm).
- At p 0.50 (SMG) the right palm is within 1 mm of the magazine's dropped
  position: the magazine is moved by the code, so the hand must reach it, not
  the other way round.
- The left hand never leaves its support point (within 0.1 mm) in either clip.
- No hand or forearm passes through the gun body; the sleeve may pass the
  magazine.
- Keep the file's 8 bones (Shoulder/UpperArm/Forearm/Hand, L and R) and the
  three materials. No cameras, lights, weapon meshes or textures.

Deliver, per clip:
- keyframe times in seconds, and the length of the clip (the game samples by
  p, so the length only sets the resolution);
- the right-hand position at p 0.00, 0.25, 0.50, 0.75 and 1.00 in gun space,
  and the magazine position it must match at p 0.50;
- the triangle count of each file (unchanged expected).
- Update `validation.json` and `grip_validation.json` of each variant, and
  `NOTES.md` with a paragraph on the two clips.

Licence: geometry and clips are original, CC0-1.0, as the other arm files.
```

## Prompts ainda por decidir

Não há mais pedidos ao Codex enquanto estes dois itens não tiverem decisão tua:

- Animação de recarga da AR (tempo de recarga ainda não decidido).
- Motor (proposta em `docs/tech/ENGINE_MIGRATION.md`).
