# Horde Breaker — GDD v2 (remake)

Estado: **proposta** de 2026-10-05, para o utilizador rever. Parte de
`docs/DECISIONS.md` (câmara média, Godot 4.7, design antes de código) e de
`design/BRAINSTORM.md`. Onde este documento recomenda algo ainda em aberto,
isso está marcado como proposta na secção 6; só passa a decisão quando entrar
em `DECISIONS.md`.

Detalhe de cada sistema vive no seu próprio documento (combate e inimigos,
progressão, mundo e missões, câmara e HUD). O GDD guarda a **intenção** e o
**âmbito**; não repete valores.

## 1. Pitch e high concept

**Pitch:** *Atravessa um arquipélago infestado, escolhe a rota, cumpre a
missão de cada ilha e rompe a horda até à extração, em 25 minutos.*

**High concept:** Horde Breaker é um shooter de horda single-player, em 3D com
câmara média (~35°, ~10 m), estruturado em expedições curtas tipo roguelite.
Cada run é um mapa em grafo de ilhas compactas: o jogador desembarca, cumpre
uma missão sob pressão de uma horda que um diretor faz crescer, aliviar e
voltar a apertar, e decide se segue para a próxima ilha ou extrai com o que
tem. A horda não é só um alvo: é terreno que se move, e o verbo central é
abri-la à força (o *breaker*). Durante a run, cartas e evoluções mudam a
forma como as armas e o *breaker* funcionam; entre runs, desbloqueiam-se
opções novas em vez de números maiores.

## 2. Pilares

Cada feature tem de servir pelo menos um pilar. Se não serve, vai para a
lista "não vamos fazer" (secção 5).

### P1 — Romper a horda

- **O que significa:** o jogador está quase sempre em movimento e a decisão
  mais frequente é *por onde passar*. A horda tem densidade, empurra e pode
  ser empurrada; o *breaker* (empurrão/dash com cooldown) abre caminho. A
  mira importa, mas posicionar-se importa mais. Especiais existem para
  quebrar padrões (um que chama horda, um que explode e empurra).
- **O que exclui:** cobertura e tiroteio parado; stealth; torres e defesa
  estática como modo principal; zombies que são só esponjas de dano.

### P2 — Cada ilha é uma decisão

- **O que significa:** a run é uma sequência de escolhas legíveis: que rota,
  que missão opcional, quando extrair. Cada ilha é pequena e autorada
  (150–250 m), com uma missão clara e uma saída clara. Arriscar mais dá mais
  recompensa; extrair cedo é sempre uma opção honesta.
- **O que exclui:** mundo aberto contínuo; exploração sem objetivo; mapas
  grandes e vazios; relógios arbitrários que decidem pelo jogador.

### P3 — Builds que mudam a forma de jogar

