local class = require("./class")
local table = require("./table")
local types = require("../types")

type EventEmitter = types.EventEmitter
local EventEmitter = {
  defaultMaxListeners = 10,
}

EventEmitter.prototype = {}
EventEmitter.interface = {}

EventEmitter.prototype.__type = "EventEmitter"

function EventEmitter.prototype._ev(self: EventEmitter, type: string)
  if not self.connections[type] then
    self.connections[type] = {}
  end

  return self.connections[type]
end

function EventEmitter.prototype._getEv(self: EventEmitter, type: string)
  return self.connections[type]
end

function EventEmitter.prototype.addListener<T...>(self: EventEmitter, type: string, listener: (T...) -> ())
  local events
  local existing

  events = self.connections
  if events then
    existing = events[type]
  end

  if not existing then
    events[type] = { listener }
  else
    table.push(existing, listener)
  end

  return self
end

EventEmitter.prototype.on = EventEmitter.prototype.addListener

function EventEmitter.prototype.once<T...>(self: EventEmitter, type: string, listener: (T...) -> ())
  local done = false
  type = type .. ":once"
  local listenerOnce: (...any) -> ()
  listenerOnce = function(...)
    if done then
      return
    end
    done = true
    self:removeListener(type, listenerOnce)
    listener(...)
  end
  self:on(type, listenerOnce)
end

function EventEmitter.prototype.emit<T...>(self: EventEmitter, type: string, ...: T...)
  local evTbl = self:_getEv(type)
  if evTbl ~= nil then
    if next(evTbl) then
      for _, lsn in evTbl do
        local status = pcall(lsn, ...)
        if not status then
          print("emit error: ", type)
        end
      end
    end
  end

  type = type .. ":once"
  evTbl = self:_getEv(type)

  if evTbl ~= nil then
    if next(evTbl) then
      for _, lsn in evTbl do
        local status = pcall(lsn, ...)
        if not status then
          print("emit error: ", type)
        end
      end
    end
  end

  return self
end

function EventEmitter.prototype.removeListener<T...>(self: EventEmitter, type: string, listener: (T...) -> ()?)
  local events = self.connections
  local list = events[type]

  local position = 0
  for i = #list, 1, -1 do
    if list[i] == listener then
      position = i
      break
    end
  end

  if position < 1 then
    return self
  end

  if position == 1 then
    table.shift(list)
  else
    print()
  end

  if #list == 1 then
    events[type] = { list[1] }
  end

  if #list == 0 then
    events[type] = nil
  end

  return self
end

function EventEmitter.prototype.listenerCount(self: EventEmitter, type: string)
  local totalCount = 0
  local evTbl = self:_getEv(type)

  if evTbl ~= nil then
    totalCount += #evTbl
  end

  evTbl = self:_getEv(type .. ":once")
  if evTbl ~= nil then
    totalCount += #evTbl
  end

  return totalCount
end

function EventEmitter.interface.new(): EventEmitter
  local event = {
    connections = {},
  }

  return class(event, EventEmitter.prototype) :: EventEmitter
end

return EventEmitter.interface
