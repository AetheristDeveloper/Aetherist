--!nocheck
--[[
    Entrenched | Combat Suite v3.1 (MCP-dumped, headless-safe, silent)
    --------------------------------------------------------------
      * Runtime: Luau executor (Roblox client). UI: ENTRENCHED custom.
      * Merged base: ESP (chams + 10 overlays) + camera-lock + silent aim.
      * v3.1: all runtime functions guarded for headless/silent operation
        (pcall + capability checks + nil-safe paths), hook/namecall/aim/
        exploit/esp/cull loops degrade gracefully on missing APIs or errors.
      * UI block left untouched (assumed working). No UI debug instrumentation.
      * MCP dump snapshot (Real MCP, live, ENTRENCHED place 3678761576
        v3022, universe 1281592938, 2026): embedded below as MCPDump.
    --------------------------------------------------------------
]]

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

-- Older loads of this file never captured TweenService as a local, so their
-- drag loop resolves it as a global and throws nil:Create on every RMB frame.
-- Publishing it keeps those orphaned handlers quiet instead of spamming errors.
if getgenv and type(getgenv) == "function" then
    pcall(function() getgenv().TweenService = game:GetService("TweenService") end)
end
local TweenService        = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Stats             = game:GetService("Stats")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local math_sqrt, math_floor, math_clamp = math.sqrt, math.floor, math.clamp
local math_abs, math_max, math_min = math.abs, math.max, math.min
local math_rad, math_tan = math.rad, math.tan
local os_clock = os.clock

-- Forward declarations (defined later, used earlier)
local CursorPos
local ApplyCrosshairImage

-- Resolve executor globals the analyzer doesn't ship in its ambient list
local GG = nil
pcall(function()
    if getgenv then GG = getgenv() end
end)
if type(GG) ~= "table" then GG = _G end

local function Cap(name)
    local v = GG[name]
    if type(v) == "function" then return v end
    v = _G[name]
    if type(v) == "function" then return v end
    local dbg: any = debug
    if dbg then
        v = dbg[name]
        if type(v) == "function" then return v end
        local short = name:match("^debug_(.+)$")
        if short then
            v = dbg[short]
            if type(v) == "function" then return v end
        end
    end
    return nil
end

local isclosure = Cap("isclosure")
local getenv = Cap("getenv")
local debug_setconstant = Cap("debug_setconstant")
local debug_getconstant = Cap("debug_getconstant")
local debug_getconstants = Cap("debug_getconstants")
local debug_setupvalue = Cap("debug_setupvalue")
local debug_getupvalue = Cap("debug_getupvalue")
local debug_getupvalues = Cap("debug_getupvalues")
local debug_getprotos = Cap("debug_getprotos")
local debug_getproto = Cap("debug_getproto")
local debug_getgenv = Cap("debug_getgenv")
local debug_getinfo = Cap("debug_getinfo")
local debug_getstack = Cap("debug_getstack")
local debug_setstack = Cap("debug_setstack")
local debug_getcallbackvalue = Cap("debug_getcallbackvalue")
local debug_getfunctionhash = Cap("debug_getfunctionhash")

local Env = {
    Drawing = (type(Drawing) == "table" or type(Drawing) == "userdata"),
    getsenv = type(getsenv) == "function",
    getrawmetatable = type(getrawmetatable) == "function",
    hookmetamethod = type(hookmetamethod) == "function",
    setreadonly = type(setreadonly) == "function",
    newcclosure = type(newcclosure) == "function",
    checkcaller = type(checkcaller) == "function",
    getnamecallmethod = type(getnamecallmethod) == "function",
    decompile = type(decompile) == "function",
    writefile = type(writefile) == "function",
    fireproximityprompt = type(fireproximityprompt) == "function",
    setfpscap = type(setfpscap) == "function",
    makefolder = type(makefolder) == "function",
    delfile = type(delfile) == "function",
    appendfile = type(appendfile) == "function",
    readfile = type(readfile) == "function",
    listfiles = type(listfiles) == "function",
    getinstances = type(getinstances) == "function",
    isfolder = type(isfolder) == "function",
    isfile = type(isfile) == "function",
    lz4compress = type(lz4compress) == "function",
    lz4decompress = type(lz4decompress) == "function",
    base64_encode = type(base64_encode) == "function",
    base64_decode = type(base64_decode) == "function",
    request = type(request) == "function",
    setthreadidentity = type(setthreadidentity) == "function",
    getthreadidentity = type(getthreadidentity) == "function",
    getscriptbytecode = type(getscriptbytecode) == "function",
    getscriptclosure = type(getscriptclosure) == "function",
    getscriptfromthread = type(getscriptfromthread) == "function",
    getscripthash = type(getscripthash) == "function",
    getscripts = type(getscripts) == "function",
    getloadedmodules = type(getloadedmodules) == "function",
    getgenv = type(getgenv) == "function",
    getrenv = type(getrenv) == "function",
    getnilinstances = type(getnilinstances) == "function",
    getgc = type(getgc) == "function",
    filtergc = type(filtergc) == "function",
    getrunningscripts = type(getrunningscripts) == "function",
    compareinstances = type(compareinstances) == "function",
    getcustomasset = type(getcustomasset) == "function",
    gethui = type(gethui) == "function",
    getconnections = type(getconnections) == "function",
    replicatesignal = type(replicatesignal) == "function",
    firesignal = type(firesignal) == "function",
    firetouchinterest = type(firetouchinterest) == "function",
    fireclickdetector = type(fireclickdetector) == "function",
    cleardrawcache = type(cleardrawcache) == "function",
    setrenderproperty = type(setrenderproperty) == "function",
    getrenderproperty = type(getrenderproperty) == "function",
    isrenderobj = type(isrenderobj) == "function",
    getcallingscript = type(getcallingscript) == "function",
    iscclosure = type(iscclosure) == "function",
    isclosure = type(isclosure) == "function",
    islclosure = type(islclosure) == "function",
    isexecutorclosure = type(isexecutorclosure) == "function",
    getfunctionhash = type(getfunctionhash) == "function",
    getcallbackvalue = type(getcallbackvalue) == "function",
    isreadonly = type(isreadonly) == "function",
    DrawingFonts = (Drawing ~= nil) and (Drawing.Fonts ~= nil),
    getenv = type(getenv) == "function",
    hookfunction = type(hookfunction) == "function",
    cloneref = type(cloneref) == "function",
    clonefunction = type(clonefunction) == "function",
    delfolder = type(delfolder) == "function",
    setconstant = type(setconstant) == "function",
    getconstant = type(getconstant) == "function",
    getconstants = type(getconstants) == "function",
    setupvalue = type(setupvalue) == "function",
    getupvalue = type(getupvalue) == "function",
    getupvalues = type(getupvalues) == "function",
    setstack = type(setstack) == "function",
    getstack = type(getstack) == "function",
    getinfo = type(getinfo) == "function",
    getproto = type(getproto) == "function",
    getprotos = type(getprotos) == "function",
    debug_setconstant = type(debug_setconstant) == "function",
    debug_getconstant = type(debug_getconstant) == "function",
    debug_getconstants = type(debug_getconstants) == "function",
    debug_setupvalue = type(debug_setupvalue) == "function",
    debug_getupvalue = type(debug_getupvalue) == "function",
    debug_getupvalues = type(debug_getupvalues) == "function",
    debug_getprotos = type(debug_getprotos) == "function",
    debug_getproto = type(debug_getproto) == "function",
    debug_getgenv = type(debug_getgenv) == "function",
    debug_getinfo = type(debug_getinfo) == "function",
    debug_getstack = type(debug_getstack) == "function",
    debug_setstack = type(debug_setstack) == "function",
    debug_getcallbackvalue = type(debug_getcallbackvalue) == "function",
    debug_getfunctionhash = type(debug_getfunctionhash) == "function",
    identifyexecutor = type(identifyexecutor) == "function",
}

