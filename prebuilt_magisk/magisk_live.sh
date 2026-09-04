#!/system/bin/sh
# magisk_live.sh - Live Magisk setup for Android-x86 (данAemon), no zygote stop/start
# Based on official Magisk scripts/live_setup.sh, minus stop/start (which crashes TV shell)
LOG=/data/local/tmp/magisk_live.log
exec > "$LOG" 2>&1

echo "=== magisk_live start $(date) ==="

# Ensure root
if [ "$(id -u)" != "0" ]; then
  echo "Not root, re-exec via su"
  exec /system/xbin/su 0 /system/bin/sh "$0"
fi

MAGISKTMP=/sbin
MAGISKBIN=/data/adb/magisk

# 1. Mount /sbin tmpfs
mount -o remount,rw / 2>/dev/null
mkdir -p /sbin 2>/dev/null
mount -t tmpfs -o mode=0755 tmpfs /sbin 2>/dev/null
chcon u:object_r:rootfs:s0 /sbin 2>/dev/null
echo "sbin mounted: $(mount | grep ' /sbin ')"

# 2. Populate /sbin
cp /system/bin/magisk $MAGISKTMP/magisk 2>/dev/null
cp /system/bin/magiskpolicy $MAGISKTMP/magiskpolicy 2>/dev/null
chmod 755 $MAGISKTMP/magiskpolicy 2>/dev/null
chmod 4755 $MAGISKTMP/magisk 2>/dev/null
ln -sf ./magisk $MAGISKTMP/su
ln -sf ./magisk $MAGISKTMP/resetprop
ln -sf ./magiskpolicy $MAGISKTMP/supolicy
echo "sbin contents: $(ls $MAGISKTMP)"

# 3. MAGISKBIN
mkdir -p $MAGISKBIN $MAGISKBIN/modules $MAGISKBIN/post-fs-data.d $MAGISKBIN/service.d 2>/dev/null
cp $MAGISKTMP/magisk $MAGISKBIN/magisk 2>/dev/null
cp $MAGISKTMP/magiskpolicy $MAGISKBIN/magiskpolicy 2>/dev/null
chmod 755 $MAGISKBIN/magisk $MAGISKBIN/magiskpolicy 2>/dev/null

# 4. Internal .magisk dirs (worker as tmpfs like official)
mkdir -p $MAGISKTMP/.magisk/device $MAGISKTMP/.magisk/worker 2>/dev/null
mount -t tmpfs -o mode=0755 tmpfs $MAGISKTMP/.magisk/worker 2>/dev/null
mount --make-private $MAGISKTMP/.magisk/worker 2>/dev/null
touch $MAGISKTMP/.magisk/config $MAGISKTMP/.magisk/live 2>/dev/null
echo "magisk internal: $(ls $MAGISKTMP/.magisk)"

# 5. SELinux patch
if [ -d /sys/fs/selinux ]; then
  if [ -f /vendor/etc/selinux/precompiled_sepolicy ]; then
    $MAGISKTMP/magiskpolicy --load /vendor/etc/selinux/precompiled_sepolicy --live --magisk 2>&1
  else
    $MAGISKTMP/magiskpolicy --live --magisk 2>&1
  fi
fi
echo "sepolicy patch done"

# 6. Start magisk daemon through init triggers (NOT --daemon directly)
export MAGISKTMP
$MAGISKTMP/magisk --post-fs-data
echo "post-fs-data rc=$?"
sleep 1
$MAGISKTMP/magisk --service
echo "service rc=$?"
sleep 2
$MAGISKTMP/magisk --boot-complete
echo "boot-complete rc=$?"

echo "=== magisk_live done ==="
echo
echo "Processes:"
ps -A | grep magisk
echo
echo "Socket:"
grep -i magisk /proc/net/unix || find /dev -name '*magisk*'
echo
echo "Log at: $LOG"