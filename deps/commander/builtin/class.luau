--!nocheck
--[[
	Construct utility method for centralising all hacky metatable stuff.

	Every 'Class' discord-luau uses should rely on this function to generate/instantiate that class object.
]]

local function failCall(self: any, callType: string)
  error(`Invoked unsupported metamethod '{callType}' on object '{tostring(self)}'`, 3)
end

local function size<T>(t: T)
  local count = 0
  for _ in t do
    count += 1
  end

  return count
end

local Class = {}

function Class.construct<S, P>(
  source: S,
  prototype: P
): S & P & {
  extend: <E>(self: S & P, other: E) -> S & P & E & { super: E },
}
  local object

  object = setmetatable({}, {
    __index = function(_, key)
      if key ~= "extend" then
        return prototype[key]
      end
    end,

    __call = function(self)
      return failCall(self, "Call")
    end,

    __concat = function(self)
      return failCall(self, "Concat")
    end,
    __iter = function(self)
      local keys = {}
      for key, _ in pairs(self) do
        if not (key:sub(1, 2) == "__" or key == "extend" or key == "super") then
          table.insert(keys, key)
        end
      end
      local i = 0
      return function()
        i = i + 1
        local key = keys[i]
        if key ~= nil then
          return key, self[key]
        end
      end
    end,

    __unm = function(self)
      return failCall(self, "-.")
    end,
    __add = function(self)
      return failCall(self, "+")
    end,
    __sub = function(self)
      return failCall(self, "-")
    end,
    __mul = function(self)
      return failCall(self, "*")
    end,
    __div = function(self)
      return failCall(self, "/")
    end,
    __idiv = function(self)
      return failCall(self, "//")
    end,
    __mod = function(self)
      return failCall(self, "%")
    end,
    __pow = function(self)
      return failCall(self, "^")
    end,
    __lt = function(self)
      return failCall(self, "<")
    end,
    __le = function(self)
      return failCall(self, "<=")
    end,
    __len = function(self)
      return failCall(self, "#")
    end,

    __mode = "",
    __type = prototype.__type or "GenericClass",

    -- __eq = ...
    -- __gc = ...

    __tostring = function()
      return `DiscordLuau<'{prototype.__type or "GenericClass"}'>`
    end,
  })

  object.extend = function<E>(self, otherPrototype: E): P & E & { super: E }
    self.super = otherPrototype
    return setmetatable({}, {
      __index = function(_, index)
        return self[index] or self.super[index]
      end,

      __newindex = function(t, index, value)
        if self.super[index] then
          self.super[index] = value
        else
          rawset(t, index, value)
        end
      end,

      __call = function(self)
        return failCall(self, "Call")
      end,
      __concat = function(self)
        return failCall(self, "Concat")
      end,
      __iter = function(self)
        local keys = {}
        for key, _ in pairs(self) do
          if not (key:sub(1, 2) == "__" or key == "extend" or key == "super") then
            table.insert(keys, key)
          end
        end
        local i = 0
        return function()
          i = i + 1
          local key = keys[i]
          if key ~= nil then
            return key, self[key]
          end
        end
      end,

      __unm = function(self)
        return failCall(self, "-.")
      end,
      __add = function(self)
        return failCall(self, "+")
      end,
      __sub = function(self)
        return failCall(self, "-")
      end,
      __mul = function(self)
        return failCall(self, "*")
      end,
      __div = function(self)
        return failCall(self, "/")
      end,
      __idiv = function(self)
        return failCall(self, "//")
      end,
      __mod = function(self)
        return failCall(self, "%")
      end,
      __pow = function(self)
        return failCall(self, "^")
      end,
      __lt = function(self)
        return failCall(self, "<")
      end,
      __le = function(self)
        return failCall(self, "<=")
      end,
      __len = function(self)
        return failCall(self, "#")
      end,

      __mode = "",
      __type = self.__type or "GenericClass",

      __tostring = function()
        local name = self["_name"] or self["name"] or self.__type
        return `Commander<'{name or "GenericClass"}'>`
      end,
    })
  end

  if size(source) > 0 then
    for key, value in source do
      object[key] = value
    end
  end

  return object
end

setmetatable(Class, {
  __call = function<P>(
    _,
    source: S,
    prototype: P
  ): S & P & {
    extend: <E>(self: S & P, other: E) -> S & P & E & { super: E },
  }
    return Class.construct(source, prototype)
  end,
})

return Class
