# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-R2 board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# RFDC
set_property -dict {LOC Y2  } [get_ports {adc_vin_p[0]}]  ;# ADC_VIN_I23_227_P from J7 (RA) via T5
set_property -dict {LOC Y1  } [get_ports {adc_vin_n[0]}]  ;# ADC_VIN_I23_227_N from J7 (RA) via T5
set_property -dict {LOC AB2 } [get_ports {adc_vin_p[1]}]  ;# ADC_VIN_I01_227_P from J17 (V) via T13
set_property -dict {LOC AB1 } [get_ports {adc_vin_n[1]}]  ;# ADC_VIN_I01_227_N from J17 (V) via T13
set_property -dict {LOC AD2 } [get_ports {adc_vin_p[2]}]  ;# ADC_VIN_I23_226_P from J8 (RA) via T6
set_property -dict {LOC AD1 } [get_ports {adc_vin_n[2]}]  ;# ADC_VIN_I23_226_N from J8 (RA) via T6
set_property -dict {LOC AF2 } [get_ports {adc_vin_p[3]}]  ;# ADC_VIN_I01_226_P from J18 (V) via T14
set_property -dict {LOC AF1 } [get_ports {adc_vin_n[3]}]  ;# ADC_VIN_I01_226_N from J18 (V) via T14
set_property -dict {LOC AH2 } [get_ports {adc_vin_p[4]}]  ;# ADC_VIN_I23_225_P from J9 (RA) via T7
set_property -dict {LOC AH1 } [get_ports {adc_vin_n[4]}]  ;# ADC_VIN_I23_225_N from J9 (RA) via T7
set_property -dict {LOC AK2 } [get_ports {adc_vin_p[5]}]  ;# ADC_VIN_I01_225_P from J19 (V) via T15
set_property -dict {LOC AK1 } [get_ports {adc_vin_n[5]}]  ;# ADC_VIN_I01_225_N from J19 (V) via T15
set_property -dict {LOC AM2 } [get_ports {adc_vin_p[6]}]  ;# ADC_VIN_I23_224_P from J10 (RA) via T8
set_property -dict {LOC AM1 } [get_ports {adc_vin_n[6]}]  ;# ADC_VIN_I23_224_N from J10 (RA) via T8
set_property -dict {LOC AP2 } [get_ports {adc_vin_p[7]}]  ;# ADC_VIN_I01_224_P from J20 (V) via T16
set_property -dict {LOC AP1 } [get_ports {adc_vin_n[7]}]  ;# ADC_VIN_I01_224_N from J20 (V) via T16

set_property -dict {LOC AF5 } [get_ports {adc_refclk_0_p}]  ;# ADC_224_REFCLK_P from U83.23 RFoutAP
set_property -dict {LOC AF4 } [get_ports {adc_refclk_0_n}]  ;# ADC_224_REFCLK_N from U83.22 RFoutAN
set_property -dict {LOC AD5 } [get_ports {adc_refclk_1_p}]  ;# ADC_225_REFCLK_P from U83.19 RFoutBP
set_property -dict {LOC AD4 } [get_ports {adc_refclk_1_n}]  ;# ADC_225_REFCLK_N from U83.18 RFoutBN
set_property -dict {LOC AB5 } [get_ports {adc_refclk_2_p}]  ;# ADC_226_REFCLK_P from U82.23 RFoutAP
set_property -dict {LOC AB4 } [get_ports {adc_refclk_2_n}]  ;# ADC_226_REFCLK_N from U82.22 RFoutAN
set_property -dict {LOC Y5  } [get_ports {adc_refclk_3_p}]  ;# ADC_227_REFCLK_P from U82.19 RFoutBP
set_property -dict {LOC Y4  } [get_ports {adc_refclk_3_n}]  ;# ADC_227_REFCLK_N from U82.18 RFoutBN

set_property -dict {LOC C2  } [get_ports {dac_vout_p[0]}]  ;# DAC_VOUT3_229_P from J3 (RA) via T1
set_property -dict {LOC C1  } [get_ports {dac_vout_n[0]}]  ;# DAC_VOUT3_229_N from J3 (RA) via T1
set_property -dict {LOC E2  } [get_ports {dac_vout_p[1]}]  ;# DAC_VOUT2_229_P from J13 (V) via T9
set_property -dict {LOC E1  } [get_ports {dac_vout_n[1]}]  ;# DAC_VOUT2_229_N from J13 (V) via T9
set_property -dict {LOC G2  } [get_ports {dac_vout_p[2]}]  ;# DAC_VOUT1_229_P from J4 (RA) via T2
set_property -dict {LOC G1  } [get_ports {dac_vout_n[2]}]  ;# DAC_VOUT1_229_N from J4 (RA) via T2
set_property -dict {LOC J2  } [get_ports {dac_vout_p[3]}]  ;# DAC_VOUT0_229_P from J14 (V) via T10
set_property -dict {LOC J1  } [get_ports {dac_vout_n[3]}]  ;# DAC_VOUT0_229_N from J14 (V) via T10
set_property -dict {LOC L2  } [get_ports {dac_vout_p[4]}]  ;# DAC_VOUT3_228_P from J5 (RA) via T3
set_property -dict {LOC L1  } [get_ports {dac_vout_n[4]}]  ;# DAC_VOUT3_228_N from J5 (RA) via T3
set_property -dict {LOC N2  } [get_ports {dac_vout_p[5]}]  ;# DAC_VOUT2_228_P from J15 (V) via T11
set_property -dict {LOC N1  } [get_ports {dac_vout_n[5]}]  ;# DAC_VOUT2_228_N from J15 (V) via T11
set_property -dict {LOC R2  } [get_ports {dac_vout_p[6]}]  ;# DAC_VOUT1_228_P from J6 (RA) via T4
set_property -dict {LOC R1  } [get_ports {dac_vout_n[6]}]  ;# DAC_VOUT1_228_N from J6 (RA) via T4
set_property -dict {LOC U2  } [get_ports {dac_vout_p[7]}]  ;# DAC_VOUT0_228_P from J16 (V) via T12
set_property -dict {LOC U1  } [get_ports {dac_vout_n[7]}]  ;# DAC_VOUT0_228_N from J16 (V) via T12

#set_property -dict {LOC R5  } [get_ports {dac_refclk_0_p}]  ;# DAC_228_REFCLK_P from U81.23 RFoutAP
#set_property -dict {LOC R4  } [get_ports {dac_refclk_0_n}]  ;# DAC_228_REFCLK_N from U81.22 RFoutAN
set_property -dict {LOC N5  } [get_ports {dac_refclk_1_p}]  ;# DAC_229_REFCLK_P from U81.19 RFoutBP
set_property -dict {LOC N4  } [get_ports {dac_refclk_1_n}]  ;# DAC_229_REFCLK_N from U81.18 RFoutBN

set_property -dict {LOC U5  } [get_ports {rfdc_sysref_p}]  ;# SYSREF_P_228 from U2.1 CLKout0_P
set_property -dict {LOC U4  } [get_ports {rfdc_sysref_n}]  ;# SYSREF_N_228 from U2.2 CLKout0_N
