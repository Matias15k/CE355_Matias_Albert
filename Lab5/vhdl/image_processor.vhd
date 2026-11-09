library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------
-- Lab 5 -- Image Processor.  Structural only.
--
--                +-------------+          +------+
--   cam_clk ---->|             |--wr_en-->|      |
--   cam_vs ----->| video_store |-wr_addr->|      |
--   cam_de ----->|    WRITE    |-wr_data->|      |
--   cam_pixel -->|             |  20bits  |      |
--    24bits      +-------------+          | bram |
--                                         |      |
--                +-------------+          |      |
--   pixel_req -->|             |-rd_addr->|      |
--   frame_sync ->|   filters   |<-rd_data-|      |
--   keys_n ----->|     READ    |  20bits  |      |
--                |             |          +------+
--                +-------------+
--                   |      |
--                 pixel   hex
--
-- The two sides never talk to each other. The video_store only writes: it
-- takes whatever the camera sends and writes it in the buffer in RGB686 (20 bits)
-- format.  The filters only reads: it asks for whatever the display wants 
-- and pipes it out. The BRAM buffer has read and write paths, and is the 
-- only thing between them, which is exactly why they can run at unrelated rates.
-- 
-- The display side is not a clock domain at all: hdmi divides the system
-- clock down to the pixel rate and hands over pixel_req, so filters simply
-- runs at pixel rate on the system clock.
--
-- The camera side genuinely is a second domain -- its clock comes from
-- the MIPI bridge, not our PLL -- so video_store samples cam_clk as an
-- ordinary signal and makes one tick per pixel.  That is the only clock
-- domain crossing in the whole design.
--------------------------------------------------------------------------
entity image_processor is
    generic (
        IMG_W           : natural := 640;
        IMG_H           : natural := 480;
        ADDR_W          : natural := 19;
        N_FILTERS       : natural := 8;
        DEBOUNCE_TICKS  : natural := 2**20
    );
    port (
        -- ---- system ----
        clock       : in  std_logic;
        reset       : in  std_logic;                       -- active high

        -- ---- camera side (write), 25 MHz ----
        cam_clk     : in  std_logic;                       -- sampled, not a clock
        cam_vs      : in  std_logic;                       -- frame valid
        cam_de      : in  std_logic;                       -- pixel valid
        cam_pixel   : in  std_logic_vector(23 downto 0);   -- RGB888

        -- ---- control ----
        keys_n      : in  std_logic_vector(1 downto 0);    -- ACTIVE LOW: 0 next, 1 prev
        
        -- ---- HEX digital display ----
        hex0        : out std_logic_vector(6 downto 0);    -- filter number,
        hex1        : out std_logic_vector(6 downto 0);    -- two digits

        -- ---- display side (read), same clock, pixel rate enable ----
        pixel_req   : in  std_logic;                        -- next active pixel
        frame_sync  : in  std_logic;                        -- holds address at 0

        pixel       : out std_logic_vector(23 downto 0);    -- RGB888
        pixel_valid : out std_logic                         -- pixel is this one
    );
end entity image_processor;


