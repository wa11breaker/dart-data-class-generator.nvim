local constructor_generator = require("dart-data-class-generator.generator.constructor")
local generate_parameter_list = constructor_generator._generate_parameter_list

local eq = assert.are.same

--- Tests for generation of Dart construtor parameter list
describe("dart-data-class-generator.generator.constructor.generate_parameter_list", function()
    it("should return empty table when no variables are passed", function()
        assert.are.same(generate_parameter_list({}), {})
    end)

    it("should handle non-nullable parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = false, },
            { name = "age",  type = "int",    is_nullable = false, },
        }
        local expected = { "required this.name", "required this.age" }
        eq(generate_parameter_list(variables), expected)
    end)

    it("should handle nullable parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name", type = "String", is_nullable = true, },
            { name = "age",  type = "int",    is_nullable = true, },
        }
        local expected = { "this.name", "this.age" }
        eq(generate_parameter_list(variables), expected)
    end)

    it("should handle mixed order of nullable and non-nullable parameters", function()
        --- @type VariableDeclaration[]
        local variables = {
            { name = "name",  type = "String", is_nullable = false },
            { name = "age",   type = "int",    is_nullable = true },
            { name = "email", type = "String", is_nullable = false },
        }
        local expected = { "required this.name", "this.age", "required this.email" }
        eq(generate_parameter_list(variables), expected)
    end)
end)
