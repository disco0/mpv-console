local M = setmetatable({ }, {
_NAME = 'default-macros',
_DESCRIPTION = 'Default macro definition factory for console.lua'
})

M.config_file =
{
    basename = [[macros]],
    --- Config file will attempt to resolve relative to MPV_HOME (or another applicable
    --- directory checked in `mp.find_config_file`)
    mpvhome_subdir = [[script-opts/]]
}

--region builtin macros functions

--- Return table containing base set of macros
---@return macros
function M.get_default_macros()
    ---@type macros
    local macros = {}

    -- Player and Script Control Macros
    macros["font"]       = 'script-message repl-font'

    macros["size"]       = 'script-message repl-size'
    macros["con+"]      = 'script-message repl-size 45'

    macros["bbox"]       = '!repl-hide; !Blackbox;'
    macros["cbox"]       = '!repl-hide; !Colorbox;'
    macros["box"]        = '#bbox ;'

    macros["scale"]      = 'cycle-values scale ewa_lanczos lanczos bilinear'
    macros["hi"]         = 'set scale ewa_lanczos; cycle-values sharpen 1 .66 .33 0'

    macros["pitchshift"] = 'cycle audio-pitch-correction; set speed "${speed}" ;'
    macros["normalize"]  = 'cycle-values af "lavfi=[loudnorm]" "lavfi=[dynaudnorm=s=30]" ""'
    macros["an"]         = macros["normalize"]
    macros["acon5"]      = 'set af acontrast=5'
    macros["acon10"]     = 'set af acontrast=10'
    macros["acon20"]     = 'set af acontrast=20'
    macros["ac"]         = macros["acon10"]

    macros["screen"]     = 'async screenshot;'


    macros["safe"]       = 'define_section "no_accidents" "q ignore\nQ ignore\nENTER ignore\nq-q-q quit\n" "force"; enable-section "no_accidents"; print-text "Press q three times to exit as normal."'
    macros["safep"]      = '!type define_section "no_accidents" "q ignore\nQ ignore\nENTER ignore\nq-q-q quit\n" "force"; enable-section "no_accidents";  print-text "Press q three times to exit as normal."'
    macros["nosafe"]     = 'disable_section "no_accidents"; show-text "no_accidents section disabled."; print-text "no_accidents section disabled.";'

    macros["tonecmds"]   = '!type "set contrast ${contrast}; set brightness ${brightness}; set gamma ${gamma}; set saturation ${saturation};"'
    macros["toneab"]     = [[!type "define-section \"toggle_tone\" \"alt+t cycle-values contrast 0 ${contrast} ; cycle-values brightness 0 ${brightness} ; cycle-values gamma 0 ${gamma} ; cycle-values saturation 0 ${saturation} ; ]] ..
                                [[ show-text \\\"contrast:   $$$${contrast$$$}\\\\nbrightness: $$$${brightness$$$}\\\\ngamma:      $$$${gamma$$$}\\\\nsaturation: $$$${saturation$$$}\\\"; ]] ..
                                [[ print-text \\\"c/b/g/s $$$${contrast$$$}/$$$${brightness$$$}/$$$${gamma$$$}/$$$${saturation$$$}\\\"; ]] ..
                                [[ \" \"force\" ; enable_section \"toggle_tone\" ;" ]]
    macros["ab"]         = macros["toneab"]
    macros["c"]          = macros["toneab"]
    macros["tonereset"]  = [[!type "set contrast 0; set brightness 0; set gamma 0; set saturation 0;"]]
    macros["levels"]     = [[ cycle-values video-output-levels limited full; ]]
    macros["levels"]     = macros["levels"]

    macros["lsize"]      = [[!list-max ]]

    macros["curveskill"] = [[!curves_kill]]
    macros["cq"]         = [[!curves-quiet]]
    macros["ce"]         = [[!curves-quit]]
    macros["cr"]         = [[!curves-restart]]

    macros["curvesoff"]  = macros["curveskill"]
    macros["nocurve"]    = macros["curveskill"]
    macros["cup"]        = [[!tone-upper ]]

    -- Info Macros
    macros["shrpscl"]    = 'print-text "[sharp] oversample <-> linear (triangle) <-> catmull_rom <-> mitchell <-> gaussian <-> bicubic [smooth]"'
    macros["vf"]         = "print-text 'Example vf command => vf set perspective=0:0.32*H:W:0:0:H:W:.8*H';"
    macros["vfex"]       = [[ !type "vf set perspective=0:0.32*H:W:0:0:H:W:.8*H" ]]
    macros["curves"]     =
            [[ print-text "## Commands, invoked with `script-message` ##";
            print-text "curves-brighten-show => Enter|Exit brightness mode";
            print-text "curves-cooler-show   => Enter|Exit temperature mode";
            print-text "curves-brighten      => Adjust brightness of video. Param: +/-1";
            print-text "curves-brighten-tone => Change the tone base [x] Param: +/-1";
            print-text "curves-temp-cooler   => Adjust the temperature by changing";
            print-text "▏                       R,G,B curve values";
            print-text "curves-temp-tone     => Change the tone base [x]";
            print-text "## Usage ##";
            print-text "In mpv, press b|y key to start manipulating color curves";
            print-text "Use arrow keys to move the point in the curve";
            print-text "r => Reset curves state";
            print-text "d => Delete the filter";
            print-text "Press b, y keys again to exit the curve mode."
            ]]
    macros["cacheinfo"]  =
            [[ print-text "#### Properties: Cache"
            print-text "cache                   => ${=cache}";
            print-text "cache-backbuffer        => ${=cache-backbuffer}";
            print-text "cache-default           => ${=cache-default}";
            print-text "cache-file              => ${=cache-file}";
            print-text "cache-file-size         => ${=cache-file-size}";
            print-text "cache-initial           => ${=cache-initial}";
            print-text "cache-pause             => ${=cache-pause}";
            print-text "cache-pause-initial     => ${=cache-pause-initial}";
            print-text "cache-pause-wait        => ${=cache-pause-wait}";
            print-text "cache-secs              => ${=cache-secs}";
            print-text "cache-seek-min          => ${=cache-seek-min}";
            print-text "demuxer-seekable-cache  => ${=demuxer-seekable-cache}";
            ]]
    macros["videoinfo"] =
            [[ print-text "#### Properties: Video"
            print-text "no-video                           => ${=no-video}";
            print-text "video                              => ${=video}";
            print-text "video-align-x                      => ${=video-align-x}";
            print-text "video-align-y                      => ${=video-align-y}";
            print-text "video-aspect                       => ${=video-aspect}";
            print-text "video-aspect-method                => ${=video-aspect-method}";
            print-text "video-latency-hacks                => ${=video-latency-hacks}";
            print-text "video-osd                          => ${=video-osd}";
            print-text "video-output-levels                => ${=video-output-levels}";
            print-text "video-pan-x                        => ${=video-pan-x}";
            print-text "video-pan-y                        => ${=video-pan-y}";
            print-text "video-rotate                       => ${=video-rotate}";
            print-text "video-sync                         => ${=video-sync}";
            print-text "video-sync-adrop-size              => ${=video-sync-adrop-size}";
            print-text "video-sync-max-audio-change        => ${=video-sync-max-audio-change}";
            print-text "video-sync-max-video-change        => ${=video-sync-max-video-change}";
            print-text "video-timing-offset                => ${=video-timing-offset}";
            print-text "video-unscaled                     => ${=video-unscaled}";
            print-text "video-zoom                         => ${=video-zoom}";
            print-text "demuxer-mkv-probe-video-duration   => ${=demuxer-mkv-probe-video-duration}";
            print-text "demuxer-rawvideo-codec             => ${=demuxer-rawvideo-codec}";
            print-text "demuxer-rawvideo-format            => ${=demuxer-rawvideo-format}";
            print-text "demuxer-rawvideo-fps               => ${=demuxer-rawvideo-fps}";
            print-text "demuxer-rawvideo-h                 => ${=demuxer-rawvideo-h}";
            print-text "demuxer-rawvideo-mp-format         => ${=demuxer-rawvideo-mp-format}";
            print-text "demuxer-rawvideo-size              => ${=demuxer-rawvideo-size}";
            print-text "demuxer-rawvideo-w                 => ${=demuxer-rawvideo-w}";
            print-text "image-subs-video-resolution        => ${=image-subs-video-resolution}";
            ]]
    macros["windowinfo"] =
            [[ print-text "window-dragging             => ${=window-dragging}";
            print-text "window-scale                => ${=window-scale}";
            print-text "scale-window                => ${=scale-window}";
            print-text "cscale-window               => ${=cscale-window}";
            print-text "dscale-window               => ${=dscale-window}";
            print-text "tscale-window               => ${=tscale-window}";
            print-text "force-window                => ${=force-window}";
            print-text "force-window-position       => ${=force-window-position}";
            print-text "snap-window                 => ${=snap-window}";
            print-text "keepaspect-window           => ${=keepaspect-window}";
            print-text "hidpi-window-scale          => ${=hidpi-window-scale}";
            ]]
    macros['oscinfo'] =
            [[ print-text "## OSCINFO ##";
            print-text "layout             =>  ${=layout} [Def: 'bottombar']";
            print-text "▏   The layout for the OSC. Currently available are: box, slimbox,";
            print-text "▏   bottombar and topbar. Default pre-0.21.0 was 'box'.";
            print-text "seekbarstyle       =>  ${=seekbarstyle} [Def: 'bar']";
            print-text "▏   Sets seekbar style: Slider (diamond marker) [Default pre-0.21.0]";
            print-text "▏                       Knob   (circle marker with guide)";
            print-text "▏                       Bar    (fill)";
            print-text "seekbarkeyframes   =>  ${=seekbarkeyframes} [Def: 'yes']";
            print-text "▏   Controls the mode used to seek when dragging the seekbar. By default,";
            print-text "▏   keyframes are used. If set to false, exact seeking on mouse drags";
            print-text "▏   will be used instead. Keyframes are preferred, but exact seeks may be";
            print-text "▏   useful in cases where keyframes cannot be found. Note that using exact";
            print-text "▏   seeks can potentially make mouse dragging much slower.";
            print-text "deadzonesize       =>  ${=deadzonesize} [Def: '0.5']";
            print-text "▏   Size of the deadzone. The deadzone is an area that makes the mouse act";
            print-text "▏   like leaving the window. Movement there won't make the OSC show up and";
            print-text "▏   it will hide immediately if the mouse enters it. The deadzone starts";
            print-text "▏   at the window border opposite to the OSC and the size controls how much";
            print-text "▏   of the window it will span. Values between 0.0 and 1.0, where 0 means the";
            print-text "▏   OSC will always popup with mouse movement in the window, and 1 means the";
            print-text "▏   OSC will only show up when the mouse hovers it. Default pre-0.21.0 was 0.";
            print-text "minmousemove       =>  ${=minmousemove} [Def: '0']";
            print-text "▏   Minimum amount of pixels the mouse has to move between ticks to make";
            print-text "▏   the OSC show up. Default pre-0.21.0 was 3.";
            print-text "showwindowed       =>  ${=showwindowed} [Def: 'yes']";
            print-text "▏   Enable the OSC when windowed";
            print-text "showfullscreen     =>  ${=showfullscreen} [Def: 'yes']";
            print-text "▏   Enable the OSC when fullscreen";
            print-text "scalewindowed      =>  ${=scalewindowed} [Def: '1.0']";
            print-text "▏   Scale factor of the OSC when windowed.";
            print-text "scalefullscreen    =>  ${=scalefullscreen} [Def: '1.0']";
            print-text "▏   Scale factor of the OSC when fullscreen";
            print-text "scaleforcedwindow  =>  ${=scaleforcedwindow} [Def: '2.0']";
            print-text "▏   Scale factor of the OSC when rendered on a forced (dummy) window";
            print-text "vidscale           =>  ${=vidscale} [Def: 'yes']";
            print-text "▏   Scale the OSC with the video";
            print-text "▏   `no` tries to keep the OSC size constant as much as the window size allows";
            print-text "valign             =>  ${=valign} [Def: '0.8']";
            print-text "▏   Vertical alignment, -1 (top) to 1 (bottom)";
            print-text "halign             =>  ${=halign} [Def: '0.0']";
            print-text "▏   Horizontal alignment, -1 (left) to 1 (right)";
            print-text "barmargin          =>  ${=barmargin} [Def: '0']";
            print-text "▏   Margin from bottom (bottombar) or top (topbar), in pixels";
            print-text "boxalpha           =>  ${=boxalpha} [Def: '80']";
            print-text "▏   Alpha of the background box, 0 (opaque) to 255 (fully transparent)";
            print-text "hidetimeout        =>  ${=hidetimeout} [Def: '500']";
            print-text "▏   Duration in ms until the OSC hides if no mouse movement, must not be";
            print-text "▏   negative";
            print-text "fadeduration       =>  ${=fadeduration} [Def: '200']";
            print-text "▏   Duration of fade out in ms, 0 = no fade";
            print-text "title              =>  ${=title} [Def: '${media-title}']";
            print-text "▏   String that supports property expansion that will be displayed as";
            print-text "▏   OSC title.";
            print-text "▏   ASS tags are escaped, and newlines and trailing slashes are stripped.";
            print-text "tooltipborder      =>  ${=tooltipborder} [Def: '1']";
            print-text "▏   Size of the tooltip outline when using bottombar or topbar layouts";
            print-text "timetotal          =>  ${=timetotal} [Def: 'no']";
            print-text "▏   Show total time instead of time remaining";
            print-text "timems             =>  ${=timems} [Def: 'no']";
            print-text "▏   Display timecodes with milliseconds";
            print-text "seekranges         =>  ${=seekranges} [Def: 'yes']";
            print-text "▏   Display seekable ranges on the seekbar";
            print-text "visibility         =>  ${=visibility} [Def: 'auto']";
            print-text "▏   Also supports `never` and `always`";
            print-text "boxmaxchars        =>  ${=boxmaxchars} [Def: '80']";
            print-text "▏   Max chars for the osc title at the box layout. mpv does not measure the";
            print-text "▏   text width on screen and so it needs to limit it by number of chars. The";
            print-text "▏   default is conservative to allow wide fonts to be used without overflow.";
            print-text "▏   However, with many common fonts a bigger number can be used. YMMV.";
            ]]
    macros['excerpt'] =
        [[ print-text "#### excerpt.lua"
        print-text "## Basics"
        print-text "▏This script allows to create excerpts of videos in mpv."
        print-text "▏ Press `i` to mark `begin`[ing] time value for excerpt output."
        print-text "▏ Press `o` to mark `end` time value for excerpt output."
        print-text "▏ Press `I` to jump to `begin` location, and initalize playback."
        print-text "▏ Press `O` to jump to `end` location, and pause."
        print-text "▏ Press `x` to start excerpt generation using an ffmpeg command"
        print-text "▏   using os.execute(), passing the following parameters: "
        print-text "▏   $1 => begin"
        print-text "▏   $2 => duration "
        print-text "▏   $3 => source filename"
        print-text "## Keybindings"
        print-text "▏   i            excerpt_mark_begin       [Forced]"
        print-text "▏   Shift+i (I)  excerpt_seek_begin       [Forced]"
        print-text "▏   o            excerpt_mark_end         [Forced]"
        print-text "▏   Shift+o (O)  excerpt_seek_end         [Forced]"
        print-text "▏   x            excerpt_write            [Forced]"
        print-text "▏   Shift+Right  excerpt_keyframe_forward (Repeatable, Complex)"
        print-text "▏   Shift+Left   excerpt_keyframe_back    (Repeatable, Complex)"
        print-text "▏   Right        excerpt_frame_forward    (Repeatable, Complex)"
        print-text "▏   Left         excerpt_frame_back       (Repeatable, Complex)"
        print-text "▏   e            excerpt_zoom_in          (Repeatable)"
        print-text "▏   w            excerpt_zoom_out         (Repeatable)"
        print-text "▏   Ctrl+Right   excerpt_pan_Right        (Repeatable)"
        print-text "▏   Ctrl+Left    excerpt_pan_left         (Repeatable)"
        print-text "▏   Ctrl+Up      excerpt_pan_up           (Repeatable)"
        print-text "▏   Ctrl+Down    excerpt_pan_down         (Repeatable)"
        print-text "## Script Messages ( invoked with `script-message`, or `!` prefix )"
        print-text "▏   `script-message in`,           `!in`           excerpt_mark_begin"
        print-text "▏   `script-message out`,          `!out`          excerpt_mark_end"
        print-text "▏   `script-message excerpt`,      `!excerpt`      excerpt_write"
        print-text "▏   `script-message excerpt-test`, `!excerpt-test` excerpt_test"
        ]]
    return macros
end

return M
