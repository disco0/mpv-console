(local fennel-view (require :fennel.view))
(local compiler (require :fennel.compiler))

;;#region Doc Comment Emit

(local SPECIALS compiler.scopes.global.specials)

;; idk yet
(local view { })

;; Based on specials.fnl -> comment
(fn doc-comment! [ast _ parent]
  (let [els []]
    (for [i 2 (length ast)]
      (table.insert els (view (. ast i) {:one-line? true})))
    (compiler.emit parent (.. "--- " (table.concat els " ")) ast)))

;; Based on utils.fnl -> comment*
; (fn comment* [contents ?source]
;   (let [{: filename : line} (or ?source [])]
;     (setmetatable {1 contents : filename : line} comment-mt)))

;;#endregion Doc Comment Emit

;;region Debugging

(eval-compiler
  (each [name (pairs _AST)]
    (print name :-> (. _AST name))))

(eval-compiler
  ; (each [name (pairs _G)]
  ;   (print name)))
  (_SPECIALS.comment [ :test ] nil  _AST))
