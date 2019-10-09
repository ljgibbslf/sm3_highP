# sm3_highP
SM3_highP is a open-source implement of SM3(Chinese Commercial Hash algorithm standard) on FPGA. highP is a high performance implement with more than 1Mbps throughout and less than 40 clocks latency for a single 512-byte-block calculation.

The interface of SM3_highP is a AXI-Stream-like protocol, support. Width of Input data is 64 bytes but IP supports byte-alignment input by tkeep signal in bus.

Based on SM3_highP SM3 IP Core, SM3_highP_Ethe integrades 1000M ethernet interface for SM3. Implementing on Xilinx Zynq-7020 device , system throughout can reach more than 700Mbps and reduce calculating time to half of time consumed by General CPU(Intel Core i7-7700K). 
Although SM3_highP_Ethe is close-source now because of use multiple Xilinx IP which are hard to transparent relatively, you are welcome to contact me if you have interest on it.


wavedrom wave code:
{signal: [
  {name: 'clk', wave: 'p...........'},
  {name: 'rst_n', wave: '01..........'},
  {},
  {name: 'data_i', wave: 'x.===0......', data: ['W0','W1','W2']},
  {name: 'data_valid_i', wave: '0.1..0......'},
  {name: 'data_last_i',  wave: '0...10......'},
  {name: 'data_keep_i', wave: 'x=...x.....x', data: ['FF']},
  {name: 'data_ready_o', wave: '01...01.....'},
  {},

  {name: 'res_o', wave: 'x.......|.=x', data: ['Hash']},
  {name: 'res_valid_o', wave: '0.......|.10'},
]}
