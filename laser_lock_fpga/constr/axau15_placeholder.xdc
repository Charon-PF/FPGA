# INTERNAL PROTOTYPE ONLY. No PACKAGE_PIN or assumed board voltage is supplied.
# Replace this file with the actual AXAU15 schematic/FMC mapping before hardware.
create_clock -name clk_200MHz -period 5.000 [get_ports clk_200m_p]

# Abstract ADC/configuration ports are synchronous to the exported 100 MHz clock.
# These provisional min/max delays make internal implementation timing reviewable.
# They are interface assumptions, NOT measurements of external ADC/DAC timing.
set work_clk [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *u_mmcm/CLKOUT0}]]
set in_bus [get_ports {adc_data_in[*] adc_valid cfg_we cfg_addr[*] cfg_wdata[*]}]
set out_bus [get_ports {adc_ready dac_data_out[*] dac_valid cfg_rdata[*] cfg_ready cfg_ack cfg_error status[*]}]
set_input_delay -clock $work_clk -max 2.000 $in_bus
set_input_delay -clock $work_clk -min 0.000 $in_bus
set_output_delay -clock $work_clk -max 2.000 $out_bus
set_output_delay -clock $work_clk -min 0.000 $out_bus
# Asynchronous external reset only. Do not false-path the controller data path.
set_false_path -from [get_ports rst_n]
# MMCM lock is an asynchronous status output.
set_false_path -to [get_ports clock_locked]

# Example only; intentionally commented, board pins must be verified:
# set_property IOSTANDARD LVDS [get_ports {clk_200m_p clk_200m_n}]
# set_property PACKAGE_PIN <verified_clock_p> [get_ports clk_200m_p]
# set_property PACKAGE_PIN <verified_clock_n> [get_ports clk_200m_n]
# set_property PACKAGE_PIN <verified_reset> [get_ports rst_n]
# set_property IOSTANDARD <verified_bank_voltage> [get_ports rst_n]
# NSTD-1/UCIO-1 remain enabled. Bitstream generation requires real constraints.
