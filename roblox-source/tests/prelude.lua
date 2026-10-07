-- ============================================================================
-- Мини-эмуляция Roblox API для запуска серверной логики в стандартном `luau`.
-- Это НЕ Roblox: проверяется логика (DataStore/session lock, чеки, экономика), а не движок.
-- ============================================================================
local realClock = os.clock
local VIRTUAL = { now = 1700000000 + 5 * 86400 + 3600, mono = 0 }
os = {
	time = function()
		return math.floor(VIRTUAL.now)
	end,
	clock = function()
		return VIRTUAL.mono
	end,
	date = os.date,
}

-- ---- планировщик задач (виртуальное время) ----
local sleepers = {}
local task_ = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("[task error] " .. tostring(err))
		TEST_ERRORS = (TEST_ERRORS or 0) + 1
	end
end
function task_.spawn(fn, ...)
	local co = coroutine.create(fn)
	resume(co, ...)
	return co
end
function task_.defer(fn, ...)
	return task_.spawn(fn, ...)
end
function task_.delay(t, fn, ...)
	local args = { ... }
	return task_.spawn(function()
		task_.wait(t)
		fn(table.unpack(args))
	end)
end
function task_.wait(t)
	t = t or 0.03
	local co = coroutine.running()
	table.insert(sleepers, { Wake = VIRTUAL.mono + t, Co = co })
	coroutine.yield()
	return t
end
task = task_
function RESET_SCHEDULER()
	sleepers = {}
end
function DRIVE_UNTIL_IDLE(limit)
	local guard = 0
	local deadline = VIRTUAL.mono + (limit or 400)
	while #sleepers > 0 do
		guard += 1
		if guard > 200000 then
			error("scheduler guard tripped")
		end
		table.sort(sleepers, function(a, b)
			return a.Wake < b.Wake
		end)
		if sleepers[1].Wake > deadline then
			break
		end
		local s = table.remove(sleepers, 1)
		local dt = s.Wake - VIRTUAL.mono
		if dt > 0 then
			VIRTUAL.mono = s.Wake
			VIRTUAL.now += dt
		end
		resume(s.Co)
	end
end
function ADVANCE(seconds)
	VIRTUAL.mono += seconds
	VIRTUAL.now += seconds
end
function SET_WALL_CLOCK(t)
	VIRTUAL.now = t
end
function GET_WALL_CLOCK()
	return VIRTUAL.now
end

warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	WARNINGS = WARNINGS or {}
	table.insert(WARNINGS, table.concat(parts, " "))
end

-- ---- математические типы ----
local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		return setmetatable({ X = t.X / m, Y = t.Y / m, Z = t.Z / m }, V3)
	end
	return nil
end
V3.__add = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3)
end
V3.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V3)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return setmetatable({ X = a.X * b, Y = a.Y * b, Z = a.Z * b }, V3)
	end
	return setmetatable({ X = a.X * b.X, Y = a.Y * b.Y, Z = a.Z * b.Z }, V3)
end
V3.__unm = function(a)
	return setmetatable({ X = -a.X, Y = -a.Y, Z = -a.Z }, V3)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
local CF = {}
CF.__index = function(t, k)
	if k == "Position" then
		return t.p
	end
	return nil
end
CF.__mul = function(a, b)
	if b.p ~= nil and b.X == nil then
		return setmetatable({ p = a.p + b.p }, CF)
	end
	return setmetatable({ p = a.p + b }, CF)
end
CF.__add = function(a, b)
	return setmetatable({ p = a.p + b }, CF)
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return setmetatable({ p = x }, CF)
		end
		return setmetatable({ p = Vector3.new(x or 0, y or 0, z or 0) }, CF)
	end,
	Angles = function()
		return setmetatable({ p = Vector3.zero }, CF)
	end,
	lookAt = function(a)
		return setmetatable({ p = a }, CF)
	end,
}
UDim2 = setmetatable({}, {
	__index = function()
		return function()
			return {}
		end
	end,
})
UDim = UDim2
-- Random.new(seed): детерминированный генератор (xorshift), как в Roblox выдаёт одинаковую последовательность на одинаковый seed
Random = {
	new = function(seed)
		local state = ((seed or os.time()) * 2654435761 + 12345) % 4294967296
		if state == 0 then
			state = 88172645
		end
		local function nextRaw()
			state = (state * 1664525 + 1013904223) % 4294967296
			return state / 4294967296
		end
		return {
			NextNumber = function(_, a, b)
				local r = if seed == nil then math.random() else nextRaw()
				if a then
					return a + (b - a) * r
				end
				return r
			end,
			NextInteger = function(_, a, b)
				local r = if seed == nil then math.random() else nextRaw()
				return a + math.floor(r * (b - a + 1))
			end,
		}
	end,
}

