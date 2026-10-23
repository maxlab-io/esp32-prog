# esp32-prog

A compact USB‑C programmer for flashing and debugging ESP32‑based boards over UART, designed to connect to the target through a [Tag‑Connect TC2050‑IDC](https://www.tag-connect.com/product/tc2050-idc-tag-connect-2050-idc) cable so the target board needs no programming header at all.

Plug it into USB, press the Tag‑Connect onto the target, and flash with `esptool`, ESP‑IDF, Arduino or PlatformIO. The on‑board auto‑reset circuit puts the ESP32 into download mode automatically, with no BOOT/EN buttons to press.

<img width="1599" height="1095" alt="image" src="https://github.com/user-attachments/assets/94f0e954-b896-424c-8ce8-1820c5b296fb" />

## Features

- **USB‑C** (USB 2.0) with 5.1 kΩ CC pull‑downs, so it works with both C‑to‑C and A‑to‑C cables
- **CP2102** USB‑to‑UART bridge
- **Automatic boot/reset**: the standard Espressif DTR/RTS cross‑coupled circuit, built with AO3400A MOSFETs
- **Switchable target power**: independent 5 V and 3.3 V outputs, each enabled by a DIP switch
- **3.3 V LDO** (ST LD39200, 2 A class) for powering the target
- **Buffered, back‑power‑safe I/O**: SN74LVC1G125 buffers with I<sub>off</sub> protection, so an unpowered target is not parasitically powered through its UART or strapping pins
- **ESD protection** on VBUS, D+ and D‑, plus a ferrite bead on VBUS
- **Status LEDs** for USB power, 5 V out, 3.3 V present, TX and RX activity
- 2‑layer, 55 × 30 mm board, four M3 mounting holes, all components on the top side

## Connector pinout

The target connector **J2** is a 2×5, 2.54 mm pin header that mates with the 0.1" IDC end of a Tag‑Connect TC2050‑IDC cable. The pinout is also printed on the board silkscreen.

| Pin | Silkscreen | Signal | Direction (from programmer) | Connect to on target |
|----:|:----------:|--------|-----------------------------|----------------------|
| 1 | 5V   | +5V     | Power out (switched)     | 5 V / VIN (optional) |
| 2 | 3V3  | +3.3V   | Power out (switched) / I/O reference | 3V3 rail (**always connect**, see below) |
| 3 | GND  | GND     | n/a                      | GND |
| 4 | GND  | GND     | n/a                      | GND |
| 5 | EN   | ESP_EN  | Open‑drain, pulls low    | `EN` / `CHIP_PU` |
| 6 | BT   | ESP_BOOT| Open‑drain, pulls low    | Boot strapping pin (`GPIO0` on ESP32/S2/S3, `GPIO9` on C3/C6/H2) |
| 7 | RX   | RXD     | Input                    | Target `U0TXD` |
| 8 | TX   | TXD     | Output                   | Target `U0RXD` |
| 9 | NC   | n/a     | Not connected            | n/a |
| 10 | NC  | n/a     | Not connected            | n/a |

TX and RX are named from the programmer's point of view, so they cross over to the target's UART.

### Designing the target‑side footprint

- Use the **TC2050** footprint (the legged version, to match the TC2050‑IDC cable's retaining clips) and assign signals using the pin numbers in the table above.
- **Always route pin 2 to the target's 3.3 V rail**, even if the target has its own supply. The TX, EN and BOOT buffers are powered from this pin, so it sets the output logic level and lets the programmer work with self‑powered targets.
- EN and BOOT are only ever pulled low by the programmer, so the target must provide its own pull‑ups (most ESP32 modules and reference designs already have them).

## Using it

### Power switch and LEDs

The two‑position DIP switch **SW1** (labeled `5V` and `3.3V` on the silkscreen) enables the corresponding output on J2.

| Target situation | 5V | 3.3V |
|------------------|:--:|:----:|
| Target has its own power supply | Off | Off |
| Power the target from the programmer, 3.3 V only | Off | On |
| Power the target from the programmer, through its own 5 V regulator | On | Off |

Do not enable an output when the target is already powered from another source. Both outputs pass through SS34 Schottky diodes to prevent back‑feeding into the programmer, so expect a few hundred millivolts of drop under load.

| LED | Color | Meaning |
|-----|-------|---------|
| D5  | Red   | USB power present |
| D4  | Red   | 5 V output enabled |
| D8  | Red   | 3.3 V present on J2 pin 2 (from the programmer or the target) |
| D9  | Blue  | TX activity |
| D10 | Blue  | RX activity |

### Drivers

Linux supports the CP2102 out of the box (`cp210x` driver), and the programmer shows up as `/dev/ttyUSB*`. On Windows or macOS, if no serial port appears, install the [Silicon Labs CP210x VCP driver](https://www.silabs.com/developer-tools/usb-to-uart-bridge-vcp-drivers).

### Flashing

Because DTR and RTS drive the auto‑reset circuit, any tool that uses esptool's default reset sequence works without touching the target:

```sh
# ESP-IDF
idf.py -p /dev/ttyUSB0 flash monitor

# esptool directly: quick sanity check that the target is reachable
esptool.py --port /dev/ttyUSB0 flash_id
```

Arduino IDE and PlatformIO use esptool under the hood, so selecting the programmer's serial port is all that is needed.

## How it works

1. **USB input.** USB‑C VBUS passes through a ferrite bead (BLM21PG221SN1D). RClamp0521P TVS diodes protect VBUS, D+ and D‑.
2. **USB‑UART.** A CP2102‑GMR, powered from VBUS through its internal regulator, provides TXD/RXD plus the DTR and RTS modem lines.
3. **Auto‑reset.** DTR and RTS are buffered and fed to two cross‑coupled AO3400A N‑MOSFETs, the same topology as on Espressif DevKits. Toggling DTR/RTS pulls EN and BOOT low in the sequence that esptool expects.
4. **Target power.** An LD39200 LDO generates 3.3 V from VBUS. Two AO3401A P‑MOSFETs, enabled by SW1, switch VBUS and the 3.3 V rail onto J2 through SS34 Schottky diodes.
5. **Level handling.** The TX, DTR and RTS buffers (SN74LVC1G125) run from J2 pin 2, so they follow the target's supply voltage. When the target is unpowered, their I<sub>off</sub> feature keeps the outputs high‑impedance, so the target is not back‑powered. The RX buffer runs from VBUS so it is always ready to receive.

Design notes and references are included directly on the schematic.

## Opening the design

The project is made with **KiCad 7**.

| File | Contents |
|------|----------|
| `esp32-prog.kicad_pro` | KiCad project |
| `esp32-prog.kicad_sch` | Schematic |
| `esp32-prog.kicad_pcb` | PCB layout |
| `sym-lib-table`, `fp-lib-table` | Project library tables (KIML) |
| `fab/` | Manufacturing outputs (see below) |

Symbols and footprints come from **[KIML](https://github.com/maxlab-io/kiml)**, MAXLAB's KiCad library, in which every part carries its manufacturer part number and supplier links. Footprints are embedded in the PCB and symbols are cached in the schematic, so the project opens without KIML, but to edit or update parts:

1. Clone the library: `git clone https://github.com/maxlab-io/kiml.git`
2. In KiCad, go to **Preferences → Configure Paths** and add a variable named `KIML_ROOT` pointing to the cloned directory.

The project's library tables already reference `${KIML_ROOT}`, so nothing else needs configuring.

## Manufacturing

Ready‑to‑order outputs are in `fab/generic/`:

| File | Contents |
|------|----------|
| `esp32_prog_generic_gerbs.zip` | Gerbers, drill files and drill maps |
| `esp32_prog_generic_bom.zip` | BOM grouped by value, with manufacturer and supplier part numbers |
| `esp32_prog_generic_pos.zip` | Component placement file (KiCad format) |

Board specs: 2 layers, 1.6 mm, 55 × 30 mm. All parts are on the top side, so single‑sided assembly is enough. Hand assembly is possible but fiddly, given 0402 passives, a QFN‑28 and 1 × 1.45 mm USON‑6 buffers.

Every part in the BOM has an MPN and a JLCPCB/LCSC part number, so it can be sourced from JLCPCB/LCSC as is. To order assembly from JLCPCB, rename the BOM and placement columns to match JLCPCB's upload format, and check part rotations in their preview before confirming the order.

### Regenerating the outputs

1. In the PCB editor, export Gerbers and drill files into `fab/generic/gerbs/`, the BOM into `fab/generic/bom/`, and the placement file into `fab/generic/pos/`.
2. Run the packaging script:

   ```sh
   cd fab/generic
   ./fab_pack.sh
   ```

The script re‑creates the zip archives. Loose `.csv` files are ignored by git, so the BOM and placement files are committed only inside the zips.

## Key components

| Ref | Part | Function | JLCPCB # |
|-----|------|----------|----------|
| U2 | Silicon Labs CP2102‑GMR | USB‑to‑UART bridge | C6568 |
| U1 | ST LD39200DPUR | 3.3 V LDO | C880590 |
| U3–U6 | TI SN74LVC1G125DRYR | Buffers with I<sub>off</sub> | C527546 |
| Q1, Q2 | AO3401A | Power switches (P‑MOSFET) | C15127 |
| Q3, Q4 | AO3400A | Auto‑reset (N‑MOSFET) | C20917 |
| D6, D7 | SS34 | Back‑feed protection | C266553 |
| D1–D3 | RCLAMP0521P‑N | USB ESD protection | C316043 |
| J1 | HRO TYPE‑C‑31‑M‑12 | USB‑C receptacle | C165948 |
| J2 | HCTL PZ254‑2‑05‑Z‑8.5 | 2×5 2.54 mm header | C2894966 (LCSC) |
| SW1 | Yuandi TP‑02 | Power‑select DIP switch | C559165 |

The complete BOM is in `fab/generic/esp32_prog_generic_bom.zip`.

## License

<!-- TODO: choose a license, e.g. CERN-OHL-P/S/W for hardware, and add a LICENSE file. -->

No license has been chosen for this project yet.

---

Designed by [MAXLAB.IO](https://github.com/maxlab-io).
