
`include "defines.v"
module cp0_reg(
    input wire clk,
    wire rst,

    input wire we_i,
    wire[4:0] waddr_i,
    wire[4:0] raddr_i,
    wire[`RegBus] data_i,

    wire[5:0]   int_i,

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
    end else begin
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
    end
end

// 读操作

always @(*) begin
    if(rst == `RstEnable) begin
        data_o<= `ZeroWord;
    end else begin
        case (raddr_i)
            `CP0_REG_COUNT:begin
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