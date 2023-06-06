#  CS214 Project Report 

## 基于Minisys开发板实现的单周期CPU



## 一、开发者说明

| 组员            | 负责模块      | 贡献比 |
| --------------- | ------------- | ------ |
| 12111114 高自然 | CPU架构，外设 | 33.3%  |
| 12112328 郑祖彬 | MIPS测试代码  | 33.3%  |
| 12112411 李达辉 | CPU架构       | 33.3%  |

## 二、CPU 架构设计说明

### （一）CPU 特性

#### 1. ISA architecture

| Instruction | Type | Description                         | Op code | Func code |
| ----------- | ---- | ----------------------------------- | ------- | --------- |
| beq         | I    | branch on equal                     | 000100  | -         |
| bne         | I    | branch on not equal                 | 000101  | -         |
| lw          | I    | load word                           | 100011  | -         |
| sw          | I    | store word                          | 101011  | -         |
| addi        | I    | add immediate word                  | 001000  | -         |
| addiu       | I    | add immediate unsigned word         | 001001  | -         |
| slti        | I    | set on less than immediate          | 001010  | -         |
| sltiu       | I    | set on less than immediate unsigned | 001011  | -         |
| andi        | I    | and immediate                       | 001100  | -         |
| ori         | I    | or immediate                        | 001101  | -         |
| xori        | I    | exclusive or immediate              | 001110  | -         |
| lui         | I    | load upper immediate                | 001111  | -         |
| sll         | R    | shift left logically                | 000000  | 000000    |
| srl         | R    | shift right logically               | 000000  | 000010    |
| sllv        | R    | shift left logical variable         | 000000  | 000100    |
| srlv        | R    | shift right logical variable        | 000000  | 000110    |
| sra         | R    | shift right arithmetically          | 000000  | 000011    |
| srav        | R    | shift right arithmetically variable | 000000  | 000111    |
| jr          | R    | jump register                       | 000000  | 001000    |
| add         | R    | add                                 | 000000  | 100000    |
| addu        | R    | add unsigned                        | 000000  | 100001    |
| sub         | R    | sub                                 | 000000  | 100010    |
| subu        | R    | sub unsigned                        | 000000  | 100011    |
| and         | R    | and                                 | 000000  | 100100    |
| or          | R    | or                                  | 000000  | 100101    |
| xor         | R    | exclusive or                        | 000000  | 100110    |
| nor         | R    | not or                              | 000000  | 100111    |
| slt         | R    | set less than                       | 000000  | 101010    |
| sltu        | R    | set less than unsigned              | 000000  | 101011    |
| j           | J    | jump                                | 000010  | -         |
| jal         | J    | jump and link                       | 000011  | -         |

参考的ISA architecture为Minisys的MIPS指令架构，支持31条MIPS指令。

对 lw 和 sw 的实现方式进行了修改，使得可以支持MMIO功能。

#### 2. 寄存器：

数量：32 个，位宽：32 位

#### 3. 异常处理：

软硬件协同，由软件进行异常处理，硬件进行异常显示。可以进行负数检测，overflow检测等。

#### 4. 寻址空间设计：

- 结构：Harvard Architecture

- 寻址单位：32 bits

- 指令空间大小：16384 * 4 bytes

- 数据空间大小：16384 * 4 bytes

#### 5. 对外设IO的支持：

##### MMIO：

| 外设          | 描述                         | 地址     | IO位宽  |
| ------------- | ---------------------------- | -------- | ------- |
| switch        | input 开关                   | FFFFFC60 | 16 bits |
| key_pad       | input 键盘                   | FFFFFC64 | 16 bits |
| led light     | output 显示数据的led灯       | FFFFFC68 | 16 bits |
| segment light | output 数码管                | FFFFFC6C | 16 bits |
| led test case | output 显示test case 的led灯 | FFFFFC70 | 3 bits  |
| IO ready      | input IO 完成信号（按钮）    | FFFFFC80 | 1 bit   |

