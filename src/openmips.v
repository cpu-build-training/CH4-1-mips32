// 对上述模块进行实例化、连接
`include "defines.v"
module openmips(
         input
         wire  clk,  rst,

         input wire[`RegBus]     rom_data_i,
         input wire              rom_data_valid,
         output  wire[`RegBus]   rom_addr_o,
         output wire             rom_ce_o,
         wire                    inst_ready,
         wire                    mem_data_ready,


         input wire[`RegBus]      ram_data_i,
         input wire                     ram_write_valid,
         output
         wire[`RegBus]     ram_addr_o,
         wire[`RegBus]     ram_data_o,

         output wire                ram_we_o,
         wire[3:0]           ram_sel_o,
         output wire                ram_ce_o,
         wire                ram_re_o,

         // 6 个外部硬件中断输入
         input wire[5:0]          int_i,
         // 是否有定时中断发生
         output wire          timer_int_o,

         // debug use
         wire[31:0]      debug_wb_pc,
         wire[3:0]       debug_wb_rf_wen,
         wire[4:0]       debug_wb_rf_wnum,
         wire[31:0]      debug_wb_rf_wdata
       );
// id_pc_i 模块_功能_输入or输出

// 送入 PC 有关跳转的信号
wire[`RegBus] pc_branch_target_address_i;
wire pc_branch_flag_i;

//  连接 IF/ID 模块与译码阶段 ID 模块的变量
wire[`InstAddrBus]  pc;
wire[`InstAddrBus]  id_pc_i;
wire[`InstBus]      id_inst_i;

// 从 ID/EX 回写到 ID 的变量
wire                id_is_in_delayslot_i;

// 连接译码阶段 ID 模块输出与 ID/EX 模块的输入变量
wire[`AluOpBus]     id_aluop_o;
wire[`AluSelBus]    id_alusel_o;
wire[`RegBus]       id_reg1_o;
wire[`RegBus]       id_reg2_o;
wire                id_wreg_o;
wire[`RegAddrBus]   id_wd_o;
wire                id_is_in_delayslot_o;
wire[`RegBus]       id_link_addr_o;
wire                id_next_inst_in_delayslot_o;
wire[`RegBus]       id_inst_o;
wire[31:0]          id_excepttype_o;
wire[`RegBus]       id_current_inst_addr_o;



// 连接 ID/EX 模块输出与执行阶段 EX 模块的输入变量
wire[`AluOpBus]     ex_aluop_i;
wire[`AluSelBus]    ex_alusel_i;
wire[`RegBus]       ex_reg1_i;
wire[`RegBus]       ex_reg2_i;
wire                ex_wreg_i;
wire[`RegAddrBus]   ex_wd_i;
wire                ex_is_in_delayslot_i;
wire[`RegBus]       ex_link_address_i;
wire[`RegBus]       ex_inst_i;
wire[31:0]          ex_excepttype_i;
wire[`RegBus]       ex_current_inst_addr_i;

// 连接执行阶段 EX 模块的输出与 EX/MEM 模块的输入的变量
wire                ex_wreg_o;
wire[`RegAddrBus]   ex_wd_o;
wire[`RegBus]       ex_wdata_o;
wire                ex_whilo_o;
wire[`RegBus]       ex_hi_o;
wire[`RegBus]       ex_lo_o;
wire[1:0]           cnt_o;
wire[`DoubleRegBus] hilo_temp_o;
wire[`AluOpBus]     ex_aluop_o;
wire[`RegBus]       ex_mem_addr_o;
wire[`RegBus]       ex_reg2_o;
wire[4:0]           ex_cp0_reg_write_addr_o;
wire                ex_cp0_reg_we_o;
wire[`RegBus]       ex_cp0_reg_data_o;
wire[31:0]          ex_excepttype_o;
wire[`RegBus]       ex_current_inst_addr_o;
wire                ex_is_in_delayslot_o;



