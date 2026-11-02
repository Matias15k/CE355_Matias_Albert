vlib work

vcom -2008 ../vhdl/mandel_pkg.vhd
vcom -2008 ../vhdl/mandel_engine.vhd
vcom -2008 ../vhdl/mandel_engine_bank.vhd
vcom -2008 ../vhdl/viewport.vhd
vcom -2008 ../vhdl/mandelbrot.vhd
vcom -2008 ../vhdl/mandelbrot_tb.vhd

vsim -voptargs=+acc mandelbrot_tb

add wave -group "TESTBENCH"   sim:/mandelbrot_tb/*
add wave -group "MANDELBROT"  sim:/mandelbrot_tb/dut/*
add wave -group "VIEWPORT"    sim:/mandelbrot_tb/dut/u_viewport/*
add wave -group "ENGINE BANK" sim:/mandelbrot_tb/dut/u_engine_bank/*
add wave -group "ENGINE 0"    sim:/mandelbrot_tb/dut/u_engine_bank/gen_engines(0)/u_engine/*

run -all
