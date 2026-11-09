library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------
-- Filter bank.
--
--   block ram --- rd_data ---+--> filter_pass      --+
--                            +--> filter_a.        --+
--                            +--> filter_b         --+--> mux --> pixel
--                            +--> filter_c         --+     ^      pixel_valid
--                            +--> ...              --+     |
--                                                          |
--   KEY[1:0] --> up/down --> filter_sel -------------------+
--                                |
--                                +--> filter_num  (the number, as bits)
--
--   pixel_req --> counter --> rd_addr --> block ram
--
-- Every filter runs on every pixel and the multiplexer picks one result,
-- so all of them share a single register stage and therefore a single
-- latency.  Switching filters cannot shift the picture sideways.
--
-- TWO KEYS, NOT ONE PER FILTER.  keys_n(0) steps forward and keys_n(1)
-- steps back, both wrapping.  The board has four keys, so a key per
-- filter ran out at four; stepping reaches as many as are built.
--
-- N_FILTERS IS THE TOTAL, PASSTHROUGH INCLUDED, so the list runs 0 to
-- N_FILTERS - 1 and filter 0 is the passthrough.
--
-- Adding a filter: write the entity with the same six ports, add a branch
-- to the generate below, and raise N_FILTERS.
--------------------------------------------------------------------------
entity filters is
    generic (
        IMG_W           : natural := 640;
        IMG_H           : natural := 480;
        ADDR_W          : natural := 19;
        N_FILTERS       : natural := 1;
        DEBOUNCE_TICKS  : natural := 2**20
    );
    port (
        clock   : in  std_logic;
        reset   : in  std_logic;                      -- active high

        -- ---- buttons ----
        -- Two keys, ACTIVE LOW, and they step rather than select:
        --
        --     keys_n(0)   next filter
        --     keys_n(1)   previous filter
        --
        -- Both wrap, so holding one direction walks the whole list and
        -- comes back round.  Two buttons reach any number of filters,
        -- where one-per-filter ran out at the four keys the board has.
        keys_n  : in  std_logic_vector(1 downto 0);

        -- Which filter is showing, as a plain binary number.  What
        -- displays it is somebody else's problem -- this module knows
        -- which filter is selected, not what the board has to show it
        -- on.  Eight bits so the two nibbles fall out as two digits.
        filter_num : out std_logic_vector(7 downto 0);

        -- ---- block ram read port ----
        rd_addr : out std_logic_vector(ADDR_W - 1 downto 0);
        rd_data : in  std_logic_vector(19 downto 0);  -- RGB686

        -- ---- hdmi ----
        frame_sync  : in  std_logic;                      -- holds address at 0
        pixel_req : in  std_logic;                      -- next active pixel

        pixel       : out std_logic_vector(23 downto 0);  -- 8:8:8
        pixel_valid : out std_logic                       -- pixel is this one
    );
end entity filters;


architecture rtl of filters is

    --------------------------------------------------------------------
    -- Filter modules.  Same six ports on every one.
    --
    -- TODO: add more filters here, and raise N_FILTERS above.
    --------------------------------------------------------------------
    component filter_pass is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_gray is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_cartonnify is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_edge is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_invert is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_sepia is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_swap is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;

    component filter_threshold is
        port (
            clock     : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(19 downto 0);
            valid_in  : in  std_logic;
            data_out  : out std_logic_vector(23 downto 0);
            valid_out : out std_logic
        );
    end component;


    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant N_PIXELS : natural := IMG_W * IMG_H;
    
    --------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------
    type slv_array is array (natural range <>) of std_logic_vector(23 downto 0);

    signal pixels : slv_array(0 to N_FILTERS - 1);
    signal valids : std_logic_vector(0 to N_FILTERS - 1);

    signal valid_in   : std_logic;

    -- Which filter is showing.  0 is the passthrough.
    signal filter_sel : natural range 0 to N_FILTERS - 1;
    signal key_cnt    : natural range 0 to DEBOUNCE_TICKS;