// 连接 EX/MEM 模块的输出与访存阶段 MEM 模块的输入的变量
wire[4:0]           mem_wreg_i;
wire[`RegAddrBus]   mem_wd_i;
wire[`RegBus]       mem_wdata_i;
wire                mem_whilo_i;
wire[`RegBus]       mem_hi_i;
wire[`RegBus]       mem_lo_i;
wire[`AluOpBus]     mem_aluop_i;
wire[`RegBus]       mem_mem_addr_i;
wire[`RegBus]       mem_reg2_i;
wire[31:0]          mem_excepttype_i;
wire[`RegBus]       mem_current_inst_addr_i;
wire                mem_is_in_delayslot_i;

// 连接访存阶段 MEM 模块的输出与 MEM/WB 模块的输入变量
wire                mem_wreg_o;
wire[`RegAddrBus]   mem_wd_o;
wire[`RegBus]       mem_wdata_o;
wire                mem_whilo_o;
wire[`RegBus]       mem_hi_o;
wire[`RegBus]       mem_lo_o;
wire                mem_LLbit_we_o;
wire                mem_LLbit_value_o;
wire                mem_cp0_reg_we_i;
wire                mem_cp0_reg_we_o;
wire[4:0]           mem_cp0_reg_write_addr_i;
wire[4:0]           mem_cp0_reg_write_addr_o;
wire[`RegBus]       mem_cp0_reg_data_i;
wire[`RegBus]       mem_cp0_reg_data_o;
// To cp0
wire                mem_is_in_delayslot_o;
wire[`RegBus]       mem_current_inst_addr_o;

// 连接 MEM/WB 模块的输出与回写阶段的输入的变量
wire                wb_wreg_i;
wire[`RegAddrBus]   wb_wd_i;
wire[`RegBus]       wb_wdata_i;
wire                wb_LLbit_we;
wire                wb_LLbit_value;

// 连接 MEM/WB 与 HILO 模块的变量
wire                hilo_we_i;
wire[`RegBus]       hilo_hi_i;
wire[`RegBus]       hilo_lo_i;

// HILO 输出 即 EX 输入
wire[`RegBus]       hilo_hi_o;
wire[`RegBus]       hilo_lo_o;

// 连接译码阶段 ID 模块与通用寄存器 Regfile 模块的变量
wire                reg1_read;
wire                reg2_read;
wire[`RegBus]       reg1_data;
wire[`RegBus]       reg2_data;
wire[`RegAddrBus]   reg1_addr;
wire[`RegAddrBus]   reg2_addr;

// 连接 CTRL 和其他模块的通路
wire                stallreq_from_if;
wire                stallreq_from_id;
wire                stallreq_from_ex;
wire                stallreq_from_mem;
wire[5:0]           stall;
wire                flush;
wire[`RegBus]       new_pc;
wire[`RegBus]       ctrl_cp0_epc;
wire[31:0]          excepttype;

// EX/MEM -> EX
wire[1:0]           cnt_i;
wire[`DoubleRegBus] hilo_temp_i;

// DIV modules
wire[`DoubleRegBus] ex_div_result_i;
wire                ex_div_ready_i;
wire[`RegBus]        ex_div_opdata1_o;
wire[`RegBus]        ex_div_opdata2_o;
wire                 ex_div_start_o;
wire                 ex_signed_div_o;

// LLbit
wire                 LLbit_LLbit_value;

// CP0
wire                cp0_we_i;
wire[4:0]           cp0_waddr_i;
wire[4:0]           cp0_raddr_i;
wire[`RegBus]       cp0_data_i;
wire[`RegBus]       cp0_data_o;
wire[`RegBus]       cp0_status_o;
wire[`RegBus]       cp0_count_o;
wire[`RegBus]       cp0_compare_o;
wire[`RegBus]       cp0_cause_o;
wire[`RegBus]       cp0_epc_o;
wire[`RegBus]       cp0_config_o;
wire[`RegBus]       cp0_prid_o;

// pc_reg 实例化
pc_reg  pc_reg0(
          .clk(clk), .rst(rst), .pc(pc), .ce(rom_ce_o),
          .stall(stall),

          .branch_flag_i(pc_branch_flag_i),
          .branch_target_address_i(pc_branch_target_address_i),

          .flush(flush),
          .new_pc(new_pc)
        );

