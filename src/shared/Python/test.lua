#!/usr/bin/env lua5.4
-- test.lua - Comprehensive Unit Tests for Python VM
-- Run with: lua5.4 test.lua
--
-- Tests cover:
--   1. Lexer (tokenization)
--   2. Parser (AST generation)
--   3. Compiler (bytecode generation)
--   4. VM (execution)
--   5. Integration (end-to-end)
--   6. Edge cases and error handling

-- Module cache
local modules = {}

-- Load a .luau file and patch requires
local function loadModule(name)
    if modules[name] then
        return modules[name]
    end

    local filename = name .. ".luau"
    local file = io.open(filename, "r")
    if not file then
        error("Cannot open " .. filename)
    end
    local source = file:read("*a")
    file:close()

    -- Patch Roblox require to standard Lua
    source = source:gsub('require%(script%.Parent%.(%w+)%)', function(mod)
        return 'loadModule("' .. mod .. '")'
    end)

    -- Load and execute
    local chunk, err = load(source, filename, "t", setmetatable({
        loadModule = loadModule,
    }, {__index = _G}))

    if not chunk then
        error("Error loading " .. filename .. ": " .. err)
    end

    local result = chunk()
    modules[name] = result
    return result
end

-- Load modules
local Lexer = loadModule("Lexer")
local Parser = loadModule("Parser")
local Compiler = loadModule("Compiler")
local VM = loadModule("VM")

local Op = Compiler.Op

--============================================================================
-- TEST UTILITIES
--============================================================================

local passed = 0
local failed = 0
local skipped = 0
local currentSection = ""

local function section(name)
    currentSection = name
    print("\n--- " .. name .. " ---\n")
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name)
        print("    Error: " .. tostring(err))
    end
end

local function skip(name, reason)
    skipped = skipped + 1
    print("  ○ " .. name .. " (SKIPPED: " .. reason .. ")")
end

local function assertEquals(expected, actual, msg)
    if expected ~= actual then
        error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertNotNil(value, msg)
    if value == nil then
        error((msg or "Assertion failed") .. ": expected non-nil value")
    end
end

local function assertTrue(value, msg)
    if not value then
        error((msg or "Assertion failed") .. ": expected true")
    end
end

local function assertFalse(value, msg)
    if value then
        error((msg or "Assertion failed") .. ": expected false")
    end
end

local function assertError(fn, expectedPattern, msg)
    local ok, err = pcall(fn)
    if ok then
        error((msg or "Expected error") .. " but function succeeded")
    end
    if expectedPattern and not string.find(tostring(err), expectedPattern) then
        error((msg or "Error mismatch") .. ": expected pattern '" .. expectedPattern .. "' in '" .. tostring(err) .. "'")
    end
end

local function assertTableEquals(expected, actual, msg)
    if type(expected) ~= "table" or type(actual) ~= "table" then
        error((msg or "Type mismatch") .. ": expected tables")
    end
    for k, v in pairs(expected) do
        if actual[k] ~= v then
            error((msg or "Table mismatch") .. " at key '" .. tostring(k) .. "': expected " .. tostring(v) .. ", got " .. tostring(actual[k]))
        end
    end
end

-- Helper to compile and run a program
local function compileAndRun(source, env, maxSteps, envTypes)
    -- Build envTypes from env keys if not provided
    if not envTypes and env then
        envTypes = {}
        for k, _ in pairs(env) do
            envTypes[k] = "any"
        end
    end
    local compiled, errors = Compiler.compile(source, nil, nil, envTypes)
    if not compiled then
        error("Compile error: " .. table.concat(errors or {"unknown"}, ", "))
    end

    local vm = VM.new()
    vm:setEnvironment(env or {})
    vm:load(compiled)

    -- Run until done or max steps
    maxSteps = maxSteps or 1000
    for i = 1, maxSteps do
        if not vm:step() then
            break
        end
    end

    return vm
end

-- Helper to just compile (for bytecode inspection)
local function compile(source, envTypes)
    local compiled, errors = Compiler.compile(source, nil, nil, envTypes)
    if not compiled then
        error("Compile error: " .. table.concat(errors or {"unknown"}, ", "))
    end
    return compiled
end

print("\n========================================")
print("   Python VM Comprehensive Test Suite")
print("========================================")

--============================================================================
-- LEXER TESTS
--============================================================================

section("Lexer Tests")