architecture structural of image_processor is

    --------------------------------------------------------------------
    -- Constant Declarations
    --------------------------------------------------------------------
    constant BRAM_BUFFER_SIZE   : integer := IMG_W * IMG_H;
    constant BRAM_ADDR_WIDTH    : integer := ADDR_W;
    constant BRAM_DATA_WIDTH    : integer := 20;  -- RGB686

    --------------------------------------------------------------------
    -- Component Declarations
    --------------------------------------------------------------------
    component video_store is
        generic (
            ADDR_W : natural := 19
        );
        port (
            clock     : in std_logic;
            reset     : in std_logic;
            cam_clk   : in std_logic;
            cam_vs    : in std_logic;
            cam_de    : in std_logic;
            cam_pixel : in std_logic_vector(23 downto 0);
            wr_addr   : out std_logic_vector(ADDR_W - 1 downto 0);
            wr_data   : out std_logic_vector(19 downto 0);
            wr_en     : out std_logic
        );
    end component;

    component bram is
        generic (
            BRAM_BUFFER_SIZE : integer := 1024;
            BRAM_ADDR_WIDTH  : integer := 10;
            BRAM_DATA_WIDTH  : integer := 32
        );
        port (
            clock   : in std_logic;
            rd_addr : in std_logic_vector(BRAM_ADDR_WIDTH - 1 downto 0);
            wr_addr : in std_logic_vector(BRAM_ADDR_WIDTH - 1 downto 0);
            wr_en   : in std_logic;
            dout    : out std_logic_vector(BRAM_DATA_WIDTH - 1 downto 0);
            din     : in std_logic_vector(BRAM_DATA_WIDTH - 1 downto 0)
        );
    end component;

    component filters is
        generic (
            IMG_W          : natural := 640;
            IMG_H          : natural := 480;
            ADDR_W         : natural := 19;
            N_FILTERS      : natural := 8;
            DEBOUNCE_TICKS : natural := 2**20
        );
        port (
            clock       : in std_logic;
            reset       : in std_logic;
            keys_n      : in std_logic_vector(1 downto 0);
            filter_num  : out std_logic_vector(7 downto 0);
            rd_addr     : out std_logic_vector(ADDR_W - 1 downto 0);
            rd_data     : in std_logic_vector(19 downto 0);
            frame_sync  : in std_logic;
            pixel_req   : in std_logic;
            pixel       : out std_logic_vector(23 downto 0);
            pixel_valid : out std_logic
        );
    end component;

    component digit_display is
        port (
            clock : in std_logic;
            reset : in std_logic;
            din   : in std_logic_vector(3 downto 0);
            dout  : out std_logic_vector(6 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Signal Declarations
    --------------------------------------------------------------------
    signal wr_addr : std_logic_vector(ADDR_W - 1 downto 0);
    signal wr_data : std_logic_vector(19 downto 0);
    signal wr_en   : std_logic;

    signal rd_addr : std_logic_vector(ADDR_W - 1 downto 0);
    signal rd_data : std_logic_vector(19 downto 0);

    signal filter_num : std_logic_vector(7 downto 0);

begin

    --------------------------------------------------------------------
    -- TODO: Instantiate and wire together the components: 
    -- video_store, bram, filters, and digital display components.
    --------------------------------------------------------------------

    -- Camera pixels -> BRAM write signals
    u_video_store : video_store
        generic map (
            ADDR_W => ADDR_W
        )
        port map (
            clock     => clock,
            reset     => reset,
            cam_clk   => cam_clk,
            cam_vs    => cam_vs,
            cam_de    => cam_de,
            cam_pixel => cam_pixel,
            wr_addr   => wr_addr,
            wr_data   => wr_data,
            wr_en     => wr_en
        );

    -- Frame buffer
    u_bram : bram
        generic map (
            BRAM_BUFFER_SIZE => BRAM_BUFFER_SIZE,
            BRAM_ADDR_WIDTH  => BRAM_ADDR_WIDTH,
            BRAM_DATA_WIDTH  => BRAM_DATA_WIDTH
        )
        port map (
            clock   => clock,
            wr_addr => wr_addr,
            wr_en   => wr_en,
            din     => wr_data,
            rd_addr => rd_addr,
            dout    => rd_data
        );

    -- Read BRAM and apply image filters
    u_filters : filters
        generic map (
            IMG_W          => IMG_W,
            IMG_H          => IMG_H,
            ADDR_W         => ADDR_W,
            N_FILTERS      => N_FILTERS,
            DEBOUNCE_TICKS => DEBOUNCE_TICKS
        )
        port map (
            clock       => clock,
            reset       => reset,
            keys_n      => keys_n,
            filter_num  => filter_num,
            rd_addr     => rd_addr,
            rd_data     => rd_data,
            frame_sync  => frame_sync,
            pixel_req   => pixel_req,
            pixel       => pixel,
            pixel_valid => pixel_valid
        );

    -- Lower hexadecimal digit
    u_hex0 : digit_display
        port map (
            clock => clock,
            reset => reset,
            din   => filter_num(3 downto 0),
            dout  => hex0
        );

    -- Upper hexadecimal digit
    u_hex1 : digit_display
        port map (
            clock => clock,
            reset => reset,
            din   => filter_num(7 downto 4),
            dout  => hex1
        );

end architecture structural;
