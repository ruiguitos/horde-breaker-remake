# Empunhaduras de primeira pessoa — cinco variantes

Cada arma carrega agora o seu próprio par de braços/mãos. Os cinco GLBs
partilham o rig `Arms`, os oito nomes de ossos e os três materiais originais,
mas a forma dos dedos e a posição das articulações são construídas para a
geometria da arma correspondente. Os GLBs e os `.blend` só contêm os braços.

| Arma | Triângulos | Adaptação |
|---|---:|---|
| rifle | 2 616 | Dedos fechados junto ao punho; apoio no guarda-mão circular |
| smg | 2 568 | Apoio mais próximo; dedos abaixo do tubo de armar |
| machine_gun | 2 658 | Mão mais à frente, no guarda-mão inferior, longe da caixa de munições |
| shotgun | 2 592 | Pega direita inclinada para a coronha convencional; mão esquerda no forend |
| marksman | 2 704 | Polegar direito pelo espaço da coronha; apoio sem deformar os dedos nas ranhuras |

## Construção e integração

Metros, +Y para cima, frente -Z; origem no ponto de empunhadura da arma.
`UpperArm` e `Forearm` conservam 0,30 m cada. O bind é alinhado e a pose
inicial é fletida, como na entrega original. Os ombros das armas compridas
são ajustados antes da construção para alcançar o apoio sem alongar ossos.
A mão direita fica na pose própria da arma; o IK esquerdo parte dessa pose.

Os dedos são malhas rígidas parentadas aos ossos `Hand_R`/`Hand_L`.
Mangas/palmas têm pesos rígidos e apenas a faixa do pulso usa 50/50.
Materiais: `sleeve_cloth`, `glove`, `skin`, sem texturas. Um atlas UV 0–1
sem sobreposição; normais e tangentes exportadas. Sem animações, luzes,
câmaras ou malhas das armas. `source/` tem `.gdignore` para impedir que o
Godot importe os ficheiros Blender como modelos adicionais.

`FirstPersonArms.MODELS` referencia explicitamente os cinco GLBs. Ao trocar
de arma, `ViewModel` escolhe a variante e aplica o contacto definido em
`WeaponModel.SUPPORT_POINTS`. Os pontos foram medidos na superfície real
das armas. A metralhadora usa apoio em Z=-0,35 m; o ponto anterior estava
perto da caixa de munições. O seu enquadramento de anca fica 6 cm abaixo do
das outras armas, para deixar a extremidade da manga fora da imagem.

## Reproduzir

Na pasta deste ficheiro:

```text
blender --background --factory-startup --python build_weapon_grips.py
```

Usa apenas módulos Blender/Python incluídos e reutiliza o script original
em `../arms_firstperson_original/build_arms.py`. Os cinco GLBs de armas em
`../../weapons/tactical_original/` servem temporariamente de gabarito.
Nada é descarregado. `-- --weapon shotgun` reconstrói apenas essa variante,
conservando as outras entradas do manifesto.

Saídas: `<arma>/arms_firstperson.glb`, `source/arms_<arma>.blend`, relatórios
por variante e `grip_profiles.json`. A arma de referência é removida antes
de criar e guardar os braços, incluindo os seus dados órfãos. O construtor
original continua a produzir o asset inicial sem alterar as suas medidas.

## Verificações

O build verifica sólidos manifold de volume positivo, faces não degeneradas,
pesos, bind, orçamento, densidade/ausência de sobreposição UV, normais e
tangentes. `validation.json` de cada variante lê os accessors reais do GLB.
`grip_validation.json` regista o ajuste contra a geometria original da arma.

As trajetórias das falanges são construídas em redor das secções das pegas.
As ranhuras são atravessadas pelos apoios largos dos dedos; não se seguem
as superfícies interiores das cavidades. Pequenas colisões locais das
almofadas das luvas são corrigidas contra a superfície, com folga nominal
de 0,6 mm. O teste numérico admite até 1,5 mm de contacto local nos vértices;
não é uma prova exata de ausência de interseções de todos os triângulos.

`godot_validation.json` mede a palma depois de aplicar os pesos à malha
real importada: erro inferior a 0,005 mm nas cinco variantes. Os testes são
`test_first_person_arms.gd`, `test_first_person_grip_assets.gd`,
`test_view_model.gd`, `test_weapon_models.gd` e `test_weapon_grips.gd`.
Este último também verifica as mãos das duas classes em terceira pessoa.
`source_validation.json` regista a reabertura dos cinco `.blend`.

As capturas estão em `docs/design/weapon_grips/`: primeira pessoa, apoio
esquerdo, pega direita, ADS e parede. Geram-se com
`tools/dev/weapon_grip_preview.gd`, num mundo isolado do Godot 4.7.2,
Compatibility, 1280×720, Recruit, FOV 70° (52,5° em ADS). A pose de grip
fica estática; não foram criadas novas animações de dedos, recarga ou pump.
A ótica e o enquadramento ADS das armas sem miras configuradas continuam
a usar o comportamento existente; esta entrega não implementa uma mira
telescópica funcional. A suite global continua condicionada pela pasta
`user://` sem permissão de escrita neste ambiente.

O JEV recebeu apenas resumos anonimizados dos testes e verificou a coerência
de duas afirmações sobre seleção de variantes, alcance e limites da evidência.
Não recebeu código, modelos ou imagens. É apoio consultivo; as verificações
de geometria e importação são as descritas acima.

## Referências e licença

Geometria e pegas: exclusivamente as armas originais do próprio projeto e
o construtor original dos braços. Referência anatómica bibliográfica:
[OpenStax — Bones of the Upper Limb](https://openstax.org/books/anatomy-and-physiology-2e/pages/8-2-bones-of-the-upper-limb).
Nenhuma imagem ou malha dessa fonte foi copiada.

Geometria, scripts e capturas originais: **CC0-1.0**. Ver `assets/LICENSES.md`.
