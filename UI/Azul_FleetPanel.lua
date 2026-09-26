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

local CANNON_BASE = {260, 360, 500, 700, 950, 1275, 1675, 2175}
local TURRET_BASE = {120, 160, 220, 300, 400, 540, 720, 950}
local panelOpen = false
local selectorOpen = false
local confirmOpen = false
local selectorMode = nil
local candidates = {}
local candidateIndex = 1
local selectorUnitID = -1
local confirmUnitID = -1
local commsEntries = {}
local commsLabels = {Controls.CommsLine1, Controls.CommsLine2, Controls.CommsLine3, Controls.CommsLine4}
local COMMS_DURATION = 8
local commsTextDirty = false
local commsAnimating = false
local cityViewOpen = UI.IsCityScreenUp ~= nil and UI.IsCityScreenUp() or false
local leaderViewOpen = UI.GetLeaderHeadRootUp ~= nil and UI.GetLeaderHeadRootUp() or false
local bulkUIHidden = false
local interfaceModeHidden = false
local majorPopupOpen = {}
local hudSuppressed = cityViewOpen or leaderViewOpen
local hudEligible = false
local pendingPlayerShipSelection = false

local function SetHidden(control, hidden)
    if control:IsHidden() ~= hidden then control:SetHide(hidden) end
end

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

local function IsModalInterfaceMode(mode)
    return InterfaceModeTypes ~= nil and (mode == InterfaceModeTypes.INTERFACEMODE_CITY_PLOT_SELECTION
        or mode == InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT)
end

if UI.GetInterfaceMode ~= nil then
    interfaceModeHidden = IsModalInterfaceMode(UI.GetInterfaceMode())
    hudSuppressed = hudSuppressed or interfaceModeHidden
end

local function RefreshComms()
    local player = ActiveAzul()
    local visible = player ~= nil and not hudSuppressed and #commsEntries > 0
        and not panelOpen and not selectorOpen and not confirmOpen
    SetHidden(Controls.CommsPanel, not visible)
    if commsTextDirty then
        for index, label in ipairs(commsLabels) do
            local entry = commsEntries[index]
            label:SetText(entry and entry.text or '')
        end
        commsTextDirty = false
    end
end

local function TickComms(deltaTime)
    local elapsed = math.max(0, tonumber(deltaTime) or 0)
    local removed = false
    for index = #commsEntries, 1, -1 do
        commsEntries[index].age = commsEntries[index].age + elapsed
        if commsEntries[index].age >= COMMS_DURATION then
            table.remove(commsEntries, index)
            removed = true
        end
    end
    if removed then
        commsTextDirty = true
        RefreshComms()
    end
    if #commsEntries == 0 then
        ContextPtr:ClearUpdate()
        commsAnimating = false
        return
    end
    if not Controls.CommsPanel:IsHidden() then
        for index, label in ipairs(commsLabels) do
            local entry = commsEntries[index]
            if label.SetAlpha ~= nil then
                label:SetAlpha(entry and math.max(0, math.min(1, (COMMS_DURATION - entry.age) / 2)) or 0)
            end
        end
    end
end

local function StartCommsAnimation()
    if not commsAnimating then
        commsAnimating = true
        ContextPtr:SetUpdate(TickComms)
    end
end

local function ApplyVisibility()
    local player = ActiveAzul()
    hudEligible = player ~= nil
    local visible = player ~= nil and not hudSuppressed
    SetHidden(Controls.FleetButton, not visible)
    SetHidden(Controls.FleetPanel, not (visible and panelOpen and not selectorOpen))
    SetHidden(Controls.TargetPanel, not (visible and selectorOpen))
    SetHidden(Controls.ConfirmPanel, not (visible and confirmOpen))
    RefreshComms()
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

local function PlotHex(plot)
    if plot == nil or ToHexFromGrid == nil then return nil end
    -- Vector2 is absent in some InGameUIAddin contexts. ToHexFromGrid also
    -- accepts an ordinary coordinate table, which is portable across them.
    return ToHexFromGrid({x = plot:GetX(), y = plot:GetY()})
end

local function SetPlotHighlight(plot, enabled, selected)
    if Events == nil or Events.SerialEventHexHighlight == nil then return end
    local hex = PlotHex(plot)
    if hex == nil then return end
    if enabled and Vector4 ~= nil then
        local color = selected and Vector4(0.22, 0.78, 1.0, 1.0)
            or Vector4(0.14, 0.42, 0.72, 0.60)
        Events.SerialEventHexHighlight(hex, true, color)
    else
        -- Highlighting is cosmetic. Keep selectors functional even if the
        -- host context does not expose the optional Vector4 constructor.
        Events.SerialEventHexHighlight(hex, enabled)
    end
end

local function ClearHighlights()
    for _, row in ipairs(candidates) do
        SetPlotHighlight(row.plot, false, false)
    end
end

