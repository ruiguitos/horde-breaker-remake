---
titulo: "Como usar e atualizar o cofre"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-15"
tags: ["horde-breaker"]
fontes: ["TODO.md", "AGENTS.md"]
---

# Como usar e atualizar o cofre

## Abrir

No Obsidian, abrir a pasta `vault` deste repositório como cofre existente. Começar em [[00 Início]]. Não exige plugins da comunidade; mapas, propriedades, ligações, backlinks e Canvas são recursos nativos.

## Três tipos de nota

| Área | Como usar |
|---|---|
| Mapas e fichas | Navegar e relacionar assuntos; todas têm fontes |
| `90 Referências/` | Cópias de consulta dos documentos; não substituem as fontes originais |
| `80 Trabalho/` e `99 Modelos/` | Registar ideias, sessões e ensaios sem criar um segundo backlog |

## Atualizar

No terminal, a partir da raiz do projeto:

```powershell
python 'vault/99 Ferramentas/sync_vault.py' --check
python 'vault/99 Ferramentas/sync_vault.py'
python 'vault/99 Ferramentas/validate_vault.py'
```

`--check` não escreve. A sincronização atualiza notas geradas que continuam intactas e **preserva notas editadas à mão**; os conflitos aparecem em `protected_user_edits` no manifest. Notas pessoais desconhecidas do gerador são preservadas. Não apaga notas nem devolve alterações às fontes.

O manifest guarda hashes das notas e das fontes. Conteúdo removido das fontes não é apagado automaticamente do cofre; rever a cobertura depois de uma atualização. Não há sincronização em tempo real.

## Trabalhar

Duplicar um modelo de `99 Modelos/`, guardar a nota em `80 Trabalho/Notas/` e ligá-la ao tema relevante. Para tarefas reais, atualizar o `TODO.md` original. Propostas ficam identificadas como propostas até decisão explícita.

## Validação e limites

O verificador testa ligações internas, dados copiados, inventário e ficheiros do cofre. Não executa Godot nem comprova o conteúdo de todas as propostas. Nesta entrega, a interface do Obsidian não foi aberta nem testada.

As respostas JEV desta tarefa ficam em `99 Ferramentas/JEV/`.
