local ClientState = {}

ClientState.currentScrap = 0
ClientState.nextGundamCost = 100
ClientState.nextBotCost = 75

ClientState.currentGundamCount = 0
ClientState.currentBotCount = 0
ClientState.MAX_GUNDAMS = 10

ClientState.GUNDAM_BASE_COST = 100
ClientState.GUNDAM_COST_MULTIPLIER = 1.5
ClientState.BOT_BASE_COST = 75
ClientState.BOT_COST_MULTIPLIER = 1.3

function ClientState.calculateGundamCost()
	return math.floor(ClientState.GUNDAM_BASE_COST * (ClientState.GUNDAM_COST_MULTIPLIER ^ ClientState.currentGundamCount))
end

function ClientState.calculateBotCost()
	return math.floor(ClientState.BOT_BASE_COST * (ClientState.BOT_COST_MULTIPLIER ^ ClientState.currentBotCount))
end

ClientState.currentPhase = "LOBBY"

ClientState.gundamPlacementMode = false
ClientState.botPlacementMode = false
ClientState.isGundamPlacementValid = false
ClientState.isBotPlacementValid = false

return ClientState
