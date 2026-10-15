`timescale 1ns/1ps
// AXAU15 + FL4322 physical wrapper. Existing digital control is unmodified.
// All configuration/debug buses stay internal; VIO supplies register requests.
module laser_lock_hw_top #(parameter ENABLE_ILA=1,parameter ENABLE_VIO=1) (
    input wire sys_clk_p,input wire sys_clk_n,input wire key_reset_n,
    input wire adc_dco_p,input wire adc_dco_n,
    input wire [13:0] adc_data_p,input wire [13:0] adc_data_n,
    input wire fpga_clk_p,input wire fpga_clk_n,
    output wire [15:0] dac_data_p,output wire [15:0] dac_data_n,
    output wire dac_dci_p,output wire dac_dci_n,output wire dac_frame_p,output wire dac_frame_n,
    output wire spi_clk,output wire spi_sdio,output wire clk_cs_n,output wire adc_cs_n,output wire dac_cs_n,
    output wire led_ready,output wire led_servo
);
    wire clk_work,core_locked;
    wire hw_reset_n=key_reset_n && core_locked;
    (* ASYNC_REG="TRUE" *) reg [2:0] hw_reset_pipe;
    always @(posedge clk_work or negedge hw_reset_n)begin
        if(!hw_reset_n)hw_reset_pipe<=3'b111;
        else hw_reset_pipe<={hw_reset_pipe[1:0],1'b0};
    end
    wire hw_rst=hw_reset_pipe[2];
    wire signed [13:0] adc_sample;
    wire adc_valid,adc_ready;
    wire signed [15:0] dac_command;
    wire dac_valid;
    wire [31:0] cfg_rdata;
    wire cfg_ready,cfg_ack,cfg_error;
    wire [7:0] status;
    wire signed [31:0] debug_error,debug_output;
    wire signed [47:0] debug_integral;
    wire request_toggle;
    wire [7:0] request_addr;
    wire [31:0] request_data;
    wire [1:0] hw_control; // bit0 init; bit1 permit DAC samples. Both default zero.
    reg request_seen=0,cfg_pending=0,last_cfg_ack=0,last_cfg_error=0;
    reg [7:0] cfg_addr_latched=0;
    reg [31:0] cfg_data_latched=0;
    always @(posedge clk_work)begin
        if(hw_rst)begin request_seen<=request_toggle;cfg_pending<=0;cfg_addr_latched<=0;cfg_data_latched<=0;last_cfg_ack<=0;last_cfg_error<=0;end
        else begin
            if(cfg_ack)begin last_cfg_ack<=1;last_cfg_error<=cfg_error;end
            if(cfg_pending)begin if(cfg_ready)cfg_pending<=0;end
            else if(request_toggle!=request_seen)begin
                request_seen<=request_toggle;cfg_pending<=1;last_cfg_ack<=0;last_cfg_error<=0;
                cfg_addr_latched<=request_addr;cfg_data_latched<=request_data;
            end
        end
    end
    laser_lock_top #(.ENABLE_ILA(ENABLE_ILA)) u_core(
        .clk_200m_p(sys_clk_p),.clk_200m_n(sys_clk_n),.rst_n(key_reset_n),
        .adc_data_in(adc_sample),.adc_valid(adc_valid),.adc_ready(adc_ready),
        .dac_data_out(dac_command),.dac_valid(dac_valid),
        .cfg_we(cfg_pending),.cfg_addr(cfg_pending ? cfg_addr_latched:request_addr),.cfg_wdata(cfg_data_latched),
        .cfg_rdata(cfg_rdata),.cfg_ready(cfg_ready),.cfg_ack(cfg_ack),.cfg_error(cfg_error),
        .clk_work_out(clk_work),.clock_locked(core_locked),.status(status),
        .ila_error(debug_error),.ila_control_output(debug_output),.ila_integral(debug_integral));
    // Only the physical wrapper selects global routing to the controller CMT.
    // The generic servo top and all its control modules keep their defaults.
    defparam u_core.u_clock.CLOCK_INPUT_BUFG=1;
    wire sequence_done;
    wire [7:0] writes_sent;
    hw_fl4322_init u_init(.clk(clk_work),.rst(hw_rst),.init_enable(hw_control[0]),
        .spi_clk(spi_clk),.spi_sdio(spi_sdio),.clk_cs_n(clk_cs_n),.adc_cs_n(adc_cs_n),.dac_cs_n(dac_cs_n),
        .sequence_done(sequence_done),.writes_sent(writes_sent));
    wire adc_clk,tx_clk,rx_ready,overflow_sticky,tx_locked,tx_active,control_ready,clocks_ok;
    wire [13:0] raw_a,raw_b;
    wire [31:0] dropped_count;
    hw_ad9643_rx #(.DECIMATION(256)) u_rx(.rst_n(hw_reset_n),.clk_work(clk_work),
        .config_done(sequence_done),.adc_dco_p(adc_dco_p),.adc_dco_n(adc_dco_n),
        .adc_data_p(adc_data_p),.adc_data_n(adc_data_n),.adc_ready(adc_ready),
        .adc_data_out(adc_sample),.adc_valid(adc_valid),.adc_clk_out(adc_clk),
        .raw_data_a(raw_a),.raw_data_b(raw_b),.rx_ready(rx_ready),
        .overflow_sticky(overflow_sticky),.dropped_count(dropped_count));
    // If the core is disabled/configured, its DAC register clears to zero without
    // dac_valid. Gate the physical adapter with core enable so no old code persists.
    hw_ad9122_tx #(.INPUT_CLK_PERIOD_NS(4.0),.MMCM_MULT_F(4.0),.OUTPUT_DIVIDE(4),.DCI_DELAY_PS(625.0)) u_tx(.clk_work(clk_work),.rst_n(hw_reset_n),.fpga_clk_p(fpga_clk_p),.fpga_clk_n(fpga_clk_n),
        .control_in(dac_command),.control_valid(dac_valid),
        .tx_enable(hw_control[1] && status[1] && clocks_ok && rx_ready && !hw_rst && !cfg_pending),
        .config_done(sequence_done),.control_ready(control_ready),.tx_clk_out(tx_clk),
        .tx_clock_locked(tx_locked),.tx_active(tx_active),
        .dac_data_p(dac_data_p),.dac_data_n(dac_data_n),.dac_dci_p(dac_dci_p),.dac_dci_n(dac_dci_n),
        .dac_frame_p(dac_frame_p),.dac_frame_n(dac_frame_n));
    wire [9:0] adc_beats,tx_beats;
    hw_clock_health u_health(.rst_n(hw_reset_n),.clk_work(clk_work),.adc_clk(adc_clk),.tx_clk(tx_clk),
        .enable(sequence_done),.clocks_ok(clocks_ok),.adc_beats(adc_beats),.tx_beats(tx_beats));
    (* ASYNC_REG="TRUE" *) reg [1:0] tx_lock_sync,tx_active_sync;
    // Status synchronizers release with the already qualified work-domain reset.
    always @(posedge clk_work)begin
        if(hw_rst)begin tx_lock_sync<=0;tx_active_sync<=0;end
        else begin tx_lock_sync<={tx_lock_sync[0],tx_locked};tx_active_sync<={tx_active_sync[0],tx_active};end
    end
    assign led_ready=sequence_done && rx_ready && tx_lock_sync[1] && clocks_ok;
    assign led_servo=status[1] && tx_active_sync[1];
    wire [7:0] hw_status={overflow_sticky,control_ready,hw_rst,tx_active_sync[1],clocks_ok,
        tx_lock_sync[1],rx_ready,sequence_done};
    generate if(ENABLE_VIO!=0)begin:g_vio
        laser_lock_hw_vio u_vio(.clk(clk_work),
            .probe_in0(cfg_rdata),.probe_in1(status),.probe_in2(hw_status),
            .probe_in3(adc_sample),.probe_in4(dac_command),
            .probe_in5({last_cfg_error,last_cfg_ack,cfg_pending,request_seen}),.probe_in6(dropped_count),
            .probe_out0(request_toggle),.probe_out1(request_addr),.probe_out2(request_data),.probe_out3(hw_control));
    end else begin:g_no_vio
        assign request_toggle=0;assign request_addr=0;assign request_data=0;assign hw_control=0;
    end endgenerate
endmodule