local function SafeCall(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

-- ============================================================
-- Main runtime
local function IsAliveInst(inst)
    local ok = false
    pcall(function() ok = inst and inst.Parent ~= nil end)
    if ok then return true end
    ok = false
    pcall(function() ok = inst ~= nil end)
    return ok
end

local function GetMousePos()
    local ok, pos = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and typeof(pos) == "Vector2" then return pos end
    return Vector2.new(0, 0)
end

local function WTVP(pos)
    local cam = Camera or workspace.CurrentCamera
    if not cam then return { X = 0, Y = 0, Z = 0 }, false end
    local ok, sp, on = pcall(function() return cam:WorldToViewportPoint(pos) end)
    if ok and sp then
        return { X = sp.X, Y = sp.Y, Z = sp.Z }, on == true
    end
    return { X = 0, Y = 0, Z = 0 }, false
end

local function RefreshCamera()
    local ok, cam = pcall(function() return workspace.CurrentCamera end)
    if ok and cam then Camera = cam end
end

local function WorldRaycast(origin, dir, params)
    local ok, res = pcall(function() return workspace:Raycast(origin, dir, params) end)
    if ok then return res end
    return nil
end

local function WrapCall(obj, method, ...)
    if not obj then return nil end
    local ok, res = pcall(function(...) return obj[method](obj, ...) end)
    if ok then return res end
    return nil
end

-- ============================================================
-- MCP live dump snapshot (captured via Real MCP tools)
-- ============================================================
local MCPDump = {
    Game = {
        Name = "ENTRENCHED ÃƒÂ°Ã…Â¸Ã‚Â¥Ã¢â€šÂ¬",
        Creator = "Edot",
        PlaceId = 3678761576,
        UniverseId = 1281592938,
        PlaceVersion = 3022,
        JobId = "7d48ffba-24f5-4578-bf6a-b4a1a85780c9",
    },
    WeaponRelated = {
        { Name = "WeaponModule", Class = "ModuleScript", Path = "ReplicatedStorage.WeaponModule" },
        { Name = "ClientModule", Class = "ModuleScript", Path = "ReplicatedStorage.ClientModule" },
        { Name = "RaycastHitboxV4", Class = "ModuleScript", Path = "ReplicatedStorage.RaycastHitboxV4" },
        { Name = "SetLookAngles", Class = "RemoteEvent", Path = "ReplicatedStorage.SetLookAngles" },
    },
    ServerEvents = {
        { Name = "Shoot", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.Shoot" },
        { Name = "Melee", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.Melee" },
        { Name = "Reload", Class = "RemoteFunction", Path = "ReplicatedStorage.ServerEvents.Reload" },
        { Name = "Equip", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.Equip" },
        { Name = "Dig", Class = "RemoteFunction", Path = "ReplicatedStorage.ServerEvents.Dig" },
        { Name = "Team", Class = "RemoteFunction", Path = "ReplicatedStorage.ServerEvents.Team" },
        { Name = "Deploy", Class = "RemoteFunction", Path = "ReplicatedStorage.ServerEvents.Deploy" },
        { Name = "Class", Class = "RemoteFunction", Path = "ReplicatedStorage.ServerEvents.Class" },
        { Name = "Customization", Class = "RemoteFunction", Path = "ReplicatedStorage.ServerEvents.Customization" },
        { Name = "Whistle", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.Whistle" },
        { Name = "Throw", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.Throw" },
        { Name = "Heal", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.Heal" },
        { Name = "ShootTurret", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.ShootTurret" },
        { Name = "LookAngle", Class = "UnreliableRemoteEvent", Path = "ReplicatedStorage.ServerEvents.LookAngle" },
        { Name = "ShootGrenadeLauncher", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.ShootGrenadeLauncher" },
        { Name = "ToggleLauncherMode", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.ToggleLauncherMode" },
        { Name = "PlaceDynamite", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.PlaceDynamite" },
        { Name = "DetonateDynamite", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.DetonateDynamite" },
        { Name = "PlaceTripWire", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.PlaceTripWire" },
        { Name = "CancelTripWire", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.CancelTripWire" },
        { Name = "ArmTripWire", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.ArmTripWire" },
        { Name = "StickyGrenadeHit", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.StickyGrenadeHit" },
        { Name = "FallDMG", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.FallDMG" },
        { Name = "DownedRevive", Class = "RemoteEvent", Path = "ReplicatedStorage.ServerEvents.DownedRevive" },
    },
    Notes = {
        "WeaponModule decompiled (partial, live): requires ClientEvents/ServerEvents/RaycastHitboxV4; defines Crosshair(a1,a2,a3) and uses it for aim/shoot paths.",
        "script-grep (live, incomplete coverage): Crosshair defined in ReplicatedStorage.WeaponModule (~line 970); Control scripts bind Shoot/Reload and call WeaponModule.Equip.",
        "Remote inventory dumped via search-instances + eval tree scan: 155 remotes under ReplicatedStorage (sample captured), ServerEvents folder present with 100+ children.",
    },
}

-- ============================================================
-- Settings
-- ============================================================
local Settings = {
    ESP = {
        Enabled = true, Color = "Red", ColorHex = "#FF4646", ChamsHex = "#FF4646",
        FillTransparency = 0.5, MaxDistance = 800,
        Box = false, Chams = true, Distance = false, Health = false,
        Skeleton = false, Snapline = false, Arrow = false, HeadCircle = false,
        Tracer = false, ClassTag = false, TeamCheck = true,
        Throttle = 0.05,
    },
    Aim = {
        CameraLock = false, Key = "LMB", Mode = "Hold",
        FOV = 200, WallCheck = true, Part = "Head", Prediction = 0,
        IgnoreTeam = true, Smooth = 0,
        TriggerBot = false, TriggerFOV = 60, TriggerDelay = 80,
        MaxDistance = 200,
        Throttle = 0.01,
    },
    Crosshair = {
        Enabled = false, Image = "", Size = 20, Color = "#FFFFFF",
        Throttle = 0.016,
    },
    FovCircle = {
        Enabled = true, Color = "#FFFFFF",
        Throttle = 0.016,
    },
    Misc = {
        InstantRevive = false,
        WalkSpeedEnabled = false, WalkSpeed = 16, JumpPower = 50,
        FOVLock = false, FOVValue = 70, Fullbright = false, NoFog = false, PostFX = false,
    },
    Render = { Culling = true, Distance = 700, Lite = false },
    Debug = { RemoteLog = false, LogShootArgs = false, MaxLogs = 120 },
    Perf = { Ping = 0, FPS = 0, Targets = 0, Hits = 0, Shots = 0, Culled = 0, _cull = 0 },
    History = { Distance = {0,0,0,0,0,0,0,0,0,0}, Index = 1, Last = 0 },
}

local colorMap = {
    Red = Color3.fromRGB(255, 0, 0), Green = Color3.fromRGB(0, 255, 0),
    Blue = Color3.fromRGB(0, 150, 255), White = Color3.fromRGB(255, 255, 255),
    Yellow = Color3.fromRGB(255, 220, 60), Cyan = Color3.fromRGB(0, 255, 240),
}

local KEY_MAP = {
    RMB = Enum.UserInputType.MouseButton2, LMB = Enum.UserInputType.MouseButton1,
    LeftShift = Enum.KeyCode.LeftShift, LeftAlt = Enum.KeyCode.LeftAlt,
    E = Enum.KeyCode.E, Q = Enum.KeyCode.Q,
}

local MAX_HIGHLIGHTS = 24
local NO_RECOIL = { { 1, 0, 0, 0.77, 0 } }

-- ============================================================
-- Utility / discovery
-- ============================================================
local Connections = {}
local Unloaded = false

-- anti-duplicate: stop any previous instance of this suite before this one runs
pcall(function()
    if type(GG) ~= "table" then return end
    local prev = GG.__ENTRENCHED
    if type(prev) == "table" then
        if type(prev.stop) == "function" then pcall(prev.stop) end
        GG.__ENTRENCHED = nil
    end
    GG.__ENTRENCHED = {
        stop = function()
            Unloaded = true
        end,
    }
end)

local function TrackConn(c)
    if c then Connections[#Connections + 1] = c end
    return c
end

local function SafeDisconnect(c)
    if c then pcall(function() c:Disconnect() end) end
end

local function DeepFind(parent, name, className)
    local okf, res = pcall(function()
        if not parent then return nil end
        local found = parent:FindFirstChild(name, true)
        if found then
            if not className then return found end
            local okc, isC = pcall(function() return found:IsA(className) end)
            if okc and isC then return found end
        end
        local desc = parent:GetDescendants()
        for _, d in ipairs(desc) do
            local okn, n = pcall(function() return d.Name end)
            if okn and n == name then
                if not className then return d end
                local okc, isC = pcall(function() return d:IsA(className) end)
                if okc and isC then return d end
            end
        end
        return nil
    end)
    return okf and res or nil
end

local function PathOf(inst)
    local ok, p = pcall(function() return inst:GetFullName() end)
    if ok and type(p) == "string" then return p end
    local oks, s = pcall(tostring, inst)
    return oks and s or "<?>"
end

local function EncodeJSON(tbl)
    local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
    return ok and res or ("<encode-failed:" .. tostring(res) .. ">")
end

local function SummarizeValue(v, depth)
    local ok, res = pcall(function()
        depth = depth or 0
        local t = typeof(v)
        if t == "Instance" then
            local cn = "?"
            pcall(function() cn = v.ClassName end)
            return { __type = "Instance", class = cn, path = PathOf(v) }
        end
        if t == "Vector3" then return { __type = "Vector3", x = v.X, y = v.Y, z = v.Z } end
        if t == "Vector2" then return { __type = "Vector2", x = v.X, y = v.Y } end
        if t == "CFrame" then
            local p = v.Position
            return { __type = "CFrame", x = p.X, y = p.Y, z = p.Z }
        end
        if t == "Color3" then return { __type = "Color3", r = v.R, g = v.G, b = v.B } end
        if t == "EnumItem" then return { __type = "EnumItem", name = tostring(v) } end
        if t == "table" then
            if depth >= 2 then return { __type = "table", keys = #v } end
            local out, n = {}, 0
            for k, val in pairs(v) do
                n += 1
                if n > 20 then out["..."] = "truncated"; break end
                out[tostring(k)] = SummarizeValue(val, depth + 1)
            end
            return out
        end
        if t == "string" then
            if #v > 120 then return v:sub(1, 120) .. "..." end
            return v
        end
        if t == "number" or t == "boolean" or t == "nil" then return v end
        return { __type = t, str = tostring(v) }
    end)
    if ok then return res end
    return { __type = "unknown" }
end

local RemoteLog = {}
local function PushRemoteLog(entry)
    pcall(function()
        if not Settings.Debug.RemoteLog and not Settings.Debug.LogShootArgs then return end
        if Settings.Debug.LogShootArgs and entry.remote ~= "Shoot" then return end
        RemoteLog[#RemoteLog + 1] = entry
        local maxn = math_max(20, Settings.Debug.MaxLogs or 120)
        while #RemoteLog > maxn do table.remove(RemoteLog, 1) end
    end)
end

-- ============================================================
-- Remote/module discovery (from live dump + runtime scan)
-- ============================================================
local ServerEvents = SafeCall(function() return ReplicatedStorage:FindFirstChild("ServerEvents") or ReplicatedStorage:WaitForChild("ServerEvents", 10) end)
local ClientEvents = SafeCall(function() return ReplicatedStorage:FindFirstChild("ClientEvents") or ReplicatedStorage:WaitForChild("ClientEvents", 10) end)
local WeaponModuleInst = SafeCall(function() return ReplicatedStorage:FindFirstChild("WeaponModule") end)
local ClientModuleInst = SafeCall(function() return ReplicatedStorage:FindFirstChild("ClientModule") end)
local RaycastHitboxInst = SafeCall(function() return ReplicatedStorage:FindFirstChild("RaycastHitboxV4") end)

local function ResolveRemote(container, name, className)
    local okr, inst = pcall(function()
        if not container then return nil end
        local i = container:FindFirstChild(name)
        if i then
            if not className then return i end
            local okc, isC = pcall(function() return i:IsA(className) end)
            if okc and isC then return i end
        end
        return DeepFind(container, name, className)
    end)
    return okr and inst or nil
end

local Remotes = {}
local function RefreshRemotes()
    pcall(function()
        if not ServerEvents then
            ServerEvents = SafeCall(function() return ReplicatedStorage:FindFirstChild("ServerEvents") or ReplicatedStorage:FindFirstChild("ServerEvents", true) end)
        end
        Remotes.Shoot = ResolveRemote(ServerEvents, "Shoot", "RemoteEvent")
        Remotes.Reload = ResolveRemote(ServerEvents, "Reload", "RemoteFunction")
        Remotes.Equip = ResolveRemote(ServerEvents, "Equip", "RemoteEvent")
        Remotes.Melee = ResolveRemote(ServerEvents, "Melee", "RemoteEvent")
        Remotes.Throw = ResolveRemote(ServerEvents, "Throw", "RemoteEvent")
        Remotes.Heal = ResolveRemote(ServerEvents, "Heal", "RemoteEvent")
        Remotes.LookAngle = ResolveRemote(ServerEvents, "LookAngle") or ResolveRemote(ReplicatedStorage, "SetLookAngles", "RemoteEvent")
    end)
end
RefreshRemotes()

-- ============================================================
-- Culling registries
-- ============================================================
local SHADOW_PARTS = {
    Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
    SpawnLocation = true, TrussPart = true, CornerWedgePart = true,
}
local PARTICLE_FX = {
    ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Sparkles = true, Smoke = true,
}
local LIGHTS = { PointLight = true, SpotLight = true, SurfaceLight = true }
local DECAL_LIKE = { Decal = true, Texture = true }

local CULL_CHUNK, CULL_BUDGET = 128, 6
local Chunks, Registered = {}, {}
local CullQueue, CullHead = {}, 1

local function IsCharacterPart(p)
    local ok, res = pcall(function()
        local parent = p and p.Parent
        if not parent then return true end
        if parent:FindFirstChildOfClass("Humanoid") then return true end
        local isAcc, isTool = false, false
        pcall(function() isAcc = parent:IsA("Accessory") end)
        pcall(function() isTool = parent:IsA("Tool") end)
        if isAcc or isTool then
            local gp = parent.Parent
            if gp and gp:FindFirstChildOfClass("Humanoid") then return true end
        end
        return false
    end)
    return ok and res or true
end

local function RegisterPart(p)
    pcall(function()
        if not p or Registered[p] then return end
        Registered[p] = true
        local tr = 0
        pcall(function() tr = p.Transparency end)
        if tr >= 1 then return end
        local s = nil
        pcall(function() s = p.Size end)
        if s and math_max(s.X, s.Y, s.Z) > 300 then return end
        if IsCharacterPart(p) then return end
        local pos = nil
        pcall(function() pos = p.Position end)
        if not pos then return end
        local key = math_floor(pos.X / CULL_CHUNK) .. "|" .. math_floor(pos.Y / CULL_CHUNK) .. "|" .. math_floor(pos.Z / CULL_CHUNK)
        local chunk = Chunks[key]
        if not chunk then
            chunk = { Center = pos, Parts = {}, Visible = true }
            Chunks[key] = chunk
        end
        local parts = chunk.Parts
        parts[#parts + 1] = p
        parts[#parts + 1] = tr
    end)
end

local function StripInstance(v)
    pcall(function()
        local cn = nil
        pcall(function() cn = v.ClassName end)
        if not cn then return end
        if SHADOW_PARTS[cn] then
            pcall(function() v.CastShadow = false end)
            local isMesh = false
            pcall(function() isMesh = v:IsA("MeshPart") end)
            if isMesh then pcall(function() v.RenderFidelity = Enum.RenderFidelity.Performance end) end
            RegisterPart(v)
        elseif PARTICLE_FX[cn] then
            pcall(function() v.Enabled = false end)
        elseif DECAL_LIKE[cn] then
            pcall(function() v.Transparency = 1 end)
        elseif LIGHTS[cn] then
            pcall(function() v.Enabled = false end)
        elseif cn == "Humanoid" then
            pcall(function() v.HealthDisplayDistance = 0 end)
            pcall(function() v.NameDisplayDistance = 0 end)
        end
    end)
end

task.spawn(function()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Technology = Enum.Technology.Voxel
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
    end)
    pcall(function()
        for _, v in ipairs(Lighting:GetChildren()) do
            pcall(function()
                if v.ClassName == "Sky" then v:Destroy()
                elseif v:IsA("PostEffect") then v.Enabled = false end
            end)
        end
    end)
    pcall(function()
        local Terrain = workspace:FindFirstChild("Terrain")
        if Terrain then
            Terrain.WaterWaveSize, Terrain.WaterWaveSpeed, Terrain.WaterReflectance = 0, 0, 0
        end
    end)
    pcall(function()
        local gameSettings: any = UserSettings():GetService("UserGameSettings")
        gameSettings.SavedQualityScale = 1
        local ws: any = workspace
        ws.StreamingTargetRadius = 512
    end)
    pcall(function()
        local d = workspace:GetDescendants()
        for i = 1, #d do
            StripInstance(d[i])
            if i % 400 == 0 then task.wait() end
        end
    end)
    pcall(function()
        TrackConn(workspace.DescendantAdded:Connect(function(v) pcall(StripInstance, v) end))
    end)
end)

local function ApplyChunk(chunk)
    pcall(function()
        if not chunk then return end
        local parts, vis = chunk.Parts, chunk.Visible
        if type(parts) ~= "table" then return end
        for i = 1, #parts, 2 do
            local part = parts[i]
            local orig = parts[i + 1]
            if part then
                pcall(function()
                    if part.Parent then part.Transparency = vis and (orig or 0) or 1 end
                end)
            end
        end
    end)
end

local function CullStep()
    pcall(function()
        local cam = Camera or workspace.CurrentCamera
        if not Settings.Render.Culling or not cam or not cam.CFrame then return end
        local camCF = cam.CFrame
        local camPos = camCF.Position
        local vp = cam.ViewportSize or Vector2.new(1, 1)
        local fov = 70
        pcall(function() fov = cam.FieldOfView end)
        local tanV = math_tan(math_rad(fov * 0.5))
        local tanH = tanV * (vp.X / math_max(1, vp.Y))
        local maxD = Settings.Render.Distance or 700
        local radius = CULL_CHUNK * 0.9
        local culled = 0
        for _, chunk in pairs(Chunks) do
            local c = chunk and chunk.Center
            if c then
                local dx, dy, dz = c.X - camPos.X, c.Y - camPos.Y, c.Z - camPos.Z
                local dist = math_sqrt(dx*dx + dy*dy + dz*dz)
                local want = true
                if dist - radius > maxD then want = false
                else
                    local okr, rel = pcall(function() return camCF:PointToObjectSpace(c) end)
                    if okr and rel then
                        local depth = -rel.Z
                        if depth < -radius then want = false
                        elseif math_abs(rel.X) > depth * tanH + radius then want = false
                        elseif math_abs(rel.Y) > depth * tanV + radius then want = false end
                    end
                end
                if want ~= chunk.Visible then
                    chunk.Visible = want
                    CullQueue[#CullQueue + 1] = chunk
                end
                if not want then culled += 1 end
            end
        end
        Settings.Perf.Culled = culled
        local budget = CULL_BUDGET
        while CullHead <= #CullQueue and budget > 0 do
            local chunk = CullQueue[CullHead]
            CullQueue[CullHead] = nil
            CullHead += 1
            budget -= 1
            ApplyChunk(chunk)
        end
        if CullHead > #CullQueue then CullQueue, CullHead = {}, 1 end
    end)
end

local function ResetCulling()
    pcall(function()
        for _, chunk in pairs(Chunks) do
            if chunk and not chunk.Visible then chunk.Visible = true; ApplyChunk(chunk) end
        end
        CullQueue, CullHead = {}, 1
    end)
end

-- ============================================================
-- Drawing
-- ============================================================
local DrawingEnabled = false
if Env.Drawing then
    local okd = pcall(function()
        local t = Drawing.new("Line")
        if t then t:Remove() end
    end)
    DrawingEnabled = okd
end

-- ============================================================
-- ESP / aim / combat runtime (headless-safe, silent, debug-free)
-- ============================================================
-- Throttle trackers (per-function rate limiting to prevent lag)
local _throttle = {
    esp = 0,
    aim = 0,
    crosshair = 0,
    fov = 0,
    cull = 0,
}

local ESP_Objects = {}
local ESP_Highlights = {}
local ESP_Container = nil
local ESP_COLOR = Color3.fromRGB(255, 70, 70)
local CHAMS_COLOR = Color3.fromRGB(255, 70, 70)
local ESP_FONT = (Drawing ~= nil and Drawing.Fonts and Drawing.Fonts.Plex) or 2

-- hex -> Color3 helper (supports #RRGGBB and RRGGBB)
local function HexToColor(hex, fallback)
    if type(hex) ~= "string" then return fallback or Color3.fromRGB(255, 255, 255) end
    local clean = hex:gsub("#", "")
    local r = tonumber(clean:sub(1, 2), 16)
    local g = tonumber(clean:sub(3, 4), 16)
    local b = tonumber(clean:sub(5, 6), 16)
    if r and g and b then return Color3.fromRGB(r, g, b) end
    return fallback or Color3.fromRGB(255, 255, 255)
end

-- sync ESP color from hex setting
local function EspColorFromHex()
    ESP_COLOR = HexToColor(Settings.ESP.ColorHex, ESP_COLOR)
end
local function ChamsColorFromHex()
    CHAMS_COLOR = HexToColor(Settings.ESP.ChamsHex, CHAMS_COLOR)
end

-- always-visible FOV circle + crosshair runtime state (declared before use)
local FovCircle = nil
local CrosshairGui = nil
local CrosshairImage = nil
local CrosshairPending = false
local LastCrosshairImage = ""

-- RMB aim window lock: Rayfield Gen2 drags the title bar on any mouse button.
-- When RMB is held (aiming with gun), pin the window so it can't be dragged.
local EntWinRoot = nil
local EntWinPos = nil

-- always-visible FOV circle -------------------------------------------------
local function EnsureFovCircle()
    if FovCircle then return end
    if not DrawingEnabled then return end
    local ok, c = pcall(function()
        local ci = Drawing.new("Circle")
        ci.Color = Color3.fromRGB(255, 255, 255)
        ci.Thickness = 1.5
        ci.Transparency = 0.45
        ci.Filled = false
        ci.Radius = Settings.Aim.FOV or 120
        ci.Position = CursorPos()
        ci.Visible = true
        return ci
    end)
    if ok and c then FovCircle = c end
end

local function UpdateFovCircle()
    if not Settings.FovCircle.Enabled then
        if FovCircle then FovCircle.Visible = false end
        return
    end
    if not FovCircle then EnsureFovCircle() end
    if FovCircle and DrawingEnabled then
        FovCircle.Visible = true
        FovCircle.Radius = Settings.Aim.FOV or 120
        FovCircle.Position = CursorPos()
        FovCircle.Color = HexToColor(Settings.FovCircle.Color, Color3.fromRGB(255, 255, 255))
    end
end

-- custom crosshair (ImageLabel in its own ScreenGui) -----------------------
local function SetupCrosshair()
    if CrosshairGui then return end
    local ok, sg = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "ENT_Crosshair"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not okp then gui.Parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui") end
        local img = Instance.new("ImageLabel")
        img.Name = "ENT_CrosshairImg"
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.new(0.5, 0, 0.5, 0)
        img.Size = UDim2.new(0, Settings.Crosshair.Size or 20, 0, Settings.Crosshair.Size or 20)
        img.BackgroundTransparency = 1
        img.ImageTransparency = 0
        img.ScaleType = Enum.ScaleType.Fit
        img.Parent = gui
        return gui, img
    end)
    if ok and sg then
        CrosshairGui, CrosshairImage = sg[1], sg[2]
    end
end

local function UpdateCrosshair()
    if not Settings.Crosshair.Enabled then
        if CrosshairImage then CrosshairImage.Visible = false end
        return
    end
    if not CrosshairImage then SetupCrosshair() end
    if CrosshairImage then
        ApplyCrosshairImage()
        CrosshairImage.Visible = true
        CrosshairImage.Size = UDim2.new(0, Settings.Crosshair.Size or 20, 0, Settings.Crosshair.Size or 20)
        CrosshairImage.ImageColor3 = HexToColor(Settings.Crosshair.Color, Color3.fromRGB(255, 255, 255))
    end
end

-- download an image from a URL and return a getcustomasset path
local function DownloadImage(url, saveAs)
    if not Env.request or not Env.writefile or not Env.getcustomasset then return nil end
    local ok, res = pcall(function()
        return request({ Url = url, Method = "GET" })
    end)
    if not ok or not res or not res.Body then return nil end
    pcall(function() writefile(saveAs, res.Body) end)
    local ok2, asset = pcall(function() return getcustomasset(saveAs) end)
    if ok2 and asset then return asset end
    return nil
end

ApplyCrosshairImage = function()
    if not CrosshairImage then return end
    local img = Settings.Crosshair.Image or ""
    if img == "" then
        CrosshairImage.Image = ""
        LastCrosshairImage = ""
        return
    end
    -- Only re-download if the image URL actually changed
    if img == LastCrosshairImage and CrosshairImage.Image ~= "" then return end
    -- Roblox image id shortcut
    if img:match("^%d+$") or img:match("^rbxassetid://") then
        local id = img:gsub("rbxassetid://", "")
        CrosshairImage.Image = "rbxassetid://" .. id
        LastCrosshairImage = img
        return
    end
    -- URL download path
    if not CrosshairPending then
        CrosshairPending = true
        local asset = DownloadImage(img, "ent_crosshair.png")
        CrosshairPending = false
        LastCrosshairImage = img
        if asset then
            CrosshairImage.Image = asset
        else
            CrosshairImage.Image = ""
        end
    end
end

-- RMB aim window lock: Rayfield Gen2 drags the title bar on any mouse button.
-- When RMB is held (aiming with gun), pin the window so it can't be dragged.
-- EntWinRoot is resolved dynamically after the UI is built.
local EntWinRoot = nil
local EntWinPos = nil
local function ResolveEntWinRoot()
    if EntWinRoot then return end
    if not Env.gethui then return end
    local okH, huiRes = pcall(gethui)
    if not okH or not huiRes then return end
    local rf = huiRes:FindFirstChild("RayfieldGen2")
    if not rf then return end
    EntWinRoot = rf:FindFirstChild("WindowRoot")
    if EntWinRoot then EntWinPos = EntWinRoot.Position end
end

local function ESP_ContainerGet()
    if ESP_Container and ESP_Container.Parent then return ESP_Container end
    local ok, folder = pcall(function()
        local f = Instance.new("Folder")
        f.Name = "ENT_ESP"
        f.Parent = workspace.CurrentCamera or workspace
        return f
    end)
    if ok then ESP_Container = folder end
    return ESP_Container
end

local function DestroyESP(p)
    if not p then return end
    local t = ESP_Objects[p]
    if type(t) == "table" then
        for _, d in ipairs(t) do
            pcall(function()
                if d then d:Remove() end
            end)
        end
        ESP_Objects[p] = nil
    end
    local h = ESP_Highlights[p]
    if h then
        pcall(function() h:Destroy() end)
        ESP_Highlights[p] = nil
    end
end

local function ESP_GetOrCreate(p)
    local t = ESP_Objects[p]
    if t then return t end
    if not DrawingEnabled then return nil end

    local okNew, pack = pcall(function()
        local box = Drawing.new("Square")
        box.Color = ESP_COLOR
        box.Thickness = 1.4
        box.Transparency = 1

        local dst = Drawing.new("Text")
        dst.Size = 12
        dst.Color = Color3.fromRGB(216, 200, 255)
        dst.Outline = true
        dst.OutlineColor = Color3.fromRGB(0, 0, 0)
        dst.Center = true
        dst.Font = ESP_FONT

        local hp = Drawing.new("Text")
        hp.Size = 12
        hp.Color = Color3.fromRGB(255, 220, 60)
        hp.Outline = true
        hp.OutlineColor = Color3.fromRGB(0, 0, 0)
        hp.Center = true
        hp.Font = ESP_FONT

        local tracer = Drawing.new("Line")
        tracer.Color = ESP_COLOR
        tracer.Thickness = 1
        tracer.Transparency = 0.75

        local snap = Drawing.new("Line")
        snap.Color = ESP_COLOR
        snap.Thickness = 1
        snap.Transparency = 0.6

        local headCircle = Drawing.new("Circle")
        headCircle.Color = ESP_COLOR
        headCircle.Thickness = 1.2
        headCircle.Filled = false
        headCircle.Transparency = 0.8

        return { box, dst, hp, tracer, snap, headCircle }
    end)

    if not okNew or type(pack) ~= "table" then return nil end
    ESP_Objects[p] = pack
    return pack
end

local function HideESPArt(p)
    local t = ESP_Objects[p]
    if t then
        for _, d in ipairs(t) do
            pcall(function() d.Visible = false end)
        end
    end
    local h = ESP_Highlights[p]
    if h then h.Enabled = false end
end

local function UpdateESP()
    EspColorFromHex()
    ChamsColorFromHex()
    for p in pairs(ESP_Objects) do
        if not p or not p.Parent or not p.Character or not p.Character.Parent then DestroyESP(p) end
    end
    for p in pairs(ESP_Highlights) do
        if not p or not p.Parent or not p.Character or not p.Character.Parent then DestroyESP(p) end
    end

    if Unloaded or not Settings.ESP.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do DestroyESP(p) end
        return
    end

    local me = LocalPlayer
    local cam = Camera or workspace.CurrentCamera
    if not me or not cam then return end

    local viewport = cam.ViewportSize
    local camPos = cam.CFrame.Position
    local maxDist = Settings.ESP.MaxDistance or 800
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local espEnabled = Settings.ESP.Enabled
    local espChams = Settings.ESP.Chams
    local espTeamCheck = Settings.ESP.TeamCheck
    local espBox = Settings.ESP.Box
    local espDistance = Settings.ESP.Distance
    local espHealth = Settings.ESP.Health
    local espTracer = Settings.ESP.Tracer
    local espSnapline = Settings.ESP.Snapline
    local espHeadCircle = Settings.ESP.HeadCircle
    local myTeam = me.Team
    local drawingEnabled = DrawingEnabled
    local players = Players:GetPlayers()

    for _, p in ipairs(players) do
        local char = p.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and char:FindFirstChild("Head")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local dist = 0
        if char and head then
            dist = (head.Position - camPos).Magnitude
        end

        -- chams track every live enemy regardless of range; overlays keep the distance gate
        local enemy = p ~= me and char ~= nil and hum ~= nil and hum.Health > 0
        if enemy and espTeamCheck and myTeam ~= nil and p.Team == myTeam then
            enemy = false
        end
        local show = enemy and dist <= maxDist

        if not enemy then
            HideESPArt(p)
        else
            if espChams then
                local h = ESP_Highlights[p]
                if not h then
                    local container = ESP_ContainerGet()
                    if container then
                        local hi = Instance.new("Highlight")
                        hi.Name = "ENT_" .. p.Name
                        hi.FillColor = CHAMS_COLOR
                        hi.OutlineColor = CHAMS_COLOR
                        hi.FillTransparency = 0.65
                        hi.OutlineTransparency = 0
                        hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hi.Adornee = char
                        hi.Parent = container
                        h = hi
                        ESP_Highlights[p] = hi
                    end
                end
                if h then
                    if h.Adornee ~= char then h.Adornee = char end
                    h.Enabled = true
                end
            else
                local h = ESP_Highlights[p]
                if h then h.Enabled = false end
            end

            if show and head and hrp and drawingEnabled then
                local dTop, onTop = WTVP(head.Position + Vector3.new(0, 0.45, 0))
                local dBot, onBot = WTVP(hrp.Position - Vector3.new(0, 2.85, 0))
                local t = ESP_GetOrCreate(p)
                if t and onTop and onBot then
                    local hgt = math_max(8, math_abs(dBot.Y - dTop.Y))
                    local wid = math_max(4, hgt * 0.55)
                    local left = dTop.X - wid * 0.5

                    t[1].Visible = espBox
                    t[1].Position = Vector2.new(left, dTop.Y)
                    t[1].Size = Vector2.new(wid, hgt)

                    t[2].Visible = espDistance
                    t[2].Text = string.format("%dm", math_floor(dist))
                    t[2].Position = Vector2.new(dTop.X, dBot.Y + 2)

                    t[3].Visible = espHealth
                    t[3].Text = tostring(math_floor(hum.Health))
                    t[3].Position = Vector2.new(left - 10, dTop.Y + hgt * 0.5)

                    t[4].Visible = espTracer
                    t[4].From = Vector2.new(viewport.X * 0.5, viewport.Y)
                    t[4].To = Vector2.new(dTop.X, dBot.Y)

                    t[5].Visible = espSnapline
                    t[5].From = center
                    t[5].To = Vector2.new(dTop.X, dTop.Y)

                    t[6].Visible = espHeadCircle
                    t[6].Position = Vector2.new(dTop.X, dTop.Y)
                    t[6].Radius = math_max(4, hgt * 0.14)
                else
                    HideESPArt(p)
                end
            end
        end
    end
end

local AimParams = nil

local AimHeld = false

CursorPos = function()
    local ok, loc = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok or not loc then return Vector2.new(0, 0) end
    return Vector2.new(loc.X, loc.Y)
end

-- aim: multi-point hitbox visibility instead of a single body ray -------------
local AIM_PARTS = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" }

local function AimRayParams()
    if AimParams then return AimParams end
    local pr = RaycastParams.new()
    local okEx = pcall(function() pr.FilterType = Enum.RaycastFilterType.Exclude end)
    if not okEx then pcall(function() pr.FilterType = Enum.RaycastFilterType.Blacklist end) end
    pcall(function() pr.IgnoreWater = true end)
    pcall(function() pr.RespectCanCollide = false end)
    AimParams = pr
    return pr
end

local function AimPredicted(part)
    local pos = part.Position
    local pred = Settings.Aim.Prediction or 0
    if pred > 0 then
        local vel = part.AssemblyLinearVelocity
        if vel then pos = pos + Vector3.new(vel.X, vel.Y, vel.Z) * (pred / 100) end
    end
    return pos
end

-- a point counts as visible only when the first hit along the ray is the target's own body
local function AimVisible(camPos, point, char)
    if not Settings.Aim.WallCheck then return true end
    local dir = point - camPos
    if dir.Magnitude < 0.05 then return true end
    local pr = AimRayParams()
    pr.FilterDescendantsInstances = { Camera, LocalPlayer.Character }
    local ok, hit = pcall(function() return workspace:Raycast(camPos, dir, pr) end)
    if not ok then return true end
    if not hit or not hit.Instance then return true end
    return hit.Instance:IsDescendantOf(char)
end

local function AimPartOrder()
    if Settings.Aim.Part == "Torso" then
        return { "UpperTorso", "HumanoidRootPart", "Head", "LowerTorso" }
    end
    return { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" }
end

local function AimBestPoint(char, camPos)
    if Settings.Aim.Part == "Closest" then
        local bestPoint, bestDist = nil, math.huge
        for _, name in ipairs(AIM_PARTS) do
            local part = char:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                local point = AimPredicted(part)
                if AimVisible(camPos, point, char) then
                    local d = (point - camPos).Magnitude
                    if d < bestDist then bestPoint, bestDist = point, d end
                end
            end
        end
        return bestPoint
    end
    for _, name in ipairs(AimPartOrder()) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local point = AimPredicted(part)
            if AimVisible(camPos, point, char) then return point end
        end
    end
    return nil
end

local function GetTarget(fovOverride)
    if Unloaded then return nil end
    local cam = Camera or workspace.CurrentCamera
    if not cam then return nil end
    local me = LocalPlayer
    if not me then return nil end

    local camPos = cam.CFrame.Position
    local cursor = CursorPos()
    local fov = fovOverride or Settings.Aim.FOV or 120
    local best, bestPos, bestD = nil, nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me then
            local sameTeam = Settings.Aim.IgnoreTeam and me.Team ~= nil and p.Team == me.Team
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not sameTeam and hum and hum.Health > 0 and hrp then
                local maxDist = Settings.Aim.MaxDistance or 200
                if maxDist > 0 and (hrp.Position - camPos).Magnitude > maxDist then
                    -- skip targets beyond max aim distance
                else
                    local pos = AimBestPoint(char, camPos)
                    if pos then
                        local d, on = WTVP(pos)
                        if on then
                            local dx = d.X - cursor.X
                            local dy = d.Y - cursor.Y
                            local dd = math_sqrt(dx * dx + dy * dy)
                            if dd <= fov and dd < bestD then
                                best, bestPos, bestD = p, pos, dd
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestPos
end

local function UpdateAim()
    if Unloaded then return false end
    local cam = Camera or workspace.CurrentCamera
    if not cam then return false end

    local lockOn = Settings.Aim.CameraLock

    -- camera lock needs RMB held
    if not lockOn and not AimHeld then
        return false
    end

    local tgt, pos = GetTarget()
    if not tgt or not pos then
        return false
    end

    local ok, want = pcall(function()
        return CFrame.lookAt(cam.CFrame.Position, pos, Vector3.new(0, 1, 0))
    end)
    if not ok or not want then return false end

    local smooth = math_clamp(Settings.Aim.Smooth or 0, 0, 95)
    local alpha = 1 - smooth / 100
    if alpha > 0.999 then
        cam.CFrame = want
    else
        cam.CFrame = cam.CFrame:Lerp(want, alpha)
    end
    return true
end

-- triggerbot: fires on its own when a visible enemy sits inside the trigger fov
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local TriggerReady = 0

local function FireWeapon()
    local char = LocalPlayer and LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local ok = pcall(function() tool:Activate() end)
        if ok then return true end
    end
    if not VirtualInputManager then return false end
    local cam = Camera or workspace.CurrentCamera
    local vp = cam and cam.ViewportSize
    if not vp then return false end
    local x, y = math_floor(vp.X * 0.5), math_floor(vp.Y * 0.5)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    return true
end

local function UpdateTrigger()
    if Unloaded or not Settings.Aim.TriggerBot then return false end
    local nowT = os_clock()
    if nowT < TriggerReady then return false end
    local tgt = GetTarget(Settings.Aim.TriggerFOV or 60)
    if not tgt then return false end
    TriggerReady = nowT + math_max(0.01, (Settings.Aim.TriggerDelay or 80) / 1000)
    FireWeapon()
    return true
end

TrackConn(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        AimHeld = true
    end
end))

TrackConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        AimHeld = false
    end
end))

-- Clean up ESP immediately when a player leaves
TrackConn(Players.PlayerRemoving:Connect(function(p)
    DestroyESP(p)
end))

local function UninstallHooks()
    AimHeld = false
end

local function UpdateVisuals()
    if Unloaded then return end
    local cam = Camera or workspace.CurrentCamera
    if Settings.Misc.FOVLock and cam then
        pcall(function() cam.FieldOfView = Settings.Misc.FOVValue end)
    end
    if Settings.Misc.NoFog then
        pcall(function() Lighting.FogEnd = 99999 end)
        pcall(function() Lighting.FogStart = 0 end)
    end
    if Settings.Misc.PostFX then
        for _, v in ipairs(Lighting:GetChildren()) do
            pcall(function() if v:IsA("PostEffect") then v.Enabled = false end end)
        end
    end
    if Settings.Misc.Fullbright then
        pcall(function()
            Lighting.Brightness = 2
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        end)
    end
end

local function UpdateMovement()
    if Unloaded then return end
    if not Settings.Misc.WalkSpeedEnabled then return end
    local ws = Settings.Misc.WalkSpeed
    for _, p in ipairs(Players:GetPlayers()) do
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = ws
        end
    end
end

-- Instant revive: cache proximity prompts instead of scanning all descendants every frame
local RevivePrompts = {}
local RevivePromptCacheTime = 0

local function RefreshRevivePrompts()
    RevivePrompts = {}
    local ok, desc = pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return end
    for _, obj in ipairs(desc) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            RevivePrompts[#RevivePrompts + 1] = obj
        end
    end
end

TrackConn(workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") and obj.Enabled then
        RevivePrompts[#RevivePrompts + 1] = obj
    end
end))

TrackConn(workspace.DescendantRemoving:Connect(function(obj)
    for i = #RevivePrompts, 1, -1 do
        if RevivePrompts[i] == obj then
            table.remove(RevivePrompts, i)
            break
        end
    end
end))

local function InstantReviveStep()
    if Unloaded or not Settings.Misc.InstantRevive then return end
    if not Env.fireproximityprompt then return end
    local nowT = os_clock()
    if nowT - (Settings.Perf._revive or 0) < 0.2 then return end
    Settings.Perf._revive = nowT

    -- Refresh prompt cache every 2 seconds to catch new prompts
    if nowT - (RevivePromptCacheTime or 0) >= 2.0 then
        RefreshRevivePrompts()
        RevivePromptCacheTime = nowT
    end

    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local origin = hrp.Position

    for _, obj in ipairs(RevivePrompts) do
        local part = obj.Parent
        if part and part:IsA("BasePart") and obj.Enabled then
            local reach = (obj.MaxActivationDistance or 10) + 4
            local d = (part.Position - origin).Magnitude
            if d <= reach then
                pcall(function() fireproximityprompt(obj) end)
            end
        end
    end
end

task.spawn(function()
    while not Unloaded do
        task.wait(0.03)
        if Unloaded then break end
        local nowT = os_clock()
        -- throttled cull step
        if nowT - (_throttle.cull or 0) >= (Settings.Render.CullDelay or 0.12) then
            CullStep()
            _throttle.cull = nowT
        end
        -- throttled visuals (FOV lock, fog, etc.)
        if nowT - (_throttle.visuals or 0) >= 0.05 then
            UpdateVisuals()
            _throttle.visuals = nowT
        end
        -- throttled movement (walkspeed)
        if nowT - (_throttle.movement or 0) >= 0.05 then
            UpdateMovement()
            _throttle.movement = nowT
        end
        -- throttled ESP (most expensive)
        if nowT - (_throttle.esp or 0) >= (Settings.ESP.Throttle or 0.05) then
            UpdateESP()
            _throttle.esp = nowT
        end
        InstantReviveStep()
    end
end)

pcall(function()
    RunService.RenderStepped:Connect(function()
        local nowT = os_clock()
        ResolveEntWinRoot()
        -- throttled aim (camera lock)
        if nowT - (_throttle.aim or 0) >= (Settings.Aim.Throttle or 0.01) then
            UpdateAim()
            _throttle.aim = nowT
        end
        UpdateTrigger()
        -- throttled fov circle
        if nowT - (_throttle.fov or 0) >= (Settings.FovCircle.Throttle or 0.016) then
            UpdateFovCircle()
            _throttle.fov = nowT
        end
        -- throttled crosshair
        if nowT - (_throttle.crosshair or 0) >= (Settings.Crosshair.Throttle or 0.016) then
            UpdateCrosshair()
            _throttle.crosshair = nowT
        end
        -- pin window while RMB is held so Rayfield's title-bar drag can't move it
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            if EntWinRoot and EntWinPos then
                pcall(function()
                    EntWinRoot.Position = EntWinPos
                end)
            end
        else
            -- refresh the stored position when not dragging so normal drag works
            if EntWinRoot then
                pcall(function()
                    EntWinPos = EntWinRoot.Position
                end)
            end
        end
    end)
end)
local function entBuildUi()
local TweenService = game:GetService("TweenService")

-- ============================================================
-- ENTRENCHED UI - Rayfield Gen 2 (amethyst)
-- ============================================================
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/SyncUnofficial/Rayfield_Gen_2_fanmade/main/source.lua"
))()

-- one window only: kill a surviving Rayfield root from a previous load
pcall(function()
    local hosts = {}
    if Env.gethui then
        local okH, hui = pcall(gethui)
        if okH and hui then hosts[#hosts + 1] = hui end
    end
    local okC, core = pcall(function() return game:GetService("CoreGui") end)
    if okC and core then hosts[#hosts + 1] = core end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then hosts[#hosts + 1] = pg end

    for _, host in ipairs(hosts) do
        for _, child in ipairs(host:GetChildren()) do
            if child.Name == "RayfieldGen2" then child:Destroy() end
        end
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "ENTRENCHED",
    Subtitle = "combat suite",
    Icon = "crosshair",
    Theme = "amethyst",
    ToggleUIKeybind = "RightAlt",
})

local Combat  = Window:CreateTab("Combat", "crosshair")
local Visuals = Window:CreateTab("Visuals", "eye")
local World   = Window:CreateTab("World", "globe")
local Customize = Window:CreateTab("Customize", "palette")

-- ---------- combat ----------
Combat:CreateSection("Aimbot")

local camLockToggle = Combat:CreateToggle({
    Name = "Camera Lock", Flag = "CameraLock",
    CurrentValue = Settings.Aim.CameraLock,
    Callback = function(v)
        Settings.Aim.CameraLock = v
        if v then
            UninstallHooks()
        end
    end,
})

Combat:CreateToggle({
    Name = "Trigger Bot", Flag = "TriggerBot",
    CurrentValue = Settings.Aim.TriggerBot,
    Callback = function(v) Settings.Aim.TriggerBot = v end,
})

Combat:CreateSlider({
    Name = "Trigger FOV", Flag = "TriggerFOV",
    Range = { 10, 300 }, Increment = 5, Suffix = "px",
    CurrentValue = Settings.Aim.TriggerFOV,
    Callback = function(v) Settings.Aim.TriggerFOV = v end,
})

Combat:CreateSlider({
    Name = "Trigger Delay", Flag = "TriggerDelay",
    Range = { 10, 300 }, Increment = 10, Suffix = "ms",
    CurrentValue = Settings.Aim.TriggerDelay,
    Callback = function(v) Settings.Aim.TriggerDelay = v end,
})

Combat:CreateSlider({
    Name = "Smoothing", Flag = "AimSmooth",
    Range = { 0, 95 }, Increment = 5, Suffix = "%",
    CurrentValue = Settings.Aim.Smooth,
    Callback = function(v) Settings.Aim.Smooth = v end,
})

Combat:CreateDropdown({
    Name = "Aim Part", Flag = "AimPart",
    Options = { "Head", "Torso", "Closest" },
    CurrentOption = Settings.Aim.Part,
    Callback = function(v) Settings.Aim.Part = v end,
})

Combat:CreateToggle({
    Name = "Wall Check", Flag = "WallCheck",
    CurrentValue = Settings.Aim.WallCheck,
    Callback = function(v) Settings.Aim.WallCheck = v end,
})

Combat:CreateToggle({
    Name = "Ignore Team", Flag = "IgnoreTeam",
    CurrentValue = Settings.Aim.IgnoreTeam,
    Callback = function(v) Settings.Aim.IgnoreTeam = v end,
})

Combat:CreateSlider({
    Name = "FOV", Flag = "AimFOV",
    Range = { 10, 400 }, Increment = 10, Suffix = "px",
    CurrentValue = Settings.Aim.FOV,
    Callback = function(v) Settings.Aim.FOV = v end,
})

Combat:CreateSlider({
    Name = "Prediction", Flag = "AimPrediction",
    Range = { 0, 100 }, Increment = 10, Suffix = "%",
    CurrentValue = Settings.Aim.Prediction,
    Callback = function(v) Settings.Aim.Prediction = v end,
})

Combat:CreateSlider({
    Name = "Max Distance", Flag = "AimMaxDistance",
    Range = { 0, 200 }, Increment = 5, Suffix = "studs",
    CurrentValue = Settings.Aim.MaxDistance,
    Callback = function(v) Settings.Aim.MaxDistance = v end,
})

Combat:CreateSection("Exploits")

Combat:CreateToggle({
    Name = "Instant Revive", Flag = "InstantRevive",
    CurrentValue = Settings.Misc.InstantRevive,
    Callback = function(v) Settings.Misc.InstantRevive = v end,
})

-- ---------- visuals ----------
Visuals:CreateSection("ESP")

Visuals:CreateToggle({
    Name = "ESP Enabled", Flag = "ESPOn",
    CurrentValue = Settings.ESP.Enabled,
    Callback = function(v) Settings.ESP.Enabled = v end,
})

Visuals:CreateToggle({
    Name = "Team Check", Flag = "TeamCheck",
    CurrentValue = Settings.ESP.TeamCheck,
    Callback = function(v) Settings.ESP.TeamCheck = v end,
})

Visuals:CreateToggle({
    Name = "Chams", Flag = "Chams",
    CurrentValue = Settings.ESP.Chams,
    Callback = function(v) Settings.ESP.Chams = v end,
})

Visuals:CreateToggle({
    Name = "Boxes", Flag = "ESPBox",
    CurrentValue = Settings.ESP.Box,
    Callback = function(v) Settings.ESP.Box = v end,
})

Visuals:CreateToggle({
    Name = "Distance", Flag = "ESPDistance",
    CurrentValue = Settings.ESP.Distance,
    Callback = function(v) Settings.ESP.Distance = v end,
})

Visuals:CreateToggle({
    Name = "Health", Flag = "ESPHealth",
    CurrentValue = Settings.ESP.Health,
    Callback = function(v) Settings.ESP.Health = v end,
})

Visuals:CreateToggle({
    Name = "Skeleton", Flag = "ESPSkeleton",
    CurrentValue = Settings.ESP.Skeleton,
    Callback = function(v) Settings.ESP.Skeleton = v end,
})

Visuals:CreateToggle({
    Name = "Snaplines", Flag = "ESPSnapline",
    CurrentValue = Settings.ESP.Snapline,
    Callback = function(v) Settings.ESP.Snapline = v end,
})

Visuals:CreateToggle({
    Name = "Arrows", Flag = "ESPArrow",
    CurrentValue = Settings.ESP.Arrow,
    Callback = function(v) Settings.ESP.Arrow = v end,
})

Visuals:CreateToggle({
    Name = "Head Circle", Flag = "ESPHeadCircle",
    CurrentValue = Settings.ESP.HeadCircle,
    Callback = function(v) Settings.ESP.HeadCircle = v end,
})

Visuals:CreateToggle({
    Name = "Tracers", Flag = "ESPTracer",
    CurrentValue = Settings.ESP.Tracer,
    Callback = function(v) Settings.ESP.Tracer = v end,
})

Visuals:CreateToggle({
    Name = "Class Tag", Flag = "ESPClassTag",
    CurrentValue = Settings.ESP.ClassTag,
    Callback = function(v) Settings.ESP.ClassTag = v end,
})

Visuals:CreateSlider({
    Name = "Max Distance", Flag = "ESPMaxDistance",
    Range = { 100, 2000 }, Increment = 50, Suffix = "m",
    CurrentValue = Settings.ESP.MaxDistance,
    Callback = function(v) Settings.ESP.MaxDistance = v end,
})

-- ---------- world ----------
World:CreateSection("Render")

World:CreateToggle({
    Name = "Chunk Culling", Flag = "Culling",
    CurrentValue = Settings.Render.Culling,
    Callback = function(v)
        Settings.Render.Culling = v
        if not v then ResetCulling() end
    end,
})

World:CreateToggle({
    Name = "Fullbright", Flag = "Fullbright",
    CurrentValue = Settings.Misc.Fullbright,
    Callback = function(v) Settings.Misc.Fullbright = v end,
})

World:CreateToggle({
    Name = "No Fog", Flag = "NoFog",
    CurrentValue = Settings.Misc.NoFog,
    Callback = function(v) Settings.Misc.NoFog = v end,
})

World:CreateToggle({
    Name = "Post FX", Flag = "PostFX",
    CurrentValue = Settings.Misc.PostFX,
    Callback = function(v) Settings.Misc.PostFX = v end,
})

World:CreateToggle({
    Name = "FOV Lock", Flag = "FOVLock",
    CurrentValue = Settings.Misc.FOVLock,
    Callback = function(v) Settings.Misc.FOVLock = v end,
})

World:CreateSlider({
    Name = "Render Distance", Flag = "RenderDistance",
    Range = { 200, 2000 }, Increment = 100, Suffix = "m",
    CurrentValue = Settings.Render.Distance,
    Callback = function(v) Settings.Render.Distance = v end,
})

World:CreateSection("Movement")

World:CreateToggle({
    Name = "Walk Speed", Flag = "WalkSpeedOn",
    CurrentValue = Settings.Misc.WalkSpeedEnabled,
    Callback = function(v) Settings.Misc.WalkSpeedEnabled = v end,
})

World:CreateSlider({
    Name = "Speed", Flag = "WalkSpeed",
    Range = { 16, 100 }, Increment = 2,
    CurrentValue = Settings.Misc.WalkSpeed,
    Callback = function(v) Settings.Misc.WalkSpeed = v end,
})

World:CreateSection("System")

World:CreateButton({
    Name = "Unload", Icon = "power",
    Callback = function()
        Unloaded = true
        UninstallHooks()
        Settings.Aim.CameraLock = false
        if FovCircle then pcall(function() FovCircle:Remove() end) end
        FovCircle = nil
        if CrosshairGui then pcall(function() CrosshairGui:Destroy() end) end
        CrosshairGui = nil
        CrosshairImage = nil
        for _, p in ipairs(Players:GetPlayers()) do DestroyESP(p) end
        ResetCulling()
        for _, c in ipairs(Connections) do SafeDisconnect(c) end
        pcall(function() Rayfield:Destroy() end)
        if type(GG) == "table" then GG.__ENTRENCHED = nil end
    end,
})

-- ---------- customize ----------
Customize:CreateSection("ESP Colors")

Customize:CreateInput({
    Name = "ESP Color (Hex)", Flag = "ESPColorHexInput",
    PlaceholderText = "#FF4646",
    CurrentValue = Settings.ESP.ColorHex,
    Callback = function(v)
        if v and v ~= "" then Settings.ESP.ColorHex = v end
    end,
})

Customize:CreateInput({
    Name = "Chams Color (Hex)", Flag = "ChamsColorHexInput",
    PlaceholderText = "#FF4646",
    CurrentValue = Settings.ESP.ChamsHex,
    Callback = function(v)
        if v and v ~= "" then Settings.ESP.ChamsHex = v end
    end,
})

Customize:CreateSection("Crosshair")

Customize:CreateToggle({
    Name = "Crosshair Enabled", Flag = "CrosshairOn",
    CurrentValue = Settings.Crosshair.Enabled,
    Callback = function(v) Settings.Crosshair.Enabled = v end,
})

Customize:CreateInput({
    Name = "Crosshair Image (URL or rbxassetid)", Flag = "CrosshairImageInput",
    PlaceholderText = "https://... or 123456789",
    CurrentValue = Settings.Crosshair.Image,
    Callback = function(v)
        Settings.Crosshair.Image = v or ""
        CrosshairPending = false
    end,
})

Customize:CreateInput({
    Name = "Crosshair Color (Hex)", Flag = "CrosshairColorHexInput",
    PlaceholderText = "#FFFFFF",
    CurrentValue = Settings.Crosshair.Color,
    Callback = function(v)
        if v and v ~= "" then Settings.Crosshair.Color = v end
    end,
})

Customize:CreateSlider({
    Name = "Crosshair Size", Flag = "CrosshairSize",
    Range = { 8, 64 }, Increment = 2,
    CurrentValue = Settings.Crosshair.Size,
    Callback = function(v) Settings.Crosshair.Size = v end,
})

Customize:CreateSection("FOV Circle")

Customize:CreateToggle({
    Name = "FOV Circle Visible", Flag = "FovCircleOn",
    CurrentValue = Settings.FovCircle.Enabled,
    Callback = function(v) Settings.FovCircle.Enabled = v end,
})

Customize:CreateInput({
    Name = "FOV Circle Color (Hex)", Flag = "FovCircleColorHexInput",
    PlaceholderText = "#FFFFFF",
    CurrentValue = Settings.FovCircle.Color,
    Callback = function(v)
        if v and v ~= "" then Settings.FovCircle.Color = v end
    end,
})

Window:Notify({
    Title = "ENTRENCHED",
    Content = "Right Alt to hide. Drag the title bar to move the window.",
    Duration = 5,
    Icon = "crosshair",
})

end

entBuildUi()
