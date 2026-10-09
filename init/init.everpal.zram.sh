#!/system/bin/sh
# Dynamic ZRAM setup per RAM size

TAG="everpal-zram"

kmsg() {
    echo "[$TAG] $1" > /dev/kmsg 2>/dev/null
    command -v log >/dev/null 2>&1 && log -t "$TAG" "$1" 2>/dev/null
}

w() {
    if [ -w "$1" ]; then
        echo "$2" > "$1" 2>/dev/null
    fi
}

kmsg "applying dynamic RAM architecture..."

# Check total RAM
TOTAL_RAM_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
case "$TOTAL_RAM_KB" in
    ''|*[!0-9]*) TOTAL_RAM_KB=3709888 ;;
esac

if [ "$TOTAL_RAM_KB" -lt 5000000 ]; then
    # 4GB
    ZRAM_SIZE_BYTES=3758096384
    MIN_FREE_KB=24576
    BG_LIMIT=64
elif [ "$TOTAL_RAM_KB" -lt 7000000 ]; then
    # 6GB
    ZRAM_SIZE_BYTES=4509715660
    MIN_FREE_KB=32768
    BG_LIMIT=96
else
    # 8GB
    ZRAM_SIZE_BYTES=6012954214
    MIN_FREE_KB=40960
    BG_LIMIT=128
fi

# App limits
setprop persist.sys.fw.bg_apps_limit "$BG_LIMIT" 2>/dev/null
setprop persist.device_config.activity_manager.max_cached_processes "$BG_LIMIT" 2>/dev/null
setprop persist.device_config.activity_manager.max_phantom_processes $((BG_LIMIT / 2)) 2>/dev/null

# VM tuning
w /proc/sys/vm/swappiness 80
w /proc/sys/vm/vfs_cache_pressure 80
w /proc/sys/vm/watermark_scale_factor 20
w /proc/sys/vm/min_free_kbytes "$MIN_FREE_KB"
w /proc/sys/vm/extra_free_kbytes 0
w /proc/sys/vm/overcommit_memory 1
w /proc/sys/vm/page-cluster 0

# ZRAM setup
if [ -b /dev/block/zram0 ]; then
    CURR_SWAP_KB=$(awk '/zram0/ {print $3}' /proc/swaps 2>/dev/null)
    case "$CURR_SWAP_KB" in
        ''|*[!0-9]*) CURR_SWAP_KB=0 ;;
    esac
    CURR_SWAP_BYTES=$((CURR_SWAP_KB * 1024))
    DIFF=$((ZRAM_SIZE_BYTES - CURR_SWAP_BYTES))
    if [ "$DIFF" -gt 104857600 ] || [ "$DIFF" -lt -104857600 ]; then
        kmsg "reconfiguring ZRAM to $ZRAM_SIZE_BYTES bytes (LZ4, tier ${TOTAL_RAM_KB}kB)..."
        swapoff /dev/block/zram0 2>/dev/null
        w /sys/block/zram0/reset 1
        w /sys/block/zram0/comp_algorithm lz4
        NPROC=$(nproc 2>/dev/null || echo 8)
        case "$NPROC" in
            ''|*[!0-9]*) NPROC=8 ;;
        esac
        w /sys/block/zram0/max_comp_streams "$NPROC"
        w /sys/block/zram0/disksize "$ZRAM_SIZE_BYTES"
        mkswap /dev/block/zram0 2>/dev/null
        swapon -p 32767 /dev/block/zram0 2>/dev/null
    else
        kmsg "ZRAM already correct (${CURR_SWAP_KB}kB), keeping"
    fi
fi

# UFS tuning
for queue in /sys/block/sd*/queue; do
    if [ -d "$queue" ]; then
        w "$queue/read_ahead_kb" 512
        w "$queue/nr_requests" 128
        w "$queue/iostats" 0
    fi
done

kmsg "done (ZRAM=$ZRAM_SIZE_BYTES min_free=$MIN_FREE_KB bg=$BG_LIMIT)"
exit 0
