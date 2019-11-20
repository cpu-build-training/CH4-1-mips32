// 利用得到的数据进行运算 就是 ALU
`include "defines.v"
module ex(
           input wire rst,
           // 译码阶段送到执行阶段的信息
           input
           wire[`AluOpBus]     aluop_i,
           wire[`AluSelBus]    alusel_i,
           wire[`RegBus]       reg1_i,
           wire[`RegBus]       reg2_i,
           wire[`RegAddrBus]   wd_i,
           wire                wreg_i,

           // HILO
           input
           wire[`RegBus] hi_i,
           wire[`RegBus] lo_i,

           // 回写阶段的指令是否要写 HI\LO，用于检测数据相关问题
           wire[`RegBus] wb_hi_i,
           wire[`RegBus] wb_lo_i,
           wire          wb_whilo_i,
           // 访存阶段的指令是否要写 HI\LO，用于检测数据相关问题
           wire[`RegBus] mem_hi_i,
           wire[`RegBus] mem_lo_i,
           wire          mem_whilo_i,

           // 执行结果
           output
           reg[`RegAddrBus]    wd_o,
           reg                 wreg_o,
           reg[`RegBus]        wdata_o,

           // 处于执行阶段的指令对 HI\LO 寄存器的写操作请求
           reg[`RegBus]        hi_o,
           reg[`RegBus]        lo_o,
           reg                 whilo_o
           // 保存逻辑运算的结果
           //    reg[`RegBus]        logicout
       );

// ???
reg[`RegBus] logicout;
reg[`RegBus] shiftres;
reg[`RegBus] moveres;
reg[`RegBus] HI;
reg[`RegBus] LO;

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
reg[`DoubleRegBus] mulres;     // 保存乘法结果


// 预计算

assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SUBU_OP) || (aluop_i == `EXE_SLT_OP)) ? (~reg2_i) + 1 : reg2_i;

assign result_sum = reg1_i + reg2_i_mux;

// 是否溢出
assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

assign reg1_lt_reg2 = ((aluop_i== `EXE_SLT_OP))? ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31])||(reg1_i[31] && reg2_i[31] && result_sum[31])):(reg1_i < reg2_i);

assign reg1_eq_reg2 = reg1_i == reg2_i;
assign reg1_i_not = ~reg1_i;

