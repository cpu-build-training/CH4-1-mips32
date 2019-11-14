// ID 模块的作用是对指令进行译码，
// 得到最终运算的类型、子类型、源操作数1、
// 源操作数2、要写入的目的寄存器地址等信息
`include "defines.v"
module id(
           input wire  rst,
           wire [`InstAddrBus] pc_i,
           wire[`InstBus]  inst_i,

           // 读取的 Regfile 的值
           input wire[`RegBus] reg1_data_i,
           wire[`RegBus] reg2_data_i,

           // 输出到 Regfile 的信息
           output
           reg reg1_read_o,
           reg reg2_read_o,
           reg[`RegAddrBus] reg1_addr_o,
           reg[`RegAddrBus] reg2_addr_o,

           // 送到执行阶段的信息
           output reg[`AluOpBus]   aluop_o,
           reg[`AluSelBus]  alusel_o,
           reg[`RegBus] reg1_o,
           reg[`RegBus] reg2_o,
           reg[`RegAddrBus] wd_o,
           reg          wreg_o,

           // 数据前推所需要加入的新的输入
           // 来自 ex, mem 的输出
           // 处于执行阶段的指令的运算结果
           input
           wire             ex_wreg_i,
           wire[`RegBus]    ex_wdata_i,
           wire[`RegAddrBus]    ex_wd_i,

           // 处于访存阶段的指令的运算结果
           input
           wire                 mem_wreg_i,
           wire[`RegBus]        mem_wdata_i,
           wire[`RegAddrBus]    mem_wd_i
       );

// reg1_data_i  从 Regfile 输入的第一个读寄存器端口的输入
// reg2_data_i
// reg1_read_o  Regfile 模块的第一个读寄存器端口的读使能信号
// reg2_read_o
// reg1_addr_o  Regfile 模块的第一个读寄存器端口的读地址信号
// reg2_addr_o
// aluop_o      译码阶段的指令要执行的运算的子类型
// alusel_o     译码阶段的指令要进行的运算的类型
// reg1_o       译码阶段的指令要进行的运算的源操作数 1
// reg2_o
// wd_o         译码阶段的指令要写入的目的寄存器地址
// wreg_o       译码阶段的指令是否有要写入的目的寄存器


// 取得指令的指令码，功能码
// 对于 ori 指令只需要通过判断第 26-31bit 的值，即可判断是否是 ori 指令

wire[5:0] op = inst_i[31:26];
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0];
wire[4:0] op4 = inst_i[20:16];