-- Enum: Enum.X.Y -> строка "Enum.X.Y"
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return "Enum." .. enumName .. "." .. item
			end,
		})
	end,
})

-- ---- сигналы ----
local function makeSignal()
	local s = { _handlers = {} }
	function s:Connect(fn)
		table.insert(self._handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Once(fn)
		return self:Connect(fn)
	end
	function s:Fire(...)
		for _, h in ipairs(self._handlers) do
			task.spawn(h, ...)
		end
	end
	return s
end
MAKE_SIGNAL = makeSignal

-- ---- Instance-подобные узлы ----
local Methods = {}
local function setParent(node, parent)
	local old = rawget(node, "_parent")
	if old then
		local ch = rawget(old, "_children")
		if ch[rawget(node, "_props").Name] == node then
			ch[rawget(node, "_props").Name] = nil
		end
		for i, c in ipairs(rawget(old, "_list")) do
			if c == node then
				table.remove(rawget(old, "_list"), i)
				break
			end
		end
	end
	rawset(node, "_parent", parent)
	if parent then
		rawget(parent, "_children")[rawget(node, "_props").Name] = node
		table.insert(rawget(parent, "_list"), node)
	end
end
local NodeMT = {}
NodeMT.__index = function(t, k)
	local m = Methods[k]
	if m then
		return m
	end
	if k == "Parent" then
		return rawget(t, "_parent")
	end
	if k == "ClassName" then
		return rawget(t, "_class")
	end
	local props = rawget(t, "_props")
	if props[k] ~= nil then
		return props[k]
	end
	return rawget(t, "_children")[k]
end
NodeMT.__newindex = function(t, k, v)
	if k == "Parent" then
		setParent(t, v)
	else
		rawget(t, "_props")[k] = v
	end
end
local function newNode(class, name)
	local n = setmetatable(
		{ _class = class, _props = { Name = name or class }, _children = {}, _list = {}, _attrs = {} },
		NodeMT
	)
	if class == "RemoteEvent" then
		rawget(n, "_props").OnServerEvent = makeSignal()
		rawget(n, "_props").OnClientEvent = makeSignal()
		rawset(n, "_fired", {})
	elseif class == "ProximityPrompt" then
		rawget(n, "_props").Triggered = makeSignal()
	end
	return n
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in ipairs(rawget(n, "_list")) do
			if rawget(c, "_parent") == n then
				table.insert(out, c)
				walk(c)
			end
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name)
	return rawget(self, "_children")[name]
end
function Methods.WaitForChild(self, name)
	return rawget(self, "_children")[name]
end
function Methods.GetChildren(self)
	return rawget(self, "_list")
end
function Methods.Destroy() end
local BASE_PARTS = { Part = true, MeshPart = true, WedgePart = true, TrussPart = true }
function Methods.IsA(self, class)
	local c = rawget(self, "_class")
	return c == class or class == "Instance" or (class == "BasePart" and BASE_PARTS[c] == true)
end
function Methods.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
	local sigs = rawget(self, "_attrSignals")
	if sigs and sigs[k] then
		sigs[k]:Fire()
	end
end
function Methods.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function Methods.FireClient(self, player, ...)
	table.insert(rawget(self, "_fired"), { Player = player, Args = { ... } })
end
function Methods.FireServer() end
function Methods.GetPlayers(self)
	return rawget(self, "_list")
end
function Methods.GetPlayerByUserId(self, id)
	for _, p in ipairs(rawget(self, "_list")) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
function Methods.PivotTo() end
-- масштаб модели (Model:ScaleTo/GetScale) и pivot — для Суперсилы
function Methods.ScaleTo(self, s)
	assert(type(s) == "number" and s > 0, "ScaleTo: scale must be > 0")
	rawget(self, "_props").ScaleFactor = s
end
function Methods.GetScale(self)
	return rawget(self, "_props").ScaleFactor or 1
end
function Methods.GetPivot(self)
	local hrp = rawget(self, "_children").HumanoidRootPart
	return CFrame.new(if hrp and hrp.Position then hrp.Position else Vector3.zero)
end
function Methods.GetAttributeChangedSignal(self, k)
	local sigs = rawget(self, "_attrSignals")
	if not sigs then
		sigs = {}
		rawset(self, "_attrSignals", sigs)
	end
	sigs[k] = sigs[k] or MAKE_SIGNAL()
	return sigs[k]
end
function Methods.LoadCharacterAsync() end
function Methods.Kick(self, msg)
	rawget(self, "_props").Kicked = msg
	setParent(self, nil)
end
function Methods.FindFirstChildOfClass(self, class)
	for _, c in ipairs(rawget(self, "_list")) do
		if rawget(c, "_class") == class then
			return c
		end
	end
	return nil
