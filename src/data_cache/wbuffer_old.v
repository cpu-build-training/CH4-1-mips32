`timescale 1ns / 1ps

module wbuffer(
    input clk,
    input rst,  // 高有效

    // to dcache
    // 写请求,与有效的wdata一起保持至收到wreq_recvd(包括wreq_recvd为高的这一个周期)
    input  wreq,
    // 成功接收wreq与wdata,维持一个周期
    output wreq_recvd,
    // 写完成, 仅在实际写入ram的那一个周期为高
    output wdone,
    // physical address of witten data to be buffered (32 - 5 = 27 bits)
    input  [26:0] wdata_paddr,
    // written data to be buffered
    input  [31:0] wdata_bank0,
    input  [31:0] wdata_bank1,
    input  [31:0] wdata_bank2,
    input  [31:0] wdata_bank3,
    input  [31:0] wdata_bank4,
    input  [31:0] wdata_bank5,
    input  [31:0] wdata_bank6,
    input  [31:0] wdata_bank7,
    // clear the buffer
    input         clear,
    output        clear_done,
    // buffer status
    output        empty,
    

    // to axi
    // aw
    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
    //aw
    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [7 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,
    //w
    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
    //b
    input  [3 :0] bid    ,
    input  [1 :0] bresp  ,
    input         bvalid ,
    output        bready
);

    reg [3:0] head_pointer;
    reg [3:0] tail_pointer;
    reg [4:0] cur_buffer_size;

    wire full  = (cur_buffer_size == 4'd16) ? 1'b1 : 1'b0;

    // 访问buffer使用的地址
    wire [3:0]  buffer_addr;

    // 总共有32个,每个27位   paddr_prefixes[buffer_addr]
    reg  [26:0] paddr_prefixes[31:0];

    // 记录一下是否有写请求,用于区分在缓冲区清空后是否要发出wdone
    // 如果是因为clear而清空缓冲区,则清空后不需要发wdone
    reg has_wreq;
    always @ (posedge clk) begin
        if(rst)
            has_wreq <= 1'b0;
        // 如果在写完成的同时收到了写请求,则会因为优先判断wreq而保持has_wreq为高
        else if(wreq)
            has_wreq <= 1'b1;
        else if(wdone)
            has_wreq <= 1'b0;
    end

    wire [31:0] rdata_bank0;
    wire [31:0] rdata_bank1;
    wire [31:0] rdata_bank2;
    wire [31:0] rdata_bank3;
    wire [31:0] rdata_bank4;
    wire [31:0] rdata_bank5;
    wire [31:0] rdata_bank6;
    wire [31:0] rdata_bank7;

    wbuffer_data_ram wbuffer_data_ram_0 (clk, buffer_addr, rdata_bank0, wreq, wdata_bank0);
    wbuffer_data_ram wbuffer_data_ram_1 (clk, buffer_addr, rdata_bank1, wreq, wdata_bank1);
    wbuffer_data_ram wbuffer_data_ram_2 (clk, buffer_addr, rdata_bank2, wreq, wdata_bank2);
    wbuffer_data_ram wbuffer_data_ram_3 (clk, buffer_addr, rdata_bank3, wreq, wdata_bank3);
    wbuffer_data_ram wbuffer_data_ram_4 (clk, buffer_addr, rdata_bank4, wreq, wdata_bank4);
    wbuffer_data_ram wbuffer_data_ram_5 (clk, buffer_addr, rdata_bank5, wreq, wdata_bank5);
    wbuffer_data_ram wbuffer_data_ram_6 (clk, buffer_addr, rdata_bank6, wreq, wdata_bank6);
    wbuffer_data_ram wbuffer_data_ram_7 (clk, buffer_addr, rdata_bank7, wreq, wdata_bank7);

    // 记录清空buffer,向内存中写数据时收到的bvalid数
    // 使用时先初始化为要写的数据行数,之后每收到一个bvalid就减1
    // 减到0时认为写入完成
    reg[3:0] bvalid_cnt;

    reg[2:0] work_state;
    parameter[2:0] state_idle_or_pushed               = 3'b000;  // 空闲状态,总是能够接受写请求
    parameter[2:0] state_pushed_to_buffer   = 3'b001;  // 之前请求写的数据已经写入buffer,如果此时buffer满了则清空buffer
    parameter[2:0] state_clearing_buffer    = 3'b010;

    always @ (posedge clk) begin
        if(rst) begin
            work_state   <= state_idle_or_pushed;
            head_pointer <= 4'd0;
            tail_pointer <= 4'd0;
            cur_buffer_size <= 4'd0;
            buffer_addr  <= 4'd0;
            generate
                genvar i;
                for(i = 0; i < 16; i++) begin
                    paddr_prefixes[i] <= 26'd0;
                end
            endgenerate
        end else begin
            case(work_state)
                state_idle_or_pushed: begin
                    if(wreq) begin
                        if(!full) begin
                            work_state <= state_pushed_to_buffer;
                            if(tail_pointer < 4'd15)
                                tail_pointer <= tail_pointer + 4'd1;
                            else
                                tail_pointer <= 4'd0;
                            cur_buffer_size <= cur_buffer_size + 4'd1;
                        end else begin
                            work_state <= state_clearing_buffer;
                        end
                    end
                end
                state_pushed_to_buffer: begin
                    if(full) begin
                        // 如果state_idle_or_pushed中写完后buffer满了
                        work_state <= state_clearing_buffer;
                    // 如果刚写完又来了一个请求
                    end else if(wreq) begin
                        work_state <= state_pushed_to_buffer;
                        if(tail_pointer < 4'd15)
                            tail_pointer <= tail_pointer + 4'd1;
                        else
                            tail_pointer <= 4'd0;
                        cur_buffer_size <= cur_buffer_size + 4'd1;
                    end else begin
                        work_state <= state_idle_or_pushed;
                    end
                end
            endcase
        end
    end

    // to wbuffer ram
    assign 

    // to AXI


    // to dcache
    assign wreq_recvd = ((work_state == state_idle_or_pushed || work_state == state_pushed_to_buffer) && wreq) ? 1'b1 : 1'b0;
    assign wdone  = (work_state == state_pushed_to_buffer) ? 1'b1 : 1'b0
    assign empty  = (cur_buffer_size == 4'd0)  ? 1'b0 : 1'b1;


endmodule