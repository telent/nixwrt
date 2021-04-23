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

(fn clock [] (- 123456 (length my-events)))

(fn new-process [command]
  {
   :command command
   "running?" false
   "exit-status" nil
   :start (fn [p]
            (set p.backoff-until nil)
            (set p.running? true))
   :stop (fn [p] (set p.running? false))
   :join (fn [p] (set p.exit-status 0))
   "backoff-until" nil
   "backoff-interval" 1
   :backoff
   (fn [p]
     (when (= nil p.backoff-until)
       (set p.backoff-until (+ (clock) p.backoff-interval))
       (set p.backoff-interval (* 2 p.backoff-interval))))
   "died?" (fn [p] (and (not p.running?) (= p.backoff-until nil)))
   "backoff-expired?"
   (fn [p]
     (and p.backoff-until (<= p.backoff-until (clock))))
   "aver-health" (fn [p] (set p.backoff-interval 1))
   })

(mocks :process
       :clock clock
       :run (fn [command] (let [p (new-process command)] (p:join)))
       )

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
            (var ifconfiged false)
            (mock :process "new-process"
                  (fn [c]
                    (if (c:match "pppd") p {})))
            (mock :process "run" #(set ifconfiged true))
            (set my-events [1 2 3 4 5 6 7 8 ])
            (pppoe "eth0" "ppp0")
            (assert ifconfiged "ifconfig process failed")
            (assert p.running? "daemon did not start")))

        (lambda backoff-increases-on-failure []
          (var delay 0)
          (var delay2 0)
          (let [p (new-process "pppd")
                mark-time #(+ $1 (if p.running? 0 1))
                count1 #(set delay (mark-time delay))
                count2 #(set delay2 (mark-time delay2))]
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
            (assert (> delay 1) )
            (assert (=  delay2 (* 2 delay)))))

        (lambda backoff-resets-on-connect []
          (var delay 0)
          (var delay2 0)
          (let [p (new-process "pppd")
                mark-time #(+ $1 (if p.running? 0 1))
                count1 #(set delay (mark-time delay))
                count2 #(set delay2 (mark-time delay2))]
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
                            ;; but if it has successfully opened a connection
                            #(mock :ppp "up?" #true)
                            9
                            ;; when it stops again
                            #(p:stop)
                            count2 count2 count2 count2 count2
                            count2 count2 count2 count2 count2
                            count2 count2 count2 count2 count2
                            ;; then the delay was reset
                            ])
            (pppoe "eth0" "ppp0")
            (assert (> delay 1) )
            (assert (<=  delay2 delay))))

        ;; test that we kill the process when link device drops
        ;; and resume instantly (no backoff) when it reappears
        (lambda process-quits-on-link-loss []
          (let [p (new-process "pppd")]
            (set p.backoff-interval 10)
            (mock :process "new-process"
                  (fn [c]
                    (if (c:match "pppd") p (new-process))))
            (set my-events [;; given the process is started
                            1 2 3 4 5 6 7 8
                            ;; when the link dies
                            #(mock :netdev "link-up?" #false)
                            9
                            ;; the process is stopped
                            #(assert (not p.running?))
                            1 2 3
                            ;; when the link goes up again
                            #(mock :netdev "link-up?" #true)
                            ;; then the process resumes without backoff
                            #(assert  p.running?)
                            ])
            (pppoe "eth0" "ppp0")
            ))


        ;; EXTRA CREDIT - could we do a kind of property based testing
        ;; by injecting a random event stream of upness/downness/
        ;; connection/disconnection/process killing/etc? what would
        ;; the properties be?
        ])

(each [_ value (pairs all-tests)] (value))
