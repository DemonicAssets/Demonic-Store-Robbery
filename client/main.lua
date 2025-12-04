local lib = lib
local currentActions = {}

-- Ensure Targets table exists
Targets = Targets or { Registers = {}, Safes = {} }

-- ===== helpers =====
-- ===== normalize Targets when using per-store groups =====


-- ===== normalize Targets when using per-store groups =====
local function normalizeTargets()
    if Targets and Targets.Stores then
        Targets.Registers = {}
        Targets.Safes = {}
        for storeId, store in pairs(Targets.Stores) do
            if store and store.enabled ~= false then
                if store.registers then
                    for i, reg in ipairs(store.registers) do
                        local rid = reg.id or ('reg'..tostring(i))
                        Targets.Registers[#Targets.Registers+1] = {
                            id = (storeId .. '_' .. rid),
                            coords = reg.coords,
                            store = storeId,
                            label = store.label or storeId
                        }
                    end
                end
                if store.safes then
                    for i, safe in ipairs(store.safes) do
                        local sid = safe.id or ('safe'..tostring(i))
                        Targets.Safes[#Targets.Safes+1] = {
                            id = (storeId .. '_' .. sid),
                            coords = safe.coords,
                            store = storeId,
                            label = store.label or storeId
                        }
                    end
                end
            end
        end
    end
end

normalizeTargets()

-- ===== inventory requirement cache (for target visibility) =====
local HaveLockpick, HaveDrill, HaveWeapon = true, true, true

local function hasAnyItems(list)
    if not list or #list == 0 then return true end
    for i = 1, #list do
        local count = exports.ox_inventory:Search('count', list[i]) or 0
        if count > 0 then return true end
    end
    return false
end

CreateThread(function()
    while true do
        if Config.RequireLockpick then
            HaveLockpick = hasAnyItems(Config.LockpickItems or {})
        else
            HaveLockpick = true
        end

        if Config.RequireDrillForSafe then
            HaveDrill = hasAnyItems(Config.DrillItems or {})
        else
            HaveDrill = true
        end

        if Config.RequireWeaponForRegister then
            local current = GetSelectedPedWeapon(cache.ped)
            HaveWeapon = false
            for i = 1, #(Config.RegisterWeapons or {}) do
                local name = Config.RegisterWeapons[i]
                if current == joaat(name) or (exports.ox_inventory:Search('count', name) or 0) > 0 then
                    HaveWeapon = true
                    break
                end
            end
        else
            HaveWeapon = true
        end

        Wait(800)
    end
end)


-- ===== ps-dispatch proxy (server bounces to robber client) =====
RegisterNetEvent('Demonic_Store_Robbery:client:psdispatch:store', function(data)
    if GetResourceState('ps-dispatch') ~= 'started' then return end
    local camId = data and data.camId or nil
    local ok = pcall(function()
        if exports['ps-dispatch'] and exports['ps-dispatch'].StoreRobbery then
            exports['ps-dispatch']:StoreRobbery(camId)
        else
            exports['ps-dispatch']:CustomAlert({
                coords = data.coords or GetEntityCoords(cache.ped),
                message = 'Store Robbery',
                dispatchCode = 'storerobbery',
                code = '10-90',
                icon = 'fas fa-store',
                priority = 2
            })
        end
    end)
end)

local function attachProp(ped, prop)
    if not prop then return nil end
    local model = joaat(prop.model)
    if not lib.requestModel(model, 2500) then return nil end
    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, prop.bone),
        prop.pos.x, prop.pos.y, prop.pos.z,
        prop.rot.x, prop.rot.y, prop.rot.z,
        true, true, false, true, 2, true)
    return obj
end

local function resolveAnim(actionCfg)
    local fallbacks = (actionCfg and actionCfg.fallbacks) or {}
    for _, a in ipairs(fallbacks) do
        if a.dict and a.name then
            if lib.requestAnimDict(a.dict, 2500) then
                return { dict = a.dict, name = a.name, flag = actionCfg.flag or 49, duration = actionCfg.duration or 5000 }
            end
        end
    end
    return nil
end

local function playAction(actionCfg)
    local ped = cache.ped
    local anim = resolveAnim(actionCfg)
    if anim then
        local obj = attachProp(ped, actionCfg.prop)
        TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, anim.duration, anim.flag, 0.0, false, false, false)
        return { mode = 'anim', obj = obj, duration = anim.duration }
    else
        -- fallback mini idle if nothing loads
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        return { mode = 'scenario', obj = nil, duration = (actionCfg and actionCfg.duration) or 5000 }
    end
end

local function stopAction(state)
    ClearPedTasks(cache.ped)
    if state and state.obj and DoesEntityExist(state.obj) then
        DeleteObject(state.obj)
    end
