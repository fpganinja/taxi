
create_ip -name pcie3_ultrascale -vendor xilinx.com -library ip -module_name pcie3_ultrascale_0

set_property -dict [list \
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} \
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
    CONFIG.AXISTEN_IF_RC_STRADDLE {false} \
    CONFIG.axisten_if_enable_client_tag {true} \
    CONFIG.axisten_if_width {256_bit} \
    CONFIG.extended_tag_field {true} \
    CONFIG.pf0_dev_cap_max_payload {1024_bytes} \
    CONFIG.axisten_freq {250} \
    CONFIG.PF0_Use_Class_Code_Lookup_Assistant {false} \
    CONFIG.pf0_class_code_base {02} \
    CONFIG.pf0_class_code_sub {00} \
    CONFIG.pf0_class_code_interface {00} \
    CONFIG.PF0_DEVICE_ID {C001} \
    CONFIG.PF0_SUBSYSTEM_ID {01a5} \
    CONFIG.PF0_SUBSYSTEM_VENDOR_ID {18f4} \
    CONFIG.pf0_bar0_64bit {true} \
    CONFIG.pf0_bar0_prefetchable {true} \
    CONFIG.pf0_bar0_scale {Megabytes} \
    CONFIG.pf0_bar0_size {16} \
    CONFIG.pf0_msi_enabled {true} \
    CONFIG.PF0_MSI_CAP_MULTIMSGCAP {32_vectors} \
    CONFIG.en_msi_per_vec_masking {true} \
    CONFIG.ext_pcie_cfg_space_enabled {true} \
    CONFIG.vendor_id {1234} \
    CONFIG.pcie_blk_locn {X0Y1} \
    CONFIG.mode_selection {Advanced} \
] [get_ips pcie3_ultrascale_0]
