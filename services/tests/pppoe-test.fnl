(local inspect (require :inspect))

(fn trace [x]
  (print x)
  x)

(lambda mock [pkg name f]
  (if (= nil (. package.loaded pkg))
      (tset package.loaded pkg {}))
  (tset (. package.loaded pkg)
        name f))

(lambda mocks [pkg ...]
  (let [[n f & rst] [...]]
    (mock pkg n f)
    (if (next rst)
        (mocks pkg (table.unpack rst)))))


(mocks :netdev
       "find-device"  (fn [name] { "name" name })
       "device-name" (fn [dev] dev.name)
       "link-up?" (fn [dev] true)
       )

(mocks :ppp
       "up?" (fn [dev] true)
       "find-device"  (fn [name] { "name" name })
       "device-name" (fn [dev] dev.name)
       "ipstate-script" (fn [dev] (.. "/run/services/ipstate-" dev.name))
       )

(var my-events [])

(mocks :process
       "new-process"
       (fn [command]
         (assert
          (or
           (command:find "ipstate-%ppp.")
           (command:find "ifconfig"))
          command)
         {:command command :running false})
       "clock" (fn [p] (- 123456 (length my-events)))
       "start-process" (fn [p] (set p.running true))
       "stop-process" (fn [p] (set p.running false))
       "running?" (fn [p] p.running))

(mock :event "next-event"
      (fn []
        (fn []
          (let [e (table.remove my-events 1)]
            (if (= (type e) "function")
                (or (e) true)
                e)))))

(local pppoe (require :pppoe))

(local all-tests
       [
        (lambda daemon-starts []
          (var joined false)
          (var started false)
          (set my-events [1 2 3 4 5 6 7 8 ])
          (mock :process :join #(set joined true))
          (mock :process "start-process" #(set started true))
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
