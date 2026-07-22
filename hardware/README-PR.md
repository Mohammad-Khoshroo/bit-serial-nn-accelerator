# معماری سخت‌افزار

## ۱. نمای کلی
این دایرکتوری حاوی کد منبع RTL (وریلوگ) برای یک **شتاب‌دهنده شبکه عصبی موازی-بیتی (Bit-Parallel)** است. معماری این سیستم بر اساس جریان داده‌ای **ثابت-خروجی (Output Stationary)** بنا شده است، جایی که هر عنصر پردازشی (PE) یک نورون خروجی را محاسبه و انباشت می‌کند. این سیستم با سه رابط AXI4 پوشیده (Wrap) شده است تا بتواند با میزبان (یا یک تست‌بنچ Cocotb) ارتباط برقرار کند.

## ۲. ساختار دایرکتوری و سلسله‌مراتب فایل‌ها
```text
hardware/
├── include/
│   └── hw_config.vh          # پارامترها و ماکروهای سراسری
└── src/
    ├── Cluster/               # منطق محاسبات اصلی (مسیر داده و کنترل‌کننده)
    │   ├── cluster_top.v
    │   ├── cluster_ctrl.v
    │   └── cluster_dp.v
    ├── Cluster-wrapper/
    │   └── cluster_wrapper.v  # سطح بالا: کلاستر را به رابط‌های AXI متصل می‌کند
    ├── axi4-interface/        # ماژول‌های اسِیو AXI4 (نگاشت‌شده به حافظه)
    │   ├── config/            # رجیسترهای کنترل و وضعیت
    │   ├── input-weight-rams/ # برام‌ها (BRAM) برای ورودی‌ها و وزن‌ها
    │   └── register-array/    # برام برای بایاس و انباشتگرهای خروجی
    └── utils/                 # ماژول‌های کمکی (BRAM، MAC)
```

سخت‌افزار به صورت یک سلسله‌مراتب دقیق از بالا به پایین ساختاربندی شده است. هنگام اجرای شبیه‌سازی، تست‌بنچ (Cocotb) به ماژول `cluster_wrapper` متصل می‌شود و داده‌ها از طریق پوشش‌دهنده‌های AXI به سمت منطق محاسباتی هسته اصلی جریان می‌یابند.

### درخت نمونه‌سازی (Instantiation) ماژول‌ها
```text
cluster_wrapper.v  (سطح بالا: پورت‌های AXI را در اختیار Cocotb/میزبان قرار می‌دهد)
│
├── Axi4_config_cluster_v1_0.v          (پوشش‌دهنده AXI پیکربندی)
│   └── Axi4_config_cluster_v1_0_S00_AXI.v (منطق و رجیسترهای AXI پیکربندی)
│
├── Axi4_input_weight_brams_v1_0.v      (پوشش‌دهنده AXI ورودی/وزن)
│   └── Axi4_input_weight_brams_v1_0_S00_AXI.v (منطق و برام‌های AXI ورودی/وزن)
│
├── Axi4_register_array_v1_0.v          (پوشش‌دهنده AXI انباشتگر)
│   └── Axi4_register_array_v1_0_S00_AXI.v (منطق و برام AXI انباشتگر)
│
└── cluster_top.v                       (پوشش‌دهنده محاسبات هسته)
    ├── cluster_ctrl.v                  (کنترل‌کننده FSM)
    └── cluster_dp.v                    (مسیر داده / عملیات MAC)
```

### الگوی فایل‌های IP ویووادو (`_v1_0.v` در مقابل `_v1_0_S00_AXI.v`)
درون زیردایرکتوری‌های `axi4-interface`، متوجه جفت فایل‌هایی برای هر پورت AXI خواهید شد. این الگو از ساختار استاندارد IP سفارشی (Custom IP) در نرم‌افزار زیلینکس ویووادو پیروی می‌کند:
*   **`*_v1_0.v` (پوشش‌دهنده/Wrapper):** این پوسته سطح بالای IP است. توسط `cluster_wrapper.v` نمونه‌سازی (Instantiate) می‌شود. هیچ منطقی ندارد و تنها کارش نگاشت (Map) پورت‌های استاندارد AXI به ماژول پیاده‌سازی است.
*   **`*_v1_0_S00_AXI.v` (پیاده‌سازی):** این "مغز" واقعی رابط AXI است. توسط پوشش‌دهنده (Wrapper) نمونه‌سازی می‌شود. شامل تمام ماشین‌های حالت متناهی AXI (.handshake، burst، رمزگشایی آدرس) و حافظه‌های داخلی (`byte_ram`) است.
*   **نکته:** هر دو فایل برای کامپایل شدن طراحی توسط شبیه‌ساز کاملاً ضروری هستند. اما زمانی که نیاز به بررسی آدرس‌های حافظه، آفست‌ها یا نحوه ذخیره‌سازی داده‌ها دارید، فقط باید فایل `_S00_AXI.v` را مطالعه کنید.

