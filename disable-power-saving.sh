#!/bin/bash
#
# Simple script trying to achieve more stable results by disabling
# cpu throtling. This is first draft, there is no way to restore original
# values.
#

function disable_cpu_throttling()
{
	pdebug "Disabling cpu throttling"

	test -f /sys/devices/system/cpu/intel_pstate/no_turbo && echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
	
	test -f /sys/devices/system/cpu/cpufreq/boost && echo 0 > /sys/devices/system/cpu/cpufreq/boost

	test -d /sys/devices/system/cpu/cpu0/cpuidle || return 0

	count=0

	while [ $count -lt 999 ] ; do
		cpu=/sys/devices/system/cpu/cpu$count
		test -d $cpu || break
		for cstate in $cpu/cpuidle/state* ; do
			test ${cstate##*/state} -ne 0 || continue
			echo 1 > $cstate/disable
		done
		count=$[count+1]
	done
}

function enable_cpu_throttling()
{
	pdebug "Enabling cpu throttling"

	test -f /sys/devices/system/cpu/intel_pstate/no_turbo && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo

	test -f /sys/devices/system/cpu/cpufreq/boost && echo 1 > /sys/devices/system/cpu/cpufreq/boost

	test -d /sys/devices/system/cpu/cpu0/cpuidle || return 0

	count=0

	while [ $count -lt 999 ] ; do
		cpu=/sys/devices/system/cpu/cpu$count
		test -d $cpu || break
		for cstate in $cpu/cpuidle/state* ; do
			test ${cstate##*/state} -ne 0 || continue
			echo 0 > $cstate/disable
		done
		count=$[count+1]
	done
}
