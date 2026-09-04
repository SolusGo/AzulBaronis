-- Azul Baronis -- gameplay controller
-- Community Patch 5.3.2 supplies CanMoveInto, UnitCanRangeAttackAt,
-- CityCanMaintain and the pre/post-battle events used below.

local SAVE = Modding.OpenSaveData()
local CIV_AZUL = GameInfoTypes.CIVILIZATION_AZUL_BARONIS
local BUILDING_CORE = GameInfoTypes.BUILDING_AZUL_MOTHERSHIP_CORE
local BUILDING_PALACE = GameInfoTypes.BUILDING_PALACE
local PROCESS_CANNON = GameInfoTypes.PROCESS_AZUL_CHARGE_MAIN_CANNON
local PROCESS_TURRET = GameInfoTypes.PROCESS_AZUL_CONSTRUCT_TURRET
local PROMO_PLAYER = GameInfoTypes.PROMOTION_AZUL_PLAYER_CONTROLLED
local PROMO_HOVER = GameInfoTypes.PROMOTION_AZUL_HOVER
local PROMO_OCEAN = GameInfoTypes.PROMOTION_AZUL_OCEAN_ACCESS
local PROMO_MOUNTAIN = GameInfoTypes.PROMOTION_AZUL_MOUNTAIN_ACCESS
local PROMO_DOG_DEFENSE = GameInfoTypes.PROMOTION_AZUL_DOGFIGHTER_DEFENSE
local PROMO_DOG_EVADE = GameInfoTypes.PROMOTION_AZUL_DOGFIGHTER_EVADE
local PROMO_TESTUDON_REDUCTION = GameInfoTypes.PROMOTION_AZUL_TESTUDON_RANGED_REDUCTION
local PROMO_HOMING = GameInfoTypes.PROMOTION_AZUL_HOMING_BOMB_ACTIVE
local TECH_ASTRONOMY = GameInfoTypes.TECH_ASTRONOMY
local TECH_FLIGHT = GameInfoTypes.TECH_FLIGHT
local TERRAIN_OCEAN = GameInfoTypes.TERRAIN_OCEAN
local DOMAIN_AIR = GameInfoTypes.DOMAIN_AIR
local UNIT_GREAT_ADMIRAL = GameInfoTypes.UNIT_GREAT_ADMIRAL
local MOVE_DENOMINATOR = GameDefines.MOVE_DENOMINATOR or 60

local ERA_ANCIENT = GameInfoTypes.ERA_ANCIENT or 0
local ERA_CLASSICAL = GameInfoTypes.ERA_CLASSICAL or 1
local ERA_MEDIEVAL = GameInfoTypes.ERA_MEDIEVAL or 2
local ERA_RENAISSANCE = GameInfoTypes.ERA_RENAISSANCE or 3
local ERA_INDUSTRIAL = GameInfoTypes.ERA_INDUSTRIAL or 4
local ERA_MODERN = GameInfoTypes.ERA_MODERN or 5
local ERA_ATOMIC = GameInfoTypes.ERA_ATOMIC or 6
local ERA_INFORMATION = GameInfoTypes.ERA_POSTMODERN or GameInfoTypes.ERA_INFORMATION or 7

local FIGHTERS = {
    [0] = GameInfoTypes.UNIT_AZUL_FIGHTER_ANCIENT,
    [1] = GameInfoTypes.UNIT_AZUL_FIGHTER_CLASSICAL,
    [2] = GameInfoTypes.UNIT_AZUL_FIGHTER_MEDIEVAL,
    [3] = GameInfoTypes.UNIT_AZUL_FIGHTER_RENAISSANCE,
    [4] = GameInfoTypes.UNIT_AZUL_FIGHTER_INDUSTRIAL,
    [5] = GameInfoTypes.UNIT_AZUL_FIGHTER_MODERN,
    [6] = GameInfoTypes.UNIT_AZUL_FIGHTER_ATOMIC,
    [7] = GameInfoTypes.UNIT_AZUL_FIGHTER_INFORMATION
}
local DESTROYERS = {
    [3] = GameInfoTypes.UNIT_AZUL_DESTROYER_RENAISSANCE,
    [4] = GameInfoTypes.UNIT_AZUL_DESTROYER_INDUSTRIAL,
    [5] = GameInfoTypes.UNIT_AZUL_DESTROYER_MODERN,
    [6] = GameInfoTypes.UNIT_AZUL_DESTROYER_ATOMIC,
    [7] = GameInfoTypes.UNIT_AZUL_DESTROYER_INFORMATION
}
local TESTUDONS = {
    [4] = GameInfoTypes.UNIT_AZUL_TESTUDON_INDUSTRIAL,
    [5] = GameInfoTypes.UNIT_AZUL_TESTUDON_MODERN,
    [6] = GameInfoTypes.UNIT_AZUL_TESTUDON_ATOMIC,
    [7] = GameInfoTypes.UNIT_AZUL_TESTUDON_INFORMATION
}
local TURRETS = {
    [0] = GameInfoTypes.UNIT_AZUL_TURRET_ANCIENT,
    [1] = GameInfoTypes.UNIT_AZUL_TURRET_CLASSICAL,
    [2] = GameInfoTypes.UNIT_AZUL_TURRET_MEDIEVAL,
    [3] = GameInfoTypes.UNIT_AZUL_TURRET_RENAISSANCE,
    [4] = GameInfoTypes.UNIT_AZUL_TURRET_INDUSTRIAL,
    [5] = GameInfoTypes.UNIT_AZUL_TURRET_MODERN,
    [6] = GameInfoTypes.UNIT_AZUL_TURRET_ATOMIC,
    [7] = GameInfoTypes.UNIT_AZUL_TURRET_INFORMATION
}
local UNIT_COMMANDER = GameInfoTypes.UNIT_AZUL_FLEET_COMMANDER

local FAMILY_BY_TYPE = {}
local function RegisterFamily(family, rows)
    for _, unitType in pairs(rows) do
        if unitType ~= nil then FAMILY_BY_TYPE[unitType] = family end
    end
end
RegisterFamily('FIGHTER', FIGHTERS)
RegisterFamily('DESTROYER', DESTROYERS)
RegisterFamily('TESTUDON', TESTUDONS)
RegisterFamily('TURRET', TURRETS)
if UNIT_COMMANDER ~= nil then FAMILY_BY_TYPE[UNIT_COMMANDER] = 'COMMANDER' end

