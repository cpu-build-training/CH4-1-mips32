// 利用得到的数据进行运算 就是 ALU
`include "defines.v"
module ex(
         input wire rst,
         // 译码阶段送到执行阶段的信息
         input
         wire[`AluOpBus]      aluop_i,
         wire[`AluSelBus]     alusel_i,
         wire[`RegBus]        reg1_i,
         wire[`RegBus]        reg2_i,
         wire[`RegAddrBus]    wd_i,
         input wire           wreg_i,

         // HILO
         wire[`RegBus]        hi_i,
         wire[`RegBus]        lo_i,

         // 回写阶段的指令是否要写 HI\LO，用于检测数据相关问题
         wire[`RegBus]        wb_hi_i,
         wire[`RegBus]        wb_lo_i,
         input wire           wb_whilo_i,
         // 访存阶段的指令是否要写 HI\LO，用于检测数据相关问题
         wire[`RegBus]        mem_hi_i,
         wire[`RegBus]        mem_lo_i,
         input wire           mem_whilo_i,

         // 第一个执行周期得到的乘法结果
         wire[`DoubleRegBus]  hilo_temp_i,
         // 当前处于执行阶段的第几个时钟周期
         wire[1:0]            cnt_i,

         // 来自除法模块的输入
         wire[`DoubleRegBus]  div_result_i,
         input wire           div_ready_i,

         // 当前处于执行阶段的指令是否位于延迟槽
         wire                 is_in_delayslot_i,
         // 当前处于执行阶段的转移指令要保存的返回地址
         wire[`RegBus]        link_address_i,
         // 新增输入接口 inst_i, 其值就是当前处于执行阶段的指令
         wire[`RegBus]        inst_i,

         // 访存阶段的指令是否要写 CP0 中的寄存器，用来检测数据相关
         input wire           mem_cp0_reg_we,
         wire[4:0]            mem_cp0_reg_write_addr,
         wire[2:0]            mem_cp0_reg_write_sel,
         wire[`RegBus]        mem_cp0_reg_data,

         // 回写阶段的指令是否要写 CP0 中的寄存器，检测数据相关
         input wire           wb_cp0_reg_we,
         wire[4:0]            wb_cp0_reg_write_addr,
         wire[2:0]            wb_cp0_reg_write_sel,
         wire[`RegBus]        wb_cp0_reg_data,

         // 与 CP0 直接相连，用于读取其中指定寄存器的值
         wire[`RegBus]        cp0_reg_data_i,

         // 异常
         wire[31:0]           excepttype_i,
         wire[`RegBus]        current_inst_address_i,
         output reg[4:0]      cp0_reg_read_addr_o,
         output reg[2:0]      cp0_reg_read_sel_o,

         // 向流水线下一级传递，用于写 CP0 中的指定寄存器
         output reg           cp0_reg_we_o,
         output reg[4:0]      cp0_reg_write_addr_o,
         output reg[2:0]      cp0_reg_write_sel_o,
         output reg[`RegBus]  cp0_reg_data_o,


         // 执行结果
         output
         reg[`RegAddrBus]     wd_o,
         output reg           wreg_o,
         reg[`RegBus]         wdata_o,

         // 处于执行阶段的指令对 HI\LO 寄存器的写操作请求
         reg[`RegBus]         hi_o,
         reg[`RegBus]         lo_o,
         output reg           whilo_o,
         // 保存逻辑运算的结果
         //    reg[`RegBus]        logicout

         // 第一个执行周期得到的乘法结果
        //  reg[`DoubleRegBus] hilo_temp_o,
         // 当前处于执行阶段的第几个时钟周期
        //  reg[1:0]             cnt_o,

         //    TO CTRL
         output reg           stallreq,

         // 到除法模块的输出
         reg[`RegBus]         div_opdata1_o,
         reg[`RegBus]         div_opdata2_o,
         output reg           div_start_o,
         reg                  signed_div_o,

         // 为加载、存储指令
         wire[`AluOpBus]      aluop_o,
         wire[`RegBus]        mem_addr_o,
         wire[`RegBus]        reg2_o,

         // 异常
         wire[31:0]           excepttype_o,
         output wire          is_in_delayslot_o,
         wire[`RegBus]        current_inst_address_o
       );

