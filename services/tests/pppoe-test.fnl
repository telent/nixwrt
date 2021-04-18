(local inspect (require :inspect))

(fn trace [x]
  (print x)
  x)

(tset package.loaded :netdev
      {
       "find-device"  (fn [name] { "name" name })
       "device-name" (fn [dev] dev.name)
       "link-up?" (fn [dev] true)
       })
(tset package.loaded :ppp
      {
       "up?" (fn [dev] true)
       "find-device"  (fn [name] { "name" name })
       "device-name" (fn [dev] dev.name)
       "ipstate-script" (fn [dev] (.. "/run/services/ipstate-" dev.name))
       })

(var my-events [])

(tset package.loaded :process
      {
       "new-process" (fn [command]
                       (assert
                        (or
                         (command:find "ipstate-%ppp.")
                         (command:find "ifconfig"))
                        command)
                       {:command command :running false})
       "clock" (fn [p] (- 123456 (length my-events)))
       "start-process" (fn [p] (set p.running true))
       "stop-process" (fn [p] (set p.running false))
       "running?" (fn [p] p.running)
       })

;; (fn mock [package name f]
;;   (tset package.loaded[package] name f))

(tset package.loaded :event
      {
       "next-event" (fn []
                      (fn []
                        (let [e (table.remove my-events 1)]
                          (if (= (type e) "function")
                              (or (e) true)
                              e))))
       })


(local pppoe (require :pppoe))

(local all-tests
       [
        (lambda daemon-starts []
          (var joined false)
          (var started false)
          (set my-events [1 2 3 4 5 6 7 8 ])
          (tset package.loaded.process
                :join
                (fn [p] (set joined true)))
          (tset package.loaded.process
                "start-process"
                (fn [p] (set started true)))
          (pppoe "eth0" "ppp0")
          (assert joined "ifconfig process did not join")
          (assert started "daemon did not start"))

        (lambda backoff-increases-on-failure []
          ;; given the process is started
          ;; when it stops without achieving health
          ;; there is a delay before it can be restarted
          )


        ])


(each [_ value (pairs all-tests)] (value))
