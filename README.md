# Horde Breaker Remake

Remake do Horde Breaker em **Godot 4.7 + GDScript**, reformulado a partir dos
documentos de design do original. Estado: **pré-produção** (design e spikes
técnicos).

- Contexto e regras do projeto: [CLAUDE.md](CLAUDE.md)
- Decisões fechadas: [docs/DECISIONS.md](docs/DECISIONS.md)
- Brainstorm em curso: [docs/design/BRAINSTORM.md](docs/design/BRAINSTORM.md)
- Tarefas para sessões na cloud: [docs/CLOUD_TASKS.md](docs/CLOUD_TASKS.md)
- Documentos do original (referência): [docs/legacy/](docs/legacy/README.md)

## Testar

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_smoke.gd
```
