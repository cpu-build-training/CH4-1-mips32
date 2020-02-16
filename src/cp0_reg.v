
`include "defines.v"
module cp0_reg(
           input wire clk,
           wire rst,

           input wire we_i,
           wire[4:0] waddr_i,
           wire[4:0] raddr_i,
           wire[`RegBus] data_i,

           wire[5:0]   int_i,

           // 异常
           wire[31:0]  excepttype_i,
           wire[`RegBus]   current_inst_addr_i,
           wire        is_in_delayslot_i,

           output
           reg[`RegBus]    data_o,
           reg[`RegBus]    count_o,
           reg[`RegBus]    compare_o,
           reg[`RegBus]    status_o,
           reg[`RegBus]    cause_o,
           reg[`RegBus]    epc_o,
           reg[`RegBus]    config_o,
           reg[`RegBus]    prid_o,

           reg timer_int_o
       );

// 对寄存器的写操作

always @(posedge clk) begin
    if(rst == `RstEnable) begin

        // Count Register
        count_o <= `ZeroWord;

        // Compare Register
        compare_o <= `ZeroWord;

        // Status CU == 4'b0001
        status_o <= 32'b00010000_00000000_00000000_00000000;

        // Cause Register
        cause_o <= `ZeroWord;

        // EPC Reg
        epc_o <= `ZeroWord;

        // Config BE == 1
        config_o <= 32'b00000000_00000000_10000000_00000000;

        prid_o <= 32'b00000000_01001100_00000001_00000010;

        timer_int_o <= `InterruptNotAssert;
    end
    else begin
        count_o <= count_o + 1;
        // 10 - 15 bit 保存外部中断声明
        cause_o[15:10] <= int_i;

        if(compare_o != `ZeroWord && count_o == compare_o) begin
            timer_int_o <= `InterruptAssert;
        end

        if(we_i == `WriteEnable) begin
            case (waddr_i)
                `CP0_REG_COUNT: begin
                    count_o <= data_i;
                end
                `CP0_REG_COMPARE: begin
                    compare_o <= data_i;
                    timer_int_o <= `InterruptNotAssert;
                end
                `CP0_REG_STATUS: begin
                    status_o <= data_i;
                end
                `CP0_REG_EPC:   begin
                    epc_o <= data_i;
                end
                `CP0_REG_CAUSE: begin
                    // Cause 寄存器只有 IP[1:0], IV, WP 字段是可写的
                    cause_o[9:8] <= data_i[9:8];
                    cause_o[23] <= data_i[23];
                    cause_o[22] <= data_i[22];
                end
            endcase


        end

        case (excepttype_i)
            32'h0000_0001: begin
            // 外部中断
                if(is_in_delayslot_i == `InDelaySlot) begin
                    epc_o <= current_inst_addr_i - 4;
                    // Cause 寄存器的 BD 字段
                    cause_o[31] <= 1'b1;
                end
                else begin
                    epc_o <= current_inst_addr_i;
                    cause_o[31] <= 1'b0;
                end
                // Status.EXL
                status_o[1] <= 1'b1;
                // Cause.ExcCode
                cause_o[6:2] <= 5'b00000;
            end
            32'h0000_0008: begin
            // 系统调用异常 syscall
                if (status_o[1] == 1'b0) begin
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        // Cause 寄存器的 BD 字段
                        cause_o[31] <= 1'b1;
                    end
                    else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end

                end                // Status.EXL
                status_o[1] <= 1'b1;
                // Cause.ExcCode
                cause_o[6:2] <= 5'b01000;
            end
            32'h0000_000a: begin
            // 无效指令
                if (status_o[1] == 1'b0) begin
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        // Cause 寄存器的 BD 字段
                        cause_o[31] <= 1'b1;
                    end
                    else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end

                end                // Status.EXL
                status_o[1] <= 1'b1;
                // Cause.ExcCode
                cause_o[6:2] <= 5'b01010;
            end
            32'h0000_000d: begin
            // 自陷异常
                if (status_o[1] == 1'b0) begin
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        // Cause 寄存器的 BD 字段
                        cause_o[31] <= 1'b1;
                    end
                    else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end

                end                // Status.EXL
                status_o[1] <= 1'b1;
                // Cause.ExcCode
                cause_o[6:2] <= 5'b01101;
            end
            32'h0000_000c: begin
            // 溢出异常
                if (status_o[1] == 1'b0) begin
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        // Cause 寄存器的 BD 字段
                        cause_o[31] <= 1'b1;
                    end
                    else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end

                end                // Status.EXL
                status_o[1] <= 1'b1;
                // Cause.ExcCode
                cause_o[6:2] <= 5'b01100;
            end
            32'h0000_000e: begin
            // 异常返回指令 eret
                status_o[1] <= 1'b0;
            end
            default: begin

            end
        endcase
    end
end

// 读操作

always @(*) begin
    if(rst == `RstEnable) begin
        data_o<= `ZeroWord;
    end
    else begin
        case (raddr_i)
            `CP0_REG_COUNT: begin
                data_o <= count_o;
            end
            `CP0_REG_COMPARE: begin
                data_o <= compare_o;
            end
            `CP0_REG_STATUS: begin
                data_o <= status_o;
            end
            `CP0_REG_CAUSE: begin
                data_o <= cause_o;
            end
            `CP0_REG_EPC: begin
                data_o <= epc_o;
            end
            `CP0_REG_PRID: begin
                data_o <= prid_o;
            end
            `CP0_REG_CONFIG: begin
                data_o <= config_o;
            end
            default: begin
            end
        endcase
    end
end

endmodule // cp0_reg
