(local netdev (require :netdev))
(local ppp (require :ppp))
(local process (require :process))
(local event (require :event))
(local inspect (require :inspect))

(fn f. [fmt ...]
  (string.format fmt ...))

(fn now [] (process.clock))
(fn nil? [x] (= x nil))

(fn pppoe-daemon [transport-device ppp-device]
  (let [ppp-device-name (ppp.device-name ppp-device)
        ipstate-script (ppp.ipstate-script ppp-device)
        pppd (process.new-process
              (f. "pppd %s  --ip-up-script %s --ip-down-script %s "
                  (netdev.device-name transport-device)
                  ipstate-script
                  ipstate-script))]
    (var backoff-until nil)
    (var backoff-interval 1)
    (each [event (event.next-event transport-device pppd)]
      (when (and (not (process.running? pppd))
                 (nil? backoff-until))
        (set backoff-interval (* 2 backoff-interval))
        (set backoff-until (+ (now) backoff-interval))
;        (print "backoff" event backoff-interval backoff-until)
        )
      (when (and (not (process.running? pppd))
                 (netdev.link-up? transport-device)
                 backoff-until
                 (< backoff-until (now)))
;        (print backoff-until (now))
        (set backoff-until nil)
        (process.join (process.new-process
                       (f. "ifconfig %s up"
                           (netdev.device-name transport-device))))
        (process.start-process pppd))
      (when (and (process.running? pppd)
                 (not (netdev.link-up? transport-device)))
        (process.stop-process pppd))
      (when (and (ppp.up? ppp-device) (> backoff-interval 1))
        (set backoff-interval 1))
      )))

(lambda main [eth-device-name ppp-device-name]
  (let [pppdev (ppp.find-device ppp-device-name)]
    (pppoe-daemon (netdev.find-device eth-device-name) pppdev)))
