-- Run with: nvim --headless --clean -l tests/run.lua
-- Needs the dart tree-sitter parser (looked up in stdpath("data")/site).
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:prepend(vim.fn.getcwd())

local ddc = require("dart-data-class-generator")
local failures = 0

local function dedent(str)
    local lines = vim.split(str, "\n")
    if lines[#lines]:match("^%s*$") then
        table.remove(lines)
    end
    return lines
end

local function buffer(src, path)
    local bufnr = vim.api.nvim_create_buf(true, false)
    -- The LSP client applies edits by URI, so the buffer needs a name.
    vim.api.nvim_buf_set_name(bufnr, path or (vim.fn.tempname() .. ".dart"))
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, dedent(src))
    vim.bo[bufnr].filetype = "dart"
    return bufnr
end

local function check(name, got, want)
    if vim.deep_equal(got, want) then
        print("ok   " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name)
        print("--- want\n" .. table.concat(want, "\n") .. "\n--- got\n" .. table.concat(got, "\n"))
    end
end

local function test(name, opts)
    ddc.opts = vim.tbl_extend("force", { use_snake_case = false }, opts.opts or {})
    local bufnr = buffer(opts.src, opts.path)
    vim.api.nvim_win_set_cursor(0, opts.cursor or { 1, 6 })
    ddc.generate(opts.kind)
    check(name, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), dedent(opts.want))
end

