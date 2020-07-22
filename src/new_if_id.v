`include "defines.v"

module new_if_id (
         input
         wire clk,
         wire rst,
         wire flush,
         // 当前传入的 pc 和 inst 是否 valid
         wire valid,
         wire[`InstAddrBus] if_pc,
         wire[`InstBus] if_inst,

         input wire[5:0] stall,

         // 来自 id，下一个是否是延迟槽指令
         input wire id_next_in_delay_slot,


         output wire[`InstAddrBus] id_pc,
         output wire[`InstBus] id_inst,

         // 是否 axi 可以读取下个 pc
         output wire next_pc_valid,

         output reg id_in_delay_slot
       );

reg[`RegBus] stored_inst;
reg[`RegBus] stored_pc;

reg delayed_next_pc_valid;

reg last_rst;

always @(posedge clk)
  begin
    last_rst <= rst;
  end

assign next_pc_valid = (valid && stall[1] == `NoStop) || delayed_next_pc_valid;

assign id_pc = (rst == `RstEnable) ? `ZeroWord: (stall[1] == `NoStop && valid) ? if_pc : ((stall[1] == `NoStop) ? stored_pc :`ZeroWord );
assign id_inst = (rst == `RstEnable) ? `ZeroWord: (stall[1] == `NoStop && valid) ? if_inst : ((stall[1] == `NoStop) ? stored_inst: `ZeroWord) ;

// 在 stall 时存储，随后输出
always @(posedge clk)
  begin
    begin
      if (rst == `RstEnable || flush == `Valid)
        begin
          stored_inst <= `ZeroWord;
          stored_pc <= `ZeroWord;
        end
      else if (valid == `Valid && stall[1] == `Stop)
        begin
          stored_inst <= if_inst;
          stored_pc <= if_pc;
        end
      else if (stall[1] == `NoStop && stored_inst != `ZeroWord)
        begin
          // 此时旧值正好传给 id_*，所以清零
          stored_inst <= `ZeroWord;
          stored_pc <= `ZeroWord;
        end
      else
        begin
          // 否则不变
        end
    end
  end

always @(posedge clk)
  begin
    begin
      if (rst == `RstEnable || flush == `Valid)
        begin
          // on reset or flush
          delayed_next_pc_valid <= `InValid;
        end
      else
        begin
          if (valid == `Valid && stall[1] == `NoStop)
            begin
              delayed_next_pc_valid <= `InValid;
            end
          else if (stall[1] == `NoStop && stored_inst != `ZeroWord)
            begin
              delayed_next_pc_valid <= `Valid;
            end
          else if (rst ==  `RstDisable && last_rst == `RstEnable)
            begin
              delayed_next_pc_valid <= `Valid;
            end
          else
            begin
              delayed_next_pc_valid <= `InValid;
            end
        end
    end
  end


reg in_delay_slot;

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
    else if (valid == `Valid)
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
      id_in_delay_slot <= (valid == `Valid)? in_delay_slot:`False_v;
  end
endmodule
