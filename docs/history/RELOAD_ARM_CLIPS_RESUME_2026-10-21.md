# Recargas dos braços — validação concluída (2026-10-21)

Retoma autorizada pelo utilizador: **65/65 scripts headless passaram**,
todos com saída 0 e sem marcadores reais de falha nos logs de consola e do
engine. Foram retomados os testes em falta e repetidos os alterados/novos.
Commitado em e54c9ec (clips e ligação ao jogo) e f40bb55 (esta nota).
A revisão a jogar continua por fazer.

## Trabalho gravado

- Clips `reload_mag_smg` e `reload_mag_mg` nos GLB e fontes Blender respetivos,
  em `assets/models/characters/weapon_grips_original/`.
- Ferramentas `reload_clips.py` e `validate_reload_clips.py`; integração no
  gerador existente e documentação em `NOTES.md`.
- Relatórios de validação por variante e testes Godot dos clips. O teste
  específico passou numa execução focada com resolução de importação de 8000.
- Geometria base, oito ossos, três materiais e pontos de apoio preservados.
  Foram acrescentados morph targets para abrir os dedos durante a recarga.
- Surgiram alterações paralelas que ligam os clips ao jogo em
  `FirstPersonArms`/`ViewModel`; foram preservadas. O novo teste
  `test_first_person_reload.gd` também passou.

## Resultado da retoma

1. **Suite:** 65/65 scripts (jogo e spikes), incluindo câmara, braços,
   grips, recarga integrada e ViewModel. APPDATA isolada para os perfis
   de teste. Corrigido o falso alarme do runner temporário, sem alterar
   os critérios nem os testes do projeto.
2. **Importação:** 8000 amostras/s e otimização do AnimationPlayer
   desativada só nos dois presets. O otimizador causava deriva na MG antes
   de p=0,80 e erro de contacto superior a 1 mm. O teste verifica agora
   importação direta e nativa, a 401 valores de p cada uma.
3. **Geometria:** ambas as auditorias passaram, com 1133 amostras na SMG e
   1097 na MG. Corrigida a abertura dos dedos médio e anelar da MG junto
   do guarda-mato e da pega; sem alterar a pose de repouso nem relaxar
   tolerâncias. A auditoria reabre as fontes Blender e compara a malha
   e os ossos com o GLB.
4. **Rebuild e imagens:** ambos os rebuilds limpos mantêm os buffers e
   metadados estáticos originais; diferença máxima de componentes de
   animação inferior a 0,000001. Vistas dez poses em Godot 4.7.2,
   Compatibility: [pré-visualização](../design/weapon_grips/reload_clips.png).
5. **Relatórios:** atualizados `delivery_validation.json`, hashes,
   relatórios por variante e NOTES.md. A nova consulta externa JEV foi
   rejeitada pela aprovação automática por envolver informação privada;
   não foi obtido veredicto. Os resultados desta retoma são locais.

## Limites a preservar e comunicar

- A pose original já contém interseções na zona do punho: não prometer
  ausência absoluta de interseções. O auditor distingue contactos herdados
  na mobília do punho e novas penetrações no corpo da arma; ver NOTES.md.
- A fórmula real da SMG só termina a inserção em p=1, não em p=0,95;
  essa diferença face ao pedido está documentada.
- SMG: 2568 triângulos, 567 chaves, duração 1 s; palma em p=0,5
  `(0, -0.268, -0.143)` em metros, igual à base do carregador descido.
- MG: 2658 triângulos, 549 chaves, duração 1 s. Contagens de triângulos
  inalteradas. Os tempos completos e coordenadas estão em NOTES.md.

## Artefactos locais para retomar

Pasta:
`C:/Users/Rui/.codex/visualizations/2026/10/05/01a10cc0-7b07-7312-9916-7b70f4c6b83d/`

- `reload_tests/results.json`: 65 resultados finais; logs na mesma pasta.
- `resume_reload_tests.ps1`: runner temporário de retoma, já corrigido.
- `reload_baseline/`: cópias dos dois GLB e fontes originais.
- `reload_rebuild/`: rebuild isolado, confirmado com a última afinação MG.
- `reload_mg_resumed_validation.log`: auditoria final MG aprovada.
- `reload_clean_build_comparison.json`: comparação dos dois rebuilds.
- `reload_preview.gd`: usa resolução explícita de 8000.

Verificar `git status` antes de continuar: pode haver trabalho de outros agentes.
Preservar ficheiros handmade do utilizador e não incluir imports de imagens
de zombies sem relação com esta tarefa. Não editar DECISIONS.md.

## Prompt de passagem ao Claude

> Lê AGENTS.md, CLAUDE.md e este relatório. Os clips reload_mag_smg e
> reload_mag_mg estão nos GLB e fontes Blender, com validação geométrica,
> rebuild limpo e importação nativa aprovados. A suite retomada passou 65/65
> scripts; foram repetidos os testes novos/alterados após a importação final.
> Preserva animation/fps=8000 e optimizer/enabled=false nos dois presets.
> Não substituir a pose, apoios, oito ossos ou três materiais. Os detalhes
> dos tempos e coordenadas estão em assets/models/characters/weapon_grips_original/NOTES.md.
> Há alterações paralelas de integração da recarga e ADS no diretório de
> trabalho; concilia-as sem apagar os clips. Falta uma revisão manual da
> sensação da recarga a jogar e decidir os commits com o utilizador.
> As sobreposições herdadas da pega estão documentadas; não afirmar
> interseção absoluta zero. Commitado em e54c9ec (clips e ligação ao jogo) e f40bb55 (esta nota).
A revisão a jogar continua por fazer.

## Comandos de commit dos assets e validação

Estes comandos não incluem as alterações paralelas de gameplay/ADS.
Inspecionar o conteúdo preparado antes de confirmar o commit.

```powershell
git add -- assets/LICENSES.md assets/models/characters/weapon_grips_original/
git add -- tests/test_first_person_grip_assets.gd tests/test_reload_arm_clips.gd tests/test_reload_arm_clips.gd.uid
git add -- docs/tech/RELOAD_ARM_CLIPS_RESUME.md docs/tech/CODEX_HANDOFF.md docs/design/weapon_grips/reload_clips.png
git diff --cached --stat
git commit -m "feat: add progress-sampled SMG and machine gun reload clips"
```