assign rom_addr_o = pc; // 指令存储器的输入地址就是 pc 的值

assign debug_wb_rf_wen = {4{wb_wreg_i}};
assign debug_wb_rf_wdata = wb_wdata_i;
assign debug_wb_rf_wnum = wb_wd_i;


// IF/ID 实例化
if_id if_id0(
        .clk(clk), .rst(rst), .if_pc(pc),
        .if_inst(rom_data_i), .id_pc(id_pc_i),
        .id_inst(id_inst_i),
        .stall(stall),

        .inst_valid(rom_data_valid),
        .inst_ready(inst_ready),
        .stallreq_for_if(stallreq_from_if),
        .flush(flush)
      );

id id0(
     .rst(rst), .pc_i(id_pc_i), .inst_i(id_inst_i),

     // 来自 Regfile 模块的输入
     .reg1_data_i(reg1_data), .reg2_data_i(reg2_data),

     // 送到 regfile 模块的信息
     .reg1_read_o(reg1_read), .reg2_read_o(reg2_read),
     .reg1_addr_o(reg1_addr), .reg2_addr_o(reg2_addr),

     // 送到 ID/EX 模块的信息
     .aluop_o(id_aluop_o), .alusel_o(id_alusel_o),
     .reg1_o(id_reg1_o), .reg2_o(id_reg2_o),
     .wd_o(id_wd_o), .wreg_o(id_wreg_o),
     .inst_o(id_inst_o),

     // NEW FEATURE 数据前推
     .ex_wreg_i(ex_wreg_o), .ex_wdata_i(ex_wdata_o),
     .ex_wd_i(ex_wd_o),.ex_aluop_i(ex_aluop_o),

     .mem_wreg_i(mem_wreg_o), .mem_wdata_i(mem_wdata_o),
     .mem_wd_i(mem_wd_o),

     .stallreq(stallreq_from_id),

     .is_in_delayslot_i(id_is_in_delayslot_i),
     .is_in_delayslot_o(id_is_in_delayslot_o),
     .link_addr_o(id_link_addr_o),
     .next_inst_in_delayslot_o(id_next_inst_in_delayslot_o),
     .branch_target_address_o(pc_branch_target_address_i),
     .branch_flag_o(pc_branch_flag_i),

     .excepttype_o(id_excepttype_o),
     .current_inst_address_o(id_current_inst_addr_o)
   );

// 通用寄存器 Regfile 实例化
regfile regfile1(
          .clk (clk), .rst(rst),
          .we(wb_wreg_i), .waddr(wb_wd_i),
          .wdata(wb_wdata_i), .re1(reg1_read),
          .raddr1(reg1_addr), .rdata1(reg1_data),
          .re2(reg2_read), .raddr2(reg2_addr),
          .rdata2(reg2_data)
        );

// ID/EX 实例化
id_ex id_ex0(
        .clk(clk),      .rst(rst),

        // 从译码阶段 ID 模块传递过来的信息
        .id_aluop(id_aluop_o), .id_alusel(id_alusel_o),
        .id_reg1(id_reg1_o), .id_reg2(id_reg2_o),
        .id_wd(id_wd_o), .id_wreg(id_wreg_o),
        .id_inst(id_inst_o),

        // 传递到执行阶段 EX 模块的信息
        .ex_aluop(ex_aluop_i), .ex_alusel(ex_alusel_i),
        .ex_reg1(ex_reg1_i), .ex_reg2(ex_reg2_i),
        .ex_wd(ex_wd_i),    .ex_wreg(ex_wreg_i),

        .ex_inst(ex_inst_i),

        .stall(stall),

        .id_link_address(id_link_addr_o),
        .id_is_in_delayslot(id_is_in_delayslot_o),
        .next_inst_in_delayslot_i(id_next_inst_in_delayslot_o),
        .ex_is_in_delayslot(ex_is_in_delayslot_i),
        .ex_link_address(ex_link_address_i),
        .is_in_delayslot_o(id_is_in_delayslot_i),

        .flush(flush),
        .id_excepttype(id_excepttype_o),
        .id_current_inst_address(id_current_inst_addr_o),
        .ex_excepttype(ex_excepttype_i),
        .ex_current_inst_address(ex_current_inst_addr_i)
      );

