-- Hive Spawn Selector
-- lua/HiveSpawnSelector/GUIHiveSpawnSelectorMenu.lua
--
-- Alien commander UI for choosing the team's starting location.
-- Adapted from the NSL plugin:
-- https://github.com/xToken/NSL - lua/NSL/GUI/GUINSLSpawnSelectionMenu.lua - by Dragon

class 'GUIHiveSpawnSelectorMenu' (GUIScript)

local kBackgroundColor = Color(0.0, 0.0, 0.0, 0.7)
local kTitleColor = Color(0.08, 0.16, 0.26, 1)
local kTitleTextColor = Color(0.28, 0.36, 0.46, 1)
local kOptionColor = Color(0.7, 0.7, 0.7, 1)
local kOptionSelectedColor = Color(1, 1, 1, 1)
local kOptionChosenColor = Color(0, 1, 0, 1)

local kOptionOffset = Vector(0, 15, 0)
local kTitleTextOffset = Vector(0, 8, 0)
local kSpawnBackgroundSize = Vector(200, 175, 0)
local kTitleBackgroundSize = Vector(198, 20, 0)

local kSelectionDelay = 1

-- The panel draws a fixed number of location slots followed by a trailing "Random Spawn" entry.
-- No stock NS2 map comes near the cap; any locations past it are simply not listed.
local kMaxSpawnOptions = 9
local kRandomOption = kMaxSpawnOptions + 1

-- When the server has synced a CustomSpawns-derived legal-spawn list (see
-- HiveSpawnSelector_Server.lua), returns a set of lowercase location names to restrict the picker
-- to. Returns nil when no such list is active (CustomSpawns absent, or not configured for this
-- map), meaning "no restriction beyond the vanilla GetTeamNumberAllowed() check" - the original
-- behaviour.
local function GetLegalAlienNameSet(gameInfo)

    local raw = gameInfo:GetLegalAlienSpawns()
    if not raw or raw == "" then
        return nil
    end

    local set = { }
    for name in string.gmatch(raw, "[^,]+") do
        set[name] = true
    end
    return set

end

local function GetRelevantTechPoints()

    local gameInfo = GetGameInfoEntity()
    local selectedIndex = kRandomOption
    if gameInfo and gameInfo:GetSpawnSelectionEnabled() then
        local legalNames = GetLegalAlienNameSet(gameInfo)
        local allowableSpawns = { }
        local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
        for _, currentTechPoint in ipairs(techPoints) do
            local locationName = currentTechPoint:GetLocationName()

            local isLegal
            if legalNames then
                isLegal = legalNames[string.lower(locationName)] == true
            else
                local teamNumberAllowed = currentTechPoint:GetTeamNumberAllowed()
                isLegal = teamNumberAllowed == 0 or teamNumberAllowed == kTeam2Index
            end

            if isLegal and #allowableSpawns < kMaxSpawnOptions then
                table.insert(allowableSpawns, locationName)
                if currentTechPoint:GetId() == gameInfo:GetSelectedSpawn() then
                    selectedIndex = #allowableSpawns
                end
            end
        end

        return true, allowableSpawns, selectedIndex

    end
    return false, { }, selectedIndex

end

local function UpdateUISize(self)

    self.background:SetSize(GUIScale(kSpawnBackgroundSize))
    self.background:SetPosition(-GUIScale(kSpawnBackgroundSize))

    self.titleBackground:SetSize(GUIScale(kTitleBackgroundSize))
    self.titleBackground:SetPosition(Vector(2, 2, 0))

    self.titleText:SetPosition(GUIScale(kTitleTextOffset))
    self.titleText:SetScale(GetScaledVector())

    for i = 1, kRandomOption do

        local vec = kOptionOffset
        vec = vec * i
        vec.y = vec.y + 15
        self["spawnLocation"..i]:SetPosition(GUIScale(vec))
        self["spawnLocation"..i]:SetScale(GetScaledVector())

    end

end

local function UpdateChoiceOptions(self)

    for i = 1, kMaxSpawnOptions do
        self["spawnLocation"..i]:SetText(self.spawnLocations[i] or "")
    end
    self["spawnLocation"..kRandomOption]:SetText("Random Spawn")
    UpdateUISize(self)
end

function GUIHiveSpawnSelectorMenu:Initialize()

    self.background = GUIManager:CreateGraphicItem()
    self.background:SetIsVisible(false)
    self.background:SetColor(kBackgroundColor)
    self.background:SetAnchor(GUIItem.Right, GUIItem.Center)
    self.background:SetLayer(kGUILayerMainMenu)

    self.titleBackground = GUIManager:CreateGraphicItem()
    self.titleBackground:SetColor(kTitleColor)
    self.background:AddChild(self.titleBackground)

    self.titleText = GUIManager:CreateTextItem()
    self.titleText:SetColor(kTitleTextColor)
    self.titleText:SetText("SELECT STARTING LOCATION")
    self.titleText:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.titleText:SetTextAlignmentX(GUIItem.Align_Center)
    self.titleText:SetTextAlignmentY(GUIItem.Align_Center)
    self.titleBackground:AddChild(self.titleText)

    self.spawnLocations = { }
    self.enabled = false
    self.selectedIndex = kRandomOption
    self.enabled, self.spawnLocations, self.selectedIndex = GetRelevantTechPoints()
    self.opened = false
    self.lastSelected = 0
    self.updateCheck = true
    self.lastUpdateCheck = Shared.GetTime()
    self.selectedId = -1

    for i = 1, kRandomOption do

        self["spawnLocation"..i] = GUIManager:CreateTextItem()
        self["spawnLocation"..i]:SetColor(kOptionColor)
        self["spawnLocation"..i]:SetAnchor(GUIItem.Middle, GUIItem.Top)
        self["spawnLocation"..i]:SetTextAlignmentX(GUIItem.Align_Center)
        self["spawnLocation"..i]:SetTextAlignmentY(GUIItem.Align_Center)
        self.background:AddChild(self["spawnLocation"..i])

    end

    UpdateChoiceOptions(self)

    UpdateUISize(self)

    if HelpScreen_AddObserver then
        HelpScreen_AddObserver(self)
    end

