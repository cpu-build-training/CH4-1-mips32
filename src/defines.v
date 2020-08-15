// 全局的宏定义
`define RstEnable       1'b0    // 复位信号有效
`define RstDisable      1'b1
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
`define EXE_ANDI        6'b001100
`define EXE_XORI        6'b001110
`define EXE_LUI         6'b001111
`define EXE_SPECIAL     6'b000000
`define EXE_SPECIAL2    6'b011100
`define EXE_REGIMM_INST 6'b000001
`define EXE_PREF        6'b110011
`define EXE_ADDI        6'b001000
`define EXE_ADDIU       6'b001001
`define EXE_SLTI        6'b001010
`define EXE_SLTIU       6'b001011
`define EXE_COP0        6'b010000


// function code
`define EXE_OR          6'b100101
`define EXE_AND         6'b100100
`define EXE_XOR         6'b100110
`define EXE_NOP         6'b000000   // same as SLL
`define EXE_NOR         6'b100111
`define EXE_SLL         6'b000000
`define EXE_SLLV        6'b000100
`define EXE_SRA         6'b000011
`define EXE_SRAV        6'b000111
`define EXE_SRL         6'b000010
`define EXE_SRLV        6'b000110
`define EXE_SYNC        6'b001111
`define EXE_MOVZ        6'b001010
`define EXE_MOVN        6'b001011
`define EXE_MFHI        6'b010000
`define EXE_MTHI        6'b010001
`define EXE_MFLO        6'b010010
`define EXE_MTLO        6'b010011
`define EXE_ADD         6'b100000
`define EXE_ADDU        6'b100001
`define EXE_SUB         6'b100010
`define EXE_SUBU        6'b100011
`define EXE_CLO         6'b100001
`define EXE_CLZ         6'b100000
`define EXE_SLT         6'b101010
`define EXE_SLTU        6'b101011
`define EXE_MUL         6'b000010
`define EXE_MULT        6'b011000
`define EXE_MULTU       6'b011001
// `define EXE_MADD        6'b000000
// `define EXE_MADDU       6'b000001
`define EXE_MSUB        6'b000100
`define EXE_MSUBU       6'b000101
`define EXE_DIV         6'b011010
`define EXE_DIVU        6'b011011
`define EXE_J           6'b000010
`define EXE_JAL         6'b000011
`define EXE_JALR        6'b001001
`define EXE_JR          6'b001000
`define EXE_BEQ         6'b000100
`define EXE_BGEZ        5'b00001
`define EXE_BGEZAL      5'b10001
`define EXE_BGTZ        6'b000111
`define EXE_BLEZ        6'b000110
`define EXE_BLTZ        5'b00000
`define EXE_BLTZ        5'b00000
`define EXE_BLTZAL      5'b10000
`define EXE_BNE         6'b000101
`define EXE_LB          6'b100000
`define EXE_LBU         6'b100100
`define EXE_LH          6'b100001
`define EXE_LHU         6'b100101
`define EXE_LW          6'b100011
`define EXE_LWL         6'b100010
`define EXE_LWR         6'b100110
`define EXE_SB          6'b101000
`define EXE_SH          6'b101001
`define EXE_SW          6'b101011
`define EXE_SWL         6'b101010
`define EXE_SWR         6'b101110
`define EXE_LL          6'b110000
`define EXE_SC          6'b111000
`define EXE_SYSCALL     6'b001100
`define EXE_BREAK       6'b001101
`define EXE_TEQ         6'b110100
`define EXE_TEQI        5'b01100
`define EXE_TGE         6'b110000
`define EXE_TGEI        5'b01000
`define EXE_TGEIU       5'b01001
`define EXE_TGEU        6'b110001
`define EXE_TLT         6'b110010
`define EXE_TLTI        5'b01010
`define EXE_TLTIU       5'b01011
`define EXE_TLTU        6'b110011
`define EXE_TNE         6'b110110
`define EXE_TNEI        5'b01110

`define EXE_ERET        32'b01000010_00000000_00000000_00011000
// COP0
`define EXE_TLBP        6'b001000
`define EXE_TLBR        6'b000001
`define EXE_TLBWI       6'b000010
`define EXE_TLBWR       6'b000110



