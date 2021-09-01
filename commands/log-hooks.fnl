;; - log-hooks.fnl
;; Defines demo command for scripting hooks—when command called, a logging function will be
;; registered for each hook type.

(local mp        (require :mp))
(local utils     (require :mp.utils))
(local logging   (require :logging))
(local msg       logging.msg)
(local constants (require :constants))
(local platform  (. constants :platform))
(local script-message (require :script-message-tracker))

(local hook-types [
  :on_load
  :on_load_fail
  :on_preloaded
  :on_unload
  :on_before_start_file
  :on_after_end_file
])

(local cmd-log  (msg.extend :hook-demo-init))
(local hook-log (msg.extend :hook-demo))

(local command-name "show-hooks")
(λ command []
  (each [_ hook-type (ipairs hook-types)]
    (cmd-log.debug "Registering hook: %s" hook-type)
    (mp.add_hook hook-type 0
      #(hook-log.info "Hook called: %s" hook-type))))

; Register on require if not yet defined (for now)
(when (not (script-message.registered command-name))
  (script-message.register command-name command))

{ : command  }
