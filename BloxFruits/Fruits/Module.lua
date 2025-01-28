local _ENV = (getgenv or getrenv or getfenv)()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CommF = Remotes:WaitForChild("CommF_")
local CommE = Remotes:WaitForChild("CommE")

local Player = Players.LocalPlayer

local Connections = {} do
  if _ENV.ax_Connections then
    for _, Connection in _ENV.ax_Connections do
      Connection:Disconnect()
    end
  end
  
  _ENV.ax_Connections = Connections
end

local Module = {} do
  local arceus_folder = "ax-hub-folder"
  
  local Cached = {
    Characters = {}
  }
  
  Module.GameData = {
    Sea = ({ [2753915549] = 1, [4442272183] = 2, [7449423635] = 3 })[game.PlaceId] or 0,
    SeasName = { "Main", "Dressrosa", "Zou" },
    MaxMastery = 600,
    MaxLevel = 2600,
  }
  
  function Module.IsAlive(Character: Model): boolean
    local Humanoid = Cached.Characters[Character] or Character:FindFirstChildOfClass("Humanoid")
    
    if Humanoid then
      Cached.Characters[Character] = Humanoid
      return Humanoid.Health > 0
    end
  end
  
  function Module.FireRemote(...)
    return CommF:InvokeServer(...)
  end
  
  function Module:TravelTo(Sea: number?): (nil)
    Module.FireRemote(`Travel{self.GameData.SeasName[Sea]}`)
  end
  
  function Module:SaveCurrentServer()
    return pcall(function()
      local Servers = HttpService:JSONDecode(readfile(`{arceus_folder}/ServersLog.json`) or "[]")
      
      for id, time in pairs(Servers) do
        if (tick() - time) >= 60*60 then
          Servers[id] = nil
        end
      end
      
      Servers[game.JobId] = tick()
      
      writefile(`{arceus_folder}/ServersLog.json`, HttpService:JSONDecode(Servers))
    end)
  end
  
  function Module:GetOldServers()
    local Success, ServersHistory = pcall(function()
      return HttpService:JSONDecode(readfile(`{arceus_folder}/ServersLog.json`))
    end)
    
    return (Success and ServersHistory) or {}
  end
  
  function Module:ServerHop(MaxPlayers: number?, Region: string?): (nil)
    local old_servers = self:GetOldServers()
    
    MaxPlayers = MaxPlayers or self.SH_MaxPlrs or 8
    -- Region = Region or self.SH_Region or "Singapore"
    
    local ServerBrowser = ReplicatedStorage.__ServerBrowser
    
    for i = 1, 100 do
      local Servers = ServerBrowser:InvokeServer(i)
      for id, info in pairs(Servers) do
        local old_server = old_servers[id or ""]
        
        if info["Count"] <= MaxPlayers and (not old_server or (tick() - old_server) >= 60*60) then
          task.spawn(ServerBrowser.InvokeServer, ServerBrowser, "teleport", id)
        end
      end
    end
  end
  
  Module.Inventory = (function()
    local Inventory = {
      Unlocked = setmetatable({}, { __index = function() return false end }),
      Count = setmetatable({}, { __index = function() return 0 end }),
      Items = {},
    }
    
    function Inventory:UpdateItem(item)
      if type(item) == "table" then
        if item.Type == "Wear" then
          item.Type = "Accessory"
        end
        
        local Name = item.Name
        
        self.Items[Name] = item
        
        if not self.Unlocked[Name] then self.Unlocked[Name] = true end
        if item.Count then self.Count[Name] = item.Count end
      end
    end
    
    function Inventory:RemoveItem(ItemName)
      if type(ItemName) == "string" then
        self.Unlocked[ItemName] = nil
        self.Count[ItemName] = nil
        self.Items[ItemName] = nil
      end
    end
    
    local function OnClientEvent(Method, ...)
      if Method == "ItemChanged" then
        Inventory:UpdateItem(...)
      elseif Method == "ItemAdded" then
        Inventory:UpdateItem(...)
      elseif Method == "ItemRemoved" then
        Inventory:RemoveItem(...)
      end
    end
    
    task.spawn(function()
      table.insert(Connections, CommE.OnClientEvent:Connect(OnClientEvent))
      for _, item in ipairs(Module.FireRemote("getInventory")) do Inventory:UpdateItem(item) end
    end)
    
    return Inventory
  end)()
  
  Module.Tween = (function()
    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1000
    
    if _ENV.tween_bodyvelocity then
      _ENV.tween_bodyvelocity:Destroy()
    end
    
    _ENV.tween_bodyvelocity = BodyVelocity
    
    local IsAlive = Module.IsAlive
    
    local BaseParts, CanCollideObjects = {}, {} do
      local function AddObjectToBaseParts(Object)
        if Object:IsA("BasePart") and Object.CanCollide then
          table.insert(BaseParts, Object)
          CanCollideObjects[Object] = true
        end
      end
      
      local function RemoveObjectsFromBaseParts(BasePart)
        local index = table.find(BaseParts, BasePart)
        
        if index then
          table.remove(BaseParts, index)
        end
      end
      
      local function NewCharacter(Character)
        table.clear(BaseParts)
        
        for _, Object in ipairs(Character:GetDescendants()) do AddObjectToBaseParts(Object) end
        Character.DescendantAdded:Connect(AddObjectToBaseParts)
        Character.DescendantRemoving:Connect(RemoveObjectsFromBaseParts)
        
        Character:WaitForChild("Humanoid", 9e9).Died:Wait()
        table.clear(BaseParts)
      end
      
      table.insert(Connections, Player.CharacterAdded:Connect(NewCharacter))
      task.spawn(NewCharacter, Player.Character)
    end
    
    local function NoClipOnStepped(Character)
      if not IsAlive(Character) then
        return nil
      end
      
      if _ENV.OnFarm and not Player:HasTag("Teleporting") then
        Player:AddTag("Teleporting")
      elseif not _ENV.OnFarm and Player:HasTag("Teleporting") then
        Player:RemoveTag("Teleporting")
      end
      
      if _ENV.OnFarm then
        for i = 1, #BaseParts do
          local BasePart = BaseParts[i]
          
          if CanCollideObjects[BasePart] and BasePart.CanCollide then
            BasePart.CanCollide = false
          end
        end
      elseif Character.PrimaryPart and not Character.PrimaryPart.CanCollide then
        for i = 1, #BaseParts do
          local BasePart = BaseParts[i]
          
          if CanCollideObjects[BasePart] then
            BasePart.CanCollide = true
          end
        end
      end
    end
    
    local function UpdateVelocityOnStepped(Character)
      local RootPart = Character and Character:FindFirstChild("UpperTorso")
      local Humanoid = Character and Character:FindFirstChild("Humanoid")
      
      if _ENV.OnFarm and RootPart and Humanoid and Humanoid.Health > 0 then
        if BodyVelocity.Parent ~= RootPart then
          BodyVelocity.Parent = RootPart
        end
      else
        if BodyVelocity.Parent then
          BodyVelocity.Parent = nil
        end
      end
      
      if BodyVelocity.Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
        BodyVelocity.Velocity = Vector3.zero
      end
    end
    
    table.insert(Connections, RunService.Stepped:Connect(function()
      local Character = Player.Character
      UpdateVelocityOnStepped(Character)
      NoClipOnStepped(Character)
    end))
    
    return BodyVelocity
  end)()
end