// EX 实例化
ex ex0(
     .rst(rst),

     // 从 ID/EX 模块传递过来的信息
     .aluop_i(ex_aluop_i), .alusel_i(ex_alusel_i),
     // FIXED: 错写成 .reg2_i(ex_reg1_i)
     // 通过调试逐步发现的
     .reg1_i(ex_reg1_i), .reg2_i(ex_reg2_i),
     .wd_i(ex_wd_i), .wreg_i(ex_wreg_i),

     // from HILO
     .hi_i(hilo_hi_o),.lo_i(hilo_lo_o),

     .inst_i(ex_inst_i),

     // 输出到 EX/MEM 模块的信息
     .wd_o(ex_wd_o), .wreg_o(ex_wreg_o),
     .wdata_o(ex_wdata_o),

     .whilo_o(ex_whilo_o),
     .hi_o(ex_hi_o),.lo_o(ex_lo_o),

     .cnt_o(cnt_o),
     .hilo_temp_o(hilo_temp_o),

     .aluop_o(ex_aluop_o),
     .mem_addr_o(ex_mem_addr_o),
     .reg2_o(ex_reg2_o),

     // 从 MEM 过来的数据
     .mem_whilo_i(mem_whilo_o),
     .mem_hi_i(mem_hi_o),
     .mem_lo_i(mem_lo_o),

     // 从 MEM/WB 过来的数据
     .wb_whilo_i(hilo_we_i),
     .wb_hi_i(hilo_hi_i),
     .wb_lo_i(hilo_lo_i),

     // From EX/MEM
     .cnt_i(cnt_i),
     .hilo_temp_i(hilo_temp_i),

     // TO CTRL
     .stallreq(stallreq_from_ex),

     // For DIV modules
     .div_result_i(ex_div_result_i),
     .div_ready_i(ex_div_ready_i),

     .div_opdata1_o(ex_div_opdata1_o),
     .div_opdata2_o(ex_div_opdata2_o),
     .div_start_o(ex_div_start_o),
     .signed_div_o(ex_signed_div_o),

     .is_in_delayslot_i(ex_is_in_delayslot_i),
     .link_address_i(ex_link_address_i),

     // cp0
     .cp0_reg_data_i(cp0_data_o),
     .cp0_reg_read_addr_o(cp0_raddr_i),

     .wb_cp0_reg_we(cp0_we_i),
     .wb_cp0_reg_write_addr(cp0_waddr_i),
     .wb_cp0_reg_data(cp0_data_i),

     .mem_cp0_reg_we(mem_cp0_reg_we_o),
     .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
     .mem_cp0_reg_data(mem_cp0_reg_data_o),

     .cp0_reg_we_o(ex_cp0_reg_we_o),
     .cp0_reg_write_addr_o(ex_cp0_reg_write_addr_o),
     .cp0_reg_data_o(ex_cp0_reg_data_o),

     .excepttype_i(ex_excepttype_i),
     .current_inst_address_i(ex_current_inst_addr_i),
     .excepttype_o(ex_excepttype_o),
     .current_inst_address_o(ex_current_inst_addr_o),
     .is_in_delayslot_o(ex_is_in_delayslot_o)
   );

