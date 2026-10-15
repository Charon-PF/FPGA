`timescale 1ns/1ps
module laser_lock_top #(parameter ENABLE_ILA = 0) (
    input wire clk_200m_p, input wire clk_200m_n, input wire rst_n,
    input wire signed [13:0] adc_data_in, input wire adc_valid,
    output wire adc_ready,
    output wire signed [15:0] dac_data_out, output wire dac_valid,
    input wire cfg_we, input wire [7:0] cfg_addr, input wire [31:0] cfg_wdata,
    output wire [31:0] cfg_rdata, output wire cfg_ready,
    output wire cfg_ack, output wire cfg_error,
    output wire clk_work_out, output wire clock_locked,
    output wire signed [31:0] ila_error,
    output wire signed [31:0] ila_control_output,
    output wire signed [47:0] ila_integral,
    output wire [7:0] status
);
    wire clk_work, clk_200MHz, rst, clear;
    clock_manager u_clock(.clk_200m_p(clk_200m_p), .clk_200m_n(clk_200m_n),
        .rst_n(rst_n), .clk_200MHz(clk_200MHz), .clk_work(clk_work),
        .locked(clock_locked), .rst(rst));
    assign clk_work_out = clk_work;
    wire signed [31:0] kp,ki,kd,k2;
    wire [15:0] output_limit;
    wire [31:0] integral_limit;
    wire servo_enable, filter_enable, error_invert;
    wire signed [15:0] adc_offset,setpoint,output_bias;
    reg busy;
    reg [31:0] sample_count;
    // Configuration wins idle-cycle arbitration. Never change gains mid-sample.
    assign cfg_ready = !busy && !rst;
    assign adc_ready = !busy && !rst && !cfg_we && servo_enable;
    wire accepted = adc_valid && adc_ready;
    wire signed [15:0] adc_sample, filtered_sample;
    wire adc_sample_valid, filtered_valid, input_clipped;
    adc_interface u_adc(.clk(clk_work), .rst(rst), .clear(clear),
        .adc_data_in(adc_data_in), .adc_valid(adc_valid), .adc_ready(adc_ready),
        .offset(adc_offset), .sample_out(adc_sample),
        .sample_valid(adc_sample_valid), .input_clipped(input_clipped));
    error_filter u_filter(.clk(clk_work), .rst(rst), .clear(clear),
        .filter_enable(filter_enable), .sample_in(adc_sample),
        .sample_valid(adc_sample_valid), .filtered_out(filtered_sample),
        .filtered_valid(filtered_valid));
    wire signed [17:0] difference = $signed({{2{setpoint[15]}},setpoint}) -
                                  $signed({{2{filtered_sample[15]}},filtered_sample});
    wire signed [17:0] signed_error = error_invert ? -difference : difference;
    (* mark_debug = "true" *) reg signed [15:0] error_signal;
    reg error_valid, error_clipped;
    always @(posedge clk_work) begin
        if (rst || clear) begin
            error_signal <= 0; error_valid <= 0; error_clipped <= 0;
        end else begin
            error_valid <= filtered_valid;
            if (filtered_valid) begin
                error_clipped <= 1'b0;
                if (signed_error > 18'sd32767) begin
                    error_signal <= 16'sd32767; error_clipped <= 1'b1;
                end else if (signed_error < -18'sd32768) begin
                    error_signal <= -16'sd32768; error_clipped <= 1'b1;
                end else error_signal <= signed_error[15:0];
            end
        end
    end
    wire signed [15:0] control_voltage;
    wire control_valid, controller_ready, output_clipped, anti_windup, integral_clipped;
    pi2d_controller u_controller(.clk(clk_work), .rst(rst), .clear(clear),
        .error_signal(error_signal), .in_valid(error_valid), .in_ready(controller_ready),
        .kp(kp), .ki(ki), .kd(kd), .k2(k2), .output_limit(output_limit),
        .integral_limit(integral_limit), .output_bias(output_bias),
        .control_voltage(control_voltage), .control_valid(control_valid),
        .integral_value(ila_integral), .output_clipped(output_clipped),
        .anti_windup(anti_windup), .integral_clipped(integral_clipped));
    dac_interface u_dac(.clk(clk_work), .rst(rst), .clear(clear), .enable(servo_enable),
        .control_in(control_voltage), .control_valid(control_valid),
        .dac_data_out(dac_data_out), .dac_valid(dac_valid));
    always @(posedge clk_work) begin
        if (rst) begin busy <= 0; sample_count <= 0; end
        else begin
            if (clear || dac_valid) busy <= 0;
            else if (accepted) busy <= 1;
            if (accepted) sample_count <= sample_count + 1'b1;
        end
    end
    assign ila_error = {{16{error_signal[15]}},error_signal};
    assign ila_control_output = {{16{dac_data_out[15]}},dac_data_out};
    assign status = {error_clipped,input_clipped,integral_clipped,anti_windup,
                     output_clipped,busy,servo_enable,clock_locked};
    parameter_register u_parameters(.clk(clk_work), .rst(rst),
        .cfg_we(cfg_we), .cfg_ready(cfg_ready), .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata), .cfg_ack(cfg_ack), .cfg_error(cfg_error), .state_clear(clear),
        .kp(kp), .ki(ki), .kd(kd), .k2(k2), .output_limit(output_limit),
        .integral_limit(integral_limit), .servo_enable(servo_enable),
        .filter_enable(filter_enable), .error_invert(error_invert), .adc_offset(adc_offset),
        .setpoint(setpoint), .output_bias(output_bias), .status(status),
        .last_error(error_signal), .last_output(dac_data_out),
        .integral_value(ila_integral), .sample_count(sample_count));
    generate if (ENABLE_ILA != 0) begin : g_ila
        // Built-in Vivado ILA IP is created by scripts/create_project.tcl.
        laser_lock_ila u_ila(.clk(clk_work), .probe0(error_signal),
            .probe1(dac_data_out), .probe2(ila_integral), .probe3(status),
            .probe4(dac_valid), .probe5(adc_ready));
    end endgenerate
endmodule
