# Pedido ao Codex: braços e mãos em primeira pessoa (F2 e F3, 2026-10-18)

Para colar na janela do Codex (ele trabalha no Blender; a integração é do Claude).
Quando o modelo chegar, a integração segue o `WEAPON_MODELS.md` (secção de
primeira pessoa): o Claude liga os ossos ao `TwoBoneIK3D` e testa as posições
das mãos contra os pontos de pega medidos no GLB das armas.

## Porque é preciso

Hoje a primeira pessoa mostra a arma com uma luva e uma manga em caixas
(`game/world/view_model.gd`). Para a mão agarrar o punho, o guarda-mãos e o
carregador de forma credível, é preciso um braço direito e um esquerdo com
esqueleto. Este brief pede os dois braços, com ossos prontos para IK.

## Parte 1: braços e mãos (F2)

```text
Task: model two first-person arms and hands (right and left) in Blender 5.x
and export them as one skinned GLB for a Godot 4.7 first-person shooter. They
hold a rifle, seen from the player's eye; they must read as real hands holding
a real gun, in the same blocky language as the other characters.

Frame and units:
- Real-world metres, applied transforms.
- Origin = the RIGHT HAND GRIP POINT on the rifle grip (the pistol grip, where
  the right palm closes around it). Gun space: +Y up, forward = -Z.
- The rifle itself is NOT in the file. Only arms and hands.
- No cameras, lights, animations or embedded textures.

Placement (in gun space, the rifle lies along -Z):
- Right hand: palm and fingers closed around the pistol grip, thumb on the
  left side of the grip, index finger along the trigger guard. The wrist sits
  about 0.06 m behind and below the grip origin.
- Left hand: the palm rests under the handguard. The contact point is at
  (0, 0.077, -0.26) m in gun space: the centre of the left palm must be there.
- Both upper arms come from the shoulders, outside the view (the shoulders
  are out of frame; only forearms, hands and the sleeve cuffs are visible).
  Bend the elbows so the forearms run forward and down from the hands.

Skeleton (armature with these bones, names exact):
- Shoulder_R, UpperArm_R, Forearm_R, Hand_R
- Shoulder_L, UpperArm_L, Forearm_L, Hand_L
- Upper arm and forearm each about 0.30 m; the bones are straight in the rest
  pose so a two-bone IK can solve them. Bend direction: the elbows point down
  and outward.
- Hands: bone at the wrist, fingers as separate meshes parented to the hand
  bone (they do not need to bend in the rest pose).
- Weights: each vertex on one bone (rigid parts), with a 50/50 blend only at
  the wrist, so the wrist does not tear.

Meshes and materials (one PBR material each, named exactly):
- sleeve_cloth: the jacket sleeve, a cuff at the wrist. Plain fabric, no print.
- glove: a dark work glove over the hand (fingers), matte.
- skin: bare skin on the knuckles and a small gap between glove and cuff.

Budget and export contract:
- File name: arms_firstperson.glb.
- 2 000 to 6 000 triangles in total. Report the exact count.
- One armature, both arms skinned to it. Report the bone names and their
  rest positions in gun space (the integration checks them).
- Name the armature "Arms".
```

## Parte 2: as animações de recarga (F3)

Só depois de a Parte 1 estar aceite. A recarga real do jogo é cronometrada e
o código já move o carregador e o punho do ferrolho (`ViewModel.reload_offset`
e `ViewModel.charge_offset`). As mãos têm de seguir esse movimento, e não
inventar um movimento próprio.

```text
Task: add reload animation to the same arms GLB, as clips the game plays by
progress (0 to 1), not by time. Export the clips in the same file.

Reload progress (p, 0 to 1) and what the magazine does (the code moves the gun):
- Magazine drops 0.12 m in gun space (straight down, -Y) over p 0.00 to 0.30,
  held down to 0.70, back into the gun by 1.00.
- Charging handle is pulled 0.03 m rearward (+Z) between p 0.80 and 1.00,
  then released.

Clips to create (one clip each, with the full range 0 to 1 mapped to the clip
length; the length does not matter, the game samples by progress):
- "reload_mag_smg": right hand takes the magazine: p 0.00 right hand on the
  grip, p 0.10 to 0.30 hand moves down to the magazine base (the magazine
  follows the hand), p 0.30 to 0.70 hand holds the magazine low, p 0.70 to 0.95
  hand brings the new magazine up and seats it, p 0.95 to 1.00 hand back on
  the grip. Left hand stays on the handguard throughout.
- "reload_mag_mg": the Machine Gun is belt-fed: right hand pulls the charging
  slide (not the magazine). Pull at p 0.80 to 0.95, release by 1.00.
- Left hand stays on the handguard in every clip (it never leaves the support point).

Constraints:
- The hands' end positions match the rest pose at p 0.00 and p 1.00 exactly.
- No hand passes through the gun body: the sleeve may pass the magazine well.
- Report each clip's keyframe times and the bone positions at p 0.5.
```

## Como se verifica

- Parte 1: as mãos chegam aos pontos de pega com erro menor que 1 mm
  (`tests/test_arms.gd`, a criar com o modelo).
- Parte 2: a posição da mão a p 0,5 coincide com o carregador em
  `reload_offset(0.5)`, com a mesma tolerância.
- Visual: capturas em `tools/dev/zombie_preview.gd -- <png> fpads_<arma>` e
  `fpreload_<arma>` (janela, GPU). A avaliação final é tua, no editor.

## Notas de licença

O modelo é do Codex e segue a regra do projeto: geometria original, sem
texturas descarregadas. Registar em `assets/LICENSES.md` com CC0-1.0, como os
restantes modelos originais.