## ۳. پیکربندی سیستم (`include/hw_config.vh`)
سخت‌افزار با استفاده از ماکروهای وریلوگ پارامترسازی شده است.
```verilog
`define MAX_INPUT_SIZE 32 // که همان I0 است
`define MAX_PES 32 // که همان O0 است

`define INPUT_D_W 8 // عرض داده ورودی
`define PE_A_W $clog2(`MAX_PES)
`define PE_D_W 32 // ماکزیمم(clog2(input_size), clog2(max_PES))

`define WEIGHT_MEM_DEPTH `MAX_INPUT_SIZE
`define WEIGHT_MEM_A_W $clog2(`MAX_INPUT_SIZE) // عرض آدرس حافظه وزن
`define WEIGHT_MEM_D_W 8 // عرض داده حافظه وزن

`define INPUT_ZP_WIDTH 8
`define INPUT_NUM_WIDTH 16
`define OUTPUT_NUM_WIDTH 16
```

## ۴. رابط‌های AXI و نقشه حافظه (جزئیات پیاده‌سازی)
میزبان از طریق سه رابط مستقل اسِیو AXI4 که توسط `cluster_wrapper.v` در معرض قرار گرفته‌اند، با شتاب‌دهنده تعامل می‌کند.

### الف. رابط پیکربندی (`s00_axi`)
آدرس پایه: `0x40000000` | اندازه: ۸ بایت
برای روشن کردن موتور، تنظیم پارامترها و بررسی اتمام کار استفاده می‌شود. منطق آن در فایل `Axi4_config_mlp_v1_0_S00_AXI.v` قرار دارد.
*   **آفست `0x00`**: `[0]` = `start` (مقدار ۱ بنویسید تا شروع شود).
*   **آفست `0x04`**: `input_zp` (نقطه صفر ورودی ۸ بیتی).
*   **آفست `0x08`**: `input_num` (۱۶ بیتی، تعداد واقعی ورودی‌ها $\le 32$).
*   **آفست `0x0C`**: `output_num` (۱۶ بیتی، تعداد واقعی خروجی‌ها $\le 32$).
*   **آفست `0x10`**: `[0]` = `done` (فقط خواندنی. توسط سخت‌افزار زمانی که کار تمام شد روی ۱ تنظیم می‌شود).

**بخشی از منطق وریلوگ:**
```verilog
// از فایل Axi4_config_mlp_v1_0_S00_AXI.v
assign start = byte_ram[0][0];
assign input_zp = byte_ram[1];
assign input_num = {byte_ram[3], byte_ram[2]};
assign output_num = {byte_ram[5], byte_ram[4]};

always @( posedge S_AXI_ACLK ) begin
    if (mem_wren & (~logic_wen)) begin
        // ... منطق نوشتن برای byte_ram ...
    end else if (logic_wen) begin
        byte_ram[6][0] <= done; // سخت‌افزار پرچم 'done' را در آفست 0x10 آپدیت می‌کند
    end
end
```

### ب. برام‌های ورودی/وزن (`s01_axi`)
آدرس پایه: `0x40001000` | اندازه: ۱۰۵۶ بایت
بردار ورودی و ماتریس وزن را در خود نگه می‌دارد. منطق آن در فایل `Axi4_input_weight_brams_v1_0_S00_AXI.v` قرار دارد.
*   **بلوک ۰ (`0x000` تا `0x01F`)**: ۳۲ داده ورودی (هر کدام ۸ بیت).
*   **بلوک ۱ (`0x020` تا `0x03F`)**: ۳۲ وزن برای PE 0.
*   ...تا بلوک ۳۲ برای PE 31.

**بخشی از منطق وریلوگ:**
```verilog
// از فایل Axi4_input_weight_brams_v1_0_S00_AXI.v
// خواندن داده به صورت داخلی زمانی که کلاستر درخواست می‌کند
always @(posedge S_AXI_ACLK) begin
    if (input_weight_ren) begin
        input_data <= byte_ram[input_weight_address];
    end
end

genvar nw;
generate
    for (nw = 1; nw <= MAX_PES; nw = nw + 1) begin
        always @(posedge S_AXI_ACLK) begin
            if (input_weight_ren) begin
                // دریافت وزن برای PE 'nw' در آدرس 'input_weight_address'
                weight_data[nw*WEIGHT_DATA_WIDTH - 1 -: WEIGHT_DATA_WIDTH] <= byte_ram[{nw[$clog2(MAX_PES) : 0], input_weight_address}]; 
            end
        end
    end	
endgenerate
```

### ج. آرایه رجیستر / انباشتگرها (`s02_axi`)
آدرس پایه: `0x40002000` | اندازه: ۱۲۸ بایت (۳۲ عدد ۳۲ بیتی)
برای مقداردهی اولیه انباشتگرها با بایاس و خواندن نتایج نهایی استفاده می‌شود. منطق آن در فایل `Axi4_register_array_v1_0_S00_AXI.v` قرار دارد.

**بخشی از منطق وریلوگ:**
```verilog
// از فایل Axi4_register_array_v1_0_S00_AXI.v
// بارگذاری بایاس از BRAM به انباشتگرهای داخلی
always @(posedge ra_clk) begin
    if (ra_ld_axi) begin
        register_array[i * 8 +: 8] <= byte_ram[i];
    end
    // انباشت نتایج MAC
    else if (ra_ld_acc) begin
        register_array[i * 8 +: 8] <= ra_in_acc[i * 8 +: 8];
    end
end

// تخلیه انباشتگرهای داخلی مجدداً به داخل BRAM تا میزبان بتواند بخواند
always @( posedge S_AXI_ACLK ) begin
    else if (axi_ram_ld) begin
        byte_ram[axi_ram_i] <= register_array[axi_ram_i * 8 +: 8];
    end	
end
```

## ۵. معماری هسته (`Cluster`)

### `cluster_ctrl.v` (کنترل‌کننده FSM)
یک ماشین حالت متناهی (FSM) ساده که جریان داده‌ها را هماهنگ می‌کند.

**کد وریلوگ:**
```verilog
module cluster_ctrl(
    input clk, input rstn, input start,
    output reg logic_wen, output reg done,
    output reg ra_ld_axi, output reg ra_ld_acc, output reg axi_ram_ld,
    output reg input_weight_ren, output reg input_counter_clr, output reg input_counter_ld,
    input input_counter_co
);

localparam [2:0] S_IDLE = 0, S_LD_BETA = 1, S_WAIT_BETA = 2, S_WAIT_MEM = 3, 
                 S_CALCULATE = 4, S_WRITE_TO_MEM = 5, S_WAIT_ACK = 6;
reg [2:0] ps, ns;

always @(posedge clk) begin
    ps <= ns;
    if (!rstn) ps <= S_IDLE;
end

always @(*) begin
    ns = S_IDLE;
    case(ps)
    S_IDLE: ns = start ? S_LD_BETA : S_IDLE;
    S_LD_BETA: ns = S_CALCULATE;
    S_CALCULATE: ns = input_counter_co ? S_WRITE_TO_MEM : S_CALCULATE;
    S_WRITE_TO_MEM: ns = S_WAIT_ACK;
    S_WAIT_ACK: ns = ~start ? S_IDLE : S_WAIT_ACK;
    endcase
end

always @(*) begin
    {done, ra_ld_acc, input_weight_ren, ra_ld_axi,input_counter_clr,input_counter_ld, axi_ram_ld, logic_wen} = 0;
    case(ps)
    S_IDLE:{input_counter_clr} = 1'b1;
    S_LD_BETA: ra_ld_axi = 1'b1;
    S_CALCULATE: {input_weight_ren, ra_ld_acc, input_counter_ld} = 3'b111;
    S_WRITE_TO_MEM: {axi_ram_ld, logic_wen, done} = 3'b111;
    S_WAIT_ACK: {logic_wen ,done} = {~start, start};
    endcase
end
endmodule
```

### `cluster_dp.v` (مسیر داده / Datapath)
شامل منطق حسابی است. برای هر کلاک در وضعیت `S_CALCULATE`، مقدار `input_data` و `weight_data` را می‌خواند و عملیات MAC را محاسبه می‌کند.

**کد وریلوگ:**
```verilog
module cluster_dp #( /* پارامترها */ ) (
    input clk, rstn,
    input [$clog2(MAX_INPUT_SIZE) - 1 : 0] input_size,
    input [$clog2(MAX_PES) - 1 : 0] output_size,
    input [INPUT_D_W - 1 : 0] input_data,
    input signed [WEIGHT_MEM_D_W * MAX_PES - 1 : 0] weight_data,
    output [ INPUT_WEIGHT_ADDR_WIDTH - 1 : 0 ] input_weight_address,
    input input_counter_clr, input input_counter_ld, output input_counter_co,
    input [`INPUT_ZP_WIDTH-1:0] input_zp,
    output reg [BYTE_REG_NUM * 8-1:0] ra_in_acc,
    input [BYTE_REG_NUM * 8-1:0] register_array
);
    