// EX/MEM 实例化
ex_mem ex_mem0(
         .clk(clk),  .rst(rst), .flush(flush),

         // 来自执行阶段 EX 模块的信息
         .ex_wd(ex_wd_o), .ex_wreg(ex_wreg_o),
         .ex_wdata(ex_wdata_o),

         .ex_whilo(ex_whilo_o), .ex_hi(ex_hi_o),
         .ex_lo(ex_lo_o),

         .cnt_i(cnt_o),
         .hilo_i(hilo_temp_o),

         .ex_aluop(ex_aluop_o),
         .ex_mem_addr(ex_mem_addr_o),
         .ex_reg2(ex_reg2_o),

         // 送到访存阶段 MEM 模块的信息
         .mem_wd(mem_wd_i), .mem_wreg(mem_wreg_i),
         .mem_wdata(mem_wdata_i),

         .mem_hi(mem_hi_i), .mem_lo(mem_lo_i),
         .mem_whilo(mem_whilo_i),

         .mem_aluop(mem_aluop_i),
         .mem_mem_addr(mem_mem_addr_i),
         .mem_reg2(mem_reg2_i),


         .stall(stall),

         // TO EX
         .cnt_o(cnt_i),
         .hilo_o(hilo_temp_i),

         // cp0
         .ex_cp0_reg_we(ex_cp0_reg_we_o),
         .ex_cp0_reg_write_addr(ex_cp0_reg_write_addr_o),
         .ex_cp0_reg_data(ex_cp0_reg_data_o),

         .mem_cp0_reg_we(mem_cp0_reg_we_i),
         .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_i),
         .mem_cp0_reg_data(mem_cp0_reg_data_i),

         .ex_excepttype(ex_excepttype_o),
         .ex_current_inst_address(ex_current_inst_addr_o),
         .ex_is_in_delayslot(ex_is_in_delayslot_o),
         .mem_excepttype(mem_excepttype_i),
         .mem_current_inst_address(mem_current_inst_addr_i),
         .mem_is_in_delayslot(mem_is_in_delayslot_i)

       );

// MEM 实例化
mem mem0(
      .rst(rst),

      // 来自 EX/MEM 模块的信息
      .wd_i(mem_wd_i), .wreg_i(mem_wreg_i),
      .wdata_i(mem_wdata_i),
      .mem_write_valid(ram_write_valid),
      .mem_data_i_valid(ram_write_valid),
      .mem_read_ready(mem_data_ready),
      .stallreq_for_mem(stallreq_from_mem),

      .whilo_i(mem_whilo_i),
      .hi_i(mem_hi_i),.lo_i(mem_lo_i),

      .aluop_i(mem_aluop_i),
      .mem_addr_i(mem_mem_addr_i),
      .reg2_i(mem_reg2_i),

      .LLbit_i(LLbit_LLbit_value),
      .wb_LLbit_we_i(wb_LLbit_we),
      .wb_LLbit_value_i(wb_LLbit_value),

      // 送到 MEM/WB 模块的信息
      .wd_o(mem_wd_o),    .wreg_o(mem_wreg_o),
      .wdata_o(mem_wdata_o),

      .whilo_o(mem_whilo_o),
      .hi_o(mem_hi_o), .lo_o(mem_lo_o),

      .LLbit_we_o(mem_LLbit_we_o),
      .LLbit_value_o(mem_LLbit_value_o),

      // 来自数据存储器的信息
      .mem_data_i(ram_data_i),

      // 送到数据存储器的信息
      .mem_addr_o(ram_addr_o),
      .mem_we_o(ram_we_o),
      .mem_sel_o(ram_sel_o),
      .mem_data_o(ram_data_o),
      .mem_ce_o(ram_ce_o),
      .mem_re_o(ram_re_o),

      // cp0
      .cp0_reg_we_i(mem_cp0_reg_we_i),
      .cp0_reg_write_addr_i(mem_cp0_reg_write_addr_i),
      .cp0_reg_data_i(mem_cp0_reg_data_i),


      .cp0_reg_we_o(mem_cp0_reg_we_o),
      .cp0_reg_write_addr_o(mem_cp0_reg_write_addr_o),
      .cp0_reg_data_o(mem_cp0_reg_data_o),

      .excepttype_i(mem_excepttype_i),
      .current_inst_address_i(mem_current_inst_addr_i),
      .is_in_delayslot_i(mem_is_in_delayslot_i),

      // TODO
      .cp0_status_i(cp0_status_o),
      .cp0_cause_i(cp0_cause_o),
      .cp0_epc_i(cp0_epc_o),
      .wb_cp0_reg_we(cp0_we_i),
      .wb_cp0_reg_write_addr(cp0_waddr_i),
      .wb_cp0_reg_data(cp0_data_i),

      .cp0_epc_o(ctrl_cp0_epc),
      .excepttype_o(excepttype),
      .is_in_delayslot_o(mem_is_in_delayslot_o),
      .current_inst_address_o(mem_current_inst_addr_o)
    );

