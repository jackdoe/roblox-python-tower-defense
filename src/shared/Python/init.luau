-- Python module
-- Exposes the Python bytecode compiler and VM

local Lexer = require(script.Lexer)
local Parser = require(script.Parser)
local Compiler = require(script.Compiler)
local VM = require(script.VM)
local Runtime = require(script.Runtime)
local GameAPI = require(script.GameAPI)
local Classes = require(script.Classes)

return {
	Lexer = Lexer,
	Parser = Parser,
	Compiler = Compiler,
	VM = VM,
	Runtime = Runtime,
	GameAPI = GameAPI,
	Classes = Classes,

	createRuntime = Runtime.new,
	tokenize = Lexer.tokenize,
	parse = Parser.parse,
	compile = Compiler.compile,
	Op = Compiler.Op,

	createGundamEnvironment = GameAPI.createGundamEnvironment,
	createBotEnvironment = GameAPI.createBotEnvironment,
	createPlayerEnvironment = GameAPI.createPlayerEnvironment,
}
