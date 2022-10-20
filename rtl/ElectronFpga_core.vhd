--------------------------------------------------------------------------------
-- Copyright (c) 2015 David Banks
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : ElectronFpga_core.vhd
-- /___/   /\     Timestamp : 28/07/2015
-- \   \  /  \
--  \___\/\___\
--
--Design Name: ElectronFpga_core

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ElectronFpga_core is
    generic (
        IncludeICEDebugger : boolean := false;
        IncludeABRRegs     : boolean := false;
        IncludeJafaMode7   : boolean := false
    );
    port (
        -- Clocks
        clk_16M00      : in  std_logic;
        clk_24M00      : in  std_logic; -- for Jafa Mode7
        clk_32M00      : in  std_logic; -- for Jafa Mode7
        clk_33M33      : in  std_logic;
        clk_40M00      : in  std_logic;

        -- Hard reset (active low)
        hard_reset_n   : in  std_logic;

        -- Keyboard
        ps2_key        : in  std_logic_vector (10 downto 0);
--        ps2_data       : in  std_logic;

        -- Video
		  video_cepix	  : out std_logic;
        video_red      : out std_logic_vector (3 downto 0);
        video_green    : out std_logic_vector (3 downto 0);
        video_blue     : out std_logic_vector (3 downto 0);
        video_vsync    : out std_logic;
        video_hsync    : out std_logic;
		  video_hblank   : out std_logic;
		  video_vblank   : out std_logic;
        -- Audio
        audio_l        : out std_logic;
        audio_r        : out std_logic;

        -- External memory (e.g. SRAM and/or FLASH)
        -- 512KB logical address space
        ext_nOE        : out std_logic;
        ext_nWE        : out std_logic;
        ext_nCS        : out std_logic;
        ext_A          : out std_logic_vector (18 downto 0);
        ext_Dout       : in  std_logic_vector (7 downto 0);
        ext_Din        : out std_logic_vector (7 downto 0);

        -- SD Card
        SDMISO         : in  std_logic;
        SDSS           : out std_logic;
        SDCLK          : out std_logic;
        SDMOSI         : out std_logic;

        -- KeyBoard LEDs (active high)
        caps_led       : out std_logic;
        motor_led      : out std_logic;

        -- Casette Port
        cassette_in    : in  std_logic;
        cassette_out   : out std_logic;

        -- Format of Video
        -- 00 - sRGB - interlaced
        -- 01 - sRGB - non interlaced
        -- 10 - SVGA - 50Hz
        -- 11 - SVGA - 60Hz
        vid_mode       : in  std_logic_vector(1 downto 0);

        -- Test outputs
        test           : out std_logic_vector(7 downto 0);

        -- ICE T65 Deubgger 57600 baud serial
        avr_RxD        : in    std_logic;
        avr_TxD        : out   std_logic;

        cpu_addr       : out   std_logic_vector(15 downto 0);
		  
		  joystick1_x   : in std_logic_vector(7 downto 0);
		  joystick1_y   : in std_logic_vector(7 downto 0);
		  joystick1_fire   : in std_logic;
		  joystick2_x   : in std_logic_vector(7 downto 0);
		  joystick2_y   : in std_logic_vector(7 downto 0);
		  joystick2_fire   : in std_logic;
		  h_cnt: out std_logic_vector(10  downto 0);
		  v_cnt: out std_logic_vector( 9  downto 0)

    );
end;

architecture behavioral of ElectronFpga_core is

    signal RSTn              : std_logic;
    signal cpu_R_W_n         : std_logic;
    signal cpu_a             : std_logic_vector (23 downto 0);
    signal cpu_din           : std_logic_vector (7 downto 0);
    signal cpu_dout          : std_logic_vector (7 downto 0);
    signal cpu_IRQ_n         : std_logic;
    signal cpu_NMI_n         : std_logic;
    signal ROM_n             : std_logic;

    signal ula_data          : std_logic_vector (7 downto 0);
    signal ula_enable        : std_logic;

    signal key_break         : std_logic;
    signal key_turbo         : std_logic_vector(1 downto 0);
    signal sound             : std_logic;
    signal kbd_data          : std_logic_vector(3 downto 0);

    signal cpu_clken         : std_logic;
    signal cpu_clken_r       : std_logic;

    signal rom_latch         : std_logic_vector(3 downto 0);

    signal ext_enable        : std_logic;

    signal abr_enable        : std_logic;
    signal abr_lo_bank_lock  : std_logic;
    signal abr_hi_bank_lock  : std_logic;

