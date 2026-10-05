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

## Em aberto (a decidir com o utilizador)

1. **Direção do jogo:** A "Expedition Survivors", B "Horde shooter tático",
   C "Sortie & Siege", ou uma mistura (ver `design/BRAINSTORM.md`). A câmara
   média aproxima-se de uma mistura A+B.
2. **Mira:** manual, assistida ou auto-fire opcional; e o papel dos headshots.
3. **Escala da horda:** dezenas com especiais inteligentes vs centenas.
4. **Base:** acampamento/construção, barco como base móvel, ou nenhuma.
5. **Pilares** e pitch de uma frase.
6. **Contexto do projeto:** solo? objetivo (Steam, portfólio, aprendizagem)? prazo?
