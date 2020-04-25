// 访存阶段
`include "defines.v"

module mem(
         input wire clk,
         input wire rst,
         // 来自执行阶段的信息
         input
         wire[`RegAddrBus]       wd_i,
         input wire              wreg_i,
         wire[`RegBus]           wdata_i,


         input wire whilo_i,
         wire[`RegBus]    hi_i,
         wire[`RegBus]    lo_i,

         // 来自执行阶段的信息
         wire[`AluOpBus]  aluop_i,
         wire[`RegBus]    mem_addr_i,
         wire[`RegBus]    reg2_i,

         // 来自外部数据存储器 RAM 的信息
         // 读取的 data 是否 valid
         input wire             mem_data_i_valid,
         wire[`RegBus]    mem_data_i,
         // 表示已经不需要再传输 mem_re
         (*mark_debug="true"*)input wire        mem_addr_read_ready,
         // axi bvalid
         // 写入是否 ready
         input wire             mem_write_ready,

         // 新增的输入接口
         wire             LLbit_i,
         wire             wb_LLbit_we_i,
         wire             wb_LLbit_value_i,

         // cp0
         wire             cp0_reg_we_i,
         wire[4:0]        cp0_reg_write_addr_i,
         wire[`RegBus]    cp0_reg_data_i,

         // 异常
         // 来自执行阶段
         wire[31:0]           excepttype_i,
         input wire                 is_in_delayslot_i,
         wire[`RegBus]       current_inst_address_i,

         // 来自 CP0 模块
         wire[`RegBus]        cp0_status_i,
         wire[`RegBus]        cp0_cause_i,
         wire[`RegBus]        cp0_epc_i,

         // 回写阶段的指令对 CP0 中寄存器的写信息
         // 用来检测数据相关
         input wire                wb_cp0_reg_we,
         wire[4:0]           wb_cp0_reg_write_addr,
         wire[`RegBus]       wb_cp0_reg_data,

         // 访存阶段的结果
         output
         reg[`RegAddrBus]        wd_o,
         output reg                     wreg_o,
         reg[`RegBus]            wdata_o,

         reg[`RegBus]         hi_o,
         reg[`RegBus]         lo_o,
         output reg whilo_o,
         // 送到外部数据存储器 RAM 的信息
         reg[`RegBus]         mem_addr_o,
         output wire          mem_read_ready,
         wire                 mem_we_o,
         reg[3:0]             mem_sel_o,
         reg[`RegBus]         mem_data_o,
         output reg           mem_ce_o,
         wire                 mem_re_o_filtered,

         // 新增的输出接口
         reg                  LLbit_we_o,
         reg                  LLbit_value_o,

         // cp0
         reg           cp0_reg_we_o,
         reg[4:0]      cp0_reg_write_addr_o,
         reg[`RegBus]  cp0_reg_data_o,

         // 异常
         reg[31:0]       excepttype_o,
         wire[`RegBus]   cp0_epc_o,
         wire[`RegBus]   current_inst_address_o,
         output wire     is_in_delayslot_o,
         output wire     stallreq_for_mem,
         wire[`RegBus]   badvaddr_o
       );
wire[`RegBus]   zero32;
reg             mem_we;

// 保存 LLbit 寄存器的最新值
reg LLbit;
// CP0 中 Status 寄存器的最新值
reg[`RegBus]        cp0_status;
// CP0 中 Cause 寄存器的最新值
reg[`RegBus]        cp0_cause;
// CP0 中 EPC 寄存器的最新值
reg[`RegBus]        cp0_epc;

(*mark_debug="true"*)wire mem_re_o;

// 外部数据存储器 RAM 的读写信号
// 不小心 multi-driver 了
// assign mem_we_o = mem_we;
assign zero32 = `ZeroWord;

// 表示访存阶段的指令是否是延迟槽指令
assign is_in_delayslot_o = is_in_delayslot_i;

// 访存阶段指令的地址
assign current_inst_address_o = current_inst_address_i;

// 在读写没有完成之前，都要请求暂停
assign stallreq_for_mem = (mem_we_o && !mem_write_ready) || (mem_re_o && !mem_data_i_valid);

// 转化出读使能
assign mem_re_o = mem_ce_o && !mem_we_o;

(*mark_debug="true"*)reg no_need_for_mem_re;

assign mem_re_o_filtered = no_need_for_mem_re? `InValid: mem_re_o;

// always @(posedge mem_addr_read_ready or negedge mem_re_o or negedge rst or posedge rst) begin
//   if (rst == `RstEnable) begin
//     no_need_for_mem_re = 1'b0;
//   end else if(mem_re_o == `Valid && mem_addr_read_ready == `Ready) begin
//   // 刚开始发出信号的时候
//     no_need_for_mem_re = 1'b1;
//   end else if(mem_re_o == `InValid)begin
//   // 已经读到了数据
//     no_need_for_mem_re = 1'b0;
//   end
// end
always @(posedge clk)
  begin
    if( rst == `RstEnable)
      begin
        no_need_for_mem_re = `InValid;
      end
    else if (mem_addr_read_ready == `Ready && mem_re_o == `Valid)
      begin
        no_need_for_mem_re = `Valid;
      end
    else if (mem_data_i_valid == `Valid)
      begin
        no_need_for_mem_re = `InValid;
      end
    else
      begin

      end

  end

// always ready because it's a logistic module and it never stall by other reason.
assign mem_read_ready = `Ready;

