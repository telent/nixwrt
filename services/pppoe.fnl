(local netdev (require :netdev))
(local ppp (require :ppp))
(local process (require :process))
(local event (require :event))
(local inspect (require :inspect))

(fn nil? [x] (= x nil))

(fn pppoe-daemon [transport-device ppp-device]
  (let [ppp-device-name (ppp.device-name ppp-device)
        ipstate-script (ppp.ipstate-script ppp-device)
        pppd (process.new-process
              (.. "pppd " (netdev.device-name transport-device)
                  " --ip-up-script " ipstate-script
                  " --ip-down-script " ipstate-script))]
    (each [event (event.next-event transport-device pppd)]
      (when (pppd:died?) (pppd:backoff))
      (when (and (netdev.link-up? transport-device)
                 (not pppd.running?)
                 (pppd:backoff-expired?))
        (:
         (process.new-process
          (.. "ifconfig "
              (netdev.device-name transport-device)
              " up"))
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
