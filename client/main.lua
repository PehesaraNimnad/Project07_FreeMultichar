local isOpen, busy = false, false
local cam
local chars, bySlot, maxSlots = {}, {}, Config.maxSlots
local S = Config.scene

local function nui(action, data) SendNUIMessage({ action = action, data = data }) end

local function fade(out, ms)
    if out then DoScreenFadeOut(ms) else DoScreenFadeIn(ms) end
    local t = GetGameTimer() + ms + 500
    while (out and not IsScreenFadedOut() or not out and not IsScreenFadedIn()) and GetGameTimer() < t do Wait(0) end
end

-- ── scene ──────────────────────────────────────────────────────────────

local function placePed()
    local ped = PlayerPedId()
    RequestCollisionAtCoord(S.coords.x, S.coords.y, S.coords.z)
    SetEntityCoordsNoOffset(ped, S.coords.x, S.coords.y, S.coords.z, false, false, false)
    SetEntityHeading(ped, S.coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true, false)
    if S.anim then
        lib.requestAnimDict(S.anim[1], 3000)
        TaskPlayAnim(ped, S.anim[1], S.anim[2], 8.0, 8.0, -1, 1, 0, false, false, false)
    end
end

local function makeCam()
    local h = math.rad(S.coords.w)
    local fwd, right = vec3(-math.sin(h), math.cos(h), 0.0), vec3(math.cos(h), math.sin(h), 0.0)
    local base = vec3(S.coords.x, S.coords.y, S.coords.z)
    local pos = base + fwd * S.distance + vec3(0.0, 0.0, S.height)
    local look = base + right * S.side + vec3(0.0, 0.0, S.height - 0.1)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, S.fov, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamDofStrength(cam, 0.6)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

-- a freemode ped without a head blend renders with no head: characters without a saved look get one of these
local DEFAULT_LOOKS = {
    [0] = {
        model = 'mp_m_freemode_01', props = {},
        headBlend = { shapeFirst = 4, shapeSecond = 0, skinFirst = 4, skinSecond = 0, shapeMix = 0.5, skinMix = 0.5, shapeThird = 0, skinThird = 0, thirdMix = 0 },
        hair = { style = 4, color = 0, highlight = 0, texture = 0 },
        components = {
            { component_id = 3, drawable = 0, texture = 0 }, { component_id = 4, drawable = 10, texture = 0 },
            { component_id = 6, drawable = 10, texture = 0 }, { component_id = 8, drawable = 15, texture = 0 },
            { component_id = 11, drawable = 4, texture = 0 },
        },
    },
    [1] = {
        model = 'mp_f_freemode_01', props = {},
        headBlend = { shapeFirst = 21, shapeSecond = 0, skinFirst = 21, skinSecond = 0, shapeMix = 0.5, skinMix = 0.5, shapeThird = 0, skinThird = 0, thirdMix = 0 },
        hair = { style = 15, color = 0, highlight = 0, texture = 0 },
        components = {
            { component_id = 3, drawable = 3, texture = 0 }, { component_id = 4, drawable = 0, texture = 0 },
            { component_id = 6, drawable = 0, texture = 0 }, { component_id = 8, drawable = 2, texture = 0 },
            { component_id = 11, drawable = 3, texture = 0 },
        },
    },
}

local function setModel(model)
    model = type(model) == 'string' and (tonumber(model) or joaat(model)) or tonumber(model)
    if not model or not IsModelInCdimage(model) then return false end
    if GetEntityModel(PlayerPedId()) ~= model then
        lib.requestModel(model, 10000)
        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
        Wait(0)
    end
    return true
end

--- puts the character's saved look (illenium-appearance) on the player ped, or a default look with a head
local function dress(char)
    if char and char.citizenid then
        local skin, model = lib.callback.await('p07free:skin', false, char.citizenid)
        if skin and setModel(model or skin.model) then
            P7H.Appearance.ApplyToPed(PlayerPedId(), skin)
            placePed()
            return
        end
    end
    local look = DEFAULT_LOOKS[char and char.gender == 1 and 1 or 0]
    setModel(look.model)
    P7H.Appearance.ApplyToPed(PlayerPedId(), look)
    placePed()
end

local function show(char)
    if busy then return end
    busy = true
    nui('busy', true)
    fade(true, 250)
    dress(char)
    fade(false, 400)
    busy = false
    nui('busy', false)
end

