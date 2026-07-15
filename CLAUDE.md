# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ZMK firmware config for a Charybdis-style 35-key (3×10 + 5 thumb) wireless split keyboard sourced from AliExpress. Right half is the BLE central and hosts a PMW3610 optical trackball. Both halves have WS2812 RGB underglow. Controllers are nice!nano v2.

## Repository structure

```
config/
  west.yml                        # ZMK + external driver dependencies (pinned to ZMK v0.3)
  charybdis.keymap                # Keymap (4 layers; edit this for layout changes)
  charybdis.conf                  # Global Kconfig flags (RGB, battery, keyboard name)
  boards/shields/charybdis/       # Custom shield definition
    charybdis.dtsi                # Shared matrix, encoder, and sensor nodes
    charybdis_left.overlay        # Left: column GPIOs + RGB SPI (29 LEDs, SPI3/P0.10)
    charybdis_right.overlay       # Right: column GPIOs + PMW3610 SPI + RGB SPI (27 LEDs)
    charybdis_right.conf          # Right-only Kconfig: PMW3610 driver, mouse input, SPI
    Kconfig.defconfig             # Right = BLE central; both halves = split enabled
    Kconfig.shield                # Shield selection symbols
build.yaml                        # CI matrix: charybdis_left, charybdis_right, settings_reset
.github/workflows/build.yml       # Delegates entirely to zmkfirmware reusable workflow
```

## Building locally

### Prerequisites

Install the Zephyr SDK and `west` following the [ZMK local toolchain guide](https://zmk.dev/docs/development/local-toolchain/setup). The Zephyr SDK version must match what ZMK v0.3 expects.

### First-time workspace setup

```bash
# From the repo root (where config/ lives)
west init -l config
west update
west zephyr-export
```

### Build commands

```bash
# Left half
west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=charybdis_left -DZMK_CONFIG="$(pwd)/config"

# Right half (central, with trackball)
west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=charybdis_right -DZMK_CONFIG="$(pwd)/config"

# settings_reset (use to clear BLE pairing when re-pairing)
west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=settings_reset -DZMK_CONFIG="$(pwd)/config"
```

Output is `build/zephyr/zmk.uf2`. Copy to the nice!nano drive in bootloader mode.

### Incremental builds

After editing only `.keymap` or `.conf` files, `west build` without `-p` is sufficient (no full clean needed).

For shield hardware changes (`.overlay`, `.dtsi`), force a pristine build:

```bash
west build -p always -s zmk/app -b nice_nano_v2 -- -DSHIELD=charybdis_left -DZMK_CONFIG="$(pwd)/config"
```

## Key architecture notes

- **Split roles**: Left is peripheral, right is central (defined in `Kconfig.defconfig`). Always flash the right half first when re-pairing.
- **PMW3610 driver**: External dependency from `DoctorWangWang/zmk-pmw3610-driver` (pinned to `main` in `west.yml`). CPI, orientation, snipe/scroll layers, and polling rate are all configured in `charybdis_right.conf`.
- **Trackball scroll**: Layer 1 activates scroll mode (set via `scroll-layers = <1>` in the right overlay's trackball node).
- **RGB**: Both halves use SPI3 on P0.10 for WS2812. Left has 29 LEDs, right has 27. RGB behavior (effects, colors) is controlled by macros in `charybdis.keymap`.
- **Keymap layout**: 35 keys — 3 rows × 5 columns per half, plus 3 thumb keys left / 2 thumb keys right. The matrix transform in `charybdis.dtsi` reflects this asymmetric thumb cluster.
- **ZMK version**: Pinned to `v0.3` tag. Before updating the revision in `west.yml`, check for breaking API changes in ZMK's changelog (particularly pointing/mouse and RGB APIs changed significantly between versions).

## CI

GitHub Actions uses the upstream reusable workflow — no custom build logic. Pushes and PRs trigger automatic builds. Download artifacts from the Actions tab to get `.uf2` files without a local toolchain.
