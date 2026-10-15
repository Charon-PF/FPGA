# FPGA 激光斜边锁定控制器：E15 内部功能完善版

本目录是真实 Vivado 2024.1 工程，目标器件为 `xcau15p-ffvb676-2-i`（XCAU15P-2FFVB676I）。双击 `laser_lock_fpga.xpr`，或运行 `open_project.cmd`。本工程覆盖功能 1 的数字伺服内部链路；FFT、温控和上位机协议需以后集成。激光器背景已更新为 NKT E15，其实际调谐接口、电压范围和 DAC 电气连接仍待确认。

本机正式工程位置：`C:\Users\V587\Documents\ChatGPT\laser_lock_fpga\laser_lock_fpga.xpr`。请保留全英文路径：已实际发现 Vivado 2024.1 的 ILA 生成器在中文工程路径下无法输出模板文件。压缩包迁移到其它电脑时，也请解压到全英文目录。原 XPR 工程标识 `b554849d7252411794d3ad94fe6d0156` 保留。

## 架构与接口

工程综合顶层为 `laser_lock_board_top.v`，内部实例化 `laser_lock_top.v`。包装顶层将调试总线保留在 FPGA 内供 ILA 观察，避免把全部调试位作为外部 GPIO 而超出器件封装引脚数。主仿真直接验证包装顶层的输入输出链路。

200 MHz 差分参考时钟 → IBUFDS → MMCME4_BASE（1 GHz VCO）→ BUFG → 100 MHz 工作时钟。外部低有效复位和 MMCM 失锁触发复位；复位解除经过三级同步。RTL 数据模块全部使用工作时钟。

当前链路为：14 位有符号 ADC 抽象输入 → 偏置扣除和 16 位限幅 → 可选 8 点滑动平均 → 17 位锁定点校准 → 光学斜率极性、Q16 环路增益和误差限幅 → 固定周期伺服调度 → PI2D 控制器及执行器投影抗积分饱和 → 执行器 Q16 缩放、输出反向和限幅 → 16 位有符号 DAC 抽象并行输出。

`adc_valid && adc_ready` 在 `clk_work_out` 上升沿表示接受一个样本。使能后，预处理链路可每个 100 MHz 工作时钟接受一个样本，控制器 busy 时仍继续接收和滤波。配置请求 `cfg_we`、禁用和复位会拉低 ready；发送端等待 ready 时需保持 data/valid。连续流源与本工作时钟不同步或不能等待 ready 时，需在前端适配层加入 CDC/FIFO、抽取或采样使能。抽象 ADC/config 输入必须与 `clk_work_out` 同步。

`servo_scheduler.v` 使用时钟使能而非新建低速时钟。默认 `servo_period=1000`，即 100 MHz / 1000 = 100 kHz（10 µs）；最小周期为 64 个工作时钟。每个 tick 选择最近的新鲜预处理结果，tick 同周期到来的结果优先。没有新鲜结果或下游忙时，该 tick 跳过并增加 `skipped_ticks`；忙时不会消费缓存，新鲜结果保留并可被更新的数据覆盖。没有新 ADC 数据时，不会重复对旧误差积分。ADC 接收速率与控制更新速率分别计数，不是逐个 ADC 样本都输出一次控制量。

`dac_valid` 为一个工作时钟周期的脉冲，输出数据保持至下一个有效输出或清零。抽象 DAC 码不表示已经形成物理电压。导出工作时钟用于集成，真实板级时钟输出需专用输出缓冲及实际时序约束。

默认上电控制器关闭，输出为 0。寄存器接口为同步写、组合读，暂未实现 AXI/UART/SPI 命令解析器。`cfg_we && cfg_ready` 在上升沿完成写入；`cfg_ack` 随后有效一个周期，非法/只读地址或非法极性值同时置 `cfg_error`。配置请求阻止新 ADC 接收和新伺服事务；已启动的伺服事务完成 DAC 输出后，ready 才允许写入。

每次成功写配置会清除积分、差分历史、滤波与校准流水线、调度缓存及 DAC 输出，防止新旧参数混用；伺服更新/跳过计数也清零，ADC 已接受样本总计数仅在复位时清零。建议先关闭使能、成组写参数、最后使能。当前不提供无扰参数切换。复位恢复全部默认参数。

## 锁定误差与定点算法

锁定点校准先计算 `delta = filtered(adc - adc_offset) - lock_offset`，用 17 位有符号数保留完整差值；关闭偏置校正时直接使用滤波结果。`lock_offset` 即 0x1C 的光强锁定设定值，单位为校正后的 ADC 码，不是伏特。

