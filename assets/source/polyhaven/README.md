# Originais Poly Haven

Pasta preparada em 2026-10-11 para os modelos descarregados pelo utilizador.
A extração foi verificada nessa data: 11 modelos Poly Haven em Blender,
com texturas de 4K, e o barco Venus em glTF, com cor de 4K e normal de 2K.
O primeiro teste integra gerador, bidão, caixote e barricada através de
glTFs oficiais de 1K descarregados separadamente, sem Blender. Os originais
de 4K desta pasta não foram modificados. Estado e continuação:
[REALISTIC_PROPS.md](../../../docs/tech/REALISTIC_PROPS.md).

## Colocar os ficheiros

Extrair cada pacote para uma subpasta com o nome do modelo, por exemplo
`portable_generator/`. Conservar o `.blend`, as texturas e as restantes
pastas do pacote na sua estrutura original. Não copiar apenas o `.blend`:
as imagens podem estar guardadas em ficheiros separados.

O `.gdignore` impede a importação e exportação desta pasta pelo Godot.
O `.gitignore` local exclui os originais dos commits, sem os apagar.
Manter uma cópia de segurança própria dos downloads.

## Entrega verificada

| Pacote | Imagens | Tamanho extraído (MiB) |
|---|---:|---:|
| `Barrel_02_4k.blend/` | 4 | 17,9 |
| `barrel_stove_4k.blend/` | 5 | 34,1 |
| `concrete_road_barrier_02_4k.blend/` | 4 | 60,7 |
| `industrial_storage_cart_4k.blend/` | 4 | 43,1 |
| `lifebuoy_4k.blend/` | 4 | 46,9 |
| `metal_jerrycan_green_4k.blend/` | 4 | 56,9 |
| `modular_fort_01_4k.blend/` | 10 | 616,7 |
| `modular_wooden_pier_4k.blend/` | 7 | 311,3 |
| `portable_generator_4k.blend/` | 6 | 50,9 |
| `vintage_radio_transceiver_4k.blend(1)/` | 8 | 137,0 |
| `wooden_crate_02_4k.blend/` | 4 | 47,6 |
| `venus_a_shetland_fourareen/` | 2 | 29,9 |

Total dos pacotes: 1 523 521 349 bytes, aproximadamente 1,52 GB / 1,42 GiB.
Os nomes das pastas resultam da extração dos ZIPs e podem manter-se.

Foram verificados a descompressão e os cabeçalhos dos 11 `.blend`, os
caminhos das imagens referenciadas e a existência das 62 imagens.
37 PNG/JPEG passaram a verificação do Pillow; 25 EXR têm cabeçalhos e
dimensões válidos. As imagens Poly Haven têm 4096×4096; no barco, a cor
tem 4096×4096 e o normal tem 2048×2048. O glTF 2.0 do barco referencia corretamente `scene.bin` e as
duas imagens, e o buffer tem o tamanho esperado. O `license.txt` do barco
indica CC0-1.0 e o Scottish Maritime Museum como autor.

O `.blend` do caixote contém duas referências externas da origem que
não acompanham o pacote: um alpha de escultura `scan_07_c_heavy_wear.png`
e o HDRI `studio_small_06_4k.exr`. As quatro texturas principais do objeto
estão presentes. Durante a conversão, verificar e remover/substituir
essas dependências auxiliares se necessário; não levar a iluminação do
ficheiro de trabalho para o jogo.

Esta inspeção não abriu os modelos no Blender nem os renderizou no
Godot. Antes da integração, falta confirmar os materiais, escala e
exportação em Blender compatível. Não foram modificados os downloads.

## Integração futura

Usar estes originais para preparar versões de jogo em glTF/GLB, com
materiais compatíveis, escala em metros, colisões simples e LODs quando
adequado. Começar com texturas de 1K; avaliar 2K para superfícies grandes
ou próximas da câmara. Os originais de 4K ficam disponíveis para novas
exportações, sem necessidade de os voltar a descarregar.

As versões utilizadas pelo jogo devem ficar fora desta pasta, em
`assets/models/`, e ter a origem e licença registadas em
`assets/LICENSES.md`. Confirmar a versão e o conteúdo de cada pacote
antes de o integrar.

Fonte e licença: [Poly Haven — CC0](https://polyhaven.com/license).
Barco: [Venus — Scottish Maritime Museum](https://sketchfab.com/3d-models/venus-a-shetland-fourareen-ce4d6915e1d041459e08f2d8da521e86),
conforme `venus_a_shetland_fourareen/license.txt` incluído no download.
Importação: [formatos 3D do Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).
