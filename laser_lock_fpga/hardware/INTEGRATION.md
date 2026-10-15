# AXAU15 + PZ-FL4322 hardware integration

This update adds the FPGA hardware interface layer to the existing `laser_lock_fpga.xpr`. Twelve original RTL files implementing the digital controller and its functional board wrapper remain unchanged. The only edited original RTL file is `clock_manager.v`: an optional input BUFG permits routing the 200 MHz board clock to an adjacent clock-management tile. This option defaults to the original direct input route and is enabled only by the hardware top's `CLOCK_INPUT_BUFG=1` override. The clock frequencies, reset behavior, control equation, numerical formats, gains, scheduler and anti-windup behavior are unchanged. The hardware top connects the existing controller interfaces to the ADC, DAC and JTAG debug controls.

Build and verification results are recorded by the build scripts under `reports/`. Consult the current hardware build summary there for the actual run status; this document does not assert a simulation, implementation or bitstream result.

## Board connections and evidence

The target is AXAU15, `xcau15p-ffvb676-2-i`, with the PZ-FL4322 FMC ADC/DAC card. The pin mapping inherits the existing local AXAU15/PZ-FL4322 hardware project and has been checked against the AXAU15 user manual's FMC package-pin table. This is an inherited engineering mapping, not independent signoff against the PZ-FL4322 card schematic or a verified card revision. See [the complete pin table](../constr/hw_pins.csv) and the registered hardware XDC files.

The board system clock is the 200 MHz differential input on T24/U24. KEY1 on N26 is the active-low reset. The status LEDs use W21 and AC16. ADC data and its DCO enter through differential FMC pins; DAC data, DCI and FRAME leave through differential FMC pins. Each P/N pair must remain matched to the same physical channel.

AXAU15 FMC I/O banks 64 and 65 operate at 1.8 V. The PZ tutorial's LVCMOS25/LVDS_25 constraints target a different carrier and are not copied to AXAU15. AD9516-3 serial input VIH is at least 2.0 V, and its serial output VOH is at least 2.7 V. Direct 1.8 V FPGA SPI therefore has no guaranteed compatibility. The PZ card revision and schematic must confirm suitable level conversion before enabling the SPI pins on connected hardware. Successful FPGA DRC or bitstream generation does not resolve this electrical condition. See [AD9516-3 Rev C, serial-port specifications](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9516_3.pdf#page=12).

## Initialization and clocks

An FPGA SPI sequencer writes 86 initialization entries. It is write-only: completion means all scheduled writes were transmitted, not that the peripheral registers were read back, the PLL was verified locked, or the card accepted every write.

The AD9516 configuration assumes a 50 MHz clock at REF1. R=2, P=8, B=10 and A=0 produce a nominal 2 GHz VCO. The VCO divider then supplies 1 GHz to the channel dividers. This initial hardware profile uses ADC and DAC interfaces at 250 MHz. Register `0x193=0x11` sets the DAC clock channel divider to divide by four, and `0x194=0x00` enables that divider. Register `0x19E=0x11` likewise divides the FPGA-return clock by four; `0x1A1=0x20` bypasses its second divider stage. The intended rates are:

| Clock or stream | Nominal rate |
| --- | --- |
| AD9643 sample clock / returned DCO | 250 MHz |
| AD9122 DAC sample clock | 250 MHz |
| FPGA DAC interface clock returned by the card | 250 MHz |
| Existing digital controller work clock | 100 MHz |

These rates require the assumed 50 MHz reference and the inherited card clock-output routing to be correct. They must be measured on the actual card. AD9122 registers `0x1C`, `0x1D` and `0x1E` are set to `0x01`, bypassing all three half-band interpolation filters for 1x operation. The DAC's factory default full-scale current is preserved; initialization does not raise it to the maximum setting. See [AD9516 clock-divider register definitions](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9516_3.pdf#page=74) and [AD9122 digital datapath descriptions](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9122.pdf#page=25).

## ADC input path

The AD9643 interface uses 14 LVDS data pairs plus the differential DCO in parallel-interleaved mode. IBUFDS inputs and a dedicated receiver MMCM generate a deskewed 250 MHz capture clock delayed by 375 ps relative to the returned DCO (33.75 degrees at 250 MHz); IDDRE1 primitives capture the two ADC channels on opposite clock edges. Receiver reset and ready sequencing wait for this MMCM to lock. This phase is an interface timing choice under the provisional external model, not a measured board calibration. The raw channel sample rate is 250 MSPS. ADC channel selection and sign interpretation belong to the interface adapter; they do not change the existing controller arithmetic.

The interface decimates by 256 before crossing into the existing 100 MHz work domain, giving a nominal 976.5625 ksample/s input stream. This is sample selection for the servo interface, not a claim of alias-free spectral decimation. A handshake mailbox transfers each selected multi-bit sample coherently across the clock domains. The full 250 MSPS stream is not presented as a lossless 100 MHz single-sample bus, and this integration does not implement a new FFT acquisition path.

## DAC output path

The existing controller's signed 16-bit command crosses to the DAC domain through a coherent mailbox. The AD9122 word interface transmits I as that command and Q as zero. I/Q words use ODDRE1 and OBUFDS outputs. The DAC-domain MMCM takes the nominal 250 MHz returned clock (4 ns input period), multiplies by four to a 1 GHz VCO, and divides by four for both data and DCI clocks. DCI is delayed by 625 ps relative to data (56.25 degrees at 250 MHz). FRAME is held low; FIFO initialization is performed by the SPI software sequence.

