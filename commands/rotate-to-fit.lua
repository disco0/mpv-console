local _local_1_ = require("commands.utils")
local mp = _local_1_["mp"]
local utils = _local_1_["utils"]
local logging = _local_1_["logging"]
local msg = _local_1_["msg"]
local constants = _local_1_["constants"]
local initialize_command = _local_1_["initialize-command"]
local states = {reset = {["video-rotation"] = 0}, portrait = {["video-rotation"] = 270}, landscape = {["video-rotation"] = 270}}
local state_transforms
do
  local tbl_11_auto = {}
  for orientation, key_value_table in pairs(states) do
    local _2_, _3_ = nil, nil
    local function _4_()
      for key, value in pairs(key_value_table) do
        mp.set_property_native(key, value)
      end
      return nil
    end
    _2_, _3_ = orientation, _4_
    if ((nil ~= _2_) and (nil ~= _3_)) then
      local k_12_auto = _2_
      local v_13_auto = _3_
      tbl_11_auto[k_12_auto] = v_13_auto
    else
    end
  end
  state_transforms = tbl_11_auto
end
local command_name = "rotate-to-fit"
local active_hook = false
local log_base = msg.extend("rotate-to-fit")
local function get_active_media_size()
  local dwidth = mp.get_property_native("dwidth", -1)
  local dheight = mp.get_property_native("dheight", -1)
  return {dwidth, dheight}
end
local function get_active_media_size_safe()
  local _let_6_ = get_active_media_size()
  local dwidth = _let_6_[1]
  local dheight = _let_6_[2]
  if ((dheight == -1) or (dwidth == -1)) then
    error(string.format("Failed to get dwidth and dheight safely in get-active-media-size-safe (dwidth: %s, dheight: %s)", tostring((dwidth or "[undefined]")), tostring((dheight or "[undefined]"))))
  else
  end
  return {dwidth, dheight}
end
local function is_valid_res_size_3f(_3fres)
  if not (type((_3fres or nil)) == "number") then
    return false
  else
    return (_3fres <= 0)
  end
end
local function valid_video_dimensions_3f(_9_)
  local _arg_10_ = _9_
  local _3fwidth = _arg_10_[1]
  local _3fheight = _arg_10_[2]
  return (is_valid_res_size_3f(_3fwidth) and is_valid_res_size_3f(_3fheight))
end
local function portrait_dimensions_3f(_11_)
  local _arg_12_ = _11_
  local dwidth = _arg_12_[1]
  local dheight = _arg_12_[2]
  _G.assert((nil ~= dheight), "Missing argument dheight on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/rotate-to-fit.fnl:90")
  _G.assert((nil ~= dwidth), "Missing argument dwidth on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/rotate-to-fit.fnl:90")
  return ((dheight / dwidth) > 1.4)
end
local apply_orientation_config
do
  local log = msg.extend("apply")
  local function _13_(orientation)
    _G.assert((nil ~= orientation), "Missing argument orientation on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/rotate-to-fit.fnl:95")
    assert(("table" == type(states[orientation])), "parameter not found in states table.")
    for prop, value in pairs(states[orientation]) do
      mp.set_property_native(prop, value)
    end
    return nil
  end
  apply_orientation_config = _13_
end
local function orientation_type(dimensions)
  _G.assert((nil ~= dimensions), "Missing argument dimensions on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/rotate-to-fit.fnl:106")
  if portrait_dimensions_3f(dimensions) then
    return "portrait"
  else
    return "landscape"
  end
end
return orientation_type
