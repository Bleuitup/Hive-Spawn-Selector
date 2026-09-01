-- Hive Spawn Selector
-- lua/HiveSpawnSelector/HiveSpawnSelector_Client.lua
--
-- Attaches the spawn-selection menu to the alien commander, and relays the commander's pick to
-- every alien team member as a chat-style message ("Your commander has selected X as your
-- spawn."). Adapted from NSL's NSLSystemMessage chat injection in lua/NSL/messages/client.lua,
-- without NSL's localization/message-id/league-name machinery - this mod only ships one message,
-- in English.

Script.Load("lua/HiveSpawnSelector/HiveSpawnSelector_Utility.lua")
Script.Load("lua/HiveSpawnSelector/HiveSpawnSelector_Shared.lua")

AddClientUIScriptForClass("AlienCommander", "HiveSpawnSelector/GUIHiveSpawnSelectorMenu")

-- The "[Hive Spawn Selector]" tag is magenta, unmistakable against the usual chat colors (this
-- used to be a dark, easy-to-miss blue-grey, 0.28, 0.36, 0.46).
local kAnnounceHeaderColor = Color(1, 0, 1, 1)

-- Vanilla's chat feed only supports two colors per line (header + one uniform color for the whole
-- body - see ns2/lua/GUIChat.lua's AddMessage, "numberElementsPerMessage = 8", messageColor is a
-- single SetColor() on the whole message text item). There is no inline color-code markup in
-- NS2's text rendering, so "only the hive/room names colored, rest white, all one line" is not
-- achievable through this mechanism - two lines, each entirely the relevant team's color, is the
-- deliberate compromise instead. kMarineFontColor/kAlienFontColor are vanilla's own globals
-- (ns2/lua/Globals.lua) - the exact colors the game already uses for marine/alien chat text and
-- player names, not our own approximation.
local kAlienLineColor = kAlienFontColor
local kMarineLineColor = kMarineFontColor

-- Queued messages get merged into vanilla's chat feed the next time it polls - see
-- ns2/lua/Chat.lua's ChatUI_GetMessages/chatMessages for the color/header/color/message/... shape
-- being matched here.
local queuedChatMessages = { }

local originalChatUIGetMessages = ChatUI_GetMessages
function ChatUI_GetMessages()
	local messages = originalChatUIGetMessages()
	if #queuedChatMessages > 0 then
		table.copy(queuedChatMessages, messages, true)
		queuedChatMessages = { }
	end
	return messages
end

local function QueueLine(bodyColor, text)
	table.insert(queuedChatMessages, kAnnounceHeaderColor)
	table.insert(queuedChatMessages, "[Hive Spawn Selector] ")
	table.insert(queuedChatMessages, bodyColor)
	table.insert(queuedChatMessages, text)
	table.insert(queuedChatMessages, false)
	table.insert(queuedChatMessages, false)
	table.insert(queuedChatMessages, 0)
	table.insert(queuedChatMessages, 0)
end

local function OnAnnounceMessage(message)

	local player = Client.GetLocalPlayer()
	if not player then
		return
	end

	local tp = Shared.GetEntity(message.techPointId)
	if tp and tp:isa("TechPoint") then
		QueueLine(kAlienLineColor, string.format("Your commander has selected %s as your spawn.", tp:GetLocationName()))
	else
		QueueLine(kAlienLineColor, "Your commander has selected a random spawn.")
	end

	-- Names every legal marine spawn for the pick, not just the one actually chosen - see
	-- AnnounceSelection in HiveSpawnSelector_Server.lua. Only sent as a second line when there's
	-- actually a marine spawn to report (a real pick, not the random/cleared case above).
	if message.marineSpawnNames and message.marineSpawnNames ~= "" then
		local marineNames = { }
		for marineName in string.gmatch(message.marineSpawnNames, "[^,]+") do
			table.insert(marineNames, marineName)
		end

		if #marineNames == 1 then
			QueueLine(kMarineLineColor, string.format("Marines will spawn in %s.", marineNames[1]))
		elseif #marineNames > 1 then
			QueueLine(kMarineLineColor, string.format("Marines will spawn in either %s.", table.concat(marineNames, ", ")))
		end
	end

	StartSoundEffect(player:GetChatSound())

end

Client.HookNetworkMessage("HiveSpawnSelector_Announce", OnAnnounceMessage)