// ???
reg[`RegBus] logicout;
reg[`RegBus] shiftres;
reg[`RegBus] moveres;
reg[`RegBus] HI;
reg[`RegBus] LO;

// 是否由于除法运算导致流水线暂停
reg stallreq_for_div;

// NEW
wire    ov_sum;         // 保存溢出情况
wire    reg1_eq_reg2;   // if reg1 == reg2
wire    reg1_lt_reg2;   // if reg1 < reg2
reg[`RegBus]    arithmeticres;  // 保存算数运算结果
wire[`RegBus]   reg2_i_mux;     // 保存输入的第二个操作数 reg2_i 的补码
wire[`RegBus]   reg1_i_not;     // 输入的第一个操作数 reg1_i 取反后的值
wire[`RegBus]   result_sum;     // 保存加法结果
wire[`RegBus]   opdata1_mult;   // 乘法操作中的被乘数
wire[`RegBus]   opdata2_mult;   // 乘法操作中的乘数
wire[`DoubleRegBus] hilo_temp;  // 临时保存成发结果，宽度为 64 位
// reg[`DoubleRegBus] hilo_temp1;
// reg             stallreq_for_madd_msub;
reg[`DoubleRegBus] mulres;     // 保存乘法结果

// // 是否有自陷异常
// reg trapassert;
// // 是否有溢出异常
// reg ovassert;

// 该阶段产生的异常
reg[`RegBus] excepttype_cur_stage = 32'b0;

// 执行阶段输出的异常信息就是译码阶段的异常信息加上自陷异常、溢出异常的信息，
// 其中第 10bit 表示自陷，11bit 表示溢出
// assign excepttype_o = {excepttype_i[31:12], ovassert, trapassert, excepttype_i[10:8], 7'b0000_000};
assign excepttype_o = excepttype_cur_stage | excepttype_i;

// 当前指令是否在延迟槽中
assign is_in_delayslot_o = is_in_delayslot_i;

// 当前处于执行阶段指令的地址
assign current_inst_address_o = current_inst_address_i;

// aluop_o 会传递到访存阶段，届时将利用其确定加载、存储类型
assign aluop_o = aluop_i;

// mem_addr_o 会传递到访存阶段，是加载、存储指令对应的存储器地址，此处的 reg1_i
// 就是加载、存储指令中地址为 base 的通用寄存器的值，inst_i[15:0] 就是指令中的
// offset。通过 mem_addr_o 的计算，读者也可以明白为何要在译码阶段 ID 模块新增输出接口 inst_o

// 计算完成后，还需要检查地址是否按照要求对齐，否则要抛出异常。
assign mem_addr_o = reg1_i + {{16{inst_i[15]}},inst_i[15:0]};

// reg2_i 是存储指令要存储的数据，或者 lwl\lwr 指令要加载到的目的寄存器的原始值，
// 将该值通过 reg2_o 接口传递到访存阶段
assign reg2_o = reg2_i;

// 预计算

assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) ||
                     (aluop_i == `EXE_SUBU_OP) ||
                     (aluop_i == `EXE_SLT_OP) ||
                     (aluop_i == `EXE_TLT_OP) ||
                     (aluop_i == `EXE_TLTI_OP)||
                     (aluop_i == `EXE_TGE_OP)||
                     (aluop_i == `EXE_TGEI_OP)
                    ) ? (~reg2_i) + 1 : reg2_i;

assign result_sum = reg1_i + reg2_i_mux;

// 是否溢出
assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

