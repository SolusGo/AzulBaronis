-- Azul Baronis -- Fleet Systems dashboard and confirmed selectors.

local SAVE = Modding.OpenSaveData()
local CIV_AZUL = GameInfoTypes.CIVILIZATION_AZUL_BARONIS
local PROCESS_CANNON = GameInfoTypes.PROCESS_AZUL_CHARGE_MAIN_CANNON
local PROCESS_TURRET = GameInfoTypes.PROCESS_AZUL_CONSTRUCT_TURRET
local TERRAIN_OCEAN = GameInfoTypes.TERRAIN_OCEAN
local TECH_ASTRONOMY = GameInfoTypes.TECH_ASTRONOMY
local TECH_FLIGHT = GameInfoTypes.TECH_FLIGHT
local DOMAIN_AIR = GameInfoTypes.DOMAIN_AIR
local MOVE_DENOMINATOR = GameDefines.MOVE_DENOMINATOR or 60
local MAX_CIV_PLAYERS = GameDefines.MAX_PLAYERS or GameDefines.MAX_CIV_PLAYERS or 64

local FAMILY = {}
local function AddFamily(name, types)
    for _, typeName in ipairs(types) do
        local id = GameInfoTypes[typeName]
        if id ~= nil then FAMILY[id] = name end
    end
end
AddFamily('FIGHTER', {
    'UNIT_AZUL_FIGHTER_ANCIENT', 'UNIT_AZUL_FIGHTER_CLASSICAL',
    'UNIT_AZUL_FIGHTER_MEDIEVAL', 'UNIT_AZUL_FIGHTER_RENAISSANCE',
    'UNIT_AZUL_FIGHTER_INDUSTRIAL', 'UNIT_AZUL_FIGHTER_MODERN',
    'UNIT_AZUL_FIGHTER_ATOMIC', 'UNIT_AZUL_FIGHTER_INFORMATION'
})
AddFamily('DESTROYER', {
    'UNIT_AZUL_DESTROYER_RENAISSANCE', 'UNIT_AZUL_DESTROYER_INDUSTRIAL',
    'UNIT_AZUL_DESTROYER_MODERN', 'UNIT_AZUL_DESTROYER_ATOMIC',
    'UNIT_AZUL_DESTROYER_INFORMATION'
})
AddFamily('TESTUDON', {
    'UNIT_AZUL_TESTUDON_INDUSTRIAL', 'UNIT_AZUL_TESTUDON_MODERN',
    'UNIT_AZUL_TESTUDON_ATOMIC', 'UNIT_AZUL_TESTUDON_INFORMATION'
})
AddFamily('TURRET', {
    'UNIT_AZUL_TURRET_ANCIENT', 'UNIT_AZUL_TURRET_CLASSICAL',
    'UNIT_AZUL_TURRET_MEDIEVAL', 'UNIT_AZUL_TURRET_RENAISSANCE',
    'UNIT_AZUL_TURRET_INDUSTRIAL', 'UNIT_AZUL_TURRET_MODERN',
    'UNIT_AZUL_TURRET_ATOMIC', 'UNIT_AZUL_TURRET_INFORMATION'
})
if GameInfoTypes.UNIT_AZUL_FLEET_COMMANDER ~= nil then
    FAMILY[GameInfoTypes.UNIT_AZUL_FLEET_COMMANDER] = 'COMMANDER'
end

local CANNON_BASE = {220, 300, 420, 600, 820, 1100, 1450, 1900}
local TURRET_BASE = {120, 160, 220, 300, 400, 540, 720, 950}
local panelOpen = false
local selectorOpen = false
local selectorMode = nil
local candidates = {}
local candidateIndex = 1
local selectorUnitID = -1
local confirmUnitID = -1

local function SavedNumber(key, fallback)
    local value = SAVE.GetValue(key)
    if value == nil then return fallback end
    return tonumber(value) or fallback
end

local function PKey(playerID, suffix)
    return 'AZUL_' .. tostring(suffix) .. '_' .. tostring(playerID)
end

local function UKey(prefix, playerID, unitID)
    return 'AZUL_' .. tostring(prefix) .. '_' .. tostring(playerID) .. '_' .. tostring(unitID)
end