误差归一化为 `e[k] = saturate16(-LOCK_POLARITY * delta * loop_gain / 65536)`，误差反向位在限幅前额外翻转符号。`LOCK_POLARITY=+1` 表示光学测量随激光频率上升而增加的斜边，`-1` 表示相反斜边；可由顶层参数设置默认值，也可通过 0x48 配置。执行器方向由独立的 `actuator_invert` 设置，需要根据真实实验确认执行器码与激光频率的方向关系。

`loop_gain` 和 `actuator_scale` 为非负 Q16 增益，`1.0=65536`、`0.5=32768`；写入最高位为 1 的值会钳至 `0x7fffffff`。它们分别调整误差增益和执行器输出码幅度，不隐含 V/Hz、A/码等物理换算。

Kp/Ki/Kd/K2 均为 32 位有符号 Q16 系数，实值为寄存器值 / 65536。例如 `1.0=65536`、`0.5=32768`、`-0.5=-32768`。每个实际被调度并接受的伺服误差执行：

```
P = Kp * e[k]
I_candidate = clamp(I_previous + Ki * e[k], +/- integral_limit * 65536)
D = Kd * (e[k] - e[k-1])
D2 = K2 * (e[k] - 2*e[k-1] + e[k-2])
u_candidate = P + I_candidate + D + D2 + output_bias * 65536
```

积分项存储已经乘过 Ki 的结果，为 48 位有符号 Q16；积分限值最大为 2147483647 个控制器整数码。P/I 乘积为 48 位，一阶差分/乘积为 17/49 位，二阶差分/乘积为 18/50 位；合成输出和积分试算扩展到 64 位。离散系数已包含有效控制周期，改变伺服周期需重新整定。

抗积分饱和同时检查控制器限值和映射后的执行器限值：先将候选控制量右移 16 位并限幅，再乘执行器 Q16 增益并应用输出反向，投影到最终执行器码域。如果候选量超出任一限值且积分增量继续推动该方向，则拒绝本次积分增量；反方向增量仍可帮助退出饱和。执行器增益为 0 时拒绝非零积分增量。选定积分后重新求和，输出经过控制器限幅及执行器缩放/反向/限幅。积分硬限幅和积分更新被拒绝有独立状态位。

所有 Q16 转整数采用算术右移，负数向负无穷取整，例如 -0.5 变为 -1。控制器及执行器输出为对称限幅，限值最多为 32767。`output_bias` 位于执行器缩放之前，单位为控制器整数码。

