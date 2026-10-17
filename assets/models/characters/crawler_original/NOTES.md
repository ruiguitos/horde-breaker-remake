# Crawler original — entrega

Modelo original construído em Blender 5.2.2, com sólidos angulares,
chanfros pequenos e cortes booleanos. Sem malhas copiadas, downloads de
modelos, scans, texturas ou fotografias usadas na construção. A criação
não altera nem substitui ainda o Crawler que o jogo desenha atualmente.

## Referência de proporções

Referência pública de anatomia: OpenStax, *Anatomy and Physiology 2e*,
[8.2 — Bones of the Upper Limb](https://openstax.org/books/anatomy-and-physiology-2e/pages/8-2-bones-of-the-upper-limb).
Foi consultada para a relação ombro–úmero–cotovelo–antebraço–punho e a
organização da mão; não foram copiadas imagens ou malhas. Essa página
não fornece uma tabela de medidas para esta pose. As dimensões são
escolhas artísticas feitas para o contrato do utilizador, não medidas
antropométricas certificadas.

Referência de estilo: linguagem em blocos das personagens existentes do
projeto. Não foi reutilizada geometria dessas personagens. Cabeça, tronco,
braços, mãos e cotos são construídos pelo script desta pasta.

## Escala, pose e eixos

- Metros reais; +Y para cima e frente em -Z no GLB. Em Blender, Z é cima
  e +Y é frente; a conversão é feita pelo exportador glTF.
- Cabeça: centro anatómico de construção a **0,69 m**; peito: centro da
  região do esterno a **0,44 m**. Não são alturas da pele exterior nem
  dos pivôs. A altura do centro dos limites da malha da cabeça é também
  medida no JSON, separadamente. Só as mãos/antebraços apoiam no chão.
- Comprimento total aproximado de **1,33 m**, incluindo os dedos;
  cabeça até às pontas dos cotos aproximadamente **1,30 m**. Largura
  aproximadamente **0,60 m**. Valores exatos em `validation.json`.
- **4 728 triângulos**, oito malhas/nós com os nomes pedidos e seis
  materiais PBR. As duas mãos tocam o plano Y=0; nenhuma peça atravessa
  o chão. Cada malha é um único sólido ligado, fechado e de volume positivo.
- Ambos os membros inferiores estão ausentes. Os cotos terminam em
  carne irregular e uma ponta de osso; o tecido das calças prolonga a
  silhueta dos restos. Não há joelhos, pernas completas ou pés escondidos.

## Origem e pivôs

O nó raiz é a própria malha `Torso`: origem em `(0, 0, 0)`, no chão
diretamente sob as ancas, com transformação identidade. Não há um nono nó
de agrupamento no GLB. Todos os nós têm rotação identidade e escala um.
As translações dos nós filhos são necessárias para conservar os pivôs:
cabeça no pescoço, braços nos ombros, cotos nas ancas e mãos nos punhos.
«Transformações aplicadas» não elimina essas posições de articulação.

`Hand_Left` é filha de `Arm_Left`; `Hand_Right` de `Arm_Right`. As restantes
peças são filhas de `Torso`. Os nomes Left/Right são anatómicos: Left fica
em X negativo. Os braços incluem braço e antebraço num único sólido,
com o cotovelo já fletido; o contrato de oito nós não inclui um nó de
cotovelo. Não existe rig, animação, câmara ou luz no GLB ou no `.blend`.

## Materiais e UVs

Os seis materiais têm cor base, metallic zero e roughness explícitos:
`skin_rot`, `cloth_shirt`, `cloth_trousers`, `flesh_wound`, `bone` e
`hair_dark`. Feridas são cavidades geométricas com paredes e fundo;
costelas, dentes e ossos dos cotos são geometria original.

Sangue antigo e fresco usam variações de cor de vértices em
`flesh_wound`, conservando um único material. Ao substituir materiais no
jogo, conservar a multiplicação por `COLOR.rgb`/«Vertex Color → Use as
Albedo» para manter essa diferença. Os outros materiais têm tint de
vértices branco. A diferença de brilho é simplificada: a rugosidade do
material de carne é comum às feridas e ao sangue, sem mapas.

Cada malha tem um único UVMap em 0–1. As oito malhas partilham um atlas
global sem ilhas empilhadas, espelhadas ou sobrepostas, com escala de
área igualada entre peças. Isto também evita sobreposição entre malhas,
embora o contrato só exija a verificação individual. Os chanfros/cortes
produzem muitas ilhas pequenas. A diferença máxima de densidade fica
abaixo de 5%; o valor medido está no JSON. Normais e tangentes são
exportadas e verificadas em todas as primitivas GLB.

## Simplificações

- Formas facetadas, sem escultura orgânica, pele simulada ou roupa dinâmica.
- Sangue e bordos rasgados são estáticos; sem decalques ou fluido simulado.
- Duas falanges/dedos amputados na mão direita, com terminais fechados;
  dedos restantes têm geometria própria ligada à palma, sem articulação.
- Sem colisores por membro, lógica de rastejar ou integração na horda.
  Esta entrega é o asset e a sua validação, conforme o pedido.

## Reproduzir e verificar

Na pasta do script:

```text
blender --background --factory-startup --python build_crawler.py
```

O script usa apenas módulos incluídos no Blender/Python. Recria GLB,
`.blend`, relatório geométrico, `validation.json` e as vistas frontal,
lateral e a três quartos sobre fundo cinzento. Inclui ainda uma vista
traseira para mostrar os dois cotos e as feridas das costas. Usa Cycles,
preferindo OptiX quando disponível e conservando alternativa CPU.
`-- --no-render` omite apenas os PNGs. Não é necessário instalar pacotes.

As verificações de sólidos são feitas na malha Blender final: arestas
manifold, volume positivo por componente, faces degeneradas e candidatos
a autointerseção por BVH. No ficheiro GLB são lidos os accessors reais
para medir limites, contar triângulos, verificar atributos e recortar
pares de triângulos UV. São verificações numéricas, não uma prova
matemática exata de ausência de interseções.

`godot_validation.json` regista uma importação direta por `GLTFDocument`
em Godot **4.7.2**, com oito malhas, seis materiais, pivôs, atributos e
contagem de triângulos. Esse teste de integração é independente do build
Blender e não é recriado pelo comando acima. Não foi corrida a suite
completa do jogo, porque nenhum sistema de gameplay foi alterado.
`source_validation.json` regista ainda a reabertura do `.blend`, sem
câmaras/luzes/rigs/animações, a contagem das malhas e o contacto do pescoço.
Os hashes do GLB nos dois relatórios de integração identificam o mesmo
ficheiro final. Esses relatórios adicionais são evidência da entrega,
não dependências do script de construção.

## Licença

Geometria, script e renders originais desta entrega: **CC0-1.0**.
A referência anatómica é apenas bibliográfica; nenhum asset da OpenStax
foi incluído. O diretório está registado em `assets/LICENSES.md`.
