-- Dart code for each data class member. Pure string functions, no buffer access.
--
-- `cls` (see parser.lua):
--   name         class name
--   type_params  type parameter names, e.g. { "T" }
--   const        whether the constructor is const
--   widget       whether the class is a Flutter widget
--   fields       { name = "_id", type = "int?", final = true }, in declaration order

local M = {}

-- Types that are read from JSON with a plain cast and written as-is.
local plain = { int = true, String = true, bool = true, num = true, Object = true }

--- "_id" -> "id": private fields can't be named parameters.
local function param_name(field)
    return (field.name:gsub("^_+", ""))
end

local function to_snake(str)
    return (str:gsub("(%u+)(%u%l)", "%1_%2"):gsub("([%l%d])(%u)", "%1_%2"):lower())
end

--- Splits on commas outside of <>, () and {}.
local function split_args(str)
    local args, depth, start = {}, 0, 1
    for i = 1, #str do
        local c = str:sub(i, i)
        if c:match("[<({]") then
            depth = depth + 1
        elseif c:match("[>)}]") then
            depth = depth - 1
        elseif c == "," and depth == 0 then
            table.insert(args, vim.trim(str:sub(start, i - 1)))
            start = i + 1
        end
    end
    table.insert(args, vim.trim(str:sub(start)))
    return args
end

--- "Map<String, List<int>>?" -> { text, name = "Map", args = { ... }, nullable = true }
local function parse_type(text)
    text = vim.trim(text)
    local t = { text = text, nullable = text:sub(-1) == "?", args = {} }
    local base = t.nullable and text:sub(1, -2) or text
    t.base = base
    if base:match("%f[%w_]Function%f[^%w_]") or base:sub(1, 1) == "(" then
        -- Function types and records can't be converted to or from JSON.
        t.name = base:match("%f[%w_]Function%f[^%w_]") and "Function" or "Record"
        return t
    end
    t.name = base:match("^[%w_$.]+") or base
    local inner = base:match("^[%w_$.]+%s*<(.*)>$")
    if inner then
        for _, arg in ipairs(split_args(inner)) do
            table.insert(t.args, parse_type(arg))
        end
    end
    return t
end

local DYNAMIC = parse_type("dynamic")

local function non_null(t)
    local copy = vim.deepcopy(t)
    copy.nullable, copy.text = false, t.base
    return copy
end

local function is_list(name)
    return name == "List" or name == "Set" or name == "Iterable"
end

--- Expression converting JSON value `e` to type `t`, or nil if it can't be.
local function decode(t, e, type_params)
    local q = t.nullable and "?" or ""
    if t.name == "Function" then
        return nil
    elseif t.name == "dynamic" then
        return e
    elseif plain[t.name] or type_params[t.name] or t.name == "Record" then
        return e .. " as " .. t.text
    elseif t.name == "double" then
        return ("(%s as num%s)%s.toDouble()"):format(e, q, q)
    elseif t.nullable then
        local value = decode(non_null(t), e, type_params)
        return value and ("%s == null ? null : %s"):format(e, value)
    elseif t.name == "DateTime" or t.name == "Uri" then
        return ("%s.parse(%s as String)"):format(t.name, e)
    elseif t.name == "Duration" then
        return ("Duration(microseconds: %s as int)"):format(e)
    elseif is_list(t.name) then
        local item = decode(t.args[1] or DYNAMIC, "e", type_params)
        if not item then
            return nil
        end
        local list = ("(%s as List<dynamic>)"):format(e)
        if item == "e" then
            return t.name == "Set" and list .. ".toSet()" or list
        end
        return ("%s.map((e) => %s).%s"):format(list, item, t.name == "Set" and "toSet()" or "toList()")
    elseif t.name == "Map" then
        local key_type = t.args[1] or parse_type("String")
        local value = decode(t.args[2] or DYNAMIC, "v", type_params)
        local key = "k"
        if key_type.name == "int" or key_type.name == "double" or key_type.name == "num" then
            key = key_type.name .. ".parse(k)"
        elseif key_type.name ~= "String" and key_type.name ~= "dynamic" then
            key = decode(key_type, "k", type_params)
        end
        if not (key and value) then
            return nil
        end
        local map = ("(%s as Map<String, dynamic>)"):format(e)
        if key == "k" and value == "v" then
            return map
        end
        return ("%s.map((k, v) => MapEntry(%s, %s))"):format(map, key, value)
    end
    return ("%s.fromJson(%s as Map<String, dynamic>)"):format(t.text, e)
