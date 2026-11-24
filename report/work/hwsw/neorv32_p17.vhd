-- ============================================================================
-- neorv32_p17.vhd  --  P17 board phase: the RV32 (NEORV32) processor
--
-- rv32i + Zicsr + Zifencei + Zicntr, 16 KB IMEM (pre-loaded with the P17
-- firmware image at synthesis: BOOT_MODE_SELECT = 2, no bootloader/UART
-- needed), 8 KB DMEM, CLINT, 8 GPIO in/out, external bus (XBUS) for the APB
-- peripherals, machine external interrupt = DDD arrhythmia IRQ.
-- The firmware image package neorv32_imem_image comes from
-- rtl/firmware/build/neorv32_imem_image.vhd (built by build_p17_fw.bat).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_p17 is
  port (
    clk_i      : in  std_logic;
    rstn_i     : in  std_logic;
    gpio_o     : out std_logic_vector(7 downto 0);
    gpio_i     : in  std_logic_vector(7 downto 0);
    irq_mei_i  : in  std_logic;
    xbus_adr_o : out std_logic_vector(31 downto 0);
    xbus_dat_o : out std_logic_vector(31 downto 0);
    xbus_we_o  : out std_logic;
    xbus_stb_o : out std_logic;
    xbus_cyc_o : out std_logic;
    xbus_dat_i : in  std_logic_vector(31 downto 0);
    xbus_ack_i : in  std_logic;
    xbus_err_i : in  std_logic
  );
end entity;

architecture rtl of neorv32_p17 is
  signal gpio_o_s, gpio_i_s : std_ulogic_vector(31 downto 0);
  signal adr_s, dat_o_s     : std_ulogic_vector(31 downto 0);
  signal we_s, stb_s, cyc_s : std_ulogic;
begin
  u_cpu : entity neorv32.neorv32_top
    generic map (
      CLOCK_FREQUENCY  => 25000000,
      BOOT_MODE_SELECT => 2,
      RISCV_ISA_Zicntr => true,
      IMEM_EN          => true,
      IMEM_SIZE        => 16*1024,
      DMEM_EN          => true,
      DMEM_SIZE        => 8*1024,
      XBUS_EN          => true,
      XBUS_TIMEOUT     => 256,
      IO_GPIO_NUM      => 8,
      IO_CLINT_EN      => true
    )
    port map (
      clk_i      => std_ulogic(clk_i),
      rstn_i     => std_ulogic(rstn_i),
      xbus_adr_o => adr_s,
      xbus_dat_o => dat_o_s,
      xbus_we_o  => we_s,
      xbus_stb_o => stb_s,
      xbus_cyc_o => cyc_s,
      xbus_dat_i => std_ulogic_vector(xbus_dat_i),
      xbus_ack_i => std_ulogic(xbus_ack_i),
      xbus_err_i => std_ulogic(xbus_err_i),
      gpio_o     => gpio_o_s,
      gpio_i     => gpio_i_s,
      irq_mei_i  => std_ulogic(irq_mei_i)
    );

  gpio_i_s   <= x"000000" & std_ulogic_vector(gpio_i);
  gpio_o     <= std_logic_vector(gpio_o_s(7 downto 0));
  xbus_adr_o <= std_logic_vector(adr_s);
  xbus_dat_o <= std_logic_vector(dat_o_s);
  xbus_we_o  <= std_logic(we_s);
  xbus_stb_o <= std_logic(stb_s);
  xbus_cyc_o <= std_logic(cyc_s);
end architecture;
