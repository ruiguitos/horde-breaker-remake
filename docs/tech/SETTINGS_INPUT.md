# Settings e imagens dos comandos — 2026-10-11

Os quatro separadores usam o mesmo painel, de 720 × 580 unidades de UI.
Numa janela menor, o painel adapta-se ao espaço disponível com uma margem
de 16 unidades. Só o conteúdo faz scroll; o título, os separadores e o
botão Done ficam acessíveis. A remarcação de teclas também conserva o tamanho.

Controls mostra a tecla/rato configurados e o botão do comando em colunas
separadas. «Controller icons» permite Auto, Xbox, PlayStation, Nintendo ou
Steam Deck. Auto identifica o primeiro comando ligado; sem identificação
usa Xbox. Ligar/desligar um comando atualiza a lista aberta. Esta escolha
é apenas visual: não troca os botões nem altera os atalhos.

As imagens vêm do G.U.I.D.E já incluído no projeto (MIT), sem novos downloads.
As direções do stick são preservadas. Em headless ou sem o formatador,
mostra-se texto com os nomes da plataforma. A preferência é guardada no
perfil; perfis anteriores usam Auto. Resultados de renderização assíncrona
antigos não substituem uma imagem entretanto atualizada.

Validação: `tests/test_settings.gd` cobre tamanho e posição nos quatro
separadores, janela de 640 × 360, plataformas, direções, persistência,
volumes e remarcação. Capturas reais em Forward+ verificam o painel e as
imagens do teclado e PlayStation.
