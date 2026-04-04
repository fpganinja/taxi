# XDC constraints for the Napatech NT40E3
# part: xc7vx330tffg1157-2

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
# set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE    [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DIV-1  [current_design]
# set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4           [current_design]
# set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP         [current_design]

# 80 MHz EMC clock
set_property -dict {LOC AP33 IOSTANDARD LVCMOS18} [get_ports clk_80mhz]
create_clock -period 12.5 -name clk_80mhz [get_ports clk_80mhz]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_80mhz_ibufg]

# 233.33 MHz DDR3 MIG clock
#set_property -dict {LOC J30 IOSTANDARD LVDS} [get_ports clk_ddr_233mhz_p]
#set_property -dict {LOC J31 IOSTANDARD LVDS} [get_ports clk_ddr_233mhz_n]
#create_clock -period 4.285 -name clk_ddr_233mhz [get_ports clk_ddr_233mhz_p]

# LEDs
set_property -dict {LOC AC12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_led[0]}]
set_property -dict {LOC AE9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_led[1]}]
set_property -dict {LOC AE8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_led[2]}]
set_property -dict {LOC AC10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_led[3]}]
set_property -dict {LOC AD30 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[0]}]
set_property -dict {LOC AD31 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[1]}]
set_property -dict {LOC AG30 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[2]}]
set_property -dict {LOC AH30 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[3]}]
set_property -dict {LOC AB27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_red}]
set_property -dict {LOC AB28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_green}]
set_property -dict {LOC AJ26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_sync[0]}]
set_property -dict {LOC AP29 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_sync[1]}]

set_false_path -to [get_ports {sfp_led[*] led[*] led_red led_green led_sync[*]}]
set_output_delay 0 [get_ports {sfp_led[*] led[*] led_red led_green led_sync[*]}]

# Time sync
#set_property -dict {LOC AB31 IOSTANDARD LVCMOS18} [get_ports {sync_ext_in}]
#set_property -dict {LOC AB32 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {sync_ext_out}]
#set_property -dict {LOC AB30 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_in_en}]
#set_property -dict {LOC AA30 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_out_en[0]}]
#set_property -dict {LOC W32  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_out_en[1]}]
#set_property -dict {LOC Y32  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_term[0]}]
#set_property -dict {LOC AA31 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_term[1]}]
#set_property -dict {LOC V30  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_vsel[0]}]
#set_property -dict {LOC U30  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_ext_vsel[1]}]

#set_property -dict {LOC AK26 IOSTANDARD LVCMOS18} [get_ports {sync_int_1_in}]
#set_property -dict {LOC AK27 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {sync_int_1_out}]
#set_property -dict {LOC AH24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_in_en}]
#set_property -dict {LOC AH25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_out_en[0]}]
#set_property -dict {LOC AJ25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_out_en[1]}]
#set_property -dict {LOC AL25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_term[0]}]
#set_property -dict {LOC AL26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_term[1]}]
#set_property -dict {LOC AG25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_vsel[0]}]
#set_property -dict {LOC AJ27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_1_vsel[1]}]

#set_property -dict {LOC AM27 IOSTANDARD LVCMOS18} [get_ports {sync_int_2_in}]
#set_property -dict {LOC AN29 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {sync_int_2_out}]
#set_property -dict {LOC AN28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_in_en}]
#set_property -dict {LOC AM28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_out_en[0]}]
#set_property -dict {LOC AP25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_out_en[1]}]
#set_property -dict {LOC AP26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_term[0]}]
#set_property -dict {LOC AN27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_term[1]}]
#set_property -dict {LOC AN25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_vsel[0]}]
#set_property -dict {LOC AM25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sync_int_2_vsel[1]}]

#set_false_path -from [get_ports {sync_ext_in}]
#set_input_delay 0 [get_ports {sync_ext_in}]
#set_false_path -to [get_ports {sync_ext_out sync_ext_in_en sync_ext_out_en[*] sync_ext_term[*] sync_ext_vsel[*]}]
#set_output_delay 0 [get_ports {sync_ext_out sync_ext_in_en sync_ext_out_en[*] sync_ext_term[*] sync_ext_vsel[*]}]

