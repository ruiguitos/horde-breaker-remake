# Armas originais para Horde Breaker

Cinco modelos estáticos originais, gerados no Blender 5.2.2 LTS exclusivamente
com geometria construída pelo script. Sem malhas, fotografias, digitalizações
ou texturas descarregadas. Modelos e scripts desta pasta: **CC0-1.0**.
As referências abaixo pertencem aos respetivos titulares e não são incluídas.

## Reprodução

Manter os três scripts Python e `mount_review.json` ao lado do gerador:

```text
blender --background --factory-startup --python build_weapons.py
```

O gerador grava os cinco GLB na sua pasta, os cinco `.blend` em `sources/`,
15 renders PNG de 1440×960 em `previews/`, os testes geométricos em `checks/`
e o relatório agregado em `validation.json`. Só usa módulos do Blender,
biblioteca padrão Python e os dois validadores locais fornecidos.
`-- --only smg` reconstrói uma arma; `-- --no-render` omite os renders.

## Referências de proporções

São interpretações originais de classes, não réplicas de um SKU. O comprimento
pedido para o jogo prevalece sobre a dimensão de cada referência comercial.
Foram consultados os dados dimensionais e as descrições; não foram utilizadas
fotografias protegidas na criação da geometria.

| Ficheiro | Referência pública | Dimensão da referência | Dimensão pedida |
|---|---|---:|---:|
| `assault_rifle.glb` | [Colt CR6920-EPR, ficha do fabricante, 2024](https://www.colt.com/wp-content/uploads/2024/08/24-COLT-LE-BI-FOLD-FINAL.pdf) | 0,923 m, coronha estendida | 0,96 m |
| `smg.glb` | [H&K MP5A2, catálogo do fabricante, 2012](https://s3.amazonaws.com/hk-manuals/files/Catalogs/Combined/HK_Combined_Catalog_2012.pdf) | 0,680 m | 0,74 m |
| `machine_gun.glb` | [FN M249S, ficha do fabricante](https://fnamerica.com/products/rifles/fn-m249s/) | 40,75 pol. ≈ 1,035 m | 1,04 m |
| `shotgun.glb` | [Remington 870, manual militar SW370-BC-OPI-010, §1-4, cópia pública](https://www.scribd.com/document/285654694/Sw370-Bc-Opi-010-Shotgun-Remington-12-Gauge-870-June-1996) | 40,75 pol. ≈ 1,035 m | 1,04 m |
| `marksman.glb` | [H&K G28, ficha técnica do fabricante](https://s3.amazonaws.com/hk-manuals/files/Military/G28/G28E_Technical_Data.pdf) | 0,965–1,082 m | 1,12 m |

A marksman combina a classe DMR da ficha com coronha original de polegar e
guarda-mão em madeira, evocando a família SVD. Não reproduz um G28 nem um SVD.
A M249S é uma referência dimensional civil da família M249/Minimi; o modelo
visual representa a classe de metralhadora ligeira pedida.

## Contrato e validação

GLB em metros: +Y para cima, frente −Z, raiz e malhas com transformação
identidade. Origem colocada no ponto de pega da mão direita; na shotgun,
no punho da coronha. `Muzzle` fica na boca do cano, com −Z local para fora.
`sources/` usa os eixos nativos do Blender (+Z cima, +Y frente); a conversão
acontece na exportação. As cenas fonte e GLB não contêm câmaras ou luzes.
As luzes e câmaras dos renders são temporárias e não são guardadas.

`validation.json` mede os GLB exportados, não apenas os valores do gerador.
O atlas UV é comum a todas as peças de cada arma, sem espelhamento ou
sobreposição, em 0–1. A densidade P95/P05 fica aproximadamente entre 1,09
e 1,13. Normais e tangentes existem em todas as primitivas. Os relatórios
guardam os erros numéricos medidos e as tolerâncias utilizadas.

Cada peça é fechada, manifold e tem volume positivo; são rejeitadas faces
degeneradas e candidatos BVH a auto-interseção. Os contactos entre peças
são enumerados em `checks/*_geometry.json` e revistos em `mount_review.json`:
pinos, encaixes, colares, ligações de bipé e relevos de superfície têm
sobreposições locais de montagem deliberadas. O teste de penetração usa
amostras e BVH; não equivale a uma prova exata de interseção de volumes.

`validate_godot.gd` descodifica diretamente os cinco GLB no Godot 4.7.2 e
verifica dimensões, triângulos, transformações, Muzzle e atributos das malhas.
O resultado está em `checks/godot_validation.json`.
O JEV verificou quatro afirmações finais contra os relatórios fornecidos;
o resultado consultivo está em `checks/jev_validation.json`.

## Simplificações e integração

Sem mecanismos internos completos, raiamento, animações ou inscrições de
fabricante. As peças móveis representam uma pose estática. Os carregadores
têm curvaturas e nervuras modeladas; as coronhas têm silhuetas próprias.
As lentes são discos refletivos opacos com o material `steel`; não simulam
refração nem ampliação. Madeira sem veio, ferrugem localizada numa anilha
da metralhadora e superfícies sem mapas: os UVs permitem texturização posterior.
Cada nome de material corresponde a um único material PBR; cada arma usa
apenas os materiais aplicáveis. Não há texturas incorporadas.

Os modelos estão integrados no projeto por `game/world/weapon_model.gd`.
O identificador existente `rifle` corresponde a `assault_rifle.glb`. O jogo
agrupa as peças estáticas por material (4–5 superfícies), partilha a malha
entre instâncias e ajusta o braço esquerdo ao guarda-mão de cada arma.
As peças separadas mantêm-se nos GLB e `.blend` para edição. Detalhes da
integração e das poses em `docs/tech/WEAPON_MODELS.md`, no repositório.
