// ID 模块的作用是对指令进行译码，
// 得到最终运算的类型、子类型、源操作数1、
// 源操作数2、要写入的目的寄存器地址等信息
`include "defines.v"
module id(
         input wire             rst,
         wire [`InstAddrBus]    pc_i,
         wire[`InstBus]         inst_i,

         // 来自执行阶段的 aluop
         wire[`AluOpBus]        ex_aluop_i,

         // 读取的 Regfile 的值
         input wire[`RegBus]    reg1_data_i,
         wire[`RegBus]          reg2_data_i,

         // 输出到 Regfile 的信息
         output
         reg                    reg1_read_o,
         reg                    reg2_read_o,
         reg[`RegAddrBus]       reg1_addr_o,
         reg[`RegAddrBus]       reg2_addr_o,

         // 送到执行阶段的信息
         output reg[`AluOpBus]  aluop_o,
         reg[`AluSelBus]        alusel_o,
         reg[`RegBus]           reg1_o,
         reg[`RegBus]           reg2_o,
         reg[`RegAddrBus]       wd_o,
         output reg             wreg_o,

         //    TO CTRL
         output wire            stallreq,

         output wire[31:0]      excepttype_o,
         output wire[`RegBus]   current_inst_address_o,

         // 数据前推所需要加入的新的输入
         // 来自 ex, mem 的输出
         // 处于执行阶段的指令的运算结果
         input
         wire                   ex_wreg_i,
         wire[`RegBus]          ex_wdata_i,
         wire[`RegAddrBus]      ex_wd_i,

         // 处于访存阶段的指令的运算结果
         input
         wire                   mem_wreg_i,
         wire[`RegBus]          mem_wdata_i,
         wire[`RegAddrBus]      mem_wd_i,

         // 如果上一条指令是转移指令，那么下一条指令进入译码阶段的时候，输入变量
         // is_in_delayslot_i 为 true, 表示是延迟槽指令，反之，为 false
         input wire             is_in_delayslot_i,
         output reg             next_inst_in_delayslot_o,
         reg                    branch_flag_o,
         reg[`RegBus]           branch_target_address_o,
         reg[`RegBus]           link_addr_o,
         output reg             is_in_delayslot_o,

         // 当前处于译码阶段的指令
         output wire[`RegBus]   inst_o,

         // 在IF阶段产生的异常
         input wire[`RegBus]    excepttype_i
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

wire[5:0] op  = inst_i[31:26];
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0];
wire[4:0] op4 = inst_i[20:16];

// 分支指令
wire[`RegBus] pc_plus_8;
wire[`RegBus] pc_plus_4;

wire[`RegBus]   imm_sll2_signedext;

assign pc_plus_8 = pc_i + 8;
assign pc_plus_4 = pc_i + 4;

reg stallreq_for_reg1_loadrelate;
reg stallreq_for_reg2_loadrelate;
wire pre_inst_is_load;

// // 是否是系统调用异常 syscall
// reg excepttype_is_syscall;
// // 是否是异常返回指令 eret
// reg excepttype_is_eret;
// // 是否为断点异常 break
// reg excepttype_is_break;

// 这个阶段产生的异常，一种异常对应于其中的一位
reg[`RegBus] excepttype_cur_stage = 32'b0;

// 保存指令执行需要的立即数
reg[`RegBus] imm;

// 指示指令是否有效
reg instvalid;

// imm_sll2_signedext 对应分支指令中的 offset 左移两位，再符号扩展至 32 位的值
assign imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};

// inst_o 的值就是译码阶段的指令
assign inst_o = inst_i;
assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;

// TODO
// 当读内存可以在一个周期内解决，确实可以通过判断之前的指令来判断是否应该暂停流水线（只暂停一个周期）
// 但是当读内存的时间不固定以后，此方法失效，必须通过 AXI 或者 mem 给出的信号来判断当前是否有相关问题
// 只要 mem 没有读完，必须一直暂停流水线
// 不过也很有意思的是，mem 读的时候本身就暂停了流水线，这个相关问题应该也不存在了
assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) ||
                           (ex_aluop_i == `EXE_LBU_OP)||
                           (ex_aluop_i == `EXE_LH_OP) ||
                           (ex_aluop_i == `EXE_LHU_OP)||
                           (ex_aluop_i == `EXE_LW_OP) ||
                           (ex_aluop_i == `EXE_LWR_OP)||
                           (ex_aluop_i == `EXE_LWL_OP) // ||
                           //    (ex_aluop_i == `EXE_LL_OP) ||
                           //    (ex_aluop_i == `EXE_SC_OP)
                          ) ? 1'b1 : 1'b0;

