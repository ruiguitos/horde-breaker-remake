# Co-op: o que teria de mudar (proposta do Codex, 2026-10-11)

Proposta para o utilizador decidir. **Nada de co-op está implementado.** Feita pelo Codex a ler o código.

**Recomendo preparar já o código para vários jogadores, validar co-op com 2 e só assumir 4 após medir desempenho.** O single-player deve continuar jogável em todas as fases.

Li as regras, decisões, análise de plugins, documentos de design e código relevante. **Não alterei ficheiros nem executei Godot.** Preços, termos externos e compatibilidade efetiva ficam por confirmar; JEV não estava disponível.

**1. Decisões propostas**

A decisão atual em [DECISIONS.md:14](C:/Users/Rui/code/horde-breaker-remake/docs/DECISIONS.md:14) diz:

> Direção: **A+B "Expedition Breaker"** — horde shooter de expedição por ilhas, single-player.

Proposta: “Horde shooter de expedição por ilhas, jogável a solo, com co-op previsto para 2 jogadores; extensão a 4 condicionada a testes.” **Só o utilizador deve editar `DECISIONS.md`.**

| Documento / pressuposto atual | Nova regra proposta |
|---|---|
| `GDD.md` §1, §4: um jogador; §5: co-op/online excluído | Solo e co-op partilham conteúdo; multiplayer passa a objetivo posterior, com marcos próprios. |
| `PROGRESSION_AND_ECONOMY.md` §1.1–1.2: XP da run, escolhas pausadas; §1.6: rerolls | XP/nível da equipa; cartas, ofertas e rerolls individuais; pausa sincronizada. “Partilhado pela run” atualmente não demonstra partilha entre jogadores. |
| Progressão §3 e pergunta 6: Intel permanente; Medic sem aliados | Perfis individuais; mesma recompensa base por participação; Medic pode apoiar colegas, mantendo utilidade a solo. |
| `COMBAT_AND_ENEMIES.md` §1, §4–5: foco, ataques, intensidade e navegação centrados num jogador | Foco por jogador; alvo por inimigo; pressão da equipa; regras de spawn/reciclagem consideram todos. Hit-stop deixa de suspender a simulação em co-op. |
| `WORLD_AND_MISSIONS.md` §1–3: decisão, presença, saída e morte individuais | Missões/rota partilhadas; qualquer jogador apto pode contribuir; derrota por eliminação da equipa; saída coletiva. |
| `MENUS.md`: preparação, cartas, pausa, abandono e relatório únicos | Lobby, loadout/pronto por jogador, voto, estado dos colegas, saída individual e debrief por perfil. |
| `BERLENGA_EXPEDITION.md`: chegar ao `Exit` termina a parte | Reunir equipa antes da transição; acampamento coletivo, sem inventar rotas na expedição linear. |
| `CAMERA_CONTROLS_HUD.md`: uma apresentação | Câmara/HUD por jogador local; preferências independentes. A decisão de câmara média não precisa de mudar por causa do co-op. |

**2. Regras de jogo recomendadas**

| Tema | Proposta para decidir |
|---|---|
| Participantes | 1–2 inicialmente; arquitetura admite 4. Entrada de novos jogadores no barco/acampamento, evitando entrada durante combate no primeiro protótipo. |
| XP, nível e cartas | XP recolhido conta uma vez para a equipa; nível comum; cada jogador recebe a sua escolha de três, filtrada pela própria build. Rever cartas de bónus de XP para evitar acumulação multiplicativa. |
| Level-up e pausa | A subida comum pausa **todos**, até terminarem as escolhas. Esc abre o menu pessoal sem parar combate; pausa manual global exige acordo. Preserva decisões ponderadas, mas pode interromper demasiado o ritmo: validar cedo. |
| UI/rerolls | Ofertas, foco e reserva individuais. Mostrar “colega a escolher”; impedir confirmações duplicadas e escolhas de ofertas antigas. |
| Caído/morto | Em co-op: caído durante ~30 s; reviver exige ~4 s próximo, interrompidos por dano. Depois, espectador até ao acampamento. Sem jogador capaz de reviver, derrota coletiva. Valores são hipóteses. |
| Run/Intel | Objetivos, rota e resultado comuns; Intel/desbloqueios por perfil. Cada participante recebe a recompensa base completa, sem divisão pelo número de jogadores; conservar o ganho ao morrer. |
| Horda/dificuldade | Escala sublinear: experimentar pressão ×`[1; 1,5; 1,9; 2,3]`. Manter teto global de 300; variar ritmo, especiais e vida dos bosses. Threat é escolhido para a sessão. |
| Power-ups | Uma recolha aplica o efeito à equipa; escudo/munição/cooldowns respeitam limites individuais. Nuke resolve uma vez no mundo. Reequilibrar duração/frequência para vários jogadores. |
| Barco/camp | Voto maioritário para rota/continuar/extrair; host desempata. Mantimento individual; todos confirmam pronto. Hazard pay torna-se escolha coletiva. |
| Expedição | Uma parte carregada de cada vez; vivos reunidos na saída; mortos regressam no acampamento. Objetivos não aceleram automaticamente com mais pessoas presentes. |
| Fogo amigo/câmara | Sem fogo amigo inicialmente; aliados não bloqueiam tiros/movimento. Câmara média, ombro ou primeira pessoa por jogador, sem alterar a autoridade do combate. |

Uma desconexão retira o jogador dos votos/esperas. No primeiro lançamento, saída do host termina a sessão; migração de host fica para depois.