end

local function distance(a, b)
    return #(vec3(a.x, a.y, a.z) - vec3(b.x, b.y, b.z))
end

-- hard freeze helpers
local function hardFreeze(ped, state)
    FreezeEntityPosition(ped, state)
    SetEntityInvincible(ped, state)
    SetPedCanRagdoll(ped, not state)
    if state then ClearPedTasksImmediately(ped) end
end

local function disableControlsTick()
    DisableControlAction(0, 24, true)  -- attack
    DisableControlAction(0, 25, true)  -- aim
    DisableControlAction(0, 22, true)  -- jump
    DisableControlAction(0, 21, true)  -- sprint
    DisableControlAction(0, 32, true)  -- W
    DisableControlAction(0, 33, true)  -- S
    DisableControlAction(0, 34, true)  -- A
    DisableControlAction(0, 35, true)  -- D
    DisableControlAction(0, 30, true)  -- analog lr
    DisableControlAction(0, 31, true)  -- analog ud
    DisableControlAction(0, 44, true)  -- cover
    DisableControlAction(0, 289, true) -- F2
    DisableControlAction(0, 170, true) -- F3
    DisableControlAction(0, 166, true) -- F5
end

-- ===== temporary safe-loot zones =====
local SafeLootZones = {}  -- id -> zoneId

RegisterNetEvent('Demonic_Store_Robbery:client:safeReady', function(id, coords)
    -- play “ready” sound at safe
    local snd = Config.SafeReadySound or { name='CHECKPOINT_PERFECT', set='HUD_MINI_GAME_SOUNDSET' }
    PlaySoundFromCoord(-1, snd.name or 'CHECKPOINT_PERFECT', coords.x, coords.y, coords.z, snd.set or 'HUD_MINI_GAME_SOUNDSET', false, 0, false)

    -- create a temporary target to grab loot
    local zoneName = ('safe_loot_%s'):format(id)
    local zid = exports.ox_target:addSphereZone({
        coords = coords, size = vec3(0.8, 0.8, 1.0),
        debug = false, drawSprite = true,
        options = {{
            name = zoneName,
            icon = 'fa-solid fa-vault',
            label = Config.SafeGrabLabel or 'Grab Safe Loot',
            distance = 1.5,
            onSelect = function()
                TriggerServerEvent('Demonic_Store_Robbery:server:claimSafeLoot', id)
            end
        }}
    })
    SafeLootZones[id] = zid
    lib.notify({ title = 'Safe ready!', description = 'Grab the loot.', type = 'success' })
end)

RegisterNetEvent('Demonic_Store_Robbery:client:safeClear', function(id)
    local zid = SafeLootZones[id]
    if zid then
        exports.ox_target:removeZone(zid)
        SafeLootZones[id] = nil
    end
end)

-- ===== TARGET SETUP =====
local function addTargets()
    if not Config.UseTarget then return end
    if not Targets or (not Targets.Registers and not Targets.Safes) then
        print('[Demonic_Store_Robbery] No Targets table found; skipping target zones.')
        return
    end

    for _, reg in ipairs(Targets.Registers or {}) do
        exports.ox_target:addSphereZone({
            coords = reg.coords, size = vec3(1.0, 1.0, 1.0),
            debug = false, drawSprite = true,
            options = {{
                name = reg.id,
                icon = 'fa-solid fa-cash-register',
                label = Config.RegisterLabel,

                canInteract = function(entity, distance, coords, name)
                    -- Hide target if required items are missing (ox_inventory client search)
                    local function hasAny(items)
                        if not items or #items == 0 then return true end
                        for i=1,#items do
                            if exports.ox_inventory:Search('count', items[i]) > 0 then
                                return true
                            end
                        end
                        return false
                    end
    
                    if Config.RequireLockpick and not HaveLockpick then
                        return false
                    end
        
                    
                    -- If a weapon is required for registers, ensure the player has/equips one
                    if Config.RequireWeaponForRegister then
                        local function hasAnyWeapon(names)
                            local current = GetSelectedPedWeapon(cache.ped)
                            for i=1,#names do
                                local hash = joaat(names[i])
                                if current == hash or exports.ox_inventory:Search('count', names[i]) > 0 then
                                    return true
                                end
                            end
                            return false
                        end
                        if not HaveWeapon then
                            return false
                        end
                    end
                    return true
                end,
    
                distance = 1.6,
                onSelect = function()
                    TriggerEvent('Demonic_Store_Robbery:client:robRegister', reg)
                end
            }}
        })
    end

    for _, safe in ipairs(Targets.Safes or {}) do
        exports.ox_target:addSphereZone({
            coords = safe.coords, size = vec3(1.0, 1.0, 1.0),
            debug = false, drawSprite = true,
            options = {{
                name = safe.id,
                icon = 'fa-solid fa-vault',
                label = Config.SafeLabel,

                canInteract = function(entity, distance, coords, name)
                    -- Hide target if required items are missing (ox_inventory client search)
                    local function hasAny(items)
                        if not items or #items == 0 then return true end
                        for i=1,#items do
                            if exports.ox_inventory:Search('count', items[i]) > 0 then
                                return true
                            end
                        end
                        return false
                    end
    
                    if Config.RequireDrillForSafe and not HaveDrill then
                        return false
                    end
        
                    return true
                end,
    
                distance = 1.6,
                onSelect = function()
                    TriggerEvent('Demonic_Store_Robbery:client:crackSafe', safe)
                end
            }}
        })
    end
