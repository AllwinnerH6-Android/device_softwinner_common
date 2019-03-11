#!/bin/bash

localpath=$(cd $(dirname $0) && pwd)
workpath=$(pwd)

action=""
config=$localpath/.buildconfig
product=""

function LOG_ERR()
{
	echo -e "\033[47;31mERROR: $*\033[0m"
}

function LOG_WARN()
{
	echo -e "\033[47;33mWARN: $*\033[0m"
}

function LOG_INFO()
{
	echo -e "\033[47;32mINFO: $*\033[0m"
}

function show_help()
{
	printf "./build.sh [-h]|[-p <product>]|[-c <configfile>] [action]\n"
	printf "option:\n"
	printf "	-h:        show this help message\n"
	printf "	-p:        build <product>, config file will find in product folder\n"
	printf "	-c:        use <configfile> as the config file\n"
	printf "action:\n"
	printf "	update:    update lichee and android code\n"
	printf "	clean:     do lichee clean and android installclean\n"
	printf "	distclean: do lichee distclean and android installclean\n"
	printf "	config:    config build parameter, save configfile to .buildconfig\n"
	printf "	lichee:    build lichee\n"
	printf "	android:   build android\n"
	printf "	pack:      pack android firmware\n"
	printf "	all:       full build\n"
	printf "	<NULL>:    equal to action all\n\n"
}

while getopts hcp: opt; do
	case $opt in
		h)
			show_help
			exit 0
			;;
		c)
			config=$OPTARG
			;;
		p)
			product=$OPTARG
			;;
		*)
			show_help
			exit 0
			;;
	esac
done

dlist=$(echo "$@" | grep -o "\-[0-9a-zA-Z]\s\+[0-9a-zA-Z_-/.]\+")
alist=$@

for act in $alist; do
	actinvalid=false
	for d in $dlist; do
		[ "x$d" == "x$act" ] && actinvalid=true
	done
	[ "x$actinvalid" == "xtrue" ] && continue

	case $act in
		update)
			action="$action code_update"
			;;
		clean)
			action="$action build_clean"
			;;
		distclean)
			action="$action build_distclean"
			;;
		lichee)
			action="$action build_lichee"
			;;
		android)
			action="$action build_android"
			;;
		pack)
			action="$action build_pack"
			;;
		all)
			action="$action build_all"
			;;
		config)
			action="$action build_config"
			;;
		*)
			LOG_WARN "Unsupport action: $act"
			;;
	esac
done

[ -z "$action" ] && action="build_all"
action="$(echo $action)"

function contains()
{
	local str=$1
	local needle=$2
	echo $str | grep -o "$needle"
}

function time2string()
{
	local timediff=$1
	echo $timediff | awk '{
		t = split("60 s 60 m 24 h 999 d",a);
		for(n = 1; n < t; n += 2) {
			if ($1 == 0) {
				if (n == 1)
					s = 0a[2]
				break
			}
			s = $1%a[n]a[n+1]s
			$1 = int($1/a[n])
		}
		print s
	}'
}

function find_key()
{
	local cfgfile=$1
	local key=$2
	local val=""
	val="$(grep "^\s*export $key\s*=" $cfgfile | tail -n 1 | grep -oP "(?<==).*" | awk '{sub("^[	 ]*","");print}')"
	eval echo "$val"
}

function save_key()
{
	local cfgfile=$1
	local key=$2
	local val=$3
	if [ -n "$(grep "^\s*export\s\+$key\s*=" $cfgfile)" ]; then
		sed -i "s#^\s*export\s\+$key\s*=.*#export $key=$val#g" $cfgfile
	else
		echo "export $key=$val" >> $cfgfile
	fi
}

function load_config()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	cd $localpath
	grep "^\s*export\s\+LICHEE_[A-Z_]\+=.*" $config > $localpath/../lichee/.buildconfig
	source build/envsetup.sh
	source $config
	lunch  $(find_key $config TARGET_PRODUCT)-$(find_key $config TARGET_BUILD_VARIANT)
}

function code_update()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	cd $localpath/../lichee
	repo sync
	cd $localpath
	repo sync
}

function build_clean()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	local platform=$1
	cd $localpath/../lichee
	./build.sh clean
	cd $localpath
	make installclean
}

function build_distclean()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	cd $localpath/../lichee
	./build.sh distclean
	cd $localpath
	make installclean
}

function build_config()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"

	cd $localpath/../lichee
	./build.sh config

	[ -f $localpath/.buildconfig ] && \
	sed -i '/^\s*export\s\+LICHEE/d' $localpath/.buildconfig && \
	chmod +w $localpath/.buildconfig
	cat $localpath/../lichee/.buildconfig >> $localpath/.buildconfig

	local args="$(find_key $config TARGET_PACK_ARGS)"
	read -p "Please input pack args [$args]: " packargs
	if [ -n "$packargs" ]; then
		save_key $config TARGET_PACK_ARGS "\"$packargs\""
	fi

	cd $localpath/
	source build/envsetup.sh
	source $config
	lunch
	save_key $config TARGET_BUILD_VARIANT $TARGET_BUILD_VARIANT
	save_key $config TARGET_PRODUCT       $TARGET_PRODUCT
}

function build_lichee()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	cd $localpath/../lichee
	./build.sh
}

function build_android()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	cpuno=$(cat /proc/cpuinfo  | grep process| wc -l)
	jobs=$((cpuno*2/3))
	cd $localpath
	extract-bsp
	make -j $jobs
}

function build_pack()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	local packargs=$(find_key $config TARGET_PACK_ARGS)
	if [ -n $(contains "$packargs" "\-v") ]; then
		cd $localpath/../lichee/tools/pack
		./createkeys -c $(find_key $config LICHEE_CHIP)
	fi
	cd $localpath
	pack $packargs
}

function build_all()
{
	LOG_INFO "FUNCNAME => (${FUNCNAME[@]})"
	build_distclean
	build_lichee && \
	build_android && \
	build_pack
}

if [ -z $(contains "$action" "build_config") ]; then
	if [ -n "$product" ]; then
		if [ -d $localpath/device/softwinner/$product ]; then
			productcfg="$(find  $localpath/device/softwinner/$product/ -name "build*.conf")"
			if [ -z "$productcfg" ]; then
				LOG_ERR "No build config found for product $product."
				exit 0
			else
				LOG_INFO "Found config file for $product:"
				for p in $productcfg; do
					LOG_INFO "$p"
				done
				config=$(echo "$productcfg" | head -n 1)
				if [ $(echo "$productcfg" | wc -l) != 1 ]; then
					LOG_WARN "Config file number > 1, use the first one."
				fi
			fi
		else
			LOG_ERR "No such product called $product."
			exit 0
		fi
	fi

	if [ ! -f $config ]; then
		LOG_ERR "No config file $config exsist, run config first."
		exit 0
	fi
fi

if [ "x$action" != "xbuild_clean" ] && \
   [ "x$action" != "xbuild_distclean" ] && \
   [ "x$action" != "xbuild_config" ] && \
   [ "x$action" != "xcode_update" ]; then
	LOG_INFO "Config file: $config"
	action="load_config $action"
fi

LOG_INFO "ACTION LIST: $action"

time_start=$(date +"%s")
for ACT in $action; do
	time0=$(date +"%s")
	$ACT
	status=$?
	time1=$(date +"%s")
	LOG_INFO "action $ACT, token time $(time2string $((time1-time0)))."
	[ $status -ne 0 ] && break
done
time_end=$(date +"%s")
LOG_INFO "all action token time $(time2string $((time_end-time_start)))."