采用轮询的方式访问IO，每次需要访问IO时，在软件代码中加入一个循环，判断访问IO ready返回的值是否为1，如果为1则进行后续的IO操作。IO ready的值和硬件上的一个按钮绑定，代表IO已经输入或准备完成，可以进行读入或写出。

#### 6. CPU其他特性说明:

单周期CPU，不支持pipeline，CPI = 1。

### （二）CPU接口：

#### 1. CPU接口说明：

1. 时钟：连接Minisys自带时钟，在硬件代码中使用IP核将时钟周期转为10MHz。

2. 复位：分为upg_rst和reset信号，分别连接Minisys上的两个按键。upg_rst信号重置uart的读入，reset信号重置CPU运行。

#### 2. 外设IO接口说明：

1. 小键盘：采用`keypad_n`与`pad_decode`类共同实现，其中`kepad_n`类对键盘获取信号进行直接处理，生成单一输出信号，其中0-9输出信号0-9，#输出信号14，无按钮按下输出信号15，输出信号传递至`pad_decode`中进行解码，输出信号为按时间顺序输入的最后四个数与他们的10进制和表示,具体实现如下：

   - keypad_n：

   | 输出信号：o1         | line       | 输入信号：row | clk      |
   | -------------------- | ---------- | ------------- | -------- |
   | 未处理的键盘输出信号 | 列扫描信号 | 行电平信号    | 时钟信号 |

   建立针对列的扫描信号，其中激活信号为0，构建的信号为2‘b0111，2‘b1011，2‘b1101，2‘b1110，逐列激活按钮后在输出端接受按钮信号，如键盘输出端检测到低电平信号，则检测判断按下按钮，将输出端o1的值修改为当前值，否则改为default。

   

   

   

   

   - pad_decode：

   | 输出信号：o1~o8   | o_4                | 输入信号：in       | clk      | rst      |
   | ----------------- | ------------------ | ------------------ | -------- | -------- |
   | 最后8个输入的信号 | 最后四个输入的信号 | 未处理键盘输出信号 | 时钟信号 | 重置信号 |

   in信号来自keypad_n，o_4为十进制信号。

   每次in输入信号改变时将输出信号左移一位，空出来的信号端被in信号赋值。

   为了避免键盘信号不稳定导致的抖动，加入防抖模块：具体为在in信号发生改变时在每个时钟上升沿将cnt信号加一，当cnt大于1000时认定为按钮被按下，如果in信号发生改变后回到default状态，则在每个时钟上升沿将cnt信号减一直至cnt信号值为0。

2. 七位数码管：

   > 使用模块`num_gif1`将数字转化为数码管点亮信号

   | 输出信号：high | value       | 输入信号：n1,n2,n3,n4,n5,n6,n7,n8 | clk      |
   | -------------- | ----------- | --------------------------------- | -------- |
   | 片选扫描信号   | Led复制信号 | 输入的应显示的数字                | 时钟信号 |

3. led_test 测试灯：

   | 输出信号：led_light | 输入信号：wdata    | led_tctrl        | clk      |
   | ------------------- | ------------------ | ---------------- | -------- |
   | 显示测试样例号，3位 | 输出信号（样例号） | led_test控制信号 | 时钟信号 |

4. led_light 显示灯

   | 输出信号：led_light | 输入信号：wdata      | ledctrl     | clk      |
   | ------------------- | -------------------- | ----------- | -------- |
   | 显示输出数据，16位  | 输出信号（输出数据） | led控制信号 | 时钟信号 |

5. uart通信：

   > 板载协议部分

   | 输出信号：uart_txd | 输入信号：uart_data | uart_ctrl | clk      |
   | ------------------ | ------------------- | --------- | -------- |
   | uart输出信号       | 等待发送的数据      | 控制信号  | 时钟信号 |

   当检测到控制信号上升沿时，将uart_data中的信号按顺序在输出信号中输出。

   > 电脑协作部分

   ```python
   serial_port = serial.Serial(
       port="COM8",
       baudrate=12800,
       bytesize=serial.EIGHTBITS,
       parity=serial.PARITY_NONE,
       stopbits=serial.STOPBITS_ONE,
   )#初始化串口
   data = serial_port.read()#获取串口数据
   ```

