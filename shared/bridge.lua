Bridge = {}

-- ---------- Framework detect (no CoreObject required) ----------
local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    return 'qb'
end

Bridge.Framework = detectFramework()

-- small helper to safely call an export; returns nil on failure
local function xcall(res, fn, ...)
    if GetResourceState(res) ~= 'started' then return nil end
    local exp = exports[res]
    if not (exp and exp[fn]) then return nil end
    local ok, ret = pcall(function(...)
        return exp[fn](...)
    end, ...)
    if not ok then return nil end
    return ret
end

-- ---------- Player getters (no CoreObject access) ----------
function Bridge.GetPlayer(src)
    if Bridge.Framework == 'qbx' then
        return xcall('qbx_core', 'GetPlayer', src)
    else
        return xcall('qb-core', 'GetPlayer', src)
    end
end

-- Enumerate players as objects (preferred) or ids
local function getPlayersRaw()
    if Bridge.Framework == 'qbx' then
        local qbPlayers = xcall('qbx_core', 'GetQBPlayers')
        if type(qbPlayers) == 'table' and next(qbPlayers) then
            return qbPlayers, 'objects'
        end
        local ids = xcall('qbx_core', 'GetPlayers') or {}
        return ids, 'ids'
    else
        local qbPlayers = xcall('qb-core', 'GetQBPlayers')
        if type(qbPlayers) == 'table' and next(qbPlayers) then
            return qbPlayers, 'objects'
        end
        local ids = xcall('qb-core', 'GetPlayers') or {}
        return ids, 'ids'
    end
end

-- ---------- Money / Inventory ----------
function Bridge.AddMoney(src, account, amount, reason)
    local p = Bridge.GetPlayer(src)
    if not p or not p.Functions or not p.Functions.AddMoney then return false end
    return p.Functions.AddMoney(account, amount, reason)
end

function Bridge.HasAnyItem(src, items)
    for _, name in ipairs(items or {}) do
        if exports.ox_inventory:GetItem(src, name, nil, true) > 0 then
            return true, name
        end
    end
    return false, nil
end

function Bridge.RemoveItem(src, item, count)
    return exports.ox_inventory:RemoveItem(src, item, count or 1)
end

function Bridge.AddItem(src, item, count, metadata)
    return exports.ox_inventory:AddItem(src, item, count or 1, metadata)
end

-- ---------- Count cops (ALWAYS returns a number; no CoreObject) ----------
function Bridge.CountCops()
    local policeNames = {}
    for _, n in ipairs(Config.PoliceJobs or {}) do policeNames[n] = true end

    local ok, result = pcall(function()
        local list, mode = getPlayersRaw()
        local count = 0

        if mode == 'objects' then
            for _, p in pairs(list) do
                local job = p and p.PlayerData and p.PlayerData.job
                if job and job.onduty and policeNames[job.name] then
                    count = count + 1
                end
            end
        else
            for k, v in pairs(list) do
                local src = tonumber(v) or tonumber(k)
                if src then
                    local p = Bridge.GetPlayer(src)
                    local job = p and p.PlayerData and p.PlayerData.job
                    if job and job.onduty and policeNames[job.name] then
                        count = count + 1
                    end
                end
            end
        end
        return count
    end)

    if not ok then
        print('[Demonic_Store_Robbery] CountCops error:', result)
        return 0
    end
    return tonumber(result) or 0
end

-- ---------- Dispatch bridges (ps-/qb-dispatch only) ----------
local function psDispatch(coords, title, message)
    if GetResourceState('ps-dispatch') ~= 'started' then return false end
    local ok = pcall(function()
        exports['ps-dispatch']:CustomAlert({
            coords = coords,
            message = message,
            codeName = title,
            cooldown = 1
        })
    end)
    return ok
end

local function qbDispatch(coords, title, message)
    if GetResourceState('qb-dispatch') ~= 'started' then return false end
    local ok = pcall(function()
        exports['qb-dispatch']:CustomAlert({
            coords = coords,
            dispatchcodename = title,
            message = message
        })
    end)
    return ok
end


-- Prefer ps-dispatch when available; if called server-side, proxy to client so it can use client exports
function Bridge.DispatchStoreRobbery(src, coords, camId)
    if GetResourceState('ps-dispatch') == 'started' then
        if IsDuplicityVersion() then
            -- server context -> bounce to robber's client
            if src and src > 0 then
                TriggerClientEvent('Demonic_Store_Robbery:client:psdispatch:store', src, { coords = coords, camId = camId })
                return true
            end
        else
            -- client context -> call export directly
            local ok = pcall(function()
                if exports['ps-dispatch'] and exports['ps-dispatch'].StoreRobbery then
                    exports['ps-dispatch']:StoreRobbery(camId)
                else
                    exports['ps-dispatch']:CustomAlert({
                        coords = coords,
                        message = 'Store Robbery',
                        dispatchCode = 'storerobbery',
                        code = '10-90',
                        icon = 'fas fa-store',
                        priority = 2
                    })
                end
            end)
            if ok then return true end
        end
    end
    return false
end

function Bridge.SendDispatch(title, msg, coords)
    if psDispatch(coords, title, msg) then return end
    if qbDispatch(coords, title, msg) then return end

    -- Fallback to console + chat if no dispatch resource
    print(('[Demonic_Store_Robbery] DISPATCH: %s - %s @ (%.2f, %.2f, %.2f)')
        :format(title, msg, coords.x, coords.y, coords.z))
    TriggerClientEvent('chat:addMessage', -1, {
        args = { '^1Dispatch', ('%s - %s'):format(title, msg) }
    })
end
