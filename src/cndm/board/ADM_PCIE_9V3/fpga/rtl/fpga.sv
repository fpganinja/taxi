// SPDX-License-Identifier: MIT
/*

Copyright (c) 2014-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA top-level module
 */
module fpga #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtexuplus",

    // FW ID
    parameter FPGA_ID = 32'h4B39093,
    parameter FW_ID = 32'h0000C001,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h4144_9003,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_W = 32,
    parameter AXIL_CTRL_ADDR_W = 24,

    // MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
)
(
    /*
     * Clock: 300MHz LVDS
     */
    input  wire logic         clk_300mhz_p,
    input  wire logic         clk_300mhz_n,

    /*
     * GPIO
     */
    output wire logic [1:0]   user_led_g,
    output wire logic         user_led_r,
    output wire logic [1:0]   front_led,
    input  wire logic [1:0]   user_sw,

    /*
     * Ethernet: QSFP28
     */
    output wire logic         qsfp_0_tx_p[4],
    output wire logic         qsfp_0_tx_n[4],
    input  wire logic         qsfp_0_rx_p[4],
    input  wire logic         qsfp_0_rx_n[4],
    input  wire logic         qsfp_0_mgt_refclk_p,
    input  wire logic         qsfp_0_mgt_refclk_n,
    input  wire logic         qsfp_0_modprs_l,
    output wire logic         qsfp_0_sel_l,

    output wire logic         qsfp_1_tx_p[4],
    output wire logic         qsfp_1_tx_n[4],
    input  wire logic         qsfp_1_rx_p[4],
    input  wire logic         qsfp_1_rx_n[4],
    // input  wire logic         qsfp_1_mgt_refclk_p,
    // input  wire logic         qsfp_1_mgt_refclk_n,
    input  wire logic         qsfp_1_modprs_l,
    output wire logic         qsfp_1_sel_l,

    output wire logic         qsfp_reset_l,
    input  wire logic         qsfp_int_l,

    /*
     * PCIe
     */
    input  wire logic [15:0]  pcie_rx_p,
    input  wire logic [15:0]  pcie_rx_n,
    output wire logic [15:0]  pcie_tx_p,
    output wire logic [15:0]  pcie_tx_n,
    input  wire logic         pcie_refclk_1_p,
    input  wire logic         pcie_refclk_1_n,
    input  wire logic         pcie_reset_n,

    /*
     * QSPI
     */
    inout  wire logic [3:0]   qspi_1_dq,
    output wire logic         qspi_1_cs
);

// Clock and reset
wire pcie_user_clk;
wire pcie_user_rst;

wire clk_300mhz_ibufg;

// Internal 125 MHz clock
wire clk_125mhz_mmcm_out;
wire clk_125mhz_int;
wire rst_125mhz_int;

wire mmcm_rst = 1'b0;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")
)
clk_300mhz_ibufg_inst (
   .O   (clk_300mhz_ibufg),
   .I   (clk_300mhz_p),
   .IB  (clk_300mhz_n)
);

