--[[ Free multicharacter: list / preview / create / play / delete. Every request is checked here. ]]

local V = Config.validation
local last = {}
local onScreen = {}

local function throttle(src, key, ms)
    local k = src .. ':' .. key
    local now = GetGameTimer()
    if (last[k] or 0) > now then return false end
    last[k] = now + ms
    return true
end

AddEventHandler('playerDropped', function()
    local p = source .. ':'
    for k in pairs(last) do if k:sub(1, #p) == p then last[k] = nil end end
    onScreen[source] = nil
end)

local function log(title, text, color)
    if SvConfig.webhook == '' then return end
    PerformHttpRequest(SvConfig.webhook, function() end, 'POST', json.encode({
        username = SvConfig.botName,
        embeds = { { title = title, description = text, color = color, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } },
    }), { ['Content-Type'] = 'application/json' })
end

local function licenses(src)
    return GetPlayerIdentifierByType(src, 'license2'), GetPlayerIdentifierByType(src, 'license')
end

local function decode(v, fallback)
    if type(v) ~= 'string' then return v or fallback end
    local ok, r = pcall(json.decode, v)
    return ok and r or fallback
end

local function fetch(src)
    local l2, l1 = licenses(src)
    local rows = MySQL.query.await([[
        SELECT citizenid, cid, charinfo, money, job, UNIX_TIMESTAMP(last_logged_out) AS lastSeen
        FROM players WHERE license = ? OR license = ? ORDER BY cid
    ]], { l2 or '', l1 or '' }) or {}
    local list = {}
    for i, row in ipairs(rows) do
        local info, money, job = decode(row.charinfo, {}), decode(row.money, {}), decode(row.job, {})
        list[#list + 1] = {
            citizenid = row.citizenid,
            slot = tonumber(row.cid) or i,
            firstname = info.firstname or '', lastname = info.lastname or '',
            birthdate = info.birthdate or '', nationality = info.nationality or '',
            gender = tonumber(info.gender) or 0,
            job = job.label or 'Civilian',
            cash = tonumber(money.cash) or 0, bank = tonumber(money.bank) or 0,
            lastSeen = tonumber(row.lastSeen),
        }
    end
    return list
end

local function owns(src, citizenid)
    if type(citizenid) ~= 'string' or #citizenid > 20 then return false end
    local l2, l1 = licenses(src)
    local owner = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { citizenid })
    return owner ~= nil and (owner == l2 or owner == l1)
end

lib.callback.register('p07free:chars', function(src)
    if not throttle(src, 'chars', 400) or P7H.Framework.IsLoaded(src) then return false end
    return fetch(src), Config.maxSlots
end)

lib.callback.register('p07free:skin', function(src, citizenid)
    if not throttle(src, 'skin', 150) or not owns(src, citizenid) then return end
    return P7H.Appearance.GetSkin(citizenid)
end)

lib.callback.register('p07free:screen', function(src, on)
    if not throttle(src, 'screen', 1000) or P7H.Framework.IsLoaded(src) then return false end
    onScreen[src] = on == true or nil
    P7H.Framework.SetBucket(src, on == true and (2000 + src) or 0)
    return true
end)

-- ── create ─────────────────────────────────────────────────────────────

local function name(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if #v < V.minName or #v > V.maxName or not v:match("^[%a][%a%-']*$") then return nil end
    local low = v:lower()
    for _, w in ipairs(V.blockedWords) do if low:find(w, 1, true) then return nil end end
    return v:sub(1, 1):upper() .. v:sub(2):lower()
end

local function giveStarter(src)
    for _, it in ipairs(Config.starterItems) do P7H.Inventory.AddItem(src, it.name, it.amount) end
end

lib.callback.register('p07free:create', function(src, data)
    if not throttle(src, 'create', 3000) or not onScreen[src] or P7H.Framework.IsLoaded(src) then return false, 'Try again' end
    if type(data) ~= 'table' then return false, 'Fill in every field' end
    local first, lastName = name(data.firstname), name(data.lastname)
    if not first or not lastName then return false, 'Names: letters only, ' .. V.minName .. '-' .. V.maxName .. ' long' end
    local y, m, d = tostring(data.birthdate or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or y < V.minYear or y > V.maxYear or m < 1 or m > 12 or d < 1 or d > 31 then return false, 'Birth date: YYYY-MM-DD' end
    local nat = type(data.nationality) == 'string' and data.nationality:match("^[%a%s%-']+$") and data.nationality:sub(1, 30)
    if not nat then return false, 'Nationality: letters only' end
    local gender = tonumber(data.gender) == 1 and 1 or 0

    local list = fetch(src)
    if #list >= Config.maxSlots then return false, 'No free slot' end
    local used, slot = {}, nil
    for _, c in ipairs(list) do used[c.slot] = true end
    for i = 1, Config.maxSlots do if not used[i] then slot = i break end end

    local ok = P7H.Framework.Login(src, nil, { charinfo = {
        firstname = first, lastname = lastName, nationality = nat, gender = gender,
        birthdate = ('%04d-%02d-%02d'):format(y, m, d), cid = slot,
    } })
    if not ok or not P7H.Framework.IsLoaded(src) then return false, 'Could not create the character' end
    onScreen[src] = nil
    P7H.Framework.SetBucket(src, 0)
    CreateThread(function() Wait(1500) giveStarter(src) end)

    local pd = P7H.Framework.GetPlayerDataOf(src)
    log('Character created', ('**%s** created **%s %s** `%s`'):format(GetPlayerName(src), first, lastName, pd and pd.citizenid or '?'), 3066993)
    return true
end)

-- ── play / delete ──────────────────────────────────────────────────────

lib.callback.register('p07free:play', function(src, citizenid)
    if not throttle(src, 'play', 2000) or not onScreen[src] or P7H.Framework.IsLoaded(src) then return false end
    if not owns(src, citizenid) then
        log('Blocked character load', ('**%s** tried to load `%s` (not theirs)'):format(GetPlayerName(src), tostring(citizenid)), 15158332)
        return false
    end
    if not P7H.Framework.Login(src, citizenid) then return false end
    onScreen[src] = nil
    P7H.Framework.SetBucket(src, 0)
    log('Character loaded', ('**%s** is playing `%s`'):format(GetPlayerName(src), citizenid), 3447003)
    return true, P7H.Framework.GetPosition(src)
end)

lib.callback.register('p07free:delete', function(src, citizenid)
    if not Config.allowDelete then return false end
    if not throttle(src, 'delete', 3000) or not onScreen[src] or P7H.Framework.IsLoaded(src) or not owns(src, citizenid) then return false end
    P7H.Framework.DeleteCharacter(citizenid)
    log('Character deleted', ('**%s** deleted `%s`'):format(GetPlayerName(src), citizenid), 15105570)
    return true
end)

RegisterNetEvent('p07free:exit', function()
    DropPlayer(source, 'See you soon.')
end)
