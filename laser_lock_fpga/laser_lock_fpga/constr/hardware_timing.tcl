# Implementation-only, LATE Tcl constraint file. External numbers are a
# PROVISIONAL engineering envelope, not measured board/signoff evidence.
# ADC 0x16=00/0x17=85 nominal lead1.0..1.6ns; board skew +/-0.10ns,
# margin0.05ns. DAC 0x16=00 setup=-.05ns, hold=.65ns, same skew/margin.
set work_pin [get_pins -hier -filter {NAME =~ *u_core/u_clock/u_mmcm/CLKOUT0}]
set work_clk [get_clocks -of_objects $work_pin]
set dci_source [get_pins -hier -filter {NAME =~ *u_tx/u_clock_mmcm/CLKOUT1}]
create_generated_clock -name dac_dci_forwarded -source $dci_source -divide_by 1 [get_ports dac_dci_p]
create_generated_clock -name spi_forwarded -source $work_pin -divide_by 100 [get_ports spi_clk]
set adc_ports [get_ports {adc_data_p[*] adc_data_n[*]}]
set dac_ports [get_ports {dac_data_p[*] dac_data_n[*] dac_frame_p dac_frame_n}]
# Reference ADC transition to the PREVIOUS opposite DCO edge (2ns UI).
set_input_delay -clock adc_dco -min 0.250 $adc_ports
set_input_delay -clock adc_dco -max 1.150 $adc_ports
set_input_delay -clock adc_dco -clock_fall -add_delay -min 0.250 $adc_ports
set_input_delay -clock adc_dco -clock_fall -add_delay -max 1.150 $adc_ports
# Default DDR STA compares opposite edges. Add the 2ns UI to both external
# requirements to model capture of the newly launched word at the next DCI
# edge delayed by the configured MMCM phase, without granting an extra half-cycle to setup.
set_output_delay -clock dac_dci_forwarded -max 2.100 $dac_ports
set_output_delay -clock dac_dci_forwarded -min 1.200 $dac_ports
set_output_delay -clock dac_dci_forwarded -clock_fall -add_delay -max 2.100 $dac_ports
set_output_delay -clock dac_dci_forwarded -clock_fall -add_delay -min 1.200 $dac_ports
set_output_delay -clock spi_forwarded -max 5.000 [get_ports {spi_sdio clk_cs_n adc_cs_n dac_cs_n}]
set_output_delay -clock spi_forwarded -min -5.000 [get_ports {spi_sdio clk_cs_n adc_cs_n dac_cs_n}]
# Mode0 sequencer changes SDIO at SCLK falling edges; CS setup/hold are also
# >=50 work clocks. Unit wire-edge test proves this enable schedule.
# Setup shifts launch back49 work edges; hold requires at least the next
# work edge (actual next permitted transition is 50 clocks after capture).
set_multicycle_path 50 -setup -start -from $work_clk -to [get_clocks spi_forwarded]
set_multicycle_path 50 -hold -start -from $work_clk -to [get_clocks spi_forwarded]
set_output_delay -clock $work_clk -max 2.000 [get_ports {led_ready led_servo}]
set_output_delay -clock $work_clk -min 0.000 [get_ports {led_ready led_servo}]
# Preserve the timing of downstream synchronization stages and datapaths.
# Never use asynchronous clock_groups: they would hide bounded mailbox paths.
set sync_inputs [get_pins -hier -regexp {.*(u_rx/(req_sync1|ack_sync1|config_sync1|source_ready_sync1|overflow_sync1)_reg/D|u_tx/(request_sync|epoch_sync|acknowledge_sync|enable_sync|configured_sync)_reg\[0\]/D|u_health/(adc_sync|tx_sync)_reg\[0\]/D|(tx_lock_sync|tx_active_sync)_reg\[0\]/D)$}]
if {[llength $sync_inputs]==0} { error "Hardware CDC synchronizers were not found" }
set_false_path -to $sync_inputs
set rx_from [get_cells -hier -filter {NAME =~ *u_rx/mailbox_data_reg* && IS_SEQUENTIAL == 1}]
set rx_to [get_cells -hier -filter {NAME =~ *u_rx/adc_data_out_reg* && IS_SEQUENTIAL == 1}]
set_max_delay -datapath_only 20.000 -from $rx_from -to $rx_to
set_bus_skew 10.000 -from $rx_from -to $rx_to
set tx_from [get_cells -hier -filter {(NAME =~ *u_tx/mailbox_code_reg* || NAME =~ *u_tx/mailbox_epoch_reg*) && IS_SEQUENTIAL == 1}]
set tx_to [get_cells -hier -filter {NAME =~ *u_tx/held_code_reg* && IS_SEQUENTIAL == 1}]
set_max_delay -datapath_only 4.000 -from $tx_from -to $tx_to
# Epoch is a held transaction qualifier, separately covered by max_delay above.
# Only the actual16-bit payload is a bus-skew group; qualifier CE logic is not.
set tx_payload [get_cells -hier -filter {NAME =~ *u_tx/mailbox_code_reg* && IS_SEQUENTIAL == 1}]
set_bus_skew 2.000 -from $tx_payload -to $tx_to
set gray_from [get_cells -hier -filter {NAME =~ *u_rx/dropped_gray_source_reg* && IS_SEQUENTIAL == 1}]
set gray_to [get_cells -hier -filter {NAME =~ *u_rx/drop_gray_sync1_reg* && IS_SEQUENTIAL == 1}]
set_max_delay -datapath_only 4.000 -from $gray_from -to $gray_to
set_bus_skew 4.000 -from $gray_from -to $gray_to
# MMCM LOCKED is an asynchronous reset condition, not a sampled data clock.
set lock_sources [get_pins -hier -filter {REF_PIN_NAME == LOCKED}]
set reset_targets [get_pins -hier -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE || REF_PIN_NAME == RST}]
set_false_path -through $lock_sources -to $reset_targets
puts "HARDWARE EXTERNAL TIMING: PROVISIONAL (nominal DCO delay and unmeasured +/-100ps board-skew envelope)."


