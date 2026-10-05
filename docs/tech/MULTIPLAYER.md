# Multiplayer (co-op): plano

Estado: **proposta, sem código**. O addon **GD-Sync** está em
`addons/GD-Sync/` mas não está ativo nem ligado ao jogo. Este documento
explica as opções, o que tens de decidir e os passos, por ordem.

## 1. Que multiplayer faz sentido

O Horde Breaker é um jogo de horda em ilhas. O formato natural é **co-op de
2 a 4 jogadores** na mesma run (como Helldivers ou Deep Rock Galactic), não
PvP. Os jogadores entram no barco juntos, escolhem rota e mantimentos e
desembarcam na mesma ilha.

## 2. Porque é que a arquitetura ajuda

A regra do jogo vive em `IslandRun`, uma classe sem nós. A horda é um
conjunto de arrays (posições, vida) e não tem um nó por zombie. Isto
permite o modelo mais simples e robusto:

**Host autoritativo**:
- **Host:** corre o `IslandRun` como hoje.
- **Clientes:** enviam só o input (movimento, mira, breaker, habilidade).
- **Host → clientes:** cerca de 20 vezes por segundo, envia um *snapshot*
  compacto: jogadores, inimigos vivos (posição em 2 bytes por eixo, tipo e
  vida) e eventos (tiros, mortes, explosões, rádio).
- **Clientes:** desenham o snapshot e interpolam entre os dois últimos. É o
  que o `island.gd` já faz com o `IslandRun`.

Com 175 inimigos, cerca de 6 bytes cada, mais eventos, dá uns 1,2 KB por
snapshot e uns 25 KB/s por cliente, o que é aceitável.

## 3. Transporte: GD-Sync ou o multiplayer nativo do Godot

| | GD-Sync (addon) | Godot `ENetMultiplayerPeer` (nativo) |
|---|---|---|
| Ligação | Servidores deles (relay), lobbies e *matchmaking* incluídos | Direta entre PCs; precisa de abrir portas ou de um servidor/relay |
| Custo | Conta em gd-sync.com; plano grátis com limites, depois pago | Grátis |
| Contas e lobbies | Incluídos | Tens de os fazer (ou usar Steam) |
| Dependência | Serviço externo (se fechar, o MP pára) | Nenhuma |
| Testar localmente | `start_local_multiplayer()` (LAN) | Sim, dois processos no mesmo PC |
| Licença do código | BSD-style; o serviço tem termos próprios | MIT (Godot) |

**Recomendação:** começar com **ENet nativo em LAN/IP direto**. Não precisa
de contas nem de serviço, e é perfeito para aprender e testar com dois
processos no mesmo PC. A comunicação fica isolada numa classe `NetSession`,
com dois backends (`EnetBackend` e `GdSyncBackend`), para trocar para o
GD-Sync quando quiseres lobbies online sem servidor próprio. Como as
mensagens são as mesmas (input e snapshot), a troca não mexe no jogo.

## 4. Decisões que são tuas

1. Quantos jogadores (2, 4)?
2. Online com lobbies desde o início (GD-Sync), ou primeiro LAN/IP (ENet)?
3. Progressão: cada jogador mantém o seu perfil (Intel, perks), ou o host
   decide?
4. Escala da dificuldade com o número de jogadores (mais inimigos? mais
   vida?).
5. Se um jogador morre: espera pelo fim da ilha, ou há *revive*?

## 5. Passos de implementação (ordem proposta)

1. **Vários jogadores no `IslandRun`, ainda offline.** `player_pos`, `hp`,
   etc. passam a uma lista de jogadores, e a horda persegue o mais próximo
   (o flow field já aceita vários alvos). Os testes headless continuam a
   valer: um bot por jogador.
2. **Snapshot e input como dados.** `IslandRun.snapshot() -> PackedByteArray`
   e `apply_input(player_id, input)`. Testa-se headless com um "cliente
   falso" que aplica snapshots e compara com o host.
3. **`NetSession` com ENet.** Botões "Host" e "Join (IP)" no título; o host
   envia snapshots e recebe inputs. Testa-se com dois processos Godot no
   mesmo PC (`--headless` para o servidor no CI).
4. **Barco partilhado.** As escolhas de rota e de mantimentos passam a votos.
5. **(Opcional) GD-Sync.** Cria-se o `GdSyncBackend` sobre `call_func` e
   `sync_var` para lobbies online.

## 6. Configurar o GD-Sync (quando chegar o passo 5)

1. Cria conta em gd-sync.com e um projeto. Recebes uma **public key** e uma
   **private key**.
2. Projeto → Definições → Plugins: ativa **GD-Sync**. Aparece o autoload
   `GDSync` e um painel de configuração.
3. Põe as chaves no painel do plugin, ou em variáveis de ambiente
   `GDSYNC_PUBLIC_KEY` e `GDSYNC_PRIVATE_KEY`. **Não as commits:** a private
   key é um segredo.
4. Para testar sem internet: `GDSync.start_local_multiplayer()` (LAN).
5. API base: `GDSync.start_multiplayer()`, `create_lobby()`/`join_lobby()`,
   `is_host()`, `call_func_all(callable, args)` para enviar o snapshot e
   `call_func_on(host_id, ...)` para enviar o input.

## Decisões propostas

- Co-op de 2 a 4 jogadores com host autoritativo e snapshots da simulação.
- ENet nativo primeiro, GD-Sync como segundo backend para lobbies online.
- Perfis individuais (cada um ganha a sua Intel); dificuldade +50% de
  inimigos por jogador extra.
