#!/usr/bin/env bash

BASE=$(dirname $(readlink -f $0))

function die(){  warn $*; exit 1; }
function warn(){ echo $* >&2; }

[ -f "$BASE/config.sh" ] && source "$BASE/config.sh"
[ -z "$NFSHOST" ] && die variable NFSHOST not defined

export NFSPREFIX=${NFSPREFIX:-$BASE}
export BASE_SYSTEMS_rel=systems
export MIRROR=${MIRROR:-http://mirrors.kernel.org/ubuntu}

export BASE_SYSTEMS=$NFSPREFIX/$BASE_SYSTEMS_rel
export CONFIG=$NFSPREFIX/pxelinux.cfg/default

export DIR_RECIPES=${DIR_RECIPES:-$BASE/recipes/}
export DIR_INTEGRATIONS=${DIR_INTEGRATIONS:-$BASE/integrations/}

mkdir -p $BASE_SYSTEMS

# grab other files
# TODO: take to the right part, maybe integrations?
cp /usr/lib/PXELINUX/pxelinux.0 /usr/lib/syslinux/modules/bios/menu.c32 $NFSPREFIX

step_integrate(){
	local integrations=$(ls $DIR_INTEGRATIONS)
	[ -n "$INTEGRATIONS_ENABLED" ] && integrations="$INTEGRATIONS_ENABLED"

	for integration in $integrations; do
		[ -x "$DIR_INTEGRATIONS/$integration" ] && $DIR_INTEGRATIONS/$integration
	done
}

step_system_install(){
	local systems=$(ls $DIR_RECIPES)
	[ -n "$SYSTEMS_ENABLED" ] && systems="$SYSTEMS_ENABLED"

	for system in $systems; do
		[ -x "$DIR_RECIPES/$system/recipe" ] && $DIR_RECIPES/$system/recipe install >$BASE_SYSTEMS/$system-install.log 2>&1 &
	done
	wait
}

step_config_write(){
	local systems=$(ls $DIR_RECIPES)
	[ -n "$SYSTEMS_ENABLED" ] && systems="$SYSTEMS_ENABLED"

	mkdir -p $(dirname $CONFIG)
	cat > $CONFIG <<-END
	# DO NOT EDIT THIS FILE
	#
	# this is autogenerated.
	#
	# look into $NFSPREFIX/setup/ and create there a new entry

	DEFAULT menu.c32
	ALLOWOPTIONS 1
	PROMPT 0
	TIMEOUT 0

	MENU TITLE BOOT OVER NETWORK
	END

	for system in $systems; do
		[ -x "$DIR_RECIPES/$system/recipe" ] && $DIR_RECIPES/$system/recipe config >> $CONFIG
	done
}

case "$1" in
	"")
		step_system_install
		step_config_write
		step_integrate
		;;
	system-install)
		step_system_install
		step_config_write
		;;
	config-write)
		step_config_write
		;;
	integrate)
		step_integrate
		;;
	*)
		die "Please specify one of the following actions: (integrate|system-install|config-write)"
		;;
esac
