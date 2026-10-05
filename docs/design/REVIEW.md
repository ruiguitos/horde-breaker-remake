# Revisão de coerência dos documentos de design

Revisão feita a 2026-10-05, depois de as tarefas D1–D5, T1 e S1–S3 subirem
para `master`. Compara cada documento com `docs/DECISIONS.md`, que
prevalece sobre todos os outros. Os documentos de design foram escritos
**antes** de várias decisões fecharem, por isso algumas diferenças são só
texto desatualizado.

## Testes

`godot --headless --path . --script res://tests/run_all.gd` → **6/6 passam**
(smoke, cena do jogo, run de ilhas, spikes `camera_medium`, `director`,
`horde_flowfield`). Só validação headless; nada verificado visualmente.

## Contradições com `DECISIONS.md` (corrigir)

| # | Documento | Diz | `DECISIONS.md` diz | Gravidade |
|---|---|---|---|---|
| 1 | `CAMERA_CONTROLS_HUD.md` §4.1, §6 (ponto 7), tabela de bindings | Auto-fire como **opção desligada por omissão**; disparo manual com prioridade | Auto-fire é o **modo normal** | Alta: o documento inteiro de controlos e HUD parte da mira manual |
| 2 | `CAMERA_CONTROLS_HUD.md` §1.3, §6 (ponto 1) | Recomenda **yaw livre** com o rato ("só o yaw livre mantém os headshots com sentido") | Câmara do slice com **yaw fixo** | Alta: muda bindings (o rato passa a apontar o foco no chão, não a rodar a câmara) |
| 3 | `GDD.md` §1, §6; `COMBAT_AND_ENEMIES.md`; `WORLD_AND_MISSIONS.md` | Horda de **80–150** ativos | **~150 ativos, teto 300** | Baixa: compatível, mas os números devem ser iguais em todo o lado |

O `COMBAT_AND_ENEMIES.md` já está alinhado com a decisão de mira: auto-fire
com **cone de foco** apontado pelo rato/stick, que é o que torna o yaw fixo
viável. O `CAMERA_CONTROLS_HUD.md` deve passar a usar esse modelo.

## Coerente entre documentos

- **Sem Scrap / "escolhe 1 de 3"** no barco: GDD, PROGRESSION (§2.1,
  recomendação A) e WORLD (§5) concordam.
- **Breaker comum, sem sprint/salto/agachar**: GDD, COMBAT (D9), PROGRESSION
  e CAMERA concordam.
- **Intel conserva-se ao morrer**, extração dá bónus: GDD, PROGRESSION (P6,
  ×1,5) e WORLD (§1) concordam.
- **Perks em slots, sem skill tree**: GDD e PROGRESSION concordam.
- **Horda e técnica**: S2 mede ~1,2–1,5 ms/tick para 150 agentes na CPU da
  cloud; o ARCHITECTURE usa o teto de 300 e um orçamento de ≤ 2 ms. O S3
  recomenda orçamento 80 → 150 com teto duro. Consistentes.

## Perguntas em aberto repetidas (responder uma vez)

Várias aparecem em mais de um documento, com propostas ligeiramente
diferentes:

1. **Intel ao morrer: 100 % ou parte?** GDD Q4 e PROGRESSION Q3. O WORLD
   propõe "o recolhido nas ilhas conserva-se sempre; o bónus só ao extrair",
   que já é uma resposta concreta.
2. **Slots de perks iniciais** (GDD Q5 propõe 2) e como se desbloqueiam.
3. **Disparo manual como opção de definições**: COMBAT (D2) propõe testá-lo
   em playtest; CAMERA trata-o como modo principal. Fica só como opção.

## Recomendações

1. Atualizar `CAMERA_CONTROLS_HUD.md` para auto-fire + cone de foco + yaw
   fixo (contradições 1 e 2). É o único documento que precisa de reescrita
   a sério.
2. Uniformizar o número da horda para "~150 ativos, teto 300".
3. O utilizador responde às três perguntas acima e regista-as em
   `DECISIONS.md`.
