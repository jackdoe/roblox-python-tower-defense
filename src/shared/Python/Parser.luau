-- Parser.luau
-- Recursive descent parser for Python subset
-- Produces an Abstract Syntax Tree (AST)

local Lexer = require(script.Parent.Lexer)
local TT = Lexer.TokenType

local Parser = {}

-- AST Node types
Parser.NodeType = {
	-- Statements
	PROGRAM = "PROGRAM",
	FUNCTION_DEF = "FUNCTION_DEF",
	IF_STMT = "IF_STMT",
	WHILE_STMT = "WHILE_STMT",
	FOR_STMT = "FOR_STMT",
	RETURN_STMT = "RETURN_STMT",
	BREAK_STMT = "BREAK_STMT",
	CONTINUE_STMT = "CONTINUE_STMT",
	PASS_STMT = "PASS_STMT",
	EXPR_STMT = "EXPR_STMT",
	ASSIGN_STMT = "ASSIGN_STMT",
	AUG_ASSIGN_STMT = "AUG_ASSIGN_STMT",
	TUPLE_UNPACK_STMT = "TUPLE_UNPACK_STMT",  -- a, b = expr

	-- Expressions
	BINARY_OP = "BINARY_OP",
	UNARY_OP = "UNARY_OP",
	CALL = "CALL",
	INDEX = "INDEX",
	ATTRIBUTE = "ATTRIBUTE",
	IDENTIFIER = "IDENTIFIER",
	NUMBER = "NUMBER",
	STRING = "STRING",
	BOOLEAN = "BOOLEAN",
	NONE = "NONE",
	LIST = "LIST",
	TUPLE = "TUPLE",  -- (a, b) or a, b
}

local NT = Parser.NodeType

-- Create parser state
local function createParser(tokens)
	return {
		tokens = tokens,
		pos = 1,
	}
end

