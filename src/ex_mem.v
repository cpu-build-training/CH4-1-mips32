// 将执行阶段取得的运算结果，在下一个时钟周期传递到流水线访村阶段
`include "defines.v"
module ex_mem(
           input wire clk, wire rst,
           // 来自执行阶段的信息
           input
           wire[`RegAddrBus] ex_wd,
           wire                ex_wreg,
           wire[`RegBus]       ex_wdata,

           wire ex_whilo,
           wire[`RegBus]    ex_hi,
           wire[`RegBus]    ex_lo,

            wire[`DoubleRegBus] hilo_i,
            wire[1:0]       cnt_i,

            // 为实现加载、存储指令而添加的输入
            wire[`AluOpBus] ex_aluop,
            // 
            wire[`RegBus]   ex_mem_addr,
            // 要存储的数据或者原始值
            wire[`RegBus]   ex_reg2,

            // cp0
            wire            ex_cp0_reg_we,
            wire[4:0]            ex_cp0_reg_write_addr,
            wire[`RegBus]   ex_cp0_reg_data,

            // CTRL
            wire            flush,
            wire[31:0]      ex_excepttype,
            wire            ex_is_in_delayslot,
            wire[`RegBus]   ex_current_inst_address,

           // 送到访存阶段的信息
           output
           reg[`RegAddrBus]        mem_wd,
           reg                     mem_wreg,
           reg[`RegBus]            mem_wdata,

           reg[`RegBus]         mem_hi,
           reg[`RegBus]         mem_lo,
           reg mem_whilo,
           reg[`DoubleRegBus]   hilo_o,
           reg[1:0]             cnt_o,

           // STORE / LOAD
            reg[`AluOpBus]      mem_aluop,
            reg[`RegBus]        mem_mem_addr,
            reg[`RegBus]        mem_reg2,

            // cp0
            reg             mem_cp0_reg_we,
            reg[4:0]        mem_cp0_reg_write_addr,
            reg[`RegBus]    mem_cp0_reg_data,

            reg[31:0]       mem_excepttype,
            reg             mem_is_in_delayslot,
            reg[`RegBus]    mem_current_inst_address,

           // From CTRL module.
           input wire[5:0]     stall
       );

always @(posedge clk) begin
    if(rst == `RstEnable) begin
        mem_wd <= `NOPRegAddr;
        mem_wreg<= `WriteDisable;
        mem_wdata <= `ZeroWord;
        mem_hi <= `ZeroWord;
        mem_lo <= `ZeroWord;
        mem_whilo <= `WriteDisable;
        hilo_o <= {`ZeroWord, `ZeroWord};
        cnt_o <= 2'b00;
        mem_aluop <= `EXE_NOP_OP;
        mem_mem_addr <= `ZeroWord;
        mem_reg2 <= `ZeroWord;
        mem_cp0_reg_we <= `WriteDisable;
        mem_cp0_reg_write_addr <= 5'b00000;
        mem_cp0_reg_data <= `ZeroWord;
        mem_excepttype <= `ZeroWord;
        mem_is_in_delayslot <= `NotInDelaySlot;
        mem_current_inst_address <= `ZeroWord;
    end
    else if(flush == 1'b1) begin
        // same as above?
        mem_wd <= `NOPRegAddr;
        mem_wreg<= `WriteDisable;
        mem_wdata <= `ZeroWord;
        mem_hi <= `ZeroWord;
        mem_lo <= `ZeroWord;
        mem_whilo <= `WriteDisable;
        hilo_o <= {`ZeroWord, `ZeroWord};
        cnt_o <= 2'b00;
        mem_aluop <= `EXE_NOP_OP;
        mem_mem_addr <= `ZeroWord;
        mem_reg2 <= `ZeroWord;
        mem_cp0_reg_we <= `WriteDisable;
        mem_cp0_reg_write_addr <= 5'b00000;
        mem_cp0_reg_data <= `ZeroWord;
        mem_excepttype <= `ZeroWord;
        mem_is_in_delayslot <= `NotInDelaySlot;
        mem_current_inst_address <= `ZeroWord;
    end else if(stall[3] == `Stop && stall[4] == `NoStop) begin
        // 输出 NOP
        mem_wd <= `NOPRegAddr;
        mem_wreg<= `WriteDisable;
        mem_wdata <= `ZeroWord;
        mem_hi <= `ZeroWord;
        mem_lo <= `ZeroWord;
        mem_whilo <= `WriteDisable;
        hilo_o <= hilo_i;
        cnt_o <= cnt_i;
        mem_aluop <= `EXE_NOP_OP;
        mem_mem_addr <= `ZeroWord;
        mem_reg2 <= `ZeroWord;
        mem_cp0_reg_we <= `WriteDisable;
        mem_cp0_reg_write_addr <= 5'b00000;
        mem_cp0_reg_data <= `ZeroWord;
        mem_excepttype <= `ZeroWord;
        mem_is_in_delayslot <= `NotInDelaySlot;
        mem_current_inst_address <= `ZeroWord;
    end
    else if(stall[3] == `NoStop) begin
        // normal
        mem_wd <= ex_wd;
        mem_wreg<= ex_wreg;
        mem_wdata<=ex_wdata;
        mem_hi <= ex_hi;
        mem_lo <= ex_lo;
        mem_whilo <= ex_whilo;
        hilo_o <= {`ZeroWord, `ZeroWord};
        cnt_o <= 2'b00;
        mem_aluop <= ex_aluop;
        mem_mem_addr <= ex_mem_addr;
        mem_reg2 <= ex_reg2;
        mem_cp0_reg_we <= ex_cp0_reg_we;
        mem_cp0_reg_write_addr <= ex_cp0_reg_write_addr;
        mem_cp0_reg_data <= ex_cp0_reg_data;
        mem_excepttype <= ex_excepttype;
        mem_is_in_delayslot <= ex_is_in_delayslot;
        mem_current_inst_address <= ex_current_inst_address;
    end else begin
    // keep same
        hilo_o <= hilo_i;
        cnt_o <= cnt_i;
    end
end

endmodule // ex_mem
