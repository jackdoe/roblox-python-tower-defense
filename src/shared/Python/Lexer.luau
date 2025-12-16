-- Lexer.luau
-- Python subset lexer with indentation handling
-- Converts source code into a stream of tokens

local Lexer = {}

-- Token types
Lexer.TokenType = {
	-- Literals
	NUMBER = "NUMBER",
	STRING = "STRING",
	IDENTIFIER = "IDENTIFIER",

	-- Keywords
	IF = "IF",
	ELIF = "ELIF",
	ELSE = "ELSE",
	WHILE = "WHILE",
	FOR = "FOR",
	IN = "IN",
	DEF = "DEF",
	RETURN = "RETURN",
	AND = "AND",
	OR = "OR",
	NOT = "NOT",
	TRUE = "TRUE",
	FALSE = "FALSE",
	NONE = "NONE",
	BREAK = "BREAK",
	CONTINUE = "CONTINUE",
	PASS = "PASS",

	-- Operators
	PLUS = "PLUS",           -- +
	MINUS = "MINUS",         -- -
	STAR = "STAR",           -- *
	SLASH = "SLASH",         -- /
	FLOOR_DIV = "FLOOR_DIV", -- //
	PERCENT = "PERCENT",     -- %
	POWER = "POWER",         -- **

	-- Comparison
	EQ = "EQ",               -- ==
	NE = "NE",               -- !=
	LT = "LT",               -- <
	GT = "GT",               -- >
	LE = "LE",               -- <=
	GE = "GE",               -- >=

	-- Assignment
	ASSIGN = "ASSIGN",       -- =
	PLUS_ASSIGN = "PLUS_ASSIGN",   -- +=
	MINUS_ASSIGN = "MINUS_ASSIGN", -- -=
	STAR_ASSIGN = "STAR_ASSIGN",   -- *=
	SLASH_ASSIGN = "SLASH_ASSIGN", -- /=

	-- Delimiters
	LPAREN = "LPAREN",       -- (
	RPAREN = "RPAREN",       -- )
	LBRACKET = "LBRACKET",   -- [
	RBRACKET = "RBRACKET",   -- ]
	COMMA = "COMMA",         -- ,
	COLON = "COLON",         -- :
	DOT = "DOT",             -- .

	-- Structure
	NEWLINE = "NEWLINE",
	INDENT = "INDENT",
	DEDENT = "DEDENT",
	EOF = "EOF",
}

local TT = Lexer.TokenType

-- Keywords mapping
local KEYWORDS = {
	["if"] = TT.IF,
	["elif"] = TT.ELIF,
	["else"] = TT.ELSE,
	["while"] = TT.WHILE,
	["for"] = TT.FOR,
	["in"] = TT.IN,
	["def"] = TT.DEF,
	["return"] = TT.RETURN,
	["and"] = TT.AND,
	["or"] = TT.OR,
	["not"] = TT.NOT,
	["True"] = TT.TRUE,
	["False"] = TT.FALSE,
	["None"] = TT.NONE,
	["break"] = TT.BREAK,
	["continue"] = TT.CONTINUE,
	["pass"] = TT.PASS,
}

-- Create a token
local function makeToken(type, value, line, column)
	return {
		type = type,
		value = value,
		line = line,
		column = column,
	}
end

-- Check if character is digit
local function isDigit(c)
	return c and c:match("%d") ~= nil
end

-- Check if character is alpha or underscore
local function isAlpha(c)
	return c and c:match("[%a_]") ~= nil
end

-- Check if character is alphanumeric or underscore
local function isAlphaNum(c)
	return c and c:match("[%w_]") ~= nil
end

-- Check if character is whitespace (not newline)
local function isSpace(c)
	return c == " " or c == "\t"
end