// MMCM instance
MMCME4_BASE #(
    // 300 MHz input
    .CLKIN1_PERIOD(3.333),
    .REF_JITTER1(0.010),
    // 300 MHz input / 3 = 100 MHz PFD (range 10 MHz to 500 MHz)
    .DIVCLK_DIVIDE(3),
    // 100 MHz PFD * 12.5 = 1250 MHz VCO (range 800 MHz to 1600 MHz)
    .CLKFBOUT_MULT_F(12.5),
    .CLKFBOUT_PHASE(0),
    // 1250 MHz / 10 = 125 MHz, 0 degrees
    .CLKOUT0_DIVIDE_F(10),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    // Not used
    .CLKOUT1_DIVIDE(10),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(90),
    // Not used
    .CLKOUT2_DIVIDE(20),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    // Not used
    .CLKOUT3_DIVIDE(4),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0),
    // Not used
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0),
    .CLKOUT4_CASCADE("FALSE"),
    // Not used
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0),
    // Not used
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT6_PHASE(0),

    // optimized bandwidth
    .BANDWIDTH("OPTIMIZED"),
    // don't wait for lock during startup
    .STARTUP_WAIT("FALSE")
)
clk_mmcm_inst (
    // 300 MHz input
    .CLKIN1(clk_300mhz_ibufg),
    // direct clkfb feeback
    .CLKFBIN(mmcm_clkfb),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    // 125 MHz, 0 degrees
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    // Not used
    .CLKOUT1(),
    .CLKOUT1B(),
    // Not used
    .CLKOUT2(),
    .CLKOUT2B(),
    // Not used
    .CLKOUT3(),
    .CLKOUT3B(),
    // Not used
    .CLKOUT4(),
    // Not used
    .CLKOUT5(),
    // Not used
    .CLKOUT6(),
    // reset input
    .RST(mmcm_rst),
    // don't power down
    .PWRDWN(1'b0),
    // locked output
    .LOCKED(mmcm_locked)
);

BUFG
clk_125mhz_bufg_inst (
    .I(clk_125mhz_mmcm_out),
    .O(clk_125mhz_int)
);

taxi_sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

// GPIO
wire [1:0] user_sw_int;

taxi_debounce_switch #(
    .WIDTH(2),
    .N(4),
    .RATE(125000)
)
debounce_switch_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),
    .in({user_sw}),
    .out({user_sw_int})
);

// Flash
wire qspi_clk_int;
wire [3:0] qspi_0_dq_int;
wire [3:0] qspi_0_dq_i_int;
wire [3:0] qspi_0_dq_o_int;
wire [3:0] qspi_0_dq_oe_int;
wire qspi_0_cs_int;
wire [3:0] qspi_1_dq_i_int;
wire [3:0] qspi_1_dq_o_int;
wire [3:0] qspi_1_dq_oe_int;
wire qspi_1_cs_int;

logic qspi_clk_reg;
logic [3:0] qspi_0_dq_o_reg;
logic [3:0] qspi_0_dq_oe_reg;
logic qspi_0_cs_reg;
logic [3:0] qspi_1_dq_o_reg;
logic [3:0] qspi_1_dq_oe_reg;
logic qspi_1_cs_reg;

always_ff @(posedge pcie_user_clk) begin
    qspi_clk_reg <= qspi_clk_int;
    qspi_0_dq_o_reg <= qspi_0_dq_o_int;
    qspi_0_dq_oe_reg <= qspi_0_dq_oe_int;
    qspi_0_cs_reg <= qspi_0_cs_int;
    qspi_1_dq_o_reg <= qspi_1_dq_o_int;
    qspi_1_dq_oe_reg <= qspi_1_dq_oe_int;
    qspi_1_cs_reg <= qspi_1_cs_int;
end

assign qspi_1_dq[0] = qspi_1_dq_oe_reg[0] ? qspi_1_dq_o_reg[0] : 1'bz;
assign qspi_1_dq[1] = qspi_1_dq_oe_reg[1] ? qspi_1_dq_o_reg[1] : 1'bz;
assign qspi_1_dq[2] = qspi_1_dq_oe_reg[2] ? qspi_1_dq_o_reg[2] : 1'bz;
assign qspi_1_dq[3] = qspi_1_dq_oe_reg[3] ? qspi_1_dq_o_reg[3] : 1'bz;
assign qspi_1_cs = qspi_1_cs_reg;

taxi_sync_signal #(
    .WIDTH(8),
    .N(2)
)
flash_sync_signal_inst (
    .clk(pcie_user_clk),
    .in({qspi_1_dq, qspi_0_dq_int}),
    .out({qspi_1_dq_i_int, qspi_0_dq_i_int})
);

