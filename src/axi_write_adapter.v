// AXI 总线协议写入部分适配器
// 对外暴露 AXI 写通道 master interface
`include "defines.v"
module axi_write_adapter(
           input
           wire clk, reset,
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
           reg         awvalid,
           input
           wire    awready,

           // write data channel signals
           output
           wire[3:0]    wid,
           wire[31:0]   wdata,
           wire[3:0]   wstrb,
           wire        wlast,
           reg        wvalid,
           input       wready,

           // write response channel signals
              input
              wire[3:0]   bid,
              wire[1:0]   bresp,
              wire        bvalid,
              output
              wire        bready,
        
            // from/to mem
            input
            wire[31:0]      data,
            wire            we,
            wire            address,
            output
            // if mem write is done.
            wire            mem_write_valid
       );

reg write_channel_state;

assign awid = 4'b0;
assign wid = 4'b0;
assign bid = 4'b0;
// 4.2
assign awlen = 4'b0;
assign wlen = 4'b0;
// 4.3 4 Bytes
// TODO?
assign awsize = 3'b010;
// 4.4
assign awburst = 2'b0;
// 2.3
assign wlast = 1'b1;
// 6.1
assign awlock = 2'b0;
// 9.2
assign wstrb = 4'b1111;
// 5.1
assign awcache = 3'b0;
// 5.2
assign awprot = 3'b000;
assign awaddr = address;
assign wdata = data;
assign mem_write_valid = bvalid;

// ignore the BRESP because we always accept it

// assign awvalid = we;
// assign wvalid = we;
// set it to high according to 3.1.2
assign bready = 1'b1;

always @(posedge clk) begin
    if(reset == `RstEnable) begin
        write_channel_state <= `WriteFree;
        awvalid <= `InValid;
        wvalid <= `InValid;
    end
    else if(we == `Valid && write_channel_state == `WriteFree) begin
        // free -> busy
        write_channel_state <= `WriteBusy;
        awvalid <= `Valid;
        wvalid <= `Valid;
    end
    else if(bvalid == `Valid && write_channel_state == `WriteBusy) begin
        write_channel_state <= `WriteFree;
    end

    if (awready == `Ready && awvalid == `Valid)
        awvalid <= `InValid;
    
    if (wready == `Ready && awvalid == `Valid)
        wvalid <= `InValid;
end


endmodule // axi_write_adapter
