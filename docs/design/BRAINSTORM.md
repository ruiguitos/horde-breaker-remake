# Brainstorm do remake

Sessão de 2026-10-05. Base: documentos de design do original
(`docs/legacy/`), sem olhar para o código. **Isto são ideias em discussão,
não decisões**: as decisões fechadas vivem em `docs/DECISIONS.md`.

Estrutura usada (pré-produção): diagnóstico → visão → loops → sistemas →
mundo → progressão → UX → tecnologia → produção.

## 0. Diagnóstico do original

1. **Identidade mudou quatro vezes**: arena por vagas → mundo aberto com
   setores e base → survivors-like → expedição num arquipélago. Cada fase
   deixou sistemas que já não pertenciam ao jogo (acampamento, construção
   livre, torres, POIs, streaming de setores).
2. **Conflito no combate**: auto-fire + orbes + cartas (survivors) contra
   hitscan com headshot ×2, mira sobre o ombro e munição escassa (shooter
   tático). Auto-fire a gastar munição escassa frustra; headshots pouco
   importam se a arma dispara sozinha. "O disparo manual fica?" ficou por
   decidir no backlog — é a decisão mais importante do jogo.
3. **3ª pessoa contra uma horda de 360°** obrigou a radar, arcos de dano,
   prioridade de especiais e alertas: interface a compensar a câmara.
4. **Progressão com camadas a mais**: Scrap, Credits, XP de run, XP de
   personagem, cartas, skill tree (57 compras por classe), ARMORY, mastery,
   variantes, evoluções, melhorias da base, outposts. Quase tudo "+X%".
5. **Mundo grande para o conteúdo**: 768 × 768 m, sete ilhas, duas com
   missões mais finas, navegação da horda entregue tarde.
6. **Documentação a sufocar o projeto**: 24 documentos, PROGRESS com 3800
   linhas, listas de prioridades concorrentes.

**A guardar:** fantasia da expedição (escolher rota, missão por ilha, boss,
extrair), diretor de horda com orçamento, disciplina de medir e testar,
pipeline de assets CC0.

## 1. Visão — três direções

| | A — Expedition Survivors | B — Horde shooter tático | C — Sortie & Siege |
|---|---|---|---|
| Câmara | alta / isométrica, twin-stick | 3ª pessoa sobre o ombro | isométrica |
| Fantasia | poder: centenas de zombies a cair | tensão: cada bala conta | preparar a base, sair, defender |
| Horda | 200–500 | 30–80 + especiais inteligentes | ondas por noite |
| Referências | DRG Survivor, Helldivers 1, Alienation | L4D2, Vermintide, WWZ | Riftbreaker, They Are Billions |
| Aproveita | cartas, orbes, arquipélago | munição, headshots, classes | torres, construção, tiers |
| Risco | género saturado | IA/animação caras; brilha em co-op | dois jogos num |

Recomendação inicial: A com mira manual. **O utilizador preferiu a câmara
média**, o que aponta para uma mistura A+B: leitura da horda melhor do que a
3ª pessoa, mas mantendo personagem, escala e alguma mira.

Pitch provisório: *"Atravessa um arquipélago infestado, escolhe a rota,
cumpre a missão de cada ilha e rompe a horda até à extração, em 25 minutos."*

Pilares possíveis:
1. **Romper a horda** — o título dá o verbo: a horda é terreno que se move e
   o jogador abre caminho por ela.
2. **Cada ilha é uma decisão** — rota, risco, recompensa.
3. **Builds que mudam a forma de jogar** — sidegrades, não percentagens.

## 2. Core loops

- **30 s:** mover, disparar, reposicionar, recolher; verbo *breaker*
  (empurrão/dash que abre caminho na horda, com cooldown).
- **5 min (ilha):** chegar → explorar → objetivo com evento de horda → saída.
- **25 min (run):** Dawn Beach → 2–3 ilhas num mapa em grafo (Slay the
  Spire/FTL) → Volcano → extração. Extrair cedo com menos, ou arriscar.
- **Meta:** desbloquear em vez de fortalecer; níveis de dificuldade (Hazard
  do DRG, Heat do Hades).

## 3. Combate e inimigos

- Armas com **comportamento** (penetração, ricochete, fogo, explosão, arco).
- **Evoluções na run**: arma + carta X = evolução.
- **Habilidade ativa por classe** (granada, torreta, cura em área).
- Especiais com contra claro: Screamer (chama horda → matar primeiro),
  Bloater (explode, empurra), Grabber (prende → dash solta), Armored (por
  trás ou explosivos).
- **Diretor à Left 4 Dead**: mede intensidade e alterna crescer → pico →
  alívio, em vez de só escalar com o tempo.
- Game feel: micro hit-stop, knockback, desmembramento simples, shake
  contextual, impacto sonoro forte.

## 4. Mundo e missões

- Ilhas como **cenas compactas** (150–250 m); a viagem de barco é a transição.
- **Templates de missão**: Hold Zone, Carry, Activate 3, Destroy Nests,
  Defend the Boat, Hunt Elite, Salvage contra o relógio.
  Template × ilha × modificador = rejogabilidade sem mapas novos.
