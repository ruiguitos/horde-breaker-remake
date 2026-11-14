---
titulo: "Arma — Machine Gun"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "weapons"]
fontes: ["game/data/weapons/machine_gun.tres", "game/data/resources/weapon_data.gd"]
---

# Arma — Machine Gun

← [[02 Conteúdo/Armas|Armas]]

Heavy primary. 90-round magazine, -20% movement, 3.2 s reload. Infinite reserve.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `machine_gun` · **Nome no jogo:** Machine Gun

| Campo | Valor | Origem |
|---|---|---|
| Dano base (HP) | 18.0 | `.tres` |
| Cadência (tiros/s) | 12.0 | `.tres` |
| Alcance (m) | 32.0 | `.tres` |
| Projéteis por disparo | 1 | Por defeito no Resource |
| Dispersão (graus) | 4.0 | `.tres` |
| Alvos por projétil | 1 | Por defeito no Resource |
| Reserva (-1 = infinita) | -1 | Por defeito no Resource |
| Empurrão (m) | 0.1 | `.tres` |
| Carregador (0 = sem carregador) | 90 | `.tres` |
| Desbloqueio (Intel) | 120 | `.tres` |
| Arma principal | Sim | `.tres` |
| Recarga (s) | 3.2 | `.tres` |
| Multiplicador de movimento | 0.8 | `.tres` |
| Multiplicador de dano próximo | 1.0 | Por defeito no Resource |
| Distância do bónus próximo (m) | 0.0 | Por defeito no Resource |

## Fontes

- `game/data/weapons/machine_gun.tres`
- `game/data/resources/weapon_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