// 传给cp0,只有在有异常的时候才有用
// 只有LH,LHU,LW,SH,SW产生地址未对齐异常,而对应的badvaddr就是前面传过来的mem_addr_i
// 如果 pc 有异常，说明是 pc 读取地址错误，需要保存的地址是 pc 中的内容
assign badvaddr_o = (current_inst_address_i[1:0] == 2'b00)? mem_addr_i:current_inst_address_i;

// 获取 LLbit 寄存器的最新之， 如果回写阶段的指令要写 LLbit，那么回写阶段要写入的
// 值就是 LLbit 寄存器的最新值，反之， LLbit 模块给出的值 LLbit_i 是最新值
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        LLbit = 1'b0;
      end
    else
      begin
        if (wb_LLbit_we_i == 1'b1)
          begin
            // 回写阶段指令要写 LLbit
            LLbit = wb_LLbit_value_i;
          end
        else
          begin
            LLbit = LLbit_i;
          end
      end
  end

/// 第一段：得到 CP0 中寄存器的最新指
// 得到 CP0 中 Status 的最新值
// 判断当前处于回写阶段的指令是否要写 CP0 中 Status 寄存器，如果要写，
// 那么要写如的值就是 Status 寄存器的最新值，反之，从 CP0 模块通过 cp0_status_i 接口
// 传入的数据就是 Status 寄存器的最新值
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        cp0_status = `ZeroWord;
      end
    else if ((wb_cp0_reg_we == `WriteEnable) &&
             (wb_cp0_reg_write_addr == `CP0_REG_STATUS))
      begin
        cp0_status= wb_cp0_reg_data;
      end
    else
      begin
        cp0_status = cp0_status_i;
      end
  end

// 得到 CP0 中 EPC 寄存器的最新值，与上同理
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        cp0_epc = `ZeroWord;
      end
    else if ((wb_cp0_reg_we == `WriteEnable) &&
             (wb_cp0_reg_write_addr == `CP0_REG_EPC))
      begin
        cp0_epc = wb_cp0_reg_data;
      end
    else
      begin
        cp0_epc = cp0_epc_i;
      end
  end

// 将 EPC 寄存器的最新值通过接口 cp0_epc_o 输出
assign cp0_epc_o = cp0_epc;

// 得到 CP0 中 Cause 寄存器的最新值
// Cause 只有几个字段是可写的。
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        cp0_cause = `ZeroWord;
      end
    else if((wb_cp0_reg_we == `WriteEnable)&&
            (wb_cp0_reg_write_addr == `CP0_REG_CAUSE))
      begin
        cp0_cause = `ZeroWord;
        // IP[1:0] 字段是可写的
        cp0_cause[9:8] = wb_cp0_reg_data[9:8];
        // WP 字段
        cp0_cause[22] = wb_cp0_reg_data[22];
        // IV
        cp0_cause[23] = wb_cp0_reg_data[23];
      end
    else
      begin
        cp0_cause = cp0_cause_i;
      end

  end

/// 第二段：给出最终的异常类型

always @(*)
  begin
    if(rst == `RstEnable)
      begin
        excepttype_o = `ZeroWord;
      end
    else
      begin
        excepttype_o = `ZeroWord;
        if(current_inst_address_i != `ZeroWord)
          begin
            if (((cp0_cause[15:8] & (cp0_status[15:8]))!= 8'h00) &&
                (cp0_status[1] == 1'b0)&&
                (cp0_status[0] == 1'b1))
              begin
                // interrupt
                excepttype_o = 32'h0000_0001;
              end
            else if (excepttype_i[`SYSCALL_IDX] == 1'b1)
              begin
                // syscall
                excepttype_o = 32'h0000_0008;
              end
            else if (excepttype_i[`BREAK_IDX] == 1'b1)
              begin
                // break
                excepttype_o = 32'h0000_0009;
              end
            else if (excepttype_i[`INSTINVALID_IDX] == 1'b1)
              begin
                // inst_invalid
                excepttype_o = 32'h0000_000a;
              end
            else if (excepttype_i[`TRAP_IDX] == 1'b1)
              begin
                // trap
                excepttype_o = 32'h0000_000d;
              end
            else if (excepttype_i[`OVERFLOW_IDX] == 1'b1)
              begin
                // ov
                excepttype_o = 32'h0000_000c;
              end
            else if(excepttype_i[`ADEL_IDX] == 1'b1)
              begin
                excepttype_o = `ADEL_FINAL;
              end
            else if(excepttype_i[`ADES_IDX] == 1'b1)
              begin
                excepttype_o = `ADES_FINAL;
              end
            else if (excepttype_i[`ERET_IDX] == 1'b1)
              begin
                // eret
                excepttype_o = 32'h0000_000e;
              end
          end
      end
  end

// 第三段：给出对数据存储器的写操作
// mem_we_o 输出到数据存储器，表示是否为写操作
// 如果发生异常，那么就要取消写操作
assign mem_we_o = mem_we & (~(|excepttype_o));

// 目前是组合逻辑电路

always @(*)
  begin
    if(rst==`RstEnable)
      begin
        wd_o = `NOPRegAddr;
        wreg_o = `WriteDisable;
        wdata_o = `ZeroWord;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
        whilo_o = `WriteDisable;
        mem_addr_o = `ZeroWord;
        mem_we = `WriteDisable;
        mem_sel_o = 4'b0000;
        mem_data_o = `ZeroWord;
        mem_ce_o = `ChipDisable;
        LLbit_we_o = `WriteDisable;
        LLbit_value_o = 1'b0;
        cp0_reg_we_o = `WriteDisable;
        cp0_reg_write_addr_o = 5'b00000;
        cp0_reg_data_o = `ZeroWord;
      end
    if (excepttype_i[`ADES_IDX]==1'b1 && excepttype_i[`ADEL_IDX]== 1'b1)
      begin
        wd_o = wd_i;
        wreg_o = wreg_i;
        wdata_o = wdata_i;
        hi_o = hi_i;
        lo_o = lo_i;
        whilo_o = whilo_i;
        mem_addr_o = `ZeroWord;
        mem_we = `WriteDisable;
        mem_data_o = `ZeroWord;
        mem_sel_o = 4'b1111;
        mem_ce_o = `ChipDisable;
        LLbit_we_o = `WriteDisable;
        LLbit_value_o = 1'b0;
        cp0_reg_we_o = cp0_reg_we_i;
        cp0_reg_write_addr_o = cp0_reg_write_addr_i;
        cp0_reg_data_o = cp0_reg_data_i;
      end
    else
      begin
        wd_o = wd_i;
        wreg_o = wreg_i;
        wdata_o = wdata_i;
        hi_o = hi_i;
        lo_o = lo_i;
        whilo_o = whilo_i;
        mem_addr_o = `ZeroWord;
        mem_we = `WriteDisable;
        mem_data_o = `ZeroWord;
        mem_sel_o = 4'b1111;
        mem_ce_o = `ChipDisable;
        LLbit_we_o = `WriteDisable;
        LLbit_value_o = 1'b0;
        cp0_reg_we_o = cp0_reg_we_i;
        cp0_reg_write_addr_o = cp0_reg_write_addr_i;
        cp0_reg_data_o = cp0_reg_data_i;
        case (aluop_i)
          `EXE_LB_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteDisable;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    wdata_o= {{24{mem_data_i[7]}}, mem_data_i[7:0]};
                    mem_sel_o = 4'b0001;
                  end
                2'b01:
                  begin
                    wdata_o= {{24{mem_data_i[15]}}, mem_data_i[15:8]};
                    mem_sel_o = 4'b0010;
                  end
                2'b10:
                  begin
                    wdata_o= {{24{mem_data_i[23]}}, mem_data_i[23:16]};
                    mem_sel_o = 4'b0100;
                  end
                2'b11:
                  begin
                    wdata_o= {{24{mem_data_i[31]}}, mem_data_i[31:24]};
                    mem_sel_o = 4'b1000;
                  end
                default:
                  begin
                    wdata_o = `ZeroWord;
                  end
              endcase
            end
          `EXE_LBU_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteDisable;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    wdata_o= {{24{1'b0}}, mem_data_i[7:0]};
                    mem_sel_o = 4'b0001;
                  end
                2'b01:
                  begin
                    wdata_o= {{24{1'b0}}, mem_data_i[15:8]};
                    mem_sel_o = 4'b0010;
                  end
                2'b10:
                  begin
                    wdata_o= {{24{1'b0}}, mem_data_i[23:16]};
                    mem_sel_o = 4'b0100;
                  end
                2'b11:
                  begin
                    wdata_o= {{24{1'b0}}, mem_data_i[31:24]};
                    mem_sel_o = 4'b1000;
                  end
                default:
                  begin
                    wdata_o = `ZeroWord;
                  end
              endcase
            end
          `EXE_LH_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteDisable;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    // wdata_o= {{16{mem_data_i[23]}},mem_data_i[23:16], mem_data_i[31:24]};
                    wdata_o= {{16{mem_data_i[15]}},mem_data_i[15:0]};
                    mem_sel_o = 4'b0011;
                  end
                2'b10:
                  begin
                    // wdata_o= {{16{mem_data_i[7]}},mem_data_i[7:0], mem_data_i[15:8]};
                    wdata_o= {{16{mem_data_i[31]}},mem_data_i[31:16]};
                    mem_sel_o = 4'b1100;
                  end
                default:
                  begin
                    wdata_o = `ZeroWord;
                  end
              endcase
            end
          `EXE_LHU_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteDisable;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    // wdata_o= {{16{1'b0}},mem_data_i[23:16], mem_data_i[31:24]};
                    wdata_o= {{16{1'b0}},mem_data_i[15:0]};
                    mem_sel_o = 4'b0011;
                  end
                2'b10:
                  begin
                    // wdata_o= {{16{1'b0}}, mem_data_i[7:0], mem_data_i[15:8]};
                    wdata_o= {{16{1'b0}},mem_data_i[31:16]};
                    mem_sel_o = 4'b1100;
                  end
                default:
                  begin
                    wdata_o = `ZeroWord;
                  end
              endcase
            end
          `EXE_LW_OP:
            begin
              mem_addr_o = mem_addr_i;
              // wdata_o    = {mem_data_i[7:0], mem_data_i[15:8], mem_data_i[23:16], mem_data_i[31:24]};
              wdata_o = mem_data_i;
              mem_sel_o = 4'b1111;
              mem_ce_o = `ChipEnable;
            end
          `EXE_LWL_OP:
            // TODO
            begin
              mem_addr_o = {mem_addr_i[31:2], 2'b00};
              mem_we     = `WriteDisable;
              mem_sel_o = 4'b1111;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    wdata_o = mem_data_i[31:0];
                  end
                2'b01:
                  begin
                    wdata_o = {mem_data_i[23:0], reg2_i[7:0]};
                  end
                2'b10:
                  begin
                    wdata_o = {mem_data_i[15:0], reg2_i[15:0]};
                  end
                2'b11:
                  begin
                    wdata_o = {mem_data_i[7:0], reg2_i[23:0]};
                  end
                default:
                  begin
                    wdata_o = `ZeroWord;
                  end
              endcase
            end
          `EXE_LWR_OP:
            begin
              mem_addr_o = {mem_addr_i[31:2], 2'b00};
              mem_we     = `WriteDisable;
              mem_sel_o = 4'b1111;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    wdata_o = {reg2_i[31:8], mem_data_i[31:24]};
                  end
                2'b01:
                  begin
                    wdata_o = {reg2_i[31:16], mem_data_i[31:16] };
                  end
                2'b10:
                  begin
                    wdata_o = {reg2_i[31:24], mem_data_i[31:8] };
                  end
                2'b11:
                  begin
                    wdata_o = mem_data_i;
                  end
                default:
                  begin
                    wdata_o = `ZeroWord;
                  end
              endcase
            end
          `EXE_SB_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteEnable;
              mem_data_o = {reg2_i[7:0], reg2_i[7:0], reg2_i[7:0],reg2_i[7:0]};
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    mem_sel_o = 4'b0001;
                  end
                2'b01:
                  begin
                    mem_sel_o = 4'b0010;
                  end
                2'b10:
                  begin
                    mem_sel_o = 4'b0100;
                  end
                2'b11:
                  begin
                    mem_sel_o = 4'b1000;
                  end
                default:
                  begin
                    mem_sel_o = 4'b0000;
                  end
              endcase
            end
          `EXE_SH_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteEnable;
              // mem_data_o = {reg2_i[7:0],reg2_i[15:8], reg2_i[7:0], reg2_i[15:8]};
              mem_data_o = {reg2_i[15:8],reg2_i[7:0],reg2_i[15:8], reg2_i[7:0]};
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    mem_sel_o = 4'b0011;
                  end
                2'b10:
                  begin
                    mem_sel_o = 4'b1100;
                  end
                default:
                  begin
                    mem_sel_o = 4'b0000;
                  end
              endcase
            end
          `EXE_SW_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteEnable;
              // mem_data_o = {reg2_i[7:0], reg2_i[15:8], reg2_i[23:16],reg2_i[31:24]};
              mem_data_o = reg2_i;
              mem_sel_o = 4'b1111;
              mem_ce_o = `ChipEnable;
            end
          `EXE_SWL_OP:
            begin
              mem_addr_o = {mem_addr_i[31:2], 2'b00};
              mem_we = `WriteEnable;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    mem_sel_o = 4'b1111;
                    mem_data_o = reg2_i;
                  end
                2'b01:
                  begin
                    mem_sel_o = 4'b0111;
                    mem_data_o = {zero32[7:0], reg2_i[31:8]};
                  end
                2'b10:
                  begin
                    mem_sel_o = 4'b0011;
                    mem_data_o = {zero32[15:0], reg2_i[31:16]};
                  end
                2'b11:
                  begin
                    mem_sel_o = 4'b0001;
                    mem_data_o = {zero32[23:0], reg2_i[31:24]};
                  end
                default:
                  begin
                    mem_sel_o = 4'b0000;
                  end
              endcase
            end
          `EXE_SWR_OP:
            begin
              mem_addr_o = {mem_addr_i[31:2], 2'b00};
              mem_we = `WriteEnable;
              mem_ce_o = `ChipEnable;
              case (mem_addr_i[1:0])
                2'b00:
                  begin
                    mem_sel_o = 4'b1000;
                    mem_data_o = {reg2_i[7:0], zero32[23:0]};
                  end
                2'b01:
                  begin
                    mem_sel_o = 4'b1100;
                    mem_data_o = {reg2_i[15:0], zero32[15:0]};
                  end
                2'b10:
                  begin
                    mem_sel_o = 4'b1110;
                    mem_data_o = {reg2_i[23:0], zero32[7:0]};
                  end
                2'b11:
                  begin
                    mem_sel_o = 4'b1111;
                    mem_data_o = reg2_i[31:0];
                  end
                default:
                  begin
                    mem_sel_o = 4'b0000;
                  end
              endcase
            end
          `EXE_LL_OP:
            begin
              mem_addr_o = mem_addr_i;
              mem_we = `WriteDisable;
              wdata_o = mem_data_i;
              LLbit_we_o = `WriteEnable;
              LLbit_value_o = 1'b1;
              mem_sel_o = 4'b1111;
              mem_ce_o = `ChipEnable;
            end
          `EXE_SC_OP:
            begin
              if(LLbit == 1'b1)
                begin
                  mem_addr_o = mem_addr_i;
                  mem_we = `WriteEnable;
                  mem_data_o = reg2_i;
                  wdata_o = 32'b1;
                  LLbit_we_o = `WriteEnable;
                  LLbit_value_o = 1'b0;
                  mem_sel_o = 4'b1111;
                  mem_ce_o = `ChipEnable;
                end
              else
                begin
                  wdata_o = 32'b0;
                end
            end
          default:
            begin
            end
        endcase
      end
  end

endmodule // mem
