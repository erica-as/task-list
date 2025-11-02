# Relatório — Laboratório 2: Interface Profissional

## Implementações Realizadas

### Principais Funcionalidades

O núcleo deste laboratório foi a transição de um aplicativo de **página única** para uma **arquitetura robusta e persistente**, com múltiplas telas e um banco de dados local.

#### Arquitetura Multi-Tela

A aplicação foi dividida em duas telas principais:

- **TaskListScreen:** Exibe a lista de tarefas, estatísticas e controles de filtro/ordenação.
- **TaskFormScreen:** Formulário dedicado para criação e edição de tarefas.

#### Persistência de Dados com `sqflite`

As tarefas são salvas em um banco de dados SQL local, com suporte a **CRUD completo** (Create, Read, Update, Delete).

#### Sistema de Prioridades

As tarefas podem ser classificadas como:

> Baixa, Média, Alta ou Urgente

Cada uma exibe uma cor de destaque diferente no **TaskCard**.

#### Validação e Feedback

- **Formulário:** Validação via `GlobalKey<FormState>`.
- **SnackBar:** Mensagens de sucesso e erro.
- **AlertDialog:** Confirmação antes de exclusão.
- **RefreshIndicator:** “Puxar para atualizar”.
- **CircularProgressIndicator:** Exibido durante o carregamento.

#### Estados da Interface

A aplicação trata de forma inteligente os estados:

- **Carregando** → Exibe indicador circular.
- **Lista vazia** → Mensagens como “Nenhuma tarefa” ou “Nenhuma tarefa concluída”.

---

### Componentes do Material Design 3

Com `useMaterial3: true`, foram utilizados diversos componentes nativos do **Material Design 3**:

**Estrutura:**  
`Scaffold`, `AppBar`, `Column`, `Row`, `SingleChildScrollView`.

**Navegação e Ação:**  
`FloatingActionButton.extended`, `Navigator.push`, `PopupMenuButton`, `IconButton`.

**Exibição de Dados:**  
`Card`, `ListView.builder`, `Text`, `Icon`, `Chip`.

**Entrada de Dados:**  
`Form`, `TextFormField`, `DropdownButtonFormField`, `SwitchListTile`.

**Feedback:**  
`AlertDialog`, `SnackBar`, `RefreshIndicator`, `CircularProgressIndicator`.

**Tema:**  
`ThemeData`, `ColorScheme.fromSeed`, `ThemeMode.system`, `appBarTheme`.

---

## Desafios Encontrados

### Problema

Durante o Exercício 2 (Sistema de Categorias), ao adicionar o modelo `Category` e atualizar o `DatabaseService`, ocorreu o erro:

```

SqfliteFfiException(no such table: categories)

```

O erro surgiu porque o método `onCreate` do `sqflite` só é executado **na primeira criação do banco**, e o app usava uma versão antiga do arquivo `.db`.

### Diagnóstico

O log de erro apontava o caminho do banco desatualizado:

```

C:\Users\erica\source\task_manager.dart_tool\sqflite_common_ffi\databases\tasks.db

```

### Solução

- Tentativa inicial: **desinstalar o app** → não aplicável em ambiente desktop.
- Solução correta: **apagar manualmente o arquivo de banco de dados.**

#### Execução via Terminal (PowerShell)

```powershell
Remove-Item "C:\Users\erica\source\task_manager\.dart_tool\sqflite_common_ffi\databases\tasks.db*"
```

Após isso, o comando `flutter run` recriou o banco corretamente com a nova estrutura.

---

## Melhorias Implementadas

Além do roteiro base, foram adicionadas melhorias para tornar o app mais completo:

### Customização 1: Tema Escuro/Claro

`ThemeMode.system` configurado no `main.dart`, adaptando-se automaticamente ao tema do sistema.

### Exercício 2: Sistema de Categorias

- Modelo `Category` com **nome** e **cor**.
- `DatabaseService` atualizado com **LEFT JOIN** e `rawQuery`.
- `DropdownButtonFormField` no formulário para seleção da categoria.
- **Filtro por categoria** via `PopupMenuButton`.
- Exibição da categoria como um **Chip colorido** no `TaskCard`.

### Exercício 4: Compartilhamento de Tarefas

- Integração com o pacote `share_plus`.
- Botão “Compartilhar” em cada `TaskCard`.
- Método `_shareTask` que formata os detalhes e abre o menu nativo de compartilhamento.

---

## Aprendizados

### Conceitos-Chave

- **Arquitetura de Apps:** Separação de responsabilidades em múltiplos widgets e telas.
- **Banco de Dados Relacional:** Uso de `FOREIGN KEY`, consultas com `LEFT JOIN` e `rawQuery`.
- **Ciclo de Vida do sqflite:** Entendimento de `onCreate` e estratégias de migração.
- **Gerenciamento de Estado Assíncrono:** Uso de múltiplos estados (`_isLoading`, `_isLoadingCategories`) e `Future.wait()`.
- **Integração Nativa:** Uso de `share_plus` para interagir com funcionalidades do sistema operacional.

---

### Comparativo: Lab 1 × Lab 2

| Aspecto      | Lab 1                | Lab 2                                             |
| ------------ | -------------------- | ------------------------------------------------- |
| Persistência | Nenhuma              | Banco local `sqflite`                             |
| Estado       | Simples (`setState`) | Múltiplos estados assíncronos                     |
| Arquitetura  | Página única         | Multi-tela, organizada em pastas                  |
| UI           | Básica               | Profissional com feedback e tratamento de estados |

---

## Próximos Passos

### Objetivos da Próxima Aula

Ao final da próxima aula, o aluno deverá ser capaz de:

✅ Capturar e gerenciar **fotos** usando a **câmera**.
✅ Integrar o **acelerômetro** para detectar gestos (_shake_).
✅ Obter **localização GPS** do usuário.
✅ Converter **coordenadas em endereços** (_geocoding_).
✅ Configurar e gerenciar **permissões complexas**.
✅ Criar **experiências interativas** com recursos nativos do dispositivo.

---

📘 **Desenvolvido no contexto do Laboratório 2 — Disciplina de Desenvolvimento de Interfaces Móveis**
