`include "hw_config.vh"

module cluster_wrapper # (
    parameter integer MAX_PES = `MAX_PES,
    parameter integer MAX_INPUT_SIZE = `MAX_INPUT_SIZE,
////////////// config axi parameters
    parameter integer CONFIG_SIZE = 8,
    parameter integer C_S00_AXI_ID_WIDTH	= 12,
    parameter integer C_S00_AXI_DATA_WIDTH	= 32,
    parameter integer C_S00_AXI_ADDR_WIDTH	= $clog2(CONFIG_SIZE),
    parameter integer C_S00_AXI_AWUSER_WIDTH	= 0,
    parameter integer C_S00_AXI_ARUSER_WIDTH	= 0,
    parameter integer C_S00_AXI_WUSER_WIDTH	= 0,
    parameter integer C_S00_AXI_RUSER_WIDTH	= 0,
    parameter integer C_S00_AXI_BUSER_WIDTH	= 0,
////////////// input_weight axi parameters

    parameter integer BLOCK_NUM = MAX_PES + 1,
    parameter integer BLOCK_SIZE = MAX_INPUT_SIZE,
    parameter integer DATA_WIDTH = `WEIGHT_MEM_D_W,
    parameter integer INPUT_WEIGHT_ADDR_WIDTH = $clog2(BLOCK_SIZE),
    parameter integer WEIGHT_DATA_WIDTH = `WEIGHT_MEM_D_W,
    parameter integer INPUT_DATA_WIDTH = `INPUT_D_W,

    parameter integer C_S01_AXI_ID_WIDTH	= 12,
    parameter integer C_S01_AXI_DATA_WIDTH	= 32,

    parameter integer C_S01_AXI_ADDR_WIDTH	= $clog2(BLOCK_NUM * BLOCK_SIZE),
    parameter integer C_S01_AXI_AWUSER_WIDTH	= 0,
    parameter integer C_S01_AXI_ARUSER_WIDTH	= 0,
    parameter integer C_S01_AXI_WUSER_WIDTH	= 0,
    parameter integer C_S01_AXI_RUSER_WIDTH	= 0,
    parameter integer C_S01_AXI_BUSER_WIDTH	= 0,

    ///////////// register_array axi parameters
    parameter integer BYTE_REG_NUM = MAX_PES << 2,

    parameter integer C_S02_AXI_ID_WIDTH	= 12,
    parameter integer C_S02_AXI_DATA_WIDTH	= 32,

    parameter integer C_S02_AXI_ADDR_WIDTH	= $clog2(BYTE_REG_NUM),
    parameter integer C_S02_AXI_AWUSER_WIDTH	= 0,
    parameter integer C_S02_AXI_ARUSER_WIDTH	= 0,
    parameter integer C_S02_AXI_WUSER_WIDTH	= 0,
    parameter integer C_S02_AXI_RUSER_WIDTH	= 0,
    parameter integer C_S02_AXI_BUSER_WIDTH	= 0

    
)(

    output debug_start,
    output [31:0] debug_reg_0,
    output wire [`OUTPUT_NUM_WIDTH-1:0] output_num,
    output wire [`INPUT_NUM_WIDTH - 1 : 0] input_num,

    output wire ra_ld_axi,
    output wire ra_ld_acc,
    output wire axi_ram_ld,

    output wire logic_wen,
    output wire done,

    input wire logic_clk,
    input wire logic_rstn,
    /// config axi port
    input wire  s00_axi_aclk,
    input wire  s00_axi_aresetn,
    input wire [C_S00_AXI_ID_WIDTH-1 : 0] s00_axi_awid,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [7 : 0] s00_axi_awlen,
    input wire [2 : 0] s00_axi_awsize,
    input wire [1 : 0] s00_axi_awburst,
    input wire  s00_axi_awlock,
    input wire [3 : 0] s00_axi_awcache,
    input wire [2 : 0] s00_axi_awprot,
    input wire [3 : 0] s00_axi_awqos,
    input wire [3 : 0] s00_axi_awregion,
    input wire [C_S00_AXI_AWUSER_WIDTH-1 : 0] s00_axi_awuser,
    input wire  s00_axi_awvalid,
    output wire  s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire  s00_axi_wlast,
    input wire [C_S00_AXI_WUSER_WIDTH-1 : 0] s00_axi_wuser,
    input wire  s00_axi_wvalid,
    output wire  s00_axi_wready,
    output wire [C_S00_AXI_ID_WIDTH-1 : 0] s00_axi_bid,
    output wire [1 : 0] s00_axi_bresp,
    output wire [C_S00_AXI_BUSER_WIDTH-1 : 0] s00_axi_buser,
    output wire  s00_axi_bvalid,
    input wire  s00_axi_bready,
    input wire [C_S00_AXI_ID_WIDTH-1 : 0] s00_axi_arid,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [7 : 0] s00_axi_arlen,
    input wire [2 : 0] s00_axi_arsize,
    input wire [1 : 0] s00_axi_arburst,
    input wire  s00_axi_arlock,
    input wire [3 : 0] s00_axi_arcache,
    input wire [2 : 0] s00_axi_arprot,
    input wire [3 : 0] s00_axi_arqos,
    input wire [3 : 0] s00_axi_arregion,
    input wire [C_S00_AXI_ARUSER_WIDTH-1 : 0] s00_axi_aruser,
    input wire  s00_axi_arvalid,
    output wire  s00_axi_arready,
    output wire [C_S00_AXI_ID_WIDTH-1 : 0] s00_axi_rid,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire  s00_axi_rlast,
    output wire [C_S00_AXI_RUSER_WIDTH-1 : 0] s00_axi_ruser,
    output wire  s00_axi_rvalid,
    input wire  s00_axi_rready,
////////////////////////// input_weight axi port
	input wire  s01_axi_aclk,
	input wire  s01_axi_aresetn,
    input wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_awid,
    input wire [C_S01_AXI_ADDR_WIDTH-1 : 0] s01_axi_awaddr,
    input wire [7 : 0] s01_axi_awlen,
    input wire [2 : 0] s01_axi_awsize,
    input wire [1 : 0] s01_axi_awburst,
    input wire  s01_axi_awlock,
    input wire [3 : 0] s01_axi_awcache,
    input wire [2 : 0] s01_axi_awprot,
    input wire [3 : 0] s01_axi_awqos,
    input wire [3 : 0] s01_axi_awregion,
    input wire [C_S01_AXI_AWUSER_WIDTH-1 : 0] s01_axi_awuser,
    input wire  s01_axi_awvalid,
    output wire  s01_axi_awready,
    input wire [C_S01_AXI_DATA_WIDTH-1 : 0] s01_axi_wdata,
    input wire [(C_S01_AXI_DATA_WIDTH/8)-1 : 0] s01_axi_wstrb,
    input wire  s01_axi_wlast,
    input wire [C_S01_AXI_WUSER_WIDTH-1 : 0] s01_axi_wuser,
    input wire  s01_axi_wvalid,
    output wire  s01_axi_wready,
    output wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_bid,
    output wire [1 : 0] s01_axi_bresp,
    output wire [C_S01_AXI_BUSER_WIDTH-1 : 0] s01_axi_buser,
    output wire  s01_axi_bvalid,
    input wire  s01_axi_bready,
    input wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_arid,
    input wire [C_S01_AXI_ADDR_WIDTH-1 : 0] s01_axi_araddr,
    input wire [7 : 0] s01_axi_arlen,
    input wire [2 : 0] s01_axi_arsize,
    input wire [1 : 0] s01_axi_arburst,
    input wire  s01_axi_arlock,
    input wire [3 : 0] s01_axi_arcache,
    input wire [2 : 0] s01_axi_arprot,
    input wire [3 : 0] s01_axi_arqos,
    input wire [3 : 0] s01_axi_arregion,
    input wire [C_S01_AXI_ARUSER_WIDTH-1 : 0] s01_axi_aruser,
    input wire  s01_axi_arvalid,
    output wire  s01_axi_arready,
    output wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_rid,
    output wire [C_S01_AXI_DATA_WIDTH-1 : 0] s01_axi_rdata,
    output wire [1 : 0] s01_axi_rresp,
    output wire  s01_axi_rlast,
    output wire [C_S01_AXI_RUSER_WIDTH-1 : 0] s01_axi_ruser,
    output wire  s01_axi_rvalid,
    input wire  s01_axi_rready,
    /////////////////////////////////// register_array axi port

	input wire  s02_axi_aclk,
	input wire  s02_axi_aresetn,
    input wire [C_S02_AXI_ID_WIDTH-1 : 0] s02_axi_awid,
    input wire [C_S02_AXI_ADDR_WIDTH-1 : 0] s02_axi_awaddr,
    input wire [7 : 0] s02_axi_awlen,
    input wire [2 : 0] s02_axi_awsize,
    input wire [1 : 0] s02_axi_awburst,
    input wire  s02_axi_awlock,
    input wire [3 : 0] s02_axi_awcache,
    input wire [2 : 0] s02_axi_awprot,
    input wire [3 : 0] s02_axi_awqos,
    input wire [3 : 0] s02_axi_awregion,
    input wire [C_S02_AXI_AWUSER_WIDTH-1 : 0] s02_axi_awuser,
    input wire  s02_axi_awvalid,
    output wire  s02_axi_awready,
    input wire [C_S02_AXI_DATA_WIDTH-1 : 0] s02_axi_wdata,
    input wire [(C_S02_AXI_DATA_WIDTH/8)-1 : 0] s02_axi_wstrb,
    input wire  s02_axi_wlast,
    input wire [C_S02_AXI_WUSER_WIDTH-1 : 0] s02_axi_wuser,
    input wire  s02_axi_wvalid,
    output wire  s02_axi_wready,
    output wire [C_S02_AXI_ID_WIDTH-1 : 0] s02_axi_bid,
    output wire [1 : 0] s02_axi_bresp,
    output wire [C_S02_AXI_BUSER_WIDTH-1 : 0] s02_axi_buser,
    output wire  s02_axi_bvalid,
    input wire  s02_axi_bready,
    input wire [C_S02_AXI_ID_WIDTH-1 : 0] s02_axi_arid,
    input wire [C_S02_AXI_ADDR_WIDTH-1 : 0] s02_axi_araddr,
    input wire [7 : 0] s02_axi_arlen,
    input wire [2 : 0] s02_axi_arsize,
    input wire [1 : 0] s02_axi_arburst,
    input wire  s02_axi_arlock,
    input wire [3 : 0] s02_axi_arcache,
    input wire [2 : 0] s02_axi_arprot,
    input wire [3 : 0] s02_axi_arqos,
    input wire [3 : 0] s02_axi_arregion,
    input wire [C_S02_AXI_ARUSER_WIDTH-1 : 0] s02_axi_aruser,
    input wire  s02_axi_arvalid,
    output wire  s02_axi_arready,
    output wire [C_S02_AXI_ID_WIDTH-1 : 0] s02_axi_rid,
    output wire [C_S02_AXI_DATA_WIDTH-1 : 0] s02_axi_rdata,
    output wire [1 : 0] s02_axi_rresp,
    output wire  s02_axi_rlast,
    output wire [C_S02_AXI_RUSER_WIDTH-1 : 0] s02_axi_ruser,
    output wire  s02_axi_rvalid,
    input wire  s02_axi_rready

);