#set_false_path -from [get_ports {sync_int_1_in}]
#set_input_delay 0 [get_ports {sync_int_1_in}]
#set_false_path -to [get_ports {sync_int_1_out sync_int_1_in_en sync_int_1_out_en[*] sync_int_1_term[*] sync_int_1_vsel[*]}]
#set_output_delay 0 [get_ports {sync_int_1_out sync_int_1_in_en sync_int_1_out_en[*] sync_int_1_term[*] sync_int_1_vsel[*]}]

#set_false_path -from [get_ports {sync_int_2_in}]
#set_input_delay 0 [get_ports {sync_int_2_in}]
#set_false_path -to [get_ports {sync_int_2_out sync_int_2_in_en sync_int_2_out_en[*] sync_int_2_term[*] sync_int_2_vsel[*]}]
#set_output_delay 0 [get_ports {sync_int_2_out sync_int_2_in_en sync_int_2_out_en[*] sync_int_2_term[*] sync_int_2_vsel[*]}]

# AVR BMC U2
#set_property -dict {LOC AC23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pc4] ;# U2.J7 PC4
#set_property -dict {LOC AD24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pc5] ;# U2.H7 PC5
#set_property -dict {LOC AC24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pc6] ;# U2.G7 PC6
#set_property -dict {LOC AD25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pc7] ;# U2.J8 PC7

#set_property -dict {LOC AC25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pd4] ;# U2.H9 PD4
#set_property -dict {LOC AE24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pd5] ;# U2.H8 PD5
#set_property -dict {LOC AE23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pd6] ;# U2.G9 PD6
#set_property -dict {LOC AF26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pd7] ;# U2.G8 PD7

#set_property -dict {LOC AF29 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj0] ;# U2.C5 PJ0
#set_property -dict {LOC AC28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj1] ;# U2.D5 PJ1
#set_property -dict {LOC AC29 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj2] ;# U2.E5 PJ2
#set_property -dict {LOC AE28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj3] ;# U2.A4 PJ3
#set_property -dict {LOC AE29 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj4] ;# U2.B4 PJ4
#set_property -dict {LOC AD29 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj5] ;# U2.C4 PJ5
#set_property -dict {LOC AH28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj6] ;# U2.D4 PJ6
#set_property -dict {LOC AD26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pj7] ;# U2.E4 PJ7

#set_property -dict {LOC AH27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pdi_data] ;# U2.F4 PDI_DATA
#set_property -dict {LOC AH29 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports avr_pdi_clk] ;# U2.F3 PDI_CLK

# Si5338 U18
set_property -dict {LOC AF33 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports si5338_i2c_scl] ;# U18.12 SCL
set_property -dict {LOC AF34 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports si5338_i2c_sda] ;# U18.19 SDA
set_property -dict {LOC AC27 IOSTANDARD LVCMOS18} [get_ports si5338_intr] ;# U18.8 INTR

set_false_path -to [get_ports {si5338_i2c_scl si5338_i2c_sda}]
set_output_delay 0 [get_ports {si5338_i2c_scl si5338_i2c_sda}]
set_false_path -from [get_ports {si5338_i2c_scl si5338_i2c_sda si5338_intr}]
set_input_delay 0 [get_ports {si5338_i2c_scl si5338_i2c_sda si5338_intr}]

