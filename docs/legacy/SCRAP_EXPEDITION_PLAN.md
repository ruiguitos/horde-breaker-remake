# Scrap na expedição — posto Dawn Supplies

2026-09-07. Primeira entrega implementada após autorização para continuar.

## Implementado e como testar

F5 → run nova → caixa verde DAWN SUPPLIES junto à tenda, à esquerda do núcleo
(108, terreno, 390). Aproximar e premir F (ou binding configurado).

1. DEPOSIT CARRIED SCRAP transfere para o saldo armazenado, sem criar moeda.
2. Munição da arma ativa: dois carregadores para a reserva por 20 Scrap.
3. Tratamento: até 50 HP por 25 Scrap.
4. Benefício/custo parciais são calculados antes de comprar; arredondamento do
   preço para cima ao Scrap inteiro. Reservas/vida cheias não são cobradas.
5. Menu mostra saldo transportado/armazenado, arma e quantidade; pausa combate.
   BACK TO EXPEDITION, F ou Escape fecham e retomam. Não é possível comprar longe
   do posto ou com o menu fechado. Duplo clique tem guarda de 250 ms.
6. Saldo acompanha Resume Run; uma partida nova começa sem Scrap. Nada converte
   Scrap em Credits e nenhuma ponte passa a cobrar Scrap.

Sem edição manual de cenas/terreno. Testar ambas as armas, quantidades parciais,
depósito, cura, stocks cheios e regresso ao menu/Resume. Valores são experimentais.
Ainda faltam melhorias do posto, posto Forest e balanceamento em combate longo.

## Validação desta entrega

- Godot 4.7.2: `test_dawn_supplies` 28/28 headless no original e 28/28 na variante;
  30/30 com renderer em 1152×648 (inclui duas capturas em `.godot/dawn_supplies`).
- `test_expedition_hud_missions` adaptado à remoção do painel: 24/24 headless.
- Após corrigir a dependência de autoload, pontes/progressão original: 27/27;
  `git diff --check` sem erros. A primeira passagem com erros de compilação
  não conta como aprovação, apesar de o teste antigo devolver saída 0.
- O teste Escape foi corrigido para aguardar o processamento do evento. Corrigida
  referência antecipada ao autoload SettingsManager detetada no teste das pontes.
- Persistem avisos Terrain3D e alguns recursos/ObjectDB no encerramento de
  determinadas suites. Não houve benchmark/soak nem alegação de corrigir crashes.

## Ficheiros e Git

Novos: `scripts/systems/dawn_supply_station.gd`, `tests/test_dawn_supplies.gd`.
Alterados: HUD, hub Dawn, suite HUD/missões e os seis documentos abaixo.
O antigo script do painel não foi apagado; já não é instanciado. Sem commit/push.
Preservar alterações anteriores: os ficheiros partilhados requerem seleção de hunks.

```powershell
git status
git add scripts/systems/dawn_supply_station.gd tests/test_dawn_supplies.gd
git add -p scripts/ui/game_hud.gd scripts/systems/dawn_beach_hub.gd tests/test_expedition_hud_missions.gd docs/GDD.md docs/ARCHITECTURE.md docs/ROADMAP.md docs/PROGRESS.md docs/HUD_AND_OUTER_MISSIONS.md docs/SCRAP_EXPEDITION_PLAN.md
git commit -m "feat: add Dawn scrap supplies and simplify weapon HUD"
```

Adicionar os dois `.gd.uid` se gerados pelo editor. As propostas originais abaixo
ficam como histórico, não como estado atual.

## Situação confirmada

CampEconomy acumula Scrap, atualiza o HUD e conta para a mastery de recolha.
Existem depósito, compras com saldo armazenado e melhorias de resupply/range/
scavenging. Os consumidores funcionais são o CampCore, pedestais e torres da
arena anterior, não os modelos decorativos de Dawn Beach.

## Primeira entrega recomendada

Um posto de abastecimento em Dawn Beach, separado dos terminais de missão:

1. Depositar Scrap transportado, reutilizando a economia existente.
2. Comprar munição e tratamento, mostrando preço e benefício antes da compra.
3. Mostrar saldo transportado/armazenado e resultado da transação no HUD/posto.

Valores experimentais para playtest: pacote de munição por 20 Scrap e tratamento
por 25 Scrap. A quantidade de munição deve ser proporcional à arma; não usar uma
quantidade universal que favoreça rifles e desvalorize shotguns. Não cobrar se
reservas/vida estiverem cheias; definir explicitamente compras parciais.

## Depois de validar

- Melhorias por run para eficiência/capacidade de abastecimento, três níveis e
  custos crescentes. Reutilizar o catálogo existente apenas com efeitos reais.
- Um posto secundário após a missão de Forest evita regressos repetitivos ao
  início. Separá-lo do guincho para não disputar a interação F.
- Mais tarde: equipamento temporário ou torres opcionais. Não integrar uma
  fortaleza completa na primeira entrega.

## Regras e testes

- Scrap temporário; Credits permanentes. Sem conversão direta entre ambos.
- A ponte obrigatória continua a exigir peças, nunca um custo de Scrap que
  possa deixar a run sem saída.
- Testar saldo insuficiente, duplo F, stocks cheios, compra parcial, troca de
  arma, nova run e suspensão/retoma. Débito e benefício têm de ser consistentes.
- Medir Scrap ganho/gasto por minuto e munição útil comprada. O benchmark atual
  pode injetar munição e não substitui um teste de balanceamento económico.
