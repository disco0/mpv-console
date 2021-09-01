(fn set-native* [property value]
  `(mp.set_property_native ,property ,value) )

(fn get-native* [property ?default]
  (if ?default
    `(mp.get_property_native ,property ,?default)
    `(mp.get_property_native ,property) ))

{
  :set-native! set-native*
  :get-native! get-native*
}
