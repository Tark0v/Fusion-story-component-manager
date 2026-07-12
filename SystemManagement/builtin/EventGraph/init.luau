local systemManagement = script.Parent

local Signal = require(script.Signal)

local eventGraph = {}
local eventGraphMeta = {}

function eventGraph.new()
	return setmetatable({
		cachedEvents = {}:: {[string]: Signal.Signal<any>}	
	}, eventGraphMeta) 
end

export type EVENT_GRAPH = typeof(eventGraph.new())

eventGraphMeta.__index = eventGraphMeta

function eventGraphMeta.GetEvent(eventGraphObject: EVENT_GRAPH, eventID: string)
	return eventGraphObject.cachedEvents[eventID]	
end

function eventGraphMeta.CreateEvent(eventGraphObject: EVENT_GRAPH, eventID: string): Signal.Signal<any>
	if eventGraphObject.cachedEvents[eventID] then
		warn(`EventGraph: Event Already Registered {eventID}`)
		return 
	end
	
	local eventSignal = Signal.new()
	eventGraphObject.cachedEvents[eventID] = eventSignal
	
	eventSignal:OnDestroy(function()
		if eventGraphObject.cachedEvents then
			eventGraphObject.cachedEvents[eventID] = nil
		end
	end)
	
	return eventSignal
end

function eventGraphMeta.CreateEventsFromList(eventGraphObject: EVENT_GRAPH, eventDictionary: {[string]: (...any)->any?} | any)
	local generatedEventList = {}
	
	for eventID, eventFunction in eventDictionary do
		local newEvent = eventGraphObject:CreateEvent(eventID)
		if newEvent then
			generatedEventList[eventID] = newEvent
			
			if eventFunction then
				newEvent:Connect(eventFunction)
			end
		end
	end	
	
	return generatedEventList
end

function eventGraphMeta.Clear(eventGraphObject: EVENT_GRAPH)
	for eventID, event in eventGraphObject.cachedEvents do
		event:Destroy()
	end
	
	eventGraphObject.cachedEvents = {}
end

function eventGraphMeta.Destroy(eventGraphObject: EVENT_GRAPH)
	for eventID, event in eventGraphObject.cachedEvents do
		event:Destroy()
	end
	
	setmetatable(eventGraphObject, nil)
	table.clear(eventGraphObject)
	table.freeze(eventGraphObject)
end

return eventGraph