STARTUPE3
startupe3_inst (
    .CFGCLK(),
    .CFGMCLK(),
    .DI(qspi_0_dq_int),
    .DO(qspi_0_dq_o_reg),
    .DTS(~qspi_0_dq_oe_reg),
    .EOS(),
    .FCSBO(qspi_0_cs_reg),
    .FCSBTS(1'b0),
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b1),
    .PACK(1'b0),
    .PREQ(),
    .USRCCLKO(qspi_clk_reg),
    .USRCCLKTS(1'b0),
    .USRDONEO(1'b0),
    .USRDONETS(1'b1)
);

// FPGA boot
wire fpga_boot;
wire fpga_boot_sync;

taxi_sync_signal #(
    .WIDTH(1),
    .N(2)
)
fpga_boot_sync_inst (
    .clk(clk_125mhz_int),
    .in({fpga_boot}),
    .out({fpga_boot_sync})
);

wire icap_avail;
logic [2:0] icap_state_reg = 0;
logic icap_csib_reg = 1'b1;
logic icap_rdwrb_reg = 1'b0;
logic [31:0] icap_di_reg = 32'hffffffff;

wire [31:0] icap_di_rev;

assign icap_di_rev[ 7] = icap_di_reg[ 0];
assign icap_di_rev[ 6] = icap_di_reg[ 1];
assign icap_di_rev[ 5] = icap_di_reg[ 2];
assign icap_di_rev[ 4] = icap_di_reg[ 3];
assign icap_di_rev[ 3] = icap_di_reg[ 4];
assign icap_di_rev[ 2] = icap_di_reg[ 5];
assign icap_di_rev[ 1] = icap_di_reg[ 6];
assign icap_di_rev[ 0] = icap_di_reg[ 7];

assign icap_di_rev[15] = icap_di_reg[ 8];
assign icap_di_rev[14] = icap_di_reg[ 9];
assign icap_di_rev[13] = icap_di_reg[10];
assign icap_di_rev[12] = icap_di_reg[11];
assign icap_di_rev[11] = icap_di_reg[12];
assign icap_di_rev[10] = icap_di_reg[13];
assign icap_di_rev[ 9] = icap_di_reg[14];
assign icap_di_rev[ 8] = icap_di_reg[15];

assign icap_di_rev[23] = icap_di_reg[16];
assign icap_di_rev[22] = icap_di_reg[17];
assign icap_di_rev[21] = icap_di_reg[18];
assign icap_di_rev[20] = icap_di_reg[19];
assign icap_di_rev[19] = icap_di_reg[20];
assign icap_di_rev[18] = icap_di_reg[21];
assign icap_di_rev[17] = icap_di_reg[22];
assign icap_di_rev[16] = icap_di_reg[23];

assign icap_di_rev[31] = icap_di_reg[24];
assign icap_di_rev[30] = icap_di_reg[25];
assign icap_di_rev[29] = icap_di_reg[26];
assign icap_di_rev[28] = icap_di_reg[27];
assign icap_di_rev[27] = icap_di_reg[28];
assign icap_di_rev[26] = icap_di_reg[29];
assign icap_di_rev[25] = icap_di_reg[30];
assign icap_di_rev[24] = icap_di_reg[31];

always_ff @(posedge clk_125mhz_int) begin
    case (icap_state_reg)
        0: begin
            icap_state_reg <= 0;
            icap_csib_reg <= 1'b1;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'hffffffff; // dummy word

            if (fpga_boot_sync && icap_avail) begin
                icap_state_reg <= 1;
                icap_csib_reg <= 1'b0;
                icap_rdwrb_reg <= 1'b0;
                icap_di_reg <= 32'hffffffff; // dummy word
            end
        end
        1: begin
            icap_state_reg <= 2;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'hAA995566; // sync word
        end
        2: begin
            icap_state_reg <= 3;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h20000000; // type 1 noop
        end
        3: begin
            icap_state_reg <= 4;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h30008001; // write 1 word to CMD
        end
        4: begin
            icap_state_reg <= 5;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h0000000F; // IPROG
        end
        5: begin
            icap_state_reg <= 0;
            icap_csib_reg <= 1'b0;
            icap_rdwrb_reg <= 1'b0;
            icap_di_reg <= 32'h20000000; // type 1 noop
        end
    endcase
end

ICAPE3
icape3_inst (
    .AVAIL(icap_avail),
    .CLK(clk_125mhz_int),
    .CSIB(icap_csib_reg),
    .I(icap_di_rev),
    .O(),
    .PRDONE(),
    .PRERROR(),
    .RDWRB(icap_rdwrb_reg)
);

// PCIe
localparam AXIS_PCIE_DATA_W = 512;
localparam AXIS_PCIE_KEEP_W = (AXIS_PCIE_DATA_W/32);
localparam AXIS_PCIE_RC_USER_W = AXIS_PCIE_DATA_W < 512 ? 75 : 161;
localparam AXIS_PCIE_RQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 62 : 137;
localparam AXIS_PCIE_CQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 85 : 183;
localparam AXIS_PCIE_CC_USER_W = AXIS_PCIE_DATA_W < 512 ? 33 : 81;
localparam RC_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 256;
localparam RQ_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 512;
localparam CQ_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 512;
localparam CC_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 512;

localparam RQ_SEQ_NUM_W = AXIS_PCIE_RQ_USER_W == 60 ? 4 : 6;
localparam RQ_SEQ_NUM_EN = 1;

localparam PCIE_TAG_CNT = AXIS_PCIE_RQ_USER_W == 60 ? 64 : 256;
localparam BAR0_APERTURE = 24;

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_CQ_USER_W)
) axis_pcie_cq();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_CC_USER_W)
) axis_pcie_cc();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_RQ_USER_W)
) axis_pcie_rq();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_RC_USER_W)
) axis_pcie_rc();