local function CloseSelector()
    ClearHighlights()
    candidates = {}
    selectorOpen = false
    selectorMode = nil
    selectorUnitID = -1
    -- Return to the dashboard only if it was still open. Selection mode hides
    -- the large panel so the centered candidate plot remains unobstructed.
    ApplyVisibility()
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
        SetPlotHighlight(row.plot, true, i == candidateIndex)
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
    if hudSuppressed then return end
    local player, playerID = ActiveAzul()
    if player == nil then return end
    if selectorOpen then CloseSelector() end
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
        instructions = 'Range 3 • 115% Ranged Strength • ignores terrain defense and line of sight • confirm to fire.'
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
    ApplyVisibility()
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
    if not panelOpen and selectorOpen then CloseSelector() end
    ApplyVisibility()
end

local function Refresh()
    local player, playerID = ActiveAzul()
    if player == nil then
        if hudEligible or panelOpen or selectorOpen or confirmOpen then
            panelOpen = false
            if selectorOpen then CloseSelector() end
            confirmOpen = false
            confirmUnitID = -1
            ApplyVisibility()
        end
        return
    end
    if not hudEligible then ApplyVisibility() end
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
            Controls.WeaponState:SetText('Focused Beam vs units • city HP floor 25/27/30/33% by hull Era • no attack after moving')
        elseif selectedFamily == 'FIGHTER' then
            Controls.WeaponState:SetText('Dogfighter • +10% ranged defense / 5% evade while mobile • ignores enemy Zone of Control')
        else
            Controls.WeaponState:SetText('No alternate weapon action.')
        end
    end

    local homingCooldown = selected and SavedNumber(UKey('HOMING', playerID, selected:GetID()), 0) or 1
    SetHidden(Controls.HomingButton, selectedFamily ~= 'DESTROYER')
    Controls.HomingButton:SetDisabled(selected == nil or selected:IsOutOfAttacks() or homingCooldown > 0
        or (selected ~= nil and IsAttackLocked(playerID, selected:GetID())))
    local captureRows = selected and (selectedFamily == 'FIGHTER' or selectedFamily == 'DESTROYER' or selectedFamily == 'TESTUDON')
        and CaptureTargets(player, selected) or {}
    SetHidden(Controls.CaptureButton, not (selectedFamily == 'FIGHTER' or selectedFamily == 'DESTROYER' or selectedFamily == 'TESTUDON'))
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
    confirmOpen = true
    ApplyVisibility()
end)
Controls.ConfirmYesButton:RegisterCallback(Mouse.eLClick, function()
    local _, playerID = ActiveAzul()
    confirmOpen = false
    ApplyVisibility()
    if confirmUnitID >= 0 then LuaEvents.Azul_SelfDestruct(playerID, confirmUnitID) end
    confirmUnitID = -1
end)
Controls.ConfirmNoButton:RegisterCallback(Mouse.eLClick, function()
    confirmUnitID = -1
    confirmOpen = false
    ApplyVisibility()
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
    if not hudSuppressed and uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE then
        if confirmOpen then confirmOpen = false; confirmUnitID = -1; ApplyVisibility(); return true end
        if selectorOpen then CloseSelector(); return true end
        if panelOpen then SetPanelOpen(false); return true end
    end
    return false
end)

LuaEvents.Azul_PlayerShipSelectionAvailable.Add(function(playerID)
    if playerID == Game.GetActivePlayer() then
        if hudSuppressed then pendingPlayerShipSelection = true; return end
        SetPanelOpen(true)
        Refresh()
        OpenSelector('PLAYER')
    end
end)
LuaEvents.Azul_StateChanged.Add(function(playerID)
    if playerID == Game.GetActivePlayer() then Refresh() end
end)
LuaEvents.Azul_CommsMessage.Add(function(playerID, message)
    local player = ActiveAzul()
    if player == nil or playerID ~= Game.GetActivePlayer() or type(message) ~= 'string' then return end
    if commsEntries[1] ~= nil and commsEntries[1].text == message then return end
    table.insert(commsEntries, 1, {text = message, age = 0})
    if #commsEntries > #commsLabels then table.remove(commsEntries) end
    commsTextDirty = true
    RefreshComms()
    StartCommsAnimation()
end)

-- Only named major screens suppress the HUD. Other popups (including ones
-- without a balanced Processed event) must never strand Fleet Systems hidden.
local majorPopupTypes = {}
local function AddMajorPopup(name)
    local popupType = ButtonPopupTypes and ButtonPopupTypes[name]
    if popupType ~= nil then majorPopupTypes[popupType] = true end
end
AddMajorPopup('BUTTONPOPUP_TECH_TREE')
AddMajorPopup('BUTTONPOPUP_CHOOSEPOLICY')
AddMajorPopup('BUTTONPOPUP_CHOOSE_IDEOLOGY')
AddMajorPopup('BUTTONPOPUP_CULTURE_OVERVIEW')
AddMajorPopup('BUTTONPOPUP_RELIGION_OVERVIEW')
AddMajorPopup('BUTTONPOPUP_ESPIONAGE_OVERVIEW')
AddMajorPopup('BUTTONPOPUP_MILITARY_OVERVIEW')
AddMajorPopup('BUTTONPOPUP_ECONOMIC_OVERVIEW')
AddMajorPopup('BUTTONPOPUP_TRADE_ROUTE_OVERVIEW')
AddMajorPopup('BUTTONPOPUP_VICTORY_INFO')

