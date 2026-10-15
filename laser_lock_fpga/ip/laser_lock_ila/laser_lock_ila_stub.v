// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Wed Oct 14 15:15:04 2026
// Host        : DESKTOP-R7OLA88 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/V587/Documents/ChatGPT/laser_lock_fpga/ip/laser_lock_ila/laser_lock_ila_stub.v
// Design      : laser_lock_ila
// Purpose     : Stub declaration of top-level module interface
// Device      : xcau15p-ffvb676-2-i
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2024.1" *)
module laser_lock_ila(clk, probe0, probe1, probe2, probe3, probe4, probe5)
/* synthesis syn_black_box black_box_pad_pin="probe0[15:0],probe1[15:0],probe2[47:0],probe3[7:0],probe4[0:0],probe5[0:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  input [15:0]probe0;
  input [15:0]probe1;
  input [47:0]probe2;
  input [7:0]probe3;
  input [0:0]probe4;
  input [0:0]probe5;
endmodule
