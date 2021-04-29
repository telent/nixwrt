# Service control

## The present

As of Oct 2020 there is the basis of a "service" abstraction for
daemon processes: we have "start" and "stop" commands, and
dependencies so that service A can say it needs service B to run first

We implement this by writing a config script for monit, which takes
care of (re)starting what is stopped and ordering things
appropriately

The service abstraction also covers network interfaces, which lets us
say things like e.g. "ntp depends on a working wan connection". It has
some but not all of what we want for service health checking - it can
tell if a network connection is down, and we *could* write tests for
services with network ports to check they are responding

What it's not very good at is

- bringing up services on boot, it takes several runs (at 30 second intervals)
 to bring up services with dependencies

- monitoring file changes (e.g. for config files)

- noticing quickly when services die (it doesn't act as parent to their
  processes, so only sees on the next run when something has fallen over)

## The future

* We get data from our ISP via DHCP6 and router advertisements, which
  we can use to dynamically control services. Typically this means
  changing a config file and then either restarting or reloading some
  process

* services often have state machines more complicated than "on" or "off",
  we don't want to start a service when the one we only just started
  is still initialising

  * for example we would like to poll the xl2tpd control socket to get
    l2tp tunnel health, then we could wait until it's set up before
    trying to start a session over it.

* we'd like to know when processes die without relying on pids (racey)

* perhaps some day we could do secrets updates through this mechanism
  as well: e.g. push a new root ssh key onto the device and have ssh restart
  
the process or service probably has its own state: for each of those
states we want to be able to say "is it healthy?" and "if not, is
there some healing intervention we could make?".  For example

- the interface is up => (yes, _)
- the process was only recently started and not ready yet => (no, no)
- the interface is down because no cable => (no, no)
- the interface is down because kernel oops => (no, reload module)
- the process is consuming 90% of available ram => (no, kill and restart)
- the process has exited => (no, restart it)

if a service is unhealthy because one of its dependencies is unhealthy, 
we will not intervene until the underlying thing comes good

each healing intervention is associated with a backoff time (or "expected
time to resolution") during which no other intervention will be
attempted

probably it would be good to have a medical history so we don't get
trapped in an infinite loop of trying the same thing over and over and
it continuing to not work.

how do we fit inputs into this? an input is
 - change in a monitored file
 - change in health of an antecedent service (expressed how?)
 - a request to start/stop
 - a piece of hardware becoming (un)available
 - a timer?
 