// AluOp !!! 尽量不要出现重复，比如 ADD & CLZ
`define EXE_OR_OP       8'b00100101
`define EXE_NOP_OP      8'b00000000
`define EXE_AND_OP      8'b00100100
`define EXE_XOR_OP      8'b00100110
`define EXE_NOR_OP      8'b00100111
`define EXE_SLL_OP      8'b00000100
`define EXE_SRL_OP      8'b00000110
`define EXE_SRA_OP      8'b00000111
`define EXE_MFHI_OP     8'b00010000
`define EXE_MFLO_OP     8'b00010010
`define EXE_MTHI_OP     8'b00010001
`define EXE_MTLO_OP     8'b00010011
`define EXE_MOVZ_OP     8'b00001010
`define EXE_MOVN_OP     8'b00001011
`define EXE_SUB_OP      8'b00100010
`define EXE_SUBU_OP     8'b00100011
`define EXE_SLT_OP      8'b00101010
`define EXE_SLTU_OP     8'b00101011
`define EXE_ADD_OP      8'b00100000
`define EXE_ADDU_OP     8'b00100001
`define EXE_MULT_OP     8'b00011000
`define EXE_MULTU_OP    8'b00011001
`define EXE_ADDI_OP     8'b00001100
`define EXE_ADDIU_OP    8'b00001001
`define EXE_CLZ_OP      8'b01100000
`define EXE_CLO_OP      8'b01100001
`define EXE_MUL_OP      8'b00000010
// `define EXE_MADD_OP        8'b01000000
// `define EXE_MADDU_OP       8'b01000001
// `define EXE_MSUB_OP        8'b01000100
// `define EXE_MSUBU_OP       8'b01000101
`define EXE_DIV_OP          8'b00011010
`define EXE_DIVU_OP         8'b00011011
`define EXE_J_OP            8'b01000010
`define EXE_JAL_OP          8'b01000011
`define EXE_JALR_OP         8'b01001001
`define EXE_JR_OP           8'b01001000
`define EXE_BEQ_OP          8'b10000100
`define EXE_BGEZ_OP         8'b00000001
`define EXE_BGEZAL_OP       8'b10010001
`define EXE_BGTZ_OP         8'b10000111
`define EXE_BLEZ_OP         8'b10000110
`define EXE_BLTZ_OP         8'b00000000
`define EXE_BLTZ_OP         8'b00000000
`define EXE_BLTZAL_OP       8'b10010000
`define EXE_BNE_OP          8'b00000101
`define EXE_LB_OP           8'b10100000
`define EXE_LBU_OP          8'b10100100
`define EXE_LH_OP           8'b10100001
`define EXE_LHU_OP          8'b10100101
`define EXE_LW_OP           8'b10100011
`define EXE_LWL_OP          8'b10100010
`define EXE_LWR_OP          8'b10100110
`define EXE_SB_OP           8'b00101000
`define EXE_SH_OP           8'b00101001
`define EXE_SW_OP           8'b10101011
`define EXE_SWL_OP          8'b10101010
`define EXE_SWR_OP          8'b00101110
`define EXE_LL_OP           8'b00110000
`define EXE_SC_OP           8'b00111000
`define EXE_MFC0_OP         8'b10111010
`define EXE_MTC0_OP         8'b10111011
`define EXE_SYSCALL_OP      8'b10001100
`define EXE_BREAK_OP        8'b10001101
`define EXE_TEQ_OP          8'b00110100
`define EXE_TEQI_OP         8'b10101100
`define EXE_TGE_OP          8'b10110000
`define EXE_TGEI_OP         8'b10101000
`define EXE_TGEIU_OP        8'b10101001
`define EXE_TGEU_OP         8'b10110001
`define EXE_TLT_OP          8'b10110010
`define EXE_TLTI_OP         8'b11101010
`define EXE_TLTIU_OP        8'b11101011
`define EXE_TLTU_OP         8'b10110011
`define EXE_TNE_OP          8'b10110110
`define EXE_TNEI_OP         8'b10101110
`define EXE_ERET_OP         8'b00101111
`define EXE_TLBP_OP         8'b10000000
`define EXE_TLBR_OP         8'b10000001
`define EXE_TLBWI_OP        8'b10000010
`define EXE_TLBWR_OP        8'b10000011


// AluSel
`define EXE_RES_LOGIC       3'b001
`define EXE_RES_NOP         3'b000
`define EXE_RES_SHIFT       3'b010
`define EXE_RES_MOVE        3'b011
`define EXE_RES_ARITHMETIC  3'b100
`define EXE_RES_MUL         3'b101
`define EXE_RES_JUMP_BRANCH 3'b110
`define EXE_RES_LOAD_STORE  3'b111

// 与指令存储器 ROM 有关的宏定义
`define InstAddrBus     31:0    // ROM 的地址总线宽度
`define InstBus         31:0    // ROM 的数据总线宽度
`define InstAddrIncrement    32'h4    // PC 自动增加时的大小，这里采用字节寻址
`define InstMemNum      131071      // ROM 的实际大小为 128KB
`define InstMemNumLog2  17          // ROM 实际使用的地址线宽度

// 与通用寄存器 Regfile 有关的宏定义
`define RegAddrBus      4:0     // Regfile 模块的地址线宽度
`define RegBus          31:0    // Regfile 模块的数据先宽度
`define DoubleRegBus    63:0    // 2 * RegBus
`define RegNum          32      // 通用寄存器的数量
`define RegNumLog2      5       // 寻址通用寄存器使用的地址位数，上面的数log2
`define NOPRegAddr      5'b0    //

// For CTRL unit
`define Stop            1'b1    // 流水线暂停
`define NoStop          1'b0    // 流水线继续

// DIV unit
`define DivFree         2'b00
`define DivByZero       2'b01
`define DivOn           2'b10
`define DivEnd          2'b11

`define DivResultNotReady   1'b0
`define DivResultReady      1'b1
`define DivStart        1'b1
`define DivStop         1'b0

`define Branch          1'b1
`define NotBranch       1'b0

`define InDelaySlot     1'b1        // 在延迟槽中
`define NotInDelaySlot  1'b0

`define DataAddrBus     31:0        // 地址总线宽度
`define DataBus         31:0        // 数据总线宽度
`define DataMemNum      500 //131071      // RAM 的大小，单位是字，此处是 128K word
`define DataMemNumLog2  17          // 实际使用的地址宽度
`define ByteWidth       7:0         // 一个字节的宽度，是 8bit

