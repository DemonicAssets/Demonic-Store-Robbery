local M = {}

local function randRange(r)
    return math.random(r[1], r[2])
end

-- Light scaling with # of cops (max ~+42%)
local function scaleByCops(baseMin, baseMax, cops)
    local factor = 1.0 + math.min(cops or 0, 6) * 0.07
    return math.floor(baseMin * factor), math.floor(baseMax * factor)
end

function M.GiveRegisterReward(src, cops)
    if Config.RewardMode == 'cash' then
        local mn, mx = scaleByCops(Config.CashRangeRegister[1], Config.CashRangeRegister[2], cops)
        local amount = randRange({ mn, mx })
        Bridge.AddMoney(src, Config.CashAccount, amount, 'register robbery')
        return { cash = amount }
    else
        local rewards = {}
        for _, entry in ipairs(Config.ItemRewardsRegister) do
            if math.random(100) <= entry.chance then
                local mn, mx = scaleByCops(entry.min, entry.max, cops)
                local count = randRange({ mn, mx })
                Bridge.AddItem(src, entry.item, count)
                rewards[#rewards+1] = { item = entry.item, count = count }
            end
        end
        return rewards
    end
end

function M.GiveSafeReward(src, cops)
    if Config.RewardMode == 'cash' then
        local mn, mx = scaleByCops(Config.CashRangeSafe[1], Config.CashRangeSafe[2], cops)
        local amount = randRange({ mn, mx })
        Bridge.AddMoney(src, Config.CashAccount, amount, 'safe robbery')
        return { cash = amount }
    else
        local rewards = {}
        for _, entry in ipairs(Config.ItemRewardsSafe) do
            if math.random(100) <= entry.chance then
                local mn, mx = scaleByCops(entry.min, entry.max, cops)
                local count = randRange({ mn, mx })
                Bridge.AddItem(src, entry.item, count)
                rewards[#rewards+1] = { item = entry.item, count = count }
            end
        end
        return rewards
    end
end

return M
