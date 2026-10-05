# Horde Breaker — Plano de expansão de classes, armas e skills

Estado: direção de design de 2026-08-01, corrigida contra o código em 2026-09-06.
Os candidatos continuam propostas, não personagens entregues. Consultar
[PROJECT_AUDIT.md](PROJECT_AUDIT.md) antes de expandir o catálogo.

## Regras de expansão

1. O combate jogável usa apenas armas de fogo. Não serão criadas novas armas,
   evoluções ou skills melee.
2. Uma classe nova precisa de quatro diferenças reais: papel de combate,
   passivo, combinação de loadout e grupo de skills específicas.
3. Nenhuma combinação primária/secundária pode repetir outra classe, mesmo com
   a ordem dos slots trocada.
4. Uma classe só entra quando as duas armas têm visual compatível com o rig,
   animações de mira/disparo/recarga e orçamento de render medido.
5. Adicionar uma classe não pode aumentar o orçamento da horda. O limite global
   normal mantém-se em 90 inimigos ativos.

## Matriz atual

| Classe | Papel | Loadout base | Identidade |
|---|---|---|---|
| Recruit | Assault | Assault Rifle + Pistol | dano sustentado e recarga rápida |
| Renegade | Vanguard | Shotgun + SMG | pressão a curta distância e 150 HP |
| Medic | Support | Pistol + SMG | sobrevivência por regeneração; selecionável após desbloqueio |

O Medic partilha a SMG com o Renegade, mas não o par de armas: Pistol + SMG
é diferente de Shotgun + SMG. Uma ability de suporte pode aprofundar a sua
identidade; não é necessária para corrigir uma duplicação de loadout inexistente.

## Candidatos para expansão

| Prioridade | Classe candidata | Loadout proposto | Papel/passivo | Dependência |
|---|---|---|---|---|
| 1 | Heavy Gunner | Machine Gun + Pistol | supressão; reduz a penalização de movimento e ganha resistência enquanto mantém fogo | usa armas existentes; exige suporte genérico a mais de três classes no save/UI |
| 2 | Recon Scout | DMR + SMG | precisão e mobilidade; headshots revelam loot/inimigos próximos | nova DMR e animação/visual compatível |
| 3 | Field Engineer | Carbine + Tool Pistol | defesa da base; repara torres e estruturas com melhor eficiência | duas armas de identidade e integração limitada com o acampamento |
| 4 | Demolitionist | Grenade Launcher + Pistol | controlo de multidão; explosões fortes com munição escassa | projétil, dano em área, feedback e visual novos |

O **Heavy Gunner** é o vertical slice recomendado: oferece um papel diferente
com o menor risco de arte e permite primeiro tornar o catálogo de classes e o
save orientados a dados. Recon Scout vem depois para acrescentar a família de
precisão; Field Engineer e Demolitionist têm mais dependências sistémicas.

## Expansão de skills

O catálogo atual tem 54 nós, 18 por classe, com ranks; não uma árvore comum de
36 nós. As linhas abaixo são propostas de comportamento para rever as skills
existentes antes de acrescentar módulos. A proposta antiga de 6 skills novas
por classe nos níveis 5/10/18 precisa primeiro de validação da progressão:

| Classe | Linha A | Linha B |
|---|---|---|
| Recruit | controlo de recoil/cadência | reload e troca de arma |
| Renegade | pellets, stagger e dano próximo | mobilidade e resistência próxima |
| Medic | cura/regeneração ativa | munição e resupply para a base |
| Heavy Gunner | spin-up e carregadores pesados | armadura durante fogo sustentado |
| Recon Scout | headshots e alcance | velocidade, deteção e loot |
| Field Engineer | reparação e custo de construção | dano/alcance das torres |
| Demolitionist | raio e knockback | munição e efeitos elementais |

Os bónus específicos devem usar efeitos próprios e limites claros; não devem
duplicar `damage_mult`, `max_health_add` ou `move_speed_mult` apenas com nomes
diferentes.

## Ordem técnica

1. Confirmar em playtest os três loadouts atuais e o teto de 90 zombies.
2. Substituir os `if` de três classes no `SaveManager` e menus por um catálogo
   de `CharacterData`, mantendo a migração dos IDs atuais.
3. Implementar Heavy Gunner + Machine Gun/Pistol como vertical slice.
4. Acrescentar o primeiro módulo de 6 skills específicas e validar a leitura da UI.
5. Medir FPS, memória, clareza do HUD e progressão antes de criar a classe seguinte.

## Critérios de aceitação por classe

- loadout não repetido e ambas as armas visíveis nas mãos;
- passivo percetível sem depender apenas de mais dano/vida;
- 6 skills específicas com efeitos testáveis;
- compra, seleção, ARMORY e save/migração cobertos por testes;
- teste manual de uma run e benchmark com 90 inimigos sem regressão material.