// excepttype_o 的低 8bit 留给外部中断，第 8bit 表示是否是 syscall 指令引起的
// 系统调用异常，第 9bit 表示是否是无效指令引起的异常，第 12bit 表示是否是eret
// 指令， eret 指令可以认为是一种特殊的异常 -- 返回异常
assign excepttype_o = excepttype_cur_stage | excepttype_i;
// assign excepttype_o = {19'b0, excepttype_is_eret, 1'b0, excepttype_is_break, instvalid, excepttype_is_syscall, 8'b0};

// 输入信号 pc_i 就是当前处于译码阶段的指令的地址
assign current_inst_address_o = pc_i;


// 对指令进行译码

always @(*)
  begin
    if (rst == `RstEnable)
      begin
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        wd_o    = `NOPRegAddr;
        wreg_o  = `WriteDisable;
        instvalid = `InstValid;
        reg1_read_o = `ReadDisable;
        reg2_read_o = `ReadDisable;
        reg1_addr_o = `NOPRegAddr;
        reg2_addr_o = `NOPRegAddr;
        imm         = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_target_address_o = `ZeroWord;
        branch_flag_o = `NotBranch;
        next_inst_in_delayslot_o = `NotInDelaySlot;
        excepttype_cur_stage = `ZeroWord;
      end
    else if (pc_i[1:0] != 2'b00)
      begin
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        wd_o = inst_i[15:11];
        wreg_o = `WriteDisable;
        instvalid = `InstInvalid;
        reg1_read_o = `ReadDisable;
        reg2_read_o = `ReadDisable;
        reg1_addr_o = inst_i[25:21];
        reg2_addr_o = inst_i[20:16];
        imm         = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_target_address_o = `ZeroWord;
        branch_flag_o = `NotBranch;
        next_inst_in_delayslot_o = `NotInDelaySlot;
        excepttype_cur_stage = `ZeroWord;
        excepttype_cur_stage[`SYSCALL_IDX] = `False_v;
        excepttype_cur_stage[`ERET_IDX] = `False_v;
        excepttype_cur_stage[`BREAK_IDX] = `False_v;
        excepttype_cur_stage[`ADEL_IDX] = `True_v;
      end
    else
      begin
        // 没有进入 case 的代码相当于设定默认值
        aluop_o = `EXE_NOP_OP;
        alusel_o = `EXE_RES_NOP;
        wd_o = inst_i[15:11];
        wreg_o = `WriteDisable;
        instvalid = `InstInvalid;
        reg1_read_o = `ReadDisable;
        reg2_read_o = `ReadDisable;
        reg1_addr_o = inst_i[25:21];
        reg2_addr_o = inst_i[20:16];
        imm         = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_target_address_o = `ZeroWord;
        branch_flag_o = `NotBranch;
        next_inst_in_delayslot_o = `NotInDelaySlot;
        excepttype_cur_stage = `ZeroWord;
        excepttype_cur_stage[`SYSCALL_IDX] = `False_v;
        excepttype_cur_stage[`ERET_IDX] = `False_v;
        excepttype_cur_stage[`BREAK_IDX] = `False_v;
        excepttype_cur_stage[`ADEL_IDX] = `False_v;
        case (op)
          `EXE_ORI:
            begin // if op is ori
              // ori 指令需要将结果写入目的寄存器，所以 wreg_o 为 WriteEnable
              wreg_o = `WriteEnable;
              // 运算子类型是逻辑或
              aluop_o = `EXE_OR_OP;
              // 运算类型是逻辑运算
              alusel_o = `EXE_RES_LOGIC;
              // 需要通过 Regfile 的读端口 1 读取寄存器
              reg1_read_o = `ReadEnable;
              // 不需要通过 Regfile 的读端口 2 读取寄存器
              reg2_read_o = `ReadDisable;
              // 指令执行需要的立即数
              imm = {16'h0, inst_i[15:0]};
              // 指令执行要写的目的寄存器的地址
              wd_o = inst_i[20:16];
              // ori 指令是有效指令
              instvalid = `InstValid;
            end
          `EXE_ANDI:
            begin
              // CHECK
              wreg_o = `WriteEnable;
              aluop_o = `EXE_AND_OP;
              alusel_o = `EXE_RES_LOGIC;
              reg1_read_o = `ReadEnable;
              imm = {16'h0, inst_i[15:0]};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_XORI:
            begin
              // CHECK
              wreg_o = `WriteEnable;
              aluop_o = `EXE_XOR_OP;
              alusel_o = `EXE_RES_LOGIC;
              reg1_read_o = `ReadEnable;
              imm = {16'h0, inst_i[15:0]};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LUI:
            begin
              // CHECK
              wreg_o = `WriteEnable;
              aluop_o = `EXE_OR_OP;
              alusel_o = `EXE_RES_LOGIC;
              reg1_read_o = `ReadEnable;
              imm = {inst_i[15:0], 16'h0};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_PREF:
            begin
              // CHECK
              wreg_o = `WriteDisable;
              aluop_o = `EXE_NOP_OP;
              alusel_o = `EXE_RES_NOP;
              reg1_read_o = `ReadEnable;
              instvalid = `InstValid;
            end
          `EXE_SLTI:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_SLT_OP;
              alusel_o = `EXE_RES_ARITHMETIC;
              reg1_read_o = `ReadEnable;
              imm = {{16{inst_i[15]}}, inst_i[15:0]};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_SLTIU:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_SLTU_OP;
              alusel_o = `EXE_RES_ARITHMETIC;
              reg1_read_o = `ReadEnable;
              imm = {{16{inst_i[15]}}, inst_i[15:0]};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_ADDI:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_ADDI_OP;
              alusel_o = `EXE_RES_ARITHMETIC;
              reg1_read_o = `ReadEnable;
              imm = {{16{inst_i[15]}}, inst_i[15:0]};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_ADDIU:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_ADDIU_OP;
              alusel_o = `EXE_RES_ARITHMETIC;
              reg1_read_o = `ReadEnable;
              imm = {{16{inst_i[15]}}, inst_i[15:0]};
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_J:
            begin
              aluop_o = `EXE_J_OP;
              alusel_o = `EXE_RES_JUMP_BRANCH;
              branch_flag_o = `Branch;
              next_inst_in_delayslot_o = `InDelaySlot;
              instvalid = `InstValid;
              branch_target_address_o = {pc_plus_4[31:28], inst_i[25:0], 2'b00};
            end
          `EXE_JAL:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_JAL_OP;
              alusel_o = `EXE_RES_JUMP_BRANCH;
              wd_o = 5'b11111;
              link_addr_o = pc_plus_8;
              branch_flag_o = `Branch;
              next_inst_in_delayslot_o = `InDelaySlot;
              instvalid= `InstValid;
              branch_target_address_o = {pc_plus_4[31:28], inst_i[25:0], 2'b00};
            end
          `EXE_BEQ:
            begin
              aluop_o = `EXE_BEQ_OP;
              alusel_o = `EXE_RES_JUMP_BRANCH;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
              // 不管是否跳转都要标明下一条指令是否为延迟槽
              next_inst_in_delayslot_o = `InDelaySlot;
              if(reg1_o == reg2_o)
                begin
                  branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                  branch_flag_o = `Branch;
                end
            end
          `EXE_BGTZ:
            begin
              aluop_o = `EXE_BGTZ_OP;
              alusel_o = `EXE_RES_JUMP_BRANCH;
              reg1_read_o = `ReadEnable;
              instvalid = `InstValid;
              // 不管是否跳转都要标明下一条指令是否为延迟槽
              next_inst_in_delayslot_o = `InDelaySlot;
              if((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord))
                begin
                  branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                  branch_flag_o = `Branch;
                end
            end
          `EXE_BLEZ:
            begin
              aluop_o =  `EXE_BLEZ_OP;
              alusel_o = `EXE_RES_JUMP_BRANCH;
              reg1_read_o = `ReadEnable;
              instvalid = `InstValid;
              // 不管是否跳转都要标明下一条指令是否为延迟槽
              next_inst_in_delayslot_o = `InDelaySlot;
              if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord))
                begin
                  branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                  branch_flag_o = `Branch;
                end
            end
          `EXE_BNE:
            begin
              aluop_o = `EXE_BNE_OP;
              alusel_o = `EXE_RES_JUMP_BRANCH;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
              // 不管是否跳转都要标明下一条指令是否为延迟槽
              next_inst_in_delayslot_o = `InDelaySlot;
              if(reg1_o != reg2_o)
                begin
                  branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                  branch_flag_o = `Branch;
                end
            end
          `EXE_LB:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LB_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LBU:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LBU_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LH:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LH_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LHU:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LHU_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LW:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LW_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              // lw 应该不需要读这个
              // reg2_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LWL:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LWL_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_LWR:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LWR_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_SB:
            begin
              aluop_o = `EXE_SB_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
            end
          `EXE_SH:
            begin
              aluop_o = `EXE_SH_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
            end
          `EXE_SW:
            begin
              aluop_o = `EXE_SW_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
            end
          `EXE_SWL:
            begin
              aluop_o = `EXE_SWL_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
            end
          `EXE_SWR:
            begin
              aluop_o = `EXE_SWR_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              instvalid = `InstValid;
            end
          `EXE_LL:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_LL_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_SC:
            begin
              wreg_o = `WriteEnable;
              aluop_o = `EXE_SC_OP;
              alusel_o = `EXE_RES_LOAD_STORE;
              reg1_read_o = `ReadEnable;
              reg2_read_o = `ReadEnable;
              wd_o = inst_i[20:16];
              instvalid = `InstValid;
            end
          `EXE_SPECIAL:
            begin
              case (op3)
                `EXE_OR:
                  begin
                    // CHECKED
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_OR_OP;
                    alusel_o = `EXE_RES_LOGIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_XOR:
                  begin
                    // CHECKED
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_XOR_OP;
                    alusel_o = `EXE_RES_LOGIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_AND:
                  begin
                    // CHECKED
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_AND_OP;
                    alusel_o = `EXE_RES_LOGIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_NOR:
                  begin
                    // CHECKED
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_NOR_OP;
                    alusel_o = `EXE_RES_LOGIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SLLV:
                  begin
                    // CHECK
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SLL_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SRLV:
                  begin
                    // CHECK
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SRL_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SRAV:
                  begin
                    // CHECK
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SRA_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SYNC:
                  begin
                    // CHECK
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_NOP_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadDisable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SLL:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SLL_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg2_read_o = `ReadEnable;
                    imm[4:0] = inst_i[10:6];
                    instvalid = `InstValid;
                  end
                `EXE_SRL:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SRL_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg2_read_o = `ReadEnable;
                    imm[4:0] = inst_i[10:6];
                    instvalid = `InstValid;
                  end
                `EXE_SRA:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SRA_OP;
                    alusel_o = `EXE_RES_SHIFT;
                    reg2_read_o = `ReadEnable;
                    imm[4:0] = inst_i[10:6];
                    instvalid = `InstValid;
                  end
                `EXE_MFHI:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_MFHI_OP;
                    alusel_o = `EXE_RES_MOVE;
                    instvalid = `InstValid;
                  end
                `EXE_MFLO:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_MFLO_OP;
                    alusel_o = `EXE_RES_MOVE;
                    instvalid = `InstValid;
                  end
                `EXE_MTHI:
                  begin
                    wreg_o = `WriteDisable;
                    aluop_o = `EXE_MTHI_OP;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_MTLO:
                  begin
                    wreg_o = `WriteDisable;
                    aluop_o = `EXE_MTLO_OP;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_MOVN:
                  begin
                    aluop_o = `EXE_MOVN_OP;
                    alusel_o = `EXE_RES_MOVE;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                    // reg2_o 的值就是地址为 rt 的通用寄存器的值
                    if(reg2_o != `ZeroWord)
                      begin
                        wreg_o = `WriteEnable;
                      end
                    else
                      begin
                        wreg_o = `WriteDisable;
                      end
                  end
                `EXE_MOVZ:
                  begin
                    aluop_o = `EXE_MOVZ_OP;
                    alusel_o = `EXE_RES_MOVE;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                    // reg2_o 的值就是地址为 rt 的通用寄存器的值
                    if(reg2_o == `ZeroWord)
                      begin
                        wreg_o = `WriteEnable;
                      end
                    else
                      begin
                        wreg_o = `WriteDisable;
                      end
                  end
                `EXE_SLT:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SLT_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SLTU:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SLTU_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_ADD:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_ADD_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_ADDU:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_ADDU_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SUB:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SUB_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SUBU:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_SUBU_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_MULT:
                  begin
                    aluop_o = `EXE_MULT_OP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_MULTU:
                  begin
                    aluop_o = `EXE_MULTU_OP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_DIV:
                  begin
                    aluop_o = `EXE_DIV_OP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_DIVU:
                  begin
                    aluop_o = `EXE_DIVU_OP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_JR:
                  begin
                    aluop_o = `EXE_JR_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH;
                    reg1_read_o = `ReadEnable;
                    branch_target_address_o = reg1_o;
                    branch_flag_o = `Branch;
                    next_inst_in_delayslot_o = `InDelaySlot;
                    instvalid = `InstValid;
                  end
                `EXE_JALR:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_JALR_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH;
                    reg1_read_o = `ReadEnable;
                    link_addr_o = pc_plus_8;
                    branch_target_address_o = reg1_o;
                    branch_flag_o = `Branch;
                    next_inst_in_delayslot_o = `InDelaySlot;
                    instvalid = `InstValid;
                  end
                `EXE_TEQ:
                  begin
                    aluop_o = `EXE_TEQ_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_TGE:
                  begin
                    aluop_o = `EXE_TGE_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_TGEU:
                  begin
                    aluop_o = `EXE_TGEU_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_TLT:
                  begin
                    aluop_o = `EXE_TLT_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_TLTU:
                  begin
                    aluop_o = `EXE_TLTU_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_TNE:
                  begin
                    aluop_o = `EXE_TNE_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_SYSCALL:
                  begin
                    aluop_o = `EXE_SYSCALL_OP;
                    alusel_o = `EXE_RES_NOP;
                    instvalid = `InstValid;
                    excepttype_cur_stage[`SYSCALL_IDX] = `True_v;
                  end
                `EXE_BREAK:
                  begin
                    aluop_o = `EXE_BREAK_OP;
                    alusel_o = `EXE_RES_NOP;
                    instvalid = `InstValid;
                    excepttype_cur_stage[`BREAK_IDX] = `True_v;
                  end
                default:
                  begin
                  end
              endcase
            end
          `EXE_SPECIAL2:
            begin
              case (op3)
                `EXE_CLZ:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_CLZ_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_CLO:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_CLO_OP;
                    alusel_o = `EXE_RES_ARITHMETIC;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                `EXE_MUL:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_MUL_OP;
                    alusel_o = `EXE_RES_MUL;
                    reg1_read_o = `ReadEnable;
                    reg2_read_o = `ReadEnable;
                    instvalid = `InstValid;
                  end
                // `EXE_MADD:
                //   begin
                //     aluop_o = `EXE_MADD_OP;
                //     alusel_o = `EXE_RES_MUL;
                //     reg1_read_o = `ReadEnable;
                //     reg2_read_o = `ReadEnable;
                //     instvalid = `InstValid;
                //   end
                // `EXE_MADDU:
                //   begin
                //     wreg_o = `WriteDisable;
                //     aluop_o = `EXE_MADDU_OP;
                //     alusel_o = `EXE_RES_MUL;
                //     reg1_read_o = `ReadEnable;
                //     reg2_read_o = `ReadEnable;
                //     instvalid = `InstValid;
                //   end
                // `EXE_MSUB:
                //   begin
                //     wreg_o = `WriteDisable;
                //     aluop_o = `EXE_MSUB_OP;
                //     alusel_o = `EXE_RES_MUL;
                //     reg1_read_o = `ReadEnable;
                //     reg2_read_o = `ReadEnable;
                //     instvalid = `InstValid;
                //   end
                // `EXE_MSUBU:
                //   begin
                //     wreg_o = `WriteDisable;
                //     aluop_o = `EXE_MSUBU_OP;
                //     alusel_o = `EXE_RES_MUL;
                //     reg1_read_o = `ReadEnable;
                //     reg2_read_o = `ReadEnable;
                //     instvalid = `InstValid;
                //   end
                default:
                  begin

                  end
              endcase
            end
          `EXE_REGIMM_INST:
            begin
              case (op4)
                `EXE_BGEZ:
                  begin
                    aluop_o = `EXE_BGEZ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                    next_inst_in_delayslot_o = `InDelaySlot;
                    if(reg1_o[31] == 1'b0)
                      begin
                        branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o = `Branch;
                      end
                  end
                `EXE_BGEZAL:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_BGEZAL_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                    link_addr_o = pc_plus_8;
                    wd_o = 5'b11111;
                    next_inst_in_delayslot_o = `InDelaySlot;
                    if(reg1_o[31] == 1'b0)
                      begin
                        branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o = `Branch;
                      end
                  end
                `EXE_BLTZ:
                  begin
                    aluop_o = `EXE_BLTZ_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH;
                    reg1_read_o = `ReadEnable;
                    instvalid = `InstValid;
                    next_inst_in_delayslot_o = `InDelaySlot;
                    if(reg1_o[31] == 1'b1)
                      begin
                        branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o = `Branch;
                      end
                  end
                `EXE_BLTZAL:
                  begin
                    wreg_o = `WriteEnable;
                    aluop_o = `EXE_BLTZAL_OP;
                    alusel_o = `EXE_RES_JUMP_BRANCH;
                    reg1_read_o = `ReadEnable;
                    link_addr_o = pc_plus_8;
                    wd_o = 5'b11111;
                    instvalid = `InstValid;
                    next_inst_in_delayslot_o = `InDelaySlot;
                    if(reg1_o[31] == 1'b1)
                      begin
                        branch_target_address_o = pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o = `Branch;
                      end
                  end
                `EXE_TEQI:
                  begin
                    aluop_o = `EXE_TEQI_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    imm = {{16{inst_i[15]}}, inst_i[15:0]};
                    instvalid = `InstValid;
                  end
                `EXE_TGEI:
                  begin
                    aluop_o = `EXE_TGEI_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    imm = {{16{inst_i[15]}}, inst_i[15:0]};
                    instvalid = `InstValid;
                  end
                `EXE_TGEIU:
                  begin
                    aluop_o = `EXE_TGEIU_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    imm = {{16{inst_i[15]}}, inst_i[15:0]};
                    instvalid = `InstValid;
                  end
                `EXE_TLTI:
                  begin
                    aluop_o = `EXE_TLTI_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    imm = {{16{inst_i[15]}}, inst_i[15:0]};
                    instvalid = `InstValid;
                  end
                `EXE_TLTIU:
                  begin
                    aluop_o = `EXE_TLTIU_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    imm = {{16{inst_i[15]}}, inst_i[15:0]};
                    instvalid = `InstValid;
                  end
                `EXE_TNEI:
                  begin
                    aluop_o = `EXE_TNEI_OP;
                    alusel_o = `EXE_RES_NOP;
                    reg1_read_o = `ReadEnable;
                    imm = {{16{inst_i[15]}}, inst_i[15:0]};
                    instvalid = `InstValid;
                  end
                default:
                  begin
                  end
              endcase
            end
          default:
            begin
            end
        endcase // case op

        if(inst_i[31:21] == 11'b0_10000_00000 && inst_i[10:0] == 11'b0)
          begin
            aluop_o = `EXE_MFC0_OP;
            alusel_o = `EXE_RES_MOVE;
            wd_o = inst_i[20:16];
            wreg_o = `WriteEnable;
            instvalid = `InstValid;
          end
        else if (inst_i[31:21] == 11'b0_10000_00100 && inst_i[10:0] == 11'b0 )
          begin
            aluop_o = `EXE_MTC0_OP;
            alusel_o = `EXE_RES_NOP;
            wreg_o = `WriteDisable;
            instvalid = `InstValid;
            reg1_read_o = `ReadEnable;
            reg1_addr_o = inst_i[20:16];
          end
        else if (inst_i == `EXE_ERET)
          begin
            aluop_o = `EXE_ERET_OP;
            alusel_o = `EXE_RES_NOP;
            instvalid = `InstValid;
            excepttype_cur_stage[`ERET_IDX] = `True_v;
          end

        excepttype_cur_stage[`INSTINVALID_IDX] = instvalid;
      end // if
  end // always

// 确定进行运算的源操作数 1
// NEW FEATURE
// 给 reg1_o 赋值的过程增加了两种情况
// 1. 如果 Regfile 模块读端口 1 要读取的寄存器就是执行阶段要写的目的寄存器
//      那么直接把执行阶段的结果 ex_wdata_i 作为 reg1_o 的值;
// 2. 如果 Regfile 模块读端口 1 要读取的寄存器就是访存阶段要写的目的寄存器
//      那么直接把访存阶段的结果 mem_wdata_i 作为 reg1_o 的值;

always @(*)
  begin
    stallreq_for_reg1_loadrelate = `NoStop;
    if (rst == `RstEnable)
      begin
        reg1_o = `ZeroWord;
      end// NEW FEATURE 数据前推
    else if (pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o && reg1_read_o == `ReadEnable)
      begin
        stallreq_for_reg1_loadrelate = `Stop;
        reg1_o = `ZeroWord;
      end
    else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1)
            && (ex_wd_i == reg1_addr_o))
      begin
        // from ex
        reg1_o = ex_wdata_i;
      end
    else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1)
            && (mem_wd_i == reg1_addr_o))
      begin
        reg1_o = mem_wdata_i;
      end
    // 通常来说，输出 reg1/2_o 作为 ALU 的输入，
    // 即可能是寄存器，也可能是立即数，
    // 需要根据`是否读取寄存器`这一条件来判断
    else if(reg1_read_o == `ReadEnable)
      begin
        // Regfile 读端口 1 的输出值
        reg1_o = reg1_data_i;
      end
    else if(reg1_read_o == `ReadDisable)
      begin
        reg1_o = imm;
      end
    else
      begin
        // 通常来说这句不会发生
        reg1_o = `ZeroWord;
      end
  end // always


// 确定进行运算的源操作数 2

always @(*)
  begin
    stallreq_for_reg2_loadrelate = `NoStop;
    if (rst == `RstEnable)
      begin
        reg2_o = `ZeroWord;
      end// NEW FEATURE 数据前推
    else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o && reg2_read_o == 1'b1)
      begin
        stallreq_for_reg2_loadrelate= `Stop;
        reg2_o = `ZeroWord;
      end
    else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1)
            && (ex_wd_i == reg2_addr_o))
      begin
        // from ex
        reg2_o = ex_wdata_i;

      end
    else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1)
            && (mem_wd_i == reg2_addr_o))
      begin
        reg2_o = mem_wdata_i;
      end
    else if(reg2_read_o == `ReadEnable)
      begin
        // Regfile 读端口 2 的输出值
        reg2_o = reg2_data_i;
      end
    else if(reg2_read_o == `ReadDisable)
      begin
        reg2_o = imm;
      end
    else
      begin
        // 通常来说这句不会发生
        reg2_o = `ZeroWord;
      end
  end // always

always @(*)
  begin
    if(rst == `RstEnable)
      begin
        is_in_delayslot_o = `NotInDelaySlot;
      end
    else
      begin
        // 直接等于 is_in_delayslot_i
        is_in_delayslot_o = is_in_delayslot_i;
      end
  end

endmodule // id
