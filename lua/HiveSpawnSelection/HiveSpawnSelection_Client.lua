-- Hive Spawn Selection
-- lua/HiveSpawnSelection/HiveSpawnSelection_Client.lua
--
-- Attaches the spawn-selection menu to the alien commander, and relays the commander's pick to
-- every alien team member as a chat-style message ("Your commander has selected X as your
-- spawn."). Adapted from NSL's NSLSystemMessage chat injection in lua/NSL/messages/client.lua,
-- without NSL's localization/message-id/league-name machinery - this mod only ships one message,
-- in English.

Script.Load("lua/HiveSpawnSelection/HiveSpawnSelection_Utility.lua")
Script.Load("lua/HiveSpawnSelection/HiveSpawnSelection_Shared.lua")

AddClientUIScriptForClass("AlienCommander", "HiveSpawnSelection/GUIHiveSpawnSelectionMenu")

local kAnnounceHeaderColor = Color(0.28, 0.36, 0.46, 1)
local kAnnounceTextColor = Color(1, 1, 1, 1)

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

local function OnAnnounceMessage(message)

	local player = Client.GetLocalPlayer()
	if not player then
		return
	end

	local text
	local tp = Shared.GetEntity(message.techPointId)
	if tp and tp:isa("TechPoint") then
		text = string.format("Your commander has selected %s as your spawn.", tp:GetLocationName())
	else
		text = "Your commander has selected a random spawn."
	end

	table.insert(queuedChatMessages, kAnnounceHeaderColor)
	table.insert(queuedChatMessages, "(Hive Spawn Selection): ")
	table.insert(queuedChatMessages, kAnnounceTextColor)
	table.insert(queuedChatMessages, text)
	table.insert(queuedChatMessages, false)
	table.insert(queuedChatMessages, false)
	table.insert(queuedChatMessages, 0)
	table.insert(queuedChatMessages, 0)

	StartSoundEffect(player:GetChatSound())

end

Client.HookNetworkMessage("HiveSpawnSelection_Announce", OnAnnounceMessage)
