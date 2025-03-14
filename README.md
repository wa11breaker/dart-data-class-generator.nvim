# Dart Data Class Generator for Neovim

> **Inspired by**: [Dart Data Class Generator for VS Code](https://marketplace.visualstudio.com/items?itemName=dotup.dart-data-class-generator)
A Neovim plugin that generates boilerplate code for data classes in Dart.

## Features

- [x] Constructor Generation
- [x] fromMap/toMap Methods
- [x] copyWith Method
- [ ] Equality Methods
- [ ] toString Method

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'wa11breaker/dart-data-class-generator.nvim',
    dependencies = {
        "nvimtools/none-ls.nvim", -- Required for code actions
    },
    ft = 'dart',
    config = function()
        require("dart-data-class-generator").setup({})
    end
}
```

## License

This plugin is licensed under the [MIT License](LICENSE).
