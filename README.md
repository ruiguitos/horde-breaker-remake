# Horde Breaker Remake

Remake do Horde Breaker em **Godot 4.7 + GDScript**, reformulado a partir dos
documentos de design do original. Estado: **vertical slice jogável em grey-box**.

- Contexto e regras do projeto: [CLAUDE.md](CLAUDE.md)
- Decisões fechadas: [docs/DECISIONS.md](docs/DECISIONS.md)
- Brainstorm em curso: [docs/design/BRAINSTORM.md](docs/design/BRAINSTORM.md)
- Propostas de design: [GDD](docs/design/GDD.md),
  [combate e inimigos](docs/design/COMBAT_AND_ENEMIES.md),
  [progressão](docs/design/PROGRESSION_AND_ECONOMY.md),
  [mundo e missões](docs/design/WORLD_AND_MISSIONS.md),
  [câmara, controlos e HUD](docs/design/CAMERA_CONTROLS_HUD.md)
- Arquitetura técnica: [docs/tech/ARCHITECTURE.md](docs/tech/ARCHITECTURE.md)
- Spikes: [camera_medium](spikes/camera_medium/README.md),
  [horde_flowfield](spikes/horde_flowfield/README.md),
  [director](spikes/director/README.md)
- Documentos do original (referência): [docs/legacy/](docs/legacy/README.md)

## Jogar

Ver [game/README.md](game/README.md): abrir a pasta no Godot 4.7 e carregar
em F5.

## Testar

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd   # todos os testes
```
