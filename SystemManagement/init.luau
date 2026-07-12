
local builtin = script.builtin
local packages = script.Packages

local EventGraph = require(builtin.EventGraph)
local Registration = require(builtin.Registration)
local SystemResolver = require(builtin.SystemResolver)

local FusionTypes = require(packages.FusionTypes)

local registerSystem = {}
local registerSystemMeta = {}

Registration.RegisterContainer("Systems")

function registerSystem.New(rootScope: FusionTypes.SCOPE, systemName: string)
	if not Registration.GetFromRegistry("Systems", systemName) then
		local systemObject = setmetatable({
			systemScope = FusionTypes.innerScope(rootScope),
			initDetails = {
				_listener = nil:: (FusionTypes.SCOPE)->nil?,
				_initScope = nil:: FusionTypes.SCOPE?,
				_thread = nil:: thread?
			},
			resolvers = {},
			eventGraph = EventGraph.new(),
			eventTransmitter = SystemResolver.new(),
		}, registerSystemMeta)
		
		Registration.AddToRegistry("Systems", systemName, systemObject)
		
		return systemObject
	end
	
	warn(`SystemManagement: {systemName} is already registered`)
end

export type SystemObject = typeof(registerSystem.New())

function registerSystem.AwaitSystem(systemName: string, awaitTime: number?): SystemObject
	local systemObject = Registration.GetFromRegistry("Systems", systemName)
	if not systemObject then
		local start = os.clock()
		repeat
			task.wait(.01)
			systemObject = Registration.GetFromRegistry("Systems", systemName)
		until systemObject or awaitTime and os.clock() - start >= awaitTime
	end	
	
	if not systemObject then
		warn(`Unyielded after await time ran out: {systemName}`)
	end
	
	return systemObject
end

function registerSystemMeta.GetTransmitter(systemObject: SystemObject)
	return systemObject.eventTransmitter
end

function registerSystem.GetSystemFromID(systemName: string): SystemObject
	return Registration.GetFromRegistry("Systems", systemName)
end

function registerSystem.GetEventFromSystem(systemName: string, eventID: string)
	local systemObject: SystemObject = Registration.GetFromRegistry("Systems", systemName)
	if systemObject then
		return systemObject:GetEventFromGraph(eventID)
	end
end

function registerSystem.DestroySystemsFromList(systemList: {string})
	for _, systemName in systemList do
		local systemObject: SystemObject = Registration.GetFromRegistry("Systems", systemName)	
		if systemObject then
			systemObject:Destroy()
		end	
	end
end

function registerSystem.DestroyAllSystems()
	for _, systemObject: SystemObject in Registration.GetRegistry("Systems") do
		systemObject:Destroy()
	end
end

registerSystemMeta.__index = registerSystemMeta

function registerSystemMeta.EventTransmitter(systemObject: SystemObject, ...)
	return systemObject.eventTransmitter:EventTransmitter(...)
end

function registerSystemMeta.Transmit(systemObject: SystemObject, ...)
	return systemObject.eventTransmitter:Transmit(...)
end

function registerSystemMeta.GetEventFromGraph(systemObject: SystemObject, eventID: string)
	return systemObject.eventGraph:GetEvent(eventID)
end

function registerSystemMeta.StopSystem(systemObject: SystemObject)
	local systemInitDetails = systemObject.initDetails
	if systemInitDetails._thread then
		task.cancel(systemInitDetails._thread)
		systemInitDetails._thread = nil
	end
	
	if systemInitDetails._initScope then
		systemInitDetails._initScope:doCleanup()
		systemInitDetails._initScope = nil
	end
end

function registerSystemMeta.StartSystem(systemObject: SystemObject)
	local systemInitDetails = systemObject.initDetails
	if not systemInitDetails._listener then
		return
	end
	
	systemObject:StopSystem()
	
	systemInitDetails._thread = task.spawn(function()
		local childScope = FusionTypes.innerScope(systemObject.systemScope)
		systemInitDetails._initScope = childScope
		
		systemInitDetails._listener(systemObject.eventGraph, childScope)
	end)
end

function registerSystemMeta.SystemInit(systemObject: SystemObject, callback: (eventGraph: EventGraph.EVENT_GRAPH, fusionScope: FusionTypes.SCOPE)->nil)
	systemObject.initDetails._listener = callback
	
	return function()
		systemObject:StartSystem()
	end
end

function registerSystemMeta.SystemResolver(
	systemObject: SystemObject,
	callback: (
		eventGraph: EventGraph.EVENT_GRAPH,
		fusionScope: FusionTypes.SCOPE
	)->nil)
	
	local resolverObject = nil
	local childScope = nil:: FusionTypes.SCOPE
	local cleanFunctionRoot = function()
		table.remove(
			systemObject.resolvers, 
			table.find(systemObject.resolvers, resolverObject)
		)
		
		if childScope then
			childScope:doCleanup()
		end
	end
	
	task.spawn(function()
		childScope = FusionTypes.innerScope(systemObject.systemScope)
		callback(systemObject.eventGraph, childScope)
	end)
	
	resolverObject = {
		Disconnect = cleanFunctionRoot,
	}
	
	table.insert(systemObject.resolvers, resolverObject) 
	return resolverObject
end

function registerSystemMeta.Destroy(systemObject: SystemObject)
	for _, resolverObject in systemObject.resolvers do
		resolverObject.Disconnect()
	end
	
	systemObject:StopSystem()
	systemObject.eventGraph:Destroy()
	systemObject.eventTransmitter:Destroy()
	
	setmetatable(systemObject, nil)
	table.clear(systemObject)
	table.freeze(systemObject)
end

return registerSystem