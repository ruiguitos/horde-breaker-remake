# Skill tree expandida — proposta e implementação do Recruit

## Integração jogável concluída — 2026-09-08

Os 36 nós do Recruit agora têm efeitos na run, gravação confirmada, conversão
com backup e respec gratuito. EXPANDED TREE usa nível e pontos reais; limite
de 30 pontos ativos e uma especialização final. Guia e limitações em
[RECRUIT_SKILL_TREE_TESTING.md](RECRUIT_SKILL_TREE_TESTING.md).
As notas seguintes são o histórico da proposta/preview, não o estado atual.

## Atualização de 2026-09-08

Primeira etapa visual implementada no Godot: Recruit → SKILLS → EXPANDED
PREVIEW. Catálogo de 36 nós com números experimentais em
`scripts/systems/recruit_skill_tree.gd`; interface em
`scripts/ui/recruit_skill_preview.gd`. O orçamento é apenas simulado, nunca
gravado. 151 verificações headless e 153 renderizadas; árvore anterior 224/224.

A implementação de combate, migração e respec continua pendente. O título
"não implementada" refere-se à árvore jogável, não à pré-visualização.
O novo catálogo descreve explicitamente Field Dressing apenas para Dawn
Supplies, Quick Recovery como recuperação de knockback e Supply Runner na
recolha da cache opcional; são limites propostos, ainda sem efeito em combate.

Data: 2026-09-07. Pedido: apresentar primeiro um esboço; só depois implementar.

## Estado confirmado

`scripts/systems/skill_tree.gd` define três personagens, três ramos por
personagem e seis nós por ramo: 18 nós distintos e 57 ranks por personagem.
Os efeitos atuais são modificadores numéricos. SaveManager atribui um ponto
por cada dois níveis, sem teto; os ranks são IDs repetidos no save. Não há
respec no fluxo de compra atual. Ao nível 114 é possível preencher a árvore,
por isso a escassez de pontos não mantém especializações distintas para sempre.

## Direção proposta

- 36 nós por personagem, 12 por ramo, mantendo três ramos legíveis.
- Cada ramo: entrada → duas linhas paralelas de cinco nós → especialização
  final. O remate aceita qualquer uma das duas linhas. É permitido investir
  nas duas linhas; não são escolhas mutuamente exclusivas.
- Os primeiros três nós de cada ramo têm até três ranks; os outros nove têm
  um rank. Resultado: 18 pontos possíveis por ramo, 54 por personagem, apesar
  de haver o dobro dos nós distintos. Mais decisões, não mais compras repetidas.
- Tiers propostos nos níveis 2/6/12/20/30/40/50. Exigem respetivamente
  0/1/3/5/7/9/11 pontos já investidos no ramo e um rank no predecessor ligado.
- Uma especialização final ativa por personagem. Pode-se misturar passivos
  dos três ramos, mas não acumular os três efeitos finais.
- Hipótese para playtest: orçamento ativo máximo de 30 pontos, disponível
  integralmente ao nível 60 com a cadência atual. XP e níveis continuam.
  Isto é uma mudança de design proposta, não uma regra aprovada ou aplicada.
  Pontos históricos excedentes nunca devem ser apagados; conservar o total
  ganho e informar separadamente o limite de atribuição antes de migrar.
- Respec gratuito fora de runs durante o balanceamento; pré-visualizar e
  confirmar alterações em conjunto. Sem gasto de Scrap ou perda de Credits.
  Não alterar a build de uma run suspensa: bloquear edição até ao seu fim.

## Esboço detalhado: Recruit

As colunas A/B são linhas paralelas; ler cada uma de cima para baixo. Os
primeiros nós têm 3 ranks; os restantes 1. Valores finais ainda por medir.

| Tier / nível | Marksman | Sustained Fire | Fieldcraft |
|---|---|---|---|
| 1 / 2 | Steady Aim | Fast Hands | Light Kit |
| 2 / 6 | Heavy Rounds / Controlled Fire | Bandolier / Drum Mags | Magnetic Pouches / Field Vest |
| 3 / 12 | Opening Shot / Follow Through | Efficient Pickup / Reload Tempo | Scrounger / Quick Recovery |
| 4 / 20 | Patient Hunter / Specialist Hunter | Ammo Recovery / Covering Fire | Safe Reload / Escape Route |
| 5 / 30 | Clean Kill / Armour Breaker | Tactical Reload / Reserve Discipline | Field Dressing / Prepared Kit |
| 6 / 40 | Target Priority / Final Round | Weapon Rhythm / Last Magazine | Second Wind / Supply Runner |
| 7 / 50 | Deadeye | Bullet Storm | Field Veteran |

