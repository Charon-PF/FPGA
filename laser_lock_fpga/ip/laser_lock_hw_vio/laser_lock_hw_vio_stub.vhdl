-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
-- Date        : Wed Oct 14 17:18:45 2026
-- Host        : DESKTOP-R7OLA88 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/Users/V587/Documents/ChatGPT/laser_lock_fpga/ip/laser_lock_hw_vio/laser_lock_hw_vio_stub.vhdl
-- Design      : laser_lock_hw_vio
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcau15p-ffvb676-2-i
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity laser_lock_hw_vio is
  Port ( 
    clk : in STD_LOGIC;
    probe_in0 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe_in1 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe_in2 : in STD_LOGIC_VECTOR ( 7 downto 0 );
    probe_in3 : in STD_LOGIC_VECTOR ( 13 downto 0 );
    probe_in4 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_in5 : in STD_LOGIC_VECTOR ( 3 downto 0 );
    probe_in6 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe_out0 : out STD_LOGIC_VECTOR ( 0 to 0 );
    probe_out1 : out STD_LOGIC_VECTOR ( 7 downto 0 );
    probe_out2 : out STD_LOGIC_VECTOR ( 31 downto 0 );
    probe_out3 : out STD_LOGIC_VECTOR ( 1 downto 0 )
  );

end laser_lock_hw_vio;

architecture stub of laser_lock_hw_vio is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe_in0[31:0],probe_in1[7:0],probe_in2[7:0],probe_in3[13:0],probe_in4[15:0],probe_in5[3:0],probe_in6[31:0],probe_out0[0:0],probe_out1[7:0],probe_out2[31:0],probe_out3[1:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "vio,Vivado 2024.1";
begin
end;
