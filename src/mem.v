// 访存阶段
`include "defines.v"

module mem(
           input wire rst,
           // 来自执行阶段的信息
           input
           wire[`RegAddrBus]       wd_i,
           wire                    wreg_i,
           wire[`RegBus]           wdata_i,


           wire whilo_i,
           wire[`RegBus]    hi_i,
           wire[`RegBus]    lo_i,

           // 来自执行阶段的信息
           wire[`AluOpBus]  aluop_i,
           wire[`RegBus]    mem_addr_i,
           wire[`RegBus]    reg2_i,

           // 来自外部数据存储器 RAM 的信息
           wire[`RegBus]   mem_data_i,

           // 新增的输入接口
           wire             LLbit_i,
           wire             wb_LLbit_we_i,
           wire             wb_LLbit_value_i,

           // cp0
           wire             cp0_reg_we_i,
           wire[4:0]        cp0_reg_write_addr_i,
           wire[`RegBus]    cp0_reg_data_i,


           // 访存阶段的结果
           output
           reg[`RegAddrBus]        wd_o,
           reg                     wreg_o,
           reg[`RegBus]            wdata_o,

           reg[`RegBus]         hi_o,
           reg[`RegBus]         lo_o,
           reg whilo_o,
           // 送到外部数据存储器 RAM 的信息
           reg[`RegBus]         mem_addr_o,
           wire                 mem_we_o,
           reg[3:0]             mem_sel_o,
           reg[`RegBus]         mem_data_o,
           reg                  mem_ce_o,

           // 新增的输出接口
           reg                  LLbit_we_o,
           reg                  LLbit_value_o,

            // cp0
           output reg           cp0_reg_we_o,
           output reg[4:0]      cp0_reg_write_addr_o,
           output reg[`RegBus]  cp0_reg_data_o
       );
wire[`RegBus]   zero32;
reg             mem_we;

// 保存 LLbit 寄存器的最新值
reg LLbit;

