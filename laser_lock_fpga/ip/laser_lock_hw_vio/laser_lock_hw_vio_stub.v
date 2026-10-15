// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Wed Oct 14 17:18:45 2026
// Host        : DESKTOP-R7OLA88 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/V587/Documents/ChatGPT/laser_lock_fpga/ip/laser_lock_hw_vio/laser_lock_hw_vio_stub.v
// Design      : laser_lock_hw_vio
// Purpose     : Stub declaration of top-level module interface
// Device      : xcau15p-ffvb676-2-i
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2024.1" *)
module laser_lock_hw_vio(clk, probe_in0, probe_in1, probe_in2, probe_in3, 
  probe_in4, probe_in5, probe_in6, probe_out0, probe_out1, probe_out2, probe_out3)
/* synthesis syn_black_box black_box_pad_pin="probe_in0[31:0],probe_in1[7:0],probe_in2[7:0],probe_in3[13:0],probe_in4[15:0],probe_in5[3:0],probe_in6[31:0],probe_out0[0:0],probe_out1[7:0],probe_out2[31:0],probe_out3[1:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  input [31:0]probe_in0;
  input [7:0]probe_in1;
  input [7:0]probe_in2;
  input [13:0]probe_in3;
  input [15:0]probe_in4;
  input [3:0]probe_in5;
  input [31:0]probe_in6;
  output [0:0]probe_out0;
  output [7:0]probe_out1;
  output [31:0]probe_out2;
  output [1:0]probe_out3;
endmodule