end

function GUIHiveSpawnSelectorMenu:OnHelpScreenVisChange(state)

    self.hiddenByHelpScreen = state
    self:UpdateVisibility()

end

function GUIHiveSpawnSelectorMenu:Uninitialize()

    GUI.DestroyItem(self.titleText)
    self.titleText = nil

    GUI.DestroyItem(self.titleBackground)
    self.titleBackground = nil

    for i = 1, kRandomOption do
        GUI.DestroyItem(self["spawnLocation"..i])
        self["spawnLocation"..i] = nil
    end

    GUI.DestroyItem(self.background)
    self.background = nil

    if HelpScreen_RemoveObserver then
        HelpScreen_RemoveObserver(self)
    end

    MouseTracker_SetIsVisible(false)

end

function GUIHiveSpawnSelectorMenu:SetIsVisible(state)

    self.opened = state
    self:UpdateVisibility()

end

function GUIHiveSpawnSelectorMenu:UpdateVisibility()

    local visible = self.opened and not self.hiddenByHelpScreen and self.enabled

    self.background:SetIsVisible(visible)
    MouseTracker_SetIsVisible(visible, "ui/Cursor_MenuDefault.dds", true)

end

function GUIHiveSpawnSelectorMenu:OnResolutionChanged(oldX, oldY, newX, newY)
    UpdateUISize(self)
end

function GUIHiveSpawnSelectorMenu:Update(deltaTime)

    PROFILE("GUIHiveSpawnSelectorMenu:Update")

    if self.background:GetIsVisible() then

        for i = 1, kRandomOption do

            if i == self.selectedIndex then
                self["spawnLocation"..i]:SetColor(kOptionChosenColor)
            elseif GUIItemContainsPoint(self["spawnLocation"..i], Client.GetCursorPosScreen()) then
                self["spawnLocation"..i]:SetColor(kOptionSelectedColor)
            else
                self["spawnLocation"..i]:SetColor(kOptionColor)
            end

        end

    end

    local gameInfo = GetGameInfoEntity()
    if not gameInfo then
        return
    end

    -- Track whether the panel *should* be open rather than whether it happens to be drawn. While
    -- selection is disabled (or the help screen is up) the panel is hidden but still open, and
    -- keying off the drawn state re-opened it every frame - which reset the refresh timer below,
    -- so self.enabled never updated and sv_spawnselect could not be toggled live.
    local gameStarted = gameInfo:GetGameStarted()
    if gameStarted and self.opened then
        self:SetIsVisible(false)
    elseif not gameStarted and not self.opened then
        self:SetIsVisible(true)
        self.updateCheck = true
        self.lastUpdateCheck = Shared.GetTime()
    end

    if self.lastUpdateCheck + 1 < Shared.GetTime() then
        local wasEnabled = self.enabled
        self.enabled, self.spawnLocations, self.selectedIndex = GetRelevantTechPoints()
        -- An admin toggling sv_spawnselect has to show or hide the panel under a seated commander.
        if wasEnabled ~= self.enabled then
            self:UpdateVisibility()
        end
        if self.updateCheck then
            UpdateChoiceOptions(self)
            self.updateCheck = false
        end
        if self.selectedId ~= gameInfo:GetSelectedSpawn() then
            self.selectedId = gameInfo:GetSelectedSpawn()
            UpdateChoiceOptions(self)
        end
        self.lastUpdateCheck = Shared.GetTime()
    end

end

local function SpawnItemSelected(self, index)

    if index ~= self.selectedIndex then

        local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
        for _, currentTechPoint in ipairs(techPoints) do
            if currentTechPoint:GetLocationName() == self.spawnLocations[index] then
                Client.SendNetworkMessage("HiveSpawnSelector_SelectSpawn", { techPointId = currentTechPoint:GetId() }, true)
                self.selectedIndex = index
            end
        end

        if index == kRandomOption then
            Client.SendNetworkMessage("HiveSpawnSelector_SelectSpawn", { techPointId = -1 }, true)
            self.selectedIndex = index
        end

    end

end

function GUIHiveSpawnSelectorMenu:SendKeyEvent(key, down)

    if self.background:GetIsVisible() then

        if key == InputKey.MouseButton0 then

            for i = 1, kRandomOption do
                local item = self["spawnLocation"..i]
                if item:GetIsVisible() and GUIItemContainsPoint(item, Client.GetCursorPosScreen()) and self.lastSelected + kSelectionDelay < Shared.GetTime() then
                    self.lastSelected = Shared.GetTime()
                    SpawnItemSelected(self, i)
                    return false

                end

            end

        end

    end

    return false

end