// 保存指令执行需要的立即数
reg[`RegBus] imm;

// 指示指令是否有效
reg instvalid;

// 对指令进行译码

always @(*) begin
    if (rst == `RstEnable) begin
        aluop_o <= `EXE_NOP_OP;
        alusel_o <= `EXE_RES_NOP;
        wd_o    <= `NOPRegAddr;
        wreg_o  <= `WriteDisable;
        instvalid <= `InstValid;
        reg1_read_o <= `ReadDisable;
        reg2_read_o <= `ReadDisable;
        reg1_addr_o <= `NOPRegAddr;
        reg2_addr_o <= `NOPRegAddr;
        imm         <= `ZeroWord;
    end
    else begin
        // 没有进入 case 的代码相当于设定默认值
        aluop_o <= `EXE_NOP_OP; // ???
        alusel_o <= `EXE_RES_NOP;
        wd_o <= inst_i[15:11];
        wreg_o <= `WriteDisable;
        instvalid <= `InstInvalid;
        reg1_read_o <= `ReadDisable;
        reg2_read_o <= `ReadDisable;
        reg1_addr_o <= inst_i[25:21];
        reg2_addr_o <= inst_i[20:16];
        imm         <= `ZeroWord;

        case (op)
            `EXE_ORI: begin // if op is ori
                // ori 指令需要将结果写入目的寄存器，所以 wreg_o 为 WriteEnable
                wreg_o <= `WriteEnable;
                // 运算子类型是逻辑或
                aluop_o <= `EXE_OR_OP;
                // 运算类型是逻辑运算
                alusel_o <= `EXE_RES_LOGIC;
                // 需要通过 Regfile 的读端口 1 读取寄存器
                reg1_read_o <= `ReadEnable;
                // 不需要通过 Regfile 的读端口 2 读取寄存器
                reg2_read_o <= `ReadDisable;
                // 指令执行需要的立即数
                imm <= {16'h0, inst_i[15:0]};
                // 指令执行要写的目的寄存器的地址
                wd_o <= inst_i[20:16];
                // ori 指令是有效指令
                instvalid <= `InstValid;
            end
            `EXE_ANDI: begin
            // CHECK
                wreg_o <= `WriteEnable;
                aluop_o <= `EXE_AND_OP;
                alusel_o <= `EXE_RES_LOGIC;
                reg1_read_o <= `ReadEnable;
                imm <= {16'h0, inst_i[15:0]};
                wd_o <= inst_i[20:16];
                instvalid <= `InstValid;
            end
            `EXE_XORI: begin
            // CHECK
                wreg_o <= `WriteEnable;
                aluop_o <= `EXE_XOR_OP;
                alusel_o <= `EXE_RES_LOGIC;
                reg1_read_o <= `ReadEnable;
                imm <= {16'h0, inst_i[15:0]};
                wd_o <= inst_i[20:16];
                instvalid <= `InstValid;
            end
            `EXE_LUI: begin
                // CHECK
                wreg_o <= `WriteEnable;
                aluop_o <= `EXE_OR_OP;
                alusel_o <= `EXE_RES_LOGIC;
                reg1_read_o <= `ReadEnable;
                imm <= {inst_i[15:0], 16'h0};
                wd_o <= inst_i[20:16];
                instvalid <= `InstValid;
            end
            `EXE_PREF: begin
                // CHECK
                wreg_o <= `WriteDisable;
                aluop_o <= `EXE_NOP_OP;
                alusel_o <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                instvalid <= `InstValid;
            end
            `EXE_SPECIAL: begin
                case (op3)
                    `EXE_OR: begin
                        // CHECKED
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_OR_OP;
                        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_XOR: begin
                        // CHECKED
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_XOR_OP;
                        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_AND: begin
                        // CHECKED
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_AND_OP;
                        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_NOR: begin
                        // CHECKED
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_NOR_OP;
                        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_SLLV: begin
                    // CHECK
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_SLL_OP;
                        alusel_o <= `EXE_RES_SHIFT;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_SRLV: begin
                    // CHECK
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_SRL_OP;
                        alusel_o <= `EXE_RES_SHIFT;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_SRAV: begin
                    // CHECK
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_SRA_OP;
                        alusel_o <= `EXE_RES_SHIFT;
                        reg1_read_o <= `ReadEnable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_SYNC: begin
                    // CHECK
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_NOP_OP;
                        alusel_o <= `EXE_RES_NOP;
                        reg1_read_o <= `ReadDisable;
                        reg2_read_o <= `ReadEnable;
                        instvalid <= `InstValid;
                    end
                    `EXE_SLL: begin
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_SLL_OP;
                        alusel_o <= `EXE_RES_SHIFT;
                        reg2_read_o <= `ReadEnable;
                        imm[4:0] <= inst_i[10:6];
                        instvalid <= `InstValid;
                    end
                    `EXE_SRL: begin
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_SRL_OP;
                        alusel_o <= `EXE_RES_SHIFT;
                        reg2_read_o <= `ReadEnable;
                        imm[4:0] <= inst_i[10:6];
                        instvalid <= `InstValid;
                    end
                    `EXE_SRA: begin
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_SRA_OP;
                        alusel_o <= `EXE_RES_SHIFT;
                        reg2_read_o <= `ReadEnable;
                        imm[4:0] <= inst_i[10:6];
                        instvalid <= `InstValid;
                    end
                    default: begin
                    end
                endcase
            end
            default: begin
            end
        endcase // case op
    end // if
end // always

// 确定进行运算的源操作数 1
// NEW FEATURE
// 给 reg1_o 赋值的过程增加了两种情况
// 1. 如果 Regfile 模块读端口 1 要读取的寄存器就是执行阶段要写的目的寄存器
//      那么直接把执行阶段的结果 ex_wdata_i 作为 reg1_o 的值;
// 2. 如果 Regfile 模块读端口 1 要读取的寄存器就是访存阶段要写的目的寄存器
//      那么直接把访存阶段的结果 mem_wdata_i 作为 reg1_o 的值;

always @(*) begin
    if (rst == `RstEnable) begin
        reg1_o <= `ZeroWord;
    end// NEW FEATURE 数据前推
    else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1)
            && (ex_wd_i == reg1_addr_o)) begin
        // from ex
        reg1_o <= ex_wdata_i;

    end
    else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1)
            && (mem_wd_i == reg1_addr_o)) begin
        reg1_o <= mem_wdata_i;
    end
    // 通常来说，输出 reg1/2_o 作为 ALU 的输入，
    // 即可能是寄存器，也可能是立即数，
    // 需要根据`是否读取寄存器`这一条件来判断
    else if(reg1_read_o == `ReadEnable) begin
        // Regfile 读端口 1 的输出值
        reg1_o <= reg1_data_i;
    end
    else if(reg1_read_o == `ReadDisable) begin
        reg1_o <= imm;
    end
    else begin
        // 通常来说这句不会发生
        reg1_o <= `ZeroWord;
    end
end // always


// 确定进行运算的源操作数 2

always @(*) begin
    if (rst == `RstEnable) begin
        reg2_o <= `ZeroWord;
    end// NEW FEATURE 数据前推
    else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1)
            && (ex_wd_i == reg2_addr_o)) begin
        // from ex
        reg2_o <= ex_wdata_i;

    end
    else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1)
            && (mem_wd_i == reg2_addr_o)) begin
        reg2_o <= mem_wdata_i;
    end
    else if(reg2_read_o == `ReadEnable) begin
        // Regfile 读端口 2 的输出值
        reg2_o <= reg2_data_i;
    end
    else if(reg2_read_o == `ReadDisable) begin
        reg2_o <= imm;
    end
    else begin
        // 通常来说这句不会发生
        reg2_o <= `ZeroWord;
    end
end // always

endmodule // id
