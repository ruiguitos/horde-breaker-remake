# Decisões

Registo das decisões **fechadas pelo utilizador**. Agentes não editam este
ficheiro: propõem decisões nos seus documentos e o utilizador decide.

## Fechadas

| Data | Decisão | Razão / notas |
|---|---|---|
| 2026-10-05 | O remake parte dos **documentos de design** do jogo original, não do código nem dos modelos implementados. | O original mudou de identidade várias vezes e acumulou sistemas órfãos. |
| 2026-10-05 | Engine: **Godot 4.7 stable + GDScript tipado**, Forward+. | Continuidade com o original; pipeline e conhecimento já existentes. |
| 2026-10-05 | Câmara: **câmara média**, mais afastada e alta do que a 3ª pessoa sobre o ombro do original, mas sem ir até à câmara alta/isométrica. | Preferência do utilizador após comparar 3ª pessoa vs câmara alta. Parâmetros exatos a definir pelo spike `camera_medium`. |
| 2026-10-05 | Nesta fase: **design + spikes técnicos isolados**. O jogo em `game/` só começa depois de o brainstorm fechar visão, pilares e core loop. | Evitar construir antes de decidir (lição do original). |
| 2026-10-05 | Direção: **A+B "Expedition Breaker"** — horde shooter de expedição por ilhas, single-player. | BRAINSTORM §10; GDD.md. |
| 2026-10-05 | Mira: **auto-fire é o modo normal**, com prioridade pela orientação do personagem (cone para onde olha). Headshots mantêm-se. | O jogador "mira com o corpo"; comando natural. |
| 2026-10-05 | **Breaker**: investida comum a todas as classes (~5 m, empurra/atordoa, solta Grabbers, ~6 s cooldown). Sem sprint. | Único verbo de movimento especial. |
| 2026-10-05 | Horda: **~150 inimigos ativos, teto de 300** simulados. Flow field + agentes como dados + MultiMesh. | Spike `horde_flowfield`: 150 ≈ 1,3 ms/tick em GDScript. |
| 2026-10-05 | Base: **barco como ecrã de serviços** entre ilhas ("escolhe 1 de 3"), sem construção. **Sem Scrap** no slice. | Lição do original (sistemas órfãos). |
| 2026-10-05 | Progressão: cartas na run (maioria de comportamento), **perks em slots** e meta em **Intel** (morrer conserva o Intel). | Duas camadas claras. |
| 2026-10-05 | Pilares: **Romper a horda · Cada ilha é uma decisão · Builds que mudam a forma de jogar**. | GDD.md §2. |
| 2026-10-05 | Contexto: projeto a solo, por diversão e aprendizagem, sem prazo. Começar já o **vertical slice em grey-box** em `game/`. | Fim da pré-produção. |
| 2026-10-05 | Câmara do slice: preset médio (~35°, ~10 m, FOV 60) com **yaw fixo**. | Spike `camera_medium`; auto-fire dispensa rodar. |

## Em aberto

- Valores de jogo (HP, dano, velocidades, cooldowns): hipóteses de playtest em `game/data/catalog.gd`.
- Humor DRG: onde aparece (texto, rádio, nomes).
- Dificuldade à Hazard: depois do slice.
