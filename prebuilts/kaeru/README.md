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

- Bootloader unlocked and `seccfg` unlocked. Flashing a patched LK
  with locked `seccfg` risks a brick. See `R0rt1z2/kaeru` wiki.
- Backup stock `lk`/`lk2` first.
- Battery >50%, correct evergo unit.
- `TARGET_NO_BOOTLOADER := true` and `lk` is not in
  `AB_OTA_PARTITIONS`, so ROM updates never flash the bootloader.
  Manual flash is always required.

## Correct partitions (everpal, not fogorow)

everpal `init/fstab.mt6833` uses raw `lk` + `lk2`:

- `/dev/block/by-name/lk` -> `/bootloader`
- `/dev/block/by-name/lk2` -> `/bootloader2`

Do NOT use `lk_a`/`lk_b` names here. fogorow uses `lk_a`/`lk_b`
because that device has A/B bootloader slots; everpal does not.

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
- From bootloader: `fastboot getvar version-bootloader`
  (and `kaeru-version` if the payload exposes it).
- In Android: `getprop ro.kaeru.version` / `getprop ro.kaeru.target`
  only shows which prebuilt the ROM shipped, not the flashed LK state.