# 10/100 PHY (DP83630)
#set_property -dict {LOC AJ16 IOSTANDARD LVCMOS18} [get_ports phy_tx_clk] ;# U5.1 TX_CLK via U53.4/13
#set_property -dict {LOC AN14 IOSTANDARD LVCMOS18} [get_ports phy_tx_en] ;# U5.2 TX_EN via U51.4/13
#set_property -dict {LOC AN18 IOSTANDARD LVCMOS18} [get_ports {phy_txd[0]}] ;# U5.3 TXD_0 via U50.4/13
#set_property -dict {LOC AL16 IOSTANDARD LVCMOS18} [get_ports {phy_txd[1]}] ;# U5.4 TXD_1 via U50.5/12
#set_property -dict {LOC AM16 IOSTANDARD LVCMOS18} [get_ports {phy_txd[2]}] ;# U5.5 TXD_2 via U50.6/11
#set_property -dict {LOC AP17 IOSTANDARD LVCMOS18} [get_ports {phy_txd[3]}] ;# U5.6 TXD_3 via U50.7/10
#set_property -dict {LOC AH15 IOSTANDARD LVCMOS18} [get_ports phy_rx_clk] ;# U5.38 RX_CLK via U55.5/12
#set_property -dict {LOC AK18 IOSTANDARD LVCMOS18} [get_ports phy_rx_dv] ;# U5.39 RX_DV via U55.6/11
#set_property -dict {LOC AL18 IOSTANDARD LVCMOS18} [get_ports phy_rx_er] ;# U5.41 RX_ER via U55.7/10
#set_property -dict {LOC AP14 IOSTANDARD LVCMOS18} [get_ports {phy_rxd[0]}] ;# U5.46 RXD_0 via U53.5/12
#set_property -dict {LOC AM17 IOSTANDARD LVCMOS18} [get_ports {phy_rxd[1]}] ;# U5.45 RXD_1 via U53.6/11
#set_property -dict {LOC AN17 IOSTANDARD LVCMOS18} [get_ports {phy_rxd[2]}] ;# U5.44 RXD_2 via U53.7/10
#set_property -dict {LOC AL15 IOSTANDARD LVCMOS18} [get_ports {phy_rxd[3]}] ;# U5.43 RXD_3 via U55.4/13
#set_property -dict {LOC AL14 IOSTANDARD LVCMOS18} [get_ports phy_crs] ;# U5.40 CRS/CRS_DV via U57.5/12
#set_property -dict {LOC AK14 IOSTANDARD LVCMOS18} [get_ports phy_col] ;# U5.42 COL via U57.4/13
#set_property -dict {LOC AF16 IOSTANDARD LVCMOS18} [get_ports phy_refclk] ;# U5.34 X1
#set_property -dict {LOC AC15 IOSTANDARD LVCMOS18} [get_ports phy_reset_n] ;# U5.29 RESET_N
#set_property -dict {LOC AD15 IOSTANDARD LVCMOS18} [get_ports phy_int_n] ;# U5.7 PWRDOWN/INTN
#set_property -dict {LOC AJ17 IOSTANDARD LVCMOS18} [get_ports phy_mdc] ;# U5.31 MDC
#set_property -dict {LOC AK17 IOSTANDARD LVCMOS18} [get_ports phy_mdio] ;# U5.30 MDIO
#set_property -dict {LOC AF13 IOSTANDARD LVCMOS18} [get_ports phy_gpio1] ;# U5.21 GPIO1
#set_property -dict {LOC AG13 IOSTANDARD LVCMOS18} [get_ports phy_gpio2] ;# U5.22 GPIO2
#set_property -dict {LOC AE17 IOSTANDARD LVCMOS18} [get_ports phy_gpio3] ;# U5.23 GPIO3
#set_property -dict {LOC AE16 IOSTANDARD LVCMOS18} [get_ports phy_gpio4] ;# U5.25 GPIO4
#set_property -dict {LOC AE14 IOSTANDARD LVCMOS18} [get_ports phy_gpio5] ;# U5.26 GPIO5/LED_ACT
#set_property -dict {LOC AF14 IOSTANDARD LVCMOS18} [get_ports phy_gpio6] ;# U5.27 GPIO6/LED_SPEED/FX_SD
#set_property -dict {LOC AC17 IOSTANDARD LVCMOS18} [get_ports phy_gpio7] ;# U5.28 GPIO7/LED_LINK
#set_property -dict {LOC AD17 IOSTANDARD LVCMOS18} [get_ports phy_gpio8] ;# U5.36 GPIO8
#set_property -dict {LOC AD14 IOSTANDARD LVCMOS18} [get_ports phy_gpio9] ;# U5.37 GPIO9
#set_property -dict {LOC AG17 IOSTANDARD LVCMOS18} [get_ports phy_gpio12] ;# U5.24 GPIO12/CLK_OUT via U57.7/10
#set_property -dict {LOC AJ14 IOSTANDARD LVCMOS18} [get_ports phy_isolate] ;# OE on U50, U51, U53, U55, U57

