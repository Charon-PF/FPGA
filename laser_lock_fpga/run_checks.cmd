@echo off
setlocal
set "VIVADO_BAT=D:\vivado\Vivado\2024.1\bin\vivado.bat"
if defined XILINX_VIVADO set "VIVADO_BAT=%XILINX_VIVADO%\bin\vivado.bat"
if not exist "%VIVADO_BAT%" exit /b 1
cd /d "%~dp0"
if not exist "laser_lock_fpga.xpr" exit /b 1
if not exist "reports" mkdir "reports"
call "%VIVADO_BAT%" -mode batch -source scripts/run_hw_sim.tcl -log reports/hardware_simulation.log -journal reports/hardware_simulation.jou
if errorlevel 1 exit /b 1
call "%VIVADO_BAT%" -mode batch -source scripts/run_hardware.tcl -log reports/hardware_prepare.log -journal reports/hardware_prepare.jou -tclargs prepare
if errorlevel 1 exit /b 1
pushd "laser_lock_fpga.runs\impl_1"
call runme.bat
set "BUILD_RESULT=%errorlevel%"
popd
if not "%BUILD_RESULT%"=="0" exit /b 1
call "%VIVADO_BAT%" -mode batch -source scripts/run_hardware.tcl -log reports/hardware_build.log -journal reports/hardware_build.jou -tclargs finish
if errorlevel 1 exit /b 1
call "%VIVADO_BAT%" -mode batch -source scripts/finalize_project.tcl -log reports/finalize.log -journal reports/finalize.jou
if errorlevel 1 exit /b 1