Especializações finais:

- **Deadeye:** três impactos consecutivos no mesmo inimigo preparam um
  disparo perfurante, no máximo dois alvos e nunca através de paredes.
- **Bullet Storm:** sequência de abates ativa cadência/recarga reforçadas
  durante uma janela curta, com cooldown e consumo normal de munição.
- **Field Veteran:** sobreviver a dano fatal com 1 HP e proteção breve,
  uma única vez por run, sem rearmar ao retomar a partida.

O esboço interativo entregue na conversa contém descrições dos 36 nós do
Recruit. Não é um simulador de compra nem a interface Godot final.

## Outras personagens: identidade, ainda sem catálogo final

Aplicar a mesma estrutura de 36 nós depois de validar o Recruit. Não apresentar
108 habilidades como implementadas ou completamente especificadas.

| Personagem | Ramo 1 | Ramo 2 | Ramo 3 |
|---|---|---|---|
| Renegade | Armour: aguentar pressão | Aggression: shotgun a curta distância | Momentum: mobilidade e troca de armas |
| Medic | Recovery: regeneração e recuperação | Utility: abastecimento e consumíveis | Combat: sobrevivência ofensiva |

Renegade mantém Shotgun/SMG: não reintroduzir espada ou dash que atravesse
barreiras. Medic deve funcionar a solo, sem depender de aliados ou multiplayer.
Evitar nomes/efeitos iguais às variantes Veteran, Berserker e Combat Medic.

## Inspirações e adaptação

- [Borderlands — manual oficial](https://assets.2k.com/1a6ngf98576c/3a1fmH50QOweeZHmRnu2zS/b676736b4e168987dbcb78934ed6ef01/BORDERLANDS_PC_MANUAL_ENG.pdf):
  referência para organizar investimento entre árvores ou concentrá-lo numa.
- [Last Epoch — skills](https://lastepoch.com/skills/): referência para nós
  que modificam o funcionamento das habilidades, não apenas atributos.

A estrutura, custos e efeitos acima são propostas próprias para Horde Breaker,
não uma reprodução destas árvores nem afirmações sobre o seu balanceamento.

## Limites e implementação posterior

1. Aprovar estrutura e orçamento; confirmar se a progressão ilimitada atual
   deve permitir eventualmente todos os passivos ou manter limite ativo.
2. Entregar primeiro Recruit: dados/UI, pré-requisitos, ranks, respec e uma
   especialização final de cada vez. Não mostrar nós compráveis sem efeito.
3. Versionar migração com backup, preservar XP/Credits/armas/pontos ganhos e
   devolver atribuições antigas para redistribuição informada. Migração repetida
   não pode duplicar pontos. Preservar saves acima do orçamento proposto.
4. Medir combinação com variantes, cartas temporárias, pickups e armas trocadas.
   Aplicação de modificadores deve ser idempotente, sem multiplicar ao retomar.
5. Depois, expandir Renegade/Medic e só então os gadgets de Scrap.

Munição básica deve ser sustentável sem obrigar a comprar Ammo Recovery.
Efeitos de abate têm limite e não se ativam recursivamente a partir de outros
efeitos. Perfurantes respeitam colisões, alcance e orçamento de queries.
Sem novas pesquisas globais de inimigos por frame, partículas ilimitadas ou
spawns adicionais. Benchmark com horda e soak de 15–30 minutos antes de aceitar.

Scrap continua temporário: não compra pontos permanentes. Granadas, iscas,
minas e torres portáteis ficam numa etapa posterior; nenhum nó desta primeira
proposta depende de gadgets ainda por implementar.

## Validação desta etapa

Revisão de definições e economia atuais; esboço de apresentação, sem alterar
scripts Godot, cenas, inputs ou saves. Não exige passos no editor. Rever as
ligações e selecionar os nós na conversa; equilíbrio de combate não foi testado.

Esboço validado em Edge headless: 36 seleções em cada uma das seis combinações
de largura (736/360/320 px) e tema (claro/escuro), com atualização da descrição,
seleção única, três ramos, ligações desenhadas e ausência de overflow horizontal
ou erros JavaScript. Captura desktop revista. Sem instalação de browsers.
