// AXI 总线协议适配器
// 对外暴露 AXI Master interface， 对内连接所有访存的设备和控制器
`include "defines.v"
module axi_read_adapter(
         // axi master interface
         input
         wire clk, reset,



         // read address channel signals
         output
         wire[3:0]   arid,
         reg[31:0]  araddr,
         wire[3:0]  arlen,
         wire[2:0]   arsize,
         wire[1:0]   arburst,
         wire[1:0]   arlock,
         wire[3:0]   arcache,
         wire[2:0]   arprot,
         reg        arvalid,
         input
         wire        arready,

         // read data channel signals
         input
         wire[3:0]    rid,
         wire[31:0]   rdata,
         wire[1:0]    rresp,
         wire         rlast,
         wire         rvalid,
         output
         reg         rready,

         // from/to if_pc

         input
         wire[31:0]       pc,
         wire             pc_re,
         // 从 IF 过来的，是否可以接受输入的信号
         wire             inst_read_ready,
         output
         wire[31:0]        inst,
         // 去 IF ，表示数据是否 valid
         reg              inst_valid,

         // from/to mem
         input
         wire             mem_re,
         wire[31:0]       mem_addr,
         wire             mem_data_read_ready,
         output
         reg              mem_data_valid,
         wire[31:0]       mem_data
       );
/////////////////////////////////////////////////////////////
//
// 设计的一个关键之一在于怎样控制流水线暂停，可选方法包括：
//    1. axi_read_adapter 直接连接 CTRL
//    2. axi_read_adapter 将信号（valid）传递给相关模块，由相关模块自己申请
// 这个 “控制” 既包括如何停止流水线，也包括如何恢复流水线。
// 目前我的想法是，只要不能确定下一个周期必将有信号到达，
// 那就必须使用 data-valid-ready 组合。
// 比如在 pc 访存这一部分中：
//      1. 因为 rom_data 送入 if_id, 因此 if_id 负责请求流水线暂停，
//          自己作为交界。
//      2. 当 if_id 在 axi not valid 情况下会一直暂停，
//          当 valid 时，他将恢复流水线，并返回 ready
//      3. 此时 axi 并不能在收到 ready 时立刻改变输出数据状态，
//          因为对方只能在时钟上升沿读取，
//          因此 axi 会在下一个周期再处理下一个请求。
//          在下一个周期的行为包括，取消 valid，以及更新 AXI 输出寄存器的值
//      4. 在暂停期间，AXI 需要通过一个寄存器来存放输出的数据，
//          原因是因为输入信号 mem 在暂停 if 期间依然有可能改变，
//          这时需要保证当前正在请求的数据不被改变。
//      5. 由于有寄存器的存在，这时 读 和 写 需要两个独立的状态机。
//          free 状态：可以接受信号，如果存入信号，将在下一个周期转为 busy
//          busy 状态：没有完成请求
//          不过如果只有两个状态的话，可以直接根据其他逻辑信号计算得出？
//
//
// 另外需要考虑到 ready 问题，当其他模块也在暂停流水显时，本模块要知道此时对方没有 ready，不能传输。
//
// 优先级问题：
//     pc 和 mem 有可能同时需要读取数据，根据流水线的推论，需要优先 mem。
/////////////////////////////////////////////////////////////

assign arid = 4'b0;
assign arlen = 4'b0;
assign arsize = 3'b010;
assign arburst = 2'b0;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b001;

// read data
assign mem_data = rdata;
assign inst = rdata;

// read ready
// 按照状态，与 IF 或者 MEM 的 valid 信号相接

// end else if ((mem_re && !rvalid) || (mem_we && !wvalid)) begin
// mem_data_ready <= 1'b0;


reg[1:0] read_channel_state;

// 决定 arvalid 的状态和 araddress 的值
// araddress 由 pc 给出
// 在收到对方的 rready 后，需要变为 invalid
// 且在数据到来之前，不能重复发送信号
// read_channel_state
// 当同时读的时候，mem 优先
always @(posedge clk)
  begin
    if (reset == `RstEnable)
      begin
        read_channel_state <= `ReadFree;
        araddr <= 32'b0;
        arvalid <= 1'b0;
      end
    else if (read_channel_state != `ReadFree
             && rvalid == `Valid)
      begin
        if (read_channel_state == `BusyForIF && inst_read_ready == `Ready)
          // 在此时数据向 IF 进行了传输，状态归位
          read_channel_state <= `ReadFree;
        else if (read_channel_state == `BusyForMEM && mem_data_read_ready == `Ready)
          // TODO: 判断
          read_channel_state <= `ReadFree;
      end
    else if (read_channel_state == `ReadFree)
      begin
        // 当 free 时
        if (mem_re == `Valid)
          begin
            // for mem, start to read
            read_channel_state <= `BusyForMEM;
            araddr <= mem_addr;
            arvalid <= `Valid;
            rready <= mem_data_read_ready;
          end
        else if (pc_re == `Valid)
          begin
            // for if, start to read
            read_channel_state <= `BusyForIF;
            araddr <= pc;
            arvalid <= `Valid;
          end
        // or remain free
      end
    // else remain the same state

    if (arready == `Ready && read_channel_state != `ReadFree && arvalid == `Valid)
      begin
        araddr <= 32'b0;
        arvalid <= `InValid;
      end
    // 如果在某个上升沿，addr ready 了，就停掉 valid
  end


// 送往 if 是否 valid
// 将会有可能决定对方流水线暂停与否
always @(*)
  begin
    if (!reset)
      // 如果需要 reset，所有输出为 0
      // axi master out buses
      inst_valid <= `InValid;
    else if (pc_re == `Valid && rvalid == `Valid && read_channel_state == `BusyForIF )
      // 数据到了
      inst_valid <= `Valid;
    else
      // 无关状态
      inst_valid <= `InValid;
  end

// 送往 mem 是否 valid
// 将会有可能决定对方流水线暂停与否
always @(*)
  begin
    if(reset == `RstEnable)
      mem_data_valid <= `InValid;
    else if (mem_re == `Valid && rvalid == `Valid && read_channel_state == `BusyForMEM)
      // 只有为 MEM 服务且信号正常时，才会 valid
      mem_data_valid <= `Valid;
    else
      mem_data_valid <= `InValid;
  end

assign awaddr = mem_addr;


endmodule // axi_read_adapter
