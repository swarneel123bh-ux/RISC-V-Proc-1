`ifndef PARAMS_VH
`define PARAMS_VH

// Status Byte 0 bitwise definition (fixed)
localparam ST_RX_BUF_EMPTY        = 0;  // [0]
localparam ST_RX_BUF_FULL         = 1;  // [1]
localparam ST_TX_BUF_EMPTY        = 2;  // [2]
localparam ST_TX_BUF_FULL         = 3;  // [3]
localparam ST_RX_FRM_ERROR        = 4;  // [4]
localparam ST_IRQ_ENABLE          = 5;  // [5]
localparam ST_RX_RESERVED         = 6;  // [6]
localparam ST_RX_OVERRUN          = 7;  // [7]

// Variable fields depending on BUFFER_WIDTH (Must fix later)
// ST_*_*PTR_LO => Index of *_*PTR's b0 inside STATUS register
// ST_*_*PTR_HI => Index of *_*PTR's b($clog2(BUFFER_WIDTH)) inside STATUS register
localparam ST_RX_WPTR_LO          = 8;
localparam ST_RX_WPTR_HI          = 8 + PW - 1;
localparam ST_RX_RPTR_LO          = ST_RX_WPTR_HI + 1;
localparam ST_RX_RPTR_HI          = ST_RX_RPTR_LO + PW - 1;
localparam ST_TX_WPTR_LO          = ST_RX_RPTR_HI + 1;
localparam ST_TX_WPTR_HI          = ST_TX_WPTR_LO + PW - 1;
localparam ST_TX_RPTR_LO          = ST_TX_WPTR_HI + 1;
localparam ST_TX_RPTR_HI          = ST_TX_RPTR_LO + PW - 1;

// Control register
localparam CTRL_CLR_RX_FRAME_ERR    = 0;          // W1C, read always 0
localparam CTRL_CLR_RX_OVERRUN      = 1;          // W1C
localparam CTRL_RESERVED1_LO        = 2;          // read and write 0 always
localparam CTRL_RESERVED1_HI        = 7;          // read and write 0 always
localparam CTRL_IRQ_ENABLE          = 8;          // R/W   (modifiable, STATUS reflects current value)
localparam CTRL_RESERVED2_LO        = 9;          // read and write 0 always
localparam CTRL_RESERVED2_HI        = 15;         // read and write 0 always
localparam CTRL_BAUD_DIV_LO         = 16;         // R/W
localparam CTRL_BAUD_DIV_HI         = 16 + CW - 1; // R/W

// MMIO register decode
localparam OFF_TX                 = 4'd0;
localparam OFF_RX                 = 4'd4;
localparam OFF_ST                 = 4'd8;
localparam OFF_CTL                = 4'd12;

// States
localparam STATE_IDLE             = 3'd0;

// TX States
localparam STATE_TX_DRAIN         = 3'd1;
localparam STATE_TX_DRAIN_WAITREADY = 3'd2;
localparam STATE_TX_DRAIN_WAITVALID = 3'd3;
localparam STATE_ERR_TXBUF_FULL   = 3'd4;

// RX States
localparam STATE_RX_FILL          = 3'd1;
localparam STATE_ERR_RXBUF_FULL   = 3'd5;

`endif // PARAMS_VH