assign reg1_lt_reg2 = ((aluop_i== `EXE_SLT_OP) ||
                       (aluop_i== `EXE_TLT_OP)||
                       (aluop_i== `EXE_TLTI_OP)||
                       (aluop_i== `EXE_TGE_OP)||
                       (aluop_i== `EXE_TGEI_OP)
                      )? ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31])||(reg1_i[31] && reg2_i[31] && result_sum[31])):(reg1_i < reg2_i);

assign reg1_eq_reg2 = reg1_i == reg2_i;
assign reg1_i_not = ~reg1_i;

// 给 arithmeticres 变量赋值
always @(*)
  begin
    if (rst == `RstEnable)
      begin
        arithmeticres = `ZeroWord;
      end
    else
      begin
        case (aluop_i)
          `EXE_SLT_OP, `EXE_SLTU_OP:
            arithmeticres = {{31{1'b0}},reg1_lt_reg2};
          `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP,`EXE_SUB_OP, `EXE_SUBU_OP:
            begin
              arithmeticres = result_sum;
            end
          `EXE_CLZ_OP:
            begin
              arithmeticres = reg1_i[31] ? 0 : reg1_i[30] ? 1:
                  reg1_i[29] ? 2 : reg1_i[28] ? 3:
                      reg1_i[27] ? 4 : reg1_i[26] ? 5:
                          reg1_i[25] ? 6 : reg1_i[24] ? 7:
                              reg1_i[23] ? 8 : reg1_i[22] ? 9:
                                  reg1_i[21] ? 10 : reg1_i[20] ? 11:
                                      reg1_i[19] ? 12 : reg1_i[18] ? 13:
                                          reg1_i[17] ? 14 : reg1_i[16] ? 15:
                                              reg1_i[15] ? 16 : reg1_i[14] ? 17:
                                                  reg1_i[13] ? 18 : reg1_i[12] ? 19:
                                                      reg1_i[11] ? 20 : reg1_i[10] ? 21:
                                                          reg1_i[9] ? 22 : reg1_i[8] ? 23:
                                                              reg1_i[7] ? 24 : reg1_i[6] ? 25:
                                                                  reg1_i[5] ? 26 : reg1_i[4] ? 27:
                                                                      reg1_i[3] ? 28 : reg1_i[2] ? 29:
                                                                          reg1_i[1] ? 30 : reg1_i[0] ? 31: 32;
            end
          `EXE_CLO_OP:
            begin
              arithmeticres = reg1_i_not[31] ? 0:
                reg1_i_not[30] ? 1:
                  reg1_i_not[29] ? 2:
                    reg1_i_not[28] ? 3:
                      reg1_i_not[27] ? 4:
                        reg1_i_not[26] ? 5:
                          reg1_i_not[25] ? 6:
                            reg1_i_not[24] ? 7:
                              reg1_i_not[23] ? 8:
                                reg1_i_not[22] ? 9:
                                  reg1_i_not[21] ? 10:
                                    reg1_i_not[20] ? 11:
                                      reg1_i_not[19] ? 12:
                                        reg1_i_not[18] ? 13:
                                          reg1_i_not[17] ? 14:
                                            reg1_i_not[16] ? 15:
                                              reg1_i_not[15] ? 16:
                                                reg1_i_not[14] ? 17:
                                                  reg1_i_not[13] ? 18:
                                                    reg1_i_not[12] ? 19:
                                                      reg1_i_not[11] ? 20:
                                                        reg1_i_not[10] ? 21:
                                                          reg1_i_not[9] ? 22:
                                                            reg1_i_not[8] ? 23:
                                                              reg1_i_not[7] ? 24:
                                                                reg1_i_not[6] ? 25:
                                                                  reg1_i_not[5] ? 26:
                                                                    reg1_i_not[4] ? 27:
                                                                      reg1_i_not[3] ? 28:
                                                                        reg1_i_not[2] ? 29:
                                                                          reg1_i_not[1] ? 30:
                                                                            reg1_i_not[0] ? 31: 32;
            end
          default:
            begin
              arithmeticres = `ZeroWord;
            end
        endcase
      end
  end

// 乘法运算
// 取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补码
assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ) && (reg1_i[31] == 1'b1)) ? (~reg1_i + 1) : reg1_i;

// 取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补码
assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ) && (reg2_i[31] == 1'b1)) ? (~reg2_i + 1) : reg2_i;

// 得到临时乘法结果，保存在变量 hilo_temp 中
assign hilo_temp = opdata1_mult * opdata2_mult;

// 对临时乘法结果进行修正，最终的乘法结果保存在变量 mulres 中，主要有两点：
//  A. 如果是有符号乘法指令 mult, mul，那么需要修正临时乘法结果，如下：
//      A1. 如果被乘数与乘数两者一正一负，那么需要对临时乘法结果 hilo_temp 求补码，作为最终的乘法结果，赋值给变量 mulres
//      A2. 如果同号，不变
//  B. 如果是无符号乘法指令 multu，那么直接赋值

always @(*)
  begin
    if(rst == `RstEnable)
      begin
        mulres = {`ZeroWord, `ZeroWord};
      end
    else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP))
      begin
        if(reg1_i[31] ^ reg2_i[31] == 1'b1)
          begin
            mulres = ~hilo_temp + 1;
          end
        else
          begin
            mulres = hilo_temp;
          end
      end
    else
      begin
        mulres = hilo_temp;
      end
  end

// MADD, MADDU, MSUB, MSUBU
// always @(*)
//   begin
//     if(rst == `RstEnable)
//       begin
//         hilo_temp_o = {`ZeroWord, `ZeroWord};
//         cnt_o = 2'b00;
//         stallreq_for_madd_msub = `NoStop;
//         hilo_temp1 = {`ZeroWord, `ZeroWord};
//       end
//     else
//       begin
//         cnt_o = 2'b00;
//         stallreq_for_madd_msub = `NoStop;
//         hilo_temp_o = {`ZeroWord, `ZeroWord};
//         hilo_temp1 = {`ZeroWord, `ZeroWord};
//         case (aluop_i)
//           `EXE_MADD_OP, `EXE_MADDU_OP:
//             begin
//               if(cnt_i == 2'b00)
//                 begin
//                   // 执行阶段第一个时钟周期
//                   hilo_temp_o = mulres;
//                   cnt_o = 2'b01;
//                   hilo_temp1 = {`ZeroWord, `ZeroWord};
//                   stallreq_for_madd_msub = `Stop;
//                 end
//               else if(cnt_i == 2'b01)
//                 begin
//                   // 执行阶段第二个时钟周期
//                   hilo_temp_o = {`ZeroWord, `ZeroWord};
//                   cnt_o = 2'b10;
//                   hilo_temp1 = hilo_temp_i + {HI, LO};
//                   stallreq_for_madd_msub = `NoStop;
//                 end
//             end
//           `EXE_MSUB_OP, `EXE_MSUBU_OP:
//             begin
//               if(cnt_i == 2'b00)
//                 begin
//                   // 执行阶段第一个时钟周期
//                   hilo_temp_o = ~mulres + 1;
//                   cnt_o = 2'b01;
//                   hilo_temp1 = {`ZeroWord, `ZeroWord};
//                   stallreq_for_madd_msub = `Stop;
//                 end
//               else if(cnt_i == 2'b01)
//                 begin
//                   // 执行阶段第二个时钟周期
//                   hilo_temp_o = {`ZeroWord, `ZeroWord};
//                   cnt_o = 2'b10;
//                   hilo_temp1 = hilo_temp_i + {HI, LO};
//                   stallreq_for_madd_msub = `NoStop;
//                 end
//             end
//           default:
//             begin
//               hilo_temp_o = {`ZeroWord, `ZeroWord};
//               cnt_o = 2'b00;
//               stallreq_for_madd_msub = `NoStop;
//             end
//         endcase
//       end
//   end

// 输出 DIV 模块的控制信息，获取 DIV 模块给出的结果
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        stallreq_for_div = `NoStop;
        div_opdata1_o = `ZeroWord;
        div_opdata2_o = `ZeroWord;
        div_start_o = `DivStop;
        signed_div_o = 1'b0;
      end
    else
      begin
        stallreq_for_div = `NoStop;
        div_opdata1_o = `ZeroWord;
        div_opdata2_o = `ZeroWord;
        div_start_o = `DivStop;
        signed_div_o = 1'b0;
        case (aluop_i)
          `EXE_DIV_OP:
            begin
              if(div_ready_i == `DivResultNotReady)
                begin
                  div_opdata1_o = reg1_i; //被除数
                  div_opdata2_o = reg2_i; // 除数
                  div_start_o = `DivStart;
                  signed_div_o = 1'b1;
                  stallreq_for_div = `Stop;
                end
              else if (div_ready_i == `DivResultReady)
                begin
                  div_opdata1_o = reg1_i;
                  div_opdata2_o = reg2_i;
                  div_start_o = `DivStop;
                  signed_div_o = 1'b1;
                  stallreq_for_div = `NoStop;
                end
              else
                begin
                  stallreq_for_div = `NoStop;
                  div_opdata1_o = `ZeroWord;
                  div_opdata2_o = `ZeroWord;
                  div_start_o = `DivStop;
                  signed_div_o = 1'b0;
                end
            end
          `EXE_DIVU_OP:
            begin
              if(div_ready_i == `DivResultNotReady)
                begin
                  div_opdata1_o = reg1_i; //被除数
                  div_opdata2_o = reg2_i; // 除数
                  div_start_o = `DivStart;
                  signed_div_o = 1'b0; // 无符号
                  stallreq_for_div = `Stop;
                end
              else if(div_ready_i == `DivResultReady)
                begin
                  div_opdata1_o = reg1_i;
                  div_opdata2_o = reg2_i;
                  div_start_o = `DivStop;
                  signed_div_o = 1'b0;
                  stallreq_for_div = `NoStop;
                end
              else
                begin
                  stallreq_for_div = `NoStop;
                  div_opdata1_o = `ZeroWord;
                  div_opdata2_o = `ZeroWord;
                  div_start_o = `DivStop;
                  signed_div_o = 1'b0;
                end
            end
          default:
            begin
            end
        endcase
      end
  end


// 暂停流水线
// 目前只有四条会导致暂停，所以就 stallreq 直接等于 stallreq_for_madd_msub 的值
always @(*)
  begin
    stallreq = stallreq_for_div;
  end

// 得到最新的 HI/LO
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        {HI, LO} = {`ZeroWord, `ZeroWord};
      end
    else if (mem_whilo_i == `WriteEnable)
      begin
        {HI, LO} = {mem_hi_i, mem_lo_i};
      end
    else if (wb_whilo_i == `WriteEnable)
      begin
        {HI,LO} = {wb_hi_i, wb_lo_i};
      end
    else
      begin
        {HI,LO} = {hi_i, lo_i};
      end
  end


//  MOV 类指令
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        moveres = `ZeroWord;
        cp0_reg_read_addr_o = 5'b00000;
        cp0_reg_read_sel_o  = 0;
      end
    else
      begin
        moveres = `ZeroWord;
        // 要从 CP0 中读取的寄存器的地址
        cp0_reg_read_addr_o = 5'b00000;
        cp0_reg_read_sel_o  = 0;
        case (aluop_i)
          `EXE_MFHI_OP:
            begin
              moveres = HI;
            end
          `EXE_MFLO_OP:
            begin
              moveres = LO;
            end
          `EXE_MOVZ_OP,`EXE_MOVN_OP:
            begin
              moveres = reg1_i;
            end
          `EXE_MFC0_OP:
            begin
              // 要从 CP0 中读取的寄存器的地址
              cp0_reg_read_addr_o = inst_i[15:11];
              cp0_reg_read_sel_o  = inst_i[2:0];

              // 读取到的 CP0 中指定寄存器的值
              moveres = cp0_reg_data_i;

              // 处理数据相关
              if (mem_cp0_reg_we == `WriteEnable &&
                  mem_cp0_reg_write_addr == inst_i[15:11] &&
                  mem_cp0_reg_write_sel == inst_i[2:0])
                begin
                  // 访存阶段数据相关
                  moveres = mem_cp0_reg_data;
                end
              else if (wb_cp0_reg_we == `WriteEnable && 
                       wb_cp0_reg_write_addr == inst_i[15:11] &&
                       wb_cp0_reg_write_sel == inst_i[2:0])
                begin
                  // 回写阶段数据相关
                  moveres = wb_cp0_reg_data;
                end
            end
          default:
            begin

            end
        endcase
      end
  end

// 根据 aluop_i 指示的运算子类型进行运算
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        logicout = `ZeroWord;
      end
    else
      begin
        case (aluop_i)
          `EXE_OR_OP:
            begin
              logicout = reg1_i | reg2_i;
            end
          `EXE_AND_OP:
            begin
              logicout = reg1_i & reg2_i;
            end
          `EXE_NOR_OP:
            begin
              logicout = ~(reg1_i | reg2_i);
            end
          `EXE_XOR_OP:
            begin
              logicout = reg1_i ^ reg2_i;
            end
          default:
            begin
              logicout = `ZeroWord;
            end
        endcase
      end
  end

always @ (*)
  begin
    if(rst == `RstEnable)
      begin
        shiftres = `ZeroWord;
      end
    else
      begin
        case (aluop_i)
          `EXE_SLL_OP:
            begin
              shiftres = reg2_i << reg1_i[4:0];
            end
          `EXE_SRL_OP:
            begin
              shiftres = reg2_i >> reg1_i[4:0];
            end
          `EXE_SRA_OP:
            begin
              shiftres = ({32{reg2_i[31]}}<< (6'd32-{1'b0, reg1_i[4:0]})) | reg2_i>> reg1_i[4:0];
            end
          default:
            begin
              shiftres= `ZeroWord;
            end
        endcase
      end
  end


// 根据 alusel_i 指示的运算类型选择运算结果

always @(*)
  begin
    wd_o = wd_i;
    // 如果溢出，就不输出的运算`
    case (aluop_i)
      `EXE_ADD_OP, `EXE_ADDI_OP, `EXE_SUB_OP:
        begin
          if(ov_sum == 1'b1)
            begin
              wreg_o = `WriteDisable;
            end
          else
            begin
              wreg_o = wreg_i;
            end
        end
      default:
        begin
          wreg_o = wreg_i;
        end
    endcase
    // 依据指令类型以及 ov_sum 的值，判断是否发生溢出异常，从而给出变量 ovassert 的值
    if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) ||
        (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1))
      begin
        wreg_o = `WriteDisable;
      end
    else
      begin
        wreg_o = wreg_i;
      end
    case (alusel_i)
      `EXE_RES_LOGIC:
        begin
          // wdata 中存放运算结果
          wdata_o = logicout;
        end
      `EXE_RES_SHIFT:
        begin
          wdata_o = shiftres;
        end
      `EXE_RES_MOVE:
        begin
          wdata_o = moveres;
        end
      `EXE_RES_ARITHMETIC:
        begin
          wdata_o = arithmeticres;
        end
      `EXE_RES_MUL:
        begin
          wdata_o = mulres[31:0];
        end
      `EXE_RES_JUMP_BRANCH:
        begin
          wdata_o = link_address_i;
        end
      default:
        begin
          wdata_o = `ZeroWord;
        end
    endcase
  end