`define CP0_REG_INDEX       5'b00000  // 0
`define CP0_REG_RANDOM      5'b00001  // 1
`define CP0_REG_ENTRYLO0    5'b00010  // 2
`define CP0_REG_ENTRYLO1    5'b00011  // 3
`define CP0_REG_CONTEXT     5'b00100  // 4
`define CP0_REG_PAGEMASK    5'b00101  // 5
`define CP0_REG_WIRED       5'b00110  // 6
`define CP0_REG_ENTRYHI     5'b01010  // 10
`define CP0_REG_COUNT       5'b01001
`define CP0_REG_COMPARE     5'b01011
`define CP0_REG_STATUS      5'b01100
`define CP0_REG_CAUSE       5'b01101
`define CP0_REG_EPC         5'b01110
`define CP0_REG_PRID        5'b01111
`define CP0_REG_CONFIG      5'b10000
`define CP0_REG_BADVADDR    5'b01000

`define InterruptAssert     1'b1
`define InterruptNotAssert     1'b0

`define TrapAssert          1'b1
`define TrapNotAssert       1'b0

`define False_v             1'b0
`define True_v              1'b1

// for axi
`define Ready               1'b1
`define NotReady            1'b0
`define Valid               1'b1
`define InValid             1'b0
`define ReadFree            2'b00
`define BusyForIF           2'b01
`define BusyForMEM          2'b10
`define WriteFree           1'b0
`define WriteBusy           1'b1

// tlb
`define VPN2        89:71
`define ASID        70:63
`define PAGEMASK    62:51
`define G           50
`define PFN0        49:30
`define C0          29:27
`define D0          26
`define V0          25
`define PFN1        24:5
`define C1          4:2
`define D1          1
`define V1          0

// Exception Related
// 在mem及之前各类型异常对应的标志位在excepttype中的下标
`define INTERRUPT_IDX       7:0
`define SYSCALL_IDX         8
`define INSTINVALID_IDX     9
`define BREAK_IDX           10
`define ERET_IDX            11
`define TRAP_IDX            12
`define OVERFLOW_IDX        13
`define ADEL_IDX            14
`define ADES_IDX            15
`define TLBRL_CODE_IDX      16  // TLB refill, entrace: 0xbfc00200
`define TLBRL_DATA_IDX      17
`define TLBRS_IDX           18
`define TLBIL_CODE_IDX      19  // TLB invalid, entrace: 0xbfc00380
`define TLBIL_DATA_IDX      20
`define TLBIS_IDX           21
`define TLBM_IDX            22  // TLB modified, entrace: 0xbfc00380

`define NOEXC_FINAL         32'h0000_0000
`define INTERRUPT_FINAL     32'h0000_0001
`define SYSCALL_FINAL       32'h0000_0008
`define INSTINVALID_FINAL   32'h0000_000a
`define BREAK_FINAL         32'h0000_0009
`define ERET_FINAL          32'h0000_000e
`define TRAP_FINAL          32'h0000_000d
`define OVERFLOW_FINAL      32'h0000_000c
`define ADEL_FINAL          32'h0000_000f
`define ADES_FINAL          32'h0000_0010
`define TLBRL_CODE_FINAL    32'h0000_0011  // load refill
`define TLBRL_DATA_FINAL    32'h0000_0012
`define TLBRS_FINAL         32'h0000_0013  // store refill
`define TLBIL_CODE_FINAL    32'h0000_0014  // load invalid
`define TLBIL_DATA_FINAL    32'h0000_0015
`define TLBIS_FINAL         32'h0000_0016  // store invalid
`define TLBM_FINAL          32'h0000_0017  // modified

// 填入CP0.Cause.ExcCode
`define EXCCODE_INT         5'b00000
`define EXCCODE_SYSCALL     5'b01000
`define EXCCODE_BR          5'b01001
`define EXCCODE_INSTINV     5'b01010
`define EXCCODE_TR          5'b01101
`define EXCCODE_OV          5'b01100
`define EXCCODE_ADEL        5'b00100
`define EXCCODE_ADES        5'b00101
`define EXCCODE_TLBL        5'h2
`define EXCCODE_TLBS        5'h3
`define EXCCODE_TLBM        5'h1