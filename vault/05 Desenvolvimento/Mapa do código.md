---
titulo: "Mapa do código"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["game/audio/ambience.gd", "game/audio/music.gd", "game/audio/sfx.gd", "game/core/dev_options.gd", "game/core/game_input.gd", "game/core/graphics_settings.gd", "game/core/profile.gd", "game/core/run_context.gd", "game/data/briefing.gd", "game/data/expeditions.gd", "game/data/game_data.gd", "game/data/origin_ending.gd", "game/data/resources/biome_data.gd", "game/data/resources/card_data.gd", "game/data/resources/class_data.gd", "game/data/resources/enemy_data.gd", "game/data/resources/mission_data.gd", "game/data/resources/modifier_data.gd", "game/data/resources/perk_data.gd", "game/data/resources/power_up_data.gd", "game/data/resources/weapon_data.gd", "game/data/story.gd", "game/horde/flow_field.gd", "game/horde/horde.gd", "game/main.gd", "game/states/armory.gd", "game/states/boat.gd", "game/states/camp.gd", "game/states/debrief.gd", "game/states/title.gd", "game/ui/armory_art.gd", "game/ui/armory_shelter.gd", "game/ui/class_preview.gd", "game/ui/credits_panel.gd", "game/ui/dev_menu.gd", "game/ui/dev_sandbox.gd", "game/ui/dev_test_panel.gd", "game/ui/dialogue_box.gd", "game/ui/dialogue_voice.gd", "game/ui/dossier.gd", "game/ui/focus_brackets.gd", "game/ui/hud.gd", "game/ui/input_icons.gd", "game/ui/island_end_panel.gd", "game/ui/loading_screen.gd", "game/ui/marked_box.gd", "game/ui/menu_dialog.gd", "game/ui/minimap.gd", "game/ui/perk_node_view.gd", "game/ui/portrait.gd", "game/ui/route_map.gd", "game/ui/route_preview.gd", "game/ui/scope_overlay.gd", "game/ui/settings_panel.gd", "game/ui/typewriter.gd", "game/ui/ui_sfx.gd", "game/ui/ui_theme.gd", "game/world/beach_vegetation.gd", "game/world/card_offers.gd", "game/world/crawler_body.gd", "game/world/director.gd", "game/world/escort_model.gd", "game/world/first_person_arms.gd", "game/world/foot_contact.gd", "game/world/fx.gd", "game/world/grading.gd", "game/world/handmade/handmade_island.gd", "game/world/handmade/scatter.gd", "game/world/island.gd", "game/world/island_map.gd", "game/world/island_props.gd", "game/world/island_roads.gd", "game/world/island_run.gd", "game/world/island_terrain.gd", "game/world/nature_kit.gd", "game/world/power_ups.gd", "game/world/recruit_rifle_hold.gd", "game/world/scenery_kit.gd", "game/world/soldier_model.gd", "game/world/special_enemy_model.gd", "game/world/view_model.gd", "game/world/visuals.gd", "game/world/weapon_model.gd", "game/world/weapon_support_hold.gd", "game/world/zombie_horde_view.gd", "game/world/zombie_model.gd"]
---

# Mapa do código

← [[05 Desenvolvimento/Desenvolvimento]]

Inventário estático dos 86 scripts próprios em `game/`; não é prova de execução.

