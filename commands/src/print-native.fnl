;; print-native:
;;   Outputs native value of given property `property` to console
;;   for inspection.

(local {
  : mp
  : utils
  : logging
  : msg
  : constants
  : initialize-command
} (require :commands.utils))

(let [ command-name :print-native
       cmd-msg      (msg.extend command-name) ]

    (λ command [ property ]
      (when (and (= (type   property) :string)
                 (> (length property) 1))
        ; Use lua's table strict table equality to test if we really got something
        (let [ failure { }
               value   (mp.get_property_native property failure) ]
          (if (= value failure)
              (cmd-msg.warn "Failed to get native value for property %q." property)
              ; else
              (let [ out (string.format "%s:\n%s" property (utils.to_string value)) ]
                (msg.info out)
                (mp.commandv :print-text out)
                (mp.commandv :show-text  out))))))

    (initialize-command command-name command))