// 给 arithmeticres 变量赋值
always @(*) begin
    if (rst == `RstEnable) begin
        arithmeticres <= `ZeroWord;
    end
    else begin
        case (aluop_i)
            `EXE_SLT_OP, `EXE_SLTU_OP:
                arithmeticres <= reg1_lt_reg2;
            `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP,`EXE_SUB_OP, `EXE_SUBU_OP: begin
                arithmeticres <= result_sum;
            end
            `EXE_CLZ_OP: begin
                arithmeticres <= reg1_i[31] ? 0 : reg1_i[30] ? 1:
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
            `EXE_CLO_OP:    begin
                arithmeticres <= reg1_i_not[31] ? 0:
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
            default: begin
                arithmeticres <= `ZeroWord;
            end
        endcase
    end
end

// 乘法运算
// 取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补码
assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) && (reg1_i[31] == 1'b1)) ? (~reg1_i + 1) : reg1_i;

// 取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补码
assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP)) && (reg2_i[31] == 1'b1)) ? (~reg2_i + 1) : reg2_i;

// 得到临时乘法结果，保存在变量 hilo_temp 中
assign hilo_temp = opdata1_mult * opdata2_mult;

// 对临时乘法结果进行修正，最终的乘法结果保存在变量 mulres 中，主要有两点：
//  A. 如果是有符号乘法指令 mult, mul，那么需要修正临时乘法结果，如下：
//      A1. 如果被乘数与乘数两者一正一负，那么需要对临时乘法结果 hilo_temp 求补码，作为最终的乘法结果，赋值给变量 mulres
//      A2. 如果同号，不变
//  B. 如果是无符号乘法指令 multu，那么直接赋值

always @(*) begin
    if(rst == `RstEnable) begin
        mulres <= {`ZeroWord, `ZeroWord};
    end
    else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP)) begin
        if(reg1_i[31] ^ reg2_i[31] == 1'b1) begin
            mulres <= ~hilo_temp + 1;
        end
        else begin
            mulres <= hilo_temp;
        end
    end else begin
        mulres <= hilo_temp;
    end
end

// 得到最新的 HI/LO
always @(*) begin
    if(rst == `RstEnable) begin
        {HI, LO} <= {`ZeroWord, `ZeroWord};
    end
    else if (mem_whilo_i == `WriteEnable) begin
        {HI, LO} <= {mem_hi_i, mem_lo_i};
    end
    else if (wb_whilo_i == `WriteEnable) begin
        {HI,LO} <= {wb_hi_i, wb_lo_i};
    end
    else begin
        {HI,LO} <= {hi_i, lo_i};
    end
end


//  MOV 类指令

always @(*) begin
    if(rst == `RstEnable) begin
        moveres <= `ZeroWord;
    end
    else begin
        moveres <= `ZeroWord;
        case (aluop_i)
            `EXE_MFHI_OP: begin
                moveres <= HI;
            end
            `EXE_MFLO_OP: begin
                moveres <= LO;
            end
            `EXE_MOVZ_OP,`EXE_MOVN_OP: begin
                moveres <= reg1_i;
            end
            default: begin

            end
        endcase
    end
end

// 根据 aluop_i 指示的运算子类型进行运算，此处只有 ori
always @(*) begin
    if(rst == `RstEnable) begin
        logicout <= `ZeroWord;
    end
    else begin
        case (aluop_i)
            `EXE_OR_OP: begin
                logicout <= reg1_i | reg2_i;
            end
            `EXE_AND_OP: begin
                logicout <= reg1_i & reg2_i;
            end
            `EXE_NOR_OP: begin
                logicout <= ~(reg1_i | reg2_i);
            end
            `EXE_XOR_OP: begin
                logicout <= reg1_i ^ reg2_i;
            end
            default: begin
                logicout <= `ZeroWord;
            end
        endcase
    end
end

always @ (*) begin
    if(rst == `RstEnable) begin
        shiftres <= `ZeroWord;
    end
    else begin
        case (aluop_i)
            `EXE_SLL_OP: begin
                shiftres <= reg2_i << reg1_i[4:0];
            end
            `EXE_SRL_OP: begin
                shiftres <= reg2_i >> reg1_i[4:0];
            end
            `EXE_SRA_OP: begin
                shiftres <= ({32{reg2_i[31]}}<< (6'd32-{1'b0, reg1_i[4:0]})) | reg2_i>> reg1_i[4:0];
            end
            default: begin
                shiftres<= `ZeroWord;
            end
        endcase
    end
end


// 根据 alusel_i 指示的运算类型选择运算结果

always @(*) begin
    wd_o <= wd_i;
    // 如果溢出，就不输出的运算`
    case (aluop_i)
        `EXE_ADD_OP, `EXE_ADDI_OP, `EXE_SUB_OP: begin
            if(ov_sum == 1'b1) begin
                wreg_o <= `WriteDisable;
            end
            else begin
                wreg_o <= wreg_i;
            end
        end
        default: begin
            wreg_o <= wreg_i;
        end
    endcase

    case (alusel_i)
        `EXE_RES_LOGIC:     begin
            // wdata 中存放运算结果
            wdata_o <= logicout;
        end
        `EXE_RES_SHIFT: begin
            wdata_o <= shiftres;
        end
        `EXE_RES_MOVE: begin
            wdata_o <= moveres;
        end
        `EXE_RES_ARITHMETIC: begin
            wdata_o <= arithmeticres;
        end
        `EXE_RES_MUL: begin
            wdata_o <= mulres[31:0];
        end
        default: begin
            wdata_o <= `ZeroWord;
        end
    endcase
end

// update hi,lo
always @(*) begin
    if(rst == `RstEnable) begin
        whilo_o  <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
    end
    else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
        whilo_o <= `WriteEnable;
        hi_o <= mulres[63:32];
        lo_o <= mulres[31:0];
    end
    else if (aluop_i == `EXE_MTHI_OP) begin
        whilo_o  <= `WriteEnable;
        hi_o <= reg1_i;
        lo_o <= LO;
    end
    else if (aluop_i == `EXE_MTLO_OP) begin
        whilo_o <= `WriteEnable;
        hi_o <= HI;
        lo_o <= reg1_i;
    end
    else begin
        whilo_o  <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
    end
end


endmodule // ex
