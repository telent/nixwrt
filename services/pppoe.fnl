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
    (each [event (event.next-event transport-device pppd)]
      (when (and (not (process.running? pppd))
                 (nil? pppd.backoff-until))
        (pppd:backoff))
      (when (and (not (process.running? pppd))
                 (netdev.link-up? transport-device)
                 pppd.backoff-until
                 (<= pppd.backoff-until (now)))
        (process.join (process.new-process
                       (f. "ifconfig %s up"
                           (netdev.device-name transport-device))))
        (process.start-process pppd))
      (when (and (process.running? pppd)
                 (not (netdev.link-up? transport-device)))
        (process.stop-process pppd))
      (when (and (ppp.up? ppp-device) (> pppd.backoff-interval 1))
        (pppd:aver-health))
      )))

(lambda main [eth-device-name ppp-device-name]
  (let [pppdev (ppp.find-device ppp-device-name)]
    (pppoe-daemon (netdev.find-device eth-device-name) pppdev)))