local BEAM_COMP = {}
for promotion in GameInfo.UnitPromotions() do
    local step = tonumber(string.match(promotion.Type or '', '^PROMOTION_AZUL_BEAM_COMP_(%d+)$'))
    if step ~= nil then BEAM_COMP[#BEAM_COMP + 1] = {step, promotion.ID} end
end
table.sort(BEAM_COMP, function(a, b) return a[1] < b[1] end)
local TEMP_PROMOS = {}
TEMP_PROMOS[PROMO_DOG_DEFENSE or -1] = true
TEMP_PROMOS[PROMO_DOG_EVADE or -2] = true
TEMP_PROMOS[PROMO_TESTUDON_REDUCTION or -3] = true
TEMP_PROMOS[PROMO_HOMING or -4] = true
for _, row in ipairs(BEAM_COMP) do
    if row[2] ~= nil then TEMP_PROMOS[row[2]] = true end
end

local CANNON_BASE = {220, 300, 420, 600, 820, 1100, 1450, 1900}
local TURRET_BASE = {120, 160, 220, 300, 400, 540, 720, 950}
local currentBattle = nil
local swappingHull = false
local homingAttack = nil

local function SavedNumber(key, fallback)
    local value = SAVE.GetValue(key)
    if value == nil then return fallback end
    return tonumber(value) or fallback
end

local function SetNumber(key, value)
    SAVE.SetValue(key, math.floor(tonumber(value) or 0))
end

local function PKey(playerID, suffix)
    return 'AZUL_' .. tostring(suffix) .. '_' .. tostring(playerID)
end

local function UKey(prefix, playerID, unitID)
    return 'AZUL_' .. tostring(prefix) .. '_' .. tostring(playerID) .. '_' .. tostring(unitID)
end

local function IsAzul(player)
    return player ~= nil and player:IsAlive() and CIV_AZUL ~= nil
        and player:GetCivilizationType() == CIV_AZUL
end

local function Notify(playerID, text)
    local player = Players[playerID]
    if player ~= nil and player:IsHuman() and playerID == Game.GetActivePlayer() then
        Events.GameplayAlertMessage(text)
    end
end

local function EraIndex(player)
    if player == nil then return 0 end
    local era = tonumber(player:GetCurrentEra()) or 0
    if era <= ERA_ANCIENT then return 0 end
    if era == ERA_CLASSICAL then return 1 end
    if era == ERA_MEDIEVAL then return 2 end
    if era == ERA_RENAISSANCE then return 3 end
    if era == ERA_INDUSTRIAL then return 4 end
    if era == ERA_MODERN then return 5 end
    if era == ERA_ATOMIC then return 6 end
    return 7
end

local function EraUnit(family, era)
    era = math.max(0, math.min(7, era or 0))
    if family == 'FIGHTER' then return FIGHTERS[era] end
    if family == 'DESTROYER' then return DESTROYERS[era] end
    if family == 'TESTUDON' then return TESTUDONS[era] end
    if family == 'TURRET' then return TURRETS[era] end
    if family == 'COMMANDER' then return UNIT_COMMANDER end
    return nil
end

local function TestudonCap(player)
    local era = EraIndex(player)
    if era < 4 then return 0 end
    return math.min(4, era - 3)
end

local function CountFamily(player, family)
    local count = 0
    for unit in player:Units() do
        if FAMILY_BY_TYPE[unit:GetUnitType()] == family then count = count + 1 end
    end
    return count
end

local function IsPlayerEligible(unit)
    if unit == nil then return false end
    local family = FAMILY_BY_TYPE[unit:GetUnitType()]
    return family == 'FIGHTER' or family == 'DESTROYER'
end

local function PlayerShip(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return nil end
    local unitID = SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1)
    if unitID < 0 then return nil end
    local unit = player:GetUnitByID(unitID)
    if not IsPlayerEligible(unit) then return nil end
    return unit
end

local function SelectPlayerShip(playerID, unitID)
    local player = Players[playerID]
    local chosen = player and player:GetUnitByID(unitID) or nil
    if not IsAzul(player) or not IsPlayerEligible(chosen) then return false end
    local current = PlayerShip(playerID)
    if current ~= nil and current:GetID() ~= unitID then return false end
    for unit in player:Units() do
        if IsPlayerEligible(unit) and PROMO_PLAYER ~= nil then
            unit:SetHasPromotion(PROMO_PLAYER, unit:GetID() == unitID)
        end
    end
    SetNumber(PKey(playerID, 'PLAYER_SHIP'), unitID)
    SetNumber(PKey(playerID, 'PLAYER_EVER'), 1)
    SetNumber(PKey(playerID, 'PLAYER_PENDING'), 0)
    Notify(playerID, '★ ' .. Locale.ConvertTextKey(chosen:GetNameKey()) .. ' is now Player Controlled.')
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function ClearPlayerShip(playerID, shouldPrompt)
    local player = Players[playerID]
    if player ~= nil and PROMO_PLAYER ~= nil then
        for unit in player:Units() do
            if unit:IsHasPromotion(PROMO_PLAYER) then unit:SetHasPromotion(PROMO_PLAYER, false) end
        end
    end
    SetNumber(PKey(playerID, 'PLAYER_SHIP'), -1)
    if shouldPrompt then SetNumber(PKey(playerID, 'PLAYER_PENDING'), 1) end
    LuaEvents.Azul_StateChanged(playerID)
end

local function HasTech(player, techID)
    if player == nil or techID == nil then return false end
    local team = Teams[player:GetTeam()]
    return team ~= nil and team:IsHasTech(techID)
end

local function ApplyTraversal(player, unit)
    if unit == nil or FAMILY_BY_TYPE[unit:GetUnitType()] == nil then return end
    if PROMO_HOVER ~= nil and not unit:IsHasPromotion(PROMO_HOVER) then
        unit:SetHasPromotion(PROMO_HOVER, true)
    end
    if PROMO_OCEAN ~= nil then unit:SetHasPromotion(PROMO_OCEAN, HasTech(player, TECH_ASTRONOMY)) end
    if PROMO_MOUNTAIN ~= nil then unit:SetHasPromotion(PROMO_MOUNTAIN, HasTech(player, TECH_FLIGHT)) end
end

local function Requirement(baseTable, player)
    local base = baseTable[EraIndex(player) + 1] or baseTable[#baseTable]
    local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
    local percent = speed and tonumber(speed.TrainPercent) or 100
    return math.max(1, math.floor(base * percent / 100 + 0.5))
end

local function OriginalCoordinates(playerID)
    local x = SavedNumber(PKey(playerID, 'MOTH_X'), -1)
    local y = SavedNumber(PKey(playerID, 'MOTH_Y'), -1)
    return x, y
end

local function OriginalCity(playerID, requireControl)
    local x, y = OriginalCoordinates(playerID)
    if x < 0 or y < 0 then return nil end
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity() or nil
    if city == nil then return nil end
    if requireControl and city:GetOwner() ~= playerID then return nil end
    return city
end

local function RecordOriginalMothership(playerID)
    local player = Players[playerID]
    if not IsAzul(player) or SavedNumber(PKey(playerID, 'MOTH_X'), -1) >= 0 then return end
    local capital = player:GetCapitalCity()
    if capital == nil then return end
    SetNumber(PKey(playerID, 'MOTH_X'), capital:GetX())
    SetNumber(PKey(playerID, 'MOTH_Y'), capital:GetY())
    SetNumber(PKey(playerID, 'MOTH_ACTIVE'), 1)
    SetNumber(PKey(playerID, 'BATTERY'), 0)
    SetNumber(PKey(playerID, 'TURRET_PROGRESS'), 0)
    SetNumber(PKey(playerID, 'TURRET_READY'), 0)
end

local function SetBuilding(city, buildingID, count)
    if city == nil or buildingID == nil then return end
    if (city:GetNumFreeBuilding(buildingID) or 0) ~= count then
        city:SetNumFreeBuilding(buildingID, count)
    end
    if city:GetNumRealBuilding(buildingID) > 0 and count == 0 then
        city:SetNumRealBuilding(buildingID, 0)
    end
end

local function NormalizePalaces(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    local mothership = OriginalCity(playerID, true)
    for city in player:Cities() do
        local isMothership = mothership ~= nil and city:GetID() == mothership:GetID()
        SetBuilding(city, BUILDING_CORE, isMothership and 1 or 0)
        SetBuilding(city, BUILDING_PALACE, (not isMothership and city:IsCapital()) and 1 or 0)
    end
end

local function DestroyTurrets(player)
    local dead = {}
    for unit in player:Units() do
        if FAMILY_BY_TYPE[unit:GetUnitType()] == 'TURRET' then dead[#dead + 1] = unit end
    end
    for _, unit in ipairs(dead) do unit:Kill(true, -1) end
end

local function UpdateMothershipControl(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    RecordOriginalMothership(playerID)
    local controlled = OriginalCity(playerID, true) ~= nil
    local wasActive = SavedNumber(PKey(playerID, 'MOTH_ACTIVE'), 0) == 1
    if wasActive and not controlled then
        SetNumber(PKey(playerID, 'MOTH_ACTIVE'), 0)
        SetNumber(PKey(playerID, 'BATTERY'), 0)
        SetNumber(PKey(playerID, 'TURRET_PROGRESS'), 0)
        SetNumber(PKey(playerID, 'TURRET_READY'), 0)
        DestroyTurrets(player)
        Notify(playerID, '[COLOR_WARNING_TEXT]MOTHERSHIP LOST[ENDCOLOR] — weapon systems and defensive turrets are offline.')
    elseif not wasActive and controlled then
        SetNumber(PKey(playerID, 'MOTH_ACTIVE'), 1)
        SetNumber(PKey(playerID, 'BATTERY'), 0)
        SetNumber(PKey(playerID, 'TURRET_PROGRESS'), 0)
        SetNumber(PKey(playerID, 'TURRET_READY'), 0)
        Notify(playerID, '[COLOR_POSITIVE_TEXT]MOTHERSHIP RESTORED[ENDCOLOR] — batteries begin empty.')
    end
    if not controlled then
        -- The captured city is no longer in Azul's city iterator, so remove the
        -- unique Palace replacement explicitly before normalizing survivors.
        SetBuilding(OriginalCity(playerID, false), BUILDING_CORE, 0)
    end
    NormalizePalaces(playerID)
end

local function AddMothershipSight(playerID)
    -- Exactly the distance-three ring extends the ordinary city sight by one.
    -- Visibility-count operations are guarded because older non-CP DLLs omit
    -- the Lua binding; the building remains fully functional without it.
    local city = OriginalCity(playerID, true)
    if city == nil or SavedNumber(PKey(playerID, 'SIGHT_ACTIVE'), 0) == 1 then return end
    local teamID = Players[playerID]:GetTeam()
    local changed = false
    for dx = -3, 3 do
        for dy = -3, 3 do
            local plot = Map.PlotXYWithRangeCheck(city:GetX(), city:GetY(), dx, dy, 3)
            if plot ~= nil and Map.PlotDistance(city:GetX(), city:GetY(), plot:GetX(), plot:GetY()) == 3 then
                local ok = pcall(function() plot:ChangeVisibilityCount(teamID, 1, -1, false, false) end)
                changed = changed or ok
            end
        end
    end
    if changed then SetNumber(PKey(playerID, 'SIGHT_ACTIVE'), 1) end
end

local function RemoveMothershipSight(playerID)
    if SavedNumber(PKey(playerID, 'SIGHT_ACTIVE'), 0) ~= 1 then return end
    local x, y = OriginalCoordinates(playerID)
    local player = Players[playerID]
    if x >= 0 and y >= 0 and player ~= nil then
        local teamID = player:GetTeam()
        for dx = -3, 3 do
            for dy = -3, 3 do
                local plot = Map.PlotXYWithRangeCheck(x, y, dx, dy, 3)
                if plot ~= nil and Map.PlotDistance(x, y, plot:GetX(), plot:GetY()) == 3 then
                    pcall(function() plot:ChangeVisibilityCount(teamID, -1, -1, false, false) end)
                end
            end
        end
    end
    SetNumber(PKey(playerID, 'SIGHT_ACTIVE'), 0)
end

local function SyncMothershipSight(playerID)
    if OriginalCity(playerID, true) ~= nil then AddMothershipSight(playerID)
    else RemoveMothershipSight(playerID) end
end

local function ProductionPerTurn(city)
    local ok, value = pcall(function()
        return city:GetCurrentProductionDifferenceTimes100(false, false) / 100
    end)
    if ok and value ~= nil then return math.max(0, math.floor(value + 0.5)) end
    return math.max(0, math.floor(city:GetYieldRate(YieldTypes.YIELD_PRODUCTION)))
end

local function ChargeMothership(playerID)
    local player = Players[playerID]
    local city = OriginalCity(playerID, true)
    if not IsAzul(player) or city == nil then return end
    local process = city:GetProductionProcess()
    local production = ProductionPerTurn(city)
    if process == PROCESS_CANNON then
        local required = Requirement(CANNON_BASE, player)
        local stored = SavedNumber(PKey(playerID, 'BATTERY'), 0)
        SetNumber(PKey(playerID, 'BATTERY'), math.min(required, stored + production))
    elseif process == PROCESS_TURRET and SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 0 then
        local required = Requirement(TURRET_BASE, player)
        local stored = SavedNumber(PKey(playerID, 'TURRET_PROGRESS'), 0)
        local updated = math.min(required, stored + production)
        SetNumber(PKey(playerID, 'TURRET_PROGRESS'), updated)
        if updated >= required then
            SetNumber(PKey(playerID, 'TURRET_READY'), 1)
            Notify(playerID, '[COLOR_POSITIVE_TEXT]TURRET READY[ENDCOLOR] — open Fleet Systems to deploy it.')
        end
    end
end

local function CopyPromotions(unit)
    local promotions = {}
    for promotion in GameInfo.UnitPromotions() do
        if not TEMP_PROMOS[promotion.ID] and unit:IsHasPromotion(promotion.ID) then
            promotions[#promotions + 1] = promotion.ID
        end
    end
    return promotions
end

local function SwapHull(playerID, unit, targetType)
    if unit == nil or targetType == nil or unit:GetUnitType() == targetType then return unit end
    local player = Players[playerID]
    local oldID = unit:GetID()
    local x, y = unit:GetX(), unit:GetY()
    local damage = unit:GetDamage()
    local experience = unit:GetExperience()
    local level = unit:GetLevel()
    local moves = unit:MovesLeft()
    local madeAttack = unit:IsOutOfAttacks()
    local name = unit:HasName() and unit:GetNameNoDesc() or nil
    local promotions = CopyPromotions(unit)
    local afterburner = SavedNumber(UKey('AFTERBURNER', playerID, oldID), 0)
    local bomb = SavedNumber(UKey('HOMING', playerID, oldID), 0)
    local wasPlayer = SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == oldID

    swappingHull = true
    local newUnit = player:InitUnit(targetType, x, y, unit:GetUnitAIType(), DirectionTypes.NO_DIRECTION)
    if newUnit ~= nil then
        for _, promotionID in ipairs(promotions) do newUnit:SetHasPromotion(promotionID, true) end
        if name ~= nil and name ~= '' then newUnit:SetName(name) end
        newUnit:SetDamage(math.min(damage, newUnit:GetMaxHitPoints() - 1), -1)
        newUnit:SetExperience(experience)
        newUnit:SetLevel(level)
        newUnit:SetMoves(math.max(0, moves))
        newUnit:SetMadeAttack(madeAttack)
        ApplyTraversal(player, newUnit)
        SetNumber(UKey('AFTERBURNER', playerID, newUnit:GetID()), afterburner)
        SetNumber(UKey('HOMING', playerID, newUnit:GetID()), bomb)
        SetNumber(UKey('AFTERBURNER', playerID, oldID), 0)
        SetNumber(UKey('HOMING', playerID, oldID), 0)
        if wasPlayer then
            SetNumber(PKey(playerID, 'PLAYER_SHIP'), newUnit:GetID())
            if PROMO_PLAYER ~= nil then newUnit:SetHasPromotion(PROMO_PLAYER, true) end
        end
        unit:Kill(true, -1)
    end
    swappingHull = false
    return newUnit or unit
end

local function ReconcileProduction(player, city)
    local oldType = city:GetProductionUnit()
    local family = FAMILY_BY_TYPE[oldType]
    if family == nil or family == 'TURRET' or family == 'COMMANDER' then return end
    local targetType = EraUnit(family, EraIndex(player))
    if targetType == nil or targetType == oldType then return end
    local stored = city:GetUnitProduction(oldType)
    local ok = pcall(function()
        city:SetUnitProduction(targetType, stored)
        city:PushOrder(OrderTypes.ORDER_TRAIN, targetType, -1, false, true, false)
        city:SetUnitProduction(oldType, 0)
    end)
    if not ok then
        -- The city may be in a network/UI transaction. Its old progress remains
        -- stored by Civ V and the next reconciliation attempt is safe.
        return
    end
end

local function ReconcileEra(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    local era = EraIndex(player)
    local replacements = {}
    for unit in player:Units() do
        local family = FAMILY_BY_TYPE[unit:GetUnitType()]
        if family ~= nil and family ~= 'COMMANDER' then
            local target = EraUnit(family, era)
            if target ~= nil and target ~= unit:GetUnitType() then
                replacements[#replacements + 1] = {unit = unit, target = target}
            end
        end
    end
    for _, row in ipairs(replacements) do SwapHull(playerID, row.unit, row.target) end
    for city in player:Cities() do ReconcileProduction(player, city) end
    SetNumber(PKey(playerID, 'ERA'), era)
    LuaEvents.Azul_StateChanged(playerID)
end

local function DecrementCooldowns(playerID)
    local player = Players[playerID]
    for unit in player:Units() do
        local family = FAMILY_BY_TYPE[unit:GetUnitType()]
        if family == 'FIGHTER' or family == 'DESTROYER' then
            local afterKey = UKey('AFTERBURNER', playerID, unit:GetID())
            local after = SavedNumber(afterKey, 0)
            if after > 0 then SetNumber(afterKey, after - 1) end
        end
        if family == 'DESTROYER' then
            local bombKey = UKey('HOMING', playerID, unit:GetID())
            local bomb = SavedNumber(bombKey, 0)
            if bomb > 0 then SetNumber(bombKey, bomb - 1) end
        end
    end
end

local function ValidCannonTarget(player, city, unit)
    if unit == nil or unit:IsDead() or not unit:IsCombatUnit() then return false end
    if unit:GetDomainType() == DOMAIN_AIR then return false end
    local targetPlayer = Players[unit:GetOwner()]
    if targetPlayer == nil or not Teams[player:GetTeam()]:IsAtWar(targetPlayer:GetTeam()) then return false end
    if Map.PlotDistance(city:GetX(), city:GetY(), unit:GetX(), unit:GetY()) > 5 then return false end
    local plot = unit:GetPlot()
    return plot ~= nil and plot:IsVisible(player:GetTeam(), false)
end

local function FireMainCannon(playerID, targetOwnerID, targetUnitID)
    local player = Players[playerID]
    local city = OriginalCity(playerID, true)
    local targetPlayer = Players[targetOwnerID]
    local target = targetPlayer and targetPlayer:GetUnitByID(targetUnitID) or nil
    if not IsAzul(player) or city == nil or not ValidCannonTarget(player, city, target) then return false end
    if city:HasPerformedRangedStrikeThisTurn()
        or SavedNumber(PKey(playerID, 'CANNON_FIRED_TURN'), -1) == Game.GetGameTurn() then return false end
    local required = Requirement(CANNON_BASE, player)
    if SavedNumber(PKey(playerID, 'BATTERY'), 0) < required then return false end
    SetNumber(PKey(playerID, 'BATTERY'), 0)
    -- The CP exposes the city's attack flag read-only. Record consumption here;
    -- PrepareBattle nullifies any attempted ordinary city shot later this turn.
    SetNumber(PKey(playerID, 'CANNON_FIRED_TURN'), Game.GetGameTurn())
    local targetName = Locale.ConvertTextKey(target:GetNameKey())
    target:Kill(true, playerID)
    Notify(playerID, '[COLOR_POSITIVE_TEXT]MAIN CANNON FIRED[ENDCOLOR] — ' .. targetName .. ' destroyed.')
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function PlotDefense(plot, defender)
    local defense = 0
    if plot ~= nil then
        local ok, value = pcall(function()
            return plot:DefenseModifier(defender and Players[defender:GetOwner()]:GetTeam() or -1, false, false)
        end)
        if ok and value ~= nil then defense = math.max(0, tonumber(value) or 0) end
    end
    if defender ~= nil then
        local ok, value = pcall(function() return defender:GetFortifyTurns() end)
        if ok and value ~= nil then defense = defense + math.max(0, value) * 20 end
    end
    return defense
end

local function ApplyBeamCompensation(attacker, amount)
    if attacker == nil or amount <= 2 then return nil end
    local bestID, bestDelta = nil, 999
    for _, row in ipairs(BEAM_COMP) do
        local delta = math.abs(row[1] - amount)
        if row[2] ~= nil and delta < bestDelta then bestID, bestDelta = row[2], delta end
    end
    if bestID ~= nil then attacker:SetHasPromotion(bestID, true) end
    return bestID
end

local function RangedStrengthScale(unit)
    if unit == nil then return 1 end
    local base = tonumber(unit:GetBaseRangedCombatStrength()) or 0
    if base <= 0 then return 1 end
    local ok, current = pcall(function()
        return unit:GetMaxRangedCombatStrength(nil, nil, true, true)
    end)
    if not ok or current == nil or current <= 0 then return 1 end
    return current / (base * 100)
end

local function ClearTemporary(unit)
    if unit == nil then return end
    for promotionID, _ in pairs(TEMP_PROMOS) do
        if promotionID >= 0 and unit:IsHasPromotion(promotionID) then unit:SetHasPromotion(promotionID, false) end
    end
end

local function ValidHomingTarget(player, destroyer, target)
    if destroyer == nil or FAMILY_BY_TYPE[destroyer:GetUnitType()] ~= 'DESTROYER' then return false end
    if target == nil or target:IsDead() or not target:IsCombatUnit() or target:GetDomainType() == DOMAIN_AIR then return false end
    local targetPlayer = Players[target:GetOwner()]
    if targetPlayer == nil or not Teams[player:GetTeam()]:IsAtWar(targetPlayer:GetTeam()) then return false end
    return Map.PlotDistance(destroyer:GetX(), destroyer:GetY(), target:GetX(), target:GetY()) <= 3
end

local function FireHomingBomb(playerID, unitID, targetOwnerID, targetUnitID)
    local player = Players[playerID]
    local destroyer = player and player:GetUnitByID(unitID) or nil
    local targetPlayer = Players[targetOwnerID]
    local target = targetPlayer and targetPlayer:GetUnitByID(targetUnitID) or nil
    if not IsAzul(player) or not ValidHomingTarget(player, destroyer, target) then return false end
    if destroyer:IsOutOfAttacks() or SavedNumber(UKey('HOMING', playerID, unitID), 0) > 0 then return false end
    ClearTemporary(destroyer)
    destroyer:SetHasPromotion(PROMO_HOMING, true)
    -- Compensate for all positive tile defense; fortification remains relevant.
    local terrainDefense = PlotDefense(target:GetPlot(), nil)
    local compensation = math.floor(terrainDefense * RangedStrengthScale(destroyer) + 0.5)
    local comp = ApplyBeamCompensation(destroyer, compensation)
    if not destroyer:CanRangeStrikeAt(target:GetX(), target:GetY(), true, false) then
        ClearTemporary(destroyer)
        return false
    end
    homingAttack = {playerID = playerID, unitID = unitID, comp = comp}
    SetNumber(UKey('HOMING', playerID, unitID), 3)
    destroyer:RangeStrike(target:GetX(), target:GetY())
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function IsCityDefeated(city)
    if city == nil then return false end
    return city:GetDamage() >= math.max(0, city:GetMaxHitPoints() - 1)
end

local function CaptureCity(playerID, unitID, x, y)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(unitID) or nil
    local family = unit and FAMILY_BY_TYPE[unit:GetUnitType()] or nil
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity() or nil
    if not IsAzul(player) or (family ~= 'FIGHTER' and family ~= 'DESTROYER' and family ~= 'TESTUDON') then return false end
    if city == nil or not IsCityDefeated(city) then return false end
    if Map.PlotDistance(unit:GetX(), unit:GetY(), x, y) ~= 1 then return false end
    local oldOwner = Players[city:GetOwner()]
    if oldOwner == nil or not Teams[player:GetTeam()]:IsAtWar(oldOwner:GetTeam()) then return false end
    local cityName = city:GetName()
    local acquired = pcall(function() player:AcquireCity(city, true, false) end)
    if not acquired then return false end
    unit:SetMadeAttack(true)
    unit:FinishMoves()
    Notify(playerID, '[COLOR_POSITIVE_TEXT]' .. cityName .. ' captured by fleet action.[ENDCOLOR]')
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function LegalTurretPlot(player, city, plot)
    if plot == nil or city == nil or plot:IsCity() or plot:GetNumUnits() > 0 then return false end
    if Map.PlotDistance(city:GetX(), city:GetY(), plot:GetX(), plot:GetY()) > 3 then return false end
    if plot:GetTerrainType() == TERRAIN_OCEAN and not HasTech(player, TECH_ASTRONOMY) then return false end
    if plot:IsMountain() and not HasTech(player, TECH_FLIGHT) then return false end
    if plot:IsImpassable() and not plot:IsMountain() then return false end
    local owner = plot:GetOwner()
    if owner >= 0 and owner ~= player:GetID() then
        local ownerPlayer = Players[owner]
        if ownerPlayer == nil or not Teams[player:GetTeam()]:IsAtWar(ownerPlayer:GetTeam()) then return false end
    end
    return true
end

local function DeployTurret(playerID, x, y)
    local player = Players[playerID]
    local city = OriginalCity(playerID, true)
    local plot = Map.GetPlot(x, y)
    if not IsAzul(player) or city == nil or not LegalTurretPlot(player, city, plot) then return false end
    if SavedNumber(PKey(playerID, 'TURRET_READY'), 0) ~= 1 or CountFamily(player, 'TURRET') >= 4 then return false end
    local unitType = EraUnit('TURRET', EraIndex(player))
    local turret = player:InitUnit(unitType, x, y, UnitAITypes.UNITAI_RANGED, DirectionTypes.NO_DIRECTION)
    if turret == nil then return false end
    turret:SetMoves(0)
    ApplyTraversal(player, turret)
    SetNumber(PKey(playerID, 'TURRET_READY'), 0)
    SetNumber(PKey(playerID, 'TURRET_PROGRESS'), 0)
    Notify(playerID, '[COLOR_POSITIVE_TEXT]DEFENSIVE TURRET DEPLOYED[ENDCOLOR]')
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function SetMothershipProcess(playerID, processID)
    local player = Players[playerID]
    local city = OriginalCity(playerID, true)
    if not IsAzul(player) or city == nil or (processID ~= PROCESS_CANNON and processID ~= PROCESS_TURRET) then return false end
    if processID == PROCESS_TURRET and SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 1 then return false end
    if city:GetProductionProcess() == processID then return true end
    city:PushOrder(OrderTypes.ORDER_MAINTAIN, processID, -1, false, true, false)
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function UseAfterburner(playerID, unitID)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(unitID) or nil
    if not IsAzul(player) or PlayerShip(playerID) ~= unit or unit:IsOutOfAttacks() then return false end
    local key = UKey('AFTERBURNER', playerID, unitID)
    if SavedNumber(key, 0) > 0 then return false end
    local family = FAMILY_BY_TYPE[unit:GetUnitType()]
    local bonus = family == 'FIGHTER' and 2 or (family == 'DESTROYER' and 1 or 0)
    if bonus <= 0 then return false end
    unit:SetMadeAttack(true)
    unit:ChangeMoves(bonus * MOVE_DENOMINATOR)
    SetNumber(key, 3)
    Notify(playerID, 'Afterburner engaged: +' .. tostring(bonus) .. ' Movement; attack consumed.')
    LuaEvents.Azul_StateChanged(playerID)
    return true
end

local function SelfDestruct(playerID, unitID)
    local unit = PlayerShip(playerID)
    if unit == nil or unit:GetID() ~= unitID then return false end
    unit:Kill(true, -1)
    return true
end

local function UnitTypeAllowed(player, unitType)
    local info = GameInfo.Units[unitType]
    if info == nil then return false end
    local family = FAMILY_BY_TYPE[unitType]
    if family == 'FIGHTER' or family == 'DESTROYER' or family == 'TESTUDON' then
        if EraUnit(family, EraIndex(player)) ~= unitType then return false end
        if family == 'TESTUDON' and CountFamily(player, 'TESTUDON') >= TestudonCap(player) then return false end
        local fleet = CountFamily(player, 'FIGHTER') + CountFamily(player, 'DESTROYER')
        if fleet >= 4 and family == 'FIGHTER' and EraIndex(player) >= 3
            and CountFamily(player, 'FIGHTER') / math.max(1, fleet) > 0.66 then return false end
        if fleet >= 4 and family == 'DESTROYER'
            and CountFamily(player, 'DESTROYER') / math.max(1, fleet) > 0.36 then return false end
        return true
    end
    if family == 'TURRET' then return false end
    if family == 'COMMANDER' then return true end

    if info.Class == 'UNITCLASS_GREAT_ADMIRAL' then return false end
    if tonumber(info.Trade) == 1 or tonumber(info.Found) == 1 or (tonumber(info.WorkRate) or 0) > 0 then return true end
    if info.Class == 'UNITCLASS_ARCHAEOLOGIST' or info.Class == 'UNITCLASS_WORKBOAT' then return true end
    if info.Special == 'SPECIALUNIT_PEOPLE' then return true end
    if (tonumber(info.Combat) or 0) > 0 or (tonumber(info.RangedCombat) or 0) > 0
        or tonumber(info.MilitarySupport) == 1 or (tonumber(info.NukeDamageLevel) or -1) >= 0 then return false end
    return true
end

local function CountOtherQueuedFamily(player, family, excludedCityID)
    local count = 0
    for city in player:Cities() do
        if city:GetID() ~= excludedCityID
            and FAMILY_BY_TYPE[city:GetProductionUnit()] == family then
            count = count + 1
        end
    end
    return count
end

local function OnPlayerCanTrain(playerID, unitType)
    local player = Players[playerID]
    if not IsAzul(player) then return true end
    return UnitTypeAllowed(player, unitType)
end

local function OnCityCanTrain(playerID, cityID, unitType)
    if not OnPlayerCanTrain(playerID, unitType) then return false end
    local player = Players[playerID]
    if not IsAzul(player) or FAMILY_BY_TYPE[unitType] ~= 'TESTUDON' then return true end
    return CountFamily(player, 'TESTUDON') + CountOtherQueuedFamily(player, 'TESTUDON', cityID) < TestudonCap(player)
end

local function OnCityCanMaintain(playerID, cityID, processType)
    local player = Players[playerID]
    if processType ~= PROCESS_CANNON and processType ~= PROCESS_TURRET then return true end
    if not IsAzul(player) then return false end
    local city = player:GetCityByID(cityID)
    local mothership = OriginalCity(playerID, true)
    if city == nil or mothership == nil or city:GetID() ~= mothership:GetID() then return false end
    if processType == PROCESS_TURRET and SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 1 then return false end
    return true
end

local function OnCanMoveInto(playerID, unitID, x, y)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(unitID) or nil
    if unit == nil or FAMILY_BY_TYPE[unit:GetUnitType()] == nil then return true end
    local plot = Map.GetPlot(x, y)
    if plot == nil then return false end
    if plot:GetTerrainType() == TERRAIN_OCEAN and not HasTech(player, TECH_ASTRONOMY) then return false end
    if plot:IsMountain() and not HasTech(player, TECH_FLIGHT) then return false end
    return true
end

local function OnUnitCanRangeAttackAt(playerID, unitID)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(unitID) or nil
    if unit ~= nil and FAMILY_BY_TYPE[unit:GetUnitType()] == 'TESTUDON' then
        return unit:MovesLeft() >= unit:MaxMoves()
    end
    return true
end

local function RangedAttacker(participant)
    if participant == nil then return false end
    if participant.isCity then return true end
    local player = Players[participant.playerID]
    local unit = player and player:GetUnitByID(participant.objectID) or nil
    if unit == nil then return false end
    local info = GameInfo.Units[unit:GetUnitType()]
    return info ~= nil and (tonumber(info.RangedCombat) or 0) > 0
end

local function PrepareBattle()
    local battle = currentBattle
    if battle == nil or battle.prepared or battle.attacker == nil or battle.defender == nil then return end
    battle.prepared = true
    local attackerPlayer = Players[battle.attacker.playerID]
    local defenderPlayer = Players[battle.defender.playerID]
    local attacker = not battle.attacker.isCity and attackerPlayer and attackerPlayer:GetUnitByID(battle.attacker.objectID) or nil
    local defender = not battle.defender.isCity and defenderPlayer and defenderPlayer:GetUnitByID(battle.defender.objectID) or nil

    if battle.attacker.isCity and defender ~= nil and IsAzul(attackerPlayer) then
        local mothership = OriginalCity(battle.attacker.playerID, true)
        if mothership ~= nil and mothership:GetID() == battle.attacker.objectID
            and SavedNumber(PKey(battle.attacker.playerID, 'CANNON_FIRED_TURN'), -1) == Game.GetGameTurn() then
            defender:SetHasPromotion(PROMO_DOG_EVADE, true)
            battle.cannonBlockedDefender = defender
            Notify(battle.attacker.playerID, 'The Main Cannon already consumed the Mothership attack this turn.')
        end
    end

    if defender ~= nil and FAMILY_BY_TYPE[defender:GetUnitType()] == 'FIGHTER'
        and defender:MovesLeft() > 0 and RangedAttacker(battle.attacker) then
        defender:SetHasPromotion(PROMO_DOG_DEFENSE, true)
        battle.dogfighter = defender
        if Game.Rand(100, 'Azul Dogfighter Evasion') < 10 then
            defender:SetHasPromotion(PROMO_DOG_EVADE, true)
            battle.evaded = true
        end
    end

    if attacker ~= nil and FAMILY_BY_TYPE[attacker:GetUnitType()] == 'TESTUDON' and defender ~= nil then
        local defense = PlotDefense(defender:GetPlot(), defender)
        -- If defender strength is B*(1+D), ignoring half D is equivalent to
        -- multiplying attack by (1+D)/(1+D/2).
        local compensation = math.floor(RangedStrengthScale(attacker)
            * (100 * defense) / math.max(1, 200 + defense) + 0.5)
        battle.focusedPromotion = ApplyBeamCompensation(attacker, compensation)
        battle.focusedAttacker = attacker
    end

    if defender ~= nil and FAMILY_BY_TYPE[defender:GetUnitType()] == 'TESTUDON' then
        if RangedAttacker(battle.attacker) and PROMO_TESTUDON_REDUCTION ~= nil then
            defender:SetHasPromotion(PROMO_TESTUDON_REDUCTION, true)
            battle.testudonDefense = defender
        end
        battle.testudon = defender
        battle.testudonX = defender:GetX()
        battle.testudonY = defender:GetY()
    end
end

local function OnBattleStarted(battleType, x, y)
    if currentBattle ~= nil then
        ClearTemporary(currentBattle.dogfighter)
        ClearTemporary(currentBattle.focusedAttacker)
        ClearTemporary(currentBattle.testudonDefense)
    end
    currentBattle = {battleType = battleType, x = x, y = y, prepared = false}
end

local function OnBattleJoined(playerID, objectID, role, isCity)
    if currentBattle == nil then currentBattle = {prepared = false} end
    local row = {playerID = playerID, objectID = objectID, isCity = isCity == true}
    if role == 0 then currentBattle.attacker = row
    elseif role == 1 then currentBattle.defender = row end
    PrepareBattle()
end

local function OnBattleFinished()
    local battle = currentBattle
    currentBattle = nil
    if battle == nil then return end
    ClearTemporary(battle.dogfighter)
    ClearTemporary(battle.focusedAttacker)
    ClearTemporary(battle.cannonBlockedDefender)
    ClearTemporary(battle.testudonDefense)
    if battle.evaded and battle.defender ~= nil then
        Notify(battle.defender.playerID, 'Dogfighter evasion: ranged attack avoided.')
    end
    if battle.testudon ~= nil and not battle.testudon:IsDead()
        and (battle.testudon:GetX() ~= battle.testudonX or battle.testudon:GetY() ~= battle.testudonY) then
        -- CP morale retreat is the only normal combat operation that relocates
        -- a surviving defender. Put the super-heavy hull back on its hard vector.
        pcall(function() battle.testudon:SetXY(battle.testudonX, battle.testudonY) end)
    end
    if homingAttack ~= nil then
        local player = Players[homingAttack.playerID]
        local unit = player and player:GetUnitByID(homingAttack.unitID) or nil
        ClearTemporary(unit)
        homingAttack = nil
    end
end

local function OnUnitPrekill(playerID, unitID)
    if swappingHull then return end
    local player = Players[playerID]
    if not IsAzul(player) then return end
    if SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == unitID then
        ClearPlayerShip(playerID, true)
        Notify(playerID, '[COLOR_WARNING_TEXT]PLAYER SHIP DESTROYED[ENDCOLOR] — select a surviving vessel next turn.')
    end
    SetNumber(UKey('AFTERBURNER', playerID, unitID), 0)
    SetNumber(UKey('HOMING', playerID, unitID), 0)
end

local function OnUnitCreated(playerID, unitID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    local unit = player:GetUnitByID(unitID)
    if unit == nil then return end
    if swappingHull then return end
    if UNIT_GREAT_ADMIRAL ~= nil and unit:GetUnitType() == UNIT_GREAT_ADMIRAL and UNIT_COMMANDER ~= nil then
        SwapHull(playerID, unit, UNIT_COMMANDER)
        return
    end
    local family = FAMILY_BY_TYPE[unit:GetUnitType()]
    if family == 'TESTUDON' and CountFamily(player, 'TESTUDON') > TestudonCap(player) then
        Notify(playerID, '[COLOR_WARNING_TEXT]TESTUDON CAP REACHED[ENDCOLOR] — excess hull removed.')
        unit:Kill(true, -1)
        return
    end
    if family ~= nil then ApplyTraversal(player, unit) end
    if IsPlayerEligible(unit) and PlayerShip(playerID) == nil then
        if SavedNumber(PKey(playerID, 'PLAYER_EVER'), 0) == 0 and family == 'FIGHTER' then
            SelectPlayerShip(playerID, unitID)
        else
            SetNumber(PKey(playerID, 'PLAYER_PENDING'), 1)
        end
    end
end

local function BestAITarget(player, city, range, cannon)
    local best, bestScore = nil, -1
    for otherID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local other = Players[otherID]
        if other ~= nil and other:IsAlive() and Teams[player:GetTeam()]:IsAtWar(other:GetTeam()) then
            for unit in other:Units() do
                local valid = cannon and ValidCannonTarget(player, city, unit)
                    or (not cannon and unit:IsCombatUnit() and unit:GetDomainType() ~= DOMAIN_AIR
                        and Map.PlotDistance(city:GetX(), city:GetY(), unit:GetX(), unit:GetY()) <= range)
                if valid then
                    local info = GameInfo.Units[unit:GetUnitType()]
                    local cost = info and math.max(0, tonumber(info.Cost) or 0) or 0
                    local strength = info and ((tonumber(info.Combat) or 0) + (tonumber(info.RangedCombat) or 0)) or 0
                    local score = cost + strength * 3 + unit:GetExperience() * 5 - unit:GetDamage() * 2
                    if Map.PlotDistance(city:GetX(), city:GetY(), unit:GetX(), unit:GetY()) <= 2 then score = score + 100 end
                    if score > bestScore then best, bestScore = unit, score end
                end
            end
        end
    end
    return best
end

local function AITurn(playerID)
    local player = Players[playerID]
    if not IsAzul(player) or player:IsHuman() then return end
    if PlayerShip(playerID) == nil then
        local best = nil
        for unit in player:Units() do
            if IsPlayerEligible(unit) and (best == nil
                or FAMILY_BY_TYPE[unit:GetUnitType()] == 'DESTROYER') then best = unit end
        end
        if best ~= nil then SelectPlayerShip(playerID, best:GetID()) end
    end

    for unit in player:Units() do
        if FAMILY_BY_TYPE[unit:GetUnitType()] == 'DESTROYER' and not unit:IsOutOfAttacks()
            and SavedNumber(UKey('HOMING', playerID, unit:GetID()), 0) == 0 then
            local target = BestAITarget(player, unit, 3, false)
            if target ~= nil then FireHomingBomb(playerID, unit:GetID(), target:GetOwner(), target:GetID()) end
        end
        local family = FAMILY_BY_TYPE[unit:GetUnitType()]
        if family == 'FIGHTER' or family == 'DESTROYER' or family == 'TESTUDON' then
            for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
                local plot = Map.PlotDirection(unit:GetX(), unit:GetY(), direction)
                local city = plot and plot:GetPlotCity() or nil
                if city ~= nil and IsCityDefeated(city) then
                    CaptureCity(playerID, unit:GetID(), city:GetX(), city:GetY())
                    break
                end
            end
        end
    end

    local city = OriginalCity(playerID, true)
    if city == nil then return end
    local required = Requirement(CANNON_BASE, player)
    if SavedNumber(PKey(playerID, 'BATTERY'), 0) >= required then
        local target = BestAITarget(player, city, 5, true)
        if target ~= nil then FireMainCannon(playerID, target:GetOwner(), target:GetID()) end
    end
    if SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 1 and CountFamily(player, 'TURRET') < 4 then
        for dx = -3, 3 do
            local deployed = false
            for dy = -3, 3 do
                local plot = Map.PlotXYWithRangeCheck(city:GetX(), city:GetY(), dx, dy, 3)
                if LegalTurretPlot(player, city, plot) and DeployTurret(playerID, plot:GetX(), plot:GetY()) then
                    deployed = true
                    break
                end
            end
            if deployed then break end
        end
    end
    local atWar = Teams[player:GetTeam()]:GetAtWarCount(true) > 0
    local desiredTurrets = atWar and 4 or 2
    if CountFamily(player, 'TURRET') < desiredTurrets
        and SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 0 then
        SetMothershipProcess(playerID, PROCESS_TURRET)
    elseif atWar and ProductionPerTurn(city) >= 12
        and SavedNumber(PKey(playerID, 'BATTERY'), 0) < required then
        SetMothershipProcess(playerID, PROCESS_CANNON)
    end
end

local function OnPlayerDoTurn(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    UpdateMothershipControl(playerID)
    SyncMothershipSight(playerID)
    if SavedNumber(PKey(playerID, 'ERA'), -1) ~= EraIndex(player) then ReconcileEra(playerID) end
    for unit in player:Units() do ApplyTraversal(player, unit) end
    DecrementCooldowns(playerID)
    ChargeMothership(playerID)
    AITurn(playerID)
    if player:IsHuman() and SavedNumber(PKey(playerID, 'PLAYER_PENDING'), 0) == 1 then
        LuaEvents.Azul_PlayerShipSelectionAvailable(playerID)
    end
    LuaEvents.Azul_StateChanged(playerID)
end

local function OnTeamTechResearched(teamID)
    for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local player = Players[playerID]
        if IsAzul(player) and player:GetTeam() == teamID then
            ReconcileEra(playerID)
            for unit in player:Units() do ApplyTraversal(player, unit) end
            LuaEvents.Azul_StateChanged(playerID)
        end
    end
end

local function OnCityCaptureComplete(oldOwnerID, isCapital, x, y, newOwnerID)
    local oldOwner = Players[oldOwnerID]
    if IsAzul(oldOwner) then
        UpdateMothershipControl(oldOwnerID)
        SyncMothershipSight(oldOwnerID)
    end
    local newOwner = Players[newOwnerID]
    if IsAzul(newOwner) then
        UpdateMothershipControl(newOwnerID)
        SyncMothershipSight(newOwnerID)
    end
end

local function Initialize()
    for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local player = Players[playerID]
        if IsAzul(player) then
            RecordOriginalMothership(playerID)
            UpdateMothershipControl(playerID)
            ReconcileEra(playerID)
            for unit in player:Units() do ApplyTraversal(player, unit) end
            if PlayerShip(playerID) == nil then
                for unit in player:Units() do
                    if IsPlayerEligible(unit) then
                        if SavedNumber(PKey(playerID, 'PLAYER_EVER'), 0) == 0 then SelectPlayerShip(playerID, unit:GetID())
                        else SetNumber(PKey(playerID, 'PLAYER_PENDING'), 1) end
                        break
                    end
                end
            end
        end
    end
end

LuaEvents.Azul_SelectPlayerShip.Add(function(playerID, unitID) SelectPlayerShip(playerID, unitID) end)
LuaEvents.Azul_UseAfterburner.Add(function(playerID, unitID) UseAfterburner(playerID, unitID) end)
LuaEvents.Azul_SelfDestruct.Add(function(playerID, unitID) SelfDestruct(playerID, unitID) end)
LuaEvents.Azul_FireHomingBomb.Add(function(playerID, unitID, ownerID, targetID) FireHomingBomb(playerID, unitID, ownerID, targetID) end)
LuaEvents.Azul_CaptureCity.Add(function(playerID, unitID, x, y) CaptureCity(playerID, unitID, x, y) end)
LuaEvents.Azul_FireMainCannon.Add(function(playerID, ownerID, unitID) FireMainCannon(playerID, ownerID, unitID) end)
LuaEvents.Azul_DeployTurret.Add(function(playerID, x, y) DeployTurret(playerID, x, y) end)
LuaEvents.Azul_SetMothershipProcess.Add(function(playerID, processID) SetMothershipProcess(playerID, processID) end)

GameEvents.PlayerDoTurn.Add(OnPlayerDoTurn)
if GameEvents.PlayerCanTrain ~= nil then GameEvents.PlayerCanTrain.Add(OnPlayerCanTrain) end
if GameEvents.CityCanTrain ~= nil then GameEvents.CityCanTrain.Add(OnCityCanTrain) end
if GameEvents.CityCanMaintain ~= nil then GameEvents.CityCanMaintain.Add(OnCityCanMaintain) end
if GameEvents.CanMoveInto ~= nil then GameEvents.CanMoveInto.Add(OnCanMoveInto) end
if GameEvents.UnitCanRangeAttackAt ~= nil then GameEvents.UnitCanRangeAttackAt.Add(OnUnitCanRangeAttackAt) end
if GameEvents.TeamTechResearched ~= nil then GameEvents.TeamTechResearched.Add(OnTeamTechResearched) end
if GameEvents.UnitPrekill ~= nil then GameEvents.UnitPrekill.Add(OnUnitPrekill) end
if GameEvents.UnitCreated ~= nil then GameEvents.UnitCreated.Add(OnUnitCreated) end
if GameEvents.BattleStarted ~= nil then GameEvents.BattleStarted.Add(OnBattleStarted) end
if GameEvents.BattleJoined ~= nil then GameEvents.BattleJoined.Add(OnBattleJoined) end
if GameEvents.BattleFinished ~= nil then GameEvents.BattleFinished.Add(OnBattleFinished) end
if GameEvents.CityCaptureComplete ~= nil then GameEvents.CityCaptureComplete.Add(OnCityCaptureComplete) end
if Events.SequenceGameInitComplete ~= nil then Events.SequenceGameInitComplete.Add(Initialize) end

Initialize()