// 外部数据存储器 RAM 的读写信号
assign mem_we_o = mem_we;
assign zero32 = `ZeroWord;


// 获取 LLbit 寄存器的最新之， 如果回写阶段的指令要写 LLbit，那么回写阶段要写入的
// 值就是 LLbit 寄存器的最新值，反之， LLbit 模块给出的值 LLbit_i 是最新值
always @(*) begin
    if(rst == `RstEnable) begin
        LLbit <= 1'b0;
    end
    else begin
        if (wb_LLbit_we_i == 1'b1) begin
            // 回写阶段指令要写 LLbit
            LLbit <= wb_LLbit_value_i;
        end
        else begin
            LLbit <= LLbit_i;
        end
    end
end


// 目前是组合逻辑电路

always @(*) begin
    if(rst==`RstEnable) begin
        wd_o <= `NOPRegAddr;
        wreg_o <= `WriteDisable;
        wdata_o <= `ZeroWord;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        whilo_o <= `WriteDisable;
        mem_addr_o <= `ZeroWord;
        mem_we <= `WriteDisable;
        mem_sel_o <= 4'b0000;
        mem_data_o <= `ZeroWord;
        mem_ce_o <= `ChipDisable;
        LLbit_we_o <= `WriteDisable;
        LLbit_value_o <= 1'b0;
        cp0_reg_we_o <= `WriteDisable;
        cp0_reg_write_addr_o <= 5'b00000;
        cp0_reg_data_o <= `ZeroWord;
    end
    else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        wdata_o <= wdata_i;
        hi_o <= hi_i;
        lo_o <= lo_i;
        whilo_o <= whilo_i;
        mem_addr_o <= `ZeroWord;
        mem_we <= `WriteDisable;
        mem_sel_o <= 4'b1111;
        mem_ce_o <= `ChipDisable;
        LLbit_we_o <= `WriteDisable;
        LLbit_value_o <= 1'b0;
        cp0_reg_we_o <= cp0_reg_we_i;
        cp0_reg_write_addr_o <= cp0_reg_write_addr_i;
        cp0_reg_data_o <= cp0_reg_data_i;
        case (aluop_i)
            `EXE_LB_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteDisable;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o<= {{24{mem_data_i[31]}}, mem_data_i[31:24]};
                        mem_sel_o <= 4'b1000;
                    end
                    2'b01: begin
                        wdata_o<= {{24{mem_data_i[23]}}, mem_data_i[23:16]};
                        mem_sel_o <= 4'b0100;
                    end
                    2'b10: begin
                        wdata_o<= {{24{mem_data_i[15]}}, mem_data_i[15:8]};
                        mem_sel_o <= 4'b0010;
                    end
                    2'b11: begin
                        wdata_o<= {{24{mem_data_i[7]}}, mem_data_i[7:0]};
                        mem_sel_o <= 4'b0001;
                    end
                    default: begin
                        wdata_o <= `ZeroWord;
                    end
                endcase
            end
            `EXE_LBU_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteDisable;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o<= {{24{1'b0}}, mem_data_i[31:24]};
                        mem_sel_o <= 4'b1000;
                    end
                    2'b01: begin
                        wdata_o<= {{24{1'b0}}, mem_data_i[23:16]};
                        mem_sel_o <= 4'b0100;
                    end
                    2'b10: begin
                        wdata_o<= {{24{1'b0}}, mem_data_i[15:8]};
                        mem_sel_o <= 4'b0010;
                    end
                    2'b11: begin
                        wdata_o<= {{24{1'b0}}, mem_data_i[7:0]};
                        mem_sel_o <= 4'b0001;
                    end
                    default: begin
                        wdata_o <= `ZeroWord;
                    end
                endcase
            end
            `EXE_LH_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteDisable;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o<= {{16{mem_data_i[31]}}, mem_data_i[31:16]};
                        mem_sel_o <= 4'b1100;
                    end
                    2'b10: begin
                        wdata_o<= {{16{mem_data_i[15]}}, mem_data_i[15:0]};
                        mem_sel_o <= 4'b0011;
                    end
                    default: begin
                        wdata_o <= `ZeroWord;
                    end
                endcase
            end
            `EXE_LHU_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteDisable;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o<= {{16{1'b0}}, mem_data_i[31:16]};
                        mem_sel_o <= 4'b1100;
                    end
                    2'b10: begin
                        wdata_o<= {{16{1'b0}}, mem_data_i[15:0]};
                        mem_sel_o <= 4'b0011;
                    end
                    default: begin
                        wdata_o <= `ZeroWord;
                    end
                endcase
            end
            `EXE_LW_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we     <= `WriteDisable;
                wdata_o    <= mem_data_i;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= `ChipEnable;
            end
            `EXE_LWL_OP: begin
                mem_addr_o <= {mem_addr_i[31:2], 2'b00};
                mem_we     <= `WriteDisable;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o <= mem_data_i[31:0];
                    end
                    2'b01: begin
                        wdata_o <= {mem_data_i[23:0], reg2_i[7:0]};
                    end
                    2'b10: begin
                        wdata_o <= {mem_data_i[15:0], reg2_i[15:0]};
                    end
                    2'b11: begin
                        wdata_o <= {mem_data_i[7:0], reg2_i[23:0]};
                    end
                    default: begin
                        wdata_o <= `ZeroWord;
                    end
                endcase
            end
            `EXE_LWR_OP: begin
                mem_addr_o <= {mem_addr_i[31:2], 2'b00};
                mem_we     <= `WriteDisable;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        wdata_o <= {reg2_i[31:8], mem_data_i[31:24]};
                    end
                    2'b01: begin
                        wdata_o <= {reg2_i[31:16], mem_data_i[31:16] };
                    end
                    2'b10: begin
                        wdata_o <= {reg2_i[31:24], mem_data_i[31:8] };
                    end
                    2'b11: begin
                        wdata_o <= mem_data_i;
                    end
                    default: begin
                        wdata_o <= `ZeroWord;
                    end
                endcase
            end
            `EXE_SB_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteEnable;
                mem_data_o <= {reg2_i[7:0], reg2_i[7:0], reg2_i[7:0],reg2_i[7:0]};
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        mem_sel_o <= 4'b1000;
                    end
                    2'b01: begin
                        mem_sel_o <= 4'b0100;
                    end
                    2'b10: begin
                        mem_sel_o <= 4'b0010;
                    end
                    2'b11: begin
                        mem_sel_o <= 4'b0001;
                    end
                    default: begin
                        mem_sel_o <= 4'b0000;
                    end
                endcase
            end
            `EXE_SH_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteEnable;
                mem_data_o <= {reg2_i[15:0], reg2_i[15:0]};
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        mem_sel_o <= 4'b1100;
                    end
                    2'b10: begin
                        mem_sel_o <= 4'b0011;
                    end
                    default: begin
                        mem_sel_o <= 4'b0000;
                    end
                endcase
            end
            `EXE_SW_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteEnable;
                mem_data_o <= reg2_i;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= `ChipEnable;
            end
            `EXE_SWL_OP: begin
                mem_addr_o <= {mem_addr_i[31:2], 2'b00};
                mem_we <= `WriteEnable;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        mem_sel_o <= 4'b1111;
                        mem_data_o <= reg2_i;
                    end
                    2'b01: begin
                        mem_sel_o <= 4'b0111;
                        mem_data_o <= {zero32[7:0], reg2_i[31:8]};
                    end
                    2'b10: begin
                        mem_sel_o <= 4'b0011;
                        mem_data_o <= {zero32[15:0], reg2_i[31:16]};
                    end
                    2'b11: begin
                        mem_sel_o <= 4'b0001;
                        mem_data_o <= {zero32[23:0], reg2_i[31:24]};
                    end
                    default: begin
                        mem_sel_o <= 4'b0000;
                    end
                endcase
            end
            `EXE_SWR_OP: begin
                mem_addr_o <= {mem_addr_i[31:2], 2'b00};
                mem_we <= `WriteEnable;
                mem_ce_o <= `ChipEnable;
                case (mem_addr_i[1:0])
                    2'b00: begin
                        mem_sel_o <= 4'b1000;
                        mem_data_o <= {reg2_i[7:0], zero32[23:0]};
                    end
                    2'b01: begin
                        mem_sel_o <= 4'b1100;
                        mem_data_o <= {reg2_i[15:0], zero32[15:0]};
                    end
                    2'b10: begin
                        mem_sel_o <= 4'b1110;
                        mem_data_o <= {reg2_i[23:0], zero32[7:0]};
                    end
                    2'b11: begin
                        mem_sel_o <= 4'b1111;
                        mem_data_o <= reg2_i[31:0];
                    end
                    default: begin
                        mem_sel_o <= 4'b0000;
                    end
                endcase
            end
            `EXE_LL_OP: begin
                mem_addr_o <= mem_addr_i;
                mem_we <= `WriteDisable;
                wdata_o <= mem_data_i;
                LLbit_we_o <= `WriteEnable;
                LLbit_value_o <= 1'b1;
                mem_sel_o <= 4'b1111;
                mem_ce_o <= `ChipEnable;
            end
            `EXE_SC_OP: begin
                if(LLbit == 1'b1) begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteEnable;
                    mem_data_o <= reg2_i;
                    wdata_o <= 32'b1;
                    LLbit_we_o <= `WriteEnable;
                    LLbit_value_o <= 1'b0;
                    mem_sel_o <= 4'b1111;
                    mem_ce_o <= `ChipEnable;
                end
                else begin
                    wdata_o <= 32'b0;
                end
            end
            default:  begin
            end
        endcase
    end
end

endmodule // mem
