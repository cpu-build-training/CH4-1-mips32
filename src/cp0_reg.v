`include "defines.v"

module cp0_reg(
    input 	wire       		clk,
    input	wire            rst,

	// direct CP0 RW
    input	wire[4:0]       raddr_i,
    output	reg[`RegBus]    rdata_o,
    input 	wire       		we_i,
    input	wire[4:0]       waddr_i,
    input	wire[`RegBus]   wdata_i,

	// exception
    input	wire[31:0]      excepttype_i,
    input	wire[`RegBus]   current_inst_addr_i,
    input 	wire       	    is_in_delayslot_i,
    input	wire[`RegBus]   badvaddr_i,
    input	wire[5:0]       int_i,
	output	reg				timer_int_o,

	// MMU
	input 	wire[`AluOpBus] aluop,

	input	wire[31:0]		inst_vaddr,
	output	wire[31:0]		inst_paddr,
	output	wire			inst_miss,
	output	wire			inst_invalid,
	output	wire			inst_cache,

	input	wire[31:0]		data_vaddr,
	input	wire			data_ren,
	input	wire			data_wen,
	output	wire[31:0]		data_paddr,
	output	wire			data_miss,
	output	wire			data_invalid,
	output	wire			data_modified,
	output 	wire			data_cache,

	// cp0 regs
    // !!!!! 现在没有sel的输入,默认sel为0
    // !!!!! 还没有实现config1寄存器(addr=16, sel=1)
    output	reg[`RegBus]    count_o,
    output	reg[`RegBus]    compare_o,
    output	reg[`RegBus]    status_o,
    output	reg[`RegBus]    cause_o,
    output	reg[`RegBus]    badvaddr_o,
    output	reg[`RegBus]    epc_o,
    output	reg[`RegBus]    config_o,
    output	reg[`RegBus]    prid_o,

    // TLB related
    output	reg[`RegBus]    index_o,    // addr = 0
    output	reg[`RegBus]    random_o,   // addr = 1
    output	reg[`RegBus]    entryLo0_o, // addr = 2
    output	reg[`RegBus]    entryLo1_o, // addr = 3
    output	reg[`RegBus]    context_o,  // addr = 4
    output	reg[`RegBus]    pageMask_o, // addr = 5
    output	reg[`RegBus]    entryHi_o   // addr = 10
);
	// with tlb
	wire[89:0]	r_resp;
	wire		w_valid;
	wire[4:0]	w_index;
	wire[4:0]	p_index;
	wire		p_miss;

	// 对寄存器的写操作
	always @(posedge clk) begin
		if(rst == `RstEnable) begin
			// Count Register
			count_o 		<= `ZeroWord;
			// Compare Register
			compare_o 		<= `ZeroWord;
			// Status CU == 4'b0001
			status_o 		<= 32'b00010000_00000000_00000000_00000000;
			// Cause Register
			cause_o 		<= `ZeroWord;
			// BadVAddr
			badvaddr_o 		<= `ZeroWord;
			// EPC Reg
			epc_o 			<= `ZeroWord;
			// Config BE == 1
			config_o 		<= 32'b00000000_00000000_10000000_00000000;
			prid_o 			<= 32'b00000000_01001100_00000001_00000010;
			timer_int_o 	<= `InterruptNotAssert;
		end else begin
			count_o 		<= count_o + 1;
			// 10 - 15 bit 保存外部中断声明
			cause_o[15:10] 	<= int_i;
			if(compare_o != `ZeroWord && count_o == compare_o) begin
			timer_int_o 	<= `InterruptAssert;
			end

			if(we_i == `WriteEnable) begin
				case (waddr_i)
					`CP0_REG_COUNT: begin
						count_o <= wdata_i;
					end
					`CP0_REG_COMPARE: begin
						compare_o <= wdata_i;
						timer_int_o <= `InterruptNotAssert;
					end
					`CP0_REG_STATUS: begin
						status_o <= wdata_i;
					end
					`CP0_REG_EPC: begin
						epc_o <= wdata_i;
					end
					`CP0_REG_CAUSE: begin
						// Cause 寄存器只有 IP[1:0], IV, WP 字段是可写的
						cause_o[9:8] <= wdata_i[9:8];
						cause_o[23] <= wdata_i[23];
						cause_o[22] <= wdata_i[22];
					end
					default: begin
						$display("WARNING: cp0_reg defult case!");
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
					end else begin
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
					if (status_o[1] == 1'b0)
					begin
						if(is_in_delayslot_i == `InDelaySlot)
						begin
							epc_o <= current_inst_addr_i - 4;
							// Cause 寄存器的 BD 字段
							cause_o[31] <= 1'b1;
						end else begin
							epc_o <= current_inst_addr_i;
							cause_o[31] <= 1'b0;
						end
					end                
					// Status.EXL
					status_o[1] <= 1'b1;
					// Cause.ExcCode
					cause_o[6:2] <= 5'b01000;
				end
				32'h0000_0009: begin
					// 断点异常 break
					if (status_o[1] == 1'b0) begin
						if(is_in_delayslot_i == `InDelaySlot) begin
							epc_o <= current_inst_addr_i - 4;
							// Cause 寄存器的 BD 字段
							cause_o[31] <= 1'b1;
						end else begin
							epc_o <= current_inst_addr_i;
							cause_o[31] <= 1'b0;
						end
					end                
					// Status.EXL
					status_o[1] <= 1'b1;
					// Cause.ExcCode
					cause_o[6:2] <= 5'b01001;
				end
				32'h0000_000a: begin
					// 无效指令
					if (status_o[1] == 1'b0) begin
						if(is_in_delayslot_i == `InDelaySlot) begin
							epc_o <= current_inst_addr_i - 4;
							// Cause 寄存器的 BD 字段
							cause_o[31] <= 1'b1;
						end else begin
							epc_o <= current_inst_addr_i;
							cause_o[31] <= 1'b0;
						end
					end                
					// Status.EXL
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
						end else begin
							epc_o <= current_inst_addr_i;
							cause_o[31] <= 1'b0;
						end
					end
					// Status.EXL
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
						end else begin
							epc_o <= current_inst_addr_i;
							cause_o[31] <= 1'b0;
						end
					end
					// Status.EXL
					status_o[1] <= 1'b1;
					// Cause.ExcCode
					cause_o[6:2] <= 5'b01100;
				end
				`ADEL_FINAL: begin
					// AdEL  读取地址未对齐
					if(is_in_delayslot_i == `InDelaySlot) begin
						epc_o <= current_inst_addr_i - 4;
						// Cause 寄存器的 BD 字段
						cause_o[31] <= 1'b1;
					end else begin
						epc_o <= current_inst_addr_i;
						cause_o[31] <= 1'b0;
					end
					// Status.EXL
					status_o[1] <= 1'b1;
					// Cause.ExcCode
					cause_o[6:2] <= 5'b00100;
					badvaddr_o <= badvaddr_i;
				end
				`ADES_FINAL: begin
					// 外部中断
					if(is_in_delayslot_i == `InDelaySlot) begin
						epc_o <= current_inst_addr_i - 4;
						// Cause 寄存器的 BD 字段
						cause_o[31] <= 1'b1;
					end else begin
						epc_o <= current_inst_addr_i;
						cause_o[31] <= 1'b0;
					end
					// Status.EXL
					status_o[1] <= 1'b1;
					// Cause.ExcCode
					cause_o[6:2] <= 5'b00101;
					badvaddr_o <= badvaddr_i;
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

	// write tlb related cp0 regs
	always @ (posedge clk) begin
		if(rwt == `RstEnable) begin
			index_o <= 32'b0;
		end else if(WriteEnable && waddr_i == 5'd0) begin
			index_o[4:0] <= wdata_i[4:0];
		end else if
	end

	// 读操作
	always @(*) begin
		if(rst == `RstEnable) begin
			rdata_o= `ZeroWord;
		end else begin
			case (raddr_i)
				`CP0_REG_COUNT: begin
					rdata_o = count_o;
				end
				`CP0_REG_COMPARE: begin
					rdata_o = compare_o;
				end
				`CP0_REG_STATUS: begin
					rdata_o = status_o;
				end
				`CP0_REG_CAUSE: begin
					rdata_o = cause_o;
				end
				`CP0_REG_EPC: begin
					rdata_o = epc_o;
				end
				`CP0_REG_PRID: begin
					rdata_o = prid_o;
				end
				`CP0_REG_CONFIG: begin
					rdata_o = config_o;
				end
				`CP0_REG_BADVADDR: begin
					rdata_o = badvaddr_o;
				end
				default: begin
					rdata_o = `ZeroWord;
				end
			endcase
		end
	end

	tlb tlb_0(
       .clk(clk),
       .rst(rst),
        
       .r_index(cp0_index[4:0]),
       .r_resp(r_resp),
        
       .w_valid(w_valid),
       .w_index(w_index),
       .w_data({entryHi_o[31:13], entryHi_o[7:0], pageMask_o[24:13], entryLo0_o[0] & entryLo1_o[0], entryLo0_o[25:1], entryLo1_o[25:1]}),
        
       .p_vpn2(entryHi_o[31:13]),
       .p_asid(entryHi_o[7:0]),
       .p_index(p_index),
       .p_miss(p_miss),
        
       .qi_asid(entryHi_o[7:0]),
       .qi_vaddr(inst_vaddr),
       .qi_paddr(inst_paddr),
       .qi_miss(inst_miss),
       .qi_invalid(inst_invalid),
       .qi_cache(inst_cache),
        
       .qd_asid(entryHi_o[7:0]),
       .qd_vaddr(data_vaddr),
       .qd_ren(data_ren),
       .qd_wen(data_wen),
       .qd_paddr(data_paddr),
       .qd_miss(data_miss),
       .qd_invalid(data_invalid),
       .qd_modified(data_modified),
       .qd_cache(data_cache)
	)

endmodule // cp0_reg
