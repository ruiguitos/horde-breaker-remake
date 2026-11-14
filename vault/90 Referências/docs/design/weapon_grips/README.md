---
titulo: "docs/design/weapon_grips/README.md"
tipo: "referencia"
estado: "referencia_a_confrontar"
atualizado: "2026-11-14"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/design/weapon_grips/README.md"]
---

# docs/design/weapon_grips/README.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original. Pode conter propostas e regras antigas. Confrontar com as decisões datadas e com os recursos atuais.

Fonte: `docs/design/weapon_grips/README.md` · SHA-256: `f2b448d838e2a6f409ff12e6698870b4f7fb098dedc75b60da58f2471019dc82`

# Empunhaduras por arma — comparação visual

As cinco variantes estão integradas em `FirstPersonArms` e são escolhidas
automaticamente por `ViewModel.set_weapon`.

| Arma | Primeira pessoa | Pega direita | Apoio esquerdo |
|---|---|---|---|
| Rifle | Ver (`docs/design/weapon_grips/rifle_first_person.png`) | Ver (`docs/design/weapon_grips/rifle_right.png`) | Ver (`docs/design/weapon_grips/rifle_left.png`) |
| SMG | Ver (`docs/design/weapon_grips/smg_first_person.png`) | Ver (`docs/design/weapon_grips/smg_right.png`) | Ver (`docs/design/weapon_grips/smg_left.png`) |
| Machine Gun | Ver (`docs/design/weapon_grips/machine_gun_first_person.png`) | Ver (`docs/design/weapon_grips/machine_gun_right.png`) | Ver (`docs/design/weapon_grips/machine_gun_left.png`) |
| Shotgun | Ver (`docs/design/weapon_grips/shotgun_first_person.png`) | Ver (`docs/design/weapon_grips/shotgun_right.png`) | Ver (`docs/design/weapon_grips/shotgun_left.png`) |
| Marksman | Ver (`docs/design/weapon_grips/marksman_first_person.png`) | Ver (`docs/design/weapon_grips/marksman_right.png`) | Ver (`docs/design/weapon_grips/marksman_left.png`) |

Cada arma tem ainda `<arma>_ads.png` e `<arma>_wall.png`, para observar as
poses existentes de mira e retração junto a uma parede. A ótica/ADS que
usa fallback não foi reformulada nesta entrega de mãos.

Imagens reais do Godot 4.7.2, Compatibility, Recruit, fundo neutro,
1280×720, FOV 70°; ADS a 52,5°. Os modelos das armas só são gabaritos
visuais: não estão dentro dos GLBs de braços nem dos seus `.blend`.

[[90 Referências/assets/models/characters/weapon_grips_original/NOTES|Construção, dimensões e validação]].