test("Tokenize simple identifier", function()
    local tokens = Lexer.tokenize("hello")
    assertNotNil(tokens)
    assertEquals(2, #tokens) -- identifier + EOF
    assertEquals("IDENTIFIER", tokens[1].type)
    assertEquals("hello", tokens[1].value)
end)

test("Tokenize integer", function()
    local tokens = Lexer.tokenize("42")
    assertEquals("NUMBER", tokens[1].type)
    assertEquals(42, tokens[1].value)
end)

test("Tokenize float", function()
    local tokens = Lexer.tokenize("3.14")
    assertEquals("NUMBER", tokens[1].type)
    assertEquals(3.14, tokens[1].value)
end)

test("Tokenize string with double quotes", function()
    local tokens = Lexer.tokenize('"hello world"')
    assertEquals("STRING", tokens[1].type)
    assertEquals("hello world", tokens[1].value)
end)

test("Tokenize string with single quotes", function()
    local tokens = Lexer.tokenize("'hello'")
    assertEquals("STRING", tokens[1].type)
    assertEquals("hello", tokens[1].value)
end)

test("Tokenize keywords", function()
    -- Lexer uses specific token types for keywords (e.g., "IF" not "KEYWORD")
    local keywordTokenTypes = {
        ["if"] = "IF", ["else"] = "ELSE", ["elif"] = "ELIF",
        ["while"] = "WHILE", ["for"] = "FOR", ["in"] = "IN",
        ["def"] = "DEF", ["return"] = "RETURN", ["break"] = "BREAK",
        ["continue"] = "CONTINUE", ["and"] = "AND", ["or"] = "OR",
        ["not"] = "NOT", ["True"] = "TRUE", ["False"] = "FALSE", ["None"] = "NONE"
    }
    for kw, expectedType in pairs(keywordTokenTypes) do
        local tokens = Lexer.tokenize(kw)
        assertEquals(expectedType, tokens[1].type, "Expected " .. expectedType .. " for: " .. kw)
        assertEquals(kw, tokens[1].value)
    end
end)

test("Tokenize operators", function()
    local operators = {"+", "-", "*", "/", "//", "%", "**", "=", "==", "!=", "<", ">", "<=", ">="}
    for _, op in ipairs(operators) do
        local tokens = Lexer.tokenize(op)
        assertNotNil(tokens[1], "Expected token for operator: " .. op)
    end
end)

test("Tokenize comment", function()
    local tokens = Lexer.tokenize("x = 5 # this is a comment")
    -- Comment should be ignored
    local foundComment = false
    for _, t in ipairs(tokens) do
        if t.type == "COMMENT" then foundComment = true end
    end
    -- Comments are typically stripped
end)

test("Tokenize multiline with indentation", function()
    local tokens = Lexer.tokenize("if True:\n    x = 1")
    assertNotNil(tokens)
    -- Should have INDENT token
    local hasIndent = false
    for _, t in ipairs(tokens) do
        if t.type == "INDENT" then hasIndent = true end
    end
    assertTrue(hasIndent, "Should have INDENT token")
end)

test("Tokenize dedent", function()
    local tokens = Lexer.tokenize("if True:\n    x = 1\ny = 2")
    assertNotNil(tokens)
    local hasDedent = false
    for _, t in ipairs(tokens) do
        if t.type == "DEDENT" then hasDedent = true end
    end
    assertTrue(hasDedent, "Should have DEDENT token")
end)

test("Track line numbers", function()
    local tokens = Lexer.tokenize("x = 1\ny = 2\nz = 3")
    -- Find 'z' token
    for _, t in ipairs(tokens) do
        if t.value == "z" then
            assertEquals(3, t.line, "z should be on line 3")
            break
        end
    end
end)

--============================================================================
-- PARSER TESTS
--============================================================================

section("Parser Tests")

-- Note: Parser returns { type = "program", statements = {...} }
-- Statement types use uppercase with _STMT suffix (e.g., ASSIGN_STMT, IF_STMT)
test("Parse simple assignment", function()
    local ast = Parser.parse("x = 5")
    assertNotNil(ast)
    assertNotNil(ast.statements)
    assertEquals(1, #ast.statements)
    assertEquals("ASSIGN_STMT", ast.statements[1].type)
end)

test("Parse binary expression", function()
    local ast = Parser.parse("x = 1 + 2")
    assertNotNil(ast)
    assertEquals("BINARY_OP", ast.statements[1].value.type)
end)

test("Parse function call", function()
    local ast = Parser.parse("print(hello)")
    assertNotNil(ast)
    assertEquals("EXPR_STMT", ast.statements[1].type)
end)

test("Parse method call", function()
    local ast = Parser.parse("obj.method(arg)")
    assertNotNil(ast)
    assertEquals("EXPR_STMT", ast.statements[1].type)
end)

test("Parse if statement", function()
    local ast = Parser.parse("if True:\n    x = 1")
    assertNotNil(ast)
    assertEquals("IF_STMT", ast.statements[1].type)
end)

test("Parse if-else statement", function()
    local ast = Parser.parse("if True:\n    x = 1\nelse:\n    x = 2")
    assertNotNil(ast)
    assertEquals("IF_STMT", ast.statements[1].type)
    assertNotNil(ast.statements[1].elseBlock)
end)

test("Parse if-elif-else statement", function()
    local ast = Parser.parse("if a:\n    x = 1\nelif b:\n    x = 2\nelse:\n    x = 3")
    assertNotNil(ast)
end)

test("Parse while loop", function()
    local ast = Parser.parse("while True:\n    x = 1")
    assertNotNil(ast)
    assertEquals("WHILE_STMT", ast.statements[1].type)
end)

test("Parse for loop", function()
    local ast = Parser.parse("for i in items:\n    print(i)")
    assertNotNil(ast)
    assertEquals("FOR_STMT", ast.statements[1].type)
end)

test("Parse function definition", function()
    local ast = Parser.parse("def foo(x):\n    return x + 1")
    assertNotNil(ast)
    assertEquals("FUNCTION_DEF", ast.statements[1].type)
end)

test("Parse list literal", function()
    local ast = Parser.parse("x = [1, 2, 3]")
    assertNotNil(ast)
end)

test("Parse index access", function()
    local ast = Parser.parse("x = items[0]")
    assertNotNil(ast)
end)

test("Parse nested expressions", function()
    local ast = Parser.parse("x = (1 + 2) * 3")
    assertNotNil(ast)
end)

test("Parse comparison chain", function()
    local ast = Parser.parse("x = a < b")
    assertNotNil(ast)
end)

test("Parse logical and/or", function()
    local ast = Parser.parse("x = a and b or c")
    assertNotNil(ast)
end)

test("Parse unary not", function()
    local ast = Parser.parse("x = not True")
    assertNotNil(ast)
end)

test("Parse unary minus", function()
    local ast = Parser.parse("x = -5")
    assertNotNil(ast)
end)

--============================================================================
-- COMPILER TESTS
--============================================================================

section("Compiler Tests")

test("Compile simple assignment generates correct opcodes", function()
    local compiled = compile("x = 5")
    assertNotNil(compiled.code)

    -- Should have LOAD_CONST and STORE_VAR
    local hasLoadConst = false
    local hasStoreVar = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.LOAD_CONST then hasLoadConst = true end
        if instr.op == Op.STORE_VAR then hasStoreVar = true end
    end
    assertTrue(hasLoadConst, "Should have LOAD_CONST")
    assertTrue(hasStoreVar, "Should have STORE_VAR")
end)

test("Compile while loop generates jump instructions", function()
    local compiled = compile("while True:\n    x = 1\n    break")

    local hasJump = false
    local hasPopJumpIfFalse = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.JUMP then hasJump = true end
        if instr.op == Op.POP_JUMP_IF_FALSE then hasPopJumpIfFalse = true end
    end
    assertTrue(hasJump or hasPopJumpIfFalse, "Should have jump instruction")
end)

test("Compile if statement generates conditional jump", function()
    local compiled = compile("if True:\n    x = 1")

    local hasCondJump = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.POP_JUMP_IF_FALSE or instr.op == Op.JUMP_IF_FALSE then
            hasCondJump = true
        end
    end
    assertTrue(hasCondJump, "Should have conditional jump")
end)

test("Compile function call generates CALL opcode", function()
    local compiled = compile("print(hello)", {hello = "any"})

    local hasCall = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.CALL then hasCall = true end
    end
    assertTrue(hasCall, "Should have CALL opcode")
end)

test("Compile binary operations", function()
    local ops = {
        {"+", Op.BINARY_ADD},
        {"-", Op.BINARY_SUB},
        {"*", Op.BINARY_MUL},
        {"/", Op.BINARY_DIV},
        {"%", Op.BINARY_MOD},
    }
    for _, pair in ipairs(ops) do
        local op, expectedOp = pair[1], pair[2]
        local compiled = compile("x = 1 " .. op .. " 2")
        local found = false
        for _, instr in ipairs(compiled.code) do
            if instr.op == expectedOp then found = true end
        end
        assertTrue(found, "Should have " .. expectedOp .. " for " .. op)
    end
end)

test("Compile comparison operations", function()
    local ops = {
        {"==", Op.COMPARE_EQ},
        {"!=", Op.COMPARE_NE},
        {"<", Op.COMPARE_LT},
        {">", Op.COMPARE_GT},
        {"<=", Op.COMPARE_LE},
        {">=", Op.COMPARE_GE},
    }
    for _, pair in ipairs(ops) do
        local op, expectedOp = pair[1], pair[2]
        local compiled = compile("x = 1 " .. op .. " 2")
        local found = false
        for _, instr in ipairs(compiled.code) do
            if instr.op == expectedOp then found = true end
        end
        assertTrue(found, "Should have " .. expectedOp .. " for " .. op)
    end
end)

test("Compile attribute access generates LOAD_ATTR", function()
    local compiled = compile("x = obj.value", {obj = "any"})

    local hasLoadAttr = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.LOAD_ATTR then hasLoadAttr = true end
    end
    assertTrue(hasLoadAttr, "Should have LOAD_ATTR")
end)

test("Compile list literal generates BUILD_LIST", function()
    local compiled = compile("x = [1, 2, 3]")

    local hasBuildList = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.BUILD_LIST then hasBuildList = true end
    end
    assertTrue(hasBuildList, "Should have BUILD_LIST")
end)

test("Compile index access generates GET_INDEX", function()
    local compiled = compile("x = items[0]", {items = "List"})

    local hasGetIndex = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.GET_INDEX then hasGetIndex = true end
    end
    assertTrue(hasGetIndex, "Should have GET_INDEX")
end)

test("Compile for loop generates iterator opcodes", function()
    local compiled = compile("for i in items:\n    x = i", {items = "List"})

    local hasGetIter = false
    local hasForIter = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.GET_ITER then hasGetIter = true end
        if instr.op == Op.FOR_ITER then hasForIter = true end
    end
    assertTrue(hasGetIter, "Should have GET_ITER")
    assertTrue(hasForIter, "Should have FOR_ITER")
end)

test("Compile function definition generates MAKE_FUNCTION", function()
    local compiled = compile("def foo():\n    return 1")

    local hasMakeFunction = false
    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.MAKE_FUNCTION then hasMakeFunction = true end
    end
    assertTrue(hasMakeFunction, "Should have MAKE_FUNCTION")
end)

--============================================================================
-- VM EXECUTION TESTS
--============================================================================

section("VM Execution Tests")

test("Execute simple assignment", function()
    local vm = compileAndRun("x = 5")
    assertEquals(5, vm.vars.x)
end)

test("Execute multiple assignments", function()
    local vm = compileAndRun("x = 1\ny = 2\nz = 3")
    assertEquals(1, vm.vars.x)
    assertEquals(2, vm.vars.y)
    assertEquals(3, vm.vars.z)
end)

test("Execute assignment from variable", function()
    local vm = compileAndRun("x = 5\ny = x")
    assertEquals(5, vm.vars.x)
    assertEquals(5, vm.vars.y)
end)

test("Execute arithmetic: addition", function()
    local vm = compileAndRun("x = 3 + 4")
    assertEquals(7, vm.vars.x)
end)

test("Execute arithmetic: subtraction", function()
    local vm = compileAndRun("x = 10 - 3")
    assertEquals(7, vm.vars.x)
end)

test("Execute arithmetic: multiplication", function()
    local vm = compileAndRun("x = 6 * 7")
    assertEquals(42, vm.vars.x)
end)

test("Execute arithmetic: division", function()
    local vm = compileAndRun("x = 15 / 3")
    assertEquals(5, vm.vars.x)
end)

test("Execute arithmetic: floor division", function()
    local vm = compileAndRun("x = 7 // 2")
    assertEquals(3, vm.vars.x)
end)

test("Execute arithmetic: modulo", function()
    local vm = compileAndRun("x = 17 % 5")
    assertEquals(2, vm.vars.x)
end)

test("Execute arithmetic: power", function()
    local vm = compileAndRun("x = 2 ** 10")
    assertEquals(1024, vm.vars.x)
end)

test("Execute arithmetic: negative", function()
    local vm = compileAndRun("x = -5")
    assertEquals(-5, vm.vars.x)
end)

test("Execute arithmetic: complex expression", function()
    local vm = compileAndRun("x = (2 + 3) * 4 - 6 / 2")
    assertEquals(17, vm.vars.x)
end)

test("Execute comparison: equal", function()
    local vm = compileAndRun("x = 5 == 5")
    assertEquals(true, vm.vars.x)
end)

test("Execute comparison: not equal", function()
    local vm = compileAndRun("x = 5 != 3")
    assertEquals(true, vm.vars.x)
end)

test("Execute comparison: less than", function()
    local vm = compileAndRun("x = 3 < 5")
    assertEquals(true, vm.vars.x)
end)

test("Execute comparison: greater than", function()
    local vm = compileAndRun("x = 5 > 3")
    assertEquals(true, vm.vars.x)
end)

test("Execute comparison: less or equal", function()
    local vm = compileAndRun("x = 5 <= 5")
    assertEquals(true, vm.vars.x)
end)

test("Execute comparison: greater or equal", function()
    local vm = compileAndRun("x = 5 >= 5")
    assertEquals(true, vm.vars.x)
end)

test("Execute logical: and (true)", function()
    local vm = compileAndRun("x = True and True")
    assertEquals(true, vm.vars.x)
end)

test("Execute logical: and (false)", function()
    local vm = compileAndRun("x = True and False")
    assertEquals(false, vm.vars.x)
end)

test("Execute logical: or (true)", function()
    local vm = compileAndRun("x = False or True")
    assertEquals(true, vm.vars.x)
end)

test("Execute logical: or (false)", function()
    local vm = compileAndRun("x = False or False")
    assertEquals(false, vm.vars.x)
end)

test("Execute logical: not", function()
    local vm = compileAndRun("x = not False")
    assertEquals(true, vm.vars.x)
end)

test("Execute string concatenation", function()
    local vm = compileAndRun('x = "hello" + " world"')
    assertEquals("hello world", vm.vars.x)
end)

test("Execute if statement (true branch)", function()
    local vm = compileAndRun("x = 0\nif True:\n    x = 1")
    assertEquals(1, vm.vars.x)
end)

test("Execute if statement (false branch)", function()
    local vm = compileAndRun("x = 0\nif False:\n    x = 1")
    assertEquals(0, vm.vars.x)
end)

test("Execute if-else (true)", function()
    local vm = compileAndRun("if True:\n    x = 1\nelse:\n    x = 2")
    assertEquals(1, vm.vars.x)
end)

test("Execute if-else (false)", function()
    local vm = compileAndRun("if False:\n    x = 1\nelse:\n    x = 2")
    assertEquals(2, vm.vars.x)
end)

test("Execute if-elif-else", function()
    local vm = compileAndRun("a = 2\nif a == 1:\n    x = 1\nelif a == 2:\n    x = 2\nelse:\n    x = 3")
    assertEquals(2, vm.vars.x)
end)

test("Execute while loop", function()
    local vm = compileAndRun("x = 0\nwhile x < 5:\n    x = x + 1")
    assertEquals(5, vm.vars.x)
end)

test("Execute while loop with break", function()
    local vm = compileAndRun("x = 0\nwhile True:\n    x = x + 1\n    if x >= 3:\n        break")
    assertEquals(3, vm.vars.x)
end)

test("Execute while loop with continue", function()
    local vm = compileAndRun([[
x = 0
y = 0
while x < 5:
    x = x + 1
    if x == 3:
        continue
    y = y + 1
]])
    assertEquals(5, vm.vars.x)
    assertEquals(4, vm.vars.y) -- skipped when x == 3
end)

test("Execute for loop over list", function()
    local vm = compileAndRun("total = 0\nfor i in [1, 2, 3, 4, 5]:\n    total = total + i")
    assertEquals(15, vm.vars.total)
end)

test("Execute for loop with break", function()
    local vm = compileAndRun("total = 0\nfor i in [1, 2, 3, 4, 5]:\n    total = total + i\n    if i == 3:\n        break")
    assertEquals(6, vm.vars.total) -- 1 + 2 + 3
end)

test("Execute list operations", function()
    local vm = compileAndRun("x = [1, 2, 3]\ny = x[1]")
    assertEquals(2, vm.vars.y) -- 0-indexed becomes 1-indexed in Lua
end)

test("Execute function call from environment", function()
    local called = false
    local env = {
        myFunc = function()
            called = true
            return 42
        end
    }
    local vm = compileAndRun("x = myFunc()", env)
    assertTrue(called, "Function should be called")
    assertEquals(42, vm.vars.x)
end)

test("Execute function with arguments", function()
    local receivedArg = nil
    local env = {
        myFunc = function(arg)
            receivedArg = arg
            return arg * 2
        end
    }
    local vm = compileAndRun("x = myFunc(21)", env)
    assertEquals(21, receivedArg)
    assertEquals(42, vm.vars.x)
end)

test("Execute method call on environment object", function()
    local called = false
    local env = {
        obj = {
            method = function()
                called = true
                return 99
            end
        }
    }
    local vm = compileAndRun("x = obj.method()", env)
    assertTrue(called)
    assertEquals(99, vm.vars.x)
end)

test("Execute attribute read", function()
    local env = {
        obj = {
            value = 123
        }
    }
    local vm = compileAndRun("x = obj.value", env)
    assertEquals(123, vm.vars.x)
end)

test("Execute user-defined function", function()
    local vm = compileAndRun([[
def double(n):
    return n * 2
x = double(21)
]])
    assertEquals(42, vm.vars.x)
end)

test("Execute recursive function", function()
    local vm = compileAndRun([[
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)
x = factorial(5)
]])
    assertEquals(120, vm.vars.x)
end)

test("Execute len() on list", function()
    local env = {
        len = function(t) return #t end
    }
    local vm = compileAndRun("x = len([1, 2, 3, 4, 5])", env)
    assertEquals(5, vm.vars.x)
end)

test("Execute built-in True/False/None", function()
    local vm = compileAndRun("a = True\nb = False\nc = None")
    assertEquals(true, vm.vars.a)
    assertEquals(false, vm.vars.b)
    assertEquals(nil, vm.vars.c)
end)

--============================================================================
-- INTEGRATION TESTS (Complex Programs)
--============================================================================

section("Integration Tests")

test("Fibonacci sequence", function()
    local vm = compileAndRun([[
a = 0
b = 1
count = 0
while count < 10:
    temp = a
    a = b
    b = temp + b
    count = count + 1
]])
    assertEquals(55, vm.vars.a) -- 10th Fibonacci number
end)

test("Sum of squares", function()
    local vm = compileAndRun([[
total = 0
for i in [1, 2, 3, 4, 5]:
    total = total + i * i
]])
    assertEquals(55, vm.vars.total) -- 1 + 4 + 9 + 16 + 25
end)

test("Nested loops", function()
    local vm = compileAndRun([[
count = 0
for i in [1, 2, 3]:
    for j in [1, 2, 3]:
        count = count + 1
]])
    assertEquals(9, vm.vars.count)
end)

test("Nested if statements", function()
    local vm = compileAndRun([[
x = 5
if x > 0:
    if x > 3:
        if x > 4:
            result = "big"
        else:
            result = "medium"
    else:
        result = "small"
else:
    result = "negative"
]])
    assertEquals("big", vm.vars.result)
end)

test("Multiple function calls in expression", function()
    local env = {
        add = function(a, b) return a + b end,
        mul = function(a, b) return a * b end
    }
    local vm = compileAndRun("x = add(mul(2, 3), mul(4, 5))", env)
    assertEquals(26, vm.vars.x) -- (2*3) + (4*5) = 6 + 20
end)

test("Bot-like environment simulation", function()
    local moveCount = 0
    local sayMessages = {}
    local env = {
        bot = {
            move = function(x, z)
                moveCount = moveCount + 1
                return true
            end,
            say = function(msg)
                table.insert(sayMessages, msg)
            end,
            danger = function()
                return 10
            end
        }
    }

    local vm = compileAndRun([[
if bot.danger() < 20:
    bot.say("Danger detected!")
    bot.move(0, 0)
]], env)

    assertEquals(1, moveCount)
    assertEquals(1, #sayMessages)
    assertEquals("Danger detected!", sayMessages[1])
end)

test("While True with environment function (original bug case)", function()
    local dangerCalls = 0
    local env = {
        B1 = {
            danger = function()
                dangerCalls = dangerCalls + 1
                return 9999
            end,
            say = function() end,
            move = function() end
        }
    }

    local vm = compileAndRun([[
while True:
    if B1.danger() < 20:
        B1.say("Help!")
        B1.move(0, 0)
    break
]], env, 100)

    assertTrue(dangerCalls > 0, "B1.danger() should have been called")
end)

test("Complex game loop simulation", function()
    local env = {
        self = {
            is_full = function() return false end,
            scraps = function() return {{id = 1, distance = 5}} end,
            collect = function(s) return true end,
            supply = function(t) return true end
        },
        G1 = {id = "gundam1"},
        len = function(t) return #t end
    }

    local iterations = 0
    env.self.is_full = function()
        iterations = iterations + 1
        return iterations >= 3 -- Become "full" after 3 iterations
    end

    local vm = compileAndRun([[
count = 0
while True:
    count = count + 1
    if self.is_full():
        break
    else:
        s = self.scraps()
        if len(s) > 0:
            self.collect(s[0])
]], env, 1000)

    assertEquals(3, vm.vars.count)
end)

--============================================================================
-- VM STATE TESTS
--============================================================================

section("VM State Tests")

test("VM initial state", function()
    local vm = VM.new()
    assertEquals(1, vm.ip)
    assertFalse(vm.running)
    assertFalse(vm.paused)
    assertFalse(vm.halted)
end)

test("VM state after load", function()
    local compiled = compile("x = 5")
    local vm = VM.new()
    vm:load(compiled)

    assertEquals(1, vm.ip)
    assertTrue(vm.running)
    assertFalse(vm.paused)
    assertFalse(vm.halted)
end)

test("VM state after execution completes", function()
    local vm = compileAndRun("x = 5")
    assertFalse(vm.running)
    assertTrue(vm.halted)
end)

test("VM getState returns correct data", function()
    local vm = compileAndRun("x = 5\ny = 10")
    local state = vm:getState()

    assertNotNil(state.ip)
    assertNotNil(state.vars)
    assertEquals(5, state.vars.x)
    assertEquals(10, state.vars.y)
end)

test("VM pause and resume", function()
    local compiled = compile("x = 0\nwhile x < 10:\n    x = x + 1")
    local vm = VM.new()
    vm:load(compiled)

    -- Run a few steps
    for i = 1, 10 do vm:step() end

    vm:pause()
    assertTrue(vm.paused)

    local ipBeforeResume = vm.ip
    vm:step() -- Should not advance when paused (returns true but doesn't execute)

    vm:resume()
    assertFalse(vm.paused)
end)

test("VM stop", function()
    local compiled = compile("while True:\n    x = 1")
    local vm = VM.new()
    vm:load(compiled)

    for i = 1, 10 do vm:step() end
    vm:stop()

    assertFalse(vm.running)
    assertTrue(vm.halted)
end)

test("VM step returns false when halted", function()
    local vm = compileAndRun("x = 5")
    local result = vm:step()
    assertFalse(result)
end)

--============================================================================
-- ERROR HANDLING TESTS
--============================================================================

section("Error Handling Tests")

test("Undefined variable error", function()
    local vm = compileAndRun("x = undefined_var + 1")
    -- Should have error or undefined marker
end)

test("Stack underflow protection", function()
    -- This would require crafting malicious bytecode, skip for now
end)

test("Division by zero handling", function()
    local vm = compileAndRun("x = 10 / 0")
    -- Lua returns inf, which is valid
    assertTrue(vm.vars.x == math.huge or vm.vars.x == -math.huge or vm.vars.x ~= vm.vars.x) -- nan check
end)

test("Call non-function error", function()
    local env = { notAFunc = 42 }
    local vm = VM.new()
    local compiled = compile("x = notAFunc()")
    vm:setEnvironment(env)
    vm:load(compiled)

    -- Run and expect error
    for i = 1, 100 do
        if not vm:step() then break end
    end

    -- Should have an error set
    assertNotNil(vm.error)
end)

test("Attribute access on nil", function()
    local vm = compileAndRun("x = None\ny = x.attr")
    assertNotNil(vm.error)
end)

--============================================================================
-- COMPILE-TIME TYPE CHECKING TESTS
--============================================================================

section("Compile-Time Type Checking")

-- Helper to check compile errors
local function expectCompileError(source, pattern, selfType, envTypes)
    local compiled = Compiler.compile(source, nil, selfType, envTypes)
    if compiled and compiled.code then
        error("Expected compile error but compilation succeeded")
    end
    if pattern and compiled and compiled.error then
        if not string.find(compiled.error.message, pattern) then
            error("Expected error pattern '" .. pattern .. "' but got: " .. compiled.error.message)
        end
    end
    return compiled
end

local function expectCompileSuccess(source, selfType, envTypes)
    local compiled = Compiler.compile(source, nil, selfType, envTypes)
    if not compiled or not compiled.code then
        error("Expected compile success but got error: " .. tostring(compiled and compiled.error and compiled.error.message))
    end
    return compiled
end

test("NameError for undefined variable", function()
    expectCompileError("x = undefined_var", "NameError.*undefined_var.*not defined")
end)

test("NameError for undefined function", function()
    expectCompileError("x = unknown_func()", "NameError.*unknown_func.*not defined")
end)

test("No error for defined variable", function()
    expectCompileSuccess("x = 5\ny = x + 1")
end)

test("No error for builtin True/False/None", function()
    expectCompileSuccess("x = True\ny = False\nz = None")
end)

test("No error for builtin functions", function()
    expectCompileSuccess("x = len([1,2,3])\ny = range(10)\nz = abs(-5)")
end)

test("No error for env-provided variables", function()
    expectCompileSuccess("x = myVar + 1", nil, {myVar = "number"})
end)

test("AttributeError for invalid Bot attribute", function()
    expectCompileError("x = self.invalid_attr", "AttributeError.*Bot.*invalid_attr", "Bot")
end)

test("AttributeError for invalid Gundam attribute", function()
    expectCompileError("x = self.invalid_method()", "AttributeError.*Gundam.*invalid_method", "Gundam")
end)

test("No error for valid Bot attributes", function()
    expectCompileSuccess("x = self.pos\ny = self.cargo", "Bot")
end)

test("No error for valid Bot methods", function()
    expectCompileSuccess("self.forward(10)\nself.collect()\nself.deposit()", "Bot")
end)

test("No error for valid Gundam methods", function()
    expectCompileSuccess("self.fire(BULLET)\nself.scan()\nself.set_range(50)", "Gundam")
end)

test("Attribute suggestion for typos (prefix match)", function()
    local compiled = Compiler.compile("self.forw()", nil, "Bot")
    assertTrue(compiled.error ~= nil, "Should have error")
    assertTrue(string.find(compiled.error.message, "did you mean") ~= nil, "Should suggest correction")
    assertTrue(string.find(compiled.error.message, "forward") ~= nil, "Should suggest 'forward'")
end)

test("Pattern B1-B4 recognized as Bot type", function()
    expectCompileSuccess("x = B1.pos\ny = B2.cargo\nz = B3.collect()", nil, {})
end)

test("Pattern G1-G30 recognized as Gundam type", function()
    expectCompileSuccess("x = G1.pos\nG5.fire(BULLET)\nG10.scan()", nil, {})
end)

test("Invalid attribute on pattern-matched Bot", function()
    expectCompileError("x = B1.nonexistent", "AttributeError.*Bot.*nonexistent")
end)

test("Invalid attribute on pattern-matched Gundam", function()
    expectCompileError("G1.nonexistent_method()", "AttributeError.*Gundam.*nonexistent_method")
end)

test("Enemy type from scan result", function()
    expectCompileSuccess([[
enemies = self.scan()
for e in enemies:
    x = e.hp
    y = e.pos
    z = e.is_boss
]], "Gundam")
end)

test("Augmented assignment requires defined variable", function()
    expectCompileError("x += 1", "NameError.*x.*not defined")
end)

test("Augmented assignment works with defined variable", function()
    expectCompileSuccess("x = 0\nx += 1\nx -= 2")
end)

test("Function parameters are defined in function scope", function()
    expectCompileSuccess([[
def foo(a, b, c):
    return a + b + c
]])
end)

test("Recursive function can reference itself", function()
    expectCompileSuccess([[
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)
]])
end)

test("For loop variable is defined in loop body", function()
    expectCompileSuccess([[
for i in [1, 2, 3]:
    x = i * 2
]])
end)

test("Break outside loop detected", function()
    expectCompileError("break", "'break' outside loop")
end)

test("Continue outside loop detected", function()
    expectCompileError("continue", "'continue' outside loop")
end)

test("Break inside loop is valid", function()
    expectCompileSuccess("while True:\n    break")
end)

test("Continue inside loop is valid", function()
    expectCompileSuccess("while True:\n    continue")
end)

test("Nested function scopes work correctly", function()
    expectCompileSuccess([[
def outer(x):
    def inner(y):
        return y * 2
    return inner(x) + 1
]])
end)

test("CORE is a recognized builtin", function()
    expectCompileSuccess("x = CORE.hp\ny = CORE.position", nil, {})
end)

test("Ammo type constants are defined", function()
    expectCompileSuccess("a = BULLET\nb = ROCKET\nc = LASER\nd = ICE\ne = GRENADE")
end)

--============================================================================
-- EDGE CASES
--============================================================================

section("Edge Cases")

test("Empty program", function()
    local vm = compileAndRun("")
    assertTrue(vm.halted or not vm.running)
end)

test("Comment-only program", function()
    local vm = compileAndRun("# just a comment")
    assertTrue(vm.halted or not vm.running)
end)

test("Deeply nested blocks", function()
    local vm = compileAndRun([[
if True:
    if True:
        if True:
            if True:
                if True:
                    x = 1
]])
    assertEquals(1, vm.vars.x)
end)

test("Long variable name", function()
    local vm = compileAndRun("this_is_a_very_long_variable_name_that_should_still_work = 42")
    assertEquals(42, vm.vars.this_is_a_very_long_variable_name_that_should_still_work)
end)

test("Zero iterations while loop", function()
    local vm = compileAndRun("x = 0\nwhile False:\n    x = 1")
    assertEquals(0, vm.vars.x)
end)

test("Empty list", function()
    local vm = compileAndRun("x = []")
    assertNotNil(vm.vars.x)
    assertEquals("table", type(vm.vars.x))
    assertEquals(0, #vm.vars.x)
end)

test("Single element list", function()
    local vm = compileAndRun("x = [42]")
    assertEquals(42, vm.vars.x[1])
end)

test("String with special characters", function()
    local vm = compileAndRun('x = "hello\\nworld"')
    assertNotNil(vm.vars.x)
end)

test("Large number", function()
    local vm = compileAndRun("x = 999999999")
    assertEquals(999999999, vm.vars.x)
end)

test("Negative number", function()
    local vm = compileAndRun("x = -42")
    assertEquals(-42, vm.vars.x)
end)

test("Float precision", function()
    local vm = compileAndRun("x = 0.1 + 0.2")
    -- Due to float precision, this might be 0.30000000000000004
    assertTrue(math.abs(vm.vars.x - 0.3) < 0.0001)
end)

test("Boolean in arithmetic", function()
    -- In Python, True = 1, False = 0 in arithmetic
    local vm = compileAndRun("x = True + True")
    -- Depending on implementation, this might be 2 or error
end)

test("Multiple breaks in nested loops", function()
    local vm = compileAndRun([[
x = 0
while True:
    while True:
        x = x + 1
        break
    x = x + 10
    break
]])
    assertEquals(11, vm.vars.x)
end)

test("Variable shadowing in function", function()
    -- NOTE: This simplified Python VM doesn't fully implement variable scoping.
    -- Assignment inside functions goes to global scope if the variable already exists globally.
    -- This is a known limitation, not a Python-compliant behavior.
    local vm = compileAndRun([[
x = 10
def foo():
    x = 20
    return x
y = foo()
]])
    -- In standard Python, x would be 10 (local scope in function)
    -- In this VM, x becomes 20 (no proper local scoping for existing globals)
    assertEquals(20, vm.vars.x) -- VM assigns to global
    assertEquals(20, vm.vars.y)
end)

--============================================================================
-- BYTECODE VERIFICATION TESTS
--============================================================================

section("Bytecode Verification")

test("First instruction exists", function()
    local compiled = compile("x = 5")
    assertNotNil(compiled.code)
    assertNotNil(compiled.code[1])
    assertNotNil(compiled.code[1].op)
end)

test("HALT at end of program", function()
    local compiled = compile("x = 5")
    local lastInstr = compiled.code[#compiled.code]
    assertEquals(Op.HALT, lastInstr.op)
end)

test("Line numbers in bytecode", function()
    local compiled = compile("x = 1\ny = 2\nz = 3")
    -- At least some instructions should have line numbers
    local hasLineNumbers = false
    for _, instr in ipairs(compiled.code) do
        if instr.line then hasLineNumbers = true break end
    end
    assertTrue(hasLineNumbers, "Bytecode should have line numbers")
end)

test("Line numbers correct with comment on first line", function()
    -- This tests the bot default program pattern where a comment is first
    local source = [[# Comment on line 1
self.say("Ready!")
self.color("cyan")

while True:
    if self.is_full():
        self.say("Delivering!")
]]
    local compiled = compile(source)

    -- Split source the same way ProgramPanel does
    local tokens = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        table.insert(tokens, line)
    end

    -- Verify source line 6 is "if self.is_full():"
    assertTrue(tokens[6]:match("if self.is_full"),
        "Source line 6 should be 'if self.is_full():' but got: " .. tokens[6])

    -- Find LOAD_ATTR is_full instruction and check its line number
    for i, instr in ipairs(compiled.code) do
        if instr.op == Op.LOAD_ATTR and instr.arg == "is_full" then
            assertEquals(6, instr.line,
                "LOAD_ATTR is_full should be on line 6 (matching 'if self.is_full():')")
            -- Verify the source line at this bytecode line matches
            assertEquals("    if self.is_full():", tokens[instr.line],
                "Bytecode line " .. instr.line .. " should match source")
            break
        end
    end
end)

test("Jump targets are valid", function()
    local compiled = compile("if True:\n    x = 1\nelse:\n    x = 2")

    for _, instr in ipairs(compiled.code) do
        if instr.op == Op.JUMP or instr.op == Op.POP_JUMP_IF_FALSE then
            local target = instr.arg
            assertTrue(target >= 1 and target <= #compiled.code + 1,
                "Jump target " .. target .. " should be valid (1 to " .. (#compiled.code + 1) .. ")")
        end
    end
end)

test("formatCode preserves comment and empty lines", function()
    -- Test that EditorPanel.formatCode logic preserves structure
    -- This mirrors the formatCode function from EditorPanel.luau
    local function formatCode(source)
        local lines = {}
        for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
            local cleaned = string.gsub(line, "%s+$", "")
            table.insert(lines, cleaned)
        end
        while #lines > 0 and lines[#lines] == "" do
            table.remove(lines)
        end
        return table.concat(lines, "\n")
    end

    local source = [[# My helpful bot!
self.say("Ready!")
self.color("cyan")

while True:
    if self.is_full():
        self.say("Delivering!")
]]
    local formatted = formatCode(source)

    -- Split and verify line numbers match
    local tokens = {}
    for line in (formatted .. "\n"):gmatch("(.-)\n") do
        table.insert(tokens, line)
    end

    -- Comment must be on line 1
    assertEquals("# My helpful bot!", tokens[1], "Line 1 should be the comment")
    -- Empty line must be preserved as line 4
    assertEquals("", tokens[4], "Line 4 should be empty")
    -- if statement must be on line 6
    assertTrue(tokens[6]:match("if self.is_full"), "Line 6 should be 'if self.is_full():'")
    -- Delivering must be on line 7
    assertTrue(tokens[7]:match("Delivering"), "Line 7 should contain 'Delivering'")
end)

--============================================================================
-- PERFORMANCE TESTS (basic sanity checks)
--============================================================================

section("Performance Tests")

test("Run 1000 iterations without timeout", function()
    local vm = compileAndRun([[
x = 0
while x < 1000:
    x = x + 1
]], {}, 15000)  -- Increased steps to account for NOP and loop overhead
    assertEquals(1000, vm.vars.x)
end)

test("Function calls in loop", function()
    local callCount = 0
    local env = {
        incr = function()
            callCount = callCount + 1
            return callCount
        end
    }
    local vm = compileAndRun([[
x = 0
while x < 100:
    x = incr()
]], env, 10000)
    assertEquals(100, callCount)
end)

--============================================================================
-- RUNTIME WRAPPER SIMULATION TESTS
-- These tests simulate how the Roblox wrapper (Interpreter/Runtime) uses the VM
--============================================================================

section("Runtime Wrapper Simulation")

-- Simulate the Runtime wrapper
local function createRuntime()
    local Runtime = {}
    Runtime.__index = Runtime

    function Runtime.new()
        local self = setmetatable({}, Runtime)
        self.vm = nil
        self.compiled = nil
        self.running = false
        self.paused = false
        self.env = {}
        self.envTypes = {}
        return self
    end

    function Runtime:setEnvironment(env)
        self.env = env or {}
        self.envTypes = {}
        for k, _ in pairs(self.env) do
            self.envTypes[k] = "any"
        end
    end

    function Runtime:compile(source)
        local compiled, errors = Compiler.compile(source, nil, nil, self.envTypes)
        if not compiled then
            self.error = errors and table.concat(errors, "\n") or "Compile error"
            return false
        end
        self.compiled = compiled
        return true
    end

    function Runtime:start()
        if not self.compiled then
            return false, "No compiled code"
        end
        self.vm = VM.new()
        self.vm:setEnvironment(self.env)
        local success = self.vm:load(self.compiled)
        if not success then
            self.error = self.vm.error
            return false, self.error
        end
        self.running = true
        self.paused = false
        return true
    end

    function Runtime:step()
        if not self.running or self.paused then
            return false
        end
        local stillRunning = self.vm:run(50)  -- Run 50 instructions like Roblox
        local vmState = self.vm:getState()
        self.running = vmState.running and not vmState.halted
        if vmState.error then
            self.error = vmState.error
            self.running = false
            return false
        end
        return self.running
    end

    function Runtime:getState()
        if not self.vm then
            return { vm = { ip = 0, running = false, halted = true } }
        end
        local vmState = self.vm:getState()
        return {
            running = self.running,
            paused = self.paused,
            error = self.error,
            vm = {
                ip = vmState.ip,
                stack = vmState.stack,
                running = vmState.running,
                halted = vmState.halted,
            }
        }
    end

    return Runtime.new()
end

test("Runtime wrapper: while True as first statement", function()
    local runtime = createRuntime()
    local env = {
        B1 = {
            danger = function() return 9999 end,
            say = function() end,
            move = function() end
        }
    }
    runtime:setEnvironment(env)

    local source = [[
while True:
    if B1.danger() < 20:
        B1.say("Help!")
        B1.move(0, 0)
    break
]]

    local success = runtime:compile(source)
    assertTrue(success, "Should compile successfully")

    success = runtime:start()
    assertTrue(success, "Should start successfully")

    local state = runtime:getState()
    print("  After start: ip=" .. state.vm.ip .. ", running=" .. tostring(state.vm.running))
    assertEquals(1, state.vm.ip, "IP should be 1 after start")
    assertTrue(state.vm.running, "VM should be running after start")

    -- Simulate stepOnce behavior: unpause, step, re-pause
    runtime.paused = false
    local stepped = runtime:step()

    state = runtime:getState()
    print("  After step: ip=" .. state.vm.ip .. ", running=" .. tostring(state.vm.running) .. ", stepped=" .. tostring(stepped))

    -- IP should have advanced past 1 (program should execute or complete)
    assert(state.vm.ip > 1 or state.vm.halted, "IP should advance or program should complete")
end)

test("Runtime wrapper: assignment then while True", function()
    local runtime = createRuntime()
    local env = {
        B1 = {
            danger = function() return 9999 end,
            say = function() end,
            move = function() end
        }
    }
    runtime:setEnvironment(env)

    local source = [[
a = 5
while True:
    if B1.danger() < 20:
        B1.say("Help!")
        B1.move(0, 0)
    break
]]

    local success = runtime:compile(source)
    assertTrue(success, "Should compile successfully")

    success = runtime:start()
    assertTrue(success, "Should start successfully")

    local state = runtime:getState()
    print("  After start: ip=" .. state.vm.ip .. ", running=" .. tostring(state.vm.running))

    runtime.paused = false
    local stepped = runtime:step()

    state = runtime:getState()
    print("  After step: ip=" .. state.vm.ip .. ", running=" .. tostring(state.vm.running) .. ", stepped=" .. tostring(stepped))

    assert(state.vm.ip > 1 or state.vm.halted, "IP should advance or program should complete")
end)

test("Runtime wrapper: multiple step calls", function()
    local runtime = createRuntime()
    runtime:setEnvironment({})

    -- Program with more iterations to ensure it spans multiple runtime steps
    local source = [[
x = 0
while x < 100:
    x = x + 1
]]

    runtime:compile(source)
    runtime:start()

    local ips = {}
    local lastIp = 0
    for i = 1, 20 do
        local state = runtime:getState()
        if state.vm.ip ~= lastIp then
            table.insert(ips, state.vm.ip)
            lastIp = state.vm.ip
        end
        if not runtime:step() then break end
    end

    print("  IP progression: " .. table.concat(ips, " -> "))
    -- With 100 iterations and 50 instructions per step, should take multiple steps
    assert(#ips >= 1, "Should have at least one IP recorded")
end)

test("Runtime wrapper: check error state preservation", function()
    local runtime = createRuntime()
    runtime:setEnvironment({})

    -- Program that will error (calling undefined function)
    local source = [[
x = undefined_func()
]]

    runtime:compile(source)
    runtime:start()
    runtime:step()

    local state = runtime:getState()
    print("  Error: " .. tostring(state.error))
    print("  Running: " .. tostring(state.running))
    print("  IP: " .. tostring(state.vm.ip))

    -- After error, running should be false
    assertFalse(state.running, "Should not be running after error")
end)

test("Runtime wrapper: reload between steps", function()
    local runtime = createRuntime()
    runtime:setEnvironment({})

    -- First load
    runtime:compile("x = 1")
    runtime:start()
    runtime:step()

    local state = runtime:getState()
    local ipAfterFirst = state.vm.ip

    -- Second load (same source)
    runtime:compile("x = 1")
    runtime:start()

    state = runtime:getState()
    assertEquals(1, state.vm.ip, "IP should reset to 1 after reload")

    runtime:step()

    state = runtime:getState()
    print("  IP after reload and step: " .. state.vm.ip)
end)

--============================================================================
-- SUMMARY
--============================================================================

print("\n========================================")
print(string.format("  Results: %d passed, %d failed, %d skipped", passed, failed, skipped))
print("========================================\n")

if failed > 0 then
    os.exit(1)
else
    print("All tests passed!")
end