6. 按钮防抖：

   | 输出信号：out    | 输入信号：in | clk      |
   | ---------------- | ------------ | -------- |
   | 处理后的按钮信号 | 按钮输入信号 | 时钟信号 |

   为了避免按钮信号不稳定导致的抖动，加入防抖模块：

   具体为以下伪代码：

   ```
   在每个clk信号上升沿：判断in信号是否为1：
   	如果in为1：
   		如果cnt信号为1000：
   			则将输出信号设为1
   		否则：
   			cnt++
   	否则：
   		如果cnt信号为0：
   			则将输出信号设为0
   		否则：
   			cnt--
   ```

### （三）CPU内部结构:

> CPU内部各子模块规格、说明与连接关系图

#### 1. cpuclk（IP core）

![image-20230604123929921](ISA architecture.assets\image-20230604123929921.png)

#### 2. clk_1k

![image-20230604125024607](ISA architecture.assets\image-20230604125024607.png)

#### 3. controller

![image-20230604124119395](ISA architecture.assets\image-20230604124119395-16858536844181.png)

![image-20230604131041409](ISA architecture.assets\image-20230604131041409.png)

#### 4. ifetch

![image-20230604124219932](ISA architecture.assets\image-20230604124219932-16858537426053-16858537456405.png)

![image-20230604131321082](ISA architecture.assets\image-20230604131321082.png)

#### 5. decoder

![image-20230604124405296](ISA architecture.assets\image-20230604124405296.png)

![image-20230604131855474](ISA architecture.assets\image-20230604131855474.png)

#### 6. execute

![image-20230604124434057](ISA architecture.assets\image-20230604124434057.png)

![image-20230604132739261](ISA architecture.assets\image-20230604132739261.png)

#### 7. memorio

![image-20230604124506269](ISA architecture.assets\image-20230604124506269.png)

![image-20230604132344217](ISA architecture.assets\image-20230604132344217.png)

#### 8. ioreader

![image-20230604124526134](ISA architecture.assets\image-20230604124526134.png)

![image-20230604132432491](ISA architecture.assets\image-20230604132432491.png)

#### 9. data memory

![image-20230604124645260](ISA architecture.assets\image-20230604124645260.png)

![image-20230604132510408](ISA architecture.assets\image-20230604132510408.png)



#### 10. program memory

![image-20230604124614278](ISA architecture.assets\image-20230604124614278.png)

![image-20230604132558363](ISA architecture.assets\image-20230604132558363.png)

#### 11. uart （IP core）

![image-20230604124946577](ISA architecture.assets\image-20230604124946577.png)

#### 12. button_decode

![image-20230604125127435](ISA architecture.assets\image-20230604125127435.png)

![image-20230604133908813](ISA architecture.assets\image-20230604133908813.png)

#### 13. pad_decode & switch

![image-20230604125307709](ISA architecture.assets\image-20230604125307709.png)

![image-20230604133117646](ISA architecture.assets\image-20230604133117646.png)

![image-20230604133322451](ISA architecture.assets\image-20230604133322451.png)

#### 14. led_test & led_light

![image-20230604125458049](ISA architecture.assets\image-20230604125458049.png)

![image-20230604133447683](ISA architecture.assets\image-20230604133447683.png)

![image-20230604133413019](ISA architecture.assets\image-20230604133413019.png)

#### 15. sig_led

![image-20230604125530873](ISA architecture.assets\image-20230604125530873.png)

![image-20230604133612877](ISA architecture.assets\image-20230604133612877.png)

#### 16. uart_tx

![image-20230604135016670](ISA architecture.assets\image-20230604135016670.png)

![image-20230604133712059](ISA architecture.assets\image-20230604133712059.png)



## 三、测试说明：

