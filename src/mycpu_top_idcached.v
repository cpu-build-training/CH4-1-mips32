`include "defines.v"
module mycpu_top_idcached(

         input
         wire aclk,
         wire aresetn,
         wire[5:0] int_i,


         // write address channel signals
         output
         wire[3:0]   awid,
         wire[31:0]  awaddr,
         wire[3:0]   awlen,
         wire[2:0]   awsize,
         wire[1:0]   awburst,
         wire[1:0]   awlock,
         wire[3:0]   awcache,
         wire[2:0]   awprot,
         output wire awvalid,
         input
         wire    awready,

         // write data channel signals
         output
         wire[3:0]    wid,
         wire[31:0]   wdata,
         wire[3:0]   wstrb,
         output wire        wlast,
         wire        wvalid,
         input       wready,

         // write response channel signals
         input
         wire[3:0]   bid,
         wire[1:0]   bresp,
         input wire  bvalid,
         output
         wire        bready,


         // read address channel signals
         output
         wire[3:0]   arid,
         wire[31:0]  araddr,
         wire[3:0]   arlen,
         wire[2:0]   arsize,
         wire[1:0]   arburst,
         wire[1:0]   arlock,
         wire[3:0]   arcache,
         wire[2:0]   arprot,
         output wire arvalid,
         input
         wire        arready,

         // read data channel signals
         input
         wire[3:0]   rid,
         wire[31:0]  rdata,
         wire[1:0]   rresp,
         input wire  rlast,
         wire        rvalid,
         output
         wire        rready,


         // port for debug
         output
         wire[`RegBus]     debug_wb_pc,
         wire[3:0]         debug_wb_rf_wen,
         wire[4:0]         debug_wb_rf_wnum,
         wire[`RegBus]     debug_wb_rf_wdata
       );

wire[`RegBus] rom_data;
wire          inst_valid;
wire[`RegBus] rom_addr;
wire          rom_re;
wire[`RegBus] ram_data_i;
wire[`RegBus] ram_addr;
wire[`RegBus] ram_data_o;
wire          ram_we;
wire          ram_re;
wire[3:0]          ram_sel;
wire          ram_write_ready;
wire          inst_ready;
wire          mem_data_ready;
wire          pc_ready;
wire          ram_read_ready;
wire[`RegBus] current_inst_address;
wire flush;
wire          mem_addr_read_ready;
wire          if_id_full;
wire[1:0]     axi_read_state;



wire [7 : 0] s_axi_awid;
wire [63: 0] s_axi_awaddr;
wire [7 : 0] s_axi_awlen;
wire [5 : 0] s_axi_awsize;
wire [3 : 0] s_axi_awburst;
wire [3 : 0] s_axi_awlock;
wire [7 : 0] s_axi_awcache;
wire [5 : 0] s_axi_awprot;
wire [7 : 0] s_axi_awqos;
wire [1 : 0] s_axi_awvalid;
wire [1 : 0] s_axi_awready;
wire [7 : 0] s_axi_wid;
wire [63 : 0] s_axi_wdata;
wire [7 : 0] s_axi_wstrb;
wire [1 : 0] s_axi_wlast;
wire [1 : 0] s_axi_wvalid;
wire [1 : 0] s_axi_wready;
wire [7 : 0] s_axi_bid;
wire [3 : 0] s_axi_bresp;
wire [1 : 0] s_axi_bvalid;
wire [1 : 0] s_axi_bready;
wire [7 : 0] s_axi_arid;
wire [63 : 0] s_axi_araddr;
wire [7 : 0] s_axi_arlen;
wire [5 : 0] s_axi_arsize;
wire [3 : 0] s_axi_arburst;
wire [3 : 0] s_axi_arlock;
wire [7 : 0] s_axi_arcache;
wire [5 : 0] s_axi_arprot;
wire [7 : 0] s_axi_arqos;
wire [1 : 0] s_axi_arvalid;
wire [1 : 0] s_axi_arready;
wire [7 : 0] s_axi_rid;
wire [63 : 0] s_axi_rdata;
wire [3 : 0] s_axi_rresp;
wire [1 : 0] s_axi_rlast;
wire [1 : 0] s_axi_rvalid;
wire [1 : 0] s_axi_rready;


wire[3:0] arqos;
wire[3:0] awqos;


axi_crossbar_0 axi_crossbar_0_merge (
                 .aclk(aclk),                    // input wire aclk
                 .aresetn(aresetn),              // input wire aresetn
                 .s_axi_awid(s_axi_awid),        // input wire [7 : 0] s_axi_awid
                 .s_axi_awaddr(s_axi_awaddr),    // input wire [63 : 0] s_axi_awaddr
                 .s_axi_awlen(s_axi_awlen),      // input wire [7 : 0] s_axi_awlen
                 .s_axi_awsize(s_axi_awsize),    // input wire [5 : 0] s_axi_awsize
                 .s_axi_awburst(s_axi_awburst),  // input wire [3 : 0] s_axi_awburst
                 .s_axi_awlock(s_axi_awlock),    // input wire [3 : 0] s_axi_awlock
                 .s_axi_awcache(s_axi_awcache),  // input wire [7 : 0] s_axi_awcache
                 .s_axi_awprot(s_axi_awprot),    // input wire [5 : 0] s_axi_awprot
                 .s_axi_awqos(s_axi_awqos),      // input wire [7 : 0] s_axi_awqos
                 .s_axi_awvalid(s_axi_awvalid),  // input wire [1 : 0] s_axi_awvalid
                 .s_axi_awready(s_axi_awready),  // output wire [1 : 0] s_axi_awready
                 .s_axi_wid(s_axi_wid),          // input wire [7 : 0] s_axi_wid
                 .s_axi_wdata(s_axi_wdata),      // input wire [63 : 0] s_axi_wdata
                 .s_axi_wstrb(s_axi_wstrb),      // input wire [7 : 0] s_axi_wstrb
                 .s_axi_wlast(s_axi_wlast),      // input wire [1 : 0] s_axi_wlast
                 .s_axi_wvalid(s_axi_wvalid),    // input wire [1 : 0] s_axi_wvalid
                 .s_axi_wready(s_axi_wready),    // output wire [1 : 0] s_axi_wready
                 .s_axi_bid(s_axi_bid),          // output wire [7 : 0] s_axi_bid
                 .s_axi_bresp(s_axi_bresp),      // output wire [3 : 0] s_axi_bresp
                 .s_axi_bvalid(s_axi_bvalid),    // output wire [1 : 0] s_axi_bvalid
                 .s_axi_bready(s_axi_bready),    // input wire [1 : 0] s_axi_bready
                 .s_axi_arid(s_axi_arid),        // input wire [7 : 0] s_axi_arid
                 .s_axi_araddr(s_axi_araddr),    // input wire [63 : 0] s_axi_araddr
                 .s_axi_arlen(s_axi_arlen),      // input wire [7 : 0] s_axi_arlen
                 .s_axi_arsize(s_axi_arsize),    // input wire [5 : 0] s_axi_arsize
                 .s_axi_arburst(s_axi_arburst),  // input wire [3 : 0] s_axi_arburst
                 .s_axi_arlock(s_axi_arlock),    // input wire [3 : 0] s_axi_arlock
                 .s_axi_arcache(s_axi_arcache),  // input wire [7 : 0] s_axi_arcache
                 .s_axi_arprot(s_axi_arprot),    // input wire [5 : 0] s_axi_arprot
                 .s_axi_arqos(s_axi_arqos),      // input wire [7 : 0] s_axi_arqos
                 .s_axi_arvalid(s_axi_arvalid),  // input wire [1 : 0] s_axi_arvalid
                 .s_axi_arready(s_axi_arready),  // output wire [1 : 0] s_axi_arready
                 .s_axi_rid(s_axi_rid),          // output wire [7 : 0] s_axi_rid
                 .s_axi_rdata(s_axi_rdata),      // output wire [63 : 0] s_axi_rdata
                 .s_axi_rresp(s_axi_rresp),      // output wire [3 : 0] s_axi_rresp
                 .s_axi_rlast(s_axi_rlast),      // output wire [1 : 0] s_axi_rlast
                 .s_axi_rvalid(s_axi_rvalid),    // output wire [1 : 0] s_axi_rvalid
                 .s_axi_rready(s_axi_rready),    // input wire [1 : 0] s_axi_rready
                 .m_axi_awid(awid),        // output wire [3 : 0] m_axi_awid
                 .m_axi_awaddr(awaddr),    // output wire [31 : 0] m_axi_awaddr
                 .m_axi_awlen(awlen),      // output wire [3 : 0] m_axi_awlen
                 .m_axi_awsize(awsize),    // output wire [2 : 0] m_axi_awsize
                 .m_axi_awburst(awburst),  // output wire [1 : 0] m_axi_awburst
                 .m_axi_awlock(awlock),    // output wire [1 : 0] m_axi_awlock
                 .m_axi_awcache(awcache),  // output wire [3 : 0] m_axi_awcache
                 .m_axi_awprot(awprot),    // output wire [2 : 0] m_axi_awprot
                 .m_axi_awqos(awqos),      // output wire [3 : 0] m_axi_awqos
                 .m_axi_awvalid(awvalid),  // output wire [0 : 0] m_axi_awvalid
                 .m_axi_awready(awready),  // input wire [0 : 0] m_axi_awready
                 .m_axi_wid(wid),          // output wire [3 : 0] m_axi_wid
                 .m_axi_wdata(wdata),      // output wire [31 : 0] m_axi_wdata
                 .m_axi_wstrb(wstrb),      // output wire [3 : 0] m_axi_wstrb
                 .m_axi_wlast(wlast),      // output wire [0 : 0] m_axi_wlast
                 .m_axi_wvalid(wvalid),    // output wire [0 : 0] m_axi_wvalid
                 .m_axi_wready(wready),    // input wire [0 : 0] m_axi_wready
                 .m_axi_bid(bid),          // input wire [3 : 0] m_axi_bid
                 .m_axi_bresp(bresp),      // input wire [1 : 0] m_axi_bresp
                 .m_axi_bvalid(bvalid),    // input wire [0 : 0] m_axi_bvalid
                 .m_axi_bready(bready),    // output wire [0 : 0] m_axi_bready
                 .m_axi_arid(arid),        // output wire [3 : 0] m_axi_arid
                 .m_axi_araddr(araddr),    // output wire [31 : 0] m_axi_araddr
                 .m_axi_arlen(arlen),      // output wire [3 : 0] m_axi_arlen
                 .m_axi_arsize(arsize),    // output wire [2 : 0] m_axi_arsize
                 .m_axi_arburst(arburst),  // output wire [1 : 0] m_axi_arburst
                 .m_axi_arlock(arlock),    // output wire [1 : 0] m_axi_arlock
                 .m_axi_arcache(arcache),  // output wire [3 : 0] m_axi_arcache
                 .m_axi_arprot(arprot),    // output wire [2 : 0] m_axi_arprot
                 .m_axi_arqos(arqos),      // output wire [3 : 0] m_axi_arqos
                 .m_axi_arvalid(arvalid),  // output wire [0 : 0] m_axi_arvalid
                 .m_axi_arready(arready),  // input wire [0 : 0] m_axi_arready
                 .m_axi_rid(rid),          // input wire [3 : 0] m_axi_rid
                 .m_axi_rdata(rdata),      // input wire [31 : 0] m_axi_rdata
                 .m_axi_rresp(rresp),      // input wire [1 : 0] m_axi_rresp
                 .m_axi_rlast(rlast),      // input wire [0 : 0] m_axi_rlast
                 .m_axi_rvalid(rvalid),    // input wire [0 : 0] m_axi_rvalid
                 .m_axi_rready(rready)    // output wire [0 : 0] m_axi_rready
               );






// memory write
wire[3:0]   mw_awid;
wire[31:0]  mw_awaddr;
wire[3:0]   mw_awlen;
wire[2:0]   mw_awsize;
wire[1:0]   mw_awburst;
wire[1:0]   mw_awlock;
wire[3:0]   mw_awcache;
wire[2:0]   mw_awprot;
wire        mw_awvalid;
wire        mw_awready;
wire[3:0]   mw_wid;
wire[31:0]  mw_wdata;
wire[3:0]   mw_wstrb;
wire        mw_wlast;
wire        mw_wvalid;
wire        mw_wready;
wire[3:0]   mw_bid;
wire[1:0]   mw_bresp;
wire        mw_bvalid;
wire        mw_bready;

wire[3:0]   mr_arid;
wire[31:0]  mr_araddr;
wire[3:0]   mr_arlen;
wire[2:0]   mr_arsize;
wire[1:0]   mr_arburst;
wire[1:0]   mr_arlock;
wire[3:0]   mr_arcache;
wire[2:0]   mr_arprot;
wire        mr_arvalid;
wire        mr_arready;
wire        mr_flush;
wire[3:0]   mr_rid;
wire[31:0]  mr_rdata;
wire[1:0]   mr_rresp;
wire        mr_rlast;
wire        mr_rvalid;
wire        mr_rready;

wire[3:0]   ir_arid;
wire[31:0]  ir_araddr;
wire[3:0]   ir_arlen;
wire[2:0]   ir_arsize;
wire[1:0]   ir_arburst;
wire[1:0]   ir_arlock;
wire[3:0]   ir_arcache;
wire[2:0]   ir_arprot;
wire        ir_arvalid;
wire        ir_arready;
wire        ir_flush;
wire[3:0]   ir_rid;
wire[31:0]  ir_rdata;
wire[1:0]   ir_rresp;
wire        ir_rlast;
wire        ir_rvalid;
wire        ir_rready;

assign s_axi_awid = {4'b0, mw_awid};
assign s_axi_awaddr = {32'b0, mw_awaddr};
assign s_axi_awlen = {4'b0, mw_awlen};
assign s_axi_awsize = {3'b0, mw_awsize};
assign s_axi_awburst = { 2'b0, mw_awburst};
assign s_axi_awlock = { 2'b0, mw_awlock};
assign s_axi_awcache = { 4'b0,mw_awcache};
assign s_axi_awprot = { 3'b0,mw_awprot};
assign s_axi_awqos = { 4'b0, 4'b0};
assign s_axi_awvalid = { 1'b0, mw_awvalid};
assign mw_awready = s_axi_awready[0];
assign s_axi_wid = {4'b0, mw_wid};
assign s_axi_wdata = { 32'b0, mw_wdata};
assign s_axi_wstrb = { 4'b0, mw_wstrb};
assign s_axi_wlast = { 1'b1, mw_wlast};
assign s_axi_wvalid = { 1'b0, mw_wvalid};
assign mw_wready = s_axi_wready[0];
assign mw_bid = s_axi_bid[3:0];
assign mw_bresp = s_axi_bresp[1:0];
assign mw_bvalid = s_axi_bvalid[0];
assign s_axi_bready = { 1'b0, mw_bready};
assign s_axi_arid = {ir_arid, mr_arid};
assign s_axi_araddr = { ir_araddr, mr_araddr};
assign s_axi_arlen = {ir_arlen, mr_arlen};
assign s_axi_arsize = {ir_arsize, mr_arsize};
assign s_axi_arburst = {ir_arburst, mr_arburst};
assign s_axi_arlock = {ir_arlock, mr_arlock};
assign s_axi_arcache = {ir_arcache, mr_arcache};
assign s_axi_arprot = {ir_arprot, mr_arprot};
assign s_axi_arqos = {4'b0, 4'b0};
assign s_axi_arvalid = {ir_arvalid, mr_arvalid};
assign {ir_arready, mr_arready} = s_axi_arready;
assign {ir_rid, mr_rid} = s_axi_rid;
assign {ir_rdata, mr_rdata}= s_axi_rdata ;
assign {ir_rresp, mr_rresp}= s_axi_rresp ;
assign {ir_rlast, mr_rlast} = s_axi_rlast;
assign {ir_rvalid, mr_rvalid} =s_axi_rvalid ;
assign s_axi_rready = {ir_rready, mr_rready};


wire data_req;
wire data_wr;
wire[3:0] data_select;
wire[`RegBus] data_addr;
wire[`RegBus] data_wdata;
wire data_addr_ok;
wire data_data_ok;
wire[`RegBus] data_rdata;


