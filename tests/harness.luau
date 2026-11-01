-- Lune test harness: loads Roblox-style ModuleScripts from src/ by emulating `script`,
-- `script.Parent.X` lookups and `require(instance)` on top of the file system, plus minimal
-- shims for the Roblox globals the pure shared modules use (Color3, Vector3, Random).
-- Run with:  lune run tests/run

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Harness = {}

------------------------------------------------------------------------------------------
-- Roblox datatype shims (only what the shared modules touch)
------------------------------------------------------------------------------------------
local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
end

local Vector3 = {}
function Vector3.new(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

-- Deterministic Random shim (xorshift32) with the Roblox Random API subset
local Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor(seed or os.clock() * 1e6) % 4294967296
	if s == 0 then
		s = 2463534242
	end
	return setmetatable({ s = s }, Random)
end
function Random:_next()
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x / 4294967296
end
function Random:NextNumber(min, max)
	local r = self:_next()
	if min then
		return min + (max - min) * r
	end
	return r
end
function Random:NextInteger(min, max)
	return min + math.floor(self:_next() * (max - min + 1))
end

Harness.Random = Random

------------------------------------------------------------------------------------------
-- Fake instance tree over the file system
------------------------------------------------------------------------------------------
local cache = {}
local nodeMeta = {}

local function makeNode(path: string, parent)
	return setmetatable({ __path = path, __parent = parent }, nodeMeta)
end

nodeMeta.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "__parent")
	end
	local path = rawget(self, "__path")
	local dir = path:gsub("%.luau$", "")
	local child = dir .. "/" .. key
	if fs.isDir(child) then
		local n = makeNode(child, self)
		rawset(self, key, n)
		return n
	elseif fs.isFile(child .. ".luau") then
		local n = makeNode(child .. ".luau", self)
		rawset(self, key, n)
		return n
	end
	error(`No child '{key}' under {path}`)
end

local function load(node)
	local path = rawget(node, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = fs.readFile(path)
	local env = setmetatable({
		script = node,
		require = function(target)
			return load(target)
		end,
		Color3 = Color3,
		Vector3 = Vector3,
		Random = Random,
	}, { __index = _G })
	local fn = luau.load(source, { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

-- Harness.require("src/shared/LootRoll")
function Harness.require(relPath: string)
	local parts = string.split(relPath, "/")
	local node = makeNode(parts[1], nil)
	for i = 2, #parts do
		node = node[parts[i]]
	end
	return load(node)
end

------------------------------------------------------------------------------------------
-- Tiny test runner
------------------------------------------------------------------------------------------
local results = { passed = 0, failed = 0 }

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
		print("  ✓ " .. name)
	else
		results.failed += 1
		print("  ✗ " .. name .. "\n      " .. tostring(err))
	end
end

function Harness.describe(name: string, fn: () -> ())
	print(name)
	fn()
end

function Harness.expect(cond: boolean, msg: string?)
	if not cond then
		error(msg or "expectation failed", 2)
	end
end

function Harness.near(a: number, b: number, tol: number, msg: string?)
	if math.abs(a - b) > tol then
		error(`{msg or "value"}: expected {b} ± {tol}, got {a}`, 2)
	end
end

function Harness.results()
	return results
end

return Harness