end
CreateThread(addTargets)

-- ===== REGISTER: reserve -> skill -> frozen anim -> finish =====
RegisterNetEvent('Demonic_Store_Robbery:client:robRegister', function(entry)
    if currentActions.register then return end
    currentActions.register = true

    if Config.RequireLockpick then
        local ok = lib.callback.await('Demonic_Store_Robbery:server:hasAnyItem', false, Config.LockpickItems)
        if not ok then
            lib.notify({ title = 'Lockpick required', type = 'error' })
            currentActions.register = nil
            return
        end
    end

    local ok, msg, duration = lib.callback.await('Demonic_Store_Robbery:server:startRegister', false, entry.id, entry.coords, GetSelectedPedWeapon(cache.ped))
    if not ok then
        lib.notify({ title = msg or 'Cannot rob register', type = 'error' })
        currentActions.register = nil
        return
    end

    local passed = lib.skillCheck(Config.RegisterSkill.difficulty, Config.RegisterSkill.inputs)
    if not passed then
        lib.notify({ title = 'You failed to pry it open!', type = 'error' })
        TriggerServerEvent('Demonic_Store_Robbery:server:cancel', entry.id)
        currentActions.register = nil
        return
    end

    local ped = cache.ped
    hardFreeze(ped, true)
    local act = playAction(Config.Anim.Register)
    local start = GetGameTimer()
    while (GetGameTimer() - start) < act.duration do
        Wait(0)
        disableControlsTick()
        if Config.CancelIfMoves and distance(GetEntityCoords(ped), entry.coords) > Config.MaxMoveDistance then
            lib.notify({ title = 'You moved away!', type = 'error' })
            TriggerServerEvent('Demonic_Store_Robbery:server:cancel', entry.id)
            stopAction(act)
            hardFreeze(ped, false)
            currentActions.register = nil
            return
        end
    end
    stopAction(act)
    hardFreeze(ped, false)

    TriggerServerEvent('Demonic_Store_Robbery:server:finishRegister', entry.id)
    currentActions.register = nil
end)

-- ===== SAFE: reserve -> (optional skill) -> ARM timer -> wait for ready -> player targets to grab =====
RegisterNetEvent('Demonic_Store_Robbery:client:crackSafe', function(entry)
    if currentActions.safe then return end
    currentActions.safe = true

    if Config.RequireDrillForSafe then
        local ok = lib.callback.await('Demonic_Store_Robbery:server:hasAnyItem', false, Config.DrillItems)
        if not ok then
            lib.notify({ title = 'You need a SafeCracker', type = 'error' })
            currentActions.safe = nil
            return
        end
    end

    local ok, msg = lib.callback.await('Demonic_Store_Robbery:server:startSafe', false, entry.id, entry.coords)
    if not ok then
        lib.notify({ title = msg or 'Cannot crack safe', type = 'error' })
        currentActions.safe = nil
        return
    end

    -- Keep skill check (delete this block if you want pure “press to arm”)
    if Config.SafeInstantLoot then
        local passed = lib.skillCheck(Config.SafeSkill.difficulty, Config.SafeSkill.inputs)
        if not passed then
            lib.notify({ title = 'You failed to find the combination!', type = 'error' })
            TriggerServerEvent('Demonic_Store_Robbery:server:cancel', entry.id)
            currentActions.safe = nil
            return
        end
    end

    -- Arm the safe: starts the server timer, later server notifies safeReady -> shows Grab Loot target
    TriggerServerEvent('Demonic_Store_Robbery:server:armSafe', entry.id)
    lib.notify({ title = 'Cracked!', description = ('Wait ~%ds for it to unlock…'):format(tonumber(Config.SafeReadyTime or 20)), type = 'inform' })
    currentActions.safe = nil
end)