| Ficheiro | Classe | Base | Funções de topo |
|---|---|---|---|
| `game/audio/ambience.gd` | Ambience | AudioStreamPlayer | 4 |
| `game/audio/music.gd` | Music | Node | 7 |
| `game/audio/sfx.gd` | Sfx | Node | 11 |
| `game/core/dev_options.gd` | DevOptions | RefCounted | 5 |
| `game/core/game_input.gd` | GameInput | RefCounted | 15 |
| `game/core/graphics_settings.gd` | GraphicsSettings | RefCounted | 7 |
| `game/core/profile.gd` | Profile | RefCounted | 48 |
| `game/core/run_context.gd` | RunContext | RefCounted | 21 |
| `game/data/briefing.gd` | Briefing | RefCounted | 2 |
| `game/data/expeditions.gd` | Expeditions | RefCounted | 7 |
| `game/data/game_data.gd` | GameData | RefCounted | 46 |
| `game/data/origin_ending.gd` | OriginEnding | RefCounted | 3 |
| `game/data/resources/biome_data.gd` | BiomeData | Resource | 0 |
| `game/data/resources/card_data.gd` | CardData | Resource | 0 |
| `game/data/resources/class_data.gd` | ClassData | Resource | 0 |
| `game/data/resources/enemy_data.gd` | EnemyData | Resource | 0 |
| `game/data/resources/mission_data.gd` | MissionData | Resource | 0 |
| `game/data/resources/modifier_data.gd` | ModifierData | Resource | 0 |
| `game/data/resources/perk_data.gd` | PerkData | Resource | 0 |
| `game/data/resources/power_up_data.gd` | PowerUpData | Resource | 0 |
| `game/data/resources/weapon_data.gd` | WeaponData | Resource | 0 |
| `game/data/story.gd` | Story | RefCounted | 4 |
| `game/horde/flow_field.gd` | FlowField | RefCounted | 13 |
| `game/horde/horde.gd` | Horde | RefCounted | 15 |
| `game/main.gd` | — | Node | 14 |
| `game/states/armory.gd` | — | Control | 48 |
| `game/states/boat.gd` | — | Control | 57 |
| `game/states/camp.gd` | — | "res://game/states/boat.gd" | 8 |
| `game/states/debrief.gd` | — | Control | 26 |
| `game/states/title.gd` | — | Node | 25 |
| `game/ui/armory_art.gd` | — | RefCounted | 5 |
| `game/ui/armory_shelter.gd` | — | ClassPreview | 24 |
| `game/ui/class_preview.gd` | ClassPreview | SubViewportContainer | 3 |
| `game/ui/credits_panel.gd` | — | MenuDialog | 5 |
| `game/ui/dev_menu.gd` | DevMenu | Control | 14 |
| `game/ui/dev_sandbox.gd` | DevSandbox | RefCounted | 11 |
| `game/ui/dev_test_panel.gd` | DevTestPanel | VBoxContainer | 19 |
| `game/ui/dialogue_box.gd` | DialogueBox | CanvasLayer | 15 |
| `game/ui/dialogue_voice.gd` | DialogueVoice | AudioStreamPlayer | 4 |
| `game/ui/dossier.gd` | Dossier | RefCounted | 17 |
| `game/ui/focus_brackets.gd` | FocusBrackets | StyleBox | 1 |
| `game/ui/hud.gd` | Hud | CanvasLayer | 67 |
| `game/ui/input_icons.gd` | InputIcons | RefCounted | 7 |
| `game/ui/island_end_panel.gd` | IslandEndPanel | Control | 15 |
| `game/ui/loading_screen.gd` | LoadingScreen | CanvasLayer | 20 |
| `game/ui/marked_box.gd` | MarkedBox | StyleBox | 5 |
| `game/ui/menu_dialog.gd` | MenuDialog | Control | 16 |
| `game/ui/minimap.gd` | Minimap | Control | 11 |
| `game/ui/perk_node_view.gd` | — | RefCounted | 2 |
| `game/ui/portrait.gd` | Portrait | Control | 10 |
| `game/ui/route_map.gd` | RouteMap | Control | 3 |
| `game/ui/route_preview.gd` | RoutePreview | Control | 14 |
| `game/ui/scope_overlay.gd` | — | Control | 2 |
| `game/ui/settings_panel.gd` | SettingsPanel | MenuDialog | 23 |
| `game/ui/typewriter.gd` | Typewriter | RefCounted | 6 |
| `game/ui/ui_sfx.gd` | UiSfx | Node | 5 |
| `game/ui/ui_theme.gd` | UiTheme | RefCounted | 45 |
| `game/world/beach_vegetation.gd` | BeachVegetation | Node3D | 10 |
| `game/world/card_offers.gd` | CardOffers | RefCounted | 10 |
| `game/world/crawler_body.gd` | CrawlerBody | RefCounted | 16 |
| `game/world/director.gd` | Director | RefCounted | 10 |
| `game/world/escort_model.gd` | EscortModel | Node3D | 7 |
| `game/world/first_person_arms.gd` | FirstPersonArms | Node3D | 9 |
| `game/world/foot_contact.gd` | — | SkeletonModifier3D | 7 |
| `game/world/fx.gd` | Fx | Node3D | 7 |
| `game/world/grading.gd` | Grading | RefCounted | 3 |
| `game/world/handmade/handmade_island.gd` | HandmadeIsland | Node3D | 26 |
| `game/world/handmade/scatter.gd` | Scatter | MultiMeshInstance3D | 5 |
| `game/world/island.gd` | — | Node3D | 100 |
| `game/world/island_map.gd` | IslandMap | RefCounted | 30 |
| `game/world/island_props.gd` | IslandProps | RefCounted | 4 |
| `game/world/island_roads.gd` | IslandRoads | RefCounted | 10 |
| `game/world/island_run.gd` | IslandRun | RefCounted | 270 |
| `game/world/island_terrain.gd` | IslandTerrain | RefCounted | 4 |
| `game/world/nature_kit.gd` | NatureKit | RefCounted | 3 |
| `game/world/power_ups.gd` | PowerUps | RefCounted | 9 |
| `game/world/recruit_rifle_hold.gd` | — | SkeletonModifier3D | 2 |
| `game/world/scenery_kit.gd` | — | RefCounted | 4 |
| `game/world/soldier_model.gd` | SoldierModel | Node3D | 28 |
| `game/world/special_enemy_model.gd` | — | RefCounted | 4 |
| `game/world/view_model.gd` | ViewModel | Node3D | 15 |
| `game/world/visuals.gd` | Visuals | RefCounted | 5 |
| `game/world/weapon_model.gd` | WeaponModel | Node3D | 12 |
| `game/world/weapon_support_hold.gd` | — | SkeletonModifier3D | 3 |
| `game/world/zombie_horde_view.gd` | ZombieHordeView | Node3D | 16 |
| `game/world/zombie_model.gd` | ZombieModel | RefCounted | 24 |
