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
         wire[31:0]   araddr,
         wire[3:0]   arlen,
         wire[2:0]   arsize,
         wire[1:0]   arburst,
         wire[1:0]   arlock,
         wire[3:0]   arcache,
         wire[2:0]   arprot,
         output reg  arvalid,
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
         reg            rready,

         // from/to if_pc

         input
         wire[31:0]     pc,
         input wire     pc_re,
         // 送往 pc, 表示是否该地址已经读取完毕，可以跳转到下一地址
         // 只存在一个周期。
         // 由它来控制 pc 的行为
         output reg    pc_ready,
         // 从 IF 过来的，是否可以接受输入的信号
         input wire             inst_read_ready,
         // inst must can remember(store),
         // when get signal from memory but if_id are not ready to recive,
         // inst and inst_valid must keep it's value, wait for ready signal
         output
         reg[31:0]        inst,
         // 去 IF ，表示数据是否 valid
         output reg       inst_valid,
         output wire[`RegBus]      current_inst_address,

         // from/to mem
         input
         wire             mem_re,
         wire             mem_data_read_ready,
         wire[31:0]       mem_addr,
         output
         reg              mem_data_valid,
         reg[31:0]       mem_data,
         // 消除锁存器以后，传出的信号延迟了一个周期，导致当读取完毕，状态为 free 时，上一次
         //  的 mem_re 还没有消除，所以增加这个信号用来告诉 mem 提前把 mem_re 变成 0；
         output reg      mem_addr_read_ready
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

reg[`RegBus] unmapped_address;

// 因为 CPU flush 的时候，这个模块还在等待读的结果，所以不能很快完成
// 因此需要记忆住这个指令是需要丢弃的
// 所以如果 inst_valid 后，这个指令是 flush，并且 Read_for_IF，就传递空指令
reg have_to_flush;

assign arid = 4'b0;
assign arlen = 4'b0;
assign arsize = 3'b010;
assign arburst = 2'b0;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b001;

assign araddr =  (unmapped_address[31:29] == 3'b100 ||
                  unmapped_address[31:29] == 3'b101
                 )? { 3'b0,unmapped_address[28:0]} : unmapped_address;

// flush 后取消这个指令
assign current_inst_address = have_to_flush? `ZeroWord: current_address;

// 发现因为流水线时序的问题，不得不把 if_id 变成组合逻辑（提前一个时钟周期）
// 让 pc 增加发生在 arvalid 出现时，不过这样，当数据传递的时候，pc 是下一个时钟周期的
// 这会影响到后面的执行结果
// 所以必须保存着当前的 address
reg[`RegBus] current_address;

// read ready
// 按照状态，与 IF 或者 MEM 的 valid 信号相接

// end else if ((mem_re && !rvalid) || (mem_we && !wvalid)) begin
// mem_data_ready <= 1'b0;

reg[1:0] read_channel_state;