end

--- Expression converting `e` of type `t` to a JSON value, or nil if it can't be.
local function encode(t, e, type_params)
    local dot = t.nullable and "?." or "."
    if t.name == "Function" then
        return nil
    elseif plain[t.name] or type_params[t.name] or t.name == "dynamic" or t.name == "double" or t.name == "Record" then
        return e
    elseif t.name == "DateTime" then
        return e .. dot .. "toIso8601String()"
    elseif t.name == "Uri" then
        return e .. dot .. "toString()"
    elseif t.name == "Duration" then
        return e .. dot .. "inMicroseconds"
    elseif is_list(t.name) then
        local item = encode(t.args[1] or DYNAMIC, "e", type_params)
        if not item then
            return nil
        elseif item == "e" then
            return t.name == "List" and e or e .. dot .. "toList()"
        end
        return ("%s%smap((e) => %s).toList()"):format(e, dot, item)
    elseif t.name == "Map" then
        local key_type = t.args[1] or parse_type("String")
        local key = "k"
        if key_type.name ~= "String" and key_type.name ~= "dynamic" then
            -- JSON object keys must be strings.
            key = encode(key_type, "k", type_params)
            key = key == "k" and "k.toString()" or key
        end
        local value = encode(t.args[2] or DYNAMIC, "v", type_params)
        if not (key and value) then
            return nil
        end
        if key == "k" and value == "v" then
            return e
        end
        return ("%s%smap((k, v) => MapEntry(%s, %s))"):format(e, dot, key, value)
    end
    return e .. dot .. "toJson()"
end

local function type_param_set(cls)
    local set = {}
    for _, name in ipairs(cls.type_params) do
        set[name] = true
    end
    return set
end

local function json_key(field, opts)
    local key = param_name(field)
    return opts.use_snake_case and to_snake(key) or key
end

--- Joins `lines` one per line, indented by `n` spaces, each ending with a comma.
--- The caller puts the first line's indentation in the template.
local function block(lines, n)
    return table.concat(lines, ",\n" .. string.rep(" ", n)) .. ","
end

--- "Box<T>" for generic classes.
local function self_type(cls)
    if #cls.type_params == 0 then
        return cls.name
    end
    return cls.name .. "<" .. table.concat(cls.type_params, ", ") .. ">"
end

--- Widgets (cls.widget) get `super.key`, and are const when all fields are final.
function M.constructor(cls)
    local const = cls.const
    if cls.widget then
        const = vim.iter(cls.fields):all(function(field)
            return field.final
        end)
    end
    local prefix = const and "const " or ""
    if #cls.fields == 0 and not cls.widget then
        return ("%s%s();"):format(prefix, cls.name)
    end

    local params, initializers = { cls.widget and "super.key" or nil }, {}
    for _, field in ipairs(cls.fields) do
        local t = parse_type(field.type)
        local required = (t.nullable or t.name == "dynamic") and "" or "required "
        local name = param_name(field)
        if name == field.name then
            table.insert(params, required .. "this." .. name)
        else
            table.insert(params, required .. field.type .. " " .. name)
            table.insert(initializers, field.name .. " = " .. name)
        end
    end

    local init = #initializers > 0 and (" : " .. table.concat(initializers, ", ")) or ""
    return ("%s%s({\n  %s\n})%s;"):format(prefix, cls.name, block(params, 2), init)
end

function M.copy_with(cls)
    if #cls.fields == 0 then
        return ("%s copyWith() => %s();"):format(self_type(cls), cls.name)
    end

    local params, args = {}, {}
    for _, field in ipairs(cls.fields) do
        local name = param_name(field)
        local current = name == field.name and "this." .. name or field.name
        local t = parse_type(field.type)
        table.insert(params, (t.name == "dynamic" and "dynamic" or t.base .. "?") .. " " .. name)
        table.insert(args, ("%s: %s ?? %s"):format(name, name, current))
    end

    return ([[
%s copyWith({
  %s
}) {
  return %s(
    %s
  );
}]]):format(self_type(cls), block(params, 2), cls.name, block(args, 4))
end

