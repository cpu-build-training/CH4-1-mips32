// 利用得到的数据进行运算 就是 alu
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
            default: begin
                logicout <= `ZeroWord;
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
        default: begin
            wdata_o <= `ZeroWord;
        end
    endcase
end

endmodule // ex
