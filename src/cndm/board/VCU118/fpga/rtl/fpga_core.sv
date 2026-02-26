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
 * FPGA core logic
 */
module fpga_core #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtexuplus",

    // FW ID
    parameter FPGA_ID = 32'h4B31093,
    parameter FW_ID = 32'h0000C001,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h10ee_9076,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,

    // PCIe interface configuration
    parameter RQ_SEQ_NUM_W = 6,

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
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire logic                     clk_125mhz,
    input  wire logic                     rst_125mhz,

    /*
     * GPIO
     */
    input  wire logic                     btnu,
    input  wire logic                     btnl,
    input  wire logic                     btnd,
    input  wire logic                     btnr,
    input  wire logic                     btnc,
    input  wire logic [3:0]               sw,
    output wire logic [7:0]               led,

    /*
     * UART: 115200 bps, 8N1
     */
    input  wire logic                     uart_rxd,
    output wire logic                     uart_txd,
    input  wire logic                     uart_rts,
    output wire logic                     uart_cts,

    /*
     * Ethernet: 1000BASE-T SGMII
     */
    input  wire logic                     phy_gmii_clk,
    input  wire logic                     phy_gmii_rst,
    input  wire logic                     phy_gmii_clk_en,
    input  wire logic [7:0]               phy_gmii_rxd,
    input  wire logic                     phy_gmii_rx_dv,
    input  wire logic                     phy_gmii_rx_er,
    output wire logic [7:0]               phy_gmii_txd,
    output wire logic                     phy_gmii_tx_en,
    output wire logic                     phy_gmii_tx_er,
    output wire logic                     phy_reset_n,
    input  wire logic                     phy_int_n,
    input  wire logic                     phy_mdio_i,
    output wire logic                     phy_mdio_o,
    output wire logic                     phy_mdio_t,
    output wire logic                     phy_mdc,

    /*
     * Ethernet: QSFP28
     */
    input  wire logic                     qsfp1_rx_p[4],
    input  wire logic                     qsfp1_rx_n[4],
    output wire logic                     qsfp1_tx_p[4],
    output wire logic                     qsfp1_tx_n[4],
    input  wire logic                     qsfp1_mgt_refclk_0_p,
    input  wire logic                     qsfp1_mgt_refclk_0_n,
    // input  wire logic                     qsfp1_mgt_refclk_1_p,
    // input  wire logic                     qsfp1_mgt_refclk_1_n,
    // output wire logic                     qsfp1_recclk_p,
    // output wire logic                     qsfp1_recclk_n,
    output wire logic                     qsfp1_modsell,
    output wire logic                     qsfp1_resetl,
    input  wire logic                     qsfp1_modprsl,
    input  wire logic                     qsfp1_intl,
    output wire logic                     qsfp1_lpmode,

    input  wire logic                     qsfp2_rx_p[4],
    input  wire logic                     qsfp2_rx_n[4],
    output wire logic                     qsfp2_tx_p[4],
    output wire logic                     qsfp2_tx_n[4],
    // input  wire logic                     qsfp2_mgt_refclk_0_p,
    // input  wire logic                     qsfp2_mgt_refclk_0_n,
    // input  wire logic                     qsfp2_mgt_refclk_1_p,
    // input  wire logic                     qsfp2_mgt_refclk_1_n,
    // output wire logic                     qsfp2_recclk_p,
    // output wire logic                     qsfp2_recclk_n,
    output wire logic                     qsfp2_modsell,
    output wire logic                     qsfp2_resetl,
    input  wire logic                     qsfp2_modprsl,
    input  wire logic                     qsfp2_intl,
    output wire logic                     qsfp2_lpmode,

    /*
     * PCIe
     */
    input  wire logic                     pcie_clk,
    input  wire logic                     pcie_rst,
    taxi_axis_if.snk                      s_axis_pcie_cq,
    taxi_axis_if.src                      m_axis_pcie_cc,
    taxi_axis_if.src                      m_axis_pcie_rq,
    taxi_axis_if.snk                      s_axis_pcie_rc,

    input  wire logic [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num0,
    input  wire logic                     pcie_rq_seq_num_vld0,
    input  wire logic [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num1,
    input  wire logic                     pcie_rq_seq_num_vld1,

    input  wire logic [2:0]               cfg_max_payload,
    input  wire logic [2:0]               cfg_max_read_req,
    input  wire logic [3:0]               cfg_rcb_status,

    output wire logic [9:0]               cfg_mgmt_addr,
    output wire logic [7:0]               cfg_mgmt_function_number,
    output wire logic                     cfg_mgmt_write,
    output wire logic [31:0]              cfg_mgmt_write_data,
    output wire logic [3:0]               cfg_mgmt_byte_enable,
    output wire logic                     cfg_mgmt_read,
    output wire logic [31:0]              cfg_mgmt_read_data,
    input  wire logic                     cfg_mgmt_read_write_done,

    input  wire logic [7:0]               cfg_fc_ph,
    input  wire logic [11:0]              cfg_fc_pd,
    input  wire logic [7:0]               cfg_fc_nph,
    input  wire logic [11:0]              cfg_fc_npd,
    input  wire logic [7:0]               cfg_fc_cplh,
    input  wire logic [11:0]              cfg_fc_cpld,
    output wire logic [2:0]               cfg_fc_sel,

    input  wire logic                     cfg_ext_read_received,
    input  wire logic                     cfg_ext_write_received,
    input  wire logic [9:0]               cfg_ext_register_number,
    input  wire logic [7:0]               cfg_ext_function_number,
    input  wire logic [31:0]              cfg_ext_write_data,
    input  wire logic [3:0]               cfg_ext_write_byte_enable,
    output wire logic [31:0]              cfg_ext_read_data,
    output wire logic                     cfg_ext_read_data_valid,

    input  wire logic [3:0]               cfg_interrupt_msi_enable,
    input  wire logic [11:0]              cfg_interrupt_msi_mmenable,
    input  wire logic                     cfg_interrupt_msi_mask_update,
    input  wire logic [31:0]              cfg_interrupt_msi_data,
    output wire logic [1:0]               cfg_interrupt_msi_select,
    output wire logic [31:0]              cfg_interrupt_msi_int,
    output wire logic [31:0]              cfg_interrupt_msi_pending_status,
    output wire logic                     cfg_interrupt_msi_pending_status_data_enable,
    output wire logic [1:0]               cfg_interrupt_msi_pending_status_function_num,
    input  wire logic                     cfg_interrupt_msi_sent,
    input  wire logic                     cfg_interrupt_msi_fail,
    output wire logic [2:0]               cfg_interrupt_msi_attr,
    output wire logic                     cfg_interrupt_msi_tph_present,
    output wire logic [1:0]               cfg_interrupt_msi_tph_type,
    output wire logic [7:0]               cfg_interrupt_msi_tph_st_tag,
    output wire logic [7:0]               cfg_interrupt_msi_function_number,

    /*
     * QSPI flash
     */
    output wire logic                     fpga_boot,
    output wire logic                     qspi_clk,
    input  wire logic [3:0]               qspi_0_dq_i,
    output wire logic [3:0]               qspi_0_dq_o,
    output wire logic [3:0]               qspi_0_dq_oe,
    output wire logic                     qspi_0_cs,
    input  wire logic [3:0]               qspi_1_dq_i,
    output wire logic [3:0]               qspi_1_dq_o,
    output wire logic [3:0]               qspi_1_dq_oe,
    output wire logic                     qspi_1_cs
);

localparam logic PTP_TS_FMT_TOD = 1'b0;
localparam PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 48;

// flashing via PCIe VPD
pyrite_pcie_us_vpd_qspi #(
    .VPD_CAP_ID(8'h03),
    .VPD_CAP_OFFSET(8'hB0),
    .VPD_CAP_NEXT(8'h00),

    // FW ID
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

    // Flash
    .FLASH_SEG_COUNT(2),
    .FLASH_SEG_DEFAULT(1),
    .FLASH_SEG_FALLBACK(0),
    .FLASH_SEG0_SIZE(32'h00000000),
    .FLASH_DATA_W(4),
    .FLASH_DUAL_QSPI(1'b1)
)
pyrite_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * PCIe
     */
    .cfg_ext_read_received(cfg_ext_read_received),
    .cfg_ext_write_received(cfg_ext_write_received),
    .cfg_ext_register_number(cfg_ext_register_number),
    .cfg_ext_function_number(cfg_ext_function_number),
    .cfg_ext_write_data(cfg_ext_write_data),
    .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    .cfg_ext_read_data(cfg_ext_read_data),
    .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

    /*
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk),
    .qspi_0_dq_i(qspi_0_dq_i),
    .qspi_0_dq_o(qspi_0_dq_o),
    .qspi_0_dq_oe(qspi_0_dq_oe),
    .qspi_0_cs(qspi_0_cs),
    .qspi_1_dq_i(qspi_1_dq_i),
    .qspi_1_dq_o(qspi_1_dq_o),
    .qspi_1_dq_oe(qspi_1_dq_oe),
    .qspi_1_cs(qspi_1_cs)
);

// XFCP
taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_ds(), xfcp_us();

taxi_xfcp_if_uart #(
    .TX_FIFO_DEPTH(512),
    .RX_FIFO_DEPTH(512)
)
xfcp_if_uart_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * UART interface
     */
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),

    /*
     * XFCP downstream interface
     */
    .xfcp_dsp_ds(xfcp_ds),
    .xfcp_dsp_us(xfcp_us),

    /*
     * Configuration
     */
    .prescale(16'(125000000/921600))
);

localparam XFCP_PORTS = 1+2;

taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_sw_ds[XFCP_PORTS](), xfcp_sw_us[XFCP_PORTS]();

taxi_xfcp_switch #(
    .XFCP_ID_STR("VCU118"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR("Taxi example"),
    .PORTS($size(xfcp_sw_us))
)
xfcp_sw_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_ds),
    .xfcp_usp_us(xfcp_us),

    /*
     * XFCP downstream ports
     */
    .xfcp_dsp_ds(xfcp_sw_ds),
    .xfcp_dsp_us(xfcp_sw_us)
);

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_stat();

taxi_xfcp_mod_stats #(
    .XFCP_ID_STR("Statistics"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR(""),
    .STAT_COUNT_W(64),
    .STAT_PIPELINE(2)
)
xfcp_stats_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_sw_ds[0]),
    .xfcp_usp_us(xfcp_sw_us[0]),

    /*
     * Statistics increment input
     */
    .s_axis_stat(axis_stat)
);

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_eth_stat[3]();

