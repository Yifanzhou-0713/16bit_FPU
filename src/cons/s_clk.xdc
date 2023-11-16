# 300Mhz clock
create_clock -period 3.333 -name sysclk -waveform {0.000 1.667} -add [get_ports clk]
set_clock_uncertainty -setup 0.14 [get_ports clk]
set_clock_latency -source -max 0.7 [get_ports clk]
set_clock_latency -max 0.3 [get_ports clk]
set_clock_transition 0.08 [get_ports clk]
set_input_delay -max 0.9 -clock clk [all_inputs]
set_output_delay -max 1.2 -clock clk [all_outputs]