begin



        T65core : entity work.T65
        port map (
            Mode            => "00",
            Abort_n         => '1',
            SO_n            => '1',
            Res_n           => RSTn,
            Enable          => cpu_clken,
            Clk             => clk_16M00,
            Rdy             => '1',
            IRQ_n           => cpu_IRQ_n,
            NMI_n           => cpu_NMI_n,
            R_W_n           => cpu_R_W_n,
            Sync            => open,
            A               => cpu_a,
            DI              => cpu_din,
            DO              => cpu_dout
        );
        avr_TxD <= avr_RxD;



    ula : entity work.ElectronULA
    generic map (
        IncludeMMC       => true,
        Include32KRAM    => false,
        IncludeVGA       => true,
        IncludeJafaMode7 => IncludeJafaMode7
    )
    port map (
        clk_16M00 => clk_16M00,
        clk_24M00 => clk_24M00,
        clk_32M00 => clk_32M00,
        clk_33M33 => clk_33M33,
        clk_40M00 => clk_40M00,

        -- CPU Interface
        addr      => cpu_a(15 downto 0),
        data_in   => cpu_dout,
        data_out  => ula_data,
        data_en   => ula_enable,
        R_W_n     => cpu_R_W_n,
        RST_n     => RSTn,
        IRQ_n     => cpu_IRQ_n,
        NMI_n     => cpu_NMI_n,

        -- Rom Enable
        ROM_n     => ROM_n,

        -- Video
		  cepix		=> video_cepix,
        red       => video_red,
        green     => video_green,
        blue      => video_blue,
        vsync     => video_vsync,
        hsync     => video_hsync,
		  hblank		=> video_hblank,
		  vblank		=> video_vblank,

        -- Audio
        sound     => sound,

        -- SD Card
        SDMISO    => SDMISO,
        SDSS      => SDSS,
        SDCLK     => SDCLK,
        SDMOSI    => SDMOSI,

        -- Casette
        casIn     => cassette_in,
        casOut    => cassette_out,

        -- Keyboard
        kbd       => kbd_data,

        -- MISC
        caps      => caps_led,
        motor     => motor_led,

        rom_latch => rom_latch,

        mode_init => vid_mode,

        -- Clock Generation
        cpu_clken_out  => cpu_clken,
        turbo          => key_turbo,

  		  joystick1_x   =>joystick1_x,
		  joystick1_y  =>joystick1_y,
		  joystick1_fire  =>joystick1_fire,
		  joystick2_x  =>joystick2_x,
		  joystick2_y   =>joystick2_y,
		  joystick2_fire  =>joystick2_fire,
		  
		  h_cnt => h_cnt,
		  v_cnt => v_cnt

    );

    input : entity work.keyboard port map(
        clk        => clk_16M00,
        rst_n      => hard_reset_n, -- to avoid a loop when break pressed!
        ps2_key    => ps2_key,
--        ps2_data   => ps2_data,
        col        => kbd_data,
        row        => cpu_a(13 downto 0),
        break      => key_break,
        turbo      => key_turbo
    );

    cpu_NMI_n      <= '1';

    RSTn    <= hard_reset_n and key_break;
    audio_l <= sound;
    audio_r <= sound;

    ext_enable <= '1' when
                  -- ROM accrss
                  ROM_n = '0' or
                  -- Non screen main memory access (0000-2FFF)
                  cpu_a(15 downto 13) = "000" or cpu_a(15 downto 12) = "0010" or
                  -- Sideways RAM Access
                  (cpu_a(15 downto 14) = "10" and rom_latch(3 downto 1) /= "100") else '0';

    cpu_din <= ext_Dout       when ext_enable = '1' else
               ula_data       when ula_enable = '1' else
               x"F1";

    -- Pipeline external memory interface
     -- External addresses 00000-3FFFF are routed to FLASH 80000-DFFFFF
     -- External addresses 40000-7FFFF are routed to SRAM
     -- Note: the bottom 32K of CPU address space is mapped to SRAM, 20K of this is overlaid by the ULA
    process(clk_16M00,hard_reset_n)
    begin

        if hard_reset_n = '0' then
            ext_A   <= (others => '0');
            ext_Din <= (others => '0');
            ext_nWE <= '1';
            ext_nOE <= '1';
        elsif rising_edge(clk_16M00) then
            -- delayed cpu_clken for use as an external write signal
            cpu_clken_r <= cpu_clken;
            if cpu_a(15) = '0' then
                -- exteral main memory access
                ext_A <= "1" & "000" & cpu_a(14 downto 0);
					 
            elsif cpu_a(15 downto 14) = "11" then
                 -- The OS rom image lives in slot 8 as on the Elk this is where the
                 -- keyboard appears, which keeps the external memory image down to 256KB.
                ext_A <= "0" & "1000" & cpu_a(13 downto 0);
					 
            elsif cpu_a(15 downto 14) = "10" and rom_latch(3 downto 2) = "00" then
                -- Slots 0..3 are mapped to SRAM
                ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
					 
            elsif cpu_a(15 downto 14) = "10" and rom_latch(3 downto 0) = "0100" and cpu_a(13 downto 8) >= "110110" then
                -- Slots 4 (MMFS) has B600 onwards as writeable for private workspace so mapped to SRAM
                ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
					 
            else
                -- everyting else is ROM
                ext_A <= "0" & rom_latch & cpu_a(13 downto 0);
            end if;

            ext_Din <= cpu_dout;

            if cpu_R_W_n = '1' or ext_enable = '0' or cpu_clken_r = '0' then
                -- Default is disable WE, except in a few cases
                ext_nWE <= '1';
            elsif cpu_a(15) = '0' then
                -- exteral main memory access
                ext_nWE <= '0';
            elsif cpu_a(14) = '0' and rom_latch(3 downto 2) = "00" and rom_latch(0) = '0' and abr_lo_bank_lock = '0' then
                -- Slots 0,2 are write protected with FCDC/FCDD
                ext_nWE <= '0';
            elsif cpu_a(14) = '0' and rom_latch(3 downto 2) = "00" and rom_latch(0) = '1' and abr_hi_bank_lock = '0' then
                -- Slots 1,3 are write protected with FCDE/FCDF
                ext_nWE <= '0';
            elsif cpu_a(14) = '0' and rom_latch(3 downto 0) = "0100" and cpu_a(13 downto 8) >= "110110" then
                -- Slots 4 (MMFS) has B600 onwards as writeable for private workspace
                ext_nWE <= '0';
            else
                -- Other slots are read only
                ext_nWE <= '1';
            end if;

            -- Could make this more restrictive
            if cpu_R_W_n = '1' and ext_enable = '1' then
                ext_nOE <= '0';
            else
                ext_nOE <= '1';
            end if;

        end if;
    end process;

    -- Always enabled
    ext_nCS <= '0';

--------------------------------------------------------
-- ABR Lock Registers
--------------------------------------------------------

    ABRIncluded: if IncludeABRRegs generate
        abr_enable <= '1' when cpu_a(15 downto 2) & "00" = x"fcdc" else '0';
        process(clk_16M00, RSTn)
        begin
            if RSTn = '0' then
                abr_lo_bank_lock <= '1';
                abr_hi_bank_lock <= '1';
            elsif rising_edge(clk_16M00) then
                if cpu_clken = '1' then
                    if abr_enable = '1' and cpu_R_W_n = '0' then
                        if cpu_a(1) = '0' then
                            abr_lo_bank_lock <= cpu_a(0);
                        else
                            abr_hi_bank_lock <= cpu_a(0);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

   ABRExcluded: if not IncludeABRRegs generate
       abr_lo_bank_lock <= '1';
       abr_hi_bank_lock <= '1';
   end generate;


   cpu_addr <= cpu_a(15 downto 0);

   test <= (others => '0');

end behavioral;
