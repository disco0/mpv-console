(fn fprint [body ...]
   (print (string.format body ...)))

; Mock mp table for testing
(when (not (type (. _G :mp)) :table)
  (global mp {
    :set_property_native (λ [value]
      (fprint "#set-property-native => %s" (tostring value)))
    :get_property_native (λ [property ?default]
      (fprint "#get-property-native => %s%s"
        (tostring property)
        (if (= ?default nil) ""
            (.. " -?> " (tostring ?default)))))
  }))

(macros {
   :set-native! (fn [value]
     `(mp.set_property_native ,value) )
   :get-native! (fn [value ?default]
     (if (sym? ?default)
        `(mp.get_property_native ,value ,?default)
        `(mp.get_property_native ,value) ) )
})

{
  : set-native!
  : get-native!
}
