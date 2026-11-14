---
titulo: "docs/tech/SETTINGS_INPUT.md"
tipo: "referencia"
estado: "referencia_a_confrontar"
atualizado: "2026-11-14"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/tech/SETTINGS_INPUT.md"]
---

# docs/tech/SETTINGS_INPUT.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original.

Fonte: `docs/tech/SETTINGS_INPUT.md` · SHA-256: `97c0bbb4f3c514fd56030c8defe2cf1febefc67ea3ff7003f845b9ce9ce9f2c0`

# Settings e imagens dos comandos — 2026-10-11

Os quatro separadores usam o mesmo painel, de 720 × 580 unidades de UI.
Numa janela menor, o painel adapta-se ao espaço disponível com uma margem
de 16 unidades. Só o conteúdo faz scroll; o título, os separadores e o
botão Done ficam acessíveis. A remarcação de teclas também conserva o tamanho.

Controls mostra a tecla/rato configurados e o botão do comando em colunas
separadas. O ícone do botão segue sempre o comando ligado: identifica o
primeiro comando (Xbox, PlayStation, Nintendo ou Steam Deck); sem comando
usa Xbox. Não há escolha manual de plataforma (removida a 2026-10-18, ver
[[90 Referências/docs/DECISIONS|DECISIONS.md]]). Ligar/desligar um comando atualiza a lista
aberta. Os ícones são apenas visuais: não trocam os botões nem alteram os
atalhos.

As imagens vêm do G.U.I.D.E já incluído no projeto (MIT), sem novos downloads.
As direções do stick são preservadas. Em headless ou sem o formatador,
mostra-se texto com os nomes da plataforma. Perfis com a escolha antiga
lêem-se sem erro e ignoram-na. Resultados de renderização assíncrona
antigos não substituem uma imagem entretanto atualizada.

Validação: `tests/test_settings.gd` cobre tamanho e posição nos quatro
separadores, janela de 640 × 360, plataformas, direções, persistência,
volumes e remarcação. Capturas reais em Forward+ verificam o painel e as
imagens do teclado e PlayStation.