taxi_axis_arb_mux #(
    .S_COUNT($size(axis_eth_stat)),
    .UPDATE_TID(1'b0),
    .ARB_ROUND_ROBIN(1'b1),
    .ARB_LSB_HIGH_PRIO(1'b0)
)
stat_mux_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * AXI4-Stream inputs (sink)
     */
    .s_axis(axis_eth_stat),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(axis_stat)
);

// BASE-T PHY
assign phy_reset_n = !rst_125mhz;

taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_eth();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_tx_cpl();

taxi_eth_mac_1g_fifo #(
    .PADDING_EN(1),
    .MIN_FRAME_LEN(64),
    .STAT_EN(1),
    .STAT_TX_LEVEL(1),
    .STAT_RX_LEVEL(1),
    .STAT_ID_BASE(0),
    .STAT_UPDATE_PERIOD(1024),
    .STAT_STR_EN(1),
    .STAT_PREFIX_STR("SGMII0"),
    .TX_FIFO_DEPTH(16384),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(16384),
    .RX_FRAME_FIFO(1)
)
eth_mac_inst (
    .rx_clk(phy_gmii_clk),
    .rx_rst(phy_gmii_rst),
    .tx_clk(phy_gmii_clk),
    .tx_rst(phy_gmii_rst),
    .logic_clk(clk_125mhz),
    .logic_rst(rst_125mhz),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_eth),
    .m_axis_tx_cpl(axis_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_eth),

    /*
     * GMII interface
     */
    .gmii_rxd(phy_gmii_rxd),
    .gmii_rx_dv(phy_gmii_rx_dv),
    .gmii_rx_er(phy_gmii_rx_er),
    .gmii_txd(phy_gmii_txd),
    .gmii_tx_en(phy_gmii_tx_en),
    .gmii_tx_er(phy_gmii_tx_er),

    /*
     * Control
     */
    .rx_clk_enable(phy_gmii_clk_en),
    .tx_clk_enable(phy_gmii_clk_en),
    .rx_mii_select(1'b0),
    .tx_mii_select(1'b0),

    /*
     * Statistics
     */
    .stat_clk(clk_125mhz),
    .stat_rst(rst_125mhz),
    .m_axis_stat(axis_eth_stat[0]),

    /*
     * Status
     */
    .tx_error_underflow(),
    .tx_fifo_overflow(),
    .tx_fifo_bad_frame(),
    .tx_fifo_good_frame(),
    .rx_error_bad_frame(),
    .rx_error_bad_fcs(),
    .rx_fifo_overflow(),
    .rx_fifo_bad_frame(),
    .rx_fifo_good_frame(),

    /*
     * Configuration
     */
    .cfg_tx_max_pkt_len(16'd9218),
    .cfg_tx_ifg(8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_max_pkt_len(16'd9218),
    .cfg_rx_enable(1'b1)
);

// PHY MDIO init
reg [19:0] delay_reg = '1;

reg [1:0] mdio_cmd_st_reg = 2'b01; // clause 22
reg [1:0] mdio_cmd_op_reg = 2'b01; // write
reg [4:0] mdio_cmd_phy_addr_reg = 5'h03;
reg [4:0] mdio_cmd_reg_addr_reg = 5'h00;
reg [15:0] mdio_cmd_data_reg = '0;
reg mdio_cmd_valid_reg = 1'b0;
wire mdio_cmd_ready;

taxi_axis_if #(.DATA_W(32)) axis_mdio_cmd();
taxi_axis_if #(.DATA_W(16)) axis_mdio_rd_data();

assign axis_mdio_cmd.tdata = {mdio_cmd_st_reg, mdio_cmd_op_reg, mdio_cmd_phy_addr_reg, mdio_cmd_reg_addr_reg, 2'b10, mdio_cmd_data_reg};
assign axis_mdio_cmd.tvalid = mdio_cmd_valid_reg;
assign mdio_cmd_ready = axis_mdio_cmd.tready;

assign axis_mdio_rd_data.tready = 1'b1;

reg [3:0] state_reg = '0;

always_ff @(posedge clk_125mhz) begin
    mdio_cmd_valid_reg <= mdio_cmd_valid_reg && !mdio_cmd_ready;

    if (delay_reg != 0) begin
        delay_reg <= delay_reg - 1;
    end else if (mdio_cmd_valid_reg) begin
        // wait for ready
        state_reg <= state_reg;
    end else begin
        case (state_reg)
            // set SGMII autonegotiation timer to 11 ms
            // write 0x0070 to CFG4 (0x0031)
            4'd0: begin
                // write to REGCR to load address
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h001F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd1;
            end
            4'd1: begin
                // write address of CFG4 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h0031;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd2;
            end
            4'd2: begin
                // write to REGCR to load data
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h401F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd3;
            end
            4'd3: begin
                // write data for CFG4 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h0070;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd4;
            end
            // enable SGMII clock output
            // write 0x4000 to SGMIICTL1 (0x00D3)
            4'd4: begin
                // write to REGCR to load address
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h001F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd5;
            end
            4'd5: begin
                // write address of SGMIICTL1 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h00D3;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd6;
            end
            4'd6: begin
                // write to REGCR to load data
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h401F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd7;
            end
            4'd7: begin
                // write data for SGMIICTL1 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h4000;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd8;
            end
            // enable 10Mbps operation
            // write 0x0015 to 10M_SGMII_CFG (0x016F)
            4'd8: begin
                // write to REGCR to load address
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h001F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd9;
            end
            4'd9: begin
                // write address of 10M_SGMII_CFG to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h016F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd10;
            end
            4'd10: begin
                // write to REGCR to load data
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h401F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd11;
            end
            4'd11: begin
                // write data for 10M_SGMII_CFG to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h0015;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd12;
            end
            4'd12: begin
                // done
                state_reg <= 4'd12;
            end
            default: begin
                // go to idle
                state_reg <= 4'd0;
            end
        endcase
    end

    if (rst_125mhz) begin
        state_reg <= '0;
        delay_reg <= SIM ? 100 : '1;
        mdio_cmd_valid_reg <= 1'b0;
    end
end

taxi_mdio_master
mdio_master_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    .s_axis_cmd(axis_mdio_cmd),
    .m_axis_rd_data(axis_mdio_rd_data),

    .mdc_o(phy_mdc),
    .mdio_i(phy_mdio_i),
    .mdio_o(phy_mdio_o),
    .mdio_t(phy_mdio_t),

    .busy(),

    // The TI DP83867IS PHY chip supports an MDC frequency of 25 MHz
    .prescale(8'(125/25/2))
);

// QSFP28
assign qsfp1_modsell = 1'b0;
assign qsfp1_resetl = 1'b1;
assign qsfp1_lpmode = 1'b0;
assign qsfp2_modsell = 1'b0;
assign qsfp2_resetl = 1'b1;
assign qsfp2_lpmode = 1'b0;

wire qsfp_tx_clk[8];
wire qsfp_tx_rst[8];
wire qsfp_rx_clk[8];
wire qsfp_rx_rst[8];

wire qsfp_rx_status[8];

for (genvar n = 0; n < 8; n = n + 1) begin
    assign led[n] = qsfp_rx_status[n];
end

wire [1:0] qsfp_gtpowergood;

wire qsfp1_mgt_refclk_0;
wire qsfp1_mgt_refclk_0_int;
wire qsfp1_mgt_refclk_0_bufg;

wire qsfp_rst;

taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_qsfp_tx[8]();
taxi_axis_if #(.DATA_W(PTP_TS_W), .KEEP_W(1), .ID_W(8)) axis_qsfp_tx_cpl[8]();
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1+PTP_TS_W)) axis_qsfp_rx[8]();

if (SIM) begin

    assign qsfp1_mgt_refclk_0 = qsfp1_mgt_refclk_0_p;
    assign qsfp1_mgt_refclk_0_int = qsfp1_mgt_refclk_0_p;
    assign qsfp1_mgt_refclk_0_bufg = qsfp1_mgt_refclk_0_int;

end else begin

    IBUFDS_GTE4 ibufds_gte4_qsfp1_mgt_refclk_0_inst (
        .I     (qsfp1_mgt_refclk_0_p),
        .IB    (qsfp1_mgt_refclk_0_n),
        .CEB   (1'b0),
        .O     (qsfp1_mgt_refclk_0),
        .ODIV2 (qsfp1_mgt_refclk_0_int)
    );

    BUFG_GT bufg_gt_qsfp1_mgt_refclk_0_inst (
        .CE      (&qsfp_gtpowergood),
        .CEMASK  (1'b1),
        .CLR     (1'b0),
        .CLRMASK (1'b1),
        .DIV     (3'd0),
        .I       (qsfp1_mgt_refclk_0_int),
        .O       (qsfp1_mgt_refclk_0_bufg)
    );

end

taxi_sync_reset #(
    .N(4)
)
qsfp_sync_reset_inst (
    .clk(qsfp1_mgt_refclk_0_bufg),
    .rst(rst_125mhz),
    .out(qsfp_rst)
);

wire qsfp_tx_p[8];
wire qsfp_tx_n[8];
wire qsfp_rx_p[8];
wire qsfp_rx_n[8];

assign qsfp1_tx_p = qsfp_tx_p[4*0 +: 4];
assign qsfp1_tx_n = qsfp_tx_n[4*0 +: 4];
assign qsfp2_tx_p = qsfp_tx_p[4*1 +: 4];
assign qsfp2_tx_n = qsfp_tx_n[4*1 +: 4];

assign qsfp_rx_p[4*0 +: 4] = qsfp1_rx_p;
assign qsfp_rx_n[4*0 +: 4] = qsfp1_rx_n;
assign qsfp_rx_p[4*1 +: 4] = qsfp2_rx_p;
assign qsfp_rx_n[4*1 +: 4] = qsfp2_rx_n;

wire ptp_clk = qsfp1_mgt_refclk_0_bufg;
wire ptp_rst = qsfp_rst;
wire ptp_sample_clk = clk_125mhz;
wire ptp_td_sd;
wire ptp_pps;
wire ptp_pps_str;

// assign led[7] = ptp_pps_str;

localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP1[4] = '{"QSFP1.1", "QSFP1.2", "QSFP1.3",  "QSFP1.4"};
localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP2[4] = '{"QSFP2.1", "QSFP2.2", "QSFP2.3",  "QSFP2.4"};

for (genvar n = 0; n < 2; n = n + 1) begin : gty_quad

    localparam CNT = 4;

    taxi_apb_if #(
        .ADDR_W(18),
        .DATA_W(16)
    )
    gt_apb_ctrl();

    taxi_xfcp_mod_apb #(
        .XFCP_EXT_ID_STR("GTY CTRL")
    )
    xfcp_mod_apb_inst (
        .clk(clk_125mhz),
        .rst(rst_125mhz),

        /*
         * XFCP upstream port
         */
        .xfcp_usp_ds(xfcp_sw_ds[n+1]),
        .xfcp_usp_us(xfcp_sw_us[n+1]),

        /*
         * APB master interface
         */
        .m_apb(gt_apb_ctrl)
    );

    taxi_eth_mac_25g_us #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .CNT(4),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE("GTY"),

        // MAC/PHY config
        .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
        .DATA_W(MAC_DATA_W),
        .PADDING_EN(1'b1),
        .DIC_EN(1'b1),
        .MIN_FRAME_LEN(64),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TD_EN(PTP_TS_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W),
        .PTP_TD_SDI_PIPELINE(2),
        .PRBS31_EN(1'b0),
        .TX_SERDES_PIPELINE(1),
        .RX_SERDES_PIPELINE(1),
        .COUNT_125US(125000/6.4),
        .STAT_EN(1),
        .STAT_TX_LEVEL(1),
        .STAT_RX_LEVEL(1),
        .STAT_ID_BASE((16+16)+n*CNT*(16+16)),
        .STAT_UPDATE_PERIOD(1024),
        .STAT_STR_EN(1),
        .STAT_PREFIX_STR(n == 0 ? STAT_PREFIX_STR_QSFP1 : STAT_PREFIX_STR_QSFP2)
    )
    mac_inst (
        .xcvr_ctrl_clk(clk_125mhz),
        .xcvr_ctrl_rst(qsfp_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(gt_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(qsfp_gtpowergood[n]),
        .xcvr_gtrefclk00_in(qsfp1_mgt_refclk_0),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'd0),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(qsfp1_mgt_refclk_0),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'd0),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        /*
         * Serial data
         */
        .xcvr_txp(qsfp_tx_p[n*CNT +: CNT]),
        .xcvr_txn(qsfp_tx_n[n*CNT +: CNT]),
        .xcvr_rxp(qsfp_rx_p[n*CNT +: CNT]),
        .xcvr_rxn(qsfp_rx_n[n*CNT +: CNT]),

        /*
         * MAC clocks
         */
        .rx_clk(qsfp_rx_clk[n*CNT +: CNT]),
        .rx_rst_in('{CNT{1'b0}}),
        .rx_rst_out(qsfp_rx_rst[n*CNT +: CNT]),
        .tx_clk(qsfp_tx_clk[n*CNT +: CNT]),
        .tx_rst_in('{CNT{1'b0}}),
        .tx_rst_out(qsfp_tx_rst[n*CNT +: CNT]),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_qsfp_tx[n*CNT +: CNT]),
        .m_axis_tx_cpl(axis_qsfp_tx_cpl[n*CNT +: CNT]),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_qsfp_rx[n*CNT +: CNT]),

        /*
         * PTP clock
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sdi(ptp_td_sd),
        .tx_ptp_ts_in('{CNT{'0}}),
        .tx_ptp_ts_out(),
        .tx_ptp_ts_step_out(),
        .tx_ptp_locked(),
        .rx_ptp_ts_in('{CNT{'0}}),
        .rx_ptp_ts_out(),
        .rx_ptp_ts_step_out(),
        .rx_ptp_locked(),

        /*
         * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
         */
        .tx_lfc_req('{CNT{1'b0}}),
        .tx_lfc_resend('{CNT{1'b0}}),
        .rx_lfc_en('{CNT{1'b0}}),
        .rx_lfc_req(),
        .rx_lfc_ack('{CNT{1'b0}}),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
         */
        .tx_pfc_req('{CNT{'0}}),
        .tx_pfc_resend('{CNT{1'b0}}),
        .rx_pfc_en('{CNT{'0}}),
        .rx_pfc_req(),
        .rx_pfc_ack('{CNT{'0}}),

        /*
         * Pause interface
         */
        .tx_lfc_pause_en('{CNT{1'b0}}),
        .tx_pause_req('{CNT{1'b0}}),
        .tx_pause_ack(),

        /*
         * Statistics
         */
        .stat_clk(clk_125mhz),
        .stat_rst(rst_125mhz),
        .m_axis_stat(axis_eth_stat[n+1]),

        /*
         * Status
         */
        .tx_start_packet(),
        .stat_tx_byte(),
        .stat_tx_pkt_len(),
        .stat_tx_pkt_ucast(),
        .stat_tx_pkt_mcast(),
        .stat_tx_pkt_bcast(),
        .stat_tx_pkt_vlan(),
        .stat_tx_pkt_good(),
        .stat_tx_pkt_bad(),
        .stat_tx_err_oversize(),
        .stat_tx_err_user(),
        .stat_tx_err_underflow(),
        .rx_start_packet(),
        .rx_error_count(),
        .rx_block_lock(),
        .rx_high_ber(),
        .rx_status(qsfp_rx_status[n*CNT +: CNT]),
        .stat_rx_byte(),
        .stat_rx_pkt_len(),
        .stat_rx_pkt_fragment(),
        .stat_rx_pkt_jabber(),
        .stat_rx_pkt_ucast(),
        .stat_rx_pkt_mcast(),
        .stat_rx_pkt_bcast(),
        .stat_rx_pkt_vlan(),
        .stat_rx_pkt_good(),
        .stat_rx_pkt_bad(),
        .stat_rx_err_oversize(),
        .stat_rx_err_bad_fcs(),
        .stat_rx_err_bad_block(),
        .stat_rx_err_framing(),
        .stat_rx_err_preamble(),
        .stat_rx_fifo_drop('{CNT{1'b0}}),
        .stat_tx_mcf(),
        .stat_rx_mcf(),
        .stat_tx_lfc_pkt(),
        .stat_tx_lfc_xon(),
        .stat_tx_lfc_xoff(),
        .stat_tx_lfc_paused(),
        .stat_tx_pfc_pkt(),
        .stat_tx_pfc_xon(),
        .stat_tx_pfc_xoff(),
        .stat_tx_pfc_paused(),
        .stat_rx_lfc_pkt(),
        .stat_rx_lfc_xon(),
        .stat_rx_lfc_xoff(),
        .stat_rx_lfc_paused(),
        .stat_rx_pfc_pkt(),
        .stat_rx_pfc_xon(),
        .stat_rx_pfc_xoff(),
        .stat_rx_pfc_paused(),

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len('{CNT{16'd9218}}),
        .cfg_tx_ifg('{CNT{8'd12}}),
        .cfg_tx_enable('{CNT{1'b1}}),
        .cfg_rx_max_pkt_len('{CNT{16'd9218}}),
        .cfg_rx_enable('{CNT{1'b1}}),
        .cfg_tx_prbs31_enable('{CNT{1'b0}}),
        .cfg_rx_prbs31_enable('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_dst_mcast('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_mcf_rx_check_eth_dst_mcast('{CNT{1'b1}}),
        .cfg_mcf_rx_eth_dst_ucast('{CNT{48'd0}}),
        .cfg_mcf_rx_check_eth_dst_ucast('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_src('{CNT{48'd0}}),
        .cfg_mcf_rx_check_eth_src('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_type('{CNT{16'h8808}}),
        .cfg_mcf_rx_opcode_lfc('{CNT{16'h0001}}),
        .cfg_mcf_rx_check_opcode_lfc('{CNT{1'b1}}),
        .cfg_mcf_rx_opcode_pfc('{CNT{16'h0101}}),
        .cfg_mcf_rx_check_opcode_pfc('{CNT{1'b1}}),
        .cfg_mcf_rx_forward('{CNT{1'b0}}),
        .cfg_mcf_rx_enable('{CNT{1'b0}}),
        .cfg_tx_lfc_eth_dst('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_tx_lfc_eth_src('{CNT{48'h80_23_31_43_54_4C}}),
        .cfg_tx_lfc_eth_type('{CNT{16'h8808}}),
        .cfg_tx_lfc_opcode('{CNT{16'h0001}}),
        .cfg_tx_lfc_en('{CNT{1'b0}}),
        .cfg_tx_lfc_quanta('{CNT{16'hffff}}),
        .cfg_tx_lfc_refresh('{CNT{16'h7fff}}),
        .cfg_tx_pfc_eth_dst('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_tx_pfc_eth_src('{CNT{48'h80_23_31_43_54_4C}}),
        .cfg_tx_pfc_eth_type('{CNT{16'h8808}}),
        .cfg_tx_pfc_opcode('{CNT{16'h0101}}),
        .cfg_tx_pfc_en('{CNT{1'b0}}),
        .cfg_tx_pfc_quanta('{CNT{'{8{16'hffff}}}}),
        .cfg_tx_pfc_refresh('{CNT{'{8{16'h7fff}}}}),
        .cfg_rx_lfc_opcode('{CNT{16'h0001}}),
        .cfg_rx_lfc_en('{CNT{1'b0}}),
        .cfg_rx_pfc_opcode('{CNT{16'h0101}}),
        .cfg_rx_pfc_en('{CNT{1'b0}})
    );

