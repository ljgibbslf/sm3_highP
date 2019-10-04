# sm3_highP
A implement of Chinese SHA(SM3) on FPGA from SHU ACTION team

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