begin

    ----------------------------------------------------------------------
    -- TODO: Implement a clocked process to address the block RAM.  The 
    -- address is a raster counter that counts from 0 to N_PIXELS-1, 
    -- stepping once per ACTIVE pixel_req from the HDMI. When a frame_sync 
    -- arrives, the counter should reset to 0. The valid_in signal should 
    -- be set high when the data from the block RAM is valid, which is one 
    -- clock cycle after the address is presented.
    ----------------------------------------------------------------------
    address_process : process (reset, clock) is
    begin
        if reset = '1' then
            addr_count <= 0;
            valid_in <= '0';

        elsif rising_edge(clock) then
            valid_in <= pixel_req and not frame_sync;

            if frame_sync = '1' then
                addr_count <= 0;

            elsif pixel_req = '1' then
                if addr_count = N_PIXELS - 1 then
                    addr_count <= 0;
                else
                    addr_count <= addr_count + 1;
                end if;
            end if;
        end if;
    end process address_process;

    rd_addr <= std_logic_vector(to_unsigned(addr_count, rd_addr'length));

    ----------------------------------------------------------------------
    -- TODO: Implement a for-generate loop to add more filters along with 
    -- if-generate to select the correct filter based on the index. Make 
    -- sure to raise N_FILTERS accordingly.
    --
    -- Index 0 is the passthrough default and is always built.
    -- The rest are effects rather than diagnostics and follow behind.
    --     0 pass        the camera as it is
    --     1 gray        grayscale image
    --     2 sepia       colour replaced with a known tint
    --     3 swap        red and blue exchanged
    --     4 invert      255 - c on every channel.
    --     5 threshold   White above the level, black below.
    --     6 cartoonify  exaggerates the edges and flattens the colours.
    --     7 edge        shows the edges only, in white on black.
    --
    ----------------------------------------------------------------------
    gen_filters : for i in 0 to N_FILTERS - 1 generate

        gen_pass : if i = 0 generate
            u_filter_pass : filter_pass
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_pass;

        gen_gray : if i = 1 generate
            u_filter_gray : filter_gray
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_gray;

        gen_sepia : if i = 2 generate
            u_filter_sepia : filter_sepia
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_sepia;

        gen_swap : if i = 3 generate
            u_filter_swap : filter_swap
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_swap;

        gen_invert : if i = 4 generate
            u_filter_invert : filter_invert
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_invert;

        gen_threshold : if i = 5 generate
            u_filter_threshold : filter_threshold
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_threshold;

        gen_cartoonify : if i = 6 generate
            u_filter_cartoonify : filter_cartoonify
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_cartoonify;

        gen_edge : if i = 7 generate
            u_filter_edge : filter_edge
                port map ( clock => clock,
                           reset => reset,
                           data_in => rd_data,
                           valid_in => valid_in,
                           data_out => pixels(i),
                           valid_out => valids(i) );
        end generate gen_edge;

    end generate gen_filters;

    ----------------------------------------------------------------------
    -- TODO: Implement a clocked process to step the filter index up or 
    -- down when the keys are pressed.  The index should wrap around when 
    -- it reaches the end of the filter list.
    --
    -- Button select: step the filter index up or down.
    --
    --     keys_n(0)   up       wraps N_FILTERS - 1 -> 0
    --     keys_n(1)   down     wraps 0 -> N_FILTERS - 1
    --
    -- THE COUNTER IS ALSO THE MEMORY OF HAVING FIRED.  It counts while a
    -- key is down and STOPS at DEBOUNCE_TICKS, so the step happens on
    -- the one clock it passes DEBOUNCE_TICKS - 1 and never again while
    -- the finger stays there.  Letting go puts it back to zero, which
    -- arms the next press and is also the debounce: a contact that
    -- chatters back to released restarts the count, so only an UNBROKEN
    -- DEBOUNCE_TICKS of "pressed" ever reaches the step.
    --
    -- Counting is decided for the whole vector, not per key -- a test
    -- per key would let the key that is UP zero the counter while the
    -- one actually held never accumulates.
    --
    -- Both keys down does nothing, which is the honest answer to being
    -- asked to go two ways at once.
    ----------------------------------------------------------------------
    button_process : process (reset, clock) is
    begin
        if reset = '1' then
            filter_sel <= 0;
            key_cnt <= 0;

        elsif rising_edge(clock) then

            if keys_n = "11" or keys_n = "00" then
                key_cnt <= 0;

            elsif key_cnt < DEBOUNCE_TICKS then
                key_cnt <= key_cnt + 1;

                if key_cnt = DEBOUNCE_TICKS - 1 then

                    if keys_n = "10" then
                        -- up
                        if filter_sel = N_FILTERS - 1 then
                            filter_sel <= 0;
                        else
                            filter_sel <= filter_sel + 1;
                        end if;

                    elsif keys_n = "01" then
                        -- down
                        if filter_sel = 0 then
                            filter_sel <= N_FILTERS - 1;
                        else
                            filter_sel <= filter_sel - 1;
                        end if;
                    end if;

                end if;
            end if;
        end if;
    end process button_process;

    ----------------------------------------------------------------------
    -- Multiplexer to select one of the N_FILTERS pixels.
    --
    -- filter_sel indexes the array directly now -- no priority encoder,
    -- because there is no longer a set of independent keys that could
    -- disagree.  Out of reset it is 0, the passthrough.
    --
    -- pixel and pixel_valid leave the SAME register, so whoever is
    -- reading them can sample both on one edge and always get a matched
    -- pair -- however many stages the read path grows.
    ----------------------------------------------------------------------
    mux_process : process (reset, clock) is
    begin
        if ( reset = '1' ) then
            pixel       <= (others => '0');
            pixel_valid <= '0';
        elsif rising_edge(clock) then
            pixel       <= pixels(filter_sel);
            pixel_valid <= valids(filter_sel);
        end if;
    end process mux_process;

    ----------------------------------------------------------------------
    -- Output LEDs: the filter number in binary.
    --
    -- The board's LEDs are active high, so no inversion.  Four bits
    -- reaches filter 15, well past the seven this file can build.
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    -- Which filter is selected, on the way out as bits.
    ----------------------------------------------------------------------
    filter_num <= std_logic_vector(to_unsigned(filter_sel, filter_num'length));

end architecture rtl;
