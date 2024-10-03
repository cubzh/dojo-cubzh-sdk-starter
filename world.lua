local worldInfo = {
    rpc_url = "http://localhost:5050",
    torii_url = "http://localhost:8080",
    world = "0x5d475a9221f6cbf1a016b12400a01b9a89935069aecd57e9876fcb2a7bb29da",
    actions = "0x791c005d5ce51675daeb505b205d4cb4132d1cf5ecf57ea97440c0a2262a5de",
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
    map = MutableShape()
    for z = -10, 10 do
        for x = -10, 10 do
            map:AddBlock((x + z) % 2 == 0 and Color(63, 155, 10) or Color(48, 140, 4), x, 0, z)
        end
    end
    map:SetParent(World)
    map.Scale = 5
    map.Pivot.Y = 1

    Camera:SetModeFree()
    Camera.Position = { 0, 40, -50 }
    Camera.Rotation.X = math.pi * 0.25

    print("createtoriiclient")
    -- create Torii client
    worldInfo.onConnect = startGame
    dojo:createToriiClient(worldInfo)
end

getOrCreatePlayerEntity = function(key, data)
    if not dojo:getModel(data, "dojo_examples-Position") then
        return
    end
    local entity = entities[key]
    if not entity then
        local avatarIndex = tonumber(key) % #avatarNames
        print("avatar index", avatarIndex)
        local avatar = require("avatar"):get(avatarNames[avatarIndex])
        avatar.Scale = 0.2
        avatar:SetParent(World)
        avatar.Position = { 0.5 * map.Scale.X, 0, 0.5 * map.Scale.Z }
        avatar.Rotation.Y = math.pi
        avatar.Physics = PhysicsMode.Disabled

        entity = {
            key = data.Key,
            data = data,
            originalPos = { x = 10, y = 10 },
            avatar = avatar
        }
        entities[key] = entity
    end

    entity.update = function(self, newEntity)
        local avatar = self.avatar

        local moves = dojo:getModel(newEntity, "dojo_examples-Moves")
        if moves then
            if moves.last_direction.value.option == "Left" then avatar.Rotation.Y = math.pi * -0.5 end
            if moves.last_direction.value.option == "Right" then avatar.Rotation.Y = math.pi * 0.5 end
            if moves.last_direction.value.option == "Up" then avatar.Rotation.Y = 0 end
            if moves.last_direction.value.option == "Down" then avatar.Rotation.Y = math.pi end

            local isLocalPlayer = myAddress == moves.player.value
            if remainingMoves and isLocalPlayer then
                remainingMoves.Text = string.format("Remaining moves: %d", moves.remaining.value)
            end
        end

        local position = dojo:getModel(newEntity, "dojo_examples-Position")
        if position then
            avatar.Position = {
                ((position.vec.value.x.value - self.originalPos.x) + 0.5) * map.Scale.X,
                0,
                (-(position.vec.value.y.value - self.originalPos.y) + 0.5) * map.Scale.Z
            }
        end

        self.data = newEntity
    end

    return entity
end

local onEntityUpdateCallbacks = {
    all = function(key, entity)
        if not entity then return end
        print("update", key, JSON:Encode(entity))
        local player = getOrCreatePlayerEntity(key, entity)
        if player then
            player:update(entity)
        end
    end,
    -- we can also listen to specific models
    -- ["dojo_starter-Position"] = updatePosition,
}

function startGame()
    print("start game")
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

-- dojo module

dojo = {}

dojo.createBurner = function(self, config, cb)
    self.toriiClient:CreateBurner(
        config.playerAddress,
        config.playerSigningKey,
        function(success, burnerAccount)
            if not success then
                error("Can't create burner")
                return
            end
            dojo.burnerAccount = burnerAccount
            cb()
        end
    )
end

dojo.createToriiClient = function(self, config)
    dojo.config = config
    local err
    dojo.toriiClient = Dojo:CreateToriiClient(config.torii_url, config.rpc_url, config.world)
    dojo.toriiClient.OnConnect = function(success)
        if not success then
            print("Connection failed")
            return
        end
        local json = dojo.toriiClient:GetBurners()
        local burners = json.burners
        if not burners then
            self:createBurner(config, function()
                config.onConnect(dojo.toriiClient)
            end)
        else
            local lastBurner = burners[1]
            self.toriiClient:CreateAccount(lastBurner.publicKey, lastBurner.privateKey, function(success, burnerAccount)
                if not success then
                    self:createBurner(config, function()
                        config.onConnect(dojo.toriiClient)
                    end)
                    -- error("Can't create burner")
                    return
                end
                dojo.burnerAccount = burnerAccount
                -- -- test if burner valid (not valid if new katana)
                -- local playerPos = Player.Position + Number3(1, 1, 1) * 1000000
                dojoActions.spawn(function(error)
                    if error == "ContractNotFound" then
                        print("new katana deployed! creating a new burner")
                        self:createBurner(config, function()
                            config.onConnect(dojo.toriiClient)
                        end)
                    else
                        print("existing katana")
                        config.onConnect(dojo.toriiClient)
                    end
                end)
            end)
        end
    end
    dojo.toriiClient:Connect()
end

dojo.getModel = function(_, entity, modelName)
    if not entity then
        return
    end
    for key, model in pairs(entity) do
        if key == modelName then
            return model
        end
    end
end

dojo.setOnEntityUpdateCallbacks = function(self, callbacks)
    local clauseJsonStr = '[{ "Keys": { "keys": [], "models": [], "pattern_matching": "VariableLen" } }]'
    self.toriiClient:OnEntityUpdate(clauseJsonStr, function(entityKey, entity)
        for modelName, callback in pairs(callbacks) do
            local model = self:getModel(entity, modelName)
            if modelName == "all" or model then
                callback(entityKey, model, entity)
            end
        end
    end)
end

dojo.syncEntities = function(self, callbacks)
    self.toriiClient:Entities('{ "limit": 1000, "offset": 0 }', function(entities)
        if not entities then
            return
        end
        for entityKey, entity in pairs(entities) do
            for modelName, callback in pairs(callbacks) do
                local model = self:getModel(entity, modelName)
                if model then
                    callback(entityKey, model, entity)
                end
            end
        end
    end)
end

-- todo: generate from manifest.json contracts
dojoActions = {
    spawn = function(callback)
        if not dojo.toriiClient then return end
        print(dojo.burnerAccount, dojo.config.actions, "spawn")
        dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "spawn", "[]", callback)
    end,
    move = function(dir)
        if not dojo.toriiClient then return end
        local calldata = string.format("[\"%d\"]", dir)
        print(dojo.burnerAccount, dojo.config.actions, "move", calldata)
        dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "move", calldata)
    end,
}