# SFP+ Interfaces (J1-J4)
set_property -dict {LOC B6  } [get_ports {sfp_rx_p[0]}] ;# MGTHRXP3_118 GTHE2_CHANNEL_X1Y39 / GTHE2_COMMON_X1Y9
set_property -dict {LOC B5  } [get_ports {sfp_rx_n[0]}] ;# MGTHRXN3_118 GTHE2_CHANNEL_X1Y39 / GTHE2_COMMON_X1Y9
set_property -dict {LOC A4  } [get_ports {sfp_tx_p[0]}] ;# MGTHTXP3_118 GTHE2_CHANNEL_X1Y39 / GTHE2_COMMON_X1Y9
set_property -dict {LOC A3  } [get_ports {sfp_tx_n[0]}] ;# MGTHTXN3_118 GTHE2_CHANNEL_X1Y39 / GTHE2_COMMON_X1Y9
set_property -dict {LOC D6  } [get_ports {sfp_rx_p[1]}] ;# MGTHRXP2_118 GTHE2_CHANNEL_X1Y38 / GTHE2_COMMON_X1Y9
set_property -dict {LOC D5  } [get_ports {sfp_rx_n[1]}] ;# MGTHRXN2_118 GTHE2_CHANNEL_X1Y38 / GTHE2_COMMON_X1Y9
set_property -dict {LOC B2  } [get_ports {sfp_tx_p[1]}] ;# MGTHTXP2_118 GTHE2_CHANNEL_X1Y38 / GTHE2_COMMON_X1Y9
set_property -dict {LOC B1  } [get_ports {sfp_tx_n[1]}] ;# MGTHTXN2_118 GTHE2_CHANNEL_X1Y38 / GTHE2_COMMON_X1Y9
set_property -dict {LOC H6  } [get_ports {sfp_mgt_refclk_p[0]}] ;# MGTREFCLK1P_118 from U20.10
set_property -dict {LOC H5  } [get_ports {sfp_mgt_refclk_n[0]}] ;# MGTREFCLK1N_118 from U20.9
set_property -dict {LOC W4  } [get_ports {sfp_rx_p[2]}] ;# MGTHRXP1_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC W3  } [get_ports {sfp_rx_n[2]}] ;# MGTHRXN1_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC V2  } [get_ports {sfp_tx_p[2]}] ;# MGTHTXP1_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC V1  } [get_ports {sfp_tx_n[2]}] ;# MGTHTXN1_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC AA4 } [get_ports {sfp_rx_p[3]}] ;# MGTHRXP0_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC AA3 } [get_ports {sfp_rx_n[3]}] ;# MGTHRXN0_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC Y2  } [get_ports {sfp_tx_p[3]}] ;# MGTHTXP0_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC Y1  } [get_ports {sfp_tx_n[3]}] ;# MGTHTXN0_116 GTHE2_CHANNEL_X1Y37 / GTHE2_COMMON_X1Y9
set_property -dict {LOC T6  } [get_ports {sfp_mgt_refclk_p[1]}] ;# MGTREFCLK0P_116 from U20.20
set_property -dict {LOC T5  } [get_ports {sfp_mgt_refclk_n[1]}] ;# MGTREFCLK0N_116 from U20.21
set_property -dict {LOC AG12 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {sfp_mod_abs[0]}]
set_property -dict {LOC AJ11 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {sfp_mod_abs[1]}]
set_property -dict {LOC AK9  IOSTANDARD LVCMOS18 PULLUP true} [get_ports {sfp_mod_abs[2]}]
set_property -dict {LOC AN10 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {sfp_mod_abs[3]}]
set_property -dict {LOC AF10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[0][0]}]
set_property -dict {LOC AG10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[0][1]}]
set_property -dict {LOC AJ12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[1][0]}]
set_property -dict {LOC AK12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[1][1]}]
set_property -dict {LOC AL11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[2][0]}]
set_property -dict {LOC AM11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[2][1]}]
set_property -dict {LOC AP12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[3][0]}]
set_property -dict {LOC AP11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_rs[3][1]}]
set_property -dict {LOC AH10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_tx_disable[0]}]
set_property -dict {LOC AK8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_tx_disable[1]}]
set_property -dict {LOC AM12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_tx_disable[2]}]
set_property -dict {LOC AM13 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {sfp_tx_disable[3]}]
# set_property -dict {LOC AF9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[0]}]
# set_property -dict {LOC AD9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[0]}]
# set_property -dict {LOC AD12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[1]}]
# set_property -dict {LOC AF8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[1]}]
# set_property -dict {LOC AF11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[2]}]
# set_property -dict {LOC AD11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[2]}]
# set_property -dict {LOC AG8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[3]}]
# set_property -dict {LOC AG11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[3]}]

