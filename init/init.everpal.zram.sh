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

parse_size() {
    _v="$1"
    case "$_v" in
        '') return 1 ;;
    esac
    case "$_v" in
        *G|*g) _n="${_v%G}"; _n="${_n%g}"; _m=1073741824 ;;
        *M|*m) _n="${_v%M}"; _n="${_n%m}"; _m=1048576 ;;
        *K|*k) _n="${_v%K}"; _n="${_n%k}"; _m=1024 ;;
        *) _n="$_v"; _m=1 ;;
    esac
    case "$_n" in
        ''|*[!0-9]*) return 1 ;;
    esac
    PARSED_SIZE=$((_n * _m))
    case "$PARSED_SIZE" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$PARSED_SIZE" -lt 268435456 ] || [ "$PARSED_SIZE" -gt 8589934592 ]; then
        return 1
    fi
    return 0
}

kmsg "applying dynamic RAM architecture..."

# Check total RAM
TOTAL_RAM_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
case "$TOTAL_RAM_KB" in
    ''|*[!0-9]*) TOTAL_RAM_KB=3709888 ;;
esac

if [ "$TOTAL_RAM_KB" -lt 5000000 ]; then
    # 4GB
    ZRAM_AUTO_BYTES=3758096384
    MIN_FREE_KB=24576
    BG_LIMIT=64
elif [ "$TOTAL_RAM_KB" -lt 7000000 ]; then
    # 6GB
    ZRAM_AUTO_BYTES=4509715660
    MIN_FREE_KB=32768
    BG_LIMIT=96
else
    # 8GB
    ZRAM_AUTO_BYTES=6012954214
    MIN_FREE_KB=40960
    BG_LIMIT=128
fi

ZRAM_SIZE_BYTES="$ZRAM_AUTO_BYTES"
USER_OVERRIDE=0
MANUAL=0

if command -v getprop >/dev/null 2>&1; then
    for _p in persist.vendor.zram.manual persist.sys.zram.manual; do
        _mv=$(getprop "$_p" 2>/dev/null)
        case "$_mv" in
            1|true|yes|y|on) MANUAL=1 ;;
        esac
    done
    if [ "$MANUAL" -eq 0 ]; then
        for _p in persist.vendor.zram.size persist.sys.zram.size; do
            _sv=$(getprop "$_p" 2>/dev/null)
            if [ -n "$_sv" ]; then
                if parse_size "$_sv"; then
                    ZRAM_SIZE_BYTES="$PARSED_SIZE"
                    USER_OVERRIDE=1
                    kmsg "user override $_p=$_sv -> $ZRAM_SIZE_BYTES bytes, keeping user value"
                    break
                else
                    kmsg "ignoring invalid $_p=$_sv, using auto size"
                fi
            fi
        done
    else
        kmsg "manual mode (zram.manual=1), keeping ROM/Kernel Manager ZRAM untouched"
    fi
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
if [ "$MANUAL" -eq 0 ] && [ -b /dev/block/zram0 ]; then
    CURR_SWAP_KB=$(awk '/zram0/ {print $3}' /proc/swaps 2>/dev/null)
    case "$CURR_SWAP_KB" in
        ''|*[!0-9]*) CURR_SWAP_KB=0 ;;
    esac
    CURR_SWAP_BYTES=$((CURR_SWAP_KB * 1024))
    DIFF=$((ZRAM_SIZE_BYTES - CURR_SWAP_BYTES))
    if [ "$DIFF" -gt 104857600 ] || [ "$DIFF" -lt -104857600 ]; then
        if [ "$USER_OVERRIDE" -eq 1 ]; then
            kmsg "applying user ZRAM $ZRAM_SIZE_BYTES bytes (auto would be $ZRAM_AUTO_BYTES)..."
        else
            kmsg "reconfiguring ZRAM to $ZRAM_SIZE_BYTES bytes (LZ4, tier ${TOTAL_RAM_KB}kB)..."
        fi
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
