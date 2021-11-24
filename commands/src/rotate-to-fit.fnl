;; rotate-to-fit (working name):
;;   Rotate portrait videos to fit on screen

(local {
  : mp
  : utils
  : logging
  : msg
  : constants
  : initialize-command
} (require :commands.utils))


(local states
{
    :reset
    {
        :video-rotation 0
    }
    :portrait
    {
        :video-rotation 270
    }
    :landscape
    {
        :video-rotation 270
    }
})

(local state-transforms
  (collect [orientation key-value-table (pairs states)]
    (values orientation (λ [ ]
      (each [key value (pairs key-value-table)]
        (mp.set_property_native key value))))))

(local command-name :rotate-to-fit)

(local active-hook false)
(local log-base (msg.extend :rotate-to-fit))

;;#region Utils

;;;
;;; @FIXME For personal vsc-fennel fork—highlighting breaks when returning a
;;;        sequential list, like so:
;;;
;;; ``` fennel
;;; (λ get-active-media-size [ ]
;;;   [ ( mp.get_property_native :dwidth  -1)
;;;     ( mp.get_property_native :dheight -1) ] )
;;; ```
;;;
;;; Above should be valid, tested this in the fennel repl and it worked:
;;;
;;; ``` fennel
;;; (λ ident [ val ] val)
;;; (λ list-test [] [ (ident 1) (ident 2) ] )
;;; -> [ 1 2 ]
;;; ```

(λ get-active-media-size [ ]
  (let [ dwidth  (or (mp.get_property_native :dwidth  -1) )
         dheight (or (mp.get_property_native :dheight -1) ) ]
    [dwidth dheight] ))

(λ get-active-media-size-safe [ ]
  (let [ [dwidth dheight] (get-active-media-size) ]
    (when (or (= dheight -1)
              (= dwidth  -1))
          (error (string.format
            "Failed to get dwidth and dheight safely in get-active-media-size-safe (dwidth: %s, dheight: %s)"
            (tostring (or dwidth  "[undefined]"))
            (tostring (or dheight "[undefined]")))))
    [dwidth dheight] ))

;---@param ?res number
;---@return boolean
(fn is-valid-res-size? [ ?res ]
  (if (not (= (type (or ?res nil)) :number))
      false
      (<= ?res 0)))

;---@alias Dimensions [ number, number ]

;---@return boolean
(fn valid-video-dimensions? [[?width ?height]]
  (and (is-valid-res-size? ?width)
       (is-valid-res-size? ?height)))

(λ portrait-dimensions? [[dwidth dheight]]
  (> (/ dheight dwidth ) 1.4))

(local apply-orientation-config
  (let [ log (msg.extend :apply)]
    (λ [orientation]
      (assert (= :table (type (. states orientation)))
              "parameter not found in states table.")
      (each [prop value (pairs (. states orientation))]

        (mp.set_property_native prop value)))))

;---@alias Orientation string | '"portrait"' |'"landscape"'

;---@param dimensions Dimensions
;---@return Orientation
(λ orientation-type [dimensions]
  (if (portrait-dimensions? dimensions)
      :portrait
      ;else
      :landscape))