// شمارنده برای پیمایش روی ورودی‌ها
reg [INPUT_WEIGHT_ADDR_WIDTH-1 : 0] input_counter_r;
always @(posedge clk) begin
    if(input_counter_ld) input_counter_r <= input_counter_r + 1;
    if (input_counter_clr | !rstn) input_counter_r <= 0; 
end
assign input_counter_co = input_counter_r >= input_size;
assign input_weight_address = input_counter_r;

// تفریق نقطه صفر ورودی
wire signed [ 8 : 0] input_signed; 
assign input_signed = input_data - input_zp;

// عملیات MAC موازی برای تمام PEها
genvar k;
generate
    for (k = 0; k < MAX_PES; k = k + 1) begin
        wire signed [PE_D_W - 1 : 0] ra_mat_temp;
        wire signed [PE_D_W - 1 : 0] ra_in;
        reg [PE_D_W - 1 : 0] ra_out;
        
        // استخراج وزن برای PE k
        reg signed [WEIGHT_MEM_D_W - 1 : 0] weight_data_i;
        always @(*) begin
            ra_out[k] = register_array[(k) * PE_D_W +: PE_D_W];
            ra_in_acc[(k) * PE_D_W +: PE_D_W] = ra_in[k];
            weight_data_i[k] = weight_data[(k) * WEIGHT_MEM_D_W +: WEIGHT_MEM_D_W];
        end
        
        // ضرب و انباشت موازی-بیتی
        assign ra_mat_temp[k] = input_signed * weight_data_i[k];
        assign ra_in[k] = ra_out[k] + ra_mat_temp[k]; 
    end
