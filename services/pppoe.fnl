(local netdev (require :netdev))
(local ppp (require :ppp))
(local process (require :process))
(local event (require :event))
(local inspect (require :inspect))

(fn f. [fmt ...]
  (string.format fmt ...))

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
      (when (pppd:died?) (pppd:backoff))
      (when (and (netdev.link-up? transport-device)
                 (not pppd.running?)
                 (pppd:backoff-expired?))
        (:
         (process.new-process
          (f. "ifconfig %s up"
              (netdev.device-name transport-device)))
         :join)
        (pppd:start))
      (when (and pppd.running?
                 (not (netdev.link-up? transport-device)))
        (pppd:stop))
      (when  (ppp.up? ppp-device)
        (pppd:aver-health))
      )))

(lambda main [eth-device-name ppp-device-name]
  (let [pppdev (ppp.find-device ppp-device-name)]
    (pppoe-daemon (netdev.find-device eth-device-name) pppdev)))
