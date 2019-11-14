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


           // 执行结果
           output
           reg[`RegAddrBus]    wd_o,
           reg                 wreg_o,
           reg[`RegBus]        wdata_o,

           // 保存逻辑运算的结果
           reg[`RegBus]        logicout
       );

// ???
reg[`RegBus] shiftres;
reg[`RegBus] moveres;
reg[`RegBus] HI;
reg[`RegBus] LO;

// NEW
wire    ov_num;         // 保存溢出情况
wire    reg1_eq_reg2;   // if reg1 == reg2
wire    reg1_lt_reg2;   // if reg1 < reg2
reg[`RegBus]    arithmeticres;  // 保存算数运算结果
wire[`RegBus]   reg2_i_mux;     // 保存输入的第二个操作数 reg2_i 的补码
wire[`RegBus]   reg1_i_not;     // 输入的第一个操作数 reg1_i 取反后的值
wire[`RegBus]   result_sum;     // 保存加法结果
wire[`RegBus]   opdata1_mult;   // 乘法操作中的被乘数
wire[`RegBus]   opdata2_mult;   // 乘法操作中的乘数
wire[`DoubleRegBus] hilo_temp;  // 临时保存成发结果，宽度为 64 位
wire[`DoubleRegBus] mulres;     // 保存乘法结果


// 预计算

assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SUBU_OP) || (aluop_i == `EXE_SLT_OP)) ? (~reg2_i) + 1 : reg2_i;

assign result_sum = reg1_i + reg2_i_mux;

// 是否溢出
assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

assign reg1_lt_reg2 = ((aluop_i== `EXE_SLT_OP))? ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31])||(reg1_i[31] && reg2_i[31] && result_sum[31])):(reg1_i < reg2_i);

assign reg1_i_not = ~reg1_i;

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
    wreg_o <= wreg_i;
    case (alusel_i)
        `EXE_RES_LOGIC:     begin
            // wdata 中存放运算结果
            wdata_o <= logicout;
        end
        `EXE_RES_SHIFT: begin
            wdata_o <= shiftres;
        end
        default: begin
            wdata_o <= `ZeroWord;
        end
    endcase
end

endmodule // ex