**3. Arquitetura necessária**

**Confirmado:** [IslandRun:26](C:/Users/Rui/code/horde-breaker-remake/game/world/island_run.gd:26) concentra posição, HP, armas, cooldowns, cartas e XP num jogador. `RunContext` também mistura estado pessoal com rota/expedição.

Separar `PlayerRunState`, identificado por `player_id` estável, de `TeamRunState`: missão, horda, diretor, XP comum e transições. Associar participantes a ligações sem confundir identidade com `peer_id`. Manter regras como dados tipados; um nó de sessão trata RPC/transporte, porque `IslandRun` é `RefCounted`.

**Host autoritativo:** recebe comandos e valida movimento, mira, cadência, habilidades, recolhas e escolhas. Executa dano, spawns, objetivos e recompensas. Clientes interpolam o mundo; previsão/correção do movimento local entra quando a latência justificar.

| Replicar | Forma |
|---|---|
| Jogadores | Posição/orientação, HP/escudo, estados, armas e cooldowns. |
| Horda | Snapshots compactos com ID, posição, tipo e estados relevantes; manter MultiMesh, sem nós por zombie. |
| Tiros/tracers | Eventos visuais; dano decidido pelo host. Projéteis persistentes precisam também de estado corrigível. |
| Pickups/objetivos | IDs, criação/recolha única, progresso e transições fiáveis. |
| Cartas/resultados | Ofertas individuais, `offer_id`, escolhas validadas e recompensas aplicadas uma vez. |

[Horde.remove:80](C:/Users/Rui/code/horde-breaker-remake/game/horde/horde.gd:80) troca o último inimigo para o índice removido. **Índices não podem ser IDs de rede:** acrescentar ID monotónico e mapas ID↔índice, atualizados na troca. Incluir versão da ilha/tick para rejeitar pacotes atrasados.

Há um alvo/flow field único. Experimentar campo multi-origem para o jogador alcançável mais próximo; campos separados apenas se o comportamento exigir. Reciclar inimigos só quando longe de todos; evitar spawns visíveis para qualquer participante. Medir particularmente jogadores separados nas ilhas grandes.

Seeds existentes ajudam testes, mas não garantem determinismo entre máquinas. Usar snapshots autoritativos.

Cada jogador local precisa de viewport, HUD, retícula e rig/Phantom Camera próprios. Distribuir eventos antes de limpar filas: atualmente HUD/cena consomem-nas. Input usa `InputMap` global e comando 0; G.U.I.D.E. está integrado em ícones/remapeamento, **não existe encaminhamento multiplayer**.

`Profile` grava um único `user://profile.json` e tem `Profile.current` global. Separar perfis locais e preferências da máquina; cada cliente grava o próprio resultado, identificado para impedir duplicação.

**4. Opções de rede**

Sem consulta externa autorizada, estas são orientações técnicas; termos/preços atuais não foram verificados.

| Opção | Licença/custo | Esforço e adequação |
|---|---|---|
| Godot High-Level Multiplayer | Godot/ENet: MIT; sem serviço obrigatório | Melhor início: ENet para LAN. Internet exige acesso direto/NAT ou relay. WebRTC exige sinalização, eventualmente TURN e integração nativa adicional. |
| Steam/GodotSteam | Wrapper MIT; Steamworks tem termos próprios; publicação pode ter custos | Lobbies/transporte Steam exigem integração específica, eventualmente um `MultiplayerPeer`; não são relay automático para ENet. |
| GD-Sync | Licença própria BSD-style local; serviço com planos/termos próprios | Facilita infraestrutura; não resolve regras de autoridade/design. Fora da lista aceite, apesar de constar no inventário. |
| Epic Online Services | SDK/serviço sujeitos a termos Epic; gratuitidade atual por confirmar | Identidade/lobbies/P2P exigem integração; não assumir compatibilidade com a regra de licenças. |

**Recomendação:** ENet/LAN primeiro, transporte substituível. Escolher relay depois; SDKs/serviços proprietários exigem decisão explícita sobre a regra do projeto.

**5. Roadmap mantendo o jogo funcional**

Estimativas inferidas, para trabalho dedicado a solo:

| Fase | Esforço | Critério de passagem / maior risco |
|---|---:|---|
| Estado por jogador, ainda solo | 2–4 semanas | Testes atuais preservados; separar contexto/eventos. |
| Dois jogadores locais/split-screen | 2–4 semanas | Validar revive, cartas, input e câmaras; medir custo gráfico. |
| Host–cliente LAN | 5–8 semanas | Testes headless com latência, jitter, perda e duplicação; IDs, recolhas e transições consistentes. |
| Online/relay e avaliação de 4 | 4–8 semanas | Reconexão, compatibilidade de versões, desempenho/banda e contratos. |

Total indicativo: **13–24 semanas**, além do desenvolvimento normal. Navegação com equipa separada e sensação do combate sob latência são os maiores riscos. Os testes existentes foram lidos, não executados; split-screen exige também validação visual.

**6. Fazer agora, com baixo custo**

1. Passar jogador explicitamente às funções novas.
2. Criar IDs estáveis para entidades e ofertas.
3. Separar comandos, regras e apresentação; evitar input/perfil globais.
4. Centralizar dano, recompensas e transições, com aplicação única.
5. Preservar testes solo e separar preferências pessoais das definições da máquina.

**Próxima decisão:** aprovar 2 jogadores como primeiro alvo e pausa coletiva nas subidas de nível.


