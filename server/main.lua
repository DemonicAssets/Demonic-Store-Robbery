local rewards = require 'server.rewards'

local globalCooldown = 0
local registerCooldowns = {}
local safeCooldowns = {}
local activeLocks = {}        -- locks while interacting
local safeStates   = {}       -- id -> { coords=vector3, ready=false, armedBy=src, claimed=false }

local function now() return os.time() end

local function setCooldown(tbl, id, seconds) tbl[id] = now() + seconds end
local function isOnCooldown(tbl, id) local t = tbl[id]; return t and t > now() end
local function remaining(tbl, id) local t = tbl[id]; return t and math.max(0, t - now()) or 0 end

local function nearEnough(src, coords)
    local ped = GetPlayerPed(src)
    local p = GetEntityCoords(ped)
    return #(p - vector3(coords.x, coords.y, coords.z)) <= (Config.InteractRadius or 1.5) + 0.5
end

-- --- callbacks --- --
lib.callback.register('Demonic_Store_Robbery:server:hasAnyItem', function(src, items)
    local has = Bridge.HasAnyItem(src, items or {})
    return has
end)

-- ========== REGISTER FLOW ==========
lib.callback.register('Demonic_Store_Robbery:server:startRegister', function(src, id, coords, weaponHash)
    if isOnCooldown(registerCooldowns, id) then
        return false, ('Register cooling down (%ds)'):format(remaining(registerCooldowns, id))
    end
    local cops = tonumber(Bridge.CountCops()) or 0
    if cops < (Config.MinCops or 0) then
        return false, ('Not enough police (%d/%d)'):format(cops, Config.MinCops or 0)
    end
    if Config.RequireWeaponForRegister then
        local ped = GetPlayerPed(src)
        local sel = GetSelectedPedWeapon(ped)
        if sel == `WEAPON_UNARMED` or not sel then
            return false, 'You need to brandish a weapon.'
        end
    end
    if activeLocks[id] and activeLocks[id] ~= src then
        return false, 'Someone is already rifling through this register.'
    end
    if not nearEnough(src, coords) then
        return false, 'Too far from register.'
    end

    activeLocks[id] = src
    do local __ok = Bridge.DispatchStoreRobbery(src, coords); if not __ok then Bridge.SendDispatch('Store Robbery', 'Register alarm triggered', coords) end end

    local base = 7000
    if Config.Anim and Config.Anim.Register and Config.Anim.Register.duration then base = Config.Anim.Register.duration end
    local duration = math.floor(base * (1.0 + math.min(cops, 6) * 0.03))
    return true, nil, duration
end)

RegisterNetEvent('Demonic_Store_Robbery:server:cancel', function(id)
    local src = source
    if activeLocks[id] == src then
        activeLocks[id] = nil
    end
end)

RegisterNetEvent('Demonic_Store_Robbery:server:finishRegister', function(id)
    local src = source
    if activeLocks[id] ~= src then return end
    activeLocks[id] = nil

    setCooldown(registerCooldowns, id, Config.RegisterCooldown or 300)
    globalCooldown = now() + (Config.GlobalCooldown or 120)

    local cops = tonumber(Bridge.CountCops()) or 0
    local reward = rewards.GiveRegisterReward(src, cops)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Register robbed',
        description = Config.RewardMode == 'cash'
            and ('You grabbed $%s.'):format(reward.cash)
            or 'You grabbed the goods.',
        type = 'success'
    })
end)

-- ========== SAFE FLOW (two-stage) ==========
lib.callback.register('Demonic_Store_Robbery:server:startSafe', function(src, id, coords)
    if isOnCooldown(safeCooldowns, id) then
        return false, ('Safe cooling down (%ds)'):format(remaining(safeCooldowns, id))
    end
    local cops = tonumber(Bridge.CountCops()) or 0
    if cops < (Config.MinCops or 0) then
        return false, ('Not enough police (%d/%d)'):format(cops, Config.MinCops or 0)
    end
    if activeLocks[id] and activeLocks[id] ~= src then
        return false, 'Someone is already working on this safe.'
    end
    if not nearEnough(src, coords) then
        return false, 'Too far from safe.'
    end

    activeLocks[id] = src
    safeStates[id] = safeStates[id] or {}
    safeStates[id].coords  = vector3(coords.x, coords.y, coords.z)
    safeStates[id].armedBy = src
    safeStates[id].ready   = false
    safeStates[id].claimed = false

    do local __ok = Bridge.DispatchStoreRobbery(src, coords); if not __ok then Bridge.SendDispatch('Store Robbery', 'Backroom safe alarm triggered', coords) end end
    return true, nil, 0
end)

-- Arm the safe -> start timer -> announce ready -> allow grabbing
RegisterNetEvent('Demonic_Store_Robbery:server:armSafe', function(id)
    local src = source
    local st = safeStates[id]
    if not st or activeLocks[id] ~= src then return end

    -- release the active lock; we’ll gate loot by ready/claimed flags
    activeLocks[id] = nil

    local delay = math.floor((Config.SafeReadyTime or 20) * 1000)
    SetTimeout(delay, function()
        local s = safeStates[id]
        if not s or s.claimed then return end
        s.ready = true
        -- notify all clients this safe is ready to be grabbed
        TriggerClientEvent('Demonic_Store_Robbery:client:safeReady', -1, id, s.coords)
    end)
end)

-- Client asks to claim loot when target appears
RegisterNetEvent('Demonic_Store_Robbery:server:claimSafeLoot', function(id)
    local src = source
    local s = safeStates[id]
    if not s or s.claimed then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Too late', description = 'Nothing left in there.', type = 'error' })
        return
    end
    -- simple proximity validation
    if not nearEnough(src, s.coords) then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Too far', description = 'Get closer to the safe.', type = 'error' })
        return
    end
    if not s.ready then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Not yet', description = 'It hasn’t unlocked.', type = 'error' })
        return
    end

    -- Give rewards, set cooldowns, mark claimed, global cooldown
    s.claimed = true
    setCooldown(safeCooldowns, id, Config.SafeCooldown or 1200)
    globalCooldown = now() + (Config.GlobalCooldown or 120)

    local cops = tonumber(Bridge.CountCops()) or 0
    local reward = rewards.GiveSafeReward(src, cops)

    -- clear client target
    TriggerClientEvent('Demonic_Store_Robbery:client:safeClear', -1, id)

    -- cleanup server state after short delay
    SetTimeout(1000, function() safeStates[id] = nil end)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Safe looted',
        description = Config.RewardMode == 'cash'
            and ('You grabbed $%s.'):format(reward.cash)
            or 'You grabbed the stash.',
        type = 'success'
    })
end)