end
FIRED = function(node)
	return rawget(node, "_fired")
end
Instance = {
	new = function(class)
		return newNode(class)
	end,
}
NEW_NODE = newNode

-- ---- «вселенная» одного сервера ----
BACKEND = { Stores = {}, Ordered = {}, FailNext = 0, FailAlways = false, Writes = 0, Log = {} }

local function makeStore(name)
	BACKEND.Stores[name] = BACKEND.Stores[name] or {}
	local data = BACKEND.Stores[name]
	local function copy(v)
		if type(v) ~= "table" then
			return v
		end
		local c = {}
		for k, x in pairs(v) do
			c[k] = copy(x)
		end
		return c
	end
	local store = {}
	function store:UpdateAsync(key, fn)
		if BACKEND.FailAlways then
			error("simulated datastore outage")
		end
		if BACKEND.FailNext > 0 then
			BACKEND.FailNext -= 1
			error(BACKEND.ErrorMessage or "simulated datastore error")
		end
		local old = copy(data[key])
		local new = fn(old)
		if new == nil then
			return nil
		end
		data[key] = copy(new)
		BACKEND.Writes += 1
		return copy(new)
	end
	function store:SetAsync(key, v)
		data[key] = v
	end
	return store
end

function MAKE_UNIVERSE(label)
	local U = { Label = label, Modules = {}, Loaded = {} }
	local guidCounter = 0
	local root = newNode("DataModel", "game")
	local services = {}
	local function svc(name)
		local n = newNode(name, name)
		services[name] = n
		return n
	end
	local RS, SSS = svc("ReplicatedStorage"), svc("ServerScriptService")
	U.Workspace = svc("Workspace") -- общий Workspace (атрибуты-переключатели видны всем модулям)
	local players = svc("Players")
	players.PlayerAdded = makeSignal()
	players.PlayerRemoving = makeSignal()
	players.PlayerMembershipChanged = makeSignal()
	services.HttpService = {
		GenerateGUID = function()
			guidCounter += 1
			return label .. "-guid-" .. guidCounter
		end,
	}
	services.RunService = {
		IsStudio = function()
			return U.IsStudio == true
		end,
		IsServer = function()
			return true
		end,
		Heartbeat = makeSignal(),
	}
	services.DataStoreService = {
		GetDataStore = function(_, name)
			return makeStore(name)
		end,
		GetOrderedDataStore = function(_, name)
			return makeStore(name)
		end,
	}
	local market = { PromptGamePassPurchaseFinished = makeSignal(), OwnedPasses = {} }
	function market:UserOwnsGamePassAsync(userId, passId)
		return self.OwnedPasses[userId .. ":" .. passId] == true
	end
	services.MarketplaceService = market
	services.PolicyService = {
		GetPolicyInfoForPlayerAsync = function()
			if U.PolicyError then
				error("policy unavailable")
			end
			return { ArePaidRandomItemsRestricted = U.Restricted == true }
		end,
	}
	U.Market = market
	U.Players = players

	local gameObj = {
		JobId = label,
		GetService = function(_, name)
			return services[name] or newNode(name, name)
		end,
		BindToClose = function(_, fn)
			U.CloseFn = fn
		end,
	}
	U.Game = gameObj
	U.RS, U.SSS = RS, SSS

	-- Регистрация исходников: path = "ReplicatedStorage/Shared/Config"
	function U.register(path, fn)
		local parts = {}
		for p in string.gmatch(path, "[^/]+") do
			table.insert(parts, p)
		end
		local parent = services[parts[1]]
		for i = 2, #parts - 1 do
			local child = parent:FindFirstChild(parts[i])
			if not child then
				child = newNode("Folder", parts[i])
				child.Parent = parent
			end
			parent = child
		end
		local node = newNode("ModuleScript", parts[#parts])
		node.Parent = parent
		rawset(node, "_fn", fn)
		rawset(node, "_universe", U)
		U.Modules[path] = node
	end
	function U.require(path)
		return REQUIRE(U.Modules[path])
	end
	U.registerStub = U.register
	return U
end

function REQUIRE(node)
	local cached = rawget(node, "_value")
	if cached ~= nil then
		return cached
	end
	local universe = rawget(node, "_universe")
	local prevGame = game
	game = universe.Game
	local value = rawget(node, "_fn")(node)
	game = prevGame
	rawset(node, "_value", value)
	return value
end
require = REQUIRE

function MAKE_PLAYER(universe, userId, name)
	local p = NEW_NODE("Player", name)
	p.UserId = userId
	p.DisplayName = name
	p.MembershipType = "Enum.MembershipType.None"
	p.CharacterAdded = MAKE_SIGNAL()
	p.Parent = universe.Players
	return p
end