// data r/w
dcache dcache_0(
    .clk(aclk),
    .rstn(aresetn),


    // AXI
    .arid(mr_arid),
    .araddr(mr_araddr),
    .arlen(mr_arlen),
    .arsize(mr_arsize),
    .arburst(mr_arburst),
    .arlock(mr_arlock),
    .arcache(mr_arcache),
    .arprot(mr_arprot),
    .arvalid(mr_arvalid),
    .arready(mr_arready),

    .rid(mr_rid),
    .rdata(mr_rdata),
    .rresp(mr_rresp),
    .rvalid(mr_rvalid),
    .rready(mr_rready),
    .rlast(mr_rlast),

    .awid(mw_awid),
    .awaddr(mw_awaddr),
    .awlen(mw_awlen),
    .awsize(mw_awsize),
    .awburst(mw_awburst),
    .awlock(mw_awlock),
    .awcache(mw_awcache),
    .awprot(mw_awprot),
    .awvalid(mw_awvalid),
    .awready(mw_awready),

    .wid(mw_wid),
    .wdata(mw_wdata),
    .wstrb(mw_wstrb),
    .wlast(mw_wlast),
    .wvalid(mw_wvalid),
    .wready(mw_wready),

    .bid(mw_bid),
    .bresp(mw_bresp),
    .bvalid(mw_bvalid),
    .bready(mw_bready),
    

    // CPU SRAM like
    .data_req(data_req),
    .data_wr(data_wr),

    .data_addr_ok(data_addr_ok),
    .data_addr(data_addr),

    .data_data_ok(data_data_ok),
    .data_rdata(data_rdata),

    .data_sel(data_select),
    .data_wdata(data_wdata)

    // .data_cache(1'b0)
);


