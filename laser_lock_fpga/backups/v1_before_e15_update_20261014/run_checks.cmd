@echo off
setlocal
set "VIVADO_BAT=D:\vivado\Vivado\2024.1\bin\vivado.bat"
if defined XILINX_VIVADO set "VIVADO_BAT=%XILINX_VIVADO%\bin\vivado.bat"
if not exist "%VIVADO_BAT%" exit /b 1
cd /d "%~dp0"
if not exist "reports" mkdir "reports"
if not exist "laser_lock_fpga.xpr" (
  call "%VIVADO_BAT%" -mode batch -source scripts/create_project.tcl -log reports/create_project.log -journal reports/create_project.jou
  if errorlevel 1 exit /b 1
)
call "%VIVADO_BAT%" -mode batch -source scripts/run_sim.tcl -log reports/simulation.log -journal reports/simulation.jou
if errorlevel 1 exit /b 1
call "%VIVADO_BAT%" -mode batch -source scripts/run_build.tcl -log reports/build_prepare.log -journal reports/build_prepare.jou -tclargs prepare
if errorlevel 1 exit /b 1
pushd "laser_lock_fpga.runs\impl_1"
call runme.bat
set "BUILD_RESULT=%errorlevel%"
popd
if not "%BUILD_RESULT%"=="0" exit /b 1
call "%VIVADO_BAT%" -mode batch -source scripts/run_build.tcl -log reports/build.log -journal reports/build.jou -tclargs finish
if errorlevel 1 exit /b 1
