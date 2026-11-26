# Dart Data Class Generator for Neovim

A Neovim plugin that generates data class boilerplate for Dart classes, as LSP code actions.

> **Inspired by**: [Dart Data Class Generator for VS Code](https://marketplace.visualstudio.com/items?itemName=dotup.dart-data-class-generator)



https://github.com/user-attachments/assets/33fff9f8-915c-4926-9c14-d49e33e9c76c


#### Features

- [x] Constructor
- [x] `copyWith`
- [x] `toJson` / `fromJson`
- [x] Equality (`==` / `hashCode`)
- [x] Widget constructors (`const Foo({super.key, ...})`)
- [x] Regenerates members that already exist instead of duplicating them
- [ ] `toString`

No none-ls needed: the code actions come from a small language server built into the plugin, so they appear next to dartls's in `vim.lsp.buf.code_action()` (`gra`).

Requires Neovim 0.11+ and the `dart` tree-sitter parser.

#### Installation

- With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'wa11breaker/dart-data-class-generator.nvim',
  ft = 'dart',
  opts = {
    enable_code_actions = true,
    use_snake_case = false, -- JSON keys in snake_case: `createdAt` -> 'created_at'
  },
}
```

- With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'wa11breaker/dart-data-class-generator.nvim',
  config = function()
    require('dart-data-class-generator').setup()
  end
}
```

#### Project config

Use Neovim's project-local config (`:help 'exrc'`). Enable it in your `init.lua`:

```lua
vim.o.exrc = true
```

Then add a `.nvim.lua` to the project root. Neovim asks you to trust it the first time. `setup()` calls are merged, so it only needs the options it changes:

```lua
require('dart-data-class-generator').setup({ use_snake_case = true })
```

#### Usage

Put the cursor anywhere in a class (outside method bodies) and open code actions:

- Generate data class (all of the below)
- Generate constructor
- Generate copyWith
- Generate toJson
- Generate fromJson
- Generate == and hashCode

On widgets (classes extending `...Widget`) only "Generate constructor" is offered, and it adds `super.key` and `const`. `State` classes get no actions.

Or use the command: `:DartDataClass [constructor|copyWith|toJson|fromJson|equality]` (no argument generates all of them). It works on any class, widgets included.

The buffer is formatted afterwards by any attached LSP client that supports formatting (dartls).

#### What gets generated

- Static fields and fields with an initializer are left out.
- Private fields (`_id`) become a named parameter `id` set in the initializer list.
- JSON conversion handles `int`, `double`, `num`, `String`, `bool`, `DateTime`, `Uri`, `Duration`, `List`, `Set`, `Map` and classes with their own `fromJson`/`toJson`, including nested and nullable types.
- Function-typed fields are left out of `toJson`/`fromJson`.
- `==` compares lists, sets and maps by content: with `listEquals`/`setEquals`/`mapEquals` from `package:flutter/foundation.dart` in Flutter projects, otherwise with `DeepCollectionEquality` from `package:collection` (add it to `pubspec.yaml`). The import is added when needed.
- Widgets are recognised by name (`extends ...Widget`), so a widget extending your own base class (`extends BaseCard`) gets all the actions.
- `copyWith` uses `value ?? this.value`, so it can't set a nullable field back to `null`.

#### Tests

```sh
nvim --headless --clean -l tests/run.lua
```

## License

This plugin is licensed under the [MIT License](LICENSE).
