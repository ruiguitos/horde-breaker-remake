# Ecrã de créditos

Implementado em 2026-10-11. A entrada **CREDITS** no título abre um painel
com o tema Atlântico. Esc, B e BACK fecham o painel e devolvem o foco ao
botão de origem. O conteúdo tem scroll; READ ABOVE/BELOW permitem lê-lo
com comando. A moldura adapta-se à janela, mantendo BACK visível.

## Atribuições

As fontes de verdade continuam a ser `assets/LICENSES.md` e as licenças
incluídas com os assets. O painel apresenta:

- **© OpenStreetMap contributors**, com ligação à página de direitos e
  licença ODbL; mapas da Berlenga.
- **The Milky Way panorama by ESO/S. Brunier, licensed under CC BY 4.0
  and used in original and modified forms.**, com ligações à imagem da
  ESO e à CC BY 4.0. O panorama é original; o star field foi modificado.
- Quaternius, Poly Haven, Ovani Sound, autores das fontes e ferramentas
  usadas pelo jogo, com as respetivas licenças.

Ao acrescentar assets que exijam atribuição, atualizar o registo de
licenças e `game/ui/credits_panel.gd`. O painel não substitui os avisos
de licença que acompanham os assets na distribuição.

## Validação

`tests/test_credits.gd` abre o painel através do título real e verifica
texto obrigatório, links, ausência de duplicação, leitura sem rato,
foco ao fechar e limites em 1152×648 e 640×360. Os links não são abertos
durante os testes.

Validação final em 2026-10-11: **31/31 scripts** passaram (28 testes do
jogo e três dos spikes), incluindo duas runs completas do bot com
extração nas seis ilhas. Capturas reais em Forward+ verificaram o título,
o painel de créditos e a janela pequena. A suite não apresentou
`TEST FAIL`, `SCRIPT ERROR` ou erros de parsing. Mantém-se o erro nativo
do Godot ao encerrar no Windows (`-1073741819`), já registado nas
validações anteriores; os resultados seguem o critério do projeto.

A revisão JEV recebeu apenas resumos sanitizados e foi inconclusiva.
A validação baseou-se na leitura local do código, nos testes e nas
capturas; uma mutação temporária da regra de seleção de armas foi
detetada pelos testes e o ficheiro foi restaurado integralmente.
