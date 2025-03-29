local constructor_generator = require("dart-data-class-generator.generator.constructor")
local get_parameter_list = constructor_generator._get_parameter_list
local get_constructor_template = constructor_generator._get_constructor_template
local generate_constructor = constructor_generator.generate_constructor

local eq = assert.are.same

--- Tests for generation of Dart constructor parameter list
describe("dart-data-class-generator.generator.constructor.get_parameter_list", function()
    it("should return empty table when no variables are passed", function()
        assert.are.same(get_parameter_list({}), {})
    end)

    it("should handle non-nullable parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = false, },
            { name = "age",  type = "int",    is_nullable = false, },
        }
        local expected = { "required this.name", "required this.age" }
        eq(get_parameter_list(variables), expected)
    end)

    it("should handle nullable parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = true, },
            { name = "age",  type = "int",    is_nullable = true, },
        }
        local expected = { "this.name", "this.age" }
        eq(get_parameter_list(variables), expected)
    end)

    it("should handle mixed order of nullable and non-nullable parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name",  type = "String", is_nullable = false },
            { name = "age",   type = "int",    is_nullable = true },
            { name = "email", type = "String", is_nullable = false },
        }
        local expected = { "required this.name", "this.age", "required this.email" }
        eq(get_parameter_list(variables), expected)
    end)
end)

describe("dart-data-class-generator.generator.constructor.get_constructor_template", function()
    it("should return empty constructor if no parameters are passed", function()
        local expected = "User();"
        assert.are.same(get_constructor_template("User", {}), expected)
    end)

    it("should reutrn contructor with parameters", function()
        local expected = [[
User({
  required this.name,
  required this.age,
});]];
        assert.are.same(
            get_constructor_template("User", { "required this.name", "required this.age" }),
            expected
        )
    end)
end)

describe("dart-data-class-generator.generator.constructor.generate_constructor", function()
    it("should return empty constructor if no parameters are passed", function()
        --- @type ClassInfo
        local varaibles = {
            bufnr = 0,
            name = "User",
            line_number = 0,
            variables = {},
        }
        local expected = "User();"
        assert.are.same(generate_constructor(varaibles), expected)
    end)

    it("should return constructor if parameters are passed", function()
        --- @type ClassInfo
        local varaibles = {
            bufnr = 0,
            name = "User",
            line_number = 0,
            variables = {
                { name = "name", type = "String", is_nullable = false, },
                { name = "age",  type = "int",    is_nullable = false, },
            },
        }
        local expected = [[
User({
  required this.name,
  required this.age,
});

]]
        assert.are.same(generate_constructor(varaibles), expected)
    end)
end)
