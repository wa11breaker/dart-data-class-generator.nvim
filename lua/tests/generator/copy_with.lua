local copy_with_generator = require("dart-data-class-generator.generator.copy_with")
local get_parameter_list = copy_with_generator._get_parameter_list
local get_constructor_parameters = copy_with_generator._get_constructor_parameters
local get_copywith_template = copy_with_generator._get_copywith_template
local generate_copy_with = copy_with_generator.generate_copy_with

local eq = assert.are.same

--- Tests for generation of Dart copy_with method parameter list
describe("dart-data-class-generator.generator.copy_with.get_parameter_list", function()
    it("should return empty table when no variables are passed", function()
        assert.are.same(get_parameter_list({}), {})
    end)

    it("should handle parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = false, type_full = "String", },
            { name = "age",  type = "int",    is_nullable = false, type_full = "int", },
        }
        local expected = { "String? name", "int? age" }
        eq(get_parameter_list(variables), expected)
    end)

    it("should handle complex parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name",      type = "String", is_nullable = false, type_full = "String", },
            { name = "age",       type = "int",    is_nullable = false, type_full = "int", },
            { name = "hobbies",   type = "List",   is_nullable = false, type_full = "List<String>", },
            { name = "customMap", type = "Map",    is_nullable = false, type_full = "Map<String, String>", },
        }
        local expected = { "String? name", "int? age", "List<String>? hobbies", "Map<String, String>? customMap" }
        eq(get_parameter_list(variables), expected)
    end)
end)

describe("dart-data-class-generator.generator.copy_with.get_constructor_parameters", function()
    it("should return empty table when no variables are passed", function()
        assert.are.same(get_constructor_parameters({}), {})
    end)

    it("should handle parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = false, type_full = "String", },
            { name = "age",  type = "int",    is_nullable = false, type_full = "int", },
        }
        local expected = { "name: name ?? this.name", "age: age ?? this.age" }
        eq(get_constructor_parameters(variables), expected)
    end)

    it("should handle complex parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = false, type_full = "String", },
            { name = "age",  type = "int",    is_nullable = false, type_full = "int", },
            {
                name = "hobbies",
                type = "List",
                is_nullable = false,
                type_full = "List<String>",
            },
            {
                name = "customMap",
                type = "Map",
                is_nullable = false,
                type_full = "Map<String, String>",
            },
        }
        local expected = { "name: name ?? this.name", "age: age ?? this.age",
            "hobbies: hobbies ?? this.hobbies", "customMap: customMap ?? this.customMap" }
        eq(get_constructor_parameters(variables), expected)
    end)
end)

describe("dart-data-class-generator.generator.copy_with.get_copywith_template", function()
    it("should return empty copyWith if no parameters are passed", function()
        local expected = "User copyWith() => User();"
        assert.are.same(get_copywith_template("User", {}, {}), expected)
    end)

    it("should return constructor if parameters are passed", function()
        local expected = [[
User copyWith({
  String? name,
  int? age,
}) {
  return User(
    name: name ?? this.name,
    age: age ?? this.age,
  );
}
]]
        assert.are.same(
            get_copywith_template(
                "User",
                { "String? name", "int? age" },
                { "name: name ?? this.name", "age: age ?? this.age" }
            ),
            expected
        )
    end)
end)

describe("dart-data-class-generator.generator.copy_with.generate_copy_with", function()
    it("should return empty constructor if no variables are passed", function()
        --- @type ClassInfo
        local varaibles = {
            bufnr = 0,
            name = "User",
            line_number = 0,
            variables = {},
        }
        local expected = "User copyWith() => User();"
        assert.are.same(generate_copy_with(varaibles), expected)
    end)

    it("should return constructor if parameters are passed", function()
        --- @type ClassInfo
        local varaibles = {
            bufnr = 0,
            name = "User",
            line_number = 0,
            variables = {
                { name = "name", type = "String", is_nullable = false, type_full = "String", },
                { name = "age",  type = "int",    is_nullable = false, type_full = "int", },
            },
        }
        local expected = [[
User copyWith({
  String? name,
  int? age,
}) {
  return User(
    name: name ?? this.name,
    age: age ?? this.age,
  );
}
]]
        assert.are.same(generate_copy_with(varaibles), expected)
    end)
end)
