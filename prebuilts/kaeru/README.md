# Kaeru for evergo (everpal tree)

Prebuilt Kaeru LK image shipped in the ROM for convenience, with a
guarded flash helper. Modeled on `moto-fogorow`'s packaging, adapted
to everpal partitions.

## Files

- `Kaeru.bin` (1606448 bytes,
  sha256 `D91D0A3A23409079F365DBC43C8B2C8798C423B13C41C051863BB53F8D3A6E05`)
  shipped to `/system/etc/kaeru/Kaeru.bin` via `kaeru.mk`.
- `flash-kaeru.sh` guarded fastboot helper (only writes `lk` + `lk2`).
- Version props: `ro.kaeru.version=fixed4`,
  `ro.kaeru.target=evergo-6eb0c11d1-20230516102240`.

## Variant scope

evergo only for now. evergreen/opal variants to be added later.
Do not flash this binary on other variants.

## What this DT integration provides

- Ships the prebuilt in every build (`PRODUCT_COPY_FILES` to
  `$(TARGET_COPY_OUT_SYSTEM)/etc/kaeru/Kaeru.bin`).
- Exposes version/target via `PRODUCT_SYSTEM_PROPERTIES`.
- `flash-kaeru.sh` guards:
  - size + sha256 check (fail closed),
  - fastboot device present,
  - variant check (`evergo`/`everpal`, `--force` to override),
  - explicit `YES` confirmation,
  - writes only `lk` and `lk2`, never `preloader`, `seccfg`,
    `nvram`, `tee`, `boot`, or `vbmeta`.

## Scope (prebuilt-only, read before claiming anti-brick)

`Kaeru.bin` here is an opaque `fixed4` prebuilt (builder claim: all 4 MTK
bypasses, bit-exact Stage1, stock certs intact) – there is no
reproducible source port in this tree. So no payload-level bootloader
behavior (in-bootloader `block flash preloader`, lock-spoofing, custom
`oem` commands, AVB/dm-verity patching) is claimed for this binary.

The anti-brick guarantee in this tree covers the flash *process* only:
`flash-kaeru.sh` writes only `lk`/`lk2` with size/hash, variant, and
explicit-confirmation gates, and never touches `preloader`, `seccfg`,
`nvram`, `tee`, `boot`, or `vbmeta`. A reproducible source port
(`R0rt1z2/kaeru` board + defconfig, UART-verified) remains future work.

## Prerequisites (read before flashing)

- `seccfg` MUST already be unlocked (details below). Flashing a patched
  LK with locked `seccfg` risks a brick. See `R0rt1z2/kaeru` wiki.
- Backup stock `lk`/`lk2` AND `seccfg` first.
- Battery >50%, correct evergo unit, data wiped/backs up (unlock wipes).
- `TARGET_NO_BOOTLOADER := true` and `lk` is not in
  `AB_OTA_PARTITIONS`, so ROM updates never flash the bootloader.
  Manual flash is always required.

### seccfg requirement in detail

`seccfg` is the 8MB `EMMC_USER`, `INVISIBLE`, non-downloadable partition
holding MediaTek's lock state and verified-boot flags. The preloader
reads it before loading LK: when `seccfg` reports unlocked, the preloader
skips signature verification of the next-stage image (this is the same
mechanism `R0rt1z2/fenrir` abuses for `bl2_ext`), so a patched Kaeru LK
is accepted. When locked, the preloader enforces verification, rejects
the patched LK, and the device refuses to boot – stuck with no display,
only an MTK USB port in BROM mode, recoverable solely by reflashing
stock `lk`/`lk2` via SP Flash/mtkclient. Upstream states this plainly:
"Most of these devices require seccfg to be unlocked beforehand;
otherwise, you risk bricking them" (`R0rt1z2/kaeru` releases).

