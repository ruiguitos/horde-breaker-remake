# Props realistas — primeiro conjunto

Integração de 2026-10-11: teste inicial com quatro modelos Poly Haven,
aprovado pelo utilizador, sem instalar Blender. Os `.blend` de 4K
extraídos em `assets/source/polyhaven/` ficam intactos e fora do Git.

## Assets utilizados

O jogo usa as versões glTF oficiais de 1K, descarregadas separadamente
através da API pública da Poly Haven. Não foi executado nenhum `.blend`
nem foi necessária conversão local. Os ficheiros e dependências têm os
tamanhos e MD5 confirmados em `assets/models/polyhaven/manifest.json`.
Total dos downloads deste conjunto: 11 253 849 bytes, cerca de 11,25 MB.
Ver autores e CC0 em `assets/LICENSES.md` e no `LICENSE.txt` do conjunto.
Os créditos do jogo passaram a indicar texturas e props da Poly Haven.

| ID no jogo | Modelo | Triângulos base no glTF | Uso |
|---|---|---:|---|
| `generator` | `portable_generator` | 26 419 | Objetivos Activate 3 |
| `jerrycan` | `metal_jerrycan_green` | 9 636 | Decoração junto ao gerador |
| `crate` | `wooden_crate_02` | 5 176 | Caixas opcionais de mantimentos |
| `barrier` | `concrete_road_barrier_02` | 23 822 | Paredes estreitas das ilhas geradas |

Os `.gltf.import` têm `meshes/generate_lods=true`. Estes números são
contagens de geometria base, não um benchmark do FPS com uma horda.

## Integração

`IslandProps` carrega os modelos com todos os componentes e materiais,
preservando os transforms originais. Calcula os limites, centra X/Z e
assenta os modelos no chão. O gerador é ajustado para 1 m de altura;
o caixote, para 0,7 m; o bidão mantém a escala original em metros.

`island.gd` mantém os nós dos objetivos e o seu feedback de progresso:
um pequeno indicador colorido acima do modelo substitui a primitiva
grande. O gerador concluído fica com indicador verde e perde o anel;
o caixote utilizado fica com indicador cinzento. O modelo de madeira
não recebe a cor do indicador. Não há animação de abertura da tampa.

O bidão é decorativo, não um novo objetivo de transporte. Segue a altura
do terreno ao lado do gerador e a sua visibilidade. As caixas aparecem
nas missões que já disponibilizam caixas; a lógica das recompensas
mantém-se em `IslandRun`.

Nas ilhas geradas, cada retângulo estreito que já bloqueava a navegação
passa a ter uma fila de barricadas, dentro da mesma área. É usado um
MultiMesh por parede. A altura de 1,6 m acompanha a parede anterior;
os modelos repetidos são ajustados ao comprimento disponível. A
transparência da câmara continua a funcionar, com material separado por
parede. As construções das ilhas feitas à mão não foram substituídas.

Os props não alteram a grelha de navegação nem adicionam física aos
objetivos. A colisão das barricadas continua a vir dos retângulos já
bloqueados. Colocar novas barricadas num mapa feito à mão exige incluir
a sua área nas colisões/navegação do próprio mapa.

## Comparação e reversão

Em `game/world/island.tscn`, desativar **Realistic Props** na raiz para
comparar com os objetos primitivos anteriores. A opção é de editor;
não foi acrescentada uma definição técnica ao menu do jogador.
Se um asset não estiver disponível, o objeto respetivo usa a primitiva.

Para reverter definitivamente uma integração já commitada, usar
`git revert <hash-do-commit-dos-props>`; não apagar os downloads originais
nem reescrever o histórico. O commit de preparação/inventário da pasta
source é independente desta integração.

## Continuação para o Claude

Ainda faltam os restantes oito modelos descarregados: barril, carrinho,
braseiro, rádio, boia, cais, kit de forte e barco Venus. Integrá-los em
passos verificáveis, escolhendo versões glTF ou preparando uma conversão
compatível. Não desativar o `.gdignore` da pasta source para importar os
originais de 4K em massa. As duas referências auxiliares em falta no
`.blend` do caixote não são dependências do glTF utilizado no jogo.

Preservar os indicadores dos objetivos, o fallback para primitivas,
os limites das barricadas e o fade da câmara. O renderer dummy headless
não devolve os transforms definidos em MultiMesh: o teste calcula os
limites a partir do layout em CPU. A renderização dos MultiMeshes foi
confirmada em capturas reais de Forward+.

## Validação

`tests/test_island_props.gd` cobre carregamento sem Blender, materiais,
escala, contacto com o chão, layouts horizontal/vertical, alternativa
com primitivas, feedback de conclusão e grelha de navegação intacta.
Foram inspecionadas capturas do conjunto junto ao Recruit e do gerador
no jogo, antes/depois e concluído, incluindo as três câmaras em Forward+.
Os 35 scripts de testes em `tests/` e `spikes/` passaram, incluindo o bot
de runs completas e a simulação prolongada, sem `TEST FAIL`, `SCRIPT ERROR`
ou erros de parsing. Foi usado um perfil de teste separado do utilizador.
Uma inversão temporária da orientação das barricadas foi detetada pelo
teste; o código foi reposto exatamente e o teste voltou a passar.

A importação registou avisos/erros já existentes dos addons de editor
(Dialogue Manager/Terrain3D); os três DLLs removidos pelo import foram
restaurados. Os testes mantêm o código de saída nativo do Godot no Windows
(`-1073741819`), apesar dos resultados limpos. Não foi medido o custo
destes modelos durante uma horda: essa comparação de desempenho fica
para uma sessão de jogo antes de alargar o conjunto.
