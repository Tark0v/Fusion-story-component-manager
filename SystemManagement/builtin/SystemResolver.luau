local SystemResolver = {}
SystemResolver.__index = SystemResolver

function SystemResolver.new()
	local self = setmetatable({
		_eventTransmitters = {},
		_connections = {}
	}, SystemResolver)
	
	return self
end

function SystemResolver:EventTransmitter(name, callback)
	self._eventTransmitters[name] = callback

	return {
		Disconnect = function()
			if self._eventTransmitters[name] == callback then
				self._eventTransmitters[name] = nil
			end
		end,
	}
end

function SystemResolver:Transmit(name, ...)
	local callback = self._eventTransmitters[name]
	if not callback then
		return nil
	end
	
	return callback(...)
end

function SystemResolver:Destroy()
	table.clear(self._eventTransmitters)
	
	for _, disconnect in ipairs(self._connections) do
		disconnect()
	end
	
	table.clear(self._connections)
end

return SystemResolver