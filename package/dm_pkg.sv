package dm;
  localparam logic [3:0] DbgVersion013 = 4'h2;

  localparam logic [4:0] ProgBufSize = 5'h8;

  localparam logic [3:0] DataCount = 4'h2;

  localparam logic [63:0] HaltAddress = 64'h800;
  localparam logic [63:0] ResumeAddress = HaltAddress + 4;
  localparam logic [63:0] ExceptionAddress = HaltAddress + 8;

  localparam logic [11:0] DataAddr = 12'h380;

  typedef enum logic [7:0] {
    Data0        = 8'h04,
    Data1        = 8'h05,
    Data2        = 8'h06,
    Data3        = 8'h07,
    Data4        = 8'h08,
    Data5        = 8'h09,
    Data6        = 8'h0A,
    Data7        = 8'h0B,
    Data8        = 8'h0C,
    Data9        = 8'h0D,
    Data10       = 8'h0E,
    Data11       = 8'h0F,
    DMControl    = 8'h10,
    DMStatus     = 8'h11,
    Hartinfo     = 8'h12,
    HaltSum1     = 8'h13,
    HAWindowSel  = 8'h14,
    HAWindow     = 8'h15,
    AbstractCS   = 8'h16,
    Command      = 8'h17,
    AbstractAuto = 8'h18,
    DevTreeAddr0 = 8'h19,
    DevTreeAddr1 = 8'h1A,
    DevTreeAddr2 = 8'h1B,
    DevTreeAddr3 = 8'h1C,
    NextDM       = 8'h1D,
    ProgBuf0     = 8'h20,
    ProgBuf15    = 8'h2F,
    AuthData     = 8'h30,
    HaltSum2     = 8'h34,
    HaltSum3     = 8'h35,
    SBAddress3   = 8'h37,
    SBCS         = 8'h38,
    SBAddress0   = 8'h39,
    SBAddress1   = 8'h3A,
    SBAddress2   = 8'h3B,
    SBData0      = 8'h3C,
    SBData1      = 8'h3D,
    SBData2      = 8'h3E,
    SBData3      = 8'h3F,
    HaltSum0     = 8'h40
  } dm_csr_t;

  localparam logic [2:0] CauseBreakpoint = 3'h1;
  localparam logic [2:0] CauseTrigger = 3'h2;
  localparam logic [2:0] CauseRequest = 3'h3;
  localparam logic [2:0] CauseSingleStep = 3'h4;

  typedef struct packed {
    logic [31:23] zero1;
    logic         impebreak;
    logic [21:20] zero0;
    logic         allhavereset;
    logic         anyhavereset;
    logic         allresumeack;
    logic         anyresumeack;
    logic         allnonexistent;
    logic         anynonexistent;
    logic         allunavail;
    logic         anyunavail;
    logic         allrunning;
    logic         anyrunning;
    logic         allhalted;
    logic         anyhalted;
    logic         authenticated;
    logic         authbusy;
    logic         hasresethaltreq;
    logic         devtreevalid;
    logic [3:0]   version;
  } dmstatus_t;

  typedef struct packed {
    logic         haltreq;
    logic         resumereq;
    logic         hartreset;
    logic         ackhavereset;
    logic         zero1;
    logic         hasel;
    logic [25:16] hartsello;
    logic [15:6]  hartselhi;
    logic [5:4]   zero0;
    logic         setresethaltreq;
    logic         clrresethaltreq;
    logic         ndmreset;
    logic         dmactive;
  } dmcontrol_t;

  typedef struct packed {
    logic [31:24] zero1;
    logic [23:20] nscratch;
    logic [19:17] zero0;
    logic         dataaccess;
    logic [15:12] datasize;
    logic [11:0]  dataaddr;
  } hartinfo_t;

  typedef enum logic [2:0] {
    CmdErrNone,
    CmdErrBusy,
    CmdErrNotSupported,
    CmdErrorException,
    CmdErrorHaltResume,
    CmdErrorBus,
    CmdErrorOther = 7
  } cmderr_t;

  typedef struct packed {
    logic [31:29] zero3;
    logic [28:24] progbufsize;
    logic [23:13] zero2;
    logic         busy;
    logic         zero1;
    cmderr_t      cmderr;
    logic [7:4]   zero0;
    logic [3:0]   datacount;
  } abstractcs_t;

  typedef enum logic [7:0] {
    AccessRegister = 8'h0,
    QuickAccess    = 8'h1,
    AccessMemory   = 8'h2
  } cmd_t;

  typedef struct packed {
    cmd_t        cmdtype;
    logic [23:0] control;
  } command_t;

  typedef struct packed {
    logic [31:16] autoexecprogbuf;
    logic [15:12] zero0;
    logic [11:0]  autoexecdata;
  } abstractauto_t;

  typedef struct packed {
    logic         zero1;
    logic [22:20] aarsize;
    logic         zero0;
    logic         postexec;
    logic         transfer;
    logic         write;
    logic [15:0]  regno;
  } ac_ar_cmd_t;

  typedef enum logic [1:0] {
    DTM_NOP   = 2'h0,
    DTM_READ  = 2'h1,
    DTM_WRITE = 2'h2
  } dtm_op_t;

  typedef struct packed {
    logic [31:29] sbversion;
    logic [28:23] zero0;
    logic         sbbusyerror;
    logic         sbbusy;
    logic         sbreadonaddr;
    logic [19:17] sbaccess;
    logic         sbautoincrement;
    logic         sbreadondata;
    logic [14:12] sberror;
    logic [11:5]  sbasize;
    logic         sbaccess128;
    logic         sbaccess64;
    logic         sbaccess32;
    logic         sbaccess16;
    logic         sbaccess8;
  } sbcs_t;

  localparam logic [1:0] DTM_SUCCESS = 2'h0;

  typedef struct packed {
    logic [6:0]  addr;
    dtm_op_t     op;
    logic [31:0] data;
  } dmi_req_t;

  typedef struct packed {
    logic [31:0] data;
    logic [1:0]  resp;
  } dmi_resp_t;

endpackage
