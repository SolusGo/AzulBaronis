-- Azul Baronis -- gameplay controller
-- Community Patch 5.3.2 supplies CanMoveInto, UnitSetXY,
-- CityCanMaintain and the pre/post-battle events used below.

local SAVE = Modding.OpenSaveData()
local CIV_AZUL = GameInfoTypes.CIVILIZATION_AZUL_BARONIS
local BUILDING_CORE = GameInfoTypes.BUILDING_AZUL_MOTHERSHIP_CORE
local BUILDING_PALACE = GameInfoTypes.BUILDING_PALACE
local PROCESS_CANNON = GameInfoTypes.PROCESS_AZUL_CHARGE_MAIN_CANNON
local PROCESS_TURRET = GameInfoTypes.PROCESS_AZUL_CONSTRUCT_TURRET
local PROMO_PLAYER = GameInfoTypes.PROMOTION_AZUL_PLAYER_CONTROLLED
local PROMO_EXTRA_INTERCEPTION = GameInfoTypes.PROMOTION_SORTIE
local FIGHTER_INTERCEPTION_PROMOS = {
    GameInfoTypes.PROMOTION_INTERCEPTION_IV,
    GameInfoTypes.PROMOTION_INTERCEPTION_1,
    GameInfoTypes.PROMOTION_INTERCEPTION_2,
    GameInfoTypes.PROMOTION_INTERCEPTION_3
}
local PROMO_HOVER = GameInfoTypes.PROMOTION_AZUL_HOVER
local PROMO_OCEAN = GameInfoTypes.PROMOTION_AZUL_OCEAN_ACCESS
local PROMO_MOUNTAIN = GameInfoTypes.PROMOTION_AZUL_MOUNTAIN_ACCESS
local PROMO_DOG_DEFENSE = GameInfoTypes.PROMOTION_AZUL_DOGFIGHTER_DEFENSE
local PROMO_DOG_EVADE = GameInfoTypes.PROMOTION_AZUL_DOGFIGHTER_EVADE
local PROMO_TESTUDON_REDUCTION = GameInfoTypes.PROMOTION_AZUL_TESTUDON_RANGED_REDUCTION
local PROMO_HOMING = GameInfoTypes.PROMOTION_AZUL_HOMING_BOMB_ACTIVE
local PROMO_AFTERBURNER = GameInfoTypes.PROMOTION_AZUL_AFTERBURNER_ACTIVE
local TECH_ASTRONOMY = GameInfoTypes.TECH_ASTRONOMY
local TECH_FLIGHT = GameInfoTypes.TECH_FLIGHT
local TERRAIN_OCEAN = GameInfoTypes.TERRAIN_OCEAN
local DOMAIN_AIR = GameInfoTypes.DOMAIN_AIR
local UNIT_GREAT_ADMIRAL = GameInfoTypes.UNIT_GREAT_ADMIRAL
local MOVE_DENOMINATOR = GameDefines.MOVE_DENOMINATOR or 60
local MAX_CIV_PLAYERS = GameDefines.MAX_PLAYERS or GameDefines.MAX_CIV_PLAYERS or 64
local DOGFIGHTER_EVADE_CHANCE = 5

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
local TESTUDON_CITY_SIEGE_BY_TYPE = {}
for era, bonus in pairs({[4] = 10, [5] = 20, [6] = 35, [7] = 50}) do
    local unitType = TESTUDONS[era]
    if unitType ~= nil then TESTUDON_CITY_SIEGE_BY_TYPE[unitType] = bonus end
end
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

