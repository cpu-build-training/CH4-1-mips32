`include "defines.v"

module cp0_reg_new(
    input 	wire       		clk,
    input	wire            rst,

	// direct CP0 RW
    input	wire[4:0]       raddr_i,
    input   wire[2:0]       rsel_i,
    output	reg[`RegBus]    rdata_o,
    input 	wire       		we_i,
    input	wire[4:0]       waddr_i,
    input   wire[2:0]       wsel_i,
    input	wire[`RegBus]   wdata_i,

	// exception
    input	wire[31:0]      excepttype_i,
    input	wire[`RegBus]   current_inst_addr_i,
    input 	wire       	    is_in_delayslot_i,
    input	wire[`RegBus]   badvaddr_i,
    input	wire[5:0]       int_i,
	output	wire			timer_int_o,

	// MMU
	input 	wire[`AluOpBus] aluop_i,

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
    output	reg[`RegBus]    config0_o,  // addr = 16, sel = 0
    output	reg[`RegBus]    prid_o,

    // TLB related
    output	reg[`RegBus]    index_o,    // addr = 0
    output	reg[`RegBus]    random_o,   // addr = 1
    output	reg[`RegBus]    entryLo0_o, // addr = 2
    output	reg[`RegBus]    entryLo1_o, // addr = 3
    output	reg[`RegBus]    context_o,  // addr = 4
    output	reg[`RegBus]    pageMask_o, // addr = 5
    output  reg[`RegBus]    wired_o,    // addr = 6
    output	reg[`RegBus]    entryHi_o,  // addr = 10
    output  reg[`RegBus]    config1_o   // addr = 16, sel = 1
);
	// with tlb
	wire[89:0]	r_resp;     // TLB匹配到的表项
	wire		w_valid;    // 向TLB写入的表项有效(其实就是wen,要写入的内容由CP0中寄存器中的值拼接得到)
	wire[4:0]	w_index;    // TLBWI中指定的被写表项的下标
	wire[4:0]	p_index;    // 
	wire		p_miss;

    // 是否是TLB相关的异常
    wire is_tlb_exception = (excepttype_i == `TLBRL_CODE_FINAL || excepttype_i == `TLBRL_DATA_FINAL || excepttype_i == `TLBRS_FINAL ||
                             excepttype_i == `TLBIL_DATA_FINAL || excepttype_i == `TLBIL_DATA_FINAL || excepttype_i == `TLBIS_FINAL ||
                             excepttype_i == `TLBM_FINAL);

    assign timer_int_o = (compare_o != `ZeroWord && count_o == compare_o) ? `InterruptAssert : `InterruptNotAssert;

    // 当前是否有异常
    wire has_exception = (excepttype_i != `NOEXC_FINAL);
    // 当前是否正在异常处理程序中
    wire is_handling_exception = status_o[1];
    // 最终写到cp0寄存器中的值
    wire[31:0]  commit_epc      = (is_in_delayslot_i ? (current_inst_addr_i - 4) : current_inst_addr_i);
    wire        commit_bd       = is_in_delayslot_i;  // cause.bd
    wire[4:0]   commit_exccode  = excepttype_i == `INTERRUPT_FINAL   ? `EXCCODE_INT      :
                                  excepttype_i == `SYSCALL_FINAL     ? `EXCCODE_SYSCALL  :
                                  excepttype_i == `BREAK_FINAL       ? `EXCCODE_BR       :
                                  excepttype_i == `INSTINVALID_FINAL ? `EXCCODE_INSTINV  :
                                  excepttype_i == `TRAP_FINAL        ? `EXCCODE_TR       :
                                  excepttype_i == `OVERFLOW_FINAL    ? `EXCCODE_OV       :
                                  excepttype_i == `ADEL_FINAL        ? `EXCCODE_ADEL     :
                                  excepttype_i == `ADES_FINAL        ? `EXCCODE_ADES     :
                                  excepttype_i == `TLBRL_CODE_FINAL  ? `EXCCODE_TLBL     :
                                  excepttype_i == `TLBRL_DATA_FINAL  ? `EXCCODE_TLBL     :
                                  excepttype_i == `TLBRS_FINAL       ? `EXCCODE_TLBS     :
                                  excepttype_i == `TLBIL_CODE_FINAL  ? `EXCCODE_TLBL     :
                                  excepttype_i == `TLBIL_DATA_FINAL  ? `EXCCODE_TLBL     :
                                  excepttype_i == `TLBIS_FINAL       ? `EXCCODE_TLBS     :
                                  excepttype_i == `TLBM_FINAL        ? `EXCCODE_TLBM     : cause_o[6:2];
    // 对于ADEL/ADES,mem会判断到底是取指造成的还是访存造成的,然后给出badvaddr(pc/mem_addr)
    // mem只要发现指令地址是对齐的就会把badvaddr设成访存地址(不管访存地址是否真的有问题)
    // 对于TLBI与TLBR则需要在这里区分是取指还是访存,然后选择badvaddr或cur_inst_addr
    wire[31:0]  commit_badvaddr = (excepttype_i == `ADEL_FINAL || excepttype_i == `ADES_FINAL ||
                                   excepttype_i == `TLBIL_DATA_FINAL || excepttype_i == `TLBRL_DATA_FINAL ||
                                   excepttype_i == `TLBM_FINAL) ? badvaddr_i :
                                  (excepttype_i == `TLBIL_CODE_FINAL || excepttype_i == `TLBRL_CODE_FINAL) ? current_inst_addr_i : 32'b0;


    // WRITE
    // count
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            count_o <= `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_COUNT) begin
            count_o <= wdata_i;
        end else begin
            count_o <= count_o + 1;
        end
    end
    // compare
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            compare_o <= `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_COMPARE) begin
            compare_o <= wdata_i;
        end
    end
    // badvaddr
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            badvaddr_o <= `ZeroWord;
        end else if(has_exception && excepttype_i != `ERET_FINAL) begin
            badvaddr_o <= commit_badvaddr;
        end
    end
    // epc
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            epc_o <= `ZeroWord;
        end else if(has_exception && excepttype_i != `ERET_FINAL && !is_handling_exception) begin
            epc_o <= commit_epc;
        end else if(we_i && waddr_i == `CP0_REG_EPC) begin
            epc_o <= wdata_i;
        end
    end
    // status
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            // Status CU == 4'b0001
			status_o <= 32'b00010000_00000000_00000000_00000000;
        end else if(has_exception) begin
            // 如果eret则之后不再在异常处理程序中,否则就在
            // 如果在的话就要置1
            status_o[1]  <= (excepttype_i != `ERET_FINAL);
        end else if(we_i && waddr_i == `CP0_REG_STATUS) begin
            status_o <= wdata_i;
        end
    end
    // cause
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            cause_o <= `ZeroWord;
        end else begin
            cause_o[15:10] <= int_i;
            if(has_exception && excepttype_i != `ERET_FINAL && !is_handling_exception) begin
                cause_o[31]  <= commit_bd;
                cause_o[6:2] <= commit_exccode;
            end else if(we_i && waddr_i == `CP0_REG_CAUSE) begin
                // Cause 寄存器只有 IP[1:0], IV, WP 字段是可写的
                cause_o[9:8] <= wdata_i[9:8];
                cause_o[23] <= wdata_i[23];
                cause_o[22] <= wdata_i[22];
            end
        end
    end
    // prid
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            prid_o <= 32'b00000000_01001100_00000001_00000010;
        end
    end
    // config0
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            // Config BE == 1
			config0_o <= 32'b00000000_00000000_10000000_00000000;
        end else if(we_i && waddr_i == `CP0_REG_CONFIG && wsel_i == 0) begin
            config0_o[2:0] <= wdata_i[2:0];
        end
    end
    // config1
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            config1_o   <= {1'b0, // M
                            6'b011111, // MMUSize - 1
                            3'b001, // IS
                            3'b100, // IL
                            3'b001, // IA
                            3'b001, // DS
                            3'b100, // DL
                            3'b001, // DA
                            7'b0000000 // C2 MD PC WR CA EP FP
                            };
        end
    end
	// tlb related cp0 regs
    // index
	always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			index_o <=  `ZeroWord;
		end else if(we_i && waddr_i == `CP0_REG_INDEX) begin
			index_o[4:0] <= wdata_i[4:0];
		end else if(aluop_i == `EXE_TLBP_OP) begin
            index_o[31]  <= p_miss;
            index_o[4:0] <= p_index;
        end
	end
    // random
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            random_o <=  `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_WIRED) begin
            random_o <= {27'b0, 5'b11111};
        end else begin
            random_o[4:0] <= random_o[4:0] + 1;
        end
    end
    // entryLo0
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            entryLo0_o <=  `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_ENTRYLO0) begin
            entryLo0_o[25:0] <= wdata_i[25:0];
        end else if(aluop_i == `EXE_TLBR_OP) begin
            entryLo0_o[25:1] <= r_resp[49:25];
            entryLo0_o[0]    <= r_resp[`G];
        end
    end
    // entryLo1
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            entryLo1_o <=  `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_ENTRYLO1) begin
            entryLo1_o[25:0] <= wdata_i[25:0];
        end else if(aluop_i == `EXE_TLBR_OP) begin
            entryLo1_o[25:1] <= r_resp[24:0];
            entryLo1_o[0]    <= r_resp[`G];
        end
    end
    // context
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            context_o <=  `ZeroWord;
        end else if(is_tlb_exception) begin
            // BadVPN2
            context_o[22:4]  <= commit_badvaddr[31:13];
        end else if(we_i && waddr_i == `CP0_REG_CONTEXT) begin
            // PTEBase
            context_o[31:23] <= wdata_i[31:23];
        end
    end
    // pagemask
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            pageMask_o <=  `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_PAGEMASK) begin
            pageMask_o[24:13] <= wdata_i[24:13];
        end else if(aluop_i == `EXE_TLBR) begin
            pageMask_o[24:13] <= r_resp[`PAGEMASK];
        end
    end
    // wired
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            wired_o <=  `ZeroWord;
        end else if(we_i && waddr_i == `CP0_REG_WIRED) begin
            // wired
            wired_o[4:0] <= wdata_i[4:0];
        end
    end
    // entryHi
    always @ (posedge clk) begin
        if(rst == `RstEnable) begin
            entryHi_o <=  `ZeroWord;
        end else if(is_tlb_exception) begin
            entryHi_o[31:13] <= badvaddr_i[31:13];
        end else if(we_i && waddr_i == `CP0_REG_ENTRYHI) begin
            entryHi_o[31:13] <= wdata_i[31:13];
            entryHi_o[7:0]   <= wdata_i[7:0];
        end else if(aluop_i == `EXE_TLBR_OP) begin
            entryHi_o[31:13] <= r_resp[`VPN2];
            entryHi_o[7:0]   <= r_resp[`ASID];
        end
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
					rdata_o = ((rsel_i == 0) ? config0_o : config1_o);
				end
				`CP0_REG_BADVADDR: begin
					rdata_o = badvaddr_o;
				end
                // TLB related
                `CP0_REG_INDEX: begin
                    if(aluop_i == `EXE_TLBP_OP)
                        rdata_o = {p_miss, index_o[30:5], p_index};
                    else
                        rdata_o = index_o;
                end
                `CP0_REG_RANDOM: begin
                    rdata_o = random_o;
                end
                `CP0_REG_ENTRYLO0: begin
                    if(aluop_i == `EXE_TLBR_OP)
                        rdata_o = {entryLo0_o[31:26], r_resp[49:25], r_resp[`G]};
                    else
                        rdata_o = entryLo0_o;
                end
                `CP0_REG_ENTRYLO1: begin
                    if(aluop_i == `EXE_TLBR_OP) 
                        rdata_o = {entryLo1_o[31:26], r_resp[24:0], r_resp[`G]};
                    else
                        rdata_o = entryLo1_o;
                end
                `CP0_REG_PAGEMASK: begin
                    if(aluop_i == `EXE_TLBR_OP)
                        rdata_o = {pageMask_o[31:25], r_resp[`PAGEMASK], pageMask_o[12:0]};
                    else
                        rdata_o = pageMask_o;
                end
                `CP0_REG_ENTRYHI: begin
                    if(aluop_i == `EXE_TLBR_OP)
                        rdata_o = {r_resp[`VPN2], entryHi_o[12:8], r_resp[`ASID]};
                    else
                        rdata_o = entryHi_o;
                end
                `CP0_REG_CONTEXT: begin
                    if(is_tlb_exception)
                        rdata_o = {context_o[31:23], commit_badvaddr[31:13], 4'b0};
                    else
                        rdata_o = context_o;
                end
                `CP0_REG_WIRED: begin
                    rdata_o = wired_o;
                end
				default: begin
					rdata_o = `ZeroWord;
				end
			endcase
		end
	end

    assign w_valid = (!has_exception && !is_handling_exception && (aluop_i == `EXE_TLBWI_OP || aluop_i == `EXE_TLBWR_OP));
    wire[31:0] random_idx = random_o + wired_o;
    assign w_index = aluop_i == `EXE_TLBWR_OP ? random_idx[4:0] : index_o[4:0];

	tlb tlb_0(
       .clk(clk),
       .rst(rst),
        
       .r_index(index_o[4:0]),
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
    );
endmodule // cp0_reg
