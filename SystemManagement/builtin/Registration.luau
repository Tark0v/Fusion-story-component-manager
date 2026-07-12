local module = {}
local registry = {}

function module.RegisterContainer(containerID: string)
	assert(registry[containerID] == nil, `{containerID} already exists`)
	registry[containerID] = {}
end

function module.GetFromRegistry(containerID: string, instanceID: string): any
	local validRegistry = assert(registry[containerID], `{containerID} Does not exists`)
	return validRegistry[instanceID]
end

function module.AddToRegistry<T>(containerID: string, instanceID: string, instanceRef: T): T
	local validRegistry = assert(registry[containerID], `{containerID} Does not exists`)
	validRegistry[instanceID] = instanceRef
	
	return instanceRef
end

function module.RemoveFromRegistry(containerID: string, instanceID: string)
	local validRegistry = assert(registry[containerID], `{containerID} Does not exists`)
	local object = validRegistry[instanceID]
	validRegistry[instanceID] = nil
	
	return object
end

function module.GetRegistry(containerID: string)
	return registry[containerID]
end

return module