local ATTACK_BONUS_PROMOS = {}
for promotion in GameInfo.UnitPromotions() do
    if tonumber(promotion.Blitz) == 1 or (tonumber(promotion.ExtraAttacks) or 0) > 0 then
        ATTACK_BONUS_PROMOS[#ATTACK_BONUS_PROMOS + 1] = promotion.ID
    end
end

local CANNON_BASE = {260, 360, 500, 700, 950, 1275, 1675, 2175}
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

local function MeterKey(playerID, name)
    return PKey(playerID, name .. '_X100')
end

local function GetMeter(playerID, name)
    local key = MeterKey(playerID, name)
    local value = SAVE.GetValue(key)
    if value == nil then
        value = SavedNumber(PKey(playerID, name), 0) * 100
        SetNumber(key, value)
    end
    return math.max(0, tonumber(value) or 0)
end

local function SetMeter(playerID, name, value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    SetNumber(MeterKey(playerID, name), value)
    -- Retain a whole-point mirror for existing v3 saves and older UI contexts.
    SetNumber(PKey(playerID, name), math.floor(value / 100))
end

local function IsAzul(player)
    return player ~= nil and player:IsAlive() and CIV_AZUL ~= nil
        and player:GetCivilizationType() == CIV_AZUL
end

-- Fleet Comms is presentation-only. These keys are new in v3 and never replace
-- existing unit, Player Ship, cooldown, or balance state.
local COMMS_PREFIX = {FIGHTER = 'Alpha', DESTROYER = 'Delta', TESTUDON = 'Testudon-'}
local COMMS_LINES = {
    DAMAGE = {'Taking hard hits!', 'My hull is taking a beating!', 'That one got through!', 'I need a moment!', 'Armor is giving way!', 'I felt that one!', 'Taking fire over here!', 'My shields are fading!'},
    CRITICAL = {'Barely holding together!', 'One more hit might do it!', 'Systems are failing!', 'That was far too close.', 'Still flying. Somehow.', 'I need cover now!'},
    LOSS_FIGHTER = {'We lost a Fighter.', 'An Alpha just went down.', 'Friendly fighter lost.', 'I lost their signal.', 'One of ours is gone.'},
    LOSS_DESTROYER = {'Destroyer down!', 'A Delta just went silent.', 'We lost a Destroyer.', 'Their signal is gone.'},
    LOSS_TESTUDON = {'Testudon lost.', 'Heavy hull down.', 'We lost the big one.', 'That was our Testudon.'},
    NEAR = {"Target's coming apart!", "They're almost finished!", 'One more good hit!', 'That hull is failing!', 'Finish the job!', 'Target is breaking up!'},
    KILL = {'Got one.', 'Target destroyed.', 'Scratch one.', "That's another.", 'One less threat.', 'Clean hit. Target down.', 'Not coming back.', 'That did it.', 'Target is gone.', 'Confirmed. Moving on.'},
    BRAG = {'That makes %d!', '%d confirmed.', 'Make that %d.', '%d and counting.', 'I have %d now.', 'That was number %d.', '%d down for me.', '%d targets gone.'},
    ASSIST = {'Could use a hand!', 'Little help over here?', 'I need some cover!', 'Anyone nearby?', "They're all over me!", 'Get them off me!'},
    HEAVY = {'Heavy contact!', 'That is a big target.', 'Priority hull ahead.', "That's no ordinary ship.", 'Something heavy out there.', 'Eyes on the big one.'},
    CITY = {'Hitting the city!', 'City defenses taking hits.', 'Keep the pressure on!', 'Their walls are shaking.', 'Targeting city defenses.', 'Opening a path through.'},
    CITY_NEAR = {'City defenses collapsing!', 'One more push!', "They're nearly finished!", 'The way in is open.'},
    CAPTURE = {'City secured.', 'Target position taken.', "We've got it.", 'Area secured.', 'The approach is clear.'},
    HOMING = {'Homing Bomb away.', 'Tracking target.', 'Bomb launched.', "Let's see them dodge this.", 'Package is on its way.'},
    AFTERBURNER = {'Punching it!', 'Afterburner engaged!', "I'm on it!", 'Coming through!', 'Give me room!'},
    TESTUDON = {'Firing.', 'Target acquired.', 'Engaging.', 'Beam aligned.'},
    TESTUDON_KILL = {'Target eliminated.', 'Path cleared.', 'Resistance removed.', 'Advance continues.'},
    INTERCEPT = {'Aircraft intercepted.', 'Not getting through.', 'Airspace clear.', 'Turned that one back.', 'I have the skies.', 'Intercept complete.'},
    INTERCEPT_KILL = {'Aircraft down!', 'Splash one!', 'That plane is gone.', 'Sky is clear.'},
    CANNON = {'Main Cannon fired.', 'Target eliminated.'}
}
local lastCommsLine = {}

local function CommsFamily(unit)
    return unit ~= nil and COMMS_PREFIX[FAMILY_BY_TYPE[unit:GetUnitType()]] ~= nil
        and FAMILY_BY_TYPE[unit:GetUnitType()] or nil
end

local function EnsureCallsign(playerID, unit)
    local family = CommsFamily(unit)
    if family == nil then return nil end
    local key = UKey('COMMS_SIGN', playerID, unit:GetID())
    local existing = SAVE.GetValue(key)
    if type(existing) == 'string' and existing ~= '' then return existing end
    local counter = PKey(playerID, 'COMMS_NEXT_' .. family)
    local nextNumber = SavedNumber(counter, 0) + 1
    SetNumber(counter, nextNumber)
    local sign = COMMS_PREFIX[family] .. string.format('%02d', nextNumber)
    SAVE.SetValue(key, sign)
    if SAVE.GetValue(UKey('COMMS_KILLS', playerID, unit:GetID())) == nil then
        SetNumber(UKey('COMMS_KILLS', playerID, unit:GetID()), 0)
    end
    return sign
end

local function MigrateCallsigns(playerID, player)
    local ships = {}
    for unit in player:Units() do
        if CommsFamily(unit) ~= nil then ships[#ships + 1] = unit end
    end
    table.sort(ships, function(a, b) return a:GetID() < b:GetID() end)
    -- Existing signs win; advance counters before filling gaps so old saves
    -- cannot duplicate a callsign when a surviving refit already has one.
    for _, unit in ipairs(ships) do
        local family = CommsFamily(unit)
        local sign = SAVE.GetValue(UKey('COMMS_SIGN', playerID, unit:GetID()))
        if type(sign) == 'string' then
            local number = tonumber(string.match(sign, '(%d+)$'))
            local counter = PKey(playerID, 'COMMS_NEXT_' .. family)
            if number ~= nil and number > SavedNumber(counter, 0) then SetNumber(counter, number) end
        end
    end
    for _, unit in ipairs(ships) do EnsureCallsign(playerID, unit) end
end

local function PickCommsLine(category)
    local pool = COMMS_LINES[category]
    if pool == nil or #pool == 0 then return nil end
    local previous = lastCommsLine[category]
    -- Flavor rolls use Lua's separate RNG, never Civ V's gameplay RNG.
    local index = math.random(#pool)
    if #pool > 1 and index == previous then index = index % #pool + 1 end
    lastCommsLine[category] = index
    return pool[index]
end

local function EmitComms(playerID, unit, category, importance, explicitLine)
    local player = Players[playerID]
    if not IsAzul(player) or not player:IsHuman() or Game.GetActivePlayer() ~= playerID then return false end
    local family = CommsFamily(unit)
    if unit ~= nil and family == nil then return false end
    local turn = Game.GetGameTurn()
    local countTurn = PKey(playerID, 'COMMS_COUNT_TURN')
    local countKey = PKey(playerID, 'COMMS_COUNT')
    local count = SavedNumber(countTurn, -1) == turn and SavedNumber(countKey, 0) or 0
    if count >= 3 then return false end
    local routine = importance ~= 'IMPORTANT' and importance ~= 'CERTAIN'
    if routine and SavedNumber(PKey(playerID, 'COMMS_ROUTINE_TURN'), -1) == turn then return false end
    if unit ~= nil and SavedNumber(UKey('COMMS_LAST_TURN', playerID, unit:GetID()), -1) == turn then return false end
    local chance = routine and 30 or 80
    if family == 'TESTUDON' then chance = routine and 9 or 50 end
    if unit ~= nil and SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == unit:GetID() then chance = math.min(100, chance + 10) end
    if importance == 'CERTAIN' then chance = 100 end
    if math.random(100) > chance then return false end
    local line = explicitLine or PickCommsLine(category)
    if line == nil then return false end
    local sign = unit ~= nil and EnsureCallsign(playerID, unit) or 'FLEET SYSTEMS'
    if unit ~= nil and SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == unit:GetID() then sign = '★ ' .. sign end
    SetNumber(countTurn, turn)
    SetNumber(countKey, count + 1)
    if routine then SetNumber(PKey(playerID, 'COMMS_ROUTINE_TURN'), turn) end
    if unit ~= nil then SetNumber(UKey('COMMS_LAST_TURN', playerID, unit:GetID()), turn) end
    if LuaEvents.Azul_CommsMessage ~= nil then LuaEvents.Azul_CommsMessage(playerID, sign .. ': ' .. line) end
    return true
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

local function HasEligibleShip(player)
    if player == nil then return false end
    for unit in player:Units() do
        if IsPlayerEligible(unit) then return true end
    end
    return false
end

local function SyncFighterInterception(playerID, unit)
    if unit == nil or FAMILY_BY_TYPE[unit:GetUnitType()] ~= 'FIGHTER' then return end
    for _, promotionID in ipairs(FIGHTER_INTERCEPTION_PROMOS) do
        if promotionID ~= nil and not unit:IsHasPromotion(promotionID) then
            unit:SetHasPromotion(promotionID, true)
        end
    end
    if PROMO_EXTRA_INTERCEPTION ~= nil then
        local isPlayerFighter = SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == unit:GetID()
        if unit:IsHasPromotion(PROMO_EXTRA_INTERCEPTION) ~= isPlayerFighter then
            unit:SetHasPromotion(PROMO_EXTRA_INTERCEPTION, isPlayerFighter)
        end
    end
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
    for unit in player:Units() do SyncFighterInterception(playerID, unit) end
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
    if player ~= nil then
        for unit in player:Units() do SyncFighterInterception(playerID, unit) end
    end
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
    SyncFighterInterception(player:GetID(), unit)
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
    SetMeter(playerID, 'BATTERY', 0)
    SetMeter(playerID, 'TURRET_PROGRESS', 0)
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
        SetMeter(playerID, 'BATTERY', 0)
        SetMeter(playerID, 'TURRET_PROGRESS', 0)
        SetNumber(PKey(playerID, 'TURRET_READY'), 0)
        DestroyTurrets(player)
        Notify(playerID, '[COLOR_WARNING_TEXT]MOTHERSHIP LOST[ENDCOLOR] — weapon systems and defensive turrets are offline.')
    elseif not wasActive and controlled then
        SetNumber(PKey(playerID, 'MOTH_ACTIVE'), 1)
        SetMeter(playerID, 'BATTERY', 0)
        SetMeter(playerID, 'TURRET_PROGRESS', 0)
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

local function ProductionPerTurn100(city)
    local ok, value = pcall(function()
        return city:GetCurrentProductionDifferenceTimes100(false, false)
    end)
    if ok and value ~= nil then return math.max(0, math.floor(value + 0.5)) end
    return math.max(0, math.floor(city:GetYieldRate(YieldTypes.YIELD_PRODUCTION) * 100 + 0.5))
end

local function ChargeMothership(playerID)
    local player = Players[playerID]
    local city = OriginalCity(playerID, true)
    if not IsAzul(player) or city == nil then return end
    local process = city:GetProductionProcess()
    local production = ProductionPerTurn100(city)
    if process == PROCESS_CANNON then
        local required = Requirement(CANNON_BASE, player) * 100
        local stored = GetMeter(playerID, 'BATTERY')
        SetMeter(playerID, 'BATTERY', math.min(required, stored + production))
    elseif process == PROCESS_TURRET and SavedNumber(PKey(playerID, 'TURRET_READY'), 0) == 0 then
        local required = Requirement(TURRET_BASE, player) * 100
        local stored = GetMeter(playerID, 'TURRET_PROGRESS')
        local updated = math.min(required, stored + production)
        SetMeter(playerID, 'TURRET_PROGRESS', updated)
        if updated >= required then
            SetNumber(PKey(playerID, 'TURRET_READY'), 1)
            Notify(playerID, '[COLOR_POSITIVE_TEXT]TURRET READY[ENDCOLOR] — open Fleet Systems to deploy it.')
        end
    end
end

local function IsAttackLocked(playerID, unitID)
    return SavedNumber(UKey('ATTACK_LOCK', playerID, unitID), -1) == Game.GetGameTurn()
end

local function ExhaustAttacks(playerID, unit)
    if unit == nil then return end
    local unitID = unit:GetID()
    for _, promotionID in ipairs(ATTACK_BONUS_PROMOS) do
        if unit:IsHasPromotion(promotionID) then
            SetNumber(UKey('LOCKED_PROMO_' .. tostring(promotionID), playerID, unitID), 1)
            unit:SetHasPromotion(promotionID, false)
        end
    end
    unit:SetMadeAttack(true)
    SetNumber(UKey('ATTACK_LOCK', playerID, unitID), Game.GetGameTurn())
end

local function RestoreAttackPromotions(playerID, unit)
    if unit == nil then return end
    local unitID = unit:GetID()
    local lockTurn = SavedNumber(UKey('ATTACK_LOCK', playerID, unitID), -1)
    if lockTurn < 0 or lockTurn >= Game.GetGameTurn() then return end
    for _, promotionID in ipairs(ATTACK_BONUS_PROMOS) do
        local key = UKey('LOCKED_PROMO_' .. tostring(promotionID), playerID, unitID)
        if SavedNumber(key, 0) == 1 then
            unit:SetHasPromotion(promotionID, true)
            SetNumber(key, 0)
        end
    end
    SetNumber(UKey('ATTACK_LOCK', playerID, unitID), -1)
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
    local attackLock = SavedNumber(UKey('ATTACK_LOCK', playerID, oldID), -1)
    local callsign = EnsureCallsign(playerID, unit)
    local commsKills = SavedNumber(UKey('COMMS_KILLS', playerID, oldID), 0)
    local commsLastTurn = SavedNumber(UKey('COMMS_LAST_TURN', playerID, oldID), -1)
    local wasPlayer = SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == oldID
    local scriptData = nil
    if unit.GetScriptData ~= nil then
        local scriptDataOK, value = pcall(function() return unit:GetScriptData() end)
        if scriptDataOK then scriptData = value end
    end
    local lockedPromos = {}
    for _, promotionID in ipairs(ATTACK_BONUS_PROMOS) do
        lockedPromos[#lockedPromos + 1] = {
            promotionID = promotionID,
            value = SavedNumber(UKey('LOCKED_PROMO_' .. tostring(promotionID), playerID, oldID), 0)
        }
    end

    local function WriteHullState(unitID)
        if callsign ~= nil then SAVE.SetValue(UKey('COMMS_SIGN', playerID, unitID), callsign) end
        SetNumber(UKey('COMMS_KILLS', playerID, unitID), commsKills)
        SetNumber(UKey('COMMS_LAST_TURN', playerID, unitID), commsLastTurn)
        SetNumber(UKey('AFTERBURNER', playerID, unitID), afterburner)
        SetNumber(UKey('HOMING', playerID, unitID), bomb)
        SetNumber(UKey('ATTACK_LOCK', playerID, unitID), attackLock)
        for _, row in ipairs(lockedPromos) do
            SetNumber(UKey('LOCKED_PROMO_' .. tostring(row.promotionID), playerID, unitID), row.value)
        end
    end

    local function ClearHullState(unitID)
        SAVE.SetValue(UKey('COMMS_SIGN', playerID, unitID), '')
        SetNumber(UKey('COMMS_KILLS', playerID, unitID), 0)
        SetNumber(UKey('COMMS_LAST_TURN', playerID, unitID), -1)
        SetNumber(UKey('AFTERBURNER', playerID, unitID), 0)
        SetNumber(UKey('HOMING', playerID, unitID), 0)
        SetNumber(UKey('ATTACK_LOCK', playerID, unitID), -1)
        for _, row in ipairs(lockedPromos) do
            SetNumber(UKey('LOCKED_PROMO_' .. tostring(row.promotionID), playerID, unitID), 0)
        end
    end

    swappingHull = true
    local newUnit = nil
    local restored, restoreError = pcall(function()
        newUnit = player:InitUnit(targetType, x, y, unit:GetUnitAIType(), DirectionTypes.NO_DIRECTION)
        if newUnit == nil then return end
        for _, promotionID in ipairs(promotions) do newUnit:SetHasPromotion(promotionID, true) end
        if name ~= nil and name ~= '' then newUnit:SetName(name) end
        newUnit:SetDamage(math.min(damage, newUnit:GetMaxHitPoints() - 1), -1)
        newUnit:SetExperience(experience)
        newUnit:SetLevel(level)
        newUnit:SetMoves(math.max(0, moves))
        newUnit:SetMadeAttack(madeAttack)
        if scriptData ~= nil and newUnit.SetScriptData ~= nil then
            newUnit:SetScriptData(scriptData)
        end
        ApplyTraversal(player, newUnit)
        WriteHullState(newUnit:GetID())
        if wasPlayer then
            if PROMO_PLAYER ~= nil then newUnit:SetHasPromotion(PROMO_PLAYER, true) end
        end
    end)

    if not restored or newUnit == nil then
        if newUnit ~= nil then
            pcall(function()
                ClearHullState(newUnit:GetID())
                newUnit:Kill(false, -1)
            end)
        end
        swappingHull = false
        if not restored then print('[Azul] Era refit restore failed: ' .. tostring(restoreError)) end
        return unit
    end

    -- Commit identity immediately before removing the old hull. If either call
    -- errors, the replacement is discarded while the original and its keys
    -- remain intact.
    local committed, commitError = pcall(function()
        if wasPlayer then SetNumber(PKey(playerID, 'PLAYER_SHIP'), newUnit:GetID()) end
        unit:Kill(true, -1)
    end)
    if not committed then
        pcall(function()
            if wasPlayer then SetNumber(PKey(playerID, 'PLAYER_SHIP'), oldID) end
            ClearHullState(newUnit:GetID())
            newUnit:Kill(false, -1)
        end)
        swappingHull = false
        print('[Azul] Era refit commit failed: ' .. tostring(commitError))
        return unit
    end

    local cleaned, cleanupError = pcall(function() ClearHullState(oldID) end)
    SyncFighterInterception(playerID, newUnit)
    swappingHull = false
    if not cleaned then print('[Azul] Era refit old-state cleanup failed: ' .. tostring(cleanupError)) end
    return newUnit
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
        RestoreAttackPromotions(playerID, unit)
        local family = FAMILY_BY_TYPE[unit:GetUnitType()]
        if family == 'FIGHTER' or family == 'DESTROYER' then
            if PROMO_AFTERBURNER ~= nil and unit:IsHasPromotion(PROMO_AFTERBURNER) then
                unit:SetHasPromotion(PROMO_AFTERBURNER, false)
            end
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
    local required = Requirement(CANNON_BASE, player) * 100
    if GetMeter(playerID, 'BATTERY') < required then return false end
    SetMeter(playerID, 'BATTERY', 0)
    -- The CP exposes the city's attack flag read-only. Record consumption here;
    -- PrepareBattle nullifies any attempted ordinary city shot later this turn.
    SetNumber(PKey(playerID, 'CANNON_FIRED_TURN'), Game.GetGameTurn())
    local targetName = Locale.ConvertTextKey(target:GetNameKey())
    target:Kill(true, playerID)
    EmitComms(playerID, nil, 'CANNON', 'CERTAIN')
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

local function TotalPositiveDefense(defender, attacker)
    if defender == nil then return 0 end
    local base = tonumber(defender:GetBaseCombatStrength()) or 0
    if base <= 0 then return PlotDefense(defender:GetPlot(), defender) end
    local ok, strength = pcall(function()
        return defender:GetMaxDefenseStrength(defender:GetPlot(), attacker,
            attacker and attacker:GetPlot() or nil, true)
    end)
    if not ok or strength == nil then return PlotDefense(defender:GetPlot(), defender) end
    return math.max(0, (tonumber(strength) or 0) / (base * 100) * 100 - 100)
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
    local plot = target:GetPlot()
    return plot ~= nil and plot:IsVisible(player:GetTeam(), false)
        and Map.PlotDistance(destroyer:GetX(), destroyer:GetY(), target:GetX(), target:GetY()) <= 3
end

local function FireHomingBomb(playerID, unitID, targetOwnerID, targetUnitID)
    local player = Players[playerID]
    local destroyer = player and player:GetUnitByID(unitID) or nil
    local targetPlayer = Players[targetOwnerID]
    local target = targetPlayer and targetPlayer:GetUnitByID(targetUnitID) or nil
    if not IsAzul(player) or not ValidHomingTarget(player, destroyer, target) then return false end
    if destroyer:IsOutOfAttacks() or IsAttackLocked(playerID, unitID)
        or SavedNumber(UKey('HOMING', playerID, unitID), 0) > 0 then return false end
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
    EmitComms(playerID, destroyer, 'HOMING', 'ROUTINE')
    -- RangeStrike resolves combat before returning; clean up and lock the
    -- weapon here as well as in BattleFinished so skipped animations/events
    -- cannot leave a hidden modifier or a bonus attack behind.
    ClearTemporary(destroyer)
    ExhaustAttacks(playerID, destroyer)
    homingAttack = nil
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
    local cityX, cityY = city:GetX(), city:GetY()
    local acquired = pcall(function() player:AcquireCity(city, true, false) end)
    if not acquired then return false end
    local plotAfter = Map.GetPlot(cityX, cityY)
    local cityAfter = plotAfter and plotAfter:GetPlotCity() or nil
    if cityAfter == nil or cityAfter:GetOwner() ~= playerID then return false end
    unit:SetMadeAttack(true)
    unit:FinishMoves()
    EmitComms(playerID, unit, 'CAPTURE', 'IMPORTANT')
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
    -- The UI add-in environment does not consistently expose the unit-AI enum.
    -- Omitting the optional AI/direction arguments lets Civ V use the turret
    -- row's UNITAI_RANGED default without depending on that missing enum.
    local turret = player:InitUnit(unitType, x, y)
    if turret == nil then return false end
    turret:SetMoves(0)
    ApplyTraversal(player, turret)
    SetNumber(PKey(playerID, 'TURRET_READY'), 0)
    SetMeter(playerID, 'TURRET_PROGRESS', 0)
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
    if not IsAzul(player) or PlayerShip(playerID) ~= unit or unit:IsOutOfAttacks()
        or IsAttackLocked(playerID, unitID) then return false end
    local key = UKey('AFTERBURNER', playerID, unitID)
    if SavedNumber(key, 0) > 0 then return false end
    local family = FAMILY_BY_TYPE[unit:GetUnitType()]
    local bonus = family == 'FIGHTER' and 2 or (family == 'DESTROYER' and 1 or 0)
    if bonus <= 0 then return false end
    unit:ChangeMoves(bonus * MOVE_DENOMINATOR)
    ExhaustAttacks(playerID, unit)
    if PROMO_AFTERBURNER ~= nil then unit:SetHasPromotion(PROMO_AFTERBURNER, true) end
    SetNumber(key, 3)
    EmitComms(playerID, unit, 'AFTERBURNER', 'ROUTINE')
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
        local queueLength = city:GetOrderQueueLength()
        for index = 0, queueLength - 1 do
            local orderType, data1 = city:GetOrderFromQueue(index)
            if orderType == OrderTypes.ORDER_TRAIN and FAMILY_BY_TYPE[data1] == family
                and not (city:GetID() == excludedCityID and index == 0) then
                count = count + 1
            end
        end
    end
    return count
end


local function PruneTestudonQueues(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    local remaining = math.max(0, TestudonCap(player) - CountFamily(player, 'TESTUDON'))
    local removals = {}
    for city in player:Cities() do
        local cityRemovals = {}
        local queueLength = city:GetOrderQueueLength()
        for index = 0, queueLength - 1 do
            local orderType, data1 = city:GetOrderFromQueue(index)
            if orderType == OrderTypes.ORDER_TRAIN and FAMILY_BY_TYPE[data1] == 'TESTUDON' then
                if remaining > 0 then remaining = remaining - 1
                else cityRemovals[#cityRemovals + 1] = index end
            end
        end
        if #cityRemovals > 0 then removals[#removals + 1] = {city = city, indices = cityRemovals} end
    end
    local removed = 0
    for _, row in ipairs(removals) do
        for index = #row.indices, 1, -1 do
            local ok = pcall(function() row.city:PopOrder(row.indices[index], false, true) end)
            if ok then removed = removed + 1 end
        end
    end
    if removed > 0 then
        Notify(playerID, '[COLOR_WARNING_TEXT]TESTUDON CAP ENFORCED[ENDCOLOR] — excess queued hulls cancelled.')
    end
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

local function OnUnitSetXY(playerID, unitID, x, y)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(unitID) or nil
    if swappingHull or unit == nil or FAMILY_BY_TYPE[unit:GetUnitType()] ~= 'TESTUDON' then return end
    local oldX = SavedNumber(UKey('LAST_X', playerID, unitID), -999)
    local oldY = SavedNumber(UKey('LAST_Y', playerID, unitID), -999)
    SetNumber(UKey('LAST_X', playerID, unitID), x)
    SetNumber(UKey('LAST_Y', playerID, unitID), y)
    if oldX ~= x or oldY ~= y then
        -- UnitSetXY fires before the DLL deducts movement cost, so coordinates
        -- are the reliable signal that a Testudon has spent its firing stance.
        ExhaustAttacks(playerID, unit)
    end
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
    battle.commsAttackerDamage = attacker and attacker:GetDamage() or nil
    battle.commsDefenderDamage = defender and defender:GetDamage() or nil
    battle.commsAttackerCombat = attacker ~= nil and attacker:IsCombatUnit()
    battle.commsDefenderCombat = defender ~= nil and defender:IsCombatUnit()
    battle.commsAttackerDomain = attacker and attacker:GetDomainType() or nil
    battle.commsDefenderDomain = defender and defender:GetDomainType() or nil
    if battle.defender.isCity and defenderPlayer ~= nil then
        local city = defenderPlayer:GetCityByID(battle.defender.objectID)
        battle.commsCityDamage = city and city:GetDamage() or nil
    end

    if attacker ~= nil and FAMILY_BY_TYPE[attacker:GetUnitType()] == 'DESTROYER' then
        battle.destroyerAttacker = attacker
        battle.destroyerPlayerID = battle.attacker.playerID
    end

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
        if Game.Rand(100, 'Azul Dogfighter Evasion') < DOGFIGHTER_EVADE_CHANCE then
            defender:SetHasPromotion(PROMO_DOG_EVADE, true)
            battle.evaded = true
        end
    end

    if attacker ~= nil and FAMILY_BY_TYPE[attacker:GetUnitType()] == 'TESTUDON' then
        if battle.defender.isCity then
            -- City combat has no defender unit. Apply only the hull's city-siege
            -- modifier during the native ranged strike, then clear it on finish.
            local bonus = TESTUDON_CITY_SIEGE_BY_TYPE[attacker:GetUnitType()] or 0
            battle.focusedPromotion = ApplyBeamCompensation(attacker, bonus)
            battle.focusedAttacker = attacker
        elseif defender ~= nil then
            local defense = TotalPositiveDefense(defender, attacker)
            -- If defender strength is B*(1+D), ignoring half D is equivalent to
            -- multiplying attack by (1+D)/(1+D/2).
            local compensation = math.floor(RangedStrengthScale(attacker)
                * (100 * defense) / math.max(1, 200 + defense) + 0.5)
            battle.focusedPromotion = ApplyBeamCompensation(attacker, compensation)
            battle.focusedAttacker = attacker
        end
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
        ClearTemporary(currentBattle.cannonBlockedDefender)
    end
    currentBattle = {battleType = battleType, x = x, y = y, prepared = false}
end

local function OnBattleJoined(playerID, objectID, role, isCity)
    if currentBattle == nil then currentBattle = {prepared = false} end
    local row = {playerID = playerID, objectID = objectID, isCity = isCity == true}
    if role == 0 then
        currentBattle.attacker = row
        local player = Players[playerID]
        local attacker = not row.isCity and player and player:GetUnitByID(objectID) or nil
        currentBattle.commsAttackerDamage = attacker and attacker:GetDamage() or nil
        currentBattle.commsAttackerCombat = attacker ~= nil and attacker:IsCombatUnit()
        currentBattle.commsAttackerDomain = attacker and attacker:GetDomainType() or nil
    elseif role == 1 then currentBattle.defender = row
    elseif role == 2 then currentBattle.interceptor = row end
    PrepareBattle()
end

local function BattleUnit(participant)
    if participant == nil or participant.isCity then return nil end
    local player = Players[participant.playerID]
    return player and player:GetUnitByID(participant.objectID) or nil
end

local function HasNearbyCommsAlly(player, ship)
    for other in player:Units() do
        if other:GetID() ~= ship:GetID() and CommsFamily(other) ~= nil
            and Map.PlotDistance(ship:GetX(), ship:GetY(), other:GetX(), other:GetY()) <= 4 then return true end
    end
    return false
end

local function CreditCommsKill(battle, killer, deadDomain)
    if battle.commsKillCredited or killer == nil or CommsFamily(killer) == nil then return end
    battle.commsKillCredited = true
    local ownerID = killer:GetOwner()
    local key = UKey('COMMS_KILLS', ownerID, killer:GetID())
    local kills = SavedNumber(key, 0) + 1
    SetNumber(key, kills)
    local category = 'KILL'
    local line = nil
    if deadDomain == DOMAIN_AIR and CommsFamily(killer) == 'FIGHTER' then
        category = 'INTERCEPT_KILL'
    elseif CommsFamily(killer) == 'TESTUDON' then
        category = 'TESTUDON_KILL'
    elseif kills >= 3 and (kills % 3 == 0 or kills % 5 == 0)
        and math.random(100) <= 55 then
        category = 'BRAG'
        line = string.format(PickCommsLine('BRAG'), kills)
    end
    battle.commsHandled = EmitComms(ownerID, killer, category, 'IMPORTANT', line)
end

local function BattleComms(battle)
    if battle == nil or battle.commsHandled then return end
    local attacker = BattleUnit(battle.attacker)
    local defender = BattleUnit(battle.defender)
    local interceptor = BattleUnit(battle.interceptor)
    local attackerPlayer = battle.attacker and Players[battle.attacker.playerID] or nil
    local defenderPlayer = battle.defender and Players[battle.defender.playerID] or nil

    -- Some delayed-death paths dispatch UnitPrekill after BattleFinished. Use
    -- the final battle snapshot as a fallback, but never credit a living unit.
    if not battle.commsKillCredited then
        if battle.commsDefenderCombat and (defender == nil or defender:IsDead())
            and attacker ~= nil and IsAzul(attackerPlayer) and battle.defender.playerID ~= attacker:GetOwner() then
            CreditCommsKill(battle, attacker, battle.commsDefenderDomain)
        elseif battle.commsAttackerCombat and (attacker == nil or attacker:IsDead()) then
            local guard = interceptor or defender
            local guardPlayer = guard and Players[guard:GetOwner()] or nil
            if IsAzul(guardPlayer) and battle.attacker.playerID ~= guard:GetOwner() then
                CreditCommsKill(battle, guard, battle.commsAttackerDomain)
            end
        end
    end
    if battle.commsHandled then return end

    -- Only a confirmed rise in damage counts as a successful interception.
    if attacker ~= nil and attacker:GetDomainType() == DOMAIN_AIR
        and battle.commsAttackerDamage ~= nil and attacker:GetDamage() > battle.commsAttackerDamage then
        local guard = interceptor or defender
        local guardPlayer = guard and Players[guard:GetOwner()] or nil
        if IsAzul(guardPlayer) and CommsFamily(guard) == 'FIGHTER' then
            if EmitComms(guard:GetOwner(), guard, 'INTERCEPT', 'IMPORTANT') then return end
        end
    end

    if not battle.prepared then return end

    local damaged = nil
    local damagedPlayerID = nil
    local prior = nil
    if attacker ~= nil and IsAzul(attackerPlayer) and CommsFamily(attacker) ~= nil then
        damaged, damagedPlayerID, prior = attacker, battle.attacker.playerID, battle.commsAttackerDamage
    end
    if defender ~= nil and IsAzul(defenderPlayer) and CommsFamily(defender) ~= nil
        and (damaged == nil or defender:GetDamage() > (battle.commsDefenderDamage or defender:GetDamage())) then
        damaged, damagedPlayerID, prior = defender, battle.defender.playerID, battle.commsDefenderDamage
    end
    if damaged ~= nil and prior ~= nil and damaged:GetDamage() > prior then
        local maxHP = math.max(1, damaged:GetMaxHitPoints())
        local remaining = maxHP - damaged:GetDamage()
        local before = maxHP - prior
        if remaining <= maxHP * 0.2 and before > maxHP * 0.2 then
            if EmitComms(damagedPlayerID, damaged, 'CRITICAL', 'IMPORTANT') then return end
        elseif remaining <= maxHP * 0.5 and before > maxHP * 0.5 then
            local category = HasNearbyCommsAlly(Players[damagedPlayerID], damaged)
                and math.random(3) == 1 and 'ASSIST' or 'DAMAGE'
            if EmitComms(damagedPlayerID, damaged, category, 'ROUTINE') then return end
        end
    end

    if attacker == nil or not IsAzul(attackerPlayer) or CommsFamily(attacker) == nil then return end
    local playerID = battle.attacker.playerID
    if battle.defender.isCity and defenderPlayer ~= nil then
        local city = defenderPlayer:GetCityByID(battle.defender.objectID)
        if city ~= nil and battle.commsCityDamage ~= nil and city:GetDamage() > battle.commsCityDamage then
            local category = city:GetMaxHitPoints() - city:GetDamage() <= city:GetMaxHitPoints() * 0.2
                and 'CITY_NEAR' or 'CITY'
            EmitComms(playerID, attacker, category, 'ROUTINE')
        end
        return
    end
    if defender == nil or battle.commsDefenderDamage == nil
        or defender:GetDamage() <= battle.commsDefenderDamage then return end
    local remaining = defender:GetMaxHitPoints() - defender:GetDamage()
    if remaining <= defender:GetMaxHitPoints() * 0.2 then
        if EmitComms(playerID, attacker, 'NEAR', 'ROUTINE') then return end
    end
    if CommsFamily(attacker) == 'TESTUDON' then
        EmitComms(playerID, attacker, 'TESTUDON', 'ROUTINE')
        return
    end
    local targetInfo = GameInfo.Units[defender:GetUnitType()]
    local ownInfo = GameInfo.Units[attacker:GetUnitType()]
    if targetInfo ~= nil and ownInfo ~= nil
        and (tonumber(targetInfo.Cost) or 0) >= math.max(250, (tonumber(ownInfo.Cost) or 0) * 1.6) then
        EmitComms(playerID, attacker, 'HEAVY', 'ROUTINE')
    end
end

local function OnBattleFinished()
    local battle = currentBattle
    currentBattle = nil
    if battle == nil then return end
    BattleComms(battle)
    ClearTemporary(battle.dogfighter)
    ClearTemporary(battle.focusedAttacker)
    ClearTemporary(battle.cannonBlockedDefender)
    ClearTemporary(battle.testudonDefense)
    if battle.destroyerAttacker ~= nil and not battle.destroyerAttacker:IsDead() then
        ExhaustAttacks(battle.destroyerPlayerID, battle.destroyerAttacker)
    end
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
        ExhaustAttacks(homingAttack.playerID, unit)
        homingAttack = nil
    end
end

local function OnUnitPrekill(playerID, unitID)
    if swappingHull then return end
    local player = Players[playerID]
    local dying = player and player:GetUnitByID(unitID) or nil
    local battle = currentBattle
    if battle ~= nil and dying ~= nil and dying:IsCombatUnit() and not battle.commsKillCredited then
        local killerParticipant = nil
        if battle.defender ~= nil and battle.defender.playerID == playerID
            and battle.defender.objectID == unitID and not battle.defender.isCity then
            killerParticipant = battle.attacker
        elseif battle.attacker ~= nil and battle.attacker.playerID == playerID
            and battle.attacker.objectID == unitID and not battle.attacker.isCity then
            killerParticipant = battle.interceptor or battle.defender
        end
        local killer = BattleUnit(killerParticipant)
        local killerPlayer = killer and Players[killer:GetOwner()] or nil
        if killer ~= nil and IsAzul(killerPlayer) and CommsFamily(killer) ~= nil
            and killer:GetOwner() ~= playerID then
            CreditCommsKill(battle, killer, dying:GetDomainType())
        end
    end
    if not IsAzul(player) then return end
    if dying ~= nil and CommsFamily(dying) ~= nil then
        local speaker = nil
        local bestDistance = 5
        for ally in player:Units() do
            if ally:GetID() ~= unitID and CommsFamily(ally) ~= nil then
                local distance = Map.PlotDistance(dying:GetX(), dying:GetY(), ally:GetX(), ally:GetY())
                if distance < bestDistance then speaker, bestDistance = ally, distance end
            end
        end
        if speaker ~= nil then
            local category = 'LOSS_' .. CommsFamily(dying)
            if EmitComms(playerID, speaker, category, 'IMPORTANT') and battle ~= nil then battle.commsHandled = true end
        end
        SAVE.SetValue(UKey('COMMS_SIGN', playerID, unitID), '')
        SetNumber(UKey('COMMS_KILLS', playerID, unitID), 0)
        SetNumber(UKey('COMMS_LAST_TURN', playerID, unitID), -1)
    end
    if SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == unitID then
        ClearPlayerShip(playerID, true)
        Notify(playerID, '[COLOR_WARNING_TEXT]PLAYER SHIP DESTROYED[ENDCOLOR] — select a surviving vessel next turn.')
    end
    SetNumber(UKey('AFTERBURNER', playerID, unitID), 0)
    SetNumber(UKey('HOMING', playerID, unitID), 0)
    SetNumber(UKey('LAST_X', playerID, unitID), -999)
    SetNumber(UKey('LAST_Y', playerID, unitID), -999)
    SetNumber(UKey('ATTACK_LOCK', playerID, unitID), -1)
    for _, promotionID in ipairs(ATTACK_BONUS_PROMOS) do
        SetNumber(UKey('LOCKED_PROMO_' .. tostring(promotionID), playerID, unitID), 0)
    end
end

local function OnUnitCreated(playerID, unitID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    local unit = player:GetUnitByID(unitID)
    if unit == nil then return end
    if swappingHull then return end
    if UNIT_GREAT_ADMIRAL ~= nil and unit:GetUnitType() == UNIT_GREAT_ADMIRAL and UNIT_COMMANDER ~= nil then
        unit:Kill(true, -1)
        Notify(playerID, '[COLOR_WARNING_TEXT]GREAT ADMIRAL DISABLED[ENDCOLOR] — Azul uses Fleet Commanders generated as Great Generals.')
        return
    end
    local family = FAMILY_BY_TYPE[unit:GetUnitType()]
    if family == 'TESTUDON' and CountFamily(player, 'TESTUDON') > TestudonCap(player) then
        Notify(playerID, '[COLOR_WARNING_TEXT]TESTUDON CAP REACHED[ENDCOLOR] — excess hull removed.')
        unit:Kill(true, -1)
        return
    end
    EnsureCallsign(playerID, unit)
    if family ~= nil then ApplyTraversal(player, unit) end
    if IsPlayerEligible(unit) and PlayerShip(playerID) == nil then
        if SavedNumber(PKey(playerID, 'PLAYER_EVER'), 0) == 0 and family == 'FIGHTER' then
            SelectPlayerShip(playerID, unitID)
        else
            SetNumber(PKey(playerID, 'PLAYER_PENDING'), 1)
            if player:IsHuman() and playerID == Game.GetActivePlayer() then
                LuaEvents.Azul_PlayerShipSelectionAvailable(playerID)
            end
        end
    end
end

local function BestAITarget(player, city, range, cannon)
    local best, bestScore = nil, -1
    for otherID = 0, MAX_CIV_PLAYERS - 1 do
        local other = Players[otherID]
        if other ~= nil and other:IsAlive() and Teams[player:GetTeam()]:IsAtWar(other:GetTeam()) then
            for unit in other:Units() do
                local valid = cannon and ValidCannonTarget(player, city, unit)
                    or (not cannon and unit:IsCombatUnit() and unit:GetDomainType() ~= DOMAIN_AIR
                        and unit:GetPlot() ~= nil and unit:GetPlot():IsVisible(player:GetTeam(), false)
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
    local required = Requirement(CANNON_BASE, player) * 100
    if GetMeter(playerID, 'BATTERY') >= required then
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
    elseif atWar and ProductionPerTurn100(city) >= 1200
        and GetMeter(playerID, 'BATTERY') < required then
        SetMothershipProcess(playerID, PROCESS_CANNON)
    elseif city:GetProductionProcess() == PROCESS_CANNON or city:GetProductionProcess() == PROCESS_TURRET then
        pcall(function() city:PopOrder(0, false, true) end)
    end
end

local function OnPlayerDoTurn(playerID)
    local player = Players[playerID]
    if not IsAzul(player) then return end
    UpdateMothershipControl(playerID)
    SyncMothershipSight(playerID)
    if SavedNumber(PKey(playerID, 'ERA'), -1) ~= EraIndex(player) then ReconcileEra(playerID) end
    PruneTestudonQueues(playerID)
    for unit in player:Units() do ApplyTraversal(player, unit) end
    DecrementCooldowns(playerID)
    ChargeMothership(playerID)
    AITurn(playerID)
    if player:IsHuman() and SavedNumber(PKey(playerID, 'PLAYER_PENDING'), 0) == 1
        and HasEligibleShip(player) then
        LuaEvents.Azul_PlayerShipSelectionAvailable(playerID)
    end
    LuaEvents.Azul_StateChanged(playerID)
end

local function OnTeamTechResearched(teamID)
    for playerID = 0, MAX_CIV_PLAYERS - 1 do
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
    for playerID = 0, MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if IsAzul(player) then
            MigrateCallsigns(playerID, player)
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
if GameEvents.UnitSetXY ~= nil then GameEvents.UnitSetXY.Add(OnUnitSetXY) end
if GameEvents.TeamTechResearched ~= nil then GameEvents.TeamTechResearched.Add(OnTeamTechResearched) end
if GameEvents.UnitPrekill ~= nil then GameEvents.UnitPrekill.Add(OnUnitPrekill) end
if GameEvents.UnitCreated ~= nil then GameEvents.UnitCreated.Add(OnUnitCreated) end
if GameEvents.BattleStarted ~= nil then GameEvents.BattleStarted.Add(OnBattleStarted) end
if GameEvents.BattleJoined ~= nil then GameEvents.BattleJoined.Add(OnBattleJoined) end
if GameEvents.BattleFinished ~= nil then GameEvents.BattleFinished.Add(OnBattleFinished) end
if GameEvents.CityCaptureComplete ~= nil then GameEvents.CityCaptureComplete.Add(OnCityCaptureComplete) end
if Events.SequenceGameInitComplete ~= nil then Events.SequenceGameInitComplete.Add(Initialize) end

Initialize()