/////////// config local ports

wire start;
wire [`INPUT_ZP_WIDTH-1:0] input_zp;

/////////// input_weight local ports
wire input_weight_ren;
wire [ INPUT_WEIGHT_ADDR_WIDTH - 1 : 0 ] input_weight_address;
wire [ MAX_PES * WEIGHT_DATA_WIDTH - 1 : 0] weight_data;
wire [INPUT_DATA_WIDTH - 1 : 0] input_data;
////////// register array local ports
wire ra_clk;
wire ra_rstn;



wire [BYTE_REG_NUM * 8-1:0] ra_in_acc;
wire [BYTE_REG_NUM * 8-1:0] register_array;
////////////////////////////////////////////
wire [$clog2(MAX_INPUT_SIZE) - 1 : 0] cluster_top_input_num;
wire [$clog2(MAX_PES) - 1 : 0] cluster_top_output_num;

assign debug_start = start;
assign debug_reg_0 = register_array[31:0];

Axi4_config_cluster_v1_0 #
	(
		.CONFIG_SIZE(CONFIG_SIZE),

		.C_S00_AXI_ID_WIDTH (C_S00_AXI_ID_WIDTH),
		.C_S00_AXI_DATA_WIDTH (C_S00_AXI_DATA_WIDTH),
        
		.C_S00_AXI_ADDR_WIDTH ($clog2(CONFIG_SIZE)),
		.C_S00_AXI_AWUSER_WIDTH (0),
		.C_S00_AXI_ARUSER_WIDTH (0),
		.C_S00_AXI_WUSER_WIDTH (0),
		.C_S00_AXI_RUSER_WIDTH (0),
		.C_S00_AXI_BUSER_WIDTH (0)	 
        
	)
    AXI_CONFIG
	(
        .logic_wen(logic_wen),
        .done(done),
        .start(start),
        .input_zp(input_zp),
        .output_num(output_num),
        .input_num(input_num),
        
	    .s00_axi_aclk(s00_axi_aclk),
	    .s00_axi_aresetn(s00_axi_aresetn),
		.s00_axi_awid(s00_axi_awid),
		.s00_axi_awaddr(s00_axi_awaddr),
		.s00_axi_awlen(s00_axi_awlen),
		.s00_axi_awsize(s00_axi_awsize),
		.s00_axi_awburst(s00_axi_awburst),
		.s00_axi_awlock(s00_axi_awlock),
		.s00_axi_awcache(s00_axi_awcache),
		.s00_axi_awprot(s00_axi_awprot),
		.s00_axi_awqos(s00_axi_awqos),
		.s00_axi_awregion(s00_axi_awregion),
		.s00_axi_awuser(s00_axi_awuser),
		.s00_axi_awvalid(s00_axi_awvalid),
		.s00_axi_awready(s00_axi_awready),
		.s00_axi_wdata(s00_axi_wdata),
		.s00_axi_wstrb(s00_axi_wstrb),
		.s00_axi_wlast(s00_axi_wlast),
		.s00_axi_wuser(s00_axi_wuser),
		.s00_axi_wvalid(s00_axi_wvalid),
		.s00_axi_wready(s00_axi_wready),
		.s00_axi_bid(s00_axi_bid),
		.s00_axi_bresp(s00_axi_bresp),
		.s00_axi_buser(s00_axi_buser),
		.s00_axi_bvalid(s00_axi_bvalid),
		.s00_axi_bready(s00_axi_bready),
		.s00_axi_arid(s00_axi_arid),
		.s00_axi_araddr(s00_axi_araddr),
		.s00_axi_arlen(s00_axi_arlen),
		.s00_axi_arsize(s00_axi_arsize),
		.s00_axi_arburst(s00_axi_arburst),
		.s00_axi_arlock(s00_axi_arlock),
		.s00_axi_arcache(s00_axi_arcache),
		.s00_axi_arprot(s00_axi_arprot),
		.s00_axi_arqos(s00_axi_arqos),
		.s00_axi_arregion(s00_axi_arregion),
		.s00_axi_aruser(s00_axi_aruser),
		.s00_axi_arvalid(s00_axi_arvalid),
		.s00_axi_arready(s00_axi_arready),
		.s00_axi_rid(s00_axi_rid),
		.s00_axi_rdata(s00_axi_rdata),
		.s00_axi_rresp(s00_axi_rresp),
		.s00_axi_rlast(s00_axi_rlast),
		.s00_axi_ruser(s00_axi_ruser),
		.s00_axi_rvalid(s00_axi_rvalid),
		.s00_axi_rready(s00_axi_rready)
		);



        Axi4_input_weight_brams_v1_0 #
        (
            // Users to add parameters here
            .MAX_PES(MAX_PES),
            .BLOCK_NUM(BLOCK_NUM),
            .BLOCK_SIZE(BLOCK_SIZE),
            .DATA_WIDTH(DATA_WIDTH),
            .INPUT_WEIGHT_ADDR_WIDTH(INPUT_WEIGHT_ADDR_WIDTH),
            .WEIGHT_DATA_WIDTH(WEIGHT_DATA_WIDTH),
            .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),

            .C_S00_AXI_ID_WIDTH(C_S01_AXI_ID_WIDTH),	
            .C_S00_AXI_DATA_WIDTH(C_S01_AXI_DATA_WIDTH),	
    
            .C_S00_AXI_ADDR_WIDTH(C_S01_AXI_ADDR_WIDTH),	
            .C_S00_AXI_AWUSER_WIDTH(C_S01_AXI_AWUSER_WIDTH),	
            .C_S00_AXI_ARUSER_WIDTH(C_S01_AXI_ARUSER_WIDTH),	
            .C_S00_AXI_WUSER_WIDTH(C_S01_AXI_WUSER_WIDTH),	
            .C_S00_AXI_RUSER_WIDTH(C_S01_AXI_RUSER_WIDTH),	
            .C_S00_AXI_BUSER_WIDTH(C_S01_AXI_BUSER_WIDTH)	
    
        ) AXI_INPUT_WEIGHT (
        .input_weight_ren(input_weight_ren),
        .input_weight_address(input_weight_address),
        .weight_data(weight_data),
    
        .input_data(input_data),

        .s00_axi_aclk(s01_axi_aclk),
        .s00_axi_aresetn(s01_axi_aresetn),
        .s00_axi_awid(s01_axi_awid),
        .s00_axi_awaddr(s01_axi_awaddr),
        .s00_axi_awlen(s01_axi_awlen),
        .s00_axi_awsize(s01_axi_awsize),
        .s00_axi_awburst(s01_axi_awburst),
        .s00_axi_awlock(s01_axi_awlock),
        .s00_axi_awcache(s01_axi_awcache),
        .s00_axi_awprot(s01_axi_awprot),
        .s00_axi_awqos(s01_axi_awqos),
        .s00_axi_awregion(s01_axi_awregion),
        .s00_axi_awuser(s01_axi_awuser),
        .s00_axi_awvalid(s01_axi_awvalid),
        .s00_axi_awready(s01_axi_awready),
        .s00_axi_wdata(s01_axi_wdata),
        .s00_axi_wstrb(s01_axi_wstrb),
        .s00_axi_wlast(s01_axi_wlast),
        .s00_axi_wuser(s01_axi_wuser),
        .s00_axi_wvalid(s01_axi_wvalid),
        .s00_axi_wready(s01_axi_wready),
        .s00_axi_bid(s01_axi_bid),
        .s00_axi_bresp(s01_axi_bresp),
        .s00_axi_buser(s01_axi_buser),
        .s00_axi_bvalid(s01_axi_bvalid),
        .s00_axi_bready(s01_axi_bready),
        .s00_axi_arid(s01_axi_arid),
        .s00_axi_araddr(s01_axi_araddr),
        .s00_axi_arlen(s01_axi_arlen),
        .s00_axi_arsize(s01_axi_arsize),
        .s00_axi_arburst(s01_axi_arburst),
        .s00_axi_arlock(s01_axi_arlock),
        .s00_axi_arcache(s01_axi_arcache),
        .s00_axi_arprot(s01_axi_arprot),
        .s00_axi_arqos(s01_axi_arqos),
        .s00_axi_arregion(s01_axi_arregion),
        .s00_axi_aruser(s01_axi_aruser),
        .s00_axi_arvalid(s01_axi_arvalid),
        .s00_axi_arready(s01_axi_arready),
        .s00_axi_rid(s01_axi_rid),
        .s00_axi_rdata(s01_axi_rdata),
        .s00_axi_rresp(s01_axi_rresp),
        .s00_axi_rlast(s01_axi_rlast),
        .s00_axi_ruser(s01_axi_ruser),
        .s00_axi_rvalid(s01_axi_rvalid),
        .s00_axi_rready(s01_axi_rready)
            );
    


    assign ra_clk = logic_clk;
    assign ra_rstn = logic_rstn;

Axi4_register_array_v1_0 #
        (

        .C_S00_AXI_ID_WIDTH(C_S02_AXI_ID_WIDTH),
        .C_S00_AXI_DATA_WIDTH(C_S02_AXI_DATA_WIDTH),
        .BYTE_REG_NUM(BYTE_REG_NUM),
    
        .C_S00_AXI_ADDR_WIDTH(C_S02_AXI_ADDR_WIDTH),
        .C_S00_AXI_AWUSER_WIDTH(C_S02_AXI_AWUSER_WIDTH),
        .C_S00_AXI_ARUSER_WIDTH(C_S02_AXI_ARUSER_WIDTH),
        .C_S00_AXI_WUSER_WIDTH(C_S02_AXI_WUSER_WIDTH),
        .C_S00_AXI_RUSER_WIDTH(C_S02_AXI_RUSER_WIDTH),
        .C_S00_AXI_BUSER_WIDTH(C_S02_AXI_BUSER_WIDTH)
    
        )
        AXI_REG_ARRAY(
            // Users to add ports here
    
        .ra_clk(ra_clk),
        .ra_rstn(ra_rstn),
        .ra_ld_axi(ra_ld_axi),
        .ra_ld_acc(ra_ld_acc),
        .axi_ram_ld(axi_ram_ld),
        .ra_in_acc(ra_in_acc),
        .register_array(register_array),

        .s00_axi_aclk(s02_axi_aclk),
        .s00_axi_aresetn(s02_axi_aresetn),
        .s00_axi_awid(s02_axi_awid),
        .s00_axi_awaddr(s02_axi_awaddr),
        .s00_axi_awlen(s02_axi_awlen),
        .s00_axi_awsize(s02_axi_awsize),
        .s00_axi_awburst(s02_axi_awburst),
        .s00_axi_awlock(s02_axi_awlock),
        .s00_axi_awcache(s02_axi_awcache),
        .s00_axi_awprot(s02_axi_awprot),
        .s00_axi_awqos(s02_axi_awqos),
        .s00_axi_awregion(s02_axi_awregion),
        .s00_axi_awuser(s02_axi_awuser),
        .s00_axi_awvalid(s02_axi_awvalid),
        .s00_axi_awready(s02_axi_awready),
        .s00_axi_wdata(s02_axi_wdata),
        .s00_axi_wstrb(s02_axi_wstrb),
        .s00_axi_wlast(s02_axi_wlast),
        .s00_axi_wuser(s02_axi_wuser),
        .s00_axi_wvalid(s02_axi_wvalid),
        .s00_axi_wready(s02_axi_wready),
        .s00_axi_bid(s02_axi_bid),
        .s00_axi_bresp(s02_axi_bresp),
        .s00_axi_buser(s02_axi_buser),
        .s00_axi_bvalid(s02_axi_bvalid),
        .s00_axi_bready(s02_axi_bready),
        .s00_axi_arid(s02_axi_arid),
        .s00_axi_araddr(s02_axi_araddr),
        .s00_axi_arlen(s02_axi_arlen),
        .s00_axi_arsize(s02_axi_arsize),
        .s00_axi_arburst(s02_axi_arburst),
        .s00_axi_arlock(s02_axi_arlock),
        .s00_axi_arcache(s02_axi_arcache),
        .s00_axi_arprot(s02_axi_arprot),
        .s00_axi_arqos(s02_axi_arqos),
        .s00_axi_arregion(s02_axi_arregion),
        .s00_axi_aruser(s02_axi_aruser),
        .s00_axi_arvalid(s02_axi_arvalid),
        .s00_axi_arready(s02_axi_arready),
        .s00_axi_rid(s02_axi_rid),
        .s00_axi_rdata(s02_axi_rdata),
        .s00_axi_rresp(s02_axi_rresp),
        .s00_axi_rlast(s02_axi_rlast),
        .s00_axi_ruser(s02_axi_ruser),
        .s00_axi_rvalid(s02_axi_rvalid),
        .s00_axi_rready(s02_axi_rready)
            );

    
    
    assign cluster_top_input_num = input_num[$clog2(MAX_INPUT_SIZE) - 1 : 0];
    assign cluster_top_output_num = output_num [$clog2(MAX_PES) - 1 : 0];
    
    cluster_top CTOP (
        .clk(logic_clk),
        .rstn(logic_rstn),
        // configs
        .input_num(cluster_top_input_num),
        .output_num(cluster_top_output_num),
        .relu(1'b0),
        .input_zp(input_zp),
        .logic_wen(logic_wen),
        .start(start),
        .done(done),
        ////////////////
        .input_weight_ren(input_weight_ren),
        .input_weight_address(input_weight_address),
        .weight_data(weight_data),
        .input_data(input_data),
        /////////////////
        .ra_ld_axi(ra_ld_axi),
        .ra_ld_acc(ra_ld_acc),
        .axi_ram_ld(axi_ram_ld),
        .ra_in_acc(ra_in_acc),
        .register_array(register_array)

    );

endmodule