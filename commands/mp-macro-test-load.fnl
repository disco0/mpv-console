(tset (require :fennel) :macro-path "./?.fnl;./?-macros.fnl;./?/init-macros.fnl;./?/init.fnl")

;;#region Utils

(fn fprint [body ...]
   (print (string.format body ...)))

;;#endregion Utils

;;#region Mock mp table for testing

(let [mp-mock { :set_property_native (λ [property value]
                  (fprint "  #set-property-native |> %s <- %s" property (tostring value)))
                :get_property_native (λ [property ?default]
                  (fprint "  #get-property-native |> %s%s"
                    property
                    (if (= (or ?default nil) nil) ""
                        (.. " <? " (tostring ?default))) )) } ]
  (lua "if not _G.mp then _G.mp = mp_mock end")
)

;;#endregion Mock mp table for testing


(import-macros { : set-native! : get-native! } :mp-macros)
(macrodebug (set-native! :prop-name 4))
(set-native! :prop-name 4)
(macrodebug (get-native! :prop-name :default-string-value))
(get-native! :prop-name :default-string-value)
