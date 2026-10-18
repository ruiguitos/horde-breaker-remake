# Braços de primeira pessoa — entrega original

**2 616 triângulos**, um rig `Arms` com oito ossos, duas malhas de
antebraço/palma e dez malhas de dedos. Geometria criada em Blender 5.2.2,
sem modelos de terceiros. As formas facetadas e os chanfros acompanham as
personagens do projeto. Luvas de trabalho com nós dos dedos descobertos,
pequena faixa de pele no punho e mangas lisas verde-oliva.

## Posição e escala

Metros; origem no ponto de empunhadura direita da espingarda; +Y para cima,
frente -Z. O nó `Arms` tem transformação identidade. A arma está ausente do
GLB e do `.blend`. A imagem `first_person_rifle.png` usa a espingarda
original do próprio projeto apenas como acessório temporário de verificação.

A superfície central de contacto da palma esquerda fica em
**(0, 0,077, -0,26) m**. A palma tem espessura e ocupa o espaço abaixo desse
plano de contacto. O erro medido na superfície exportada é inferior a
0,001 mm, também depois da importação e aplicação dos pesos no Godot.
O punho direito fica em **(0,040, -0,060, 0,060) m**; indicador estendido
ao longo do guarda-mato e polegar do lado esquerdo da empunhadura.

## Repouso alinhado e pose fixa fletida

Conforme a combinação confirmada pelo utilizador, os ossos de braço e
antebraço têm **0,30 m cada e estão alinhados no repouso de bind**. A pose
inicial de empunhadura dobra os cotovelos para baixo e para fora.
Não há clips, curvas de animação ou constraints de IK.

Posições das cabeças dos ossos no repouso de bind, em espaço da arma:

| Osso | X (m) | Y (m) | Z (m) | Comprimento (m) |
|---|---:|---:|---:|---:|
| Shoulder_R | 0,185000 | -0,160000 | 0,350000 | 0,035 |
| UpperArm_R | 0,220000 | -0,160000 | 0,350000 | 0,300 |
| Forearm_R | 0,068173 | -0,075652 | 0,105390 | 0,300 |
| Hand_R | -0,083654 | 0,008696 | -0,139220 | 0,090 |
| Shoulder_L | -0,185000 | -0,100000 | 0,300000 | 0,035 |
| UpperArm_L | -0,220000 | -0,100000 | 0,300000 | 0,300 |
| Forearm_L | -0,128468 | -0,029171 | 0,023224 | 0,300 |
| Hand_L | -0,036935 | 0,041657 | -0,253553 | 0,090 |

`validation.json` contém as posições completas de cabeça e cauda, o
repouso recuperado das matrizes inversas de bind e a pose fixa inicial.
Nessa pose, o punho esquerdo está em (-0,052, 0,030, -0,208) m.

**Integração Godot:** o importador conserva o repouso alinhado nas matrizes
de `Skin`, mas usa a pose fletida dos nós glTF como o repouso inicial de
`Skeleton3D`. São dois conjuntos de matrizes distintos. Chamar
`get_bone_global_rest()` devolve a configuração fletida; inverter as
matrizes de bind da `Skin` recupera o repouso alinhado. Ao criar um sistema
de IK que exija um repouso reto, configurar esse repouso a partir do bind
e reaplicar a pose de empunhadura. As duas configurações estão identificadas
separadamente em `godot_validation.json`.

## Pesos, materiais e UVs

Cada vértice tem um único osso, exceto uma faixa de 6,5 mm em redor do
plano do punho, limitada à região do pulso: 50% `Forearm` e 50% `Hand` do
mesmo lado. As mangas e palmas usam uma `Skin` partilhada. Cada dedo é uma
malha separada rigidamente parentada ao osso `Hand`, com grupo de peso 1
no `.blend`; o GLB usa filhos dos nós dos ossos, importados como
`BoneAttachment3D`, sem aplicar skinning duas vezes. Os dedos não se dobram
individualmente. Há 342 vértices exportados na faixa de mistura, incluindo
duplicados nas costuras de UV e nas normais planas.

Materiais PBR únicos `sleeve_cloth`, `glove` e `skin`, todos metallic 0,
cor base definida e roughness respetivamente 0,94, 0,86 e 0,66. Sem
texturas. Um UVMap por malha, num atlas global 0–1 sem sobreposições,
com densidade de área igualada: diferença máxima medida inferior a 0,15%.
Normais e tangentes unitárias e ortogonais exportadas e verificadas.

## Referências e simplificações

Referência anatómica pública:
[OpenStax — Bones of the Upper Limb](https://openstax.org/books/anatomy-and-physiology-2e/pages/8-2-bones-of-the-upper-limb),
apenas para organização de ombro, cotovelo, punho e dedos. As medidas de
0,30 m são as do contrato, não uma reprodução de medidas dessa página.
Nenhuma fotografia, imagem, scan ou malha externa foi incluída.

Só antebraços, mãos e mangas/punhos têm geometria visível; os ossos dos
braços superiores e ombros ficam fora do enquadramento de primeira pessoa.
Mangas sem simulação de tecido; dedos blocados sem ossos próprios.
Não há lógica de IK, recarga, movimento ou integração no controlador do jogo
nesta entrega. A geometria apoia a pose de empunhadura especificada.

## Reproduzir e verificar

Na pasta do script:

```text
blender --background --factory-startup --python build_arms.py
```

Usa apenas Blender/Python incluídos. Recria GLB, `.blend`, `validation.json`
e três PNGs com fundo cinzento; `-- --no-render` omite os PNGs. O acessório
da espingarda só é mostrado se o GLB original estiver na pasta de armas do
projeto. O `.blend` é guardado antes de criar câmaras/luzes ou importar
essa espingarda. Estes auxiliares não pertencem aos ficheiros entregues.

O build verifica sólidos fechados, volume positivo, faces degeneradas,
ossos, pesos, matrizes de bind, contacto da palma, atributos e interseções
dos triângulos UV do GLB real. `source_validation.json` regista a reabertura
do `.blend`. A importação independente em Godot 4.7.2 está em
`godot_validation.json`; pode repetir-se a partir da raiz do projeto com
`--headless --path . --script res://assets/models/characters/arms_firstperson_original/validate_godot.gd`.
O Godot quantiza pesos para 16 bits; o teste admite o erro de arredondamento
de duas unidades nesse formato, conservando os pesos fonte exatos.

## Licença

Geometria, script e renders originais: **CC0-1.0**. Referência OpenStax
apenas bibliográfica. Registado em `assets/LICENSES.md`.
