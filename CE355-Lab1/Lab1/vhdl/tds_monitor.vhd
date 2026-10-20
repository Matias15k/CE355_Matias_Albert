library ieee;
use ieee.std_logic_1164.all;

------------------------------------------------------------------
-- Entity Declaration: TDS Monitor
--
-- Monitors the TDS (Total Dissolved Solids) level using an ADC and 
-- displays it on 7-segment displays.
-- 
--        ADC (12-bit)
--            |
--            v
--        +------------------+
--        |   TDS Converter  |---------------------> LED
--        |   ADC → TDS ppm  |                      Threshold
--        +------------------+
--            |
--            | TDS Value (8-bit)
--            v
--        +------------------+
--        | Binary-to-BCD    |
--        +------------------+
--            |
--            +----------+----------+----------+
--            |          |          |          |
--            v          v          v          v
--         Digit 0    Digit 1    Digit 2    Digit 3
--         Decoder    Decoder    Decoder    Decoder
--            |          |          |          |
--            v          v          v          v
--           HEX0       HEX1       HEX2       HEX3
--           Ones       Tens     Hundreds   Thousands
--
------------------------------------------------------------------
entity tds_monitor is
    port(
        adc     : in  std_logic_vector(11 downto 0);

        hex0    : out std_logic_vector(6 downto 0);
        hex1    : out std_logic_vector(6 downto 0);
        hex2    : out std_logic_vector(6 downto 0);
        hex3    : out std_logic_vector(6 downto 0);
        led     : out std_logic
    );
end entity tds_monitor;

------------------------------------------------------------------
-- Architecture Declaration: Structural
------------------------------------------------------------------
architecture structural of tds_monitor is

    ----------------------------------------------------------------
    -- Signal declarations
    --
    -- TODO: Add signal declarations 
    ----------------------------------------------------------------

    -- 5.2
    signal tds : std_logic_vector(11 downto 0);
    signal digit0 : std_logic_vector(3 downto 0);
    signal digit1 : std_logic_vector(3 downto 0);
    signal digit2 : std_logic_vector(3 downto 0);
    signal digit3 : std_logic_vector(3 downto 0);

    ----------------------------------------------------------------
    -- Component declarations
    --
    -- TODO: Add component declarations
    ----------------------------------------------------------------

    -- 5.1
    component digit_display is
        port(
        din : in std_logic_vector(3 downto 0);
        dout : out std_logic_vector(6 downto 0)
        );
    end component digit_display;

    component bcd is
        port(
        bin : in std_logic_vector(11 downto 0);
        thousands : out std_logic_vector(3 downto 0);
        hundreds : out std_logic_vector(3 downto 0);
        tens : out std_logic_vector(3 downto 0);
        ones : out std_logic_vector(3 downto 0)
        );
    end component bcd;

    component tds_converter is
        generic(
        TDS_THRESHOLD : integer := 500
        );
        port(
        adc : in std_logic_vector(11 downto 0);
        tds : out std_logic_vector(11 downto 0);
        threshold : out std_logic
        );
    end component tds_converter;

begin

    ----------------------------------------------------------------
    -- Component Instantiations
    ----------------------------------------------------------------

    -- 5.3
    tds_converter_inst : tds_converter
        generic map(
            TDS_THRESHOLD => 250
        )
        port map(
            adc       => adc,
            tds       => tds,
            threshold => led
        );

    
    -- 5.4
    bcd_inst : bcd
        port map(
            bin       => tds,
            thousands => digit3,
            hundreds  => digit2,
            tens      => digit1,
            ones      => digit0
        );


    -- 5.5
    display0 : digit_display
        port map(
            din  => digit0,
            dout => hex0
        );

    display1 : digit_display
        port map(
            din  => digit1,
            dout => hex1
        );

    display2 : digit_display
        port map(
            din  => digit2,
            dout => hex2
        );

    display3 : digit_display
        port map(
            din  => digit3,
            dout => hex3
        );

end architecture structural;
