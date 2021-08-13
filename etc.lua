--region Unused

-- quick test
-- local af = {
--     info = mp.get_property_native('option-info/af', false)
-- }
-- if af.info then
--     msg.info('af (Audio Filter) object info:\n'
--                 .. utils.format_json(af.info)
--                 .. '\n' .. utils.format_json(af.info.choices) )
-- end

--region build_completers - Unused Partial Implementations

-- (Unused atm)
-- @ param  content string
-- @ return         string
--- function bracketed(content)
---    if type(content) == "string" then
---        return
---    else
---        return
---    end
--- end

---
--- Build a token pattern with additional character classes. Use of `]` and
--- `^` should be escaped (`%]`)
---
-- @ param  chars string
-- @ return       string
--- -- local function token_with(chars)
--- --     if type(chars) ~= "string" then
--- --         return token
--- --     else
--- --         return '[' .. token_char_base .. chars .. ']*'
--- --     end
--- -- end
---
--- ---
--- --- Build a completion description table, and optionally immediately append
--- --- to the result table instead of returning if `target` table passed.
--- ---
--- -- @ overload fun(pattern: string, list: CompletionList, append: string, target: CompletionList)
--- -- @ overload fun(pattern: CompletionCompArgTable): CompletionSet
--- -- @ overload fun(pattern: CompletionCompArgTableTargeted)
--- -- @ param  pattern string
--- -- @ param  list    CompletionList
--- -- @ param  append  string | nil
--- -- @ return         CompletionSet
--- local function prop_comp(pattern, list, append)
---     -- Handle alternate syntax (prop_comp{pattern = ...})
---     if type(pattern) == "table"
---         and pattern.list
---         and pattern.append
---         and pattern.pattern
---     then
---         -- [typesystem incantations]
---         -- @ type CompletionCompArgTable | CompletionCompArgTableTargeted
---         local pattern = pattern
---
---         list   = pattern.list
---         append = pattern.append
---         target = type(pattern.target) and pattern.target or nil
---         -- Have to do this last to avoid wiping other values
---         pattern = pattern.pattern
---     end
---
---     -- @ type CompletionSet
---     local comp =
---     {
---         pattern = pattern,
---         list    = list,
---         append  = append
---     }
---
---     if type(target) == "table" then
---         target[#target + 1] = comp
---         return
---     else
---         return comp
---     end
--- end

--endregion build_completers - Unused Partial Implementations

-- set_osd_ass test
-- test_repl_active   = false
-- ass_test_text_def  = [[{\\rDefault\\blur0\\bord1\\1c&H000000\\3c&HFFFFFF}]]
-- ass_test_text      = ass_test_text_def
-- do_begin_draw_msg  = true

-- local function ass_def_style(x_max, y_max)
--     local template = "{\\1c&H%s&}{\\1a&H%s}{\\bord%s}{\\3c&H%s&}{\\3a&H%s&}{\\p1}m 0 %f l %f %f %f 0 0 0{\\p0}"
--     local border = { color = '000000', alpha = 'FF', width = '0' }
--     local bg     = { color = '000000', alpha = '00' }
--     local bg_box = string.format(
--         template,
--         bg.color, bg.alpha,
--         border.width, border.color, border.alpha,
--         y_max, x_max, -- ???
--         y_max, x_max
--     )
--     msg.info(bg_box)
--     return bg_box
-- end


-- -- Plot the color curves on mpv OSD
-- function draw_curves(points_m, points_r, points_g, points_b)
--     -- (0, 0) at top-left corner
--     local assdraw = require 'mp.assdraw'

--     local canvas_w = 1280
--     local canvas_h = 720
--     local dw, dh, da = mp.get_osd_size()
--     if dw ~= nil and dw > 0 and dh > 0 then
--         canvas_w = dw / dh * canvas_h  -- Fix aspect?
--     end

--     local margin = 6
--     local size_ratio = 1 / 3
--     local dim = canvas_h * size_ratio
--     local o_x = canvas_w - dim - margin
--     local o_y = margin
--     local ass = assdraw.ass_new()
--     ass.scale = 1

--     -- border color: in BGR order <BBGGRR>. alpha: 00 - FF
--     function set_style(color, alpha, border)
--         local style = ""
--         if color ~= nil then
--             style = string.format("%s\\3c&H%s&", style, color)
--         end
--         if alpha ~= nil then
--             style = string.format("%s\\alpha&H%s&", style, alpha)
--         end
--         if border ~= nil then
--             style = string.format("%s\\bord%.3f", style, border)
--         end
--         ass:append(string.format("{%s}", style))
--     end

--     smooth = 0.2
--     -- convert curve point to ass point in dim
--     function fix_cpoint(p)
--         local px = math.floor(p[1] * dim + 0.5)
--         local py = math.floor((1 - p[2]) * dim + 0.5)
--         return {px, py}
--     end

--     function draw_bezier(x0, y0, points, color)
--         local p0, p1, p2, p3
--         ass:new_event()
--         p0 = fix_cpoint(points[1])
--         ass:pos(x0, y0)
--         set_style(color, "00", 0.5)
--         ass:draw_start()

--         ass:move_to(p0[1], p0[2])
--         local rpoints = {}
--         for i = 2, #points do
--             bzs = bezier_points(points, i, smooth)
--             p0 = fix_cpoint(points[i-1])
--             p1 = fix_cpoint(bzs[1])
--             p2 = fix_cpoint(bzs[2])
--             p3 = fix_cpoint(bzs[3])
--             ass:bezier_curve(p1[1], p1[2], p2[1], p2[2], p3[1], p3[2])
--             table.insert(rpoints, {p2, p1, p0})
--         end
--         -- reverse draw, close the drawing
--         for i = #rpoints, 1, -1 do
--             p1 = rpoints[i][1]
--             p2 = rpoints[i][2]
--             p3 = rpoints[i][3]
--             ass:bezier_curve(p1[1], p1[2], p2[1], p2[2], p3[1], p3[2])
--         end

--         -- draw points on curves
--         local psize = 2
--         for i = 2, #points - 1 do
--             p0 = fix_cpoint(points[i])
--             ass:rect_cw(p0[1]-psize/2, p0[2]-psize/2, p0[1]+psize, p0[2]+psize)
--         end
--         ass:draw_stop()
--     end

--     ass:new_event()
--     set_style(nil, "C0", 0)
--     ass:pos(o_x, o_y)
--     ass:draw_start()
--     ass:rect_cw(0, 0, dim, dim)
--     ass:draw_stop()

--     -- points_m = {{0, 0}, {0.33, 0.22}, {0.5, 0.7}, {1, 1}}
--     if points_m ~= nil then
--         draw_bezier(o_x, o_y, points_m, "666666")
--     end
--     if points_r ~= nil then
--         draw_bezier(o_x, o_y, points_r, "0000ff")
--     end
--     if points_g ~= nil then
--         draw_bezier(o_x, o_y, points_g, "00ff00")
--     end
--     if points_b ~= nil then
--         draw_bezier(o_x, o_y, points_b, "ff0000")
--     end
--     -- msg.info(ass.text)
--     mp.set_osd_ass(canvas_w, canvas_h, ass.text)
-- end


-- local function ass_test_dbg_screenxy()
--     local screenx, screeny, aspect = mp.get_osd_size()
--     msg.info("[screenx, screeny]: " .. screenx .. ', ' .. screeny)
-- end

-- local function toggle_test_flag(val)
--     local force = val or nil
--     if type(force) == 'boolean' then
--         test_repl_active = val
--     else
--         test_repl_active = not test_repl_active
--     end
--     msg.info([[Active: ]]..tostring(test_repl_active))
-- end

-- local function ass_test_handle()
--     -- Begin draw
--     if test_repl_active == false then
--         toggle_test_flag()
--         msg.info([[ASS Test: Enabled]])
--         ass_test_dbg_screenxy()
--         mp.register_event("tick", ass_test_draw)
--     else
--     -- End draw
--         toggle_test_flag()
--         msg.info([[ASS Test: Disabled]])
--         ass_test_dbg_screenxy()
--         do_begin_draw_msg = false
--         mp.unregister_event(ass_test_draw)
--     end

-- end

-- local function ass_test_draw(text)
--     -- (0, 0) at top-left corner
--     local assdraw = require 'mp.assdraw'

--     local canvas_w = 1280
--     local canvas_h = 720
--     local dw, dh, da = mp.get_osd_size()
--     if dw ~= nil and dw > 0 and dh > 0 then
--         canvas_w = dw / dh * canvas_h  -- Fix aspect?
--     end

--     local margin = 6
--     local size_ratio = 1 / 3
--     local dim = canvas_h * size_ratio
--     local o_x = canvas_w - dim - margin
--     local o_y = margin
--     local ass = assdraw.ass_new()
--     ass.scale = 1

--     -- border color: in BGR order <BBGGRR>. alpha: 00 - FF
--     function set_style(color, alpha, border)
--         local style = ""
--         if color ~= nil then
--             style = string.format("%s\\3c&H%s&", style, color)
--         end
--         if alpha ~= nil then
--             style = string.format("%s\\alpha&H%s&", style, alpha)
--         end
--         if border ~= nil then
--             style = string.format("%s\\bord%.3f", style, border)
--         end
--         ass:append(string.format("{%s}", style))
--     end
--     -- local screenx, screeny, aspect = mp.get_osd_size()
--     -- local canvas_w = screenx
--     -- local canvas_h = screeny
--     -- local margin = 6
--     -- local size_ratio = 1 / 3
--     -- local dim = canvas_h * size_ratio
--     -- local o_x = canvas_w - dim - margin
--     -- local o_y = margin
--     -- local ass = assdraw.ass_new()

--     -- border color: in BGR order <BBGGRR>. alpha: 00 - FF
--     local function set_style(color, alpha, border)
--         local style = ""
--         if color ~= nil then
--             style = string.format("%s\\3c&H%s&", style, color)
--         end
--         if alpha ~= nil then
--             style = string.format("%s\\alpha&H%s&", style, alpha)
--         end
--         if border ~= nil then
--             style = string.format("%s\\bord%.3f", style, border)
--         end
--         ass:append(string.format("{%s}", style))
--     end

--     -- -- Clear the OSD if the console is not active
--     -- if not test_repl_active then
--     --     mp.set_osd_ass(screenx, screeny, '')
--     --     return
--     -- end

--     if do_begin_draw_msg then
--         msg.info([[~~~~~ Begin Draw ~~~~~~]])
--         do_begin_draw_msg = false
--     end

--     ass:new_event()
--     set_style("000000", "80", 1)
--     ass:pos(o_x, o_y)
--     ass:draw_start()
--     ass:rect_cw(0, 0, dim, dim)
--     ass:draw_stop()

--     msg.info(ass.text)
--     mp.set_osd_ass(canvas_w, canvas_h, ass.text)
-- end

-- local function ass_test_set(text)
--     local text    = text or ass_test_text_def
--     ass_test_text = text
--     msg.info([[Updated ASS test text src: ]] .. ass_test_text)
-- end

-- local function ass_test_set_fill()
--     mp.command( 'script-message type "script-message test_set \\"'
--                 .. ass_test_text_def:gsub([[\]], '\\\\') .. '\\""')
-- end

-- msg.info([[Drawing with set_osd_ass...]])
-- mp.register_script_message('test',     ass_test_handle)
-- mp.register_script_message('test_set', function(...) ass_test_set(...) end)
-- mp.register_script_message('test_fill', ass_test_set_fill)

-- -- Redraw the console when the OSD size changes. This is needed because the
-- -- PlayRes of the OSD will need to be adjusted.
-- mp.observe_property('osd-width',  'native', ass_test_draw)
-- mp.observe_property('osd-height', 'native', ass_test_draw)

--endregion Unused