local function HasMajorPopupOpen()
    for _ in pairs(majorPopupOpen) do return true end
    return false
end

-- UI state is transient; never persist it into a game save. A new turn or
-- active-player switch is a reliable recovery point for missed close events.
local function ResetScreenState()
    cityViewOpen = UI.IsCityScreenUp ~= nil and UI.IsCityScreenUp() or false
    leaderViewOpen = UI.GetLeaderHeadRootUp ~= nil and UI.GetLeaderHeadRootUp() or false
    interfaceModeHidden = UI.GetInterfaceMode ~= nil and IsModalInterfaceMode(UI.GetInterfaceMode()) or false
    bulkUIHidden = false
    majorPopupOpen = {}
end

-- Screen-transition events change suppression. Game-data dirty events below
-- refresh values, but never scan UI contexts or reapply visibility per frame.
local function UpdateScreenVisibility()
    local hidden = cityViewOpen or leaderViewOpen or bulkUIHidden or interfaceModeHidden or HasMajorPopupOpen()
    if hidden == hudSuppressed then return end
    hudSuppressed = hidden
    if hidden then
        -- Target highlights and self-destruct confirmations must not survive
        -- a modal transition; keep the main dashboard's open/closed state.
        if selectorOpen then CloseSelector() end
        confirmOpen = false
        confirmUnitID = -1
        ApplyVisibility()
        return
    end
    ApplyVisibility()
    Refresh()
    if pendingPlayerShipSelection then
        pendingPlayerShipSelection = false
        SetPanelOpen(true)
        OpenSelector('PLAYER')
    end
end

if Events.SerialEventEnterCityScreen ~= nil then
    Events.SerialEventEnterCityScreen.Add(function()
        cityViewOpen = true
        UpdateScreenVisibility()
    end)
end
if Events.SerialEventExitCityScreen ~= nil then
    Events.SerialEventExitCityScreen.Add(function()
        cityViewOpen = false
        UpdateScreenVisibility()
    end)
end
if Events.SerialEventGameMessagePopupShown ~= nil then
    Events.SerialEventGameMessagePopupShown.Add(function(info)
        local popupType = info and info.Type
        if not majorPopupTypes[popupType] or majorPopupOpen[popupType] then return end
        majorPopupOpen[popupType] = true
        UpdateScreenVisibility()
    end)
end
if Events.SerialEventGameMessagePopupProcessed ~= nil then
    Events.SerialEventGameMessagePopupProcessed.Add(function(popupType)
        if not majorPopupOpen[popupType] then return end
        majorPopupOpen[popupType] = nil
        UpdateScreenVisibility()
    end)
end
if Events.SystemUpdateUI ~= nil and SystemUpdateUIType ~= nil then
    Events.SystemUpdateUI.Add(function(updateType)
        if updateType == SystemUpdateUIType.BulkHideUI then bulkUIHidden = true
        elseif updateType == SystemUpdateUIType.BulkShowUI then bulkUIHidden = false
        else return end
        UpdateScreenVisibility()
    end)
end
if Events.AILeaderMessage ~= nil then
    Events.AILeaderMessage.Add(function()
        leaderViewOpen = true
        UpdateScreenVisibility()
    end)
end
if Events.LeavingLeaderViewMode ~= nil then
    Events.LeavingLeaderViewMode.Add(function()
        leaderViewOpen = false
        UpdateScreenVisibility()
    end)
end
if Events.InterfaceModeChanged ~= nil then
    Events.InterfaceModeChanged.Add(function(_, newMode)
        interfaceModeHidden = IsModalInterfaceMode(newMode)
        UpdateScreenVisibility()
    end)
end
if Events.SerialEventGameDataDirty ~= nil then Events.SerialEventGameDataDirty.Add(Refresh) end
if Events.SerialEventUnitInfoDirty ~= nil then Events.SerialEventUnitInfoDirty.Add(Refresh) end
if Events.UnitSelectionChanged ~= nil then Events.UnitSelectionChanged.Add(Refresh) end
if Events.ActivePlayerTurnStart ~= nil then
    Events.ActivePlayerTurnStart.Add(function()
        ResetScreenState()
        UpdateScreenVisibility()
        Refresh()
    end)
end
Events.GameplaySetActivePlayer.Add(function()
    ResetScreenState()
    commsEntries = {}
    commsTextDirty = true
    if commsAnimating then ContextPtr:ClearUpdate(); commsAnimating = false end
    pendingPlayerShipSelection = false
    SetPanelOpen(false)
    confirmOpen = false
    confirmUnitID = -1
    UpdateScreenVisibility()
    ApplyVisibility()
    Refresh()
end)

ApplyVisibility()
Refresh()
