// 暂时保存取指阶段取得的指令，以及对应的指令地址
`include "defines.v"
module if_id(
         input wire clk,
         wire rst,
         wire[`InstAddrBus] if_pc,
         wire[`InstBus] if_inst,

         // CTRL
         input wire flush,
         input wire[5:0] stall, // From CTRL module.

         // if inst is a valid signal
         input wire inst_valid,

         // if pc is

         // if pc is ready to recive branch signal
         input wire pc_ready,
         // if in branch
         input wire branch_flag,
         output reg[`InstAddrBus] id_pc,
         reg[`InstBus] id_inst,
         // if we need to stall due to axi wait
         output reg             stallreq_for_if,
         output reg             stallreq_for_ex,
         // if ready to receive inst
         output wire inst_ready,
         // tell pc don't request because if cannot receive any more.if_inst
         output wire full,

         // PC传来的异常类型
         input wire[`RegBus] pc_excepttype,
         // 传向ID的异常
         output reg[`RegBus] id_excepttype,

         // 来自 id
         input wire id_next_in_delay_slot,

         // 当前指令是否在延迟槽中
         output reg id_in_delay_slot
       );


// to adapt axi_read_adaptor
// always @(*) begin
//     inst
// end


// if_pc 取指阶段取得的指令对应的地址
// if_inst 取指阶段取得的指令
// id_pc 译码阶段的指令对应的地址
// id_inst 译码阶段的指令

// 指令仅在 inst_valid 情况下有意义
wire[`RegBus] if_pc_filtered;
wire[`RegBus] if_inst_filtered;

reg in_delay_slot;

assign if_pc_filtered = inst_valid? if_pc: `ZeroWord;
assign if_inst_filtered = inst_valid? if_inst: `ZeroWord;

always @(posedge clk)
  begin
    // 只是对数据做了简单的带使能的保存\传递功能
    if (rst == `RstEnable)
      begin
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
      end
    else if(flush == 1'b1)
      begin
        // flush 为 1 表示异常发生，要清楚流水线
        // 所以复位 id_pc, id_inst 寄存器的值
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
      end
    else if (stall[1] == `NoStop && pc_ready== `Ready && full == 1'b1 && branch_flag == 1'b1)
      begin
        // 这说明此时向后输出的信号是 full 中的，马上 full 的值也要消失了，
        // id_pc <= saved ? saved_pc : if_pc_filtered;
        // id_inst <= saved? saved_inst : if_inst_filtered;
        id_pc <= if_pc_filtered;
        id_inst <= if_inst_filtered;
      end
    else if(stall[1] == `Stop && stall[2] == `NoStop && inst_valid == `InValid)
      begin
        // 表示取指阶段暂停，而译码阶段继续，所以使用空指令为下一个周期进入译码阶段的指令
        // 如果 inst_valid == `Valid 的话，说明已经从 mem 读取了数据，这时应当往下传输
        // $display("if_inst = %x, valid = %d, stall!", if_inst, inst_valid);
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
      end
    else if(stall[1] == `Stop && stall[2] == `Stop && full == 1'b0 && branch_flag == 1'b1 && pc_ready== `Ready)
      begin
        id_pc <= if_pc_filtered;
        id_inst <= if_inst_filtered;
      end
    else if(stall[1] == `Stop && stall[2] == `Stop && inst_valid == `Valid && id_inst == `ZeroWord)
      begin

        id_pc <= if_pc_filtered;
        id_inst <= if_inst_filtered;

      end
    else if(stall[1] ==  `Stop && stall[2] == `NoStop && inst_valid == `Valid && inst_ready == `Ready)
      begin
        //  now if_* have the right value;
        id_pc <= saved ? saved_pc : if_pc_filtered;
        id_inst <= saved? saved_inst : if_inst_filtered;
      end
    else if(stall[1] == `NoStop)
      begin
        // 这时两个阶段都为继续，正常工作
        id_pc <= saved ? saved_pc : if_pc_filtered;
        id_inst <= saved? saved_inst : if_inst_filtered;
      end
    else
      begin
        // stall[1] == `Stop

        if (last_inst_valid == `Valid)
          begin
            // mem 也暂停了流水线，这时候会形成死锁，需要在这里解开对 axi read 的占用
            // 什么时候存 现在
            // 怎么存 还需要有信号标识：已经收到了一个值
            // 什么时候释放 当 stall 结束了

            // inst_ready <= `Ready;


          end
        else if(stall[4:1] == 4'b1111)
          begin
            // 但恐怕目前这种不严格的判断，会导致，如果 id_inst 目前已经有合法的值，这样会被冲刷掉
            // 但其实目前应该可以假设，mem 锁住流水线的时候，id 没有东西
            // 这里是 mem 暂停流水线时的情况
            // id_pc <=if_pc_filtered;
            // id_inst <= if_inst_filtered;

          end
        else
          begin
            // 这里要利用好 ready 信号，控制 axi，不要使之转换到 Free 状态
          end
      end
    // 其余情况下，保持输出不变
  end

reg last_inst_valid;
reg[`RegBus] saved_inst;
reg saved;
reg[`RegBus] saved_pc;
assign inst_ready = !full;

always @(posedge clk)
  begin
    if(rst == `RstEnable)
      begin
        saved_inst <= `ZeroWord;
        saved_pc <= `ZeroWord;
        saved <= 1'b0;
      end
    else if (stall[1] == `Stop && stall[2] == `Stop && inst_valid == `Valid && id_inst != `ZeroWord)
      begin
        // 此时应该保存
        saved_inst <= if_inst;
        saved_pc <= if_pc;
        saved <= 1'b1;
      end
    else if (stall[1] == `Stop && stall[2] == `Stop)
      begin

      end
    else
      begin
        saved <= 1'b0;
      end

  end

always @(posedge clk)
  begin
    if(rst == `RstEnable)
      last_inst_valid <= `InValid;
    else
      last_inst_valid <= inst_valid;
  end

assign full = saved;

// 这个信号表示　if_id 没有数据了，将提供空指令
// if_id 如果收到这个信号，应该保持指令为空
always @(*)
  begin
    if(rst == `RstEnable)
      stallreq_for_if = `NoStop;
    else if (inst_valid)
      stallreq_for_if = `NoStop;
    else
      stallreq_for_if = `Stop;


  end


always @(*)
  begin
    if(rst == `RstEnable)
      stallreq_for_ex = `NoStop;
    else if(!branch_flag|| (branch_flag && pc_ready))
      stallreq_for_ex = `NoStop;
    else
      stallreq_for_ex = `Stop;
  end

always @(posedge clk)
  begin
    if (rst == `RstEnable)
      begin
        in_delay_slot<=`False_v;

      end
    else if (id_next_in_delay_slot == 1'b1)
      begin
        // 一旦收到了，先保存着，在 valid 以后再释放
        in_delay_slot <= id_next_in_delay_slot;
      end
    else if (inst_valid == `Valid)
      begin
        in_delay_slot<=id_next_in_delay_slot;

      end
    else
      begin

      end

    // 为了产生一个周期的延迟，和其他数据同步。
    if(rst == `RstEnable)
      id_in_delay_slot <= `False_v;
    else
      id_in_delay_slot <= (inst_valid == `Valid)? in_delay_slot:`False_v;
  end

endmodule // if_id
