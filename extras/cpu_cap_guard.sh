#!/system/bin/sh
# OneOS CPU-cap guard. OneOS's performance worker lowers CPU limits when the phone is hot
# and raises them when it cools, but the moment it sees a limit it didn't write it marks
# the core "external" and stops managing it for good. A cap set while the phone was hot
# (Samsung cpufreq_limit vote 998400, policies at ~1 GHz) then stays forever: the whole
# phone runs at ~1/4 speed. This guard only acts when the phone is COOL (skin < 40 C on
# two checks in a row): it releases the stale cap and hands control back to OneOS.
#
# Usage:  sh cpu_cap_guard.sh        keep watching (put it in /data/adb/service.d/)
#         sh cpu_cap_guard.sh once   check right now and release a stale cap if the phone is cool
LOG=/data/adb/cpu_cap_guard.log
PIDFILE=/data/adb/cpu_cap_guard.pid
S=/sys/devices/system/cpu
STATE=/data/local/tmp/oneos/performance_handover
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG; }


skin() {  # highest skin temperature (type 3) reported by the thermal service, in C
  timeout 5 dumpsys thermalservice 2>/dev/null | sed -n '/^Current temperatures from HAL:/,/^Current cooling devices/p' |
    sed -n 's/.*mValue=\([0-9.]*\), mType=3,.*/\1/p' | awk 'NF{if(!s||$1>m)m=$1;s=1} END{if(s)printf "%d", m}'
}
capped() {
  [ "$(cat $S/cpufreq_limit/cpufreq_max_limit 2>/dev/null)" != "-1" ] && return 0
  for p in $S/cpufreq/policy*; do
    [ "$(cat $p/scaling_max_freq)" -lt "$(cat $p/cpuinfo_max_freq)" ] && return 0
  done
  return 1
}
oneos_locked_out() {  # OneOS (in its own mount namespace) has given up on a core
  P=$(pgrep -f bring_watch.sh | head -1); [ -n "$P" ] || return 1
  busybox nsenter -t $P -m sh -c "ls $STATE/*.external >/dev/null 2>&1"
}

release() {  # $1 = skin temperature
  before="limit=$(cat $S/cpufreq_limit/cpufreq_max_limit) p0=$(cat $S/cpufreq/policy0/scaling_max_freq) p6=$(cat $S/cpufreq/policy6/scaling_max_freq)"
  echo -1 > $S/cpufreq_limit/cpufreq_max_limit
  for p in $S/cpufreq/policy*; do cat $p/cpuinfo_max_freq > $p/scaling_max_freq; done
  P=$(pgrep -f bring_watch.sh | head -1)
  busybox nsenter -t $P -m sh -c "cd $STATE && rm -f *.external *.last && echo \"\$(date +%T) cpu_cap_guard: released stale cap ($before) at skin ${1}C\" >> ../performance_handover.log"
  log "skin ${1}C, released stale cap ($before)"
  echo "Released the stale CPU cap ($before). Full speed is back."
}

if [ "$1" = once ]; then
  t=$(skin)
  if [ -z "$t" ]; then echo "Could not read the temperature; doing nothing."; exit 1; fi
  if [ "$t" -ge 40 ]; then echo "Phone is warm (${t}C): the cap is protecting it. Try again when it has cooled down."; exit 0; fi
  if ! capped; then echo "CPU is not capped (${t}C). Nothing to do."; exit 0; fi
  if ! oneos_locked_out; then echo "CPU is capped, but OneOS is still managing it (${t}C). Leaving it alone."; exit 0; fi
  release "$t"; exit 0
fi

if [ -f $PIDFILE ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then kill "$(cat $PIDFILE)" 2>/dev/null; fi
echo $$ > $PIDFILE
log "guard started (pid $$)"

cool=0
while true; do
  sleep 60
  t=$(skin)
  if [ -n "$t" ] && [ "$t" -lt 40 ]; then cool=$((cool + 1)); else cool=0; continue; fi
  [ $cool -ge 2 ] || continue
  capped || continue
  oneos_locked_out || continue
  release "$t"
  cool=0
done