-- Parser helper functions
local function peek(p, offset)
	offset = offset or 0
	local idx = p.pos + offset
	if idx > #p.tokens then
		return p.tokens[#p.tokens] -- Return EOF
	end
	return p.tokens[idx]
end

local function current(p)
	return peek(p, 0)
end

local function check(p, type)
	return current(p).type == type
end

local function advance(p)
	local token = current(p)
	if token.type ~= TT.EOF then
		p.pos = p.pos + 1
	end
	return token
end

local function consume(p, type, message)
	if check(p, type) then
		return advance(p)
	end
	local tok = current(p)
	error(message .. " at line " .. tok.line .. ", got " .. tok.type)
end

local function match(p, ...)
	for _, type in ipairs({...}) do
		if check(p, type) then
			advance(p)
			return true
		end
	end
	return false
end

local function skipNewlines(p)
	while check(p, TT.NEWLINE) do
		advance(p)
	end
end

-- Forward declarations for recursive parsing
local parseExpression
local parseStatement
local parseBlock

-- Parse primary expression (literals, identifiers, parenthesized expressions)
local function parsePrimary(p)
	local tok = current(p)

	if check(p, TT.NUMBER) then
		advance(p)
		return { type = NT.NUMBER, value = tok.value, line = tok.line }
	end

	if check(p, TT.STRING) then
		advance(p)
		return { type = NT.STRING, value = tok.value, line = tok.line }
	end

	if check(p, TT.TRUE) then
		advance(p)
		return { type = NT.BOOLEAN, value = true, line = tok.line }
	end

	if check(p, TT.FALSE) then
		advance(p)
		return { type = NT.BOOLEAN, value = false, line = tok.line }
	end

	if check(p, TT.NONE) then
		advance(p)
		return { type = NT.NONE, line = tok.line }
	end

	if check(p, TT.IDENTIFIER) then
		advance(p)
		return { type = NT.IDENTIFIER, name = tok.value, line = tok.line }
	end

	if check(p, TT.LPAREN) then
		advance(p)
		local expr = parseExpression(p)
		consume(p, TT.RPAREN, "Expected ')' after expression")
		return expr
	end

	if check(p, TT.LBRACKET) then
		advance(p)
		local elements = {}
		if not check(p, TT.RBRACKET) then
			table.insert(elements, parseExpression(p))
			while match(p, TT.COMMA) do
				if check(p, TT.RBRACKET) then break end -- Trailing comma
				table.insert(elements, parseExpression(p))
			end
		end
		consume(p, TT.RBRACKET, "Expected ']' after list")
		return { type = NT.LIST, elements = elements, line = tok.line }
	end

	error("Expected expression at line " .. tok.line .. ", got " .. tok.type)
end

-- Parse call/index/attribute (postfix operations)
local function parsePostfix(p)
	local expr = parsePrimary(p)

	while true do
		if check(p, TT.LPAREN) then
			-- Function call
			advance(p)
			local args = {}
			if not check(p, TT.RPAREN) then
				table.insert(args, parseExpression(p))
				while match(p, TT.COMMA) do
					table.insert(args, parseExpression(p))
				end
			end
			consume(p, TT.RPAREN, "Expected ')' after arguments")
			expr = { type = NT.CALL, callee = expr, args = args, line = expr.line }

		elseif check(p, TT.LBRACKET) then
			-- Index
			advance(p)
			local index = parseExpression(p)
			consume(p, TT.RBRACKET, "Expected ']' after index")
			expr = { type = NT.INDEX, object = expr, index = index, line = expr.line }

		elseif check(p, TT.DOT) then
			-- Attribute access
			advance(p)
			local name = consume(p, TT.IDENTIFIER, "Expected attribute name after '.'")
			expr = { type = NT.ATTRIBUTE, object = expr, attribute = name.value, line = expr.line }

		else
			break
		end
	end

	return expr
end

-- Parse unary operators (not, -)
local function parseUnary(p)
	if check(p, TT.NOT) or check(p, TT.MINUS) then
		local op = advance(p)
		local right = parseUnary(p)
		return { type = NT.UNARY_OP, operator = op.type, operand = right, line = op.line }
	end
	return parsePostfix(p)
end

-- Parse power (right-associative)
local function parsePower(p)
	local left = parseUnary(p)
	if check(p, TT.POWER) then
		local op = advance(p)
		local right = parsePower(p) -- Right associative
		return { type = NT.BINARY_OP, operator = op.type, left = left, right = right, line = op.line }
	end
	return left
end

-- Parse multiplication/division
local function parseTerm(p)
	local left = parsePower(p)
	while check(p, TT.STAR) or check(p, TT.SLASH) or check(p, TT.FLOOR_DIV) or check(p, TT.PERCENT) do
		local op = advance(p)
		local right = parsePower(p)
		left = { type = NT.BINARY_OP, operator = op.type, left = left, right = right, line = op.line }
	end
	return left
end

-- Parse addition/subtraction
local function parseArith(p)
	local left = parseTerm(p)
	while check(p, TT.PLUS) or check(p, TT.MINUS) do
		local op = advance(p)
		local right = parseTerm(p)
		left = { type = NT.BINARY_OP, operator = op.type, left = left, right = right, line = op.line }
	end
	return left
end

-- Parse comparison
local function parseComparison(p)
	local left = parseArith(p)
	while check(p, TT.LT) or check(p, TT.GT) or check(p, TT.LE) or check(p, TT.GE) or check(p, TT.EQ) or check(p, TT.NE) do
		local op = advance(p)
		local right = parseArith(p)
		left = { type = NT.BINARY_OP, operator = op.type, left = left, right = right, line = op.line }
	end
	return left
end

-- Parse 'not' as a unary (already handled above, but we need this for boolean context)
local function parseNotExpr(p)
	return parseComparison(p)
end

-- Parse 'and'
local function parseAnd(p)
	local left = parseNotExpr(p)
	while check(p, TT.AND) do
		local op = advance(p)
		local right = parseNotExpr(p)
		left = { type = NT.BINARY_OP, operator = op.type, left = left, right = right, line = op.line }
	end
	return left
end

-- Parse 'or'
local function parseOr(p)
	local left = parseAnd(p)
	while check(p, TT.OR) do
		local op = advance(p)
		local right = parseAnd(p)
		left = { type = NT.BINARY_OP, operator = op.type, left = left, right = right, line = op.line }
	end
	return left
end

-- Main expression parser
parseExpression = function(p)
	return parseOr(p)
end

-- Parse block (indented statements)
parseBlock = function(p)
	consume(p, TT.COLON, "Expected ':' before block")
	skipNewlines(p)
	consume(p, TT.INDENT, "Expected indented block")

	local statements = {}
	while not check(p, TT.DEDENT) and not check(p, TT.EOF) do
		skipNewlines(p)
		if check(p, TT.DEDENT) or check(p, TT.EOF) then break end
		table.insert(statements, parseStatement(p))
	end

	if check(p, TT.DEDENT) then
		advance(p)
	end

	return statements
end

-- Parse if statement
local function parseIfStatement(p)
	local tok = advance(p) -- consume 'if'
	local condition = parseExpression(p)
	local thenBlock = parseBlock(p)

	local elseIfClauses = {}
	local elseBlock = nil

	skipNewlines(p)

	-- Handle elif clauses
	while check(p, TT.ELIF) do
		advance(p) -- consume 'elif'
		local elifCondition = parseExpression(p)
		local elifBlock = parseBlock(p)
		table.insert(elseIfClauses, { condition = elifCondition, body = elifBlock })
		skipNewlines(p)
	end

	-- Handle else clause
	if check(p, TT.ELSE) then
		advance(p) -- consume 'else'
		elseBlock = parseBlock(p)
	end

	return {
		type = NT.IF_STMT,
		condition = condition,
		thenBlock = thenBlock,
		elseIfClauses = elseIfClauses,
		elseBlock = elseBlock,
		line = tok.line,
	}
end

-- Parse while statement
local function parseWhileStatement(p)
	local tok = advance(p) -- consume 'while'
	local condition = parseExpression(p)
	local body = parseBlock(p)

	return {
		type = NT.WHILE_STMT,
		condition = condition,
		body = body,
		line = tok.line,
	}
end

-- Parse for statement (limited: for i in range(n))
local function parseForStatement(p)
	local tok = advance(p) -- consume 'for'
	local varName = consume(p, TT.IDENTIFIER, "Expected variable name in for loop")
	consume(p, TT.IN, "Expected 'in' in for loop")

	local iterable = parseExpression(p)
	local body = parseBlock(p)

	return {
		type = NT.FOR_STMT,
		variable = varName.value,
		iterable = iterable,
		body = body,
		line = tok.line,
	}
end

-- Parse function definition
local function parseFunctionDef(p)
	local tok = advance(p) -- consume 'def'
	local name = consume(p, TT.IDENTIFIER, "Expected function name")
	consume(p, TT.LPAREN, "Expected '(' after function name")

	local params = {}
	if not check(p, TT.RPAREN) then
		table.insert(params, consume(p, TT.IDENTIFIER, "Expected parameter name").value)
		while match(p, TT.COMMA) do
			table.insert(params, consume(p, TT.IDENTIFIER, "Expected parameter name").value)
		end
	end
	consume(p, TT.RPAREN, "Expected ')' after parameters")

	local body = parseBlock(p)

	return {
		type = NT.FUNCTION_DEF,
		name = name.value,
		params = params,
		body = body,
		line = tok.line,
	}
end

-- Parse return statement
local function parseReturnStatement(p)
	local tok = advance(p) -- consume 'return'
	local value = nil

	if not check(p, TT.NEWLINE) and not check(p, TT.EOF) and not check(p, TT.DEDENT) then
		value = parseExpression(p)
	end

	return {
		type = NT.RETURN_STMT,
		value = value,
		line = tok.line,
	}
end

-- Parse statement
parseStatement = function(p)
	skipNewlines(p)

	if check(p, TT.IF) then
		return parseIfStatement(p)
	end

	if check(p, TT.WHILE) then
		return parseWhileStatement(p)
	end

	if check(p, TT.FOR) then
		return parseForStatement(p)
	end

	if check(p, TT.DEF) then
		return parseFunctionDef(p)
	end

	if check(p, TT.RETURN) then
		local stmt = parseReturnStatement(p)
		match(p, TT.NEWLINE)
		return stmt
	end

	if check(p, TT.BREAK) then
		local tok = advance(p)
		match(p, TT.NEWLINE)
		return { type = NT.BREAK_STMT, line = tok.line }
	end

	if check(p, TT.CONTINUE) then
		local tok = advance(p)
		match(p, TT.NEWLINE)
		return { type = NT.CONTINUE_STMT, line = tok.line }
	end

	if check(p, TT.PASS) then
		local tok = advance(p)
		match(p, TT.NEWLINE)
		return { type = NT.PASS_STMT, line = tok.line }
	end

	-- Expression statement or assignment
	local expr = parseExpression(p)

	local function requireEndOfStatement(p, line)
		if not check(p, TT.NEWLINE) and not check(p, TT.EOF) and not check(p, TT.DEDENT) then
			local tok = current(p)
			error("Unexpected token '" .. tostring(tok.value or tok.type) .. "' at line " .. line)
		end
		match(p, TT.NEWLINE)
	end

	if check(p, TT.COMMA) then
		local targets = { expr }
		while check(p, TT.COMMA) do
			advance(p)
			local nextExpr = parseExpression(p)
			table.insert(targets, nextExpr)
		end

		if check(p, TT.ASSIGN) then
			advance(p)
			local value = parseExpression(p)
			requireEndOfStatement(p, expr.line)
			return { type = NT.TUPLE_UNPACK_STMT, targets = targets, value = value, line = expr.line }
		else
			requireEndOfStatement(p, expr.line)
			return { type = NT.EXPR_STMT, expression = { type = NT.TUPLE, elements = targets, line = expr.line }, line = expr.line }
		end
	end

	if check(p, TT.ASSIGN) then
		advance(p)
		local value = parseExpression(p)
		requireEndOfStatement(p, expr.line)
		return { type = NT.ASSIGN_STMT, target = expr, value = value, line = expr.line }
	end

	if check(p, TT.PLUS_ASSIGN) or check(p, TT.MINUS_ASSIGN) or
	   check(p, TT.STAR_ASSIGN) or check(p, TT.SLASH_ASSIGN) then
		local op = advance(p)
		local value = parseExpression(p)
		requireEndOfStatement(p, expr.line)
		return { type = NT.AUG_ASSIGN_STMT, target = expr, operator = op.type, value = value, line = expr.line }
	end

	requireEndOfStatement(p, expr.line)
	return { type = NT.EXPR_STMT, expression = expr, line = expr.line }
end

-- Parse program (multiple statements)
local function parseProgram(p)
	local statements = {}

	skipNewlines(p)
	while not check(p, TT.EOF) do
		table.insert(statements, parseStatement(p))
		skipNewlines(p)
	end

	return {
		type = NT.PROGRAM,
		statements = statements,
	}
end

-- Main parse function
function Parser.parse(source)
	local tokens = Lexer.tokenize(source)
	local p = createParser(tokens)
	return parseProgram(p)
end

-- Parse from tokens (if already tokenized)
function Parser.parseTokens(tokens)
	local p = createParser(tokens)
	return parseProgram(p)
end

-- Debug: format AST as string
function Parser.formatAST(node, indent)
	indent = indent or 0
	local pad = string.rep("  ", indent)

	if type(node) ~= "table" then
		return pad .. tostring(node)
	end

	if node.type == NT.NUMBER then
		return pad .. "Number(" .. node.value .. ")"
	elseif node.type == NT.STRING then
		return pad .. "String(\"" .. node.value .. "\")"
	elseif node.type == NT.BOOLEAN then
		return pad .. "Boolean(" .. tostring(node.value) .. ")"
	elseif node.type == NT.NONE then
		return pad .. "None"
	elseif node.type == NT.IDENTIFIER then
		return pad .. "Identifier(" .. node.name .. ")"
	elseif node.type == NT.BINARY_OP then
		local lines = {pad .. "BinaryOp(" .. node.operator .. ")"}
		table.insert(lines, Parser.formatAST(node.left, indent + 1))
		table.insert(lines, Parser.formatAST(node.right, indent + 1))
		return table.concat(lines, "\n")
	elseif node.type == NT.CALL then
		local lines = {pad .. "Call"}
		table.insert(lines, Parser.formatAST(node.callee, indent + 1))
		for _, arg in ipairs(node.args) do
			table.insert(lines, Parser.formatAST(arg, indent + 1))
		end
		return table.concat(lines, "\n")
	elseif node.type == NT.PROGRAM then
		local lines = {pad .. "Program"}
		for _, stmt in ipairs(node.statements) do
			table.insert(lines, Parser.formatAST(stmt, indent + 1))
		end
		return table.concat(lines, "\n")
	else
		return pad .. "Node(" .. (node.type or "?") .. ")"
	end
end

return Parser
