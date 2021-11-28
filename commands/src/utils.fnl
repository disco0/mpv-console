;; - utils.fnl
;; Utility functions and collection common requires for (fennel based) commands.

(local M { })

;;#region Common Requires

(each [ key value (pairs { :mp             (require :mp)
                           :utils          (require :mp.utils)
                           :logging        (require :log-ext)
                           :msg            (. (require :log-ext) :msg)
                           :constants      (require :constants)
                           :platform       (. (require :constants) :platform)
                           :script-message (require :script-message-tracker) } ) ]
  (tset M key value))

;;#endregion Common Requires

;;#region Utils

;; Will add script-message if command's name, not already registered, and then unconditionally
;; return the module table at the end of each command script.
(λ M.initialize-command [name command]

  (when (not (M.script-message.registered name))
    (M.script-message.register name command))

  { : command : name } )

;; Allows for registering multiple commands at the same time, returning each passed command
;; defined as an additional return value at the end of each script
(λ M.initialize-commands [ ... ]
  (let [ command-tables [ ] ]

    ;; Return all
    (values (table.unpack command-tables))))

;;#endregion Utils

M
