Targets = {}

-- Grouped per-store targets. Each store has its own registers and safes.
-- The client will normalize this into flat Targets.Registers/Safes at runtime.
-- Set enabled=false on any block you haven't filled coords for yet.
Targets.Stores = {
    -- 24/7: Little Seoul
    ['247_1'] = {
        label = '24/7 - Little Seoul',
        enabled = true,
        registers = {
            { id = 'reg1', coords = vec3(24.42, -1346.62, 29.5) },
            { id = 'reg2', coords = vec3(24.89, -1347.32, 29.5) },
        },
        safes = {
            { id = 'safe', coords = vec3(28.27, -1338.47, 29.5) },
        },
    },

    -- 24/7: Great Ocean Highway
    ['247_2'] = {
        label = '24/7 - Great Ocean',
        enabled = true,
        registers = {
            { id = 'reg1', coords = vec3(-3038.62, 584.46, 7.91) },
            { id = 'reg2', coords = vec3(-3039.08, 584.99, 7.91) },
        },
        safes = {
            { id = 'safe', coords = vec3(-3047.70, 585.59, 7.91) },
        },
    },

    -- 24/7: Route 68
    ['247_3'] = {
        label = '24/7 - Route 68',
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
            -- { id = 'reg2', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },

    -- 24/7: Sandy Shores
    ['247_4'] = {
        label = '24/7 - Sandy Shores',
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
            -- { id = 'reg2', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },

    -- LTD: Davis
    ['ltd_davis'] = {
        label = 'LTD - Davis',
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
            -- { id = 'reg2', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },

    -- LTD: Mirror Park
    ['ltd_mirror'] = {
        label = 'LTD - Mirror Park',
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
            -- { id = 'reg2', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },

    -- Rob's Liquor: Vespucci Canals
    ['robs_canals'] = {
        label = "Rob's Liquor - Canals",
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },

    -- Rob's Liquor: Morningwood
    ['robs_morningwood'] = {
        label = "Rob's Liquor - Morningwood",
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },

    -- 24/7: Paleto Bay
    ['247_paleto'] = {
        label = '24/7 - Paleto',
        enabled = false, -- fill coords then set to true
        registers = {
            -- { id = 'reg1', coords = vec3(0,0,0) },
            -- { id = 'reg2', coords = vec3(0,0,0) },
        },
        safes = {
            -- { id = 'safe', coords = vec3(0,0,0) },
        },
    },
}