test("all members, skipping static and initialized fields", {
    src = [[
class User {
  static int count = 0;
  final int id;
  final String? name;
  final x = 1;
}]],
    want = [[
class User {
  User({
    required this.id,
    this.name,
  });

  static int count = 0;
  final int id;
  final String? name;
  final x = 1;

  User copyWith({
    int? id,
    String? name,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}]],
})

test("one declaration with several fields", {
    kind = "constructor",
    src = "class P {\n  int a, b;\n}",
    want = "class P {\n  P({\n    required this.a,\n    required this.b,\n  });\n\n  int a, b;\n}",
})

test("replaces existing members and keeps const", {
    kind = "constructor",
    src = [[
class P {
  const P(this.a);
  final int a;
  final int b;
}]],
    want = [[
class P {
  const P({
    required this.a,
    required this.b,
  });
  final int a;
  final int b;
}]],
})

test("replaces a method with a block body", {
    kind = "toJson",
    src = [[
class P {
  final DateTime at;
  Map<String, dynamic> toJson() {
    return {};
  }
}]],
    want = [[
class P {
  final DateTime at;
  Map<String, dynamic> toJson() {
    return {
      'at': at.toIso8601String(),
    };
  }
}]],
})

test("private fields", {
    kind = "constructor",
    src = "class P {\n  final int _id;\n}",
    want = "class P {\n  P({\n    required int id,\n  }) : _id = id;\n\n  final int _id;\n}",
})

test("untyped fields are dynamic and optional", {
    kind = "copyWith",
    src = "class P {\n  var y;\n}",
    want = "class P {\n  var y;\n\n  P copyWith({\n    dynamic y,\n  }) {\n    return P(\n      y: y ?? this.y,\n    );\n  }\n}",
})

test("empty one-line class", {
    src = "class E {}",
    want = [[
class E {
  E();

  E copyWith() => E();

  Map<String, dynamic> toJson() => {};

  factory E.fromJson(Map<String, dynamic> json) => E();

  @override
  bool operator ==(Object other) => identical(this, other) || other is E;

  @override
  int get hashCode => runtimeType.hashCode;
}]],
})

test("collections, custom classes and snake_case keys", {
    kind = "fromJson",
    opts = { use_snake_case = true },
    src = [[
class P {
  final List<Item>? items;
  final Map<String, double> prices;
  final Set<int> ids;
  final void Function()? onTap;
}]],
    want = [[
class P {
  final List<Item>? items;
  final Map<String, double> prices;
  final Set<int> ids;
  final void Function()? onTap;

  factory P.fromJson(Map<String, dynamic> json) {
    return P(
      items: json['items'] == null ? null : (json['items'] as List<dynamic>).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList(),
      prices: (json['prices'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ids: (json['ids'] as List<dynamic>).map((e) => e as int).toSet(),
    );
  }
}]],
})

test("generic class", {
    kind = "copyWith",
    src = "class Box<T extends num> {\n  final T value;\n}",
    want = [[
class Box<T extends num> {
  final T value;

  Box<T> copyWith({
    T? value,
  }) {
    return Box(
      value: value ?? this.value,
    );
  }
}]],
})

-- Equality: collections are compared by content.
local dart_project = vim.fn.tempname()
vim.fn.mkdir(dart_project .. "/lib", "p")
vim.fn.writefile({ "name: app", "dependencies:", "  meta: any" }, dart_project .. "/pubspec.yaml")
local flutter_project = vim.fn.tempname()
vim.fn.mkdir(flutter_project .. "/lib", "p")
vim.fn.writefile({ "name: app", "dependencies:", "  flutter:", "    sdk: flutter" }, flutter_project .. "/pubspec.yaml")

test("equality with package:collection outside Flutter", {
    cursor = { 3, 6 },
    kind = "equality",
    path = dart_project .. "/lib/a.dart",
    src = [[
import 'dart:math';

class A<T> {
  final List<int> ids;
  final T value;
}]],
    want = [[
import 'dart:math';
import 'package:collection/collection.dart';

class A<T> {
  final List<int> ids;
  final T value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is A<T> &&
        const DeepCollectionEquality().equals(other.ids, ids) &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(ids), value);
}]],
})

test("equality with flutter/foundation.dart, replacing the old ==", {
    kind = "equality",
    path = flutter_project .. "/lib/a.dart",
    src = [[
class A {
  final List<int>? ids;
  final Set<String> tags;
  final Map<String, int> scores;

  @override
  bool operator ==(Object other) => false;
}]],
    want = [[
import 'package:flutter/foundation.dart';

class A {
  final List<int>? ids;
  final Set<String> tags;
  final Map<String, int> scores;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is A &&
        listEquals(other.ids, ids) &&
        setEquals(other.tags, tags) &&
        mapEquals(other.scores, scores);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(ids ?? const []), Object.hashAllUnordered(tags), Object.hashAllUnordered(scores.entries.map((e) => Object.hash(e.key, e.value))));
}]],
})

test("equality keeps an existing import and a single field's hashCode", {
    cursor = { 3, 6 },
    kind = "equality",
    path = flutter_project .. "/lib/b.dart",
    src = [[
import 'package:flutter/foundation.dart';

class B {
  final List<int> ids;
}]],
    want = [[
import 'package:flutter/foundation.dart';

class B {
  final List<int> ids;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is B &&
        listEquals(other.ids, ids);
  }

  @override
  int get hashCode => Object.hashAll(ids);
}]],
})

test("widget constructor", {
    kind = "constructor",
    src = [[
class Title extends StatelessWidget {
  final String text;
  final Color? color;
}]],
    want = [[
class Title extends StatelessWidget {
  const Title({
    super.key,
    required this.text,
    this.color,
  });

  final String text;
  final Color? color;
}]],
})

test("widget constructor without fields", {
    kind = "constructor",
    src = "class Logo extends StatelessWidget {}",
    want = "class Logo extends StatelessWidget {\n  const Logo({\n    super.key,\n  });\n}",
})

test("widget constructor with a mutable field isn't const", {
    kind = "constructor",
    src = "class Page extends StatefulWidget {\n  int count;\n}",
    want = "class Page extends StatefulWidget {\n  Page({\n    super.key,\n    required this.count,\n  });\n\n  int count;\n}",
})

-- Code actions through the built-in language server.
ddc.setup({ enable_code_actions = true })
local bufnr = buffer("class A {\n  final int a;\n  void f() {\n    print(a);\n  }\n}")
vim.wait(1000, function()
    return #vim.lsp.get_clients({ bufnr = bufnr, name = "dart-data-class-generator" }) > 0
end)
local client = vim.lsp.get_clients({ bufnr = bufnr, name = "dart-data-class-generator" })[1]

local function titles(row, col)
    local params = {
        textDocument = { uri = vim.uri_from_bufnr(bufnr) },
        range = { start = { line = row, character = col }, ["end"] = { line = row, character = col } },
        context = { diagnostics = {} },
    }
    local result = client and client:request_sync("textDocument/codeAction", params, 1000, bufnr)
    return vim.tbl_map(function(action)
        return action.title
    end, result and result.result or {})
end

check("code actions on the class", titles(0, 6), {
    "Generate data class", "Generate constructor", "Generate copyWith", "Generate toJson", "Generate fromJson",
    "Generate == and hashCode",
})
check("no code actions in a method body", titles(3, 4), {})

local function titles_for(src)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, dedent(src))
    return titles(0, 6)
end
check("only the constructor on widgets", titles_for("class W extends StatelessWidget {\n  final int a;\n}"), {
    "Generate constructor",
})
check("nothing on State classes", titles_for("class S extends State<W> {\n  int a = 0;\n}"), {})

-- A project's .nvim.lua calls setup() again; it's merged into the global options.
ddc.opts = { enable_code_actions = false, use_snake_case = false }
ddc.setup({ use_snake_case = true })
ddc.setup({})
check("setup() merges into earlier options", { ddc.opts.use_snake_case, ddc.opts.enable_code_actions }, { true, false })

print(failures == 0 and "\nall passed" or ("\n" .. failures .. " failed"))
vim.cmd.cquit({ count = failures > 0 and 1 or 0, bang = true })
