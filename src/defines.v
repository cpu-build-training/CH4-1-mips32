// 全局的宏定义
`define RstEnable       1'b1    // 复位信号有效
`define RstDisable      1'b0
`define ChipEnable      1'b1    // 芯片使能
`define ChipDisable     1'b0
`define WriteEnable     1'b1    // 写使能
`define WriteDisable    1'b0
`define ReadEnable      1'b1    // 读使能
`define ReadDisable     1'b0    
`define AluOpBus        7:0     // 译码阶段的输出 aluop_o 的宽度
`define AluSelBus       2:0     // 译码阶段的输出 alusel_o 的宽度
`define InstValid       1'b0    // 指令有效
`define InstInvalid     1'b1    // 指令无效
`define ZeroWord        32'h0   // 32位的数值0

// 与具体指令有关的宏定义
`define EXE_ORI         6'b001101   // 指令 ori 的指令码
`define ExE_NOP         6'b000000

// AluOp
`define EXE_OR_OP       8'b00100101
`define EXE_NOP_OP      8'b0

// AluSel
`define EXE_RES_LOGIC   3'b001
`define EXE_RES_NOP     3'b000

// 与指令存储器 ROM 有关的宏定义
`define InstAddrBus     31:0    // ROM 的地址总线宽度
`define InstBus         31:0    // ROM 的数据总线宽度
`define InstAddrIncrement    4'h4    // PC 自动增加时的大小，这里采用字节寻址
`define InstMemNum      131071      // ROM 的实际大小为 128KB
`define InstMemNumLog2  17          // ROM 实际使用的地址线宽度

// 与通用寄存器 Regfile 有关的宏定义
`define RegAddrBus      4:0     // Regfile 模块的地址线宽度
`define RegBus          31:0    // Regfile 模块的数据先宽度
`define RegNum          32      // 通用寄存器的数量
`define RegNumLog2      5       // 寻址通用寄存器使用的地址位数，上面的数log2
`define NOPRegAddr      5'b0    // 