本工程按用户公式保留“P + 单积分 I + 一阶差分 D + 二阶差分 D2”。Vescent 商业伺服器的 PI²D 使用两个积分阶段，不能将本工程的 D2 二阶差分称为该产品的第二积分阶段；本工程不声称与其传递函数等价。官方资料仅用于澄清该算法区别：[Vescent PI²D 官方 PDF](https://vescent-production-media.s3.us-west-2.amazonaws.com/files/67cf311d0dd3d0160e559a99.pdf)。

## 寄存器表

|地址|读写|含义|默认值|
|---|---|---|---|
|0x00|RW|Kp，32 位有符号 Q16|65536（1）|
|0x04|RW|Ki，每次实际伺服更新的积分增益|256（1/256）|
|0x08|RW|Kd，一阶差分增益|0|
|0x0C|RW|K2，二阶差分增益|0|
|0x10|RW|控制器对称输出限值，低 16 位；超过 32767 钳为 32767|16384|
|0x14|RW|bit0 使能、bit1 平均滤波、bit2 误差反向|0|
|0x18|RW|ADC 偏置，低 16 位有符号|0|
|0x1C|RW|光强锁定点 lock_offset，低 16 位有符号|0|
|0x20|RW|控制器输出偏置，低 16 位有符号|0|
|0x24|RW|积分项限值，整数控制码，钳至 0x7fffffff|32767|
|0x28|RO|状态，见下文|实时|
|0x2C|RO|最近被调度的控制误差，符号扩展至 32 位|实时|
|0x30|RO|最近 DAC 输出，符号扩展至 32 位|实时|
|0x34|RO|48 位积分的低 32 位|实时|
|0x38|RO|积分的高 16 位，符号扩展至 32 位|实时|
|0x3C|RO|已接受 ADC 样本计数，32 位自然回卷；仅复位清零|0|
|0x40|RW|伺服更新周期，单位为 100 MHz 时钟周期；最小 64|1000|
|0x44|RW|非负 Q16 误差环路增益 loop_gain|65536（1）|
|0x48|RW|光学斜率极性，仅允许 1（+1）或 0xffffffff（-1）|由 LOCK_POLARITY 决定，默认 +1|
|0x4C|RW|bit0 启用锁定点偏置校正|1|
|0x50|RW|非负 Q16 执行器输出增益 actuator_scale|65536（1）|
|0x54|RW|执行器对称输出限值，低 16 位；超过 32767 钳为 32767|16384|
|0x58|RW|bit0 执行器输出反向|0|
|0x60|RO|已调度伺服更新计数；成功写配置时清零|0|
|0x64|RO|无新鲜数据或下游忙的跳过 tick 计数；成功写配置时清零|0|

状态 bit0=MMCM locked，bit1=servo enable，bit2=servo transaction busy，bit3=控制器或执行器输出限幅，bit4=抗积分饱和拒绝增量，bit5=积分硬限幅，bit6=被调度样本的 ADC 扣偏置限幅，bit7=被调度样本的误差限幅。读取一组对应结果时以 `dac_valid` 为准。连续流状态下要稳定读取积分高低字，先停止发送 ADC、等待最后的新鲜样本处理完并确认 busy=0，避免跨更新撕裂。

非法读地址返回 0。`cfg_we` 持续有效且 ready 连续有效会每周期产生写事务，发送端需在确认写入后撤销请求。非法极性值被拒绝且不清除控制状态。

## 本次修改文件

- 新增 `rtl/lock_point_calibration.v`、`locking_error_normalizer.v`、`servo_scheduler.v`、`laser_actuator_output.v`，分别实现锁定点、误差增益/极性、控制更新节奏和执行器码映射。
- 修改 `rtl/parameter_register.v`、`pi2d_controller.v`、`laser_lock_top.v`、`laser_lock_board_top.v`，增加配置项、执行器投影抗积分饱和、连续预处理与事务握手；更新 ADC/DAC 模块的接口说明。
- 新增 `sim/tb_laser_lock.v` 和 `tb_servo_features.v`，更新 `tb_pi2d_controller.v` 的控制器接口连接；旧主测试保留作历史参考。
- 更新 `scripts/run_sim.tcl`、`run_build.tcl`、`finalize_project.tcl`、`package_project.py`、工程更新/调试帮助脚本和 `run_checks.cmd`，接入新版源文件、仿真、实现报告和交付打包。

## 仿真与验证

当前主仿真顶层为 `sim/tb_laser_lock.v`，采用真实 Vivado MMCM 模型、连续 ADC 输入和独立 64 位 PI2D/执行器算术参考。检查默认 100 kHz 输出节奏、配置握手、执行器限幅导致的积分保护、输出反向及零增益保护，并运行四组正负光学斜率/正负初始偏移的抽象闭环，包含谐振漂移、温漂及确定性噪声，记录末段 RMS 和 DAC 最大步变。

`sim/tb_servo_features.v` 独立检查 17 位锁定点校准、极性和 Q16 增益、连续 valid 流水线及限幅标志对齐、默认/最小调度周期、最新样本优先、无新数据跳过、忙时保留、执行器缩放/反向/限幅和投影抗积分饱和恢复。`sim/tb_pi2d_controller.v` 验证完整 16 位极值、一阶/二阶差分位宽、极值系数、负 Ki、运算中输入和系数变化以及复位取消。

2026-10-14 本轮仿真已通过：主测试接受 2,429,098 个 ADC 样本，逐次校验 2,429 个 DAC 更新；控制器极值测试 59 组通过；功能测试 74 次检查通过。四组闭环数据如下，RMS 单位为 ADC 码，最大步变单位为 DAC 码：

|case|斜率|初始偏移|初段 RMS|末段 RMS|末段最大 DAC 步变|
|---|---|---|---|---|---|
|0|+1|+1200|455.8978|2.2561|4|
|1|+1|-1200|457.2651|2.6420|5|
|2|-1|+1200|456.7147|2.3473|4|
|3|-1|-1200|457.1945|2.5140|5|

`sim/tb_laser_lock_top.v` 保留为 v1 历史测试台，按旧逐样本节奏编写；新版默认主测试使用 `tb_laser_lock`，不要将旧测试台的时限或样本协议当作新版验收标准。

在 Vivado Run Simulation 中对 `tb_laser_lock` 执行 Run All；也可运行 `run_checks.cmd`，依次完成主仿真、控制器测试、功能模块测试、综合和 route。验证数值以 `reports/` 中当前内容为准：`simulation_result.txt`、`controller_result.txt`、`servo_features_result.txt`、`closed_loop_metrics.txt` 和 `closed_loop.csv` 为仿真证据；`build_summary.txt`、`timing_summary.rpt`、综合/实现资源报告、`route_status.rpt` 和 `drc.rpt` 为实现证据。旧版资源和时序数值不作为本次修改结果。

本轮 Vivado 2024.1 综合与 route 已通过，工程 finalize 已确认实现结果为当前版本。最终 `reports/timing_summary.rpt`（min/max）为 WNS=+0.156 ns、WHS=+0.006 ns；6798/6798 个网络完成布线，内部未约束端点数为 0。资源为 3225 LUT、4001 FF、14 DSP、3 BRAM，包含已启用的 6 探针、1024 深度 ILA。占位约束文件与 v1 的 SHA-256 相同，原有 9 个 RTL 模块均保留；本次补充内部功能，不生成 bitstream。

内置 ILA 为 6 个探针、1024 深度，采集误差 16 位、DAC 16 位、积分 48 位、状态 8 位、DAC valid、ADC ready，工作时钟为 100 MHz。实现默认启用，测试台关闭 ILA。只需逻辑验证时，可将 sources_1 顶层 generic 设置为 `ENABLE_ILA=0` 后重新综合。`scripts/create_project.tcl` 用于源文件迁移后首次创建，已有 xpr 时拒绝覆盖。

Windows 构建脚本使用 Vivado 支持的 `-tempDir` 参数，把嵌套调试核项目放到短目录（默认 `C:/laser_lock_temp`）。单独调用 `run_build.tcl` 时，Windows 使用 `-tclargs prepare` / 执行生成的 `runme.bat` / `-tclargs finish` 三步；直接使用 `run_checks.cmd` 即可。临时目录可用 `LASER_LOCK_TEMP` 指定为另一个可写、全英文且不含空格的短路径。

仿真验证上述 RTL 和抽象光学模型，不代表已经得到真实 E15 的捕获范围、锁定带宽、相位裕度或实验性能。当前没有自动寻峰、斜边选择、失锁判断和自动重捕获；需先通过锁定点、输出偏置及真实执行器将工作点放入合适斜边附近。

## 约束与后续硬件适配

`constr/axau15_placeholder.xdc` 建立 200 MHz 输入时钟和暂定工作时钟接口延迟，没有填写 PACKAGE_PIN 或猜测 IOSTANDARD。可用于内部综合及布局布线检查，自动分配的 I/O 不能作为板级引脚映射。NSTD-1/UCIO-1 不降级、不隐藏，不生成可上板 bitstream；真实引脚、电平、接口时序确定后才能补全板级约束。

PZ-FL4322 教程描述 AD9643/AD9516/AD9122，示例平台为 PZ7100-FH，其引脚不能照搬到 AXAU15。AD9643BCPZ-250 是 14 位、最高 250 MSPS 的 LVDS ADC；当前 `adc_interface.v` 接收已经解串并重采样到 100 MHz 域的抽象数据。250 MSPS LVDS 物理层、SPI 初始化、时钟芯片配置、CDC/FIFO 和抽取仍需根据实际连接实现，不能把 100 MHz RTL 预处理速率等同于 ADC 物理采样率。

`laser_actuator_output.v` 为通用码域执行器适配，`dac_interface.v` 为有符号并行码交接；没有实现 AD9122 LVDS/SPI，也没有实现 NKT E15 专用 UART/SPI 协议。E15 的实际调谐接口、方向、带宽、允许电压/电流、DAC 满量程和模拟驱动电路仍需确认，才能确定数字码到物理执行量的映射。

下一轮主要补充 ADC/DAC 物理适配层、时钟/CDC/FIFO、真实引脚和源同步约束，并根据 E15 资料调整执行器增益/偏置/限值、伺服周期及 PI2D 系数。先 Ki/Kd/K2=0、从小 Kp 开始确认负反馈方向，再增加 Ki；导数和二阶差分会放大高频噪声。8 点平均带来的延迟也应纳入实际闭环带宽设计。

## 参考资料

用户提供论文的 Methods: Mechanism of the laser stabilization and tagging 用作光强斜边锁定背景，不用于推导未知执行器电气参数。频谱仪用户手册属于已有拍频功能背景，本工程不集成频谱仪控制。

MMCM 原语和 ILA 方式核对 AMD 官方资料及本机 Vivado 2024.1 原语/IP：

- [AMD UG572 MMCMs](https://docs.amd.com/r/en-US/ug572-ultrascale-clocking/MMCMs)
- [AMD UG912 2024.1 HW_ILA](https://docs.amd.com/r/2024.1-English/ug912-vivado-properties/HW_ILA)
- [Vescent PI²D 官方 PDF](https://vescent-production-media.s3.us-west-2.amazonaws.com/files/67cf311d0dd3d0160e559a99.pdf)