end

cndm_micro_pcie_us #(
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

    // Structural configuration
    .PORTS(8),

    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(1'b0),
    .PTP_CLK_PER_NS_NUM(32),
    .PTP_CLK_PER_NS_DENOM(5),

    // PCIe interface configuration
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_W(AXIL_CTRL_DATA_W),
    .AXIL_CTRL_ADDR_W(AXIL_CTRL_ADDR_W)
)
cndm_inst (
    /*
     * PCIe
     */
    .pcie_clk(pcie_clk),
    .pcie_rst(pcie_rst),
    .s_axis_pcie_cq(s_axis_pcie_cq),
    .m_axis_pcie_cc(m_axis_pcie_cc),
    .m_axis_pcie_rq(m_axis_pcie_rq),
    .s_axis_pcie_rc(s_axis_pcie_rc),

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
     * PTP
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sdo(ptp_td_sd),
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_sync_locked(),
    .ptp_sync_ts_rel(),
    .ptp_sync_ts_rel_step(),
    .ptp_sync_ts_tod(),
    .ptp_sync_ts_tod_step(),
    .ptp_sync_pps(),
    .ptp_sync_pps_str(),

    /*
     * Ethernet
     */
    .mac_tx_clk(qsfp_tx_clk),
    .mac_tx_rst(qsfp_tx_rst),
    .mac_axis_tx(axis_qsfp_tx),
    .mac_axis_tx_cpl(axis_qsfp_tx_cpl),

    .mac_rx_clk(qsfp_rx_clk),
    .mac_rx_rst(qsfp_rx_rst),
    .mac_axis_rx(axis_qsfp_rx)
);

endmodule

`resetall