wire [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num0;
wire pcie_rq_seq_num_vld0;
wire [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num1;
wire pcie_rq_seq_num_vld1;

wire [2:0] cfg_max_payload;
wire [2:0] cfg_max_read_req;
wire [3:0] cfg_rcb_status;

wire [9:0]  cfg_mgmt_addr;
wire [7:0]  cfg_mgmt_function_number;
wire        cfg_mgmt_write;
wire [31:0] cfg_mgmt_write_data;
wire [3:0]  cfg_mgmt_byte_enable;
wire        cfg_mgmt_read;
wire [31:0] cfg_mgmt_read_data;
wire        cfg_mgmt_read_write_done;

wire [7:0]  cfg_fc_ph;
wire [11:0] cfg_fc_pd;
wire [7:0]  cfg_fc_nph;
wire [11:0] cfg_fc_npd;
wire [7:0]  cfg_fc_cplh;
wire [11:0] cfg_fc_cpld;
wire [2:0]  cfg_fc_sel;

wire         cfg_ext_read_received;
wire         cfg_ext_write_received;
wire [9:0]   cfg_ext_register_number;
wire [7:0]   cfg_ext_function_number;
wire [31:0]  cfg_ext_write_data;
wire [3:0]   cfg_ext_write_byte_enable;
wire [31:0]  cfg_ext_read_data;
wire         cfg_ext_read_data_valid;

// wire [3:0]   cfg_interrupt_msix_enable;
// wire [3:0]   cfg_interrupt_msix_mask;
// wire [251:0] cfg_interrupt_msix_vf_enable;
// wire [251:0] cfg_interrupt_msix_vf_mask;
// wire [63:0]  cfg_interrupt_msix_address;
// wire [31:0]  cfg_interrupt_msix_data;
// wire         cfg_interrupt_msix_int;
// wire [1:0]   cfg_interrupt_msix_vec_pending;
// wire         cfg_interrupt_msix_vec_pending_status;
// wire         cfg_interrupt_msix_sent;
// wire         cfg_interrupt_msix_fail;
// wire [7:0]   cfg_interrupt_msi_function_number;

wire [3:0]   cfg_interrupt_msi_enable;
wire [11:0]  cfg_interrupt_msi_mmenable;
wire         cfg_interrupt_msi_mask_update;
wire [31:0]  cfg_interrupt_msi_data;
wire [1:0]   cfg_interrupt_msi_select;
wire [31:0]  cfg_interrupt_msi_int;
wire [31:0]  cfg_interrupt_msi_pending_status;
wire         cfg_interrupt_msi_pending_status_data_enable;
wire [1:0]   cfg_interrupt_msi_pending_status_function_num;
wire         cfg_interrupt_msi_sent;
wire         cfg_interrupt_msi_fail;
wire [2:0]   cfg_interrupt_msi_attr;
wire         cfg_interrupt_msi_tph_present;
wire [1:0]   cfg_interrupt_msi_tph_type;
wire [7:0]   cfg_interrupt_msi_tph_st_tag;
wire [7:0]   cfg_interrupt_msi_function_number;

wire stat_err_cor;
wire stat_err_uncor;

wire pcie_sys_clk;
wire pcie_sys_clk_gt;

IBUFDS_GTE4 #(
    .REFCLK_HROW_CK_SEL(2'b00)
)
ibufds_gte4_pcie_refclk_inst (
    .I             (pcie_refclk_1_p),
    .IB            (pcie_refclk_1_n),
    .CEB           (1'b0),
    .O             (pcie_sys_clk_gt),
    .ODIV2         (pcie_sys_clk)
);

pcie4_uscale_plus_0
pcie4_uscale_plus_inst (
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_rxn(pcie_rx_n),
    .pci_exp_rxp(pcie_rx_p),
    .user_clk(pcie_user_clk),
    .user_reset(pcie_user_rst),
    .user_lnk_up(),

    .s_axis_rq_tdata(axis_pcie_rq.tdata),
    .s_axis_rq_tkeep(axis_pcie_rq.tkeep),
    .s_axis_rq_tlast(axis_pcie_rq.tlast),
    .s_axis_rq_tready(axis_pcie_rq.tready),
    .s_axis_rq_tuser(axis_pcie_rq.tuser),
    .s_axis_rq_tvalid(axis_pcie_rq.tvalid),

    .m_axis_rc_tdata(axis_pcie_rc.tdata),
    .m_axis_rc_tkeep(axis_pcie_rc.tkeep),
    .m_axis_rc_tlast(axis_pcie_rc.tlast),
    .m_axis_rc_tready(axis_pcie_rc.tready),
    .m_axis_rc_tuser(axis_pcie_rc.tuser),
    .m_axis_rc_tvalid(axis_pcie_rc.tvalid),

    .m_axis_cq_tdata(axis_pcie_cq.tdata),
    .m_axis_cq_tkeep(axis_pcie_cq.tkeep),
    .m_axis_cq_tlast(axis_pcie_cq.tlast),
    .m_axis_cq_tready(axis_pcie_cq.tready),
    .m_axis_cq_tuser(axis_pcie_cq.tuser),
    .m_axis_cq_tvalid(axis_pcie_cq.tvalid),

    .s_axis_cc_tdata(axis_pcie_cc.tdata),
    .s_axis_cc_tkeep(axis_pcie_cc.tkeep),
    .s_axis_cc_tlast(axis_pcie_cc.tlast),
    .s_axis_cc_tready(axis_pcie_cc.tready),
    .s_axis_cc_tuser(axis_pcie_cc.tuser),
    .s_axis_cc_tvalid(axis_pcie_cc.tvalid),

    .pcie_rq_seq_num0(pcie_rq_seq_num0),
    .pcie_rq_seq_num_vld0(pcie_rq_seq_num_vld0),
    .pcie_rq_seq_num1(pcie_rq_seq_num1),
    .pcie_rq_seq_num_vld1(pcie_rq_seq_num_vld1),
    .pcie_rq_tag0(),
    .pcie_rq_tag1(),
    .pcie_rq_tag_av(),
    .pcie_rq_tag_vld0(),
    .pcie_rq_tag_vld1(),

    .pcie_tfc_nph_av(),
    .pcie_tfc_npd_av(),

    .pcie_cq_np_req(1'b1),
    .pcie_cq_np_req_count(),

    .cfg_phy_link_down(),
    .cfg_phy_link_status(),
    .cfg_negotiated_width(),
    .cfg_current_speed(),
    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_function_status(),
    .cfg_function_power_state(),
    .cfg_vf_status(),
    .cfg_vf_power_state(),
    .cfg_link_power_state(),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),
    .cfg_mgmt_debug_access(1'b0),

    .cfg_err_cor_out(),
    .cfg_err_nonfatal_out(),
    .cfg_err_fatal_out(),
    .cfg_local_error_valid(),
    .cfg_local_error_out(),
    .cfg_ltssm_state(),
    .cfg_rx_pm_state(),
    .cfg_tx_pm_state(),
    .cfg_rcb_status(cfg_rcb_status),
    .cfg_obff_enable(),
    .cfg_pl_status_change(),
    .cfg_tph_requester_enable(),
    .cfg_tph_st_mode(),
    .cfg_vf_tph_requester_enable(),
    .cfg_vf_tph_st_mode(),

    .cfg_msg_received(),
    .cfg_msg_received_data(),
    .cfg_msg_received_type(),
    .cfg_msg_transmit(1'b0),
    .cfg_msg_transmit_type(3'd0),
    .cfg_msg_transmit_data(32'd0),
    .cfg_msg_transmit_done(),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_dsn(64'd0),

    .cfg_bus_number(),

    .cfg_power_state_change_ack(1'b1),
    .cfg_power_state_change_interrupt(),

    .cfg_err_cor_in(stat_err_cor),
    .cfg_err_uncor_in(stat_err_uncor),
    .cfg_flr_in_process(),
    .cfg_flr_done(4'd0),
    .cfg_vf_flr_in_process(),
    .cfg_vf_flr_func_num(8'd0),
    .cfg_vf_flr_done(8'd0),

    .cfg_link_training_enable(1'b1),

    .cfg_ext_read_received(cfg_ext_read_received),
    .cfg_ext_write_received(cfg_ext_write_received),
    .cfg_ext_register_number(cfg_ext_register_number),
    .cfg_ext_function_number(cfg_ext_function_number),
    .cfg_ext_write_data(cfg_ext_write_data),
    .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    .cfg_ext_read_data(cfg_ext_read_data),
    .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

    .cfg_interrupt_int(4'd0),
    .cfg_interrupt_pending(4'd0),
    .cfg_interrupt_sent(),
    // .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    // .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    // .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    // .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    // .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    // .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    // .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    // .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    // .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    // .cfg_interrupt_msi_sent(cfg_interrupt_msix_sent),
    // .cfg_interrupt_msi_fail(cfg_interrupt_msix_fail),
    // .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),
    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_pending_status_data_enable(cfg_interrupt_msi_pending_status_data_enable),
    .cfg_interrupt_msi_pending_status_function_num(cfg_interrupt_msi_pending_status_function_num),
    .cfg_interrupt_msi_sent(cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_attr(cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_tph_present(cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_type(cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_tph_st_tag(cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    .cfg_pm_aspm_l1_entry_reject(1'b0),
    .cfg_pm_aspm_tx_l0s_entry_disable(1'b0),

    .cfg_hot_reset_out(),

    .cfg_config_space_enable(1'b1),
    .cfg_req_pm_transition_l23_ready(1'b0),
    .cfg_hot_reset_in(1'b0),

    .cfg_ds_port_number(8'd0),
    .cfg_ds_bus_number(8'd0),
    .cfg_ds_device_number(5'd0),

    .sys_clk(pcie_sys_clk),
    .sys_clk_gt(pcie_sys_clk_gt),
    .sys_reset(pcie_reset_n),

    .phy_rdy_out()
);

fpga_core #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),

    // FW ID
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),

    // PCIe interface configuration
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_W(AXIL_CTRL_DATA_W),
    .AXIL_CTRL_ADDR_W(AXIL_CTRL_ADDR_W),

    // MAC configuration
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),
    .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
    .MAC_DATA_W(MAC_DATA_W)
)
core_inst (
    /*
     * Clock: 125 MHz
     * Synchronous reset
     */
    .clk_125mhz(clk_125mhz_int),
    .rst_125mhz(rst_125mhz_int),

    /*
     * GPIO
     */
    .user_led_g(user_led_g),
    .user_led_r(user_led_r),
    .front_led(front_led),
    .user_sw(user_sw_int),

    /*
     * Ethernet: QSFP28
     */
    .qsfp_0_tx_p(qsfp_0_tx_p),
    .qsfp_0_tx_n(qsfp_0_tx_n),
    .qsfp_0_rx_p(qsfp_0_rx_p),
    .qsfp_0_rx_n(qsfp_0_rx_n),
    .qsfp_0_mgt_refclk_p(qsfp_0_mgt_refclk_p),
    .qsfp_0_mgt_refclk_n(qsfp_0_mgt_refclk_n),
    .qsfp_0_modprs_l(qsfp_0_modprs_l),
    .qsfp_0_sel_l(qsfp_0_sel_l),

    .qsfp_1_tx_p(qsfp_1_tx_p),
    .qsfp_1_tx_n(qsfp_1_tx_n),
    .qsfp_1_rx_p(qsfp_1_rx_p),
    .qsfp_1_rx_n(qsfp_1_rx_n),
    // .qsfp_1_mgt_refclk_p(qsfp_1_mgt_refclk_p),
    // .qsfp_1_mgt_refclk_n(qsfp_1_mgt_refclk_n),
    .qsfp_1_modprs_l(qsfp_1_modprs_l),
    .qsfp_1_sel_l(qsfp_1_sel_l),

    .qsfp_reset_l(qsfp_reset_l),
    .qsfp_int_l(qsfp_int_l),

    /*
     * PCIe
     */
    .pcie_clk(pcie_user_clk),
    .pcie_rst(pcie_user_rst),
    .s_axis_pcie_cq(axis_pcie_cq),
    .m_axis_pcie_cc(axis_pcie_cc),
    .m_axis_pcie_rq(axis_pcie_rq),
    .s_axis_pcie_rc(axis_pcie_rc),

    .pcie_rq_seq_num0(pcie_rq_seq_num0),
    .pcie_rq_seq_num_vld0(pcie_rq_seq_num_vld0),
    .pcie_rq_seq_num1(pcie_rq_seq_num1),
    .pcie_rq_seq_num_vld1(pcie_rq_seq_num_vld1),

    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_rcb_status(cfg_rcb_status),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_ext_read_received(cfg_ext_read_received),
    .cfg_ext_write_received(cfg_ext_write_received),
    .cfg_ext_register_number(cfg_ext_register_number),
    .cfg_ext_function_number(cfg_ext_function_number),
    .cfg_ext_write_data(cfg_ext_write_data),
    .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    .cfg_ext_read_data(cfg_ext_read_data),
    .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

    // .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    // .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    // .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    // .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    // .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    // .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    // .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    // .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    // .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    // .cfg_interrupt_msix_sent(cfg_interrupt_msix_sent),
    // .cfg_interrupt_msix_fail(cfg_interrupt_msix_fail),
    // .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_pending_status_data_enable(cfg_interrupt_msi_pending_status_data_enable),
    .cfg_interrupt_msi_pending_status_function_num(cfg_interrupt_msi_pending_status_function_num),
    .cfg_interrupt_msi_sent(cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_attr(cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_tph_present(cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_type(cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_tph_st_tag(cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    /*
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk_int),
    .qspi_0_dq_i(qspi_0_dq_i_int),
    .qspi_0_dq_o(qspi_0_dq_o_int),
    .qspi_0_dq_oe(qspi_0_dq_oe_int),
    .qspi_0_cs(qspi_0_cs_int),
    .qspi_1_dq_i(qspi_1_dq_i_int),
    .qspi_1_dq_o(qspi_1_dq_o_int),
    .qspi_1_dq_oe(qspi_1_dq_oe_int),
    .qspi_1_cs(qspi_1_cs_int)
);

endmodule

`resetall