Xiaomi adds a second lock: alongside `seccfg`, its LK consults an
RPMB-backed signature proving an official unlock, and forces "locked"
unless both agree (see upstream `board/xiaomi/board-ruby.c` comments).
Kaeru board ports redirect that getter – but this tree's `Kaeru.bin` is
an opaque prebuilt, so dual-lock handling on evergo is unverified. Treat
`seccfg` unlock as necessary but not proven sufficient: verify after
flashing (below) before relying on the device.

Unlock flow (wipes data, voids warranty, brick risk – author's
responsibility): boot to BROM (auth bypass, Vol keys), then either
`python mtk.py e metadata,userdata,md_udc` + `python mtk.py da seccfg
unlock` (mtkclient), or penumbra `seccfg unlock` (cf. `tanuki.sh`:
reboot to BROM, `seccfg unlock`, then write Kaeru). Known failure mode
from mtkclient reports: unlock appears to succeed but a misconfigured
SEJ/hardware legacy path or a relock function (cf. Kaeru issue #23:
`proinfo`-flag relock, Malta-style force-relock) re-locks on first
reboot – if `fastboot getvar unlocked` does not report `unlocked: yes`
after reboot, stop and restore stock `seccfg` before flashing Kaeru.

## Correct partitions (everpal, not fogorow) – verified

evergo IS Virtual A/B for Android (`boot` and all logical partitions in
`init/fstab.mt6833` carry `slotselect`; `BoardConfig.mk` lists them in
`AB_OTA_PARTITIONS`). The *bootloader* is a separate scheme: raw
redundant pair, no slots. Evidence in this tree:

- `init/fstab.mt6833:15`: `boot` has `slotselect` (A/B).
  `fstab.mt6833:50-51`: `lk` -> `/bootloader`, `lk2` -> `/bootloader2`,
  plain `emmc defaults` – NO `slotselect`, same as `tee1`/`tee2`,
  `scp1`/`scp2`. `update_engine` therefore cannot address them, and
  `BoardConfig.mk:61` sets `TARGET_NO_BOOTLOADER := true` with no `lk`
  in `AB_OTA_PARTITIONS`.
- Stock MT6833 scatter (`MT6833_Android_scatter.txt`, same platform):
  `lk` @ `0x47900000` + `lk2` @ `0x47b00000`, each `0x200000` (2MB),
  `EMMC_USER`, `UPDATE`; `seccfg` is `NONE`/`INVISIBLE` (not flashable
  via SP Flash normal path); `preloader` lives in `EMMC_BOOT1_BOOT2`
  (`SV5_BL_BIN`) – a different region entirely, which is why the flash
  script refuses to go near it. Newer MTK (e.g. MT6897) uses
  `lk_a`/`lk_b`; MT6833 does not.

So on evergo the fastboot names are:

- `/dev/block/by-name/lk` -> `/bootloader`
- `/dev/block/by-name/lk2` -> `/bootloader2`

Size check passes: `Kaeru.bin` is 1606448 bytes < 2097152 (2MB slot),
~490KB spare. Do NOT use `lk_a`/`lk_b` names here. fogorow uses
`lk_a`/`lk_b` because that (Motorola, newer) device has A/B bootloader
slots; everpal does not.

## Install / upgrade / rollback

Fastboot path (upgrades and re-flash):

```sh
./flash-kaeru.sh
# flashes Kaeru.bin to lk, then lk2
fastboot reboot
```

First install from stock without fastboot access needs BROM mode
(`mtkclient` / SP Flash Tool) to write `lk`/`lk2`, then fastboot works
for later upgrades. To roll back, flash your backed-up stock `lk`/`lk2`
the same way.

## Verify

- Script already checks size + sha256 before flashing.
- Before flashing Kaeru: `fastboot getvar unlocked` must report
  `unlocked: yes`. If not, unlock `seccfg` first – do not proceed.
- After flashing, from bootloader: `fastboot getvar version-bootloader`
  (and `kaeru-version` if the payload exposes it, cf. Kaeru issue #23
  log showing `kaeru-version: 1.0.0`).
- In Android: `getprop ro.kaeru.version` / `getprop ro.kaeru.target`
  only shows which prebuilt the ROM shipped, not the flashed LK state.