// update hi,lo
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        whilo_o  = `WriteDisable;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
      end
    else if ((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP))
      begin
        whilo_o = `WriteEnable;
        hi_o = div_result_i[63:32];
        lo_o = div_result_i[31:0];
      end
    else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP))
      begin
        whilo_o = `WriteEnable;
        hi_o = mulres[63:32];
        lo_o = mulres[31:0];
      end
    // else if((aluop_i == `EXE_MSUB_OP) || (aluop_i == `EXE_MSUBU_OP) || (aluop_i == `EXE_MADD_OP) ||(aluop_i == `EXE_MADDU_OP) )
    //   begin
    //     whilo_o = `WriteEnable;
    //     hi_o = hilo_temp1[63:32];
    //     lo_o = hilo_temp1[31:0];
    //   end
    else if (aluop_i == `EXE_MTHI_OP)
      begin
        whilo_o  = `WriteEnable;
        hi_o = reg1_i;
        lo_o = LO;
      end
    else if (aluop_i == `EXE_MTLO_OP)
      begin
        whilo_o = `WriteEnable;
        hi_o = HI;
        lo_o = reg1_i;
      end
    else
      begin
        whilo_o  = `WriteDisable;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
      end
  end

always @(*)
  begin
    if(rst == `RstEnable)
      begin
        cp0_reg_write_addr_o = 5'b00000;
        cp0_reg_write_sel_o  = 0;
        cp0_reg_we_o = `WriteDisable;
        cp0_reg_data_o = `ZeroWord;
      end
    else if (aluop_i == `EXE_MTC0_OP)
      begin
        // 是 mtc0 指令
        cp0_reg_write_addr_o = inst_i[15:11];
        cp0_reg_write_sel_o  = inst_i[2:0];
        cp0_reg_we_o = `WriteEnable;
        cp0_reg_data_o = reg1_i;
      end
    else
      begin
        cp0_reg_write_addr_o = 5'b00000;
        cp0_reg_write_sel_o  = 0;
        cp0_reg_we_o = `WriteDisable;
        cp0_reg_data_o = `ZeroWord;
      end
  end


// 依据上面得到的比较结果，判断是否满足自陷指令的条件，从而给出变量 trapassert 的值
always @(*)
  begin
    excepttype_cur_stage = `ZeroWord;
    // excepttype_cur_stage[`TRAP_IDX] = `TrapNotAssert;
    case (aluop_i)
      // teg, teqi
      `EXE_TEQ_OP, `EXE_TEQI_OP:
        begin
          if( reg1_i == reg2_i )
            begin
              excepttype_cur_stage[`TRAP_IDX] = `TrapAssert;
            end
        end
      // tge, tgei, tgeiu, tgeu 指令
      `EXE_TGE_OP, `EXE_TGEI_OP, `EXE_TGEIU_OP, `EXE_TGEU_OP:
        begin
          if(~reg1_lt_reg2)
            begin
              excepttype_cur_stage[`TRAP_IDX] = `TrapAssert;
            end
        end
      // tlt, tlti, tltiu, tltu
      `EXE_TLT_OP, `EXE_TLTI_OP, `EXE_TLTIU_OP, `EXE_TLTU_OP:
        begin
          if( reg1_lt_reg2 )
            begin
              excepttype_cur_stage[`TRAP_IDX] = `TrapAssert;
            end
        end
      // tne, tnei
      `EXE_TNE_OP, `EXE_TNEI_OP:
        begin
          if (reg1_i != reg2_i)
            begin
              excepttype_cur_stage[`TRAP_IDX] = `TrapAssert;
            end
        end
      default:
        begin
          excepttype_cur_stage[`TRAP_IDX] = `TrapNotAssert;
        end
    endcase
    // 根据指令类型以及 mem_addr_o 的值，判断是否发生地址未对齐异常
    if(rst == `RstEnable)
      begin
        excepttype_cur_stage = `ZeroWord;
      end
    else if((aluop_i == `EXE_LH_OP || aluop_i == `EXE_LHU_OP) && mem_addr_o[0] != 1'b0)
      begin
        excepttype_cur_stage[`ADEL_IDX] = 1'b1;
      end
    else if(aluop_i == `EXE_LW_OP && mem_addr_o[1:0] != 2'b0)
      begin
        excepttype_cur_stage[`ADEL_IDX] = 1'b1;
      end
    else if(aluop_i == `EXE_SH_OP && mem_addr_o[0] != 1'b0)
      begin
        excepttype_cur_stage[`ADES_IDX] = 1'b1;
      end
    else if(aluop_i == `EXE_SW_OP && mem_addr_o[1:0] != 2'b0)
      begin
        excepttype_cur_stage[`ADES_IDX] = 1'b1;
      end
    else
      begin
        excepttype_cur_stage[`ADES_IDX] = 1'b0;
        excepttype_cur_stage[`ADEL_IDX] = 1'b0;
      end

    if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) ||
        (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1))
      begin
        excepttype_cur_stage[`OVERFLOW_IDX] = 1'b1;
      end
    else
      begin
        excepttype_cur_stage[`OVERFLOW_IDX] = 1'b0;
      end
  end


always @(*)
  begin

  end
endmodule // ex
