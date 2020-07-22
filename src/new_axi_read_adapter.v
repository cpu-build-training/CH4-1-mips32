// 指令的 AXI 总线协议适配器
// 对外暴露 AXI master interface， 对内连接 pc_reg/mem
`include "defines.v"

module new_axi_read_adapter(
         // axi master interface
         input
         wire clk, reset,



         // read address channel signals
         output
         wire[3:0]   arid,
         wire[31:0]   araddr,
         wire[3:0]   arlen,
         wire[2:0]   arsize,
         wire[1:0]   arburst,
         wire[1:0]   arlock,
         wire[3:0]   arcache,
         wire[2:0]   arprot,
         output wire  arvalid,
         input
         wire        arready,

         // input
         input wire  flush,

         // read data channel signals
         input
         wire[3:0]      rid,
         wire[31:0]     rdata,
         wire[1:0]     rresp,
         input wire     rlast,
         wire           rvalid,
         output
         wire            rready,

         // from/to master
         // 地址
         input wire[31:0] address,
         // valid 信号，表示是有效的读取请求
         input wire address_valid,
         // 表示是否该地址已经读取完毕，可以跳转到下一地址
         // 只存在一个周期。
         // 由它来控制 pc 的行为
         output wire address_read_ready,

         // 表示数据是否 valid
         output wire data_valid,
         // 读取的数据本身
         output wire[31:0] data,
         // 随着 data 一起输出的地址
         output wire[`RegBus] data_address
       );



// 未经过映射的地址
// 需要经过映射以后才能送出
// 但送回 if_id 的地址不需要映射
// 可以在此阶段映射，但在后续的阶段映射更好（合并以后）
reg[`RegBus] unmapped_address;

reg flushed;


assign arid = 4'b0;
assign arlen = 4'b0;
assign arsize = 3'b010;
assign arburst = 2'b0;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b001;

assign rready = 1'b1;

assign data = (reset == `RstEnable || flushed == 1'b1)? `ZeroWord: rdata;
assign data_address = (reset == `RstEnable || flushed == 1'b1)? `ZeroWord: unmapped_address;
assign data_valid = (reset == `RstEnable)? 1'b0: rvalid;

// 1'b0 当前没有任务
// 1'b1 正在与 slave 握手
// reg busy;

always @(posedge clk)
  begin
    if (reset == `RstEnable)
      begin
        flushed <= 1'b0;
      end
    else if (flush)
      begin
        flushed <= 1'b1;
      end
    else if (data_valid || address_valid)
      begin
        flushed <= 1'b0;
      end
  end

assign araddr =  (unmapped_address[31:29] == 3'b100 ||
                  unmapped_address[31:29] == 3'b101
                 )? { 3'b0,unmapped_address[28:0]} : unmapped_address;


assign address_read_ready = (arready && arvalid)? `Ready : `NotReady;

// save address
always @(posedge clk)
  begin
    if(reset == `RstEnable)
      unmapped_address <= `ZeroWord;
    else if(address_valid == `Valid)
      unmapped_address <= address;
    else
      begin

      end
  end

// 如果当 address_valid 来临时， arready 没有就绪，那么需要存储
reg stored_address_valid;

assign arvalid = address_valid || stored_address_valid;


always @(posedge clk)
  begin
    if(reset == `RstEnable)
      stored_address_valid <= `InValid;
    else if (address_valid && (arready == `NotReady))
      stored_address_valid <= `Valid;
    else if (stored_address_valid && arready)
      stored_address_valid <= `InValid;
    else begin

    end
  end
endmodule