// 决定 araddress 的值
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
        unmapped_address <= 32'b0;
        arvalid <= `InValid;
        pc_ready <= `NotReady;
        current_address <= `ZeroWord;
        mem_addr_read_ready <= `NotReady;
      end
    else if  (read_channel_state == `BusyForIF)
      // state: BusyForIF
      begin
        if (rvalid == `Valid && inst_read_ready == `Ready )
          begin

            // 在此时数据向 IF 进行了传输，状态归位
            // $display("read data: %x\n", rdata);
            read_channel_state <= `ReadFree;
          end
        else if (flush == 1'b1)
          begin
            // 正在等待读的时候，flush 来了
            // 改动在后面了
          end
      end
    else if (read_channel_state == `BusyForMEM && mem_data_read_ready == `Ready)
      begin
        if (rvalid==`Valid && mem_data_read_ready == `Ready)
          begin
            read_channel_state <= `ReadFree;
            current_address <= `ZeroWord;
          end
      end
    else if (read_channel_state == `ReadFree)
      begin
        // 当 free 时
        if (mem_re == `Valid)
          begin
            // for mem, start to read
            // $display("read channel activated, address = %x", mem_addr);
            read_channel_state <= `BusyForMEM;
            unmapped_address <= mem_addr;
            arvalid <= `Valid;
            current_address <= mem_addr;
          end
        else if (pc_re == `Valid)
          begin
            // for if, start to read
            read_channel_state <= `BusyForIF;
            unmapped_address <= pc;
            arvalid <= `Valid;
            current_address <= pc;
          end
        else
          begin
            // or remain free
            current_address <= `ZeroWord;
          end
      end
    // else remain the same state

    if (arready == `Ready && read_channel_state == `BusyForIF && arvalid == `Valid)
      begin
        // 如果在某个上升沿，addr ready 了，就停掉 valid，关于 IF
        pc_ready <= `Ready;
        unmapped_address <= 32'b0;
        arvalid <= `InValid;
      end
    else if
    (arready == `Ready && read_channel_state == `BusyForMEM && arvalid == `Valid)
      begin
        // about MEM
        unmapped_address <= 32'b0;
        arvalid <= `InValid;
        mem_addr_read_ready <= `Ready;
      end
    else
      begin
        mem_addr_read_ready <= `NotReady;
        pc_ready <= `NotReady;
      end
  end

// flush
always @(posedge clk)
  begin
    if (reset == `RstEnable )
      begin
        have_to_flush <= 1'b0;
      end
    else if (read_channel_state == `ReadFree)
      begin
        have_to_flush <= 1'b0;
      end
    else if (flush == 1'b1)
      begin
        have_to_flush <= 1'b1;
      end
  end

// 送往 if 是否 valid
// 将会有可能决定对方流水线暂停与否
always @(posedge clk)
  begin
    if (!reset)
      begin
        // 如果需要 reset，所有输出为 0
        // axi master out buses
        inst_valid = `InValid;
        inst = `ZeroWord;
        mem_data = `ZeroWord;
        mem_data_valid = `InValid;
      end
    else if (read_channel_state == `BusyForIF)
      begin
        // in this state we should treat inst_valid and inst properly,
        // otherwise is in `BusyForMem` state
        if(have_to_flush==1'b1)
          begin
            // flush
            // 一直持续到本次读结束
            inst_valid = rvalid;
            inst = `ZeroWord;

          end
        else if (inst_valid == `Valid && inst_read_ready == `NotReady)
          begin
            // should wait for inst_read_ready
            // inst_valid = inst_valid;
            // 是这里产生了锁存吗？
            // inst = inst;
          end
        else
          begin
            inst_valid = rvalid;
            inst = rdata;
          end
        mem_data = `ZeroWord;
        mem_data_valid = `InValid;
      end
    else if (read_channel_state == `BusyForMEM)
      begin
        // in this state we should treat mem_data and mem_data_valid properly,
        // otherwise is in `BusyForIF` state
        if(mem_data_valid == `Valid && mem_data_read_ready == `NotReady)
          begin
            // should wait for mem_data_read_ready
            // we latch
            // mem_data_valid = mem_data_valid;
            // mem_data = mem_data;
          end
        else
          begin
            mem_data = rdata;
            mem_data_valid = rvalid;
          end

        inst_valid = `InValid;
        inst = `ZeroWord;
      end
    else
      begin
        // in `Free`
        inst_valid = `InValid;
        inst = `ZeroWord;
        mem_data = `ZeroWord;
        mem_data_valid = `InValid;
      end


    // ! 将语句移到这里是因为出现了多驱动的问题
    // ! 这里代码有点多余
    // 送往 mem 是否 valid
    // 将会有可能决定对方流水线暂停与否
    if(reset == `RstEnable)
      mem_data_valid = `InValid;
    else if (rvalid == `Valid && read_channel_state == `BusyForMEM)
      // 只有为 MEM 服务且信号正常时，才会 valid
      mem_data_valid = `Valid;
    else
      mem_data_valid = `InValid;
    // else if ((rvalid == `Valid && read_channel_state == `BusyForIF )
    //          ||(read_channel_state == `BusyForIF && inst_read_ready == `NotReady))
    //   // 有两种可能，一种是 valid 来了，需要保持一致
    //   //  另一种是 还在等待 if_id ready
    //   // 数据到了
    //   begin
    //     inst_valid = `Valid;
    //     inst = inst;
    //   end
    // else
    //   // 无关状态
    //   inst_valid = rvalid;
  end

// always @(*)
// begin

// end

// rready
always @(*)
  begin
    if (reset == `RstEnable)
      begin
        rready = `NotReady;
      end
    else if (read_channel_state == `ReadFree)
      begin
        rready = `NotReady;
      end
    else if (read_channel_state == `BusyForIF)
      begin
        rready = inst_read_ready;
      end
    else if (read_channel_state == `BusyForMEM)
      begin
        rready = mem_data_read_ready;
      end
  end


endmodule // axi_read_adapter
