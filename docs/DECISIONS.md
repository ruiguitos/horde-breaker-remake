# Decisões

Registo das decisões **fechadas pelo utilizador**. Agentes não editam este
ficheiro: propõem decisões nos seus documentos e o utilizador decide.

Exceção nesta atualização: a 2026-10-11, o utilizador pediu explicitamente
ao agente para registar as seis decisões abaixo. A data do registo não
implica que toda a implementação esteja concluída.

## Fechadas

| Data | Decisão | Razão / notas |
|---|---|---|
| 2026-10-05 | O remake parte dos **documentos de design** do jogo original, não do código nem dos modelos implementados. | O original mudou de identidade várias vezes e acumulou sistemas órfãos. |
| 2026-10-05 | Engine: **Godot 4.7 stable + GDScript tipado**, Forward+. | Continuidade com o original; pipeline e conhecimento já existentes. |
| 2026-10-05 | Câmara: **câmara média**, mais afastada e alta do que a 3ª pessoa sobre o ombro do original, mas sem ir até à câmara alta/isométrica. | Preferência do utilizador após comparar 3ª pessoa vs câmara alta. Parâmetros exatos a definir pelo spike `camera_medium`. **Substituída pela decisão de três modos de 2026-10-11.** |
| 2026-10-05 | Nesta fase: **design + spikes técnicos isolados**. O jogo em `game/` só começa depois de o brainstorm fechar visão, pilares e core loop. | Evitar construir antes de decidir (lição do original). |
| 2026-10-05 | Direção: **A+B "Expedition Breaker"** — horde shooter de expedição por ilhas, single-player. | BRAINSTORM §10; GDD.md. |
| 2026-10-05 | Mira: **auto-fire é o modo normal**, com prioridade pela orientação do personagem (cone para onde olha). Headshots mantêm-se. | O jogador "mira com o corpo"; comando natural. |
| 2026-10-05 | **Breaker**: investida comum a todas as classes (~5 m, empurra/atordoa, solta Grabbers, ~6 s cooldown). | Verbo de movimento principal. |
| 2026-10-05 | **Sprint** (pedido do utilizador; substitui o "sem sprint" anterior): Shift / L3, ×1,6, estamina de 3 s, **sem disparar** enquanto corre. | Fugir ou lutar é uma escolha; não substitui o breaker. |
| 2026-10-05 | Horda: **~150 inimigos ativos, teto de 300** simulados. Flow field + agentes como dados + MultiMesh. | Spike `horde_flowfield`: 150 ≈ 1,3 ms/tick em GDScript. |
| 2026-10-05 | Base: **barco como ecrã de serviços** entre ilhas ("escolhe 1 de 3"), sem construção. **Sem Scrap** no slice. | Lição do original (sistemas órfãos). |
| 2026-10-05 | Progressão: cartas na run (maioria de comportamento), **perks em slots** e meta em **Intel** (morrer conserva o Intel). | Duas camadas claras. |
| 2026-10-05 | Pilares: **Romper a horda · Cada ilha é uma decisão · Builds que mudam a forma de jogar**. | GDD.md §2. |
| 2026-10-05 | Contexto: projeto a solo, por diversão e aprendizagem, sem prazo. Começar já o **vertical slice em grey-box** em `game/`. | Fim da pré-produção. |
| 2026-10-05 | Câmara do slice: preset médio (~35°, ~10 m, FOV 60) com **yaw fixo**. | Spike `camera_medium`; auto-fire dispensa rodar. **Substituída como modo único pela decisão de 2026-10-11; a câmara fixa mantém-se como opção.** |
| 2026-10-05 | **Assets externos permitidos** (pedido do utilizador; substitui "só primitivas"): só com licença livre, registados em `assets/LICENSES.md`. Estilo alvo: low-poly estilizado com boa luz. | Mais qualidade visual e sonora sem arte própria. |
| 2026-10-11 | Câmara: **três modos selecionáveis — 1.ª pessoa, 3.ª pessoa e fixa**. | Substitui a câmara média com yaw fixo como única opção. Modos presentes em `game/core/profile.gd` e `game/world/island.gd`; preferência guardada no perfil. |
| 2026-10-11 | Menus: **redesenho com a paleta B, «Atlântico e azulejo»**. | Escolha feita a 2026-10-10 e registada agora. Basalto, painéis azul-petróleo e texto cal; âmbar para ações e foco. As sete propostas e os estados visuais estão em [MENUS.md](design/MENUS.md). |
| 2026-10-11 | **Power-ups de abate em todas as missões**, incluindo as partes da Berlenga. | Abrange Activate, Defend, Rescue e Holdout. Só têm efeito quando recolhidos; expirar ou sair sem os apanhar significa perdê-los. Implementação descrita em [POWER_UPS_AND_DEFEAT.md](tech/POWER_UPS_AND_DEFEAT.md). |
| 2026-10-11 | Armas: **opção B, com principais trocáveis**. Principais: Assault Rifle, SMG e a nova **Machine Gun**. Secundárias: Shotgun e Marksman Rifle. **Heavy Pistol removida do arsenal aprovado.** | A Marksman cobre a perfuração; a Machine Gun acrescenta fogo pesado e contínuo. Escolher outra principal não perde a propriedade da anterior. **Implementação pendente:** a Machine Gun e a seleção principal/secundária ainda não existem; a Heavy Pistol continua no código atual. Detalhes e consequências em [CARDS_WEAPONS_PERKS.md §E2](design/CARDS_WEAPONS_PERKS.md). |
| 2026-10-11 | **Expedição Berlenga em quatro partes, com transições a pé** e acampamentos entre partes. | Escolha feita a 2026-10-08 e registada agora. Viagem própria, fora do sorteio Beach: Carreiro do Mosteiro → Planalto do Farol → Costa Sudoeste → Forte de São João Baptista. Vida, armas e cartas transitam; o barco de resgate surge no final. Escala e percurso em [BERLENGA_EXPEDITION.md](design/BERLENGA_EXPEDITION.md). |
| 2026-10-11 | Licenças: **aceite a exceção CC BY 4.0 para as texturas do céu noturno do Sky3D**, com atribuição obrigatória nos créditos. | Aplica-se a `Milkyway.jpg` e `StarField.jpg`, de ESO/S. Brunier; não autoriza indiscriminadamente outros assets CC BY. Crédito: «The Milky Way panorama by ESO/S. Brunier, licensed under CC BY 4.0 and used in original and modified forms.» Registo em [LICENSES.md](../assets/LICENSES.md); regra já presente em `CLAUDE.md`. |

## Em aberto

- Valores de jogo (HP, dano, velocidades, cooldowns): hipóteses de playtest em `game/data/catalog.gd`.
- Humor DRG: onde aparece (texto, rádio, nomes).
- Dificuldade à Hazard: depois do slice.
