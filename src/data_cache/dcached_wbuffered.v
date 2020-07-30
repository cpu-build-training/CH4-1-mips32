`timescale 1ns / 1ps

module dcache_wbuffered(
    input         clk    ,
    input         rstn   ,     // 低有效
    input         flush  ,
    
    // axi
    // ar
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [3 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot ,
    output        arvalid,
    input         arready,
    //r
    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
    // uncached写由dcache直接完成,因此仍然需要这些写相关的axi信号
    //aw
    // output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [3 :0] awlen  ,
    // output [2 :0] awsize ,
    output [1 :0] awburst,
    // output [1 :0] awlock ,
    // output [3 :0] awcache,
    // output [2 :0] awprot ,
    output        awvalid,
    input         awready,
    //w
    // output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
    //b
    // input  [3 :0] bid    ,
    // input  [1 :0] bresp  ,
    input         bvalid ,
    // output        bready ,

    // wbuffer
    // wb related
    output        wbuffer_wreq       ,
    output        wbuffer_uchd_wreq  ,
    input         wbuffer_wreq_recvd ,
    input         wbuffer_wdone      ,

    output [26:0] wbuffer_wdata_paddr_prefix,
    output [31:0] wbuffer_wdata_bank0,
    output [31:0] wbuffer_wdata_bank1,
    output [31:0] wbuffer_wdata_bank2,
    output [31:0] wbuffer_wdata_bank3,
    output [31:0] wbuffer_wdata_bank4,
    output [31:0] wbuffer_wdata_bank5,
    output [31:0] wbuffer_wdata_bank6,
    output [31:0] wbuffer_wdata_bank7,

    // clear related
    input         wbuffer_empty     ,
    output reg    wbuffer_clear_req ,
    input         wbuffer_clear_done,

    // lookup related
    output        wbuffer_lookup_req    ,
    input         wbuffer_lookup_res_hit,

    output [31:0] wbuffer_lookup_paddr,
    input  [31:0] wbuffer_rdata_bank0,
    input  [31:0] wbuffer_rdata_bank1,
    input  [31:0] wbuffer_rdata_bank2,
    input  [31:0] wbuffer_rdata_bank3,
    input  [31:0] wbuffer_rdata_bank4,
    input  [31:0] wbuffer_rdata_bank5,
    input  [31:0] wbuffer_rdata_bank6,
    input  [31:0] wbuffer_rdata_bank7,
    
    // from cpu, sram like
    input         data_req    ,
    input         data_wr     ,
    input  [3:0]  data_sel    ,
    input  [31:0] data_addr   ,
    input  [31:0] data_wdata  ,
    output        data_addr_ok,
    output        data_data_ok,
    output [31:0] data_rdata

    // input         data_cache
    );

    wire rst;
    assign rst = ~rstn;

    wire data_cache = data_addr[31:29] == 3'b101 ? 1'b0 : 1'b1;

    wire[31:0] data_paddr;
    assign data_paddr = (data_addr[31:29] == 3'b100 ||
                         data_addr[31:29] == 3'b101) ? 
                        {3'b0, data_addr[28:0]} : data_addr;
    reg[31:0] data_paddr_r;
    reg[31:0] data_wdata_r;
    reg[3:0]  data_sel_r;
    reg       data_cache_r;
    always @ (posedge clk) begin
        if (data_req) begin
            data_paddr_r    <= data_paddr;
            data_wdata_r    <= data_wdata;
            data_sel_r      <= data_sel;
            data_cache_r    <= data_cache;
        end
    end
    wire [19:0] tag_r      = data_paddr_r[31:12];
    wire [6:0]  line_idx_r = data_paddr_r[11:5];


    reg[127:0] lru;
    reg[127:0] way0_dirty;
    reg[127:0] way1_dirty;
    
    wire way0_is_victim = (lru[line_idx_r] == 1'b0);
    wire way1_is_victim = (lru[line_idx_r] == 1'b1);
    wire victim_is_dirty = way0_is_victim ? way0_dirty[line_idx_r] :
                           way1_is_victim ? way1_dirty[line_idx_r] : 1'b0;
    
    
    wire tag0_wen;
    wire tag1_wen;
    wire[20:0] tag_wdata;
    wire[31:0] access_cache_addr = data_req ? data_paddr : data_paddr_r;
    wire hit0, hit1;
    wire valid0, valid1;
    wire work0, work1;
    wire op0, op1;
    wire[19:0] tag0_rdata, tag1_rdata;
    dcache_tag dcache_tag_0(rst, clk, tag0_wen, tag_wdata, access_cache_addr, tag0_rdata, hit0, valid0, work0, op0);
    dcache_tag dcache_tag_1(rst, clk, tag1_wen, tag_wdata, access_cache_addr, tag1_rdata, hit1, valid1, work1, op1);
    
    wire hit = (hit0 && valid0) || (hit1 && valid1);

    // 从dcache中读到的数据
    wire[31:0] dcache_rdata_way_bank[1:0][7:0];

    // cache实际上使用的写使能是分字节的,一行4字节,因此写使能有4位
    // 由burst控制的向cache写使能,这里只有1位,实际使用时扩展到4位
    wire       burst_wen_way_bank[1:0][7:0];
    // 实际上直接接到cache上的写使能
    wire[3:0]  wen_way_bank[1:0][7:0];
    // 向cache_data中写的数据
    wire[31:0] dcache_wdata_way_bank[1:0][7:0];

    
    dcache_data way0_bank_0(clk, rst, 1'b1, wen_way_bank[0][0], dcache_wdata_way_bank[0][0], access_cache_addr, dcache_rdata_way_bank[0][0]);
    dcache_data way0_bank_1(clk, rst, 1'b1, wen_way_bank[0][1], dcache_wdata_way_bank[0][1], access_cache_addr, dcache_rdata_way_bank[0][1]);
    dcache_data way0_bank_2(clk, rst, 1'b1, wen_way_bank[0][2], dcache_wdata_way_bank[0][2], access_cache_addr, dcache_rdata_way_bank[0][2]);
    dcache_data way0_bank_3(clk, rst, 1'b1, wen_way_bank[0][3], dcache_wdata_way_bank[0][3], access_cache_addr, dcache_rdata_way_bank[0][3]);
    dcache_data way0_bank_4(clk, rst, 1'b1, wen_way_bank[0][4], dcache_wdata_way_bank[0][4], access_cache_addr, dcache_rdata_way_bank[0][4]);
    dcache_data way0_bank_5(clk, rst, 1'b1, wen_way_bank[0][5], dcache_wdata_way_bank[0][5], access_cache_addr, dcache_rdata_way_bank[0][5]);
    dcache_data way0_bank_6(clk, rst, 1'b1, wen_way_bank[0][6], dcache_wdata_way_bank[0][6], access_cache_addr, dcache_rdata_way_bank[0][6]);
    dcache_data way0_bank_7(clk, rst, 1'b1, wen_way_bank[0][7], dcache_wdata_way_bank[0][7], access_cache_addr, dcache_rdata_way_bank[0][7]);
    dcache_data way1_bank_0(clk, rst, 1'b1, wen_way_bank[1][0], dcache_wdata_way_bank[1][0], access_cache_addr, dcache_rdata_way_bank[1][0]);
    dcache_data way1_bank_1(clk, rst, 1'b1, wen_way_bank[1][1], dcache_wdata_way_bank[1][1], access_cache_addr, dcache_rdata_way_bank[1][1]);
    dcache_data way1_bank_2(clk, rst, 1'b1, wen_way_bank[1][2], dcache_wdata_way_bank[1][2], access_cache_addr, dcache_rdata_way_bank[1][2]);
    dcache_data way1_bank_3(clk, rst, 1'b1, wen_way_bank[1][3], dcache_wdata_way_bank[1][3], access_cache_addr, dcache_rdata_way_bank[1][3]);
    dcache_data way1_bank_4(clk, rst, 1'b1, wen_way_bank[1][4], dcache_wdata_way_bank[1][4], access_cache_addr, dcache_rdata_way_bank[1][4]);
    dcache_data way1_bank_5(clk, rst, 1'b1, wen_way_bank[1][5], dcache_wdata_way_bank[1][5], access_cache_addr, dcache_rdata_way_bank[1][5]);
    dcache_data way1_bank_6(clk, rst, 1'b1, wen_way_bank[1][6], dcache_wdata_way_bank[1][6], access_cache_addr, dcache_rdata_way_bank[1][6]);
    dcache_data way1_bank_7(clk, rst, 1'b1, wen_way_bank[1][7], dcache_wdata_way_bank[1][7], access_cache_addr, dcache_rdata_way_bank[1][7]);

    wire swap_to_mem = (work_state == s_miss_victim_wb_wreq);

    reg [2:0]  read_counter;    // 当前从内存中读取的的是一次burst中的第几个字节
    reg [31:0] read_data;       // 暂存从内存中读取到的数据
    reg [4:0]  work_state;      // 当前的状态(状态内赋的值就是下一个状态)
    reg        is_read;         // 记录当前操作的类型  1 读   0 写

    // 空闲状态,可接受请求
    parameter[4:0] s_idle                           = 5'b00000;

    // uncached read   完成后会到s_rw_done
    parameter[4:0] s_uncached_read_addr_hshake      = 5'b00001;
    parameter[4:0] s_uncached_read_data_transf      = 5'b00010;

    // uncached write  完成后会到s_rw_done
    parameter[4:0] s_uncached_write_addr_hshake     = 5'b00011;
    parameter[4:0] s_uncached_write_data_transf     = 5'b00100;
    parameter[4:0] s_uncached_write_waitfor_bv      = 5'b00101;

    // uncached rw 或 cached miss rw 完成
    // 用于向cpu发出data_data_ok, 可接受请求
    parameter[4:0] s_rw_done                        = 5'b00110;

    // cached rw 查看是否命中并根据结果判断下一步
    // 查询请求在上一个周期发出,结果在这周期得到
    // 如果命中,则根据读/写执行相应的操作
    // 命中后也可在本状态下接受请求
    parameter[4:0] s_cached_lookup                  = 5'b00111;

    // miss rw 向wbuffer中写回dirty victim
    parameter[4:0] s_miss_victim_wb_wreq            = 5'b01001;
    parameter[4:0] s_miss_victim_wb_waitfor_wdone   = 5'b01010;

    // miss rw 查看缺失的行能否在wbuffer中找到
    parameter[4:0] s_check_wbuffer_lookup_res       = 5'b01011;

    // miss rw wbuffer中没有所需要的行,从内存中去取
    parameter[4:0] s_miss_fetch_addr_hshake         = 5'b01100;
    parameter[4:0] s_miss_fetch_data_transf         = 5'b01101;

    // cached rw 完成后更新LRU与dirty    cached w 向cache写数据
    // 无条件转移到s_rw_done
    parameter[4:0] s_miss_update                    = 5'b01110;

    // ucached read/write 需要先清空wbuffer,该状态用于等待缓冲区清空完毕
    parameter[4:0] s_clear_buffer_waitfor_done      = 5'b01111;


    always @ (posedge clk) begin
        if(rst) begin
            work_state          <= s_idle;
            is_read             <= 1'b0;
            read_data           <= 32'b0;
            read_counter        <= 3'b0;
            wbuffer_clear_req   <= 1'b0;
        end else begin
            case(work_state)
                // state: 0
                s_idle: begin
                    if(data_req && !flush) begin
                        if(!data_wr) begin
                            is_read     <= 1'b1;
                            if(work0 && work1 && data_cache) begin
                                work_state  <= s_cached_lookup;
                            end else begin
                                if(wbuffer_empty)
                                    work_state  <= s_uncached_read_addr_hshake;
                                else begin
                                    wbuffer_clear_req <= 1'b1;
                                    work_state  <= s_clear_buffer_waitfor_done;
                                end
                            end
                        end else begin  // data_wr == 1'b1;
                            is_read     <= 1'b0;
                            if(work0 && work1 && data_cache) begin
                                work_state  <= s_cached_lookup;
                            end else begin
                                if(wbuffer_empty)
                                    work_state  <= s_uncached_write_addr_hshake;
                                else begin
                                    wbuffer_clear_req <= 1'b1;
                                    work_state  <= s_clear_buffer_waitfor_done;
                                end
                            end
                        end
                    end
                end
                s_clear_buffer_waitfor_done: begin
                    wbuffer_clear_req <= 1'b0;
                    if(wbuffer_clear_done) begin
                        if(is_read)
                            work_state  <= s_uncached_read_addr_hshake;
                        else
                            work_state  <= s_uncached_write_addr_hshake;
                    end
                end
                // uncached read
                // state: 1
                s_uncached_read_addr_hshake: begin
                    if(arready)
                        work_state  <= s_uncached_read_data_transf;
                end
                // state: 2
                s_uncached_read_data_transf: begin
                    if(rvalid) begin
                        work_state  <= s_rw_done;
                    end
                end
                // uncached write
                // state: 3
                s_uncached_write_addr_hshake: begin
                    if(awready)
                        work_state  <= s_uncached_write_data_transf;
                end
                // state: 4
                s_uncached_write_data_transf: begin
                    if(wready)
                        work_state  <= s_uncached_write_waitfor_bv;
                end
                // state: 5
                s_uncached_write_waitfor_bv: begin
                    if(bvalid)
                        work_state  <= s_rw_done;
                end
                // uncached rw / cached miss rw done
                // state: 6
                s_rw_done: begin
                    if(data_req && !flush) begin
                        if(!data_wr) begin
                            is_read     <= 1'b1;
                            if(work0 && work1 && data_cache) begin
                                work_state  <= s_cached_lookup;
                            end else begin
                                if(wbuffer_empty)
                                    work_state  <= s_uncached_read_addr_hshake;
                                else begin
                                    wbuffer_clear_req <= 1'b1;
                                    work_state  <= s_clear_buffer_waitfor_done;
                                end
                            end
                        end else begin  // data_wr == 1'b1;
                            is_read     <= 1'b0;
                            if(work0 && work1 && data_cache) begin
                                work_state <= s_cached_lookup;
                            end else begin
                                if(wbuffer_empty)
                                    work_state  <= s_uncached_write_addr_hshake;
                                else begin
                                    wbuffer_clear_req <= 1'b1;
                                    work_state  <= s_clear_buffer_waitfor_done;
                                end
                            end
                        end
                    end else
                        work_state  <= s_idle;
                end
                // state: 7
                // cached rw
                s_cached_lookup: begin
                    if(hit) begin
                        // 如果命中可以在本周期接受下个请求
                        if(data_req && !flush) begin
                            if(!data_wr) begin
                                is_read     <= 1'b1;
                                if(work0 && work1 && data_cache) begin
                                    work_state  <= s_cached_lookup;
                                end else begin
                                    if(wbuffer_empty)
                                        work_state  <= s_uncached_read_addr_hshake;
                                    else begin
                                        wbuffer_clear_req <= 1'b1;
                                        work_state  <= s_clear_buffer_waitfor_done;
                                    end
                                end
                            end else begin  // data_wr == 1'b1;
                                is_read     <= 1'b0;
                                if(work0 && work1 && data_cache) begin
                                    work_state <= s_cached_lookup;
                                end else begin
                                    if(wbuffer_empty)
                                        work_state  <= s_uncached_write_addr_hshake;
                                    else begin
                                        wbuffer_clear_req <= 1'b1;
                                        work_state  <= s_clear_buffer_waitfor_done;
                                    end
                                end
                            end
                        end else
                            work_state  <= s_idle;
                    end else begin
                        if(victim_is_dirty)
                            // 若未命中,且victim是dirty的,需要写回
                            // wreq会在下周期发出
                            work_state  <= s_miss_victim_wb_wreq;
                        else
                            // 若未命中,且victim不是dirty的,不需要写回
                            // 则本周期会发出查询wbuffer的请求
                            // 在下个周期可以得到查询结果
                            work_state  <= s_check_wbuffer_lookup_res;
                    end
                end
                // state: 9
                s_miss_victim_wb_wreq: begin
                    // 这周期发出wreq,收到wreq_recvd后开始等wdone
                    // 理论上wreq_recvd会与wreq同时出现
                    if(wbuffer_wreq_recvd)
                        work_state  <= s_miss_victim_wb_waitfor_wdone;
                end
                // state: 10   a
                s_miss_victim_wb_waitfor_wdone: begin
                    // 如果向wbuffer写回完成,这时认为victim已经不dirty了
                    // 则本周期会发出查询wbuffer的请求
                    // 在下个周期可以得到查询结果
                    if(wbuffer_wdone)
                        work_state  <= s_check_wbuffer_lookup_res;
                end
                // state: 11   b
                s_check_wbuffer_lookup_res: begin
                    if(wbuffer_lookup_res_hit) begin
                        // 如果在wbuffer中找到了所需的行,则将这行读取到cache
                        // 向cache写的内容在这周期已经得到,且wen也会在这周期发出
                        // 下个周期时向cache的写入已经完成
                        // 下个周期会更新LRU及dirty,如果是写操作的话还会将数据写入取到的cache行中
                        work_state  <= s_miss_update;
                        read_data   <= data_paddr_r[4:2] == 0 ? wbuffer_rdata_bank0 :
                                       data_paddr_r[4:2] == 1 ? wbuffer_rdata_bank1 :
                                       data_paddr_r[4:2] == 2 ? wbuffer_rdata_bank2 :
                                       data_paddr_r[4:2] == 3 ? wbuffer_rdata_bank3 :
                                       data_paddr_r[4:2] == 4 ? wbuffer_rdata_bank4 :
                                       data_paddr_r[4:2] == 5 ? wbuffer_rdata_bank5 :
                                       data_paddr_r[4:2] == 6 ? wbuffer_rdata_bank6 :
                                       data_paddr_r[4:2] == 7 ? wbuffer_rdata_bank7 : 0;
                    end else
                        // 如果没有在wbuffer中找到所需的行,则需要访问内存
                        // 访存请求在这个周期发出(即arvalid)
                        work_state  <= s_miss_fetch_addr_hshake;
                end
                // state: 12   c
                s_miss_fetch_addr_hshake: begin
                    if(arready)
                        work_state  <= s_miss_fetch_data_transf;
                end
                // state: 13   d
                s_miss_fetch_data_transf: begin
                    if(rvalid) begin
                        if(read_counter == data_paddr_r[4:2])
                            read_data   <= rdata;
                        if(rlast) begin
                            work_state   <= s_miss_update;
                            read_counter <= 3'b0;
                        end else begin
                            read_counter <= read_counter + 3'b1;
                        end
                    end
                end
                // state: 14   e
                s_miss_update: begin
                    work_state  <= s_rw_done;
                end
            endcase  // case(work_state)
        end  // if(rst)
    end  // always @ (posedge clk)


    always @ (posedge clk) begin
        if(rst)
            lru <= 128'b0;
        else begin
            if(work_state == s_cached_lookup) begin
                if(hit0 && valid0)
                    lru[line_idx_r] <= 1'b1;
                else if(hit1 && valid1)
                    lru[line_idx_r] <= 1'b0;
            end else if(work_state == s_miss_update) begin
                lru[line_idx_r] <= ~lru[line_idx_r];
            end
        end
    end

    
    always @ (posedge clk) begin
        if(rst)
            way0_dirty <= 128'b0;
        else begin
            if(work_state == s_cached_lookup && !is_read && hit0 && valid0)
                way0_dirty[line_idx_r] <= 1'b1;
            else if(work_state == s_miss_update && way0_is_victim) begin
                if(is_read)
                    way0_dirty[line_idx_r] <= 1'b0;
                else
                    way0_dirty[line_idx_r] <= 1'b1;
            end
        end
    end

    always @ (posedge clk) begin
        if(rst)
            way1_dirty <= 128'b0;
        else begin
            if(work_state == s_cached_lookup && !is_read && hit1 && valid1)
                way1_dirty[line_idx_r] <= 1'b1;
            else if(work_state == s_miss_update && way1_is_victim) begin
                if(is_read)
                    way1_dirty[line_idx_r] <= 1'b0;
                else
                    way1_dirty[line_idx_r] <= 1'b1;
            end
        end
    end


    assign tag0_wen = ((work_state == s_miss_update) && way0_is_victim) ? 1'b1 : 1'b0;
    assign tag1_wen = ((work_state == s_miss_update) && way1_is_victim) ? 1'b1 : 1'b0;
    // tag只有20位,最高那位是valid位,目前总是1
    assign tag_wdata = (work_state == s_miss_update) ? {1'b1, tag_r} : 21'b0;

    // 向cache_data写的地址
    // 未命中时从内存中burst读取到的字需要写到cache中,且wstrb一定全是1
    wire[1:0] burst_wen_way;
    assign burst_wen_way[0] = (work_state == s_miss_fetch_data_transf) && rvalid && way0_is_victim;
    assign burst_wen_way[1] = (work_state == s_miss_fetch_data_transf) && rvalid && way1_is_victim;
    generate
        genvar i, j;
        for(i = 0; i < 2; i = i + 1) begin
            for(j = 0; j < 8; j = j + 1) begin
                assign burst_wen_way_bank[i][j] = burst_wen_way[i] && (read_counter == j);
            end
        end
    endgenerate
    // 写命中,或将行取到cache后向这行写,即实际完成CPU发出的写操作时
    // 需要根据CPU给出的data_sel决定cache的字节写使能
    // burst时,直接将burst_wen_way_bank的1位扩展至4位使用
    generate
        for(i = 0; i < 8; i = i + 1) begin
            assign wen_way_bank[0][i] = (((work_state == s_cached_lookup && !is_read && hit0 && valid0) ||
                                          (work_state == s_miss_update && !is_read && way0_is_victim)) && data_paddr_r[4:2] == i) ? data_sel :
                                        (work_state == s_check_wbuffer_lookup_res && wbuffer_lookup_res_hit) ? 4'b1111 : 
                                        {4{burst_wen_way_bank[0][i]}};
        end
        for(i = 0; i < 8; i = i + 1) begin
            assign wen_way_bank[1][i] = (((work_state == s_cached_lookup && !is_read && hit1 && valid1) ||
                                          (work_state == s_miss_update && !is_read && way1_is_victim)) &&
                                          data_paddr_r[4:2] == i) ? data_sel :
                                        (work_state == s_check_wbuffer_lookup_res && wbuffer_lookup_res_hit) ? 4'b1111 : 
                                        {4{burst_wen_way_bank[1][i]}};
        end
    endgenerate
    // 向cache_data写的数据
    // 可能来自wbuffer,也可能来自内存,也可能来自CPU要写的数据
    // 来自内存或CPU的数据
    wire [31:0] cache_wdata_not_from_wbuffer = (work_state == s_miss_fetch_data_transf) ? rdata :
                                               (((work_state == s_cached_lookup && hit) || (work_state == s_miss_update)) && !is_read) ? data_wdata_r : 32'b0;
    // 来自wbuffer时,8个bank同时得到数据; 来自内存时,8个bank依次得到数据
    assign dcache_wdata_way_bank[0][0] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank0 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][1] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank1 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][2] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank2 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][3] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank3 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][4] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank4 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][5] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank5 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][6] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank6 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[0][7] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank7 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][0] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank0 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][1] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank1 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][2] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank2 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][3] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank3 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][4] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank4 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][5] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank5 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][6] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank6 : cache_wdata_not_from_wbuffer;
    assign dcache_wdata_way_bank[1][7] = (work_state == s_check_wbuffer_lookup_res) ? wbuffer_rdata_bank7 : cache_wdata_not_from_wbuffer;

    // 命中后读出的字
    wire[31:0] word_selection0 = dcache_rdata_way_bank[0][data_paddr_r[4:2]];
    wire[31:0] word_selection1 = dcache_rdata_way_bank[1][data_paddr_r[4:2]];
    wire[31:0] hit_word = (hit0 && valid0) ? word_selection0 :
                          (hit1 && valid1) ? word_selection1 : 32'b0;


    // 与wbuffer
    // 向wbuffer写回的被换出的victim
    assign wbuffer_wreq        = (work_state == s_miss_victim_wb_wreq) ? 1'b1 : 1'b0;
    assign wbuffer_uchd_wreq   = (work_state == s_uncached_write_addr_hshake ||
                                  work_state == s_uncached_write_data_transf ||
                                  work_state == s_uncached_write_waitfor_bv) ? 1'b1 :1'b0;
    assign wbuffer_wdata_paddr_prefix = way0_is_victim ? {tag0_rdata, line_idx_r} :
                                        way1_is_victim ? {tag1_rdata, line_idx_r} : 27'b0;
    assign wbuffer_wdata_bank0 = way0_is_victim ? dcache_rdata_way_bank[0][0] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][0] : 32'b0;
    assign wbuffer_wdata_bank1 = way0_is_victim ? dcache_rdata_way_bank[0][1] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][1] : 32'b0;
    assign wbuffer_wdata_bank2 = way0_is_victim ? dcache_rdata_way_bank[0][2] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][2] : 32'b0;
    assign wbuffer_wdata_bank3 = way0_is_victim ? dcache_rdata_way_bank[0][3] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][3] : 32'b0;
    assign wbuffer_wdata_bank4 = way0_is_victim ? dcache_rdata_way_bank[0][4] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][4] : 32'b0;
    assign wbuffer_wdata_bank5 = way0_is_victim ? dcache_rdata_way_bank[0][5] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][5] : 32'b0;
    assign wbuffer_wdata_bank6 = way0_is_victim ? dcache_rdata_way_bank[0][6] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][6] : 32'b0;
    assign wbuffer_wdata_bank7 = way0_is_victim ? dcache_rdata_way_bank[0][7] :
                                 way1_is_victim ? dcache_rdata_way_bank[1][7] : 32'b0;
    // 主动清空缓冲区的请求    在进入s_clear_buffer_waitfor_done之前发出请求
    // assign wbuffer_clear_req   = (work_state == s_idle || work_state == s_rw_done || (work_state == s_cached_lookup && hit) &&
    //                               (!(work0 && work1 && data_cache) && !wbuffer_empty)) ? 1'b1 : 1'b0;
    // 向wbuffer查询是否有需要的行
    assign wbuffer_lookup_req  = (work_state == s_cached_lookup && !hit && !victim_is_dirty) ||
                                 (work_state == s_miss_victim_wb_waitfor_wdone && wbuffer_wdone) ? 1'b1 : 1'b0;
    assign wbuffer_lookup_paddr= data_req ? data_paddr : data_paddr_r;


    // 与AXI
    // 只有在uncached read 与 miss且没有在wbuffer中找到需要的行 的情况下需要通过axi读
    // ar
    assign arid    = 4'b0000;
    assign araddr  = (work_state == s_uncached_read_addr_hshake) ? {data_paddr_r[31:2], 2'b00} :
                     (work_state == s_miss_fetch_addr_hshake) ? {data_paddr_r[31:5], 5'b00000} : 32'b0;
    assign arlen   = data_cache_r ? 4'b0111 : 4'b0000;
    assign arsize  = 3'b010;
    assign arburst = data_cache_r ? 2'b01 : 2'b00;
    assign arlock  = 2'b00;
    assign arcache = 4'b0000;
    assign arprot  = 3'b000;
    assign arvalid = ((work_state == s_uncached_read_addr_hshake) || 
                     (work_state == s_miss_fetch_addr_hshake)) ? 1'b1 : 1'b0;
    // r
    assign rready  = 1'b1;

    // 只剩下uncached w需要直接通过axi写
    // aw
    // assign awid   = 4'b0000;
    assign awaddr = (work_state == s_uncached_write_addr_hshake) ? {data_paddr_r[31:2], 2'b00} : 32'b0;
    assign awlen  = data_cache_r ? 4'b0111 : 4'b0000;
    // assign awsize = 3'b010;
    assign awburst= data_cache_r ? 2'b01 : 2'b00;
    // assign awlock = 2'b00;
    // assign awcache= 4'b0000;
    // assign awprot = 3'b000;
    assign awvalid= (work_state == s_uncached_write_addr_hshake) ? 1'b1 : 1'b0;
    // w
    // assign wid    = 4'b0000;
    assign wdata  = (work_state == s_uncached_write_data_transf) ? data_wdata_r : 32'b0;
    assign wstrb  = (work_state == s_uncached_write_data_transf) ? data_sel : 4'b0000;
    assign wlast  = (work_state == s_uncached_write_data_transf) ? 1'b1 : 1'b0;
    assign wvalid = (work_state == s_uncached_write_data_transf) ? 1'b1 : 1'b0;
    // b
    // assign bready = 1'b1;


    // 与CPU
    assign data_addr_ok = (work_state == s_idle ||
                           work_state == s_rw_done ||
                           work_state == s_cached_lookup) && data_req ? 1'b1 : 1'b0;
    assign data_data_ok = (work_state == s_rw_done ||
                          (work_state == s_cached_lookup && hit) ||
                          (work_state == s_uncached_read_data_transf && rvalid)) ? 1'b1 : 1'b0;
    assign data_rdata   = ((work_state == s_idle || work_state == s_rw_done || work_state == s_cached_lookup) && is_read && hit) ? hit_word :
                          (work_state == s_rw_done && is_read && !hit) ? read_data :
                          (work_state == s_uncached_read_data_transf && rvalid) ? rdata : 32'b0;
endmodule
