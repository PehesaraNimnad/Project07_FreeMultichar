Config = {}

Config.maxSlots = 4                -- slots every account starts with
Config.slotLimit = 10              -- most slots an admin can give one account
Config.allowDelete = true

-- /logout: back to the character screen; /logout <id>: admins only
-- /addcharslot <id> [amount], /removecharslot <id> [amount]: admins only (extra slots are saved per account)
Config.commands = {
    logout = 'logout',
    addSlot = 'addcharslot',
    removeSlot = 'removecharslot',
}
Config.playerLogout = true         -- false: only admins can use /logout
Config.exitAction = 'disconnect'   -- 'disconnect' or 'quit'

-- The one scene: where the character stands and how the camera frames it (character on the right, text on the left)
Config.scene = {
    coords = vec4(-1850.3, -1250.8, 8.6, 140.0),   -- Del Perro pier
    weather = 'EXTRASUNNY',
    hour = 19, minute = 40,
    distance = 2.6,        -- camera in front of the character (m)
    height = 0.35,         -- camera height above the waist (m)
    side = 0.95,           -- look this far to the character's right: the character sits on the right of the screen
    fov = 34.0,
    anim = { 'anim@amb@nightclub@peds@', 'rcmme_amanda1_stand_loop_cop' }, -- idle pose (false = none)
}

-- New characters start here when no spawn selector runs
Config.newCharacter = vec4(-1037.7, -2737.6, 20.17, 330.0)    -- airport

Config.starterItems = {
    { name = 'phone', amount = 1 },
    { name = 'id_card', amount = 1 },
}

Config.validation = {
    minName = 2, maxName = 16,
    minYear = 1940, maxYear = 2008,
    blockedWords = { 'admin', 'moderator', 'staff' },
}
