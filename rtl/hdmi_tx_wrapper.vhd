library ieee;
use ieee.std_logic_1164.all;

entity hdmi_tx_wrapper is
    port (
        reset       : in  std_logic;
        clk_pixel   : in  std_logic;
        clk_5x      : in  std_logic;
        active      : in  std_logic;
        hsync       : in  std_logic;
        vsync       : in  std_logic;
        red         : in  std_logic_vector(7 downto 0);
        green       : in  std_logic_vector(7 downto 0);
        blue        : in  std_logic_vector(7 downto 0);
        tmds_data_p : out std_logic_vector(2 downto 0);
        tmds_data_n : out std_logic_vector(2 downto 0);
        tmds_clk_p  : out std_logic;
        tmds_clk_n  : out std_logic
    );
end entity;

architecture rtl of hdmi_tx_wrapper is
begin
    u_tx : entity work.hdmi_tx
        generic map (
            DEVICE_FAMILY   => "GW2A",
            CLOCK_FREQUENCY => 25.200,
            ENCODE_MODE     => "DVI",
            USE_EXTCONTROL  => "OFF",
            SYNC_POLARITY   => "NEGATIVE",
            PICTUREASPECT   => "4:3",
            FORMATASPECT    => "4:3",
            CONTENTTYPE     => "GRAPHICS",
            VIDEO_CODE      => 1,
            USE_AUDIO_PACKET=> "OFF"
        )
        port map (
            reset   => reset,
            clk     => clk_pixel,
            clk_x5  => clk_5x,
            cc_swap => '0',
            control => "0000",
            active  => active,
            r_data  => red,
            g_data  => green,
            b_data  => blue,
            hsync   => hsync,
            vsync   => vsync,
            pcm_fs  => '0',
            pcm_l   => (others => '0'),
            pcm_r   => (others => '0'),
            data    => tmds_data_p,
            data_n  => tmds_data_n,
            clock   => tmds_clk_p,
            clock_n => tmds_clk_n
        );
end architecture;
