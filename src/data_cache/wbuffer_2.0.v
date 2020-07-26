`timescale 1ns / 1ps

module wbuffer(
    input clk,
    input rstn,  // 低有效

    // with dcache
    // 写请求,与有效的wdata一起保持至收到wreq_recvd(包括wreq_recvd为高的这一个周期)
    input  wreq,
    // 当前的写请求是否是uncached的,如果是则直接将dcache与axi的信号直接传递过去
    input  is_uncached,
    // 成功接收wreq与wdata,维持一个周期
    output wreq_recvd,
    // 写完成, 仅在实际写入ram的那一个周期为高
    output wdone,
    // physical address of witten data to be buffered (32 - 5 = 27 bits)
    input  [31:0] wdata_paddr,
    // written data to be buffered
    input  [31:0] wdata_bank0,
    input  [31:0] wdata_bank1,
    input  [31:0] wdata_bank2,
    input  [31:0] wdata_bank3,
    input  [31:0] wdata_bank4,
    input  [31:0] wdata_bank5,
    input  [31:0] wdata_bank6,
    input  [31:0] wdata_bank7,
    // buffer status
    output        empty,
    // clear the buffer
    input         clear,
    output        clear_done,

    // 请求查询某一行是否在wbuffer中
    input  lookup_req,
    input  [31:0] lookup_paddr,

    output lookup_res_hit,
    output [31:0] lookup_res_data_bank0,
    output [31:0] lookup_res_data_bank1,
    output [31:0] lookup_res_data_bank2,
    output [31:0] lookup_res_data_bank3,
    output [31:0] lookup_res_data_bank4,
    output [31:0] lookup_res_data_bank5,
    output [31:0] lookup_res_data_bank6,
    output [31:0] lookup_res_data_bank7,
    
    // dcache axi write (for uncached write)
    // aw
    input  [3 :0] dch_awid   ,
    input  [31:0] dch_awaddr ,
    input  [3 :0] dch_awlen  ,
    input  [2 :0] dch_awsize ,
    input  [1 :0] dch_awburst,
    input  [1 :0] dch_awlock ,
    input  [3 :0] dch_awcache,
    input  [2 :0] dch_awprot ,
    input         dch_awvalid,
    output        dch_awready,
    //w
    input  [3 :0] dch_wid    ,
    input  [31:0] dch_wdata  ,
    input  [3 :0] dch_wstrb  ,
    input         dch_wlast  ,
    input         dch_wvalid ,
    output        dch_wready ,
    //b
    output [3 :0] dch_bid    ,
    output [1 :0] dch_bresp  ,
    output        dch_bvalid ,
    input         dch_bready ,

    // with axi
    //aw
    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [3 :0] awlen  ,
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

    wire rst = ~rstn;

    reg [3:0] head_pointer;
    reg [3:0] tail_pointer;
    reg [4:0] cur_buffer_size;  // buffer中的总行数(无论行是否需要写回)
    reg [4:0] bvalid_cnt_init;  // buffer中需要写回内存的行数

    wire full  = (cur_buffer_size == 16) ? 1'b1 : 1'b0;

    // 读写buffer使用的地址
    wire [3:0]  buffer_addr;

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

    wire        wbuffer_ram_wen;
    wire [31:0] rdata_bank0;
    wire [31:0] rdata_bank1;
    wire [31:0] rdata_bank2;
    wire [31:0] rdata_bank3;
    wire [31:0] rdata_bank4;
    wire [31:0] rdata_bank5;
    wire [31:0] rdata_bank6;
    wire [31:0] rdata_bank7;

    wbuffer_data_ram wbuffer_data_ram_0 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank0), .wea(wbuffer_ram_wen), .dina(wdata_bank0));
    wbuffer_data_ram wbuffer_data_ram_1 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank1), .wea(wbuffer_ram_wen), .dina(wdata_bank1));
    wbuffer_data_ram wbuffer_data_ram_2 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank2), .wea(wbuffer_ram_wen), .dina(wdata_bank2));
    wbuffer_data_ram wbuffer_data_ram_3 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank3), .wea(wbuffer_ram_wen), .dina(wdata_bank3));
    wbuffer_data_ram wbuffer_data_ram_4 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank4), .wea(wbuffer_ram_wen), .dina(wdata_bank4));
    wbuffer_data_ram wbuffer_data_ram_5 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank5), .wea(wbuffer_ram_wen), .dina(wdata_bank5));
    wbuffer_data_ram wbuffer_data_ram_6 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank6), .wea(wbuffer_ram_wen), .dina(wdata_bank6));
    wbuffer_data_ram wbuffer_data_ram_7 (.clka(clk), .addra(buffer_addr), .douta(rdata_bank7), .wea(wbuffer_ram_wen), .dina(wdata_bank7));


    // 记录清空buffer,向内存中写数据时收到的bvalid数
    // 使用时先初始化为要写的数据行数,之后每收到一个bvalid就减1
    // 减到0时认为写入完成
    reg[3:0] bvalid_cnt;
    // 当前写的是这一行中的第几个字节
    reg[2:0] write_word_idx;

    reg[2:0] work_state;
    parameter[2:0] state_idle                     = 3'b000;  // 空闲状态
    parameter[2:0] state_write_to_buffer_done     = 3'b001;  // 之前请求写的数据已经写入buffer
    parameter[2:0] state_clear_buffer_init        = 3'b010;  // 开始清空缓存,主要是给bvalid_cnt赋值
    parameter[2:0] state_clear_buffer_addr_hshake = 3'b011;  // 写入一行前的地址握手
    parameter[2:0] state_clear_buffer_data_transf = 3'b100;  // burst传输一行数据,结束时会发出wlast
    parameter[2:0] state_clear_buffer_wait_bvalid = 3'b101;  // 保持该状态直到所有的bvalid都收到
    parameter[2:0] state_lookup_res               = 3'b110;

    // 总共有16个,每个27位   paddr_prefixes[buffer_addr]
    reg  [26:0] paddr_prefixes[15:0];
    // 记录wbuffer的每行是否有效
    // 已经被写回内存(这点由head, tail, size也可以确认) / 未被写回内存且被读出过 都认为是不need_wb的
    // 只有need_wb的行才需要在清空时写回内存
    // 当某行变为不need_wb的时候,bvalid_cnt_init会减1
    reg  [15:0] need_wb;

    assign lookup_res_data_bank0 = rdata_bank0;
    assign lookup_res_data_bank1 = rdata_bank1;
    assign lookup_res_data_bank2 = rdata_bank2;
    assign lookup_res_data_bank3 = rdata_bank3;
    assign lookup_res_data_bank4 = rdata_bank4;
    assign lookup_res_data_bank5 = rdata_bank5;
    assign lookup_res_data_bank6 = rdata_bank6;
    assign lookup_res_data_bank7 = rdata_bank7;

    // [4] 0: 未找到需要的行    1: 找到了需要的行
    // [3:0] 需要的行在wbuffer中的下标
    wire[4:0] lookup_res_hit_and_wbuffer_addr = 
                    (lookup_paddr[31:5] == paddr_prefixes[0] && need_wb[0])  ? 5'b10000 :
                    (lookup_paddr[31:5] == paddr_prefixes[1] && need_wb[1])  ? 5'b10001 :
                    (lookup_paddr[31:5] == paddr_prefixes[2] && need_wb[2])  ? 5'b10010 :
                    (lookup_paddr[31:5] == paddr_prefixes[3] && need_wb[3])  ? 5'b10011 :
                    (lookup_paddr[31:5] == paddr_prefixes[4] && need_wb[4])  ? 5'b10100 :
                    (lookup_paddr[31:5] == paddr_prefixes[5] && need_wb[5])  ? 5'b10101 :
                    (lookup_paddr[31:5] == paddr_prefixes[6] && need_wb[6])  ? 5'b10110 :
                    (lookup_paddr[31:5] == paddr_prefixes[7] && need_wb[7])  ? 5'b10111 :
                    (lookup_paddr[31:5] == paddr_prefixes[8] && need_wb[8])  ? 5'b11000 :
                    (lookup_paddr[31:5] == paddr_prefixes[9] && need_wb[9])  ? 5'b11001 :
                    (lookup_paddr[31:5] == paddr_prefixes[10] && need_wb[10]) ? 5'b11010 :
                    (lookup_paddr[31:5] == paddr_prefixes[11] && need_wb[11]) ? 5'b11011 :
                    (lookup_paddr[31:5] == paddr_prefixes[12] && need_wb[12]) ? 5'b11100 :
                    (lookup_paddr[31:5] == paddr_prefixes[13] && need_wb[13]) ? 5'b11101 :
                    (lookup_paddr[31:5] == paddr_prefixes[14] && need_wb[14]) ? 5'b11110 :
                    (lookup_paddr[31:5] == paddr_prefixes[15] && need_wb[15]) ? 5'b11111 : 5'b0000;
    assign lookup_res_hit = lookup_res_hit_and_wbuffer_addr[4];
    wire [3:0] lookup_res_wbuffer_addr = lookup_res_hit_and_wbuffer_addr[3:0];

    generate
        genvar i;
        for(i = 0; i < 16; i = i + 1) begin
            always @ (posedge clk) begin
                if(rst) begin
                    paddr_prefixes[i] <= 27'd0;
                    need_wb[i]        <= 1'b0;
                end
            end
        end
    endgenerate

    always @ (posedge clk) begin
        if(rst) begin
            work_state      <= state_idle;
            head_pointer    <= 0;
            tail_pointer    <= 0;
            cur_buffer_size <= 0;
            bvalid_cnt_init <= 0;
        end else begin
            case(work_state)
                state_idle: begin
                    // 这个状态下buffer中一定至少留有一个空闲位置
                    if(wreq) begin
                        work_state <= state_write_to_buffer_done;
                        if(tail_pointer < 15)
                            tail_pointer <= tail_pointer + 1;
                        else
                            tail_pointer <= 4;
                        
                        cur_buffer_size  <= cur_buffer_size + 1;
                        bvalid_cnt_init  <= bvalid_cnt_init + 1;
                        // 记录这一行的物理地址(仅使用高27位)
                        paddr_prefixes[tail_pointer] <= wdata_paddr[31:5];
                        need_wb[tail_pointer] <= 1'b1;
                    end else if(lookup_req) begin
                        // dcache发出req的同时会给出lookup_paddr,所以该状态下已经可以得到lookup_res
                        work_state <= state_lookup_res;
                    end else begin
                        work_state <= state_idle;
                    end
                end
                state_write_to_buffer_done: begin
                    // 如果state_idle中写完后buffer满了
                    if(full) begin
                        // 开始清空buffer
                        work_state <= state_clear_buffer_init;
                    end else begin
                        // 写入完毕,回到idle
                        work_state <= state_idle;
                    end
                end
                state_clear_buffer_init: begin
                    work_state <= state_clear_buffer_addr_hshake;
                end
                state_clear_buffer_addr_hshake: begin
                    if(!need_wb[head_pointer]) begin
                        if(cur_buffer_size == 1) begin
                            // 如果这是buffer中的最后一行
                            // 开始等待直到收到所有的bvalid
                            work_state <= state_clear_buffer_wait_bvalid;
                        end else begin
                            // 开始写下一行
                            work_state <= state_clear_buffer_addr_hshake;
                        end
                        // 更新缓冲区中的数据行数及头指针
                        if(head_pointer < 15)
                            head_pointer <= head_pointer + 1;
                        else
                            head_pointer <= 0;
                        cur_buffer_size <= cur_buffer_size - 1;
                        // need_wb[head_pointer] = 1'b0;
                    end else if(awready) begin
                        work_state <= state_clear_buffer_data_transf;
                        write_word_idx <= 0;
                    end
                end
                state_clear_buffer_data_transf: begin
                    if(wready) begin
                        if(write_word_idx < 7)
                            write_word_idx <= write_word_idx + 1;
                        // 如果这一行写完了(实际上在写最后一个字节,但这里的赋值都是给下个周期用的)
                        else if(write_word_idx == 7) begin
                            if(cur_buffer_size == 1) begin
                                // 如果这是要写回内存的最后一行
                                // 开始等待直到收到所有的bvalid
                                work_state <= state_clear_buffer_wait_bvalid;
                            end else begin
                                // 开始写下一行
                                work_state <= state_clear_buffer_addr_hshake;
                            end
                            // 更新缓冲区中的数据行数及头指针
                            if(head_pointer < 15)
                                head_pointer <= head_pointer + 1;
                            else
                                head_pointer <= 0;
                            cur_buffer_size <= cur_buffer_size - 1;
                            need_wb[head_pointer] = 1'b0;
                        end
                    end
                end
                state_clear_buffer_wait_bvalid: begin
                    // 收到所有bvalid后才可以认为本次写缓冲完成
                    if(bvalid_cnt == 0)
                        work_state = state_write_to_buffer_done;
                end
                // 是否命中已经在上一个状态(state_idle)下得到,并保持在这个状态中
                // 但数据要等到这个状态才能读到
                state_lookup_res: begin
                    work_state <= state_idle;
                    if(lookup_res_hit)
                        need_wb[lookup_res_wbuffer_addr] = 1'b0;
                end
            endcase
        end
    end

    // 更新bvalid_cnt
    always @ (posedge clk) begin
        if(rst)
            bvalid_cnt <= 0;
        else if(work_state == state_clear_buffer_init)
            bvalid_cnt <= cur_buffer_size;
        else if(bvalid)
            bvalid_cnt <= bvalid_cnt - 1;
    end

    
    // 当前要向内存中写的字
    wire[31:0] cur_write_word;
    assign cur_write_word = (write_word_idx == 0) ? rdata_bank0 :
                            (write_word_idx == 1) ? rdata_bank1 :
                            (write_word_idx == 2) ? rdata_bank2 :
                            (write_word_idx == 3) ? rdata_bank3 :
                            (write_word_idx == 4) ? rdata_bank4 :
                            (write_word_idx == 5) ? rdata_bank5 :
                            (write_word_idx == 6) ? rdata_bank6 :
                            (write_word_idx == 7) ? rdata_bank7 : 32'b0;


    // to wbuffer ram
    assign buffer_addr = ((work_state == state_idle) && wreq) ? tail_pointer : // 向tail_pointer指向的位置写
                         (work_state == state_clear_buffer_addr_hshake) ? head_pointer : // 从head_pointer指向的位置读,由于读有一个周期的延迟,需要在实际传输数据之前给出地址
                         ((work_state == state_idle) && lookup_req) ? lookup_res_wbuffer_addr : 1'b0;  // lookup时从lookup_res的地址中读
    assign wbuffer_ram_wen = (work_state == state_idle && wreq) ? 1'b1 : 1'b0;  // idle下且有写请求时需要向wbuffer_ram写
    // 要写的数据直接连到dcache上,dcache会在发出wreq的同时给出要写的数据
    // 可以保证dcache只会在state_idle下发出wreq

    // to AXI
    // aw
    assign awid = 4'b0000;
    assign awaddr = (work_state == state_clear_buffer_addr_hshake && need_wb[head_pointer]) ? {paddr_prefixes[head_pointer], 5'b0} : 32'b0;
    // 一个burst中传输一行, 8 x 4 = 32字节
    assign awlen    = 4'b0111;  // 一个burst传输8次
    assign awsize   = 3'b010;  // 每次传输4字节
    assign awburst  = 2'b01;  // incrementing-address burst
    assign awlock   = 2'b00;
    assign awcache  = 4'b0000;
    assign awprot   = 3'b000;
    assign awvalid  = (work_state == state_clear_buffer_addr_hshake && need_wb[head_pointer]) ? 1'b1 : 1'b0;

    // w
    assign wid      = 4'b0000;
    assign wdata    = cur_write_word;
    assign wstrb    = 4'b1111;
    assign wlast    = ((work_state == state_clear_buffer_data_transf) && (write_word_idx == 7)) ? 1'b1 : 1'b0;
    assign wvalid   = (work_state == state_clear_buffer_data_transf) ? 1'b1 : 1'b0;

    // b
    assign bready   = 1'b1;


    // to dcache
    assign wreq_recvd = ((work_state == state_idle) && wreq) ? 1'b1 : 1'b0;
    // 写完后仍然不full / 写完后full了但清空完毕了 的情况下可以发出wdone
    assign wdone  = (work_state == state_write_to_buffer_done && !full) ? 1'b1 : 1'b0;
    assign empty  = (cur_buffer_size == 0)  ? 1'b0 : 1'b1;
    // 在回到state_write_to_buffer_done且之前没有收到wreq则可以认为有dcache主动要求的clear操作完成
    assign clear_done = ((work_state == state_write_to_buffer_done) && !has_wreq) ? 1'b1 : 1'b0;


endmodule