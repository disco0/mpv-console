-- Lua Library inline imports
function __TS__Class(self)
    local c = {prototype = {}}
    c.prototype.__index = c.prototype
    c.prototype.constructor = c
    return c
end

function __TS__StringAccess(self, index)
    if (index >= 0) and (index < #self) then
        return string.sub(self, index + 1, index + 1)
    end
end

function __TS__New(target, ...)
    local instance = setmetatable({}, target.prototype)
    instance:____constructor(...)
    return instance
end

function isValidRGBHexComponent(self, value)
    return (((type(value) == "string") and (#value == 2)) and isHexDigit(
        _G,
        __TS__StringAccess(value, 0)
    )) and isHexDigit(
        _G,
        __TS__StringAccess(value, 1)
    )
end
function isHexDigit(self, char)
    return ((type(char) == "string") and (#char == 1)) and (function(____, charCode) return (((charCode >= 48) and (charCode <= 57)) or ((charCode >= 65) and (charCode <= 70))) or ((charCode >= 97) and (charCode <= 102)) end)(
        _G,
        string.byte(char, 1) or (0 / 0)
    )
end
ASSColorData = __TS__Class()
ASSColorData.name = "ASSColorData"
function ASSColorData.prototype.____constructor(self, ...)
    local values = {...}
    local arg_count = #values
    if arg_count == 1 then
        local rgbRaw = values[1]
        if #rgbRaw == 3 then
            local b = tostring(
                __TS__StringAccess(rgbRaw, 0)
            ) .. tostring(
                __TS__StringAccess(rgbRaw, 0)
            )
            local g = tostring(
                __TS__StringAccess(rgbRaw, 1)
            ) .. tostring(
                __TS__StringAccess(rgbRaw, 1)
            )
            local r = tostring(
                __TS__StringAccess(rgbRaw, 2)
            ) .. tostring(
                __TS__StringAccess(rgbRaw, 2)
            )
            for ____, value in ipairs({r, g, b}) do
                if not isValidRGBHexComponent(_G, value) then
                    error(
                        _G,
                        "Invalid BGR component: " .. tostring(value)
                    )
                end
            end
            self.r = r
            self.g = g
            self.b = b
            return
        elseif #rgbRaw == 6 then
            local b = string.sub(rgbRaw, 1, 1)
            local g = string.sub(rgbRaw, 3, 3)
            local r = string.sub(rgbRaw, 5, 5)
            for ____, value in ipairs({r, g, b}) do
                if not isValidRGBHexComponent(_G, value) then
                    error(
                        _G,
                        "Invalid BGR component: " .. tostring(value)
                    )
                end
            end
            self.r = r
            self.g = g
            self.b = b
        else
            error("", 0)
            return nil
        end
        error("", 0)
        return
    elseif arg_count == 3 then
        local r, g, b = unpack(values)
        for ____, value in ipairs({r, g, b}) do
            if not isValidRGBHexComponent(_G, value) then
                error(
                    _G,
                    "Invalid BGR component: " .. tostring(value)
                )
            end
        end
        self.r = r
        self.g = g
        self.b = b
        return
    else
        error("", 0)
        return nil
    end
end
function ASSColorData.prototype.__tostring(self)
    return tostring(self)
end
function ASSColorData.prototype.toEsc(self)
    return (function(____, ____bindingPattern0)
        local r
        r = ____bindingPattern0.r
        local g
        g = ____bindingPattern0.g
        local b
        b = ____bindingPattern0.b
        return (b .. g) .. r
    end)(_G, self)
end
color = __TS__New(ASSColorData, "FF", "FF", "00")
