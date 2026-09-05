#!/system/bin/sh
# init.magisk.sh - In-tree Magisk for Android-x86 (no PID1 hijack, no zygote stop/start)
# Runs at post-fs-data: builds /sbin (tmpfs), installs stub for trusted_cert, then
# marks the post-fs-data stage. The service and boot-complete stages are handled
# by magisk.rc after boot completed, so the manager gets recognized and NOT removed.
LOG=/data/local/tmp/magisk_live.log
[ -n "$1" ] 2>/dev/null && ACTION="$1" || ACTION=""
export PATH=/sbin:/system/bin:/system/xbin:$PATH

log() { echo "$@" >> "$LOG"; }

case "$ACTION" in
  service)
    # Late start: bring up the root manager daemon socket
    /sbin/magisk --service
    chmod o+rx /sbin 2>/dev/null
    chmod o+rx /sbin/.magisk 2>/dev/null
    chmod o+rx /sbin/.magisk/device 2>/dev/null
    chmod o+rw /sbin/.magisk/device/socket 2>/dev/null
    log "service done: $(ps -A | grep '[m]agiskd')"
    exit 0
    ;;
  bootcomplete)
    # Tells daemon boot is completed; it resets bootloop counter & re-ensures manager
    /sbin/magisk --boot-complete
    log "boot-complete done"
    exit 0
    ;;
esac

# ===== post-fs-data (default) =====
echo "=== init.magisk.sh post-fs-data $(date) ===" > "$LOG"

# Ensure root. No /system/xbin/su is shipped; it only exists as a symlink to the
# /sbin (tmpfs) su applet after step 2a. If we're already root (post-fs-data runs
# as root via rc), just continue. Otherwise re-exec via the ramdisk su if present.
if [ "$(id -u)" != "0" ]; then
  if [ -x /sbin/su ]; then
    exec /sbin/su 0 /system/bin/sh "$0" "$ACTION"
  else
    # No su available yet (not root, /sbin not mounted): abort cleanly.
    echo "init.magisk.sh: not root and no /sbin/su yet" >> "$LOG"
    exit 0
  fi
fi

MAGISKTMP=/sbin
MAGISKBIN=/data/adb/magisk
STUB_SRC=/system/etc/magisk/stub.apk

# 1. Mount /sbin tmpfs
mount -o remount,rw / 2>/dev/null
mkdir -p /sbin 2>/dev/null
grep -q ' /sbin ' /proc/mounts || mount -t tmpfs -o mode=0755 tmpfs /sbin 2>/dev/null
chcon u:object_r:rootfs:s0 /sbin 2>/dev/null
log "sbin mounted: $(mount | grep ' /sbin ')"

# 2. Populate /sbin
cp /system/bin/magisk $MAGISKTMP/magisk 2>/dev/null
cp /system/bin/magiskpolicy $MAGISKTMP/magiskpolicy 2>/dev/null
chmod 755 $MAGISKTMP/magiskpolicy 2>/dev/null
chmod 755 $MAGISKTMP/magisk 2>/dev/null
ln -sf ./magisk $MAGISKTMP/su
ln -sf ./magisk $MAGISKTMP/resetprop
ln -sf ./magiskpolicy $MAGISKTMP/supolicy

# 2a. Point the in-PATH /system/xbin/su at the hidden systemless su applet.
# The shipped file is a 49-byte setuid-script bootstrap; once /sbin is up we
# replace it with a symlink to the /sbin su, exactly as real Magisk does
# (su = magisk applet, kept in tmpfs, nothing stored in /system itself).
ln -sf /sbin/su /system/xbin/su 2>/dev/null

# 3. Stub for trusted_cert (in-tree so first boot has it before /data exists)
mkdir -p /sbin/.magisk/device /sbin/.magisk/worker 2>/dev/null
# 3a. Create the preinit block device. Magisk's env_check (>= 25210) requires
# $MAGISKTMP/.magisk/device/preinit to be a block device, otherwise the Magisk
# app shows "Requires additional setup / reflash" even though Magisk works.
# On a phone this node is created by magiskinit from the boot ramdisk; on the
# x86/UEFI (aropa) target there is no boot ramdisk, so we fake it with a block
# node (loop0, 7:0) so env_check passes after every boot.
[ -e /sbin/.magisk/device/preinit ] || mknod /sbin/.magisk/device/preinit b 7 0 2>/dev/null
chmod 660 /sbin/.magisk/device/preinit 2>/dev/null
if [ -f "$STUB_SRC" ]; then
  cp "$STUB_SRC" $MAGISKTMP/stub.apk 2>/dev/null
  chmod 755 $MAGISKTMP/stub.apk 2>/dev/null
fi
log "sbin contents: $(ls $MAGISKTMP)"

# 4. MAGISKBIN + internal dirs
mkdir -p $MAGISKBIN $MAGISKBIN/modules $MAGISKBIN/post-fs-data.d $MAGISKBIN/service.d 2>/dev/null
cp $MAGISKTMP/magisk $MAGISKBIN/magisk 2>/dev/null
cp $MAGISKTMP/magiskpolicy $MAGISKBIN/magiskpolicy 2>/dev/null
chmod 755 $MAGISKBIN/magisk $MAGISKBIN/magiskpolicy 2>/dev/null

# 4b. Ship the helper binaries that Magisk module install needs but that
# the x86/UEFI aropa ramp isn't able to put there on its own: busybox,
# util_functions.sh, magiskinit and magiskboot. These live in /system and
# are staged here so module install works without any manual dodge.
cp /system/bin/busybox $MAGISKBIN/busybox 2>/dev/null
cp /system/etc/magisk/util_functions.sh $MAGISKBIN/util_functions.sh 2>/dev/null
cp /system/bin/magiskinit $MAGISKTMP/magiskinit 2>/dev/null
cp /system/bin/magiskboot $MAGISKTMP/magiskboot 2>/dev/null
chmod 755 $MAGISKBIN/busybox $MAGISKTMP/magiskinit $MAGISKTMP/magiskboot 2>/dev/null
chmod 644 $MAGISKBIN/util_functions.sh 2>/dev/null

mount -t tmpfs -o mode=0755 tmpfs $MAGISKTMP/.magisk/worker 2>/dev/null
touch $MAGISKTMP/.magisk/config $MAGISKTMP/.magisk/live 2>/dev/null

# 5. SELinux patch (live)
if [ -d /sys/fs/selinux ]; then
  $MAGISKTMP/magiskpolicy --live --magisk 2>/dev/null
fi
log "sepolicy patch done"

# 6. Run the post-fs-data stage (reads trusted_cert from /sbin/stub.apk)
$MAGISKTMP/magisk --post-fs-data
log "post-fs-data rc=$?"

chmod o+rx /sbin /sbin/.magisk /sbin/.magisk/device 2>/dev/null
chmod o+rw /sbin/.magisk/device/socket 2>/dev/null
log "socket: $(ls -la /sbin/.magisk/device/socket 2>/dev/null)"
log "=== init.magisk.sh post-fs-data done ==="
exit 0