function M.to_json(cls, opts)
    local type_params, entries = type_param_set(cls), {}
    for _, field in ipairs(cls.fields) do
        local value = encode(parse_type(field.type), field.name, type_params)
        if value then
            table.insert(entries, ("'%s': %s"):format(json_key(field, opts), value))
        end
    end

    if #entries == 0 then
        return "Map<String, dynamic> toJson() => {};"
    end
    return ([[
Map<String, dynamic> toJson() {
  return {
    %s
  };
}]]):format(block(entries, 4))
end

function M.from_json(cls, opts)
    local type_params, args = type_param_set(cls), {}
    for _, field in ipairs(cls.fields) do
        local value = decode(parse_type(field.type), ("json['%s']"):format(json_key(field, opts)), type_params)
        if value then
            table.insert(args, ("%s: %s"):format(param_name(field), value))
        end
    end

    if #args == 0 then
        return ("factory %s.fromJson(Map<String, dynamic> json) => %s();"):format(cls.name, cls.name)
    end
    return ([[
factory %s.fromJson(Map<String, dynamic> json) {
  return %s(
    %s
  );
}]]):format(cls.name, cls.name, block(args, 4))
end

-- Collections are compared by content: with flutter/foundation.dart in
-- Flutter projects (opts.flutter), package:collection otherwise.
local DEEP = "const DeepCollectionEquality()"
local flutter_equals = { List = "listEquals", Set = "setEquals", Map = "mapEquals" }

local function is_collection(t, opts)
    if opts.flutter then
        return flutter_equals[t.name] ~= nil
    end
    return is_list(t.name) or t.name == "Map"
end

--- The import `==` and `hashCode` need, if any.
function M.equality_import(cls, opts)
    for _, field in ipairs(cls.fields) do
        if is_collection(parse_type(field.type), opts) then
            return opts.flutter and "package:flutter/foundation.dart" or "package:collection/collection.dart"
        end
    end
end

function M.equals(cls, opts)
    if #cls.fields == 0 then
        return ("@override\nbool operator ==(Object other) => identical(this, other) || other is %s;"):format(
            self_type(cls))
    end

    local checks = { "other is " .. self_type(cls) }
    for _, field in ipairs(cls.fields) do
        local t, f = parse_type(field.type), field.name
        if not is_collection(t, opts) then
            table.insert(checks, ("other.%s == %s"):format(f, f))
        elseif opts.flutter then
            table.insert(checks, ("%s(other.%s, %s)"):format(flutter_equals[t.name], f, f))
        else
            table.insert(checks, ("%s.equals(other.%s, %s)"):format(DEEP, f, f))
        end
    end

    return ([[
@override
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  return %s;
}]]):format(table.concat(checks, " &&\n      "))
end

--- Hash of a field, matching how `==` compares it.
local function hash(field, opts)
    local t, f = parse_type(field.type), field.name
    if not is_collection(t, opts) then
        return f
    elseif not opts.flutter then
        return ("%s.hash(%s)"):format(DEEP, f)
    elseif t.name == "Map" then
        local entries = t.nullable and ("(%s?.entries ?? const [])"):format(f) or f .. ".entries"
        return ("Object.hashAllUnordered(%s.map((e) => Object.hash(e.key, e.value)))"):format(entries)
    end
    local value = t.nullable and f .. " ?? const []" or f
    return ("Object.%s(%s)"):format(t.name == "Set" and "hashAllUnordered" or "hashAll", value)
end

function M.hash_code(cls, opts)
    local hashes = {}
    for _, field in ipairs(cls.fields) do
        table.insert(hashes, hash(field, opts))
    end

    local value
    if #hashes == 0 then
        value = "runtimeType.hashCode"
    elseif #hashes == 1 then
        value = hashes[1] == cls.fields[1].name and hashes[1] .. ".hashCode" or hashes[1]
    elseif #hashes <= 20 then
        value = "Object.hash(" .. table.concat(hashes, ", ") .. ")"
    else
        -- Object.hash takes at most 20 values.
        value = "Object.hashAll([" .. table.concat(hashes, ", ") .. "])"
    end
    return "@override\nint get hashCode => " .. value .. ";"
end

return M