// inst read
inst_cache inst_cache_0(
    .clk(aclk),
    .rstn(aresetn),
    .flush(flush),

    .arid(ir_arid),
    .araddr(ir_araddr),
    .arlen(ir_arlen),
    .arsize(ir_arsize),
    .arburst(ir_arburst),
    .arlock(ir_arlock),
    .arcache(ir_arcache),
    .arprot(ir_arprot),
    .arvalid(ir_arvalid),
    .arready(ir_arready),
    .rid(ir_rid),
    .rdata(ir_rdata),
    .rresp(ir_rresp),
    .rvalid(ir_rvalid),
    .rready(ir_rready),
    .rlast(ir_rlast),

    .inst_req(rom_re),                      // cpu::rom_ce_o == read_adapter::address_valid
    .inst_addr_ready(pc_ready),             // cpu::pc_ready == read_adapter::address_read_ready
    .inst_addr(rom_addr),
    .inst_addr_out(current_inst_address),
    .inst_rdata(rom_data),
    .inst_data_ok(inst_valid)
    
    // .inst_cache(1'b0)
);


openmips openmips0(
           .clk(aclk),.rst(aresetn),
           .flush_o(flush),

           .rom_data_i_le(rom_data),
           .rom_data_valid(inst_valid),
           .rom_addr_o(rom_addr),
           .rom_ce_o(rom_re),
           .inst_ready(inst_ready),
           .pc_ready(pc_ready),
           .current_inst_address(current_inst_address),


           .data_req(data_req),
           .data_wr(data_wr),
           .data_select(data_select),
           .data_addr(data_addr),
           .data_wdata(data_wdata),
           .data_addr_ok(data_addr_ok),
           .data_data_ok(data_data_ok),
           .data_rdata(data_rdata),

           .int_i(int_i),
           .timer_int_o(),

           .debug_wb_pc(debug_wb_pc),
           .debug_wb_rf_wen(debug_wb_rf_wen),
           .debug_wb_rf_wnum(debug_wb_rf_wnum),
           .debug_wb_rf_wdata(debug_wb_rf_wdata)
         );

endmodule