The MMCM phase setting is a hardware-interface choice that must be checked against the actual DAC eye. The adapter preserves the abstract signed command semantics. It does not implement an NKT E15 protocol or define volts per DAC code, actuator tuning polarity, analog offset, laser tuning range or frequency-per-volt conversion. The PZ-FL4322 analog output circuit and the E15 tuning-input specifications are still required for that analog connection.

## JTAG VIO controls

The VIO hardware-control word's configured initial value is `0`:

| Bit | Meaning |
| --- | --- |
| 0 | Permit ADC/DAC/clock SPI initialization |
| 1 | Permit the DAC output interface |

The digital controller also starts disabled. Enabling the DAC interface does not itself enable the servo. The default state allows the project to configure while hardware output permission and peripheral initialization remain under deliberate JTAG control. KEY1 resets the controller and physical interfaces; it does not reset the VIO output values. Set the hardware-control bits explicitly in Hardware Manager when preparing another initialization or output session.

The VIO register bridge exposes a request toggle, register address, write data and pending/acknowledgment state. A register read requires only setting the address and observing read data while no write is pending; do not toggle the request bit for a read. To make a write, first wait until pending is zero, set the address and data, and then change the request-toggle bit exactly once. Keep the payload stable until completion. Before each subsequent request, wait for pending to return to zero. The last acknowledgment and error are latched for inspection and reset when the next request starts. The bridge waits for the existing controller's configuration-ready handshake; it does not bypass a busy control transaction. While a configuration request is pending, the wrapper gates the DAC adapter to zero so clearing the core cannot leave an old physical output word active. The controller register map remains the one documented in the project README.

## Clock constraints and provisional external timing

The hardware constraints define the 200 MHz board clock, 250 MHz ADC DCO and 250 MHz returned DAC interface clock, with MMCM-derived clocks and the forwarded DAC DCI relationship. The two nominal ADC/DAC clocks come from different external paths and cross through explicit CDC structures. A real 1 ms observation window checks both source rates (about 244 heartbeat transitions each) before declaring clocks healthy. ADC and DAC I/O delays cover both DDR clock edges with minimum and maximum values. CDC paths use their mailbox/synchronizer structure; broad false paths are not a substitute for constraining the source-synchronous ADC/DAC pins.

The current external I/O envelope is explicitly **PROVISIONAL and unmeasured**. It uses nominal ADC data lead of 1.0 to 1.6 ns, assumed board data-to-clock skew of -0.1 to +0.1 ns, and an additional 0.05 ns margin. These values are build assumptions, not measured PCB limits or device guarantees.

For AD9643, `0x16=0x00` leaves DCO uninverted and `0x17=0x85` enables delay code 5. The register formula gives a nominal additional 600 ps; the base data-to-DCO lead is 0.4 to 1.0 ns. Their sum supplies the provisional 1.0 to 1.6 ns model, but the programmable delay does not establish guaranteed full-condition minimum and maximum timing. See [AD9643 timing and register specifications](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9643.pdf#page=8) and [ADI's note on the uncharacterized DCO delay](https://ez.analog.com/data_converters/high-speed_adcs/f/q-a/21871/ad9643-test-modes/71619).

For AD9122, DCI delay register `0x16=0x00` specifies minimum setup of -0.05 ns and hold of 0.65 ns. Data and FRAME must both satisfy the receive window. The forwarded-clock constraint must retain the actual MMCM phase and both DDR relationships. See [AD9122 Rev C, Table 13](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9122.pdf#page=32).

A passing implementation under this provisional envelope shows that the FPGA can meet the stated model. It does not sign off the actual card, connector, trace skew, clock duty cycle, delay variation, jitter or SPI voltage compatibility. Final hardware qualification requires the card schematic/revision, reference-clock confirmation, measured or documented timing bounds, SPI register verification and ADC/DAC test-pattern checks. Until then, the resulting bitstream is a hardware-integration build, not evidence of a tested laser-locking system.

The controller input BUFG routes its 200 MHz reference to the adjacent Bank 66 MMCM through `CLOCK_DEDICATED_ROUTE SAME_CMT_COLUMN`. This constraint keeps the route on dedicated global clock resources, as described in [AMD UG912](https://docs.amd.com/r/en-US/ug912-vivado-properties/CLOCK_DEDICATED_ROUTE). The ADC DCO feeds the Bank 65 MMCM directly for I/O deskew, and the DAC uses Bank 64. No general-fabric clock-routing waiver is used.

The implementation uses `hardware/reference/clock_route_seed.dcp` as an incremental routing reference to preserve the qualified clock-placement geometry across rebuilds. This checkpoint is a placement/routing cache, not a timing waiver or a substitute for the current design. Each resulting implementation still requires current routed setup/hold, recovery/removal and DRC validation before its bitstream is accepted.

## Hardware reset qualification

The clock-health monitor has separate three-stage reset-release synchronizers for the ADC, DAC and 100 MHz work domains. External reset assertion is asynchronous; each domain's counters and monitor state leave reset only on that domain's clock edges. If a source clock is absent, its domain remains in reset until clock edges return. The wrapper's DAC lock and activity status synchronizers use the already qualified work-domain `hw_rst` in their clocked reset branch. These changes qualify hardware reset release without changing the original controller arithmetic or its reset behavior. Recovery/removal closure must be checked in the routed build; functional UNISIM reset/relock simulation alone does not establish those timing margins.

