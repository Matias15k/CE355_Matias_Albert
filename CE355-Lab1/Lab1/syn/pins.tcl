# Pin assignments for tds_monitor_system (DE25-Standard)
# Run from the Quartus Tcl Console with the project open:
#   source pins.tcl

set pins {
    led         CC71
    clk         CH128
    reset_n     BM78

    adc_cs_n    BP22
    adc_dout    CK4
    adc_din     BF32
    adc_sclk    CH4

    hex0[0] BP81  hex0[1] BM81  hex0[2] BM89  hex0[3] BK89
    hex0[4] BH92  hex0[5] BM92  hex0[6] BP92

    hex1[0] CA78  hex1[1] BW78  hex1[2] BU78  hex1[3] BR78
    hex1[4] BU81  hex1[5] BR81  hex1[6] CA89

    hex2[0] BW89  hex2[1] BU92  hex2[2] BR92  hex2[3] BU89
    hex2[4] BR89  hex2[5] CF78  hex2[6] CH78

    hex3[0] CC81  hex3[1] CA81  hex3[2] CH81  hex3[3] CF81
    hex3[4] CF89  hex3[5] CH89  hex3[6] CH92
}

foreach {port pin} $pins {
    set_location_assignment PIN_$pin -to $port
}

export_assignments
puts "Assigned [expr {[llength $pins] / 2}] pins."
