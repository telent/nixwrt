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
       "up?" (fn [dev] false)
       "find-device"  (fn [name] { "name" name })
       "device-name" (fn [dev] dev.name)
       "ipstate-script" (fn [dev] (.. "/run/services/ipstate-" dev.name))
       )

(var my-events [])

(fn new-process [command]
  {
   :command command
   :running false
   :start (fn [p] (set p.running true))
   :stop (fn [p] (set p.running false))
   })

(mocks :process
       "clock" (fn [p] (- 123456 (length my-events)))
       "start-process" (fn [p] (p:start))
       "stop-process" (fn [p] (p:stop))
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
          (let [p (new-process "pppd")]
            (mock :process "new-process"
                  (fn [c]
                    (if (c:match "pppd") p (new-process))))
            (var joined false)
            (var started false)
            (set my-events [1 2 3 4 5 6 7 8 ])
            (mock :process :join #(set joined true))
            (tset p "start" #(set started true))
            (pppoe "eth0" "ppp0")
            (assert joined "ifconfig process did not join")
            (assert started "daemon did not start")))

        (lambda backoff-increases-on-failure []
          (var delay 0)
          (var delay2 0)
          (let [p (new-process "pppd")
                mark-time #(+ $1 (if p.running 0 1))
                count1 #(set delay (mark-time delay))
                count2 #(set delay2 (mark-time delay2))]
            (mock :process :join #(+ 1))
            (mock :process "new-process"
                  (fn [c]
                    (if (c:match "pppd") p (new-process))))
            (set my-events [;; given the process is started
                            1 2 3 4 5 6 7 8
                            ;; when it stops without achieving health
                            #(p:stop)
                            ;; there is a delay before it can be restarted
                            count1 count1 count1 count1 count1
                            count1 count1 count1 count1 count1
                            count1 count1 count1 count1 count1
                            ;; when it stops again without achieving health
                            #(p:stop)
                            count2 count2 count2 count2 count2
                            count2 count2 count2 count2 count2
                            count2 count2 count2 count2 count2
                            ;; then the delay is longer
                            ])
            (pppoe "eth0" "ppp0")
            (print delay) (print delay2)
            (assert (> delay 1) )
            (assert (>  delay2 (* 2 (- delay 1))))))
        ])

(each [_ value (pairs all-tests)] (value))
