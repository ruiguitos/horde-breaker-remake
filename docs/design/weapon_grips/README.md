# Empunhaduras por arma — comparação visual

As cinco variantes estão integradas em `FirstPersonArms` e são escolhidas
automaticamente por `ViewModel.set_weapon`.

| Arma | Primeira pessoa | Pega direita | Apoio esquerdo |
|---|---|---|---|
| Rifle | [Ver](rifle_first_person.png) | [Ver](rifle_right.png) | [Ver](rifle_left.png) |
| SMG | [Ver](smg_first_person.png) | [Ver](smg_right.png) | [Ver](smg_left.png) |
| Machine Gun | [Ver](machine_gun_first_person.png) | [Ver](machine_gun_right.png) | [Ver](machine_gun_left.png) |
| Shotgun | [Ver](shotgun_first_person.png) | [Ver](shotgun_right.png) | [Ver](shotgun_left.png) |
| Marksman | [Ver](marksman_first_person.png) | [Ver](marksman_right.png) | [Ver](marksman_left.png) |

Cada arma tem ainda `<arma>_ads.png` e `<arma>_wall.png`, para observar as
poses existentes de mira e retração junto a uma parede. A ótica/ADS que
usa fallback não foi reformulada nesta entrega de mãos.

Imagens reais do Godot 4.7.2, Compatibility, Recruit, fundo neutro,
1280×720, FOV 70°; ADS a 52,5°. Os modelos das armas só são gabaritos
visuais: não estão dentro dos GLBs de braços nem dos seus `.blend`.

[Construção, dimensões e validação](../../../assets/models/characters/weapon_grips_original/NOTES.md).