local function fetch()
    local list, max = lib.callback.await('p07free:chars', false)
    if list then
        chars, maxSlots = list, max or Config.maxSlots
        bySlot = {}
        for _, c in ipairs(chars) do bySlot[c.slot] = c end
    end
end

local function open()
    if isOpen then return end
    isOpen = true
    DoScreenFadeOut(0)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DisplayRadar(false)
    lib.callback.await('p07free:screen', false, true)
    P7H.Weather.Pause(true, S.weather)
    P7H.Weather.Show(S.weather, S.hour, S.minute)

    fetch()
    dress(chars[1] or { gender = 0 })
    makeCam()
    SetNuiFocus(true, true)
    nui('open', { characters = chars, maxSlots = maxSlots, allowDelete = Config.allowDelete })
    fade(false, 1200)
end

--- camera back to the game, ped free (no spawn)
local function cleanup()
    isOpen = false
    SetNuiFocus(false, false)
    nui('close')
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
    P7H.Weather.Pause(false)
end

local function teleport(c)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    local t = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
end

-- ── NUI ────────────────────────────────────────────────────────────────

RegisterNUICallback('select', function(d, cb)
    cb(1)
    local slot = tonumber(d.slot)
    if isOpen and slot and slot >= 1 and slot <= maxSlots then CreateThread(function() show(bySlot[slot] or { gender = 0 }) end) end
end)

-- the create form shows a male / female body while typing
RegisterNUICallback('preview', function(d, cb)
    cb(1)
    if isOpen and not busy then CreateThread(function() show({ gender = tonumber(d.gender) == 1 and 1 or 0 }) end) end
end)

RegisterNUICallback('play', function(d, cb)
    local char = bySlot[tonumber(d.slot)]
    if not isOpen or busy or not char then return cb({ ok = false }) end
    busy = true
    fade(true, 700)
    local ok, pos = lib.callback.await('p07free:play', false, char.citizenid)
    if not ok then
        busy = false
        fade(false, 400)
        return cb({ ok = false, error = 'Could not load this character' })
    end
    cb({ ok = true })
    cleanup()
    busy = false
    if P7H.Spawn.Open(false) then return end
    teleport(pos and vec4(pos.x, pos.y, pos.z, pos.w or 0.0) or Config.newCharacter)
    P7H.Framework.TriggerPlayerLoaded()
    fade(false, 1000)
end)

RegisterNUICallback('create', function(d, cb)
    if not isOpen or busy then return cb({ ok = false }) end
    local ok, err = lib.callback.await('p07free:create', false, d)
    if not ok then return cb({ ok = false, error = err }) end
    cb({ ok = true })
    busy = true
    fade(true, 700)
    dress({ gender = tonumber(d.gender) == 1 and 1 or 0 })
    cleanup()
    busy = false
    if P7H.Spawn.Open(true) then return end
    teleport(Config.newCharacter)
    P7H.Framework.TriggerPlayerLoaded()
    fade(false, 1000)
    Wait(600)
    P7H.Appearance.OpenCreator()
end)

RegisterNUICallback('delete', function(d, cb)
    local char = bySlot[tonumber(d.slot)]
    if not isOpen or busy or not char then return cb({ ok = false }) end
    if not lib.callback.await('p07free:delete', false, char.citizenid) then return cb({ ok = false, error = 'Could not delete' }) end
    fetch()
    cb({ ok = true, characters = chars, maxSlots = maxSlots })
    CreateThread(function() show(chars[1] or { gender = 0 }) end)
end)

RegisterNUICallback('exit', function(_, cb)
    cb(1)
    if Config.exitAction == 'quit' then QuitGame() else TriggerServerEvent('p07free:exit') end
end)

-- an admin changed this account's slots while the screen is open
RegisterNetEvent('p07free:refresh', function()
    if not isOpen then return end
    fetch()
    nui('open', { characters = chars, maxSlots = maxSlots, allowDelete = Config.allowDelete })
end)

-- ── start / logout ─────────────────────────────────────────────────────

RegisterNetEvent(P7H.Framework.LoggedOutEvent, function()
    if GetInvokingResource() then return end
    CreateThread(function()
        DoScreenFadeOut(500)
        Wait(600)
        open()
    end)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    Wait(250)
    if LocalPlayer.state.isLoggedIn then return end
    open()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= cache.resource or not isOpen then return end
    if cam then RenderScriptCams(false, false, 0, true, true) end
    DoScreenFadeIn(0)
end)
