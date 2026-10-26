vlib work

vcom -2008 ../vhdl/audio_package.vhd
vcom -2008 ../vhdl/metronome.vhd
vcom -2008 ../vhdl/audio_pulse.vhd
vcom -2008 ../vhdl/audio_mixer.vhd
vcom -2008 ../vhdl/drum_voice.vhd
vcom -2008 ../vhdl/drum_pad.vhd
vcom -2008 ../vhdl/drum_pad_tb.vhd

vsim -voptargs=+acc drum_pad_tb

add wave -group "TESTBENCH" sim:/drum_pad_tb/*
add wave -group "DRUM PAD" sim:/drum_pad_tb/dut/*
add wave -group "AUDIO PULSE" sim:/drum_pad_tb/dut/audio_pulse_inst/*
add wave -group "AUDIO MIXER" sim:/drum_pad_tb/dut/audio_mixer_inst/*
add wave -group "METRONOME" sim:/drum_pad_tb/dut/metronome_inst/*
add wave -group "KICK VOICE" sim:/drum_pad_tb/dut/gen_voices(0)/voice_inst/*
add wave -group "SNARE VOICE" sim:/drum_pad_tb/dut/gen_voices(1)/voice_inst/*
add wave -group "HIHAT VOICE" sim:/drum_pad_tb/dut/gen_voices(2)/voice_inst/*
add wave -group "CRASH VOICE" sim:/drum_pad_tb/dut/gen_voices(3)/voice_inst/*
add wave -group "CLICK VOICE" sim:/drum_pad_tb/dut/gen_voices(4)/voice_inst/*

add wave -radix decimal -format analog-step -height 120 -min -32768 -max 32767 sim:/drum_pad_tb/audio_out

run -all
