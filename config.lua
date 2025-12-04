Config = Config or {}

-- Framework + jobs
Config.Framework  = Config.Framework  or 'auto'        -- 'auto' | 'qb' | 'qbx'
Config.PoliceJobs = Config.PoliceJobs or { 'police', 'sasp', 'bcso' }

-- Interactions
Config.UseTarget     = true
Config.RegisterLabel = 'Rob Register'
Config.SafeLabel     = 'Crack Safe'

-- Requirements
Config.MinCops = Config.MinCops or 0
Config.RequireWeaponForRegister = false
Config.RegisterWeapons = Config.RegisterWeapons or { 'weapon_pistol', 'weapon_combatpistol', 'weapon_pistol_mk2' }

Config.RequireLockpick = true
Config.LockpickItems = { 'advancedlockpick', 'lockpick' }

Config.RequireDrillForSafe = true
Config.DrillItems = { 'safecracker' }

-- Skill checks (ox_lib)
Config.RegisterSkill = Config.RegisterSkill or { difficulty = { 'easy','easy','medium' }, inputs = { 'W','A','S','D' } }
Config.SafeSkill     = Config.SafeSkill     or { difficulty = { 'easy','easy','easy','easy' }, inputs = { 'W','A','S','D' } }

-- Cooldowns (seconds)
Config.GlobalCooldown   = Config.GlobalCooldown   or 120
Config.RegisterCooldown = Config.RegisterCooldown or 300
Config.SafeCooldown     = Config.SafeCooldown     or 1200

-- Distances / cancel bounds
Config.InteractRadius  = Config.InteractRadius  or 1.5
Config.CancelIfMoves   = true
Config.MaxMoveDistance = Config.MaxMoveDistance or 3.0

-- Rewards
Config.RewardMode = Config.RewardMode or 'items' -- 'cash' | 'items'
Config.CashAccount = Config.CashAccount or 'cash'
Config.CashRangeRegister = Config.CashRangeRegister or { 250, 600 }
Config.CashRangeSafe     = Config.CashRangeSafe     or { 1500, 3000 }

-- Item rewards (ox_inventory)
Config.ItemRewardsRegister = {
    { item = 'black_money', chance = 100, min = 10, max = 25 },
}
Config.ItemRewardsSafe = {
    { item = 'securitycard_green',     chance = 5, min = 1, max = 1 },
    { item = 'black_money', chance = 100, min = 30, max = 50 },
}

-- Dispatch (ps-dispatch / qb-dispatch only; frenzy_mdt was removed)
Config.Dispatch = Config.Dispatch or {
    AlertRadius = 50.0,
    AlertBlipTime = 60
}

-- Animations
Config.Anim = {
    Register = {
        duration = 7000,
        flag = 49,
        fallbacks = {
            { dict = 'oddjobs@shop_robbery@rob_till', name = 'loop' },
            { dict = 'oddjobs@shop_robbery@rob_till', name = 'enter' },
            { dict = 'amb@prop_human_bum_bin@idle_b', name = 'idle_d' },
            { dict = 'amb@prop_human_bum_bin@base',   name = 'base' },
        },
        scenarioFallback = 'WORLD_HUMAN_STAND_IMPATIENT',
        prop = nil
    },
    -- Safe has no animation in the new flow
}

-- SAFE READY FLOW (new)
Config.SafeInstantLoot = true          -- no anim; use timed “ready to loot” flow
Config.SafeReadyTime   = 5            -- seconds after crack before loot can be grabbed
Config.SafeReadySound  = {             -- sound played at the safe when it becomes lootable
    name = 'CHECKPOINT_PERFECT',
    set  = 'HUD_MINI_GAME_SOUNDSET'
}
Config.SafeGrabLabel   = 'Grab Safe Loot' -- label for the temporary target option