# 156.25 MHz MGT reference clock
create_clock -period 6.4 -name {sfp_mgt_refclk_0} [get_ports {sfp_mgt_refclk_p[0]}]
create_clock -period 6.4 -name {sfp_mgt_refclk_1} [get_ports {sfp_mgt_refclk_p[1]}]

set_false_path -from [get_ports {sfp_mod_abs[*]}]
set_input_delay 0 [get_ports {sfp_mod_abs[*]}]
set_false_path -to [get_ports {sfp_rs[*][*]}]
set_output_delay 0 [get_ports {sfp_rs[*][*]}]
set_false_path -to [get_ports {get_ports sfp_tx_disable[*]}]
set_output_delay 0 [get_ports {get_ports sfp_tx_disable[*]}]
# set_false_path -to [get_ports {sfp_i2c_scl[*] sfp_i2c_sda[*]}]
# set_output_delay 0 [get_ports {sfp_i2c_scl[*] sfp_i2c_sda[*]}]
# set_false_path -from [get_ports {sfp_i2c_scl[*] sfp_i2c_sda[*]}]
# set_input_delay 0 [get_ports {sfp_i2c_scl[*] sfp_i2c_sda[*]}]

# PCIe Interface
#set_property -dict {LOC AC4 } [get_ports {pcie_rx_p[0]}] ;# MGTHRXP3_115 GTHE2_CHANNEL_X0Y11 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AC3 } [get_ports {pcie_rx_n[0]}] ;# MGTHRXN3_115 GTHE2_CHANNEL_X0Y11 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AB2 } [get_ports {pcie_tx_p[0]}] ;# MGTHTXP3_115 GTHE2_CHANNEL_X0Y11 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AB1 } [get_ports {pcie_tx_n[0]}] ;# MGTHTXN3_115 GTHE2_CHANNEL_X0Y11 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AE4 } [get_ports {pcie_rx_p[1]}] ;# MGTHRXP2_115 GTHE2_CHANNEL_X0Y10 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AE3 } [get_ports {pcie_rx_n[1]}] ;# MGTHRXN2_115 GTHE2_CHANNEL_X0Y10 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AD2 } [get_ports {pcie_tx_p[1]}] ;# MGTHTXP2_115 GTHE2_CHANNEL_X0Y10 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AD1 } [get_ports {pcie_tx_n[1]}] ;# MGTHTXN2_115 GTHE2_CHANNEL_X0Y10 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AF6 } [get_ports {pcie_rx_p[2]}] ;# MGTHRXP1_115 GTHE2_CHANNEL_X0Y9 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AF5 } [get_ports {pcie_rx_n[2]}] ;# MGTHRXN1_115 GTHE2_CHANNEL_X0Y9 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AF2 } [get_ports {pcie_tx_p[2]}] ;# MGTHTXP1_115 GTHE2_CHANNEL_X0Y9 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AF1 } [get_ports {pcie_tx_n[2]}] ;# MGTHTXN1_115 GTHE2_CHANNEL_X0Y9 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AG4 } [get_ports {pcie_rx_p[3]}] ;# MGTHRXP0_115 GTHE2_CHANNEL_X0Y8 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AG3 } [get_ports {pcie_rx_n[3]}] ;# MGTHRXN0_115 GTHE2_CHANNEL_X0Y8 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AH2 } [get_ports {pcie_tx_p[3]}] ;# MGTHTXP0_115 GTHE2_CHANNEL_X0Y8 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AH1 } [get_ports {pcie_tx_n[3]}] ;# MGTHTXN0_115 GTHE2_CHANNEL_X0Y8 / GTHE2_COMMON_X0Y2
#set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[4]}] ;# MGTHRXP3_114 GTHE2_CHANNEL_X0Y7 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[4]}] ;# MGTHRXN3_114 GTHE2_CHANNEL_X0Y7 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AK2 } [get_ports {pcie_tx_p[4]}] ;# MGTHTXP3_114 GTHE2_CHANNEL_X0Y7 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AK1 } [get_ports {pcie_tx_n[4]}] ;# MGTHTXN3_114 GTHE2_CHANNEL_X0Y7 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AL4 } [get_ports {pcie_rx_p[5]}] ;# MGTHRXP2_114 GTHE2_CHANNEL_X0Y6 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AL3 } [get_ports {pcie_rx_n[5]}] ;# MGTHRXN2_114 GTHE2_CHANNEL_X0Y6 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AM2 } [get_ports {pcie_tx_p[5]}] ;# MGTHTXP2_114 GTHE2_CHANNEL_X0Y6 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AM1 } [get_ports {pcie_tx_n[5]}] ;# MGTHTXN2_114 GTHE2_CHANNEL_X0Y6 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AM6 } [get_ports {pcie_rx_p[6]}] ;# MGTHRXP1_114 GTHE2_CHANNEL_X0Y5 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AM5 } [get_ports {pcie_rx_n[6]}] ;# MGTHRXN1_114 GTHE2_CHANNEL_X0Y5 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AN4 } [get_ports {pcie_tx_p[6]}] ;# MGTHTXP1_114 GTHE2_CHANNEL_X0Y5 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AN3 } [get_ports {pcie_tx_n[6]}] ;# MGTHTXN1_114 GTHE2_CHANNEL_X0Y5 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AP6 } [get_ports {pcie_rx_p[7]}] ;# MGTHRXP0_114 GTHE2_CHANNEL_X0Y4 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AP5 } [get_ports {pcie_rx_n[7]}] ;# MGTHRXN0_114 GTHE2_CHANNEL_X0Y4 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AP2 } [get_ports {pcie_tx_p[7]}] ;# MGTHTXP0_114 GTHE2_CHANNEL_X0Y4 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AP1 } [get_ports {pcie_tx_n[7]}] ;# MGTHTXN0_114 GTHE2_CHANNEL_X0Y4 / GTHE2_COMMON_X0Y1
#set_property -dict {LOC AK6 } [get_ports pcie_mgt_refclk_p] ;# MGTREFCLK1P_115 via U28
#set_property -dict {LOC AK5 } [get_ports pcie_mgt_refclk_n] ;# MGTREFCLK1N_115 via U28
#set_property -dict {LOC AK32 IOSTANDARD LVCMOS18 PULLUP true} [get_ports pcie_reset]

# 100 MHz MGT reference clock
#create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_mgt_refclk_p]

#set_false_path -from [get_ports {pcie_reset}]
#set_input_delay 0 [get_ports {pcie_reset}]