endgenerate
endmodule
```

## ۶. جریان اجرا (از دیدگاه میزبان)
برای اجرای یک عملیات لایه، میزبان (Cocotb) باید دقیقاً این توالی را دنبال کند:
۱. **نوشتن بایاس:** ارسال ۳۲ مقدار بایاس ۳۲ بیتی به `s02_axi` (`0x40002000`).

۲. **نوشتن داده:** ارسال حداکثر ۳۲ مقدار ورودی به `s01_axi` (`0x40001000`، بلوک ۰).

۳. **نوشتن وزن:** ارسال حداکثر ۳۲×۳۲ مقدار وزن به `s01_axi` (`0x40001000`، بلوک‌های ۱ تا ۳۲).

۴. **پیکربندی:** نوشتن `input_zp`، `input_num` و `output_num` در `s00_axi` (به ترتیب در آفست‌های `0x04`، `0x08`، `0x0C`).

۵. **شروع:** نوشتن مقدار `۱` در آفست `0x00` مربوط به `s00_axi` (بیت `start`).

۶. **پایش (Poll):** خواندن مداوم آفست `0x10` از `s00_axi` تا زمانی که بیت `[0]` برابر `۱` شود (یعنی `done`).

۷. **پاک کردن شروع (Clear Start):** نوشتن مقدار `۰` در آفست `0x00` مربوط به `s00_axi` برای تأیید دریافتِ اتمام کار.

۸. **خواندن خروجی:** خواندن ۳۲ مقدار خروجی ۳۲ بیتی از `s02_axi` (`0x40002000`).

## ۷. ابزارهای کمکی (`utils/`)
*   `bram_sp.v`: یک پوشش‌دهنده (Wrapper) استاندارد برای برام تک‌پورت (Single-Port).
*   `mull_add.v`: یک ماژول پایپ‌لاین‌شده برای ضرب و انباشت (MAC). در حالی که `cluster_dp.v` فعلی از ضرب درون‌خطی وریلوگ (`*`) استفاده می‌کند، این ماژول منطقی را نشان می‌دهد که در فاز ۲ پروژه، هدف بهینه‌سازی سریال-بیتی (Bit-Serial) قرار خواهد گرفت.

```verilog
// فایل mull_add.v
module mul_add #( /* پارامترها */ ) (
    input clk, rstn, input en, clear,
    input signed [A_WIDTH-1 : 0] mul_a,
    input signed [B_WIDTH-1 : 0] mul_b,
    input signed [C_WIDTH-1 : 0] add_c,
    output reg signed [O_WIDTH-1 : 0] out
);
    reg signed [O_WIDTH - 1 : 0] mult_res;
    always @(posedge clk) begin
        if (en) begin
            mult_res <= mul_a * mul_b;
            out <= mult_res + out;
        end
        if (clear | !rstn) begin
            mult_res <= 0; out <= 0;
        end
    end
endmodule
```