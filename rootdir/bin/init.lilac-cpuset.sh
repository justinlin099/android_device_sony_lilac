#!/vendor/bin/sh
sleep 8
[ "$(cat /dev/cpuset/background/cpus)" = "0-1" ] && exit 0
echo "0-3,6"   > /dev/cpuset/foreground/boost/cpus
echo "0-3,6"   > /dev/cpuset/foreground/cpus
echo "${1:-0-3,6-7}" > /dev/cpuset/top-app/cpus
echo "0-1"     > /dev/cpuset/background/cpus
echo "0-3"     > /dev/cpuset/system-background/cpus
echo "0-3"     > /dev/cpuset/restricted/cpus
echo "0-3,6-7" > /dev/cpuset/camera-daemon/cpus
