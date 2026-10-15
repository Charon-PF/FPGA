@echo off
setlocal
set "VIVADO_BAT=D:\vivado\Vivado\2024.1\bin\vivado.bat"
if defined XILINX_VIVADO set "VIVADO_BAT=%XILINX_VIVADO%\bin\vivado.bat"
if not exist "%VIVADO_BAT%" (
  echo Vivado 2024.1 not found. Open laser_lock_fpga.xpr from Vivado.
  pause
  exit /b 1
)
call "%VIVADO_BAT%" -mode gui "%~dp0laser_lock_fpga.xpr"