| 测试方法 | 测试类型                | 测试用例描述                                                 | 测试结果 |
| -------- | ----------------------- | ------------------------------------------------------------ | -------- |
| 上板     | 单元（拨码开关、LED灯） | 拨动拨码开关，控制对应LED灯亮灭                              | 通过     |
| 上板     | 单元（七段数码管）      | 七段数码管每隔1秒显示数字加1，从0开始                        | 通过     |
| 上板     | 单元（小键盘）          | 按下小键盘，七段数码管同步显示对应数字                       | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a（仅识别a的低7bit），输入完毕后在led灯上显示a，同时用1个led灯显示a的奇校验结果：a=$(11111111)_2$, a=$(10111111)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a（识别a的完整8bit），输入完毕后在led灯上显示a，同时用1个led灯显示a的奇校验结果：a=$(11111111)_2$, a=$(10111111)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a, 用拨码开关输入测试数b，计算 a 和 b的按位或非运算，将结果显示在LED灯：a=$(00000101)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a, 用拨码开关输入测试数b，计算 a 和 b的按位或运算，将结果显示在LED灯：a=$(00000101)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a, 用拨码开关输入测试数b，计算 a 和 b的按位异或或运算，将结果显示在LED灯：a=$(00000101)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a, 用拨码开关输入测试数b，将a和b按照无符号数进行比较，用LED灯展示a<b的关系是否成立：a=$(01111111)_2$, b=$(11111111)_2$；a=$(00000010)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a, 用拨码开关输入测试数b，将a和b按照有符号数进行比较，用LED灯展示a<b的关系是否成立：a=$(01111111)_2$, b=$(11111111)_2$；a=$(00000010)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a, 用拨码开关输入测试数b，在LED灯上展示a和b的值：a=$(11111111)_2$, b=$(10111111)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入输入a的数值（a被看作有符号数），计算1到a的累加和，在LED灯上显示累加和（如果a是负数，以LED灯闪烁的方式给与提示）：a=$(10000000)_2$, a=$(00000110)_2$ | 通过     |
| 上板     | 集成                    | 用小键盘输入a的数值（a被看作无符号数），七段数码管同步显示a的数值。以递归的方式计算1到a的累加和，累加和用LED灯表示。记录本次入栈和出栈次数，在七段数码管和LED灯同步上显示入栈和出栈的次数之和：a=$(00000110)_2$ | 通过     |
| 上板     | 集成                    | **（bonus测试用例）**用小键盘输入a的数值（a被看作无符号数），七段数码管同步显示a的数值。以递归的方式计算1到a的累加和，记录入栈和出栈的数据，在七段数码管，LED灯，PC终端屏幕上显示入栈的参数，每一个入栈的参数显示停留2-3秒：a=$(00000110)_2$ | 通过     |
| 上板     | 集成                    | 用小键盘输入a的数值（a被看作无符号数），七段数码管同步显示a的数值。以递归的方式计算1到a的累加和，记录入栈和出栈的数据，在七段数码管，LED灯上显示出栈的参数，每一个出栈的参数显示停留2-3秒：a=$(00000110)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a和测试数b，实现有符号数（a，b以及相加和都是8bit，其中的最高bit被视作符号位，如果符号位为1，表示的是该负数的补码）的加法，并对是否溢出进行判断，LED灯显示运算结果以及溢出判断：a=$(01111111)_2$, b=$(01111111)_2$；a=$(00000010)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a和测试数b，实现有符号数（a，b以及相减差都是8bit，其中的最高bit被视作符号位，如果符号位为1，表示的是该负数的补码）的减法，并对是否溢出进行判断，LED灯显示运算结果以及溢出判断：a=$(01111111)_2$, b=$(11111110)_2$；a=$(00000010)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a和测试数b，实现有符号数（a，b都是8bit，乘积是16bit，其中的最高bit被视作符号位，如果符号位为1，表示的是该负数的补码）的乘法，LED灯显示乘积：a=$(11111111)_2$, b=$(00100000)_2$；a=$(00000010)_2$, b=$(00000011)_2$ | 通过     |
| 上板     | 集成                    | 用拨码开关输入测试数a和测试数b，实现有符号数（a，b，商和余数都是8bit，其中的最高bit被视作符号位，如果符号位为1，表示的是该负数的补码）的除法，LED灯显示商和余数（商和余数交替显示，每个结果显示持续5秒）：a=$(00000111)_2$, b=$(00000010)_2$；a=$(00000101)_2$, b=$(11111110)_2$ | 通过     |