- **O que significa:** cada escolha de build tem de mudar o que o jogador
  *faz*, não só quanto dano dá. Cartas são ⅔ comportamento ("o dash deixa
  fogo", "recarregar empurra a horda") e ⅓ stats. A meta desbloqueia
  alternativas (sidegrades), não percentagens.
- **O que exclui:** árvores de 50+ nós de "+X%"; várias moedas permanentes;
  mastery, variantes e evoluções sobrepostas que dizem a mesma coisa.

## 3. Core loops

| Loop | Ações | Decisões do jogador | Recompensa |
|---|---|---|---|
| **30 s — combate** | mover, mirar, disparar, recarregar, *breaker*, recolher XP/Scrap | por onde romper; que alvo primeiro (especial vs massa); usar o *breaker* agora ou guardá-lo; trocar para a arma de munição limitada | sobreviver com espaço livre; XP e Scrap no chão; o "estalo" de abrir caminho (game feel) |
| **5 min — ilha** | desembarcar → orientar-se → cumprir a missão (com evento de horda) → recolher opcionais → voltar ao barco | fazer o opcional ou não; que ordem de objetivos; aguentar o pico ou fugir para o alívio | carta(s) por nível de run; Scrap; recompensa da missão; nova ilha no grafo |
| **25 min — run** | 3–4 ilhas num grafo (início → 2–3 ilhas → ilha final com boss → extração); entre ilhas, o barco | que rota seguir no grafo; o que comprar no barco; extrair cedo ou arriscar a ilha seguinte | extração com a moeda meta; desbloqueios; o boss derrotado |
| **Meta** | gastar a moeda meta; escolher classe, loadout e nível de dificuldade antes da run | o que desbloquear primeiro; subir a dificuldade (estilo Hazard/Heat) ou não | armas, cartas e classes novas no pool; dificuldades e modificadores; nunca só "+5% dano" |

Notas:

- O loop de 30 s é o que se prototipa primeiro: se não for divertido numa
  arena cinzenta, nada acima o salva.
- O ritmo da ilha vem do diretor (crescer → pico → alívio), não de vagas
  numeradas. A missão provoca o pico; o alívio é quando se explora.
- Morrer perde os recursos da run mas não a moeda já extraída. Extrair cedo
  leva menos, mas leva sempre alguma coisa.

## 4. Fantasia, público, plataforma e sessão

**Fantasia do jogador:** *"Não fico cercado: eu atravesso a horda."* A ponta
de lança de uma expedição de recuperação, sozinha, que entra onde ninguém
entra, faz o trabalho e sai a tempo. Poder crescente ao longo da run, mas
sempre com a sensação de que um passo errado fecha o círculo.

**Público-alvo:** jogadores de PC que gostam de runs curtas com builds
(*Deep Rock Galactic: Survivor*, *Vampire Survivors*, *Hades*) mas querem
mais controlo e mira do que um auto-shooter; e jogadores de *Left 4 Dead*/
*Vermintide* que querem essa tensão de horda a solo, sem marcar sessões com
amigos.

**Plataforma:** PC Windows. Teclado e rato e comando, ambos de primeira
classe desde o vertical slice (a mira assistida da secção 6 existe por causa
do comando). Alvo inicial de desempenho: 60 FPS a 1080p numa RX 590, a
validar com o spike de escala da horda.

**Sessão-alvo:** uma run de 20–30 min, com pausa natural no barco entre
ilhas. O vertical slice visa 10 minutos.

**O que a câmara média implica** (estimativa geométrica para 35°/10 m/FOV
vertical 60°, a confirmar no spike `camera_medium`): o chão visível estende-se
~55 m à frente do jogador mas só ~5 m atrás, com ~20 m de largura à altura do
jogador. Ou seja, a horda à frente lê-se bem; a de trás e dos lados não.
Daí três regras de design:

1. Spawns sempre fora do frustum, sobretudo atrás e nos lados, a uma distância
   mínima a afinar (o original usava ≥ 12 m, que aqui seria visível à frente).
2. Pistas para a horda fora de vista: som direcional e indicadores na borda do
   ecrã, em vez de um radar de 360°.
3. Pontos fracos legíveis de cima a ~35° (costas, sacos, carapaças), em vez
   de depender só da cabeça.

## 5. Âmbito do vertical slice e "não vamos fazer"

### Vertical slice

Objetivo: **10 minutos divertidos em grey-box**, que provem P1 e P3 e deem um
primeiro sinal de P2. Primitivas Godot, sem assets externos.

| Elemento | Proposta | Porquê |
|---|---|---|
| **1 ilha** | ilha compacta (~200 m), 3 landmarks, 2 rotas de fuga por encontro, barco de chegada/saída | mede a escala de ilha antes de fazer mais |
| **1 classe** | *Vanguard* (nome provisório): arma base + *breaker* + uma habilidade ativa (granada de empurrão) | o *breaker* é o verbo do título; tem de estar no slice |
| **3 armas** | Carbine (base, munição infinita, precisa); Shotgun (limitada, cone, knockback forte); Launcher (limitada, área, explosão empurra) | uma arma "de sempre" e duas de decisão; comportamento, não só stats |
| **4 inimigos** | Walker (massa), Runner (rápido, castiga ficar parado), Bloater (explode e empurra; pode ser usado contra a horda), Screamer (chama horda; prioridade) | dois de massa e dois especiais com contra claro |
| **1 missão** | *Activate 3*: ligar três relés que carregam sob ataque, depois voltar ao barco; uma cache opcional fora do caminho | provoca três picos do diretor e uma decisão de risco (cache vs extrair) |
| **Run** | XP de run com ~8 cartas (⅔ comportamento) | prova mínima de P3 |
| **Fora do slice** | meta-progressão, grafo de ilhas, boss, loja do barco, save | só depois de o slice ser divertido |

Os detalhes de armas e inimigos são do `COMBAT_AND_ENEMIES.md`; esta lista é
o âmbito, e esse documento pode trocar um elemento por outro equivalente.

**Critérios de sucesso do slice** (playtest com perguntas definidas): o
jogador usa o *breaker* por iniciativa própria; consegue dizer o que uma carta
mudou na forma como joga; mata o Screamer primeiro sem lhe dizerem; quer jogar
outra vez.

### Não vamos fazer

| Fora | Porquê |
|---|---|
| Acampamento com tiers, construção livre e torres | era um segundo jogo dentro do primeiro; deixou sistemas órfãos no original (P1, P2) |
| Mundo aberto contínuo (768 m), streaming de setores, Terrain3D | conteúdo nunca acompanhou o tamanho; ilhas compactas autoradas servem P2 com menos custo |
| Multiplayer / co-op | rede multiplica o custo de tudo; o jogo tem de funcionar a solo primeiro |
| Skill tree grande, mastery, variantes de classe, evoluções por kills | camadas sobrepostas de "+X%" contra P3 |
| Mais de uma moeda permanente | uma moeda de run (Scrap) e uma meta chegam |
| Barco controlável e física naval | a viagem é transição e menu, não gameplay |
| Armas melee | o original já as retirou; o *breaker* é o "corpo a corpo" do jogo |
| Cobertura, stealth, agachar | contra P1: o jogo é movimento |
| Radar circular de 360° | a câmara média e as pistas na borda do ecrã substituem-no |
| Narrativa com cutscenes ou voz | custo alto, não serve nenhum pilar; rádio em texto chega |
| Save a meio da run (em disco) | complexo e frágil; uma run de 25 min pode ser feita de seguida |
| Addons externos e assets na pré-produção | regra do projeto; primitivas até o gameplay estar fechado |

## 6. Decisões propostas

Uma por cada ponto em aberto de `DECISIONS.md`. Todas coerentes com a câmara
média. **O utilizador decide**; nada aqui está fechado.

### 6.1 Direção do jogo

| Opção | Prós | Contras |
|---|---|---|
| A — Expedition Survivors | género provado; aproveita cartas, orbes, arquipélago | câmara média não é a câmara alta que o género pede; saturado |
| B — Horde shooter tático | tensão; aproveita munição, headshots, classes | IA e animação caras; brilha em co-op, que não vamos fazer |
| **A+B — Expedition Breaker** | estrutura de run de A, tensão de especiais de B; casa com a câmara média | risco de ficar a meio caminho se os pilares não forem respeitados |

**Recomendação: A+B.** Estrutura de A (grafo de ilhas, cartas, extração),
combate com mira e especiais de B. C fica fora: é a parte que deixou órfãos.

### 6.2 Mira e papel dos headshots

| Opção | Prós | Contras |
|---|---|---|
| Manual pura (retícula + raycast) | habilidade conta; simples de perceber | difícil com comando; a ~35° acertar na cabeça é ilegível |
| **Manual com assistência** | rato preciso, comando jogável; magnetismo leve resolve a altura do alvo | afinar a força sem parecer automático |
| Auto-fire opcional | acessível; o original já o tinha | se for o modo dominante, anula a mira e cria o conflito do original |

**Recomendação: mira manual com assistência** (forte no comando, leve no
rato, sobretudo vertical). Auto-fire só como opção de acessibilidade, nunca
como modo principal. Headshots substituídos por **pontos fracos visíveis de
cima** (×2), mais importantes nos especiais do que na massa. Detalhe em
`COMBAT_AND_ENEMIES.md`.

### 6.3 Escala da horda

| Opção | Prós | Contras |
|---|---|---|
| Dezenas (30–80) + especiais inteligentes | IA rica, barato de renderizar | com câmara média parece pouco; P1 perde força |
| Centenas (200–500) | espetáculo de A | não cabem lidos em ~20 m de largura; exige VAT/MultiMesh desde já |
| **Intermédia (~80–150 ativos, 3–6 especiais)** | densidade suficiente para "romper"; especiais com espaço para brilhar | ainda exige zombies como dados + MultiMesh |

**Recomendação: intermédia.** O número final sai do spike de escala (60 FPS
na RX 590); o design não deve pedir mais do que o spike provar.

### 6.4 Base

| Opção | Prós | Contras |
|---|---|---|
| Acampamento com tiers e construção | profundidade; existia no original | é o modo C; contra P1/P2; custo enorme |
| **Barco como base móvel** | encaixa nas ilhas; serviços simples (loja, cura, depósito) num menu/diorama entre ilhas | menos "casa"; tentação de o tornar jogável |
| Nenhuma | mínimo custo | a run perde o respiro e a decisão de compra entre ilhas |

**Recomendação: barco como base móvel, só como ecrã de serviços entre ilhas.**
Sem construção nem defesa da base. Fora do vertical slice.

### 6.5 Pilares e pitch

**Recomendação:** os da secção 1 e 2 (pitch do brainstorm, pilares *Romper a
horda*, *Cada ilha é uma decisão*, *Builds que mudam a forma de jogar*).
Alternativa a considerar para P2: *"Arriscar ou extrair"*, mais curto e mais
focado na tensão, mas cobre menos a escolha de rota.

### 6.6 Contexto do projeto

| Opção | Prós | Contras |
|---|---|---|
| Aprendizagem | sem pressão; cada spike vale por si | sem meta, o âmbito volta a crescer |
| **Portfólio com o slice como meta** | objetivo concreto e mostrável; obriga a acabar algo | menos ambicioso |
| Lançamento na Steam | motivação real | exige arte, som, polimento, marketing; prazo |

**Recomendação: portfólio, com o vertical slice como primeira meta**, e só
depois decidir se há caminho para a Steam (o slice responde a essa pergunta).
O prazo é do utilizador; ver secção 7.

## 7. Perguntas para o utilizador

1. **Direção:** aceitas A+B "Expedition Breaker"? (sim / não)
2. **Mira:** manual com assistência, auto-fire só como acessibilidade? (sim / não)
3. **Horda:** ~80–150 ativos, ajustado pelo spike? (sim / quero mais / quero menos)
4. **Base:** barco como ecrã de serviços entre ilhas? (sim / nenhuma base)
5. **Pilares:** os três da secção 2? (sim / mudar P2 para "Arriscar ou extrair")
6. **Projeto:** solo? (sim / não)
7. **Objetivo:** portfólio com o slice como meta? (portfólio / Steam / aprendizagem)
8. **Prazo:** há uma data para o vertical slice? (data / sem prazo)
9. **Comando:** é obrigatório desde o slice ou pode vir depois? (slice / depois)
10. **Tom:** sério (*L4D*) ou com humor (*DRG*)? (sério / humor)