local function GetMeter(playerID, name)
    local precise = SAVE.GetValue(PKey(playerID, name .. '_X100'))
    if precise ~= nil then return math.max(0, tonumber(precise) or 0) end
    return math.max(0, SavedNumber(PKey(playerID, name), 0) * 100)
end

local function FormatHundredths(value)
    local text = string.format('%.2f', math.max(0, value or 0) / 100)
    text = string.gsub(text, '0+$', '')
    text = string.gsub(text, '%.$', '')
    return text
end

local function IsAttackLocked(playerID, unitID)
    return SavedNumber(UKey('ATTACK_LOCK', playerID, unitID), -1) == Game.GetGameTurn()
end

local function ActiveAzul()
    local playerID = Game.GetActivePlayer()
    local player = playerID ~= nil and playerID >= 0 and Players[playerID] or nil
    if player == nil or not player:IsAlive() or player:GetCivilizationType() ~= CIV_AZUL then return nil, playerID end
    return player, playerID
end

local function EraIndex(player)
    return math.max(0, math.min(7, tonumber(player:GetCurrentEra()) or 0))
end

local function Requirement(base, player)
    local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
    local percent = speed and tonumber(speed.TrainPercent) or 100
    return math.max(1, math.floor((base[EraIndex(player) + 1] or base[#base]) * percent / 100 + 0.5))
end

local function HasTech(player, techID)
    return techID ~= nil and Teams[player:GetTeam()]:IsHasTech(techID)
end

local function OriginalCity(playerID, controlled)
    local x = SavedNumber(PKey(playerID, 'MOTH_X'), -1)
    local y = SavedNumber(PKey(playerID, 'MOTH_Y'), -1)
    if x < 0 or y < 0 then return nil end
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity() or nil
    if city == nil or (controlled and city:GetOwner() ~= playerID) then return nil end
    return city
end

local function PlayerShip(player, playerID)
    local id = SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1)
    local unit = id >= 0 and player:GetUnitByID(id) or nil
    local family = unit and FAMILY[unit:GetUnitType()] or nil
    if family ~= 'FIGHTER' and family ~= 'DESTROYER' then return nil end
    return unit
end

local function SelectedFleetUnit(player)
    local unit = UI.GetHeadSelectedUnit()
    if unit == nil or unit:GetOwner() ~= player:GetID() or FAMILY[unit:GetUnitType()] == nil then return nil end
    return unit
end

local function CountFamily(player, wanted)
    local count = 0
    for unit in player:Units() do if FAMILY[unit:GetUnitType()] == wanted then count = count + 1 end end
    return count
end

local function TestudonCap(player)
    local era = EraIndex(player)
    return era < 4 and 0 or math.min(4, era - 3)
end

local function UnitLabel(unit)
    if unit == nil then return 'Unknown unit' end
    local name = unit:HasName() and unit:GetNameNoDesc() or Locale.ConvertTextKey(unit:GetNameKey())
    return name .. '  |  (' .. tostring(unit:GetX()) .. ', ' .. tostring(unit:GetY()) .. ')'
end

local function ClearHighlights()
    for _, row in ipairs(candidates) do
        if row.plot ~= nil then
            Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(row.plot:GetX(), row.plot:GetY())), false)
        end
    end
end

local function CloseSelector()
    ClearHighlights()
    candidates = {}
    selectorOpen = false
    selectorMode = nil
    selectorUnitID = -1
    Controls.TargetPanel:SetHide(true)
end

local function RefreshSelector()
    ClearHighlights()
    if #candidates == 0 then
        Controls.TargetName:SetText('No valid targets are currently available.')
        Controls.ConfirmTargetButton:SetDisabled(true)
        Controls.PreviousButton:SetDisabled(true)
        Controls.NextButton:SetDisabled(true)
        return
    end
    if candidateIndex < 1 then candidateIndex = #candidates end
    if candidateIndex > #candidates then candidateIndex = 1 end
    Controls.ConfirmTargetButton:SetDisabled(false)
    Controls.PreviousButton:SetDisabled(#candidates <= 1)
    Controls.NextButton:SetDisabled(#candidates <= 1)
    for i, row in ipairs(candidates) do
        local color = i == candidateIndex and Vector4(0.22, 0.78, 1.0, 1.0)
            or Vector4(0.14, 0.42, 0.72, 0.60)
        Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(row.plot:GetX(), row.plot:GetY())), true, color)
    end
    local row = candidates[candidateIndex]
    Controls.TargetName:SetText(tostring(candidateIndex) .. ' / ' .. tostring(#candidates) .. '   ' .. row.label)
    UI.LookAt(row.plot, 0)
end

local function IsHostile(player, ownerID)
    local other = Players[ownerID]
    return other ~= nil and Teams[player:GetTeam()]:IsAtWar(other:GetTeam())
end

local function UnitsInRange(player, origin, range, cannonOnly)
    local rows = {}
    for ownerID = 0, MAX_CIV_PLAYERS - 1 do
        local other = Players[ownerID]
        if other ~= nil and other:IsAlive() and IsHostile(player, ownerID) then
            for unit in other:Units() do
                local plot = unit:GetPlot()
                local valid = unit:IsCombatUnit() and unit:GetDomainType() ~= DOMAIN_AIR and plot ~= nil
                    and plot:IsVisible(player:GetTeam(), false)
                    and Map.PlotDistance(origin:GetX(), origin:GetY(), unit:GetX(), unit:GetY()) <= range
                if valid then
                    rows[#rows + 1] = {
                        plot = plot,
                        ownerID = ownerID,
                        unitID = unit:GetID(),
                        label = UnitLabel(unit) .. '  •  ' .. tostring(unit:GetDamage()) .. ' damage'
                    }
                end
            end
        end
    end
    return rows
end

local function CaptureTargets(player, unit)
    local rows = {}
    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
        local plot = Map.PlotDirection(unit:GetX(), unit:GetY(), direction)
        local city = plot and plot:GetPlotCity() or nil
        if city ~= nil and IsHostile(player, city:GetOwner())
            and city:GetDamage() >= math.max(0, city:GetMaxHitPoints() - 1) then
            rows[#rows + 1] = {plot = plot, x = plot:GetX(), y = plot:GetY(), label = city:GetName() .. ' — defeated city'}
        end
    end
    return rows
end

local function LegalTurretPlot(player, city, plot)
    if plot == nil or plot:IsCity() or plot:GetNumUnits() > 0 then return false end
    if Map.PlotDistance(city:GetX(), city:GetY(), plot:GetX(), plot:GetY()) > 3 then return false end
    if plot:GetTerrainType() == TERRAIN_OCEAN and not HasTech(player, TECH_ASTRONOMY) then return false end
    if plot:IsMountain() and not HasTech(player, TECH_FLIGHT) then return false end
    if plot:IsImpassable() and not plot:IsMountain() then return false end
    local owner = plot:GetOwner()
    return owner < 0 or owner == player:GetID() or IsHostile(player, owner)
end

local function TurretPlots(player, city)
    local rows, seen = {}, {}
    for dx = -3, 3 do
        for dy = -3, 3 do
            local plot = Map.PlotXYWithRangeCheck(city:GetX(), city:GetY(), dx, dy, 3)
            if LegalTurretPlot(player, city, plot) and not seen[plot:GetPlotIndex()] then
                seen[plot:GetPlotIndex()] = true
                local terrain = GameInfo.Terrains[plot:GetTerrainType()]
                rows[#rows + 1] = {
                    plot = plot, x = plot:GetX(), y = plot:GetY(),
                    label = Locale.ConvertTextKey(terrain.Description) .. ' deployment at ('
                        .. tostring(plot:GetX()) .. ', ' .. tostring(plot:GetY()) .. ')'
                }
            end
        end
    end
    return rows
end

local function EligibleShips(player)
    local rows = {}
    for unit in player:Units() do
        local family = FAMILY[unit:GetUnitType()]
        if family == 'FIGHTER' or family == 'DESTROYER' then
            rows[#rows + 1] = {plot = unit:GetPlot(), unitID = unit:GetID(), label = '★ ' .. UnitLabel(unit)}
        end
    end
    return rows
end

local function OpenSelector(mode)
    local player, playerID = ActiveAzul()
    if player == nil then return end
    CloseSelector()
    selectorMode = mode
    selectorOpen = true
    candidateIndex = 1
    local selected = SelectedFleetUnit(player)
    local title, instructions = 'SELECT TARGET', 'Choose a highlighted target and confirm.'
    if mode == 'PLAYER' then
        title = 'SELECT PLAYER SHIP'
        instructions = 'Only Fighters and Destroyers are eligible. Selection is free only while no Player Ship exists.'
        candidates = EligibleShips(player)
    elseif mode == 'HOMING' and selected ~= nil and FAMILY[selected:GetUnitType()] == 'DESTROYER' then
        title = 'HOMING BOMB TARGET'
        instructions = 'Range 3 • 125% Ranged Strength • ignores terrain defense and line of sight • confirm to fire.'
        selectorUnitID = selected:GetID()
        candidates = UnitsInRange(player, selected, 3, false)
    elseif mode == 'CANNON' then
        local city = OriginalCity(playerID, true)
        title = 'MAIN CANNON TARGET'
        instructions = 'Range 5 • visible hostile combat units only • confirmation instantly destroys the target and empties the battery.'
        if city ~= nil then candidates = UnitsInRange(player, city, 5, true) end
    elseif mode == 'TURRET' then
        local city = OriginalCity(playerID, true)
        title = 'DEPLOY DEFENSIVE TURRET'
        instructions = 'Choose an empty legal tile within 3 of the Mothership. Confirmation permanently anchors the turret.'
        if city ~= nil then candidates = TurretPlots(player, city) end
    elseif mode == 'CAPTURE' and selected ~= nil then
        title = 'CAPTURE DEFEATED CITY'
        instructions = 'Confirm military conquest. The ship loses all Movement and cannot attack again this turn.'
        selectorUnitID = selected:GetID()
        candidates = CaptureTargets(player, selected)
    end
    Controls.TargetTitle:SetText(title)
    Controls.TargetInstructions:SetText(instructions)
    Controls.TargetPanel:SetHide(false)
    RefreshSelector()
end

local function ConfirmTarget()
    local player, playerID = ActiveAzul()
    local row = candidates[candidateIndex]
    if player == nil or row == nil then return end
    if selectorMode == 'PLAYER' then
        LuaEvents.Azul_SelectPlayerShip(playerID, row.unitID)
    elseif selectorMode == 'HOMING' then
        LuaEvents.Azul_FireHomingBomb(playerID, selectorUnitID, row.ownerID, row.unitID)
    elseif selectorMode == 'CANNON' then
        LuaEvents.Azul_FireMainCannon(playerID, row.ownerID, row.unitID)
    elseif selectorMode == 'TURRET' then
        LuaEvents.Azul_DeployTurret(playerID, row.x, row.y)
    elseif selectorMode == 'CAPTURE' then
        LuaEvents.Azul_CaptureCity(playerID, selectorUnitID, row.x, row.y)
    end
    CloseSelector()
    Events.SerialEventGameDataDirty()
end

local function SetPanelOpen(open)
    local player = ActiveAzul()
    panelOpen = open == true and player ~= nil
    Controls.FleetPanel:SetHide(not panelOpen)
    if not panelOpen then CloseSelector() end
end

local function Refresh()
    local player, playerID = ActiveAzul()
    if player == nil then
        Controls.FleetButton:SetHide(true)
        Controls.FleetPanel:SetHide(true)
        panelOpen = false
        CloseSelector()
        return
    end
    Controls.FleetButton:SetHide(false)
    Controls.TurnLabel:SetText('TURN ' .. tostring(Game.GetGameTurn()))

    local playerShip = PlayerShip(player, playerID)
    if playerShip == nil then
        Controls.PlayerShipName:SetText('NO PLAYER SHIP')
        Controls.PlayerShipStats:SetText('The ability is dormant until a Fighter or Destroyer is selected.')
        Controls.AfterburnerState:SetText('Afterburner — OFFLINE')
        Controls.AfterburnerButton:SetDisabled(true)
        Controls.LocateButton:SetDisabled(true)
        Controls.SelectShipButton:SetDisabled(#EligibleShips(player) == 0)
        Controls.SelfDestructButton:SetDisabled(true)
    else
        local family = FAMILY[playerShip:GetUnitType()]
        local cooldown = SavedNumber(UKey('AFTERBURNER', playerID, playerShip:GetID()), 0)
        Controls.PlayerShipName:SetText('★ ' .. (playerShip:HasName() and playerShip:GetNameNoDesc()
            or Locale.ConvertTextKey(playerShip:GetNameKey())))
        Controls.PlayerShipStats:SetText(family .. '  •  [ICON_MOVES] '
            .. string.format('%.1f / %.1f', playerShip:MovesLeft() / MOVE_DENOMINATOR, playerShip:MaxMoves() / MOVE_DENOMINATOR)
            .. '  •  +25% XP  •  +1 Sight')
        Controls.AfterburnerState:SetText(cooldown == 0 and '[COLOR_POSITIVE_TEXT]Afterburner — READY[ENDCOLOR]'
            or ('Afterburner — ' .. tostring(cooldown) .. (cooldown == 1 and ' turn' or ' turns')))
        Controls.AfterburnerButton:SetDisabled(cooldown > 0 or playerShip:IsOutOfAttacks()
            or IsAttackLocked(playerID, playerShip:GetID()))
        Controls.LocateButton:SetDisabled(false)
        Controls.SelectShipButton:SetDisabled(true)
        Controls.SelfDestructButton:SetDisabled(false)
    end

    local selected = SelectedFleetUnit(player)
    local selectedFamily = selected and FAMILY[selected:GetUnitType()] or nil
    if selected == nil then
        Controls.SelectedUnitName:SetText('No fleet vessel selected')
        Controls.SelectedUnitStats:SetText('Select a Fighter, Destroyer, Testudon, turret, or Fleet Commander on the map.')
        Controls.WeaponState:SetText('Fleet actions appear here.')
    else
        Controls.SelectedUnitName:SetText(UnitLabel(selected))
        local info = GameInfo.Units[selected:GetUnitType()]
        local displayedMoves = selectedFamily == 'TURRET' and 0 or selected:MovesLeft() / MOVE_DENOMINATOR
        Controls.SelectedUnitStats:SetText(selectedFamily .. '  •  [ICON_STRENGTH] ' .. tostring(info.Combat)
            .. '  •  [ICON_RANGE_STRENGTH] ' .. tostring(info.RangedCombat)
            .. '  •  [ICON_MOVES] ' .. string.format('%.1f', displayedMoves))
        if selectedFamily == 'DESTROYER' then
            local cooldown = SavedNumber(UKey('HOMING', playerID, selected:GetID()), 0)
            Controls.WeaponState:SetText(cooldown == 0 and '[COLOR_POSITIVE_TEXT]Forward Beam  |  Homing Bomb — READY[ENDCOLOR]'
                or ('Forward Beam  |  Homing Bomb — ' .. tostring(cooldown) .. (cooldown == 1 and ' turn' or ' turns')))
        elseif selectedFamily == 'TESTUDON' then
            Controls.WeaponState:SetText('Focused Beam • cannot attack after moving • 25% ranged damage reduction')
        elseif selectedFamily == 'FIGHTER' then
            Controls.WeaponState:SetText('Dogfighter • ignores enemy Zone of Control • mobile ranged capture vessel')
        else
            Controls.WeaponState:SetText('No alternate weapon action.')
        end
    end

    local homingCooldown = selected and SavedNumber(UKey('HOMING', playerID, selected:GetID()), 0) or 1
    Controls.HomingButton:SetHide(selectedFamily ~= 'DESTROYER')
    Controls.HomingButton:SetDisabled(selected == nil or selected:IsOutOfAttacks() or homingCooldown > 0
        or (selected ~= nil and IsAttackLocked(playerID, selected:GetID())))
    local captureRows = selected and (selectedFamily == 'FIGHTER' or selectedFamily == 'DESTROYER' or selectedFamily == 'TESTUDON')
        and CaptureTargets(player, selected) or {}
    Controls.CaptureButton:SetHide(not (selectedFamily == 'FIGHTER' or selectedFamily == 'DESTROYER' or selectedFamily == 'TESTUDON'))
    Controls.CaptureButton:SetDisabled(#captureRows == 0)

    local city = OriginalCity(playerID, true)
    local cannonRequired = Requirement(CANNON_BASE, player) * 100
    local cannon = math.min(cannonRequired, GetMeter(playerID, 'BATTERY'))
    local turretRequired = Requirement(TURRET_BASE, player) * 100
    local turret = math.min(turretRequired, GetMeter(playerID, 'TURRET_PROGRESS'))
    local turretReady = SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 1
    local turretCount = CountFamily(player, 'TURRET')

    Controls.CannonFill:SetSizeX(math.max(1, math.floor(359 * cannon / math.max(1, cannonRequired))))
    Controls.CannonProgress:SetText(FormatHundredths(cannon) .. ' / ' .. FormatHundredths(cannonRequired))
    Controls.TurretFill:SetSizeX(math.max(1, math.floor(359 * turret / math.max(1, turretRequired))))
    Controls.TurretProgress:SetText(turretReady and 'TURRET READY'
        or (FormatHundredths(turret) .. ' / ' .. FormatHundredths(turretRequired)))
    Controls.TurretCount:SetText('Turrets: ' .. tostring(turretCount) .. ' / 4')
    Controls.TestudonCount:SetText('TESTUDONS  ' .. tostring(CountFamily(player, 'TESTUDON')) .. ' / ' .. tostring(TestudonCap(player)))

    if city == nil then
        Controls.MothershipState:SetText('[COLOR_WARNING_TEXT]MOTHERSHIP LOST — SYSTEMS OFFLINE[ENDCOLOR]')
        Controls.CannonDetail:SetText('Retake the original Mothership city to restore its Core. Batteries restart at zero.')
        Controls.TurretDetail:SetText('All deployed turrets were destroyed when the Mothership was lost.')
    else
        local production = math.max(0, city:GetCurrentProductionDifferenceTimes100(false, false))
        Controls.MothershipState:SetText('[COLOR_POSITIVE_TEXT]MOTHERSHIP ONLINE[ENDCOLOR]  •  ' .. city:GetName())
        Controls.CannonDetail:SetText(city:GetProductionProcess() == PROCESS_CANNON
            and ('Charging at +' .. FormatHundredths(production) .. ' per turn.')
            or 'Stored energy persists when charging stops.')
        Controls.TurretDetail:SetText(turretReady and '[COLOR_POSITIVE_TEXT]One completed turret is ready for deployment.[ENDCOLOR]'
            or (city:GetProductionProcess() == PROCESS_TURRET
                and ('Constructing at +' .. FormatHundredths(production) .. ' per turn.')
                or 'One completed turret may be stored.'))
    end
    Controls.ChargeButton:SetDisabled(city == nil or cannon >= cannonRequired)
    local cityAttackSpent = city ~= nil and (city:HasPerformedRangedStrikeThisTurn()
        or SavedNumber(PKey(playerID, 'CANNON_FIRED_TURN'), -1) == Game.GetGameTurn())
    Controls.FireButton:SetDisabled(city == nil or cannon < cannonRequired or cityAttackSpent)
    Controls.ConstructButton:SetDisabled(city == nil or turretReady or turretCount >= 4)
    Controls.DeployButton:SetDisabled(city == nil or not turretReady or turretCount >= 4)
    Controls.FooterLabel:SetText(city == nil
        and 'Fleet hull scaling and Player Ship control remain active without the Mothership.'
        or 'All meters and cooldowns persist through save/load. Ships modernize automatically on Era change.')
    Controls.FleetButtonLabel:SetText('★ FLEET SYSTEMS  •  T' .. tostring(CountFamily(player, 'TESTUDON')) .. '/' .. tostring(TestudonCap(player)))
end

Controls.FleetButton:RegisterCallback(Mouse.eLClick, function()
    SetPanelOpen(not panelOpen)
    if panelOpen then Refresh() end
end)
Controls.CloseButton:RegisterCallback(Mouse.eLClick, function() SetPanelOpen(false) end)
Controls.RefreshButton:RegisterCallback(Mouse.eLClick, Refresh)
Controls.SelectShipButton:RegisterCallback(Mouse.eLClick, function() OpenSelector('PLAYER') end)
Controls.AfterburnerButton:RegisterCallback(Mouse.eLClick, function()
    local player, playerID = ActiveAzul()
    local unit = player and PlayerShip(player, playerID) or nil
    if unit ~= nil then LuaEvents.Azul_UseAfterburner(playerID, unit:GetID()) end
end)
Controls.LocateButton:RegisterCallback(Mouse.eLClick, function()
    local player, playerID = ActiveAzul()
    local unit = player and PlayerShip(player, playerID) or nil
    if unit ~= nil then UI.LookAt(unit:GetPlot(), 0) end
end)
Controls.SelfDestructButton:RegisterCallback(Mouse.eLClick, function()
    local player, playerID = ActiveAzul()
    local unit = player and PlayerShip(player, playerID) or nil
    if unit == nil then return end
    confirmUnitID = unit:GetID()
    Controls.ConfirmText:SetText('Permanently destroy ' .. UnitLabel(unit)
        .. '? Switching Player Ship is allowed only because this vessel will be destroyed.')
    Controls.ConfirmPanel:SetHide(false)
end)
Controls.ConfirmYesButton:RegisterCallback(Mouse.eLClick, function()
    local _, playerID = ActiveAzul()
    Controls.ConfirmPanel:SetHide(true)
    if confirmUnitID >= 0 then LuaEvents.Azul_SelfDestruct(playerID, confirmUnitID) end
    confirmUnitID = -1
end)
Controls.ConfirmNoButton:RegisterCallback(Mouse.eLClick, function()
    confirmUnitID = -1
    Controls.ConfirmPanel:SetHide(true)
end)
Controls.HomingButton:RegisterCallback(Mouse.eLClick, function() OpenSelector('HOMING') end)
Controls.CaptureButton:RegisterCallback(Mouse.eLClick, function() OpenSelector('CAPTURE') end)
Controls.ChargeButton:RegisterCallback(Mouse.eLClick, function()
    local _, playerID = ActiveAzul()
    LuaEvents.Azul_SetMothershipProcess(playerID, PROCESS_CANNON)
end)
Controls.FireButton:RegisterCallback(Mouse.eLClick, function() OpenSelector('CANNON') end)
Controls.ConstructButton:RegisterCallback(Mouse.eLClick, function()
    local _, playerID = ActiveAzul()
    LuaEvents.Azul_SetMothershipProcess(playerID, PROCESS_TURRET)
end)
Controls.DeployButton:RegisterCallback(Mouse.eLClick, function() OpenSelector('TURRET') end)
Controls.PreviousButton:RegisterCallback(Mouse.eLClick, function() candidateIndex = candidateIndex - 1; RefreshSelector() end)
Controls.NextButton:RegisterCallback(Mouse.eLClick, function() candidateIndex = candidateIndex + 1; RefreshSelector() end)
Controls.ConfirmTargetButton:RegisterCallback(Mouse.eLClick, ConfirmTarget)
Controls.CancelTargetButton:RegisterCallback(Mouse.eLClick, CloseSelector)

ContextPtr:SetInputHandler(function(uiMsg, wParam)
    if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE then
        if not Controls.ConfirmPanel:IsHidden() then Controls.ConfirmPanel:SetHide(true); return true end
        if selectorOpen then CloseSelector(); return true end
        if panelOpen then SetPanelOpen(false); return true end
    end
    return false
end)

LuaEvents.Azul_PlayerShipSelectionAvailable.Add(function(playerID)
    if playerID == Game.GetActivePlayer() then
        SetPanelOpen(true)
        Refresh()
        OpenSelector('PLAYER')
    end
end)
LuaEvents.Azul_StateChanged.Add(function(playerID)
    if playerID == Game.GetActivePlayer() then Refresh() end
end)
if Events.SerialEventGameDataDirty ~= nil then Events.SerialEventGameDataDirty.Add(Refresh) end
if Events.SerialEventUnitInfoDirty ~= nil then Events.SerialEventUnitInfoDirty.Add(Refresh) end
if Events.UnitSelectionChanged ~= nil then Events.UnitSelectionChanged.Add(Refresh) end
if Events.ActivePlayerTurnStart ~= nil then Events.ActivePlayerTurnStart.Add(Refresh) end
Events.GameplaySetActivePlayer.Add(function()
    SetPanelOpen(false)
    Controls.ConfirmPanel:SetHide(true)
    Refresh()
end)

Refresh()