测试结论：所有测试用例结果均为通过，CPU设计合理，实现了基本以及bonus的功能和效果。



## 四、bonus 部分说明：

1. 设计思路：debug_bridge_for_cpu

   将电脑（或者任何可以接受uart信号的设备）作为一个信息展示设备，使用mmio的方式将cpu上任意内存区域内的某块内存通过uart传输至电脑上，以此展示与测试存储在内存中的数据。

2. 核心代码

   python部分：

   ```python
   import time
   import serial
   
   print("BEGIN RECEIVE DATA")
   
   
   serial_port = serial.Serial(
       port="COM8",                
       baudrate=12800,
       bytesize=serial.EIGHTBITS,
       parity=serial.PARITY_NONE,
       stopbits=serial.STOPBITS_ONE,
   )
   # Wait a second to let the port initialize
   time.sleep(1)
   
   try:
       def data1():
           data=None
           while data is None:
               if serial_port.inWaiting() > 0:
                   data = serial_port.read()
           return ord(data)
       print(f'this is the {data1()}-th case')
       print(f'入栈的参数{data1()}')
       while True:
           a=data1()
           print(f'当前参数{a}')
           if a == 0:
               print(f'入栈完毕')
               break
   
   except KeyboardInterrupt:
       print("Exiting Program")
   
   except Exception as exception_error:
       print("Error occurred. Exiting Program")
       print("Error: " + str(exception_error))
   
   finally:
       serial_port.close()
       pass
   ```

3. 场景说明

   通过测试2中的第2个测试实例展示功能：

   		在LED上与数码管上显示数字的同时通过uart传输数据，并与电脑的uart数据接收端配合展示数据。

4. 测试结果

   开始运行时显示`BEGIN RECEIVE DATA`

   收到样例时显示`this is the 2-th case`

   收到入栈请求显示`入栈的参数{data}`

   后续会显示`当前参数{data}`

   直至data==0，显示`入栈完毕`

   

## 五、问题及总结：

#### 1. 关于 MMIO 如何知道IO已经准备好

- 如果IO在收到IO指令后立刻执行，很可能会将未输入时的数据（例如开关的初始值是全0）作为输入数据进行运算，得出错误的结果。因此，在硬件中分配一个按钮作为IO ready信号，软件编写中在需要访问IO时先轮询该信号，在IO ready信号为1（按钮被按下）时，才将输入设备的内容读入。
- IO ready信号持续的时间会影响后续的IO指令，如果IO ready存在的时间过长，可能会使得后续未ready的IO也被该信号影响。最初我们希望使用硬件解决，但时间控制比较困难，后来使用软件硬件结合的方法，在IO后插入空指令，确保一次IO ready信号只对一次IO起作用。结果IO读入很稳定，问题得到解决。

#### 2. 关于 IO 显示的时钟频率

- 七段数码管使用视觉暂留的现象来进行同时显示，控制数据变化的时钟和控制显示的时钟可能产生冲突，造成重影等问题。
- 最后让控制数据变化的时钟使用高频率，控制显示的时钟使用较低的频率，解决了这个问题。

#### 3. 关于设计时如何保证各个模块之间可以协同工作

- 需要进行良好的顶层设计，确定好各个模块需要负责的功能，需要发送到不同模块和从不同模块接收的信号。
- 不同模块使用的相同信号最好使用相同的命名，方便在cpu_top编写时方便连接各个模块。

#### 4. 关于调节uart初始化模块与uart_tx模块之间的关系

-  由于这两个模块均使用了uart_tx作为输出信号，故需要调节：在uart初始化完毕后会向cpu发送完成指令，此时将tx切换至uart_tx进行输出。