-- Main lexer function
function Lexer.tokenize(source)
	local tokens = {}
	local pos = 1
	local line = 1
	local column = 1
	local indentStack = {0} -- Stack of indentation levels
	local atLineStart = true

	local function peek(offset)
		offset = offset or 0
		local p = pos + offset
		if p > #source then return nil end
		return source:sub(p, p)
	end

	local function advance()
		local c = peek()
		pos = pos + 1
		if c == "\n" then
			line = line + 1
			column = 1
		else
			column = column + 1
		end
		return c
	end

	local function addToken(type, value)
		table.insert(tokens, makeToken(type, value, line, column))
	end

	local function skipComment()
		while peek() and peek() ~= "\n" do
			advance()
		end
	end

	local function readString(quote)
		local startLine = line
		local startCol = column
		local str = ""
		advance() -- consume opening quote

		while peek() and peek() ~= quote do
			local c = peek()
			if c == "\\" then
				advance()
				local escaped = advance()
				if escaped == "n" then
					str = str .. "\n"
				elseif escaped == "t" then
					str = str .. "\t"
				elseif escaped == "\\" then
					str = str .. "\\"
				elseif escaped == quote then
					str = str .. quote
				else
					str = str .. escaped
				end
			elseif c == "\n" then
				error("Unterminated string at line " .. startLine)
			else
				str = str .. advance()
			end
		end

		if not peek() then
			error("Unterminated string at line " .. startLine)
		end
		advance() -- consume closing quote

		table.insert(tokens, makeToken(TT.STRING, str, startLine, startCol))
	end

	local function readNumber()
		local startCol = column
		local num = ""
		local hasDecimal = false

		while isDigit(peek()) or (peek() == "." and not hasDecimal and isDigit(peek(1))) do
			if peek() == "." then
				hasDecimal = true
			end
			num = num .. advance()
		end

		table.insert(tokens, makeToken(TT.NUMBER, tonumber(num), line, startCol))
	end

	local function readIdentifier()
		local startCol = column
		local ident = ""

		while isAlphaNum(peek()) do
			ident = ident .. advance()
		end

		local keyword = KEYWORDS[ident]
		if keyword then
			table.insert(tokens, makeToken(keyword, ident, line, startCol))
		else
			table.insert(tokens, makeToken(TT.IDENTIFIER, ident, line, startCol))
		end
	end

	local function handleIndentation()
		local indent = 0
		while isSpace(peek()) do
			if peek() == "\t" then
				indent = indent + 4 -- Treat tab as 4 spaces
			else
				indent = indent + 1
			end
			advance()
		end

		-- Skip blank lines and comment-only lines
		if peek() == "\n" or peek() == "#" or peek() == nil then
			return
		end

		local currentIndent = indentStack[#indentStack]

		if indent > currentIndent then
			table.insert(indentStack, indent)
			addToken(TT.INDENT, indent)
		elseif indent < currentIndent then
			while #indentStack > 1 and indentStack[#indentStack] > indent do
				table.remove(indentStack)
				addToken(TT.DEDENT, indent)
			end
			if indentStack[#indentStack] ~= indent then
				error("Inconsistent indentation at line " .. line)
			end
		end
	end

	-- Main tokenization loop
	while pos <= #source do
		local c = peek()

		-- Handle start of line (indentation)
		if atLineStart then
			atLineStart = false
			handleIndentation()
			c = peek()
			if not c then break end
		end

		-- Skip spaces (not at line start)
		if isSpace(c) then
			advance()

		-- Newline
		elseif c == "\n" then
			-- Only emit NEWLINE if we have meaningful tokens
			if #tokens > 0 and tokens[#tokens].type ~= TT.NEWLINE
				and tokens[#tokens].type ~= TT.INDENT then
				addToken(TT.NEWLINE, nil)
			end
			advance()
			atLineStart = true

		-- Comment
		elseif c == "#" then
			skipComment()

		-- String
		elseif c == '"' or c == "'" then
			readString(c)

		-- Number
		elseif isDigit(c) then
			readNumber()

		-- Identifier or keyword
		elseif isAlpha(c) then
			readIdentifier()

		-- Two-character operators
		elseif c == "=" then
			advance()
			if peek() == "=" then
				advance()
				addToken(TT.EQ, "==")
			else
				addToken(TT.ASSIGN, "=")
			end

		elseif c == "!" then
			advance()
			if peek() == "=" then
				advance()
				addToken(TT.NE, "!=")
			else
				error("Unexpected character '!' at line " .. line .. " (did you mean '!='?)")
			end

		elseif c == "<" then
			advance()
			if peek() == "=" then
				advance()
				addToken(TT.LE, "<=")
			else
				addToken(TT.LT, "<")
			end

		elseif c == ">" then
			advance()
			if peek() == "=" then
				advance()
				addToken(TT.GE, ">=")
			else
				addToken(TT.GT, ">")
			end

		elseif c == "+" then
			advance()
			if peek() == "=" then
				advance()
				addToken(TT.PLUS_ASSIGN, "+=")
			else
				addToken(TT.PLUS, "+")
			end

		elseif c == "-" then
			advance()
			if peek() == "=" then
				advance()
				addToken(TT.MINUS_ASSIGN, "-=")
			else
				addToken(TT.MINUS, "-")
			end

		elseif c == "*" then
			advance()
			if peek() == "*" then
				advance()
				addToken(TT.POWER, "**")
			elseif peek() == "=" then
				advance()
				addToken(TT.STAR_ASSIGN, "*=")
			else
				addToken(TT.STAR, "*")
			end

		elseif c == "/" then
			advance()
			if peek() == "/" then
				advance()
				addToken(TT.FLOOR_DIV, "//")
			elseif peek() == "=" then
				advance()
				addToken(TT.SLASH_ASSIGN, "/=")
			else
				addToken(TT.SLASH, "/")
			end

		elseif c == "%" then
			advance()
			addToken(TT.PERCENT, "%")

		-- Single character tokens
		elseif c == "(" then
			advance()
			addToken(TT.LPAREN, "(")

		elseif c == ")" then
			advance()
			addToken(TT.RPAREN, ")")

		elseif c == "[" then
			advance()
			addToken(TT.LBRACKET, "[")

		elseif c == "]" then
			advance()
			addToken(TT.RBRACKET, "]")

		elseif c == "," then
			advance()
			addToken(TT.COMMA, ",")

		elseif c == ":" then
			advance()
			addToken(TT.COLON, ":")

		elseif c == "." then
			advance()
			addToken(TT.DOT, ".")

		else
			error("Unexpected character '" .. c .. "' at line " .. line .. ", column " .. column)
		end
	end

	-- Emit remaining DEDENTs at end of file
	while #indentStack > 1 do
		table.remove(indentStack)
		addToken(TT.DEDENT, 0)
	end

	-- Add EOF token
	addToken(TT.EOF, nil)

	return tokens
end

-- Utility: format tokens for debugging
function Lexer.formatTokens(tokens)
	local lines = {}
	for _, token in ipairs(tokens) do
		local valueStr = token.value ~= nil and tostring(token.value) or ""
		table.insert(lines, string.format("[%s] %s (L%d:C%d)",
			token.type, valueStr, token.line, token.column))
	end
	return table.concat(lines, "\n")
end

return Lexer