// MEM/WB 实例化
mem_wb mem_wb0(
         .clk(clk), .rst(rst), .flush(flush),

         // 来自访存阶段 MEM 模块的信息
         .mem_wd(mem_wd_o), .mem_wreg(mem_wreg_o),
         .mem_wdata(mem_wdata_o),

         .mem_whilo(mem_whilo_o),
         .mem_hi(mem_hi_o), .mem_lo(mem_lo_o),

         .mem_LLbit_value(mem_LLbit_value_o),
         .mem_LLbit_we(mem_LLbit_we_o),


         // 送到回写阶段的信息
         .wb_wd(wb_wd_i), .wb_wreg(wb_wreg_i),
         .wb_wdata(wb_wdata_i),

         .wb_hi(hilo_hi_i),
         .wb_lo(hilo_lo_i),
         .wb_whilo(hilo_we_i),

         .wb_LLbit_we(wb_LLbit_we),
         .wb_LLbit_value(wb_LLbit_value),

         .stall(stall),

         // cp0
         .mem_cp0_reg_we(mem_cp0_reg_we_o),
         .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
         .mem_cp0_reg_data(mem_cp0_reg_data_o),

         .wb_cp0_reg_data(cp0_data_i),
         .wb_cp0_reg_we(cp0_we_i),
         .wb_cp0_reg_write_addr(cp0_waddr_i),

         .mem_current_address(mem_current_inst_addr_o),
         .wb_current_address(debug_wb_pc)
       );

hilo_reg hilo_reg0(
           .clk(clk), .rst(rst),

           .we(hilo_we_i), .hi_i(hilo_hi_i),
           .lo_i(hilo_lo_i),

           .hi_o(hilo_hi_o),
           .lo_o(hilo_lo_o)
         );

ctrl ctrl0(
       .rst(rst),
       .stall(stall),
       .stallreq_from_ex(stallreq_from_ex),
       .stallreq_from_id(stallreq_from_id),
       .stallreq_from_if(stallreq_from_if),
       .stallreq_from_mem(stallreq_from_mem),

       .cp0_epc_i(ctrl_cp0_epc),
       .excepttype_i(excepttype),
       .new_pc(new_pc),
       .flush(flush)
     );

div div0(
      .clk(clk),
      .rst(rst),

      .signed_div_i(ex_signed_div_o),
      .opdata1_i(ex_div_opdata1_o),
      .opdata2_i(ex_div_opdata2_o),
      .start_i(ex_div_start_o),
      .annul_i(1'b0),

      .result_o(ex_div_result_i),
      .ready_o(ex_div_ready_i)
    );

LLbit_reg LLbit_reg0(
            .clk(clk),
            .rst(rst),
            .flush(flush),
            .we(wb_LLbit_we),
            .LLbit_i(wb_LLbit_value),
            .LLbit_o(LLbit_LLbit_value)
          );

cp0_reg cp0_reg0(
          .clk(clk),
          .rst(rst),
          .int_i(int_i),
          .timer_int_o(timer_int_o),

          .data_i(cp0_data_i),
          .waddr_i(cp0_waddr_i),
          .we_i(cp0_we_i),

          .raddr_i(cp0_raddr_i),

          .data_o(cp0_data_o),
          .count_o(cp0_count_o),
          .compare_o(cp0_compare_o),
          .status_o(cp0_status_o),
          .cause_o(cp0_cause_o),
          .epc_o(cp0_epc_o),
          .config_o(cp0_config_o),
          .prid_o(cp0_prid_o),

          .excepttype_i(excepttype),
          .current_inst_addr_i(mem_current_inst_addr_o),
          .is_in_delayslot_i(mem_is_in_delayslot_o)
        );

endmodule // openmips
