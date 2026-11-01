-- Minimal signal implementation (no dependencies).

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn, connected = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			task.spawn(entry.fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
