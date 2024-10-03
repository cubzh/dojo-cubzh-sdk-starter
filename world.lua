Modules = {
    dojo = "github.com/caillef/cubzh-library/dojo"
}

local worldInfo = {
    rpc_url = "http://localhost:5050",
    torii_url = "http://localhost:8080",
    world = "0x5d475a9221f6cbf1a016b12400a01b9a89935069aecd57e9876fcb2a7bb29da",
    actions = "0x025d128c5fe89696e7e15390ea58927bbed4290ae46b538b28cfc7c2190e378b",
    playerAddress = "0xb3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca",
    playerSigningKey = "0x2bbf4f9fd0bbb2e60b0316c1fe0b76cf7a4d0198bd493ced9b8df2a3a24d68a",
}

-- CONSTANTS
local Direction = {
    Left = 1,
    Right = 2,
    Up = 3,
    Down = 4,
}
local avatarNames = { "caillef", "aduermael", "gdevillele", "claire", "soliton", "buche", "voxels", "petroglyph" }

-- GLOBAL VARIABLES
local entities = {}

Client.OnStart = function()
    -- init map
    map = MutableShape()
    for z = -10, 10 do
        for x = -10, 10 do
            map:AddBlock((x + z) % 2 == 0 and Color(63, 155, 10) or Color(48, 140, 4), x, 0, z)
        end
    end
    map:SetParent(World)
    map.Scale = 5
    map.Pivot.Y = 1

    -- init camera
    Camera:SetModeFree()
    Camera.Position = { 0, 40, -50 }
    Camera.Rotation.X = math.pi * 0.25

    -- create Torii client
    worldInfo.onConnect = initBurners
    dojo:createToriiClient(worldInfo)
end

function createEntity(key, position, moves)
    local avatarIndex = tonumber(key) % #avatarNames
    local avatar = require("avatar"):get(avatarNames[avatarIndex])
    avatar.Scale = 0.2
    avatar:SetParent(World)
    avatar.Position = { 0.5 * map.Scale.X, 0, 0.5 * map.Scale.Z }
    avatar.Rotation.Y = math.pi
    avatar.Physics = PhysicsMode.Disabled

    entity = {
        key = key,
        position = position,
        moves = moves,
        originalPos = { x = 10, y = 10 },
        avatar = avatar
    }
    entities[key] = entity
    return entity
end

getOrCreatePlayerEntity = function(key, position)
    local entity = entities[key]
    if not entity then
        entity = createEntity(key, position)
    end

    entity.update = function(self, position)
        if not position then return end
        local avatar = self.avatar

        avatar.Position = {
            ((position.vec.value.x.value - self.originalPos.x) + 0.5) * map.Scale.X,
            0,
            (-(position.vec.value.y.value - self.originalPos.y) + 0.5) * map.Scale.Z
        }

        self.position = position
    end

    return entity
end

function updatePosition(key, position)
    print("A")
    if not position then return end
    print("B")
    local player = getOrCreatePlayerEntity(key, position)
    print("C")

    if player then
        player:update(position)
        print("D")
    end
end

function updateRemainingMoves(key, moves)
    print("1")

    if not moves then return end

    print("2")
    local entity = entities[key]
    if not entity then
        print("3")

        entity = createEntity(key, nil, moves)
    end

    print("4")

    entity.moves = moves
    local avatar = entity.avatar

    -- Rotate avatar based on latest direction
    if moves.last_direction.value.option == "Left" then avatar.Rotation.Y = math.pi * -0.5 end
    if moves.last_direction.value.option == "Right" then avatar.Rotation.Y = math.pi * 0.5 end
    if moves.last_direction.value.option == "Up" then avatar.Rotation.Y = 0 end
    if moves.last_direction.value.option == "Down" then avatar.Rotation.Y = math.pi end

    print("5")

    -- Check if is local player
    local myAddress = dojo.burnerAccount.Address
    local isLocalPlayer = myAddress == moves.player.value
    if not isLocalPlayer then return end

    print("6")

    if remainingMoves then
        remainingMoves.Text = string.format("Remaining moves: %d", moves.remaining.value)
    end
end

local onEntityUpdateCallbacks = {
    ["dojo_starter-Position"] = updatePosition,
    ["dojo_starter-Moves"] = updateRemainingMoves,
}

function initBurners(toriiClient)
    -- get latest burner or deploy a new one
    local json = toriiClient:GetBurners()
    local burners = json.burners

    local createBurnerCallback = function(success, errorMessage)
        if not success then
            error(errorMessage)
            return
        end
        startGame()
    end

    -- no burner, create a new one
    if not burners then
        dojo:createBurner(worldInfo, createBurnerCallback)
        return
    end

    -- get latest burner
    local lastBurner = burners[1]
    toriiClient:CreateAccount(lastBurner.publicKey, lastBurner.privateKey, function(success, burnerAccount)
        if not success then
            -- can't recreate latest burner, making a new one
            dojo:createBurner(worldInfo, createBurnerCallback)
            return
        end
        dojo.burnerAccount = burnerAccount

        -- test if burner valid (not valid if new katana deployed for example)
        dojoActions.spawn(function(error)
            if error == "ContractNotFound" then
                print("new katana deployed! creating a new burner")
                dojo:createBurner(worldInfo, createBurnerCallback)
                return
            end
            startGame()
        end)
    end)
end

function startGame()
    -- add callbacks for all existing entities
    dojo:syncEntities(onEntityUpdateCallbacks)
    -- add callbacks when an entity is updated
    dojo:setOnEntityUpdateCallbacks(onEntityUpdateCallbacks)

    -- call spawn method
    dojoActions.spawn()

    -- init ui
    ui = require("uikit")
    remainingMoves = ui:createText("Remaining moves: 50", Color.White, "big")
    remainingMoves.parentDidResize = function()
        local x = Screen.Width - remainingMoves.Width - 5
        local y = Screen.Height - remainingMoves.Height - Screen.SafeArea.Top
        remainingMoves.pos = { x, y }
    end
    remainingMoves:parentDidResize()
end

Client.DirectionalPad = function(dx, dy)
    if dx == -1 then
        dojoActions.move(Direction.Left)
    elseif dx == 1 then
        dojoActions.move(Direction.Right)
    elseif dy == 1 then
        dojoActions.move(Direction.Up)
    elseif dy == -1 then
        dojoActions.move(Direction.Down)
    end
end

-- todo: generate from manifest.json
dojoActions = {
    spawn = function(callback)
        if not dojo.toriiClient then return end
        dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "spawn", "[]", callback)
    end,
    move = function(dir)
        if not dojo.toriiClient then return end
        local calldata = string.format("[\"%d\"]", dir)
        dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "move", calldata)
    end,
}
