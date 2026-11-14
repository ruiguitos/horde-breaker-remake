# Integração neste projeto — 2026-11-14

Upstream: Assets2Godot **0.8.2**, tag `v0.8.2`, commit
`177b79b940afd80b2cf67816dff0d86b4e2d8fce`.

Pacote oficial: `assets2godot_v0.8.2_nobin.zip` (306 749 bytes).
SHA-256: `8826e2e92c9100c46f92e835fe2db506cbcc713c0c3d95eec696b8e86d5bc2df`.
Origem: <https://github.com/ikonnow/Assets2Godot/releases/tag/v0.8.2>.

## Modificações locais

- `project_policy.gd`: cliente auxiliar só pode iniciar se o projeto permitir
  explicitamente e o editor o pedir. A flag partilhada
  `assets2godot/allow_blendkit_client` está desligada; valores inválidos também
  não autorizam. Preferências globais de outros projetos não contornam isto.
- `plugin.gd`: aplica a política na inicialização e nas mudanças de definições;
  oculta BlendKit enquanto o cliente não for autorizado. Não cria UI nem
  serviços em sessões headless, e a saída tem o mesmo guard.
- `a2g/a2g_polyhaven.gd` e `a2g/a2g_ambientcg.gd`: preferência inicial de 1K.
- `client_connection.gd` e consumidores: enum `ClientState` evita a colisão
  com a classe global `State` de `PlayerCharacter/StateMachine/`.
- `a2g/a2g_scene_drop.gd`: usa a fonte regular do editor com emboldening,
  evitando consultar a fonte `main_bold`, inexistente no Godot 4.7.
- `ui/icons.gd`, `a2g/a2g_ui.gd`: usam `logo/asset-source.svg`, ícone original
  CC0, em vez da marca BlendKit; o ícone pequeno também foi substituído.
  Os SVG e descritores de importação das marcas substituídas foram removidos;
  `logo/LICENSE` do upstream fica preservado como aviso das marcas originais.

Estas adaptações ao código do addon seguem **GPLv2**. Os avisos originais e
`LICENSE` foram preservados. A exceção do utilizador cobre a ferramenta do
editor; não é permissão geral para qualquer asset fornecido pelas lojas.

O cliente opcional não está incluído no pacote e não deve ser descarregado
ou executado nesta configuração. O índice local dependente do daemon e o
BlendKit ficam fora deste primeiro uso; Poly Haven e ambientCG são o alvo.

## Atualização

Não substituir a pasta sem comparar as mudanças acima e repetir os testes.
O histórico de teste e o fluxo para o utilizador ficam em
`docs/tech/ASSETS2GODOT.md`. O teste de política está em
`tests/test_assets2godot.gd`.
