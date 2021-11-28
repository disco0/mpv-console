; this, https://gist.github.com/nikneym/b7422a73c91d632e95ad34a813aad105
;; but stuffed in a Fennel macro.

;; Based on

;; @TODO: Prototypal inheritance support

(macro class [?super]
  `(let [ o#     { }
          super# (or ,?super nil) ]
     (tset o# :__index o#)
     (when super#
       (tset o# :super super#)
       (each [k# v# (pairs super#)]
         (when (not= 1 (k#:find "__"))
           (tset o# k# v#))))
     (setmetatable o# { :__call (fn [self# ...]
                                 (let [new# (setmetatable {} self#)]
                                   (new#:new ...)
                                   new#))})))
