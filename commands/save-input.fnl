;; save-input (working name):
;;   Log console repl content to file (when enabled)

(local mp        (require :mp))
(local utils     (require :mp.utils))
(local logging   (require :logging))
(local msg       logging.msg)
(local constants (require :constants))
(local platform  (. constants :platform))
(local script-message (require :script-message-tracker))
