---
titulo: "README.md"
tipo: "referencia"
estado: "referencia_a_confrontar"
atualizado: "2026-11-15"
tags: ["horde-breaker", "referencia"]
fontes: ["README.md"]
---

# README.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original.

Fonte: `README.md` · SHA-256: `91a76cd3408fb82e1d134bc8ac8ae49c5a5348bdd965f0fff04e25055e03214f`

# Horde Breaker Remake

Remake do Horde Breaker em **Godot 4.7 + GDScript**, reformulado a partir dos
documentos de design do original. Estado: **vertical slice jogável em grey-box**.

- Contexto e regras do projeto: [[90 Referências/CLAUDE - referência|CLAUDE.md]]
- Decisões fechadas: [[90 Referências/docs/DECISIONS|docs/DECISIONS.md]]
- Brainstorm em curso: [[90 Referências/docs/design/BRAINSTORM|docs/design/BRAINSTORM.md]]
- Propostas de design: [[90 Referências/docs/design/GDD|GDD]],
  [[90 Referências/docs/design/COMBAT_AND_ENEMIES|combate e inimigos]],
  [[90 Referências/docs/design/PROGRESSION_AND_ECONOMY|progressão]],
  [[90 Referências/docs/design/WORLD_AND_MISSIONS|mundo e missões]],
  [[90 Referências/docs/design/CAMERA_CONTROLS_HUD|câmara, controlos e HUD]]
- Arquitetura técnica: [[90 Referências/docs/tech/ARCHITECTURE|docs/tech/ARCHITECTURE.md]]
- Spikes: [[90 Referências/spikes/camera_medium/README|camera_medium]],
  [[90 Referências/spikes/horde_flowfield/README|horde_flowfield]],
  [[90 Referências/spikes/director/README|director]]
- Documentos do original (referência): [[90 Referências/docs/legacy/README|docs/legacy/]]

## Jogar

Ver [[90 Referências/game/README|game/README.md]]: abrir a pasta no Godot 4.7 e carregar
em F5.

## Testar

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd   # todos os testes
```