- **Barco como base móvel** (depósito, loja, cura, melhorias) em vez de
  acampamento com tiers, construção e torres.

## 5. Progressão e economia

- Duas camadas: **run** (XP → cartas/evoluções; Scrap → loja) e **meta**
  (uma moeda → desbloqueios horizontais).
- Cartas: ⅓ stats, ⅔ comportamento ("cada 5.º tiro explode", "o dash deixa
  fogo", "recarregar empurra a horda").
- Skill tree → perks equipáveis com slots, ou árvore pequena (~15 nós) com
  escolhas exclusivas.
- Munição: arma base infinita + armas especiais limitadas (Helldivers 1,
  Enter the Gungeon). Logística como escolha, não ansiedade.

## 6. UX e HUD

- Informação no mundo antes do HUD (luzes, cores, marcas no chão).
- Indicadores na borda do ecrã para objetivos e especiais fora de vista.
- Mapa da expedição no ecrã do barco; debrief com telemetria real.

## 7. Câmara — discussão

Comparámos 3ª pessoa (atual no original) com câmara alta (inclinação 55–60°,
~22 m, ~32 × 22 m de terreno visível). Conclusões da comparação:

- A câmara alta mostra a horda a 360° e torna o radar quase dispensável; os
  alcances de auto-fire do original (8–13 m) cabem no ecrã.
- Com câmara mais alta, o **spawn mínimo** tem de passar a "fora do ecrã"
  (o original usava ≥ 12 m, que fica visível).
- **Oclusão** (árvores, telhados, falésias) exige shader de recorte/fade.
- Perde-se imersão e o momento "parede de zombies no horizonte".

**Escolha do utilizador: câmara média.** Ponto de partida para o spike:

| Preset | Inclinação | Distância | Offset lateral | FOV | Sensação |
|---|---|---|---|---|---|
| Ombro afastado | ~25° | ~7 m | ~0,8 m | ~65° | perto do original, mais contexto |
| **Média** | ~35° | ~10 m | ~0,4 m | ~60° | alvo provável |
| Alta leve | ~45° | ~13 m | 0 m | ~55° | aproxima-se da câmara alta |

Perguntas que o spike tem de responder: yaw controlado pelo rato ou fixo?
Como mirar (retícula no ecrã + raycast ao plano do jogador vs ao inimigo)?
Quanto da horda atrás do jogador continua invisível e que pistas são
precisas (som, borda do ecrã)?

## 8. Tecnologia

- Ficar no Godot (decidido). Horda escalável: **flow field** por ilha,
  zombies como dados (arrays + spatial hash), render com **MultiMesh**
  (e mais tarde Vertex Animation Textures), rig completo só para os mais
  próximos; hitscan contra o spatial hash.
- Arquitetura: Resources para dados, event bus, state machine da run,
  pooling, save versionado.
- Ferramentas: telemetria por run (JSON), bot de soak, painel de debug.
- Orçamento definido cedo: p. ex. 60 FPS na RX 590 com N zombies.

## 9. Produção

- GDD de uma página + documentos vivos curtos + lista "não vamos fazer".
- Vertical slice em grey-box: 1 ilha, 1 classe, 3 armas, 4 inimigos,
  1 missão — 10 minutos divertidos antes de mais nada.
- Cada feature serve um pilar; playtests curtos com perguntas definidas.

## 10. Respostas do utilizador (2026-10-05)

Respostas às 10 perguntas abertas. Ainda **não** estão em `DECISIONS.md`:
o utilizador regista-as lá quando as confirmar.

1. **Direção**: A+B ("Expedition Breaker").
2. **Mira**: **auto-fire como modo de disparo normal** do jogo (não só
   acessibilidade).
3. **Headshots**: mantêm-se; há tiros à cabeça e ao corpo (pontos fracos
   visíveis nos especiais podem somar-se a isto).
4. **Breaker**: investida comum a todas as classes, sem sprint. O Bull Rush
   do Renegade tem de mudar.
5. **Horda**: ~80–150 inimigos ativos; o número final vem do spike S2.
6. **Base**: o barco como ecrã de loja e serviços entre ilhas, sem construção.
7. **Progressão**: perks em slots em vez de skill tree; meta em "Intel";
   morrer conserva o Intel. Dúvida do utilizador: faz sentido haver Scrap?
   - Proposta: **cortar o Scrap** no vertical slice. Entre ilhas, o barco
     oferece "escolhe 1 de 3" (carta, arma, cura) em vez de uma loja com
     moeda. Uma moeda a menos para equilibrar e explicar. Volta a ser
     considerado só se os playtests pedirem decisões de gasto na run.
8. **Vertical slice**: Recruit; 4.º inimigo = Grabber (testa o breaker).
9. **Contexto**: projeto por divertimento, a solo, sem experiência prévia em
   desenvolvimento de jogos e sem prazo. Implica: âmbito pequeno, passos
   explicados, nada que exija arte ou rede.
10. **Tom**: humor ao estilo DRG; desmembramento simples (com primitivas:
    partes da cápsula que se soltam).
