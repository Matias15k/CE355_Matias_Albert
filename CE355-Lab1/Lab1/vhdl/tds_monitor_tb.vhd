library ieee;
use ieee.std_logic_1164.all;

entity tds_monitor_tb is
end entity tds_monitor_tb;

architecture behavioral of tds_monitor_tb is

    ----------------------------------------------------------------
    -- Signals connected to the device under test
    --
    -- TODO: Add signal declarations 
    ----------------------------------------------------------------
    signal adc  : std_logic_vector(11 downto 0);


    ----------------------------------------------------------------
    -- Component Declaration: Device Under Test
    --
    -- TODO: Add component declaration for tds_monitor
    ----------------------------------------------------------------
    

begin

    ----------------------------------------------------------------
    -- Device Under Test
    --
    -- TODO: Instantiate the tds_monitor component and connect the signals
    ----------------------------------------------------------------
    

    ----------------------------------------------------------------
    -- Test Stimulus
    --
    -- The test stimulus is a series of ADC values that correspond to 
    -- various TDS levels. The LED output is expected to turn on when 
    -- the TDS level exceeds the threshold defined in the tds_monitor entity.
    --
    -- ADC = Vin * (4095 / 3.3)
    -- Vin = (ADC / 4095) * 3.3

    -- LED states assume TDS_THRESHOLD => 250 in tds_monitor.
    ----------------------------------------------------------------
    stimulus : process
    begin

        -- 0.000 V : 0000 ppm, LED off (dry probe)
        adc <= X"000";
        wait for 20 ns;

        ----------------------------------------------------------------
        -- TODO: Add more test cases for different ADC values 
        ----------------------------------------------------------------

        -- wait forever
        wait;

    end process stimulus;

end architecture behavioral;
