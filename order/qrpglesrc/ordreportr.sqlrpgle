**free
// -------------------------------------------------------------------------------------------------
// Program Name : ITMDTLR
// Description  : Program to generate Customer Order Reports.
// Parameters   : None.
// Written By   : Ravisankar Pandian
// Company.     : Programmers.IO
// Date         : 19-07-2023
// -------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------
// Definition of program control statements.
// -------------------------------------------------------------------------------------------------
    ctl-opt option(*nodebugio:*srcstmt:*nounref); // dftactgrp(*no);


// -------------------------------------------------------------------------------------------------
// Procedure definition.
// -------------------------------------------------------------------------------------------------

    dcl-pr get_Cust_info Extproc('GET_CUST_INFO');
      In_Cusno     packed(5);
      Out_Cusnam   Char(30);
      Out_Cuscity  Char(30);
    end-pr;

    dcl-pr get_Item_info Extproc('GET_ITEM_INFO');
      In_ItNum    packed(5);
      Out_ItDesc  Char(30);
      Out_ItPrice packed(5);
    end-pr;

//  dcl-pr write_report;
//  end-pr;
// -------------------------------------------------------------------------------------------------
// Definition of files.
// -------------------------------------------------------------------------------------------------
    dcl-f ORDREPORTD workstn Indds(screen);
    dcl-f ORDREPORTP Printer Oflind(OverFlowInd);
// -------------------------------------------------------------------------------------------------
// Definition of Standalone Variables
// -------------------------------------------------------------------------------------------------
    dcl-s OverFlowInd ind;
    dcl-s  p_Cusno      packed(5) inz;
    dcl-s  p_Cusnam     Char(30) inz;
    dcl-s  p_Cuscity    Char(30) inz;
    dcl-s  p_ItNum      packed(5) inz;
    dcl-s  p_ItDesc     Char(30) inz;
    dcl-s  p_ItPrice    packed(5) inz;

    dcl-s wk_cusno packed(5) inz;
    dcl-s wk_fromdate date inz;
    dcl-s wk_todate date inz;

    dcl-s wk_sqlstmt Varchar(1000)
    Inz('select a.hordno, b.dlinno, b.dcusno, b.ditmno, b.ditmqty, b.dlintot +
         from ordhdrf a left outer join orddtlf b on +
         (a.hordno = b.dordno) where b.dcusno = ? and horddate between ? and ?');

    dcl-s wk_sqlstmt_c varchar(700) inz('select distinct hcusno from ordhdrf order by hcusno');
// -------------------------------------------------------------------------------------------------
// Data Structures
// -------------------------------------------------------------------------------------------------
  dcl-s p_Indicators pointer inz(%addr(*in));
  dcl-ds screen qualified based(p_Indicators);
  exit        ind pos(03);
  refresh     ind pos(05);
  Cust_RI     ind pos(71);
  from_dat_RI ind pos(72);
  to_dat_RI   ind pos(73);
  error_blink ind pos(74);
  end-ds;

  dcl-ds PgmDs psds qualified;
    PgmName   *proc;
    UserName  char(10) pos(254);
  end-ds;

  dcl-ds order qualified inz;
    number   packed(5);
    lineNo   packed(5);
    customer packed(5);
    item     packed(5);
    quantity packed(5);
    total    packed(15);
  end-ds;


// -------------------------------------------------------------------------------------------------
// Definition of Global Constants
// -------------------------------------------------------------------------------------------------
dcl-c TRUE const('1');
dcl-c FALSE const('0');


///
// -------------------------------------------------------------------------------------------------
// Start of Main Logic
// -------------------------------------------------------------------------------------------------
///
*InLr = TRUE;
S_PGMNAME = PgmDs.PgmName;

exec sql SET OPTION COMMIT = *NONE, CLOSQLCSR = *ENDMOD ;

exfmt ordrpt;

dow screen.exit   = FALSE;

  if screen.refresh = TRUE;
    clear screen;
    clear ordrpt;
    S_PGMNAME = PgmDs.PgmName;
    exfmt ordrpt;
    iter;
  endif;


  if validate() = TRUE;
    process_report();
  endif;

  clear ordrpt;
  exfmt ordrpt;

enddo;


return;

// -------------------------------------------------------------------------------------------------
// Validate the screen
// -------------------------------------------------------------------------------------------------
  dcl-proc validate;
    dcl-pi *n char(1);
    end-pi;

    // Standalone variable declaration.
    dcl-s wk_count packed(7) inz;
    dcl-s save_exit char(1) inz;
    dcl-s save_refresh char(1) inz;

    // save the F Key to temp variable before clearning the screen indicators.
    save_exit     = screen.exit;
    save_refresh  = screen.refresh;

    // clear the screen indicators.
    clear screen;
    clear S_ERROR;


    select;
    when S_CUS > *Zeros;
        exec sql select count(1) into :wk_count from ordhdrf where HCUSNO =  :S_CUS;
        if wk_count = *zeros;
            S_ERROR = 'Invalid Customer Number';
            screen.Cust_RI = TRUE;
        endif;

    when S_FROMDATE = *Zeros;
        S_ERROR = 'From date cannot be zeros';
        screen.from_dat_RI = TRUE;

    when S_TODATE = *Zeros;
        S_ERROR = 'To date cannot be zeros';
        screen.to_dat_RI = TRUE;

    when S_FROMDATE > *Zeros and
         S_TODATE   > *Zeros;

        if validate_Date(S_FROMDATE) = FALSE;
          S_ERROR = 'Invalid date entered';
          screen.from_dat_RI = TRUE;
        endif;

        if validate_Date(S_TODATE) = FALSE;
          S_ERROR = 'Invalid date entered';
          screen.to_dat_RI = TRUE;
        endif;

        if S_ERROR = *Blanks;
          if %date(S_FROMDATE: *mdy) > %date(S_TODATE: *mdy);
            S_ERROR = 'From Date cannot be greater than To date';
            screen.from_dat_RI = TRUE;
            screen.to_dat_RI = TRUE;
          endif;
        endif;



    endsl;

    // Restore the Fkey values so that the screen can be exited or refreshed.
    screen.exit = save_exit;
    screen.refresh = save_refresh;

    if S_ERROR = *blanks;
      return TRUE;
    else;
      screen.error_blink = TRUE;
      return FALSE;
    endif;

  end-proc;


// -------------------------------------------------------------------------------------------------
// Process the report
// -------------------------------------------------------------------------------------------------
dcl-proc process_report;
  dcl-s A_cusno packed(5) dim(500) inz;
  dcl-s counter packed(5) inz;

  RDate  =  %Char(%Date()      :*Iso);
  RFrom  =  %Char(%Date(S_FROMDATE:*mdy));
  RTo    =  %Char(%Date(S_TODATE:*mdy));
  Write Title;
  Write Header;

  if S_CUS = *Zeros;
    fetch_customer_number();

    dow SQLSTATE = '00000';

        fetch_this_customer_info();
        write_report();

        Exec Sql Fetch next From cusnocursor Into :S_CUS;
    enddo;
    exec sql close cusnocursor;

  else;
    fetch_this_customer_info();
    write_report();

  endif;

  S_ERROR = 'Report submitted successfully!';

end-proc;


//
// -------------------------------------------------------------------------------------------------
// Validate the date field
// -------------------------------------------------------------------------------------------------
//
  dcl-proc validate_Date;
    dcl-pi *n char(1);
      thisDate packed(6);
    end-pi;

    test(de) *mdy thisDate;
    if (%error);
      return FALSE;
    else;
      return TRUE;
    endif;
  end-proc;

//
// -------------------------------------------------------------------------------------------------
// Procedure to fetch this customer info
// -------------------------------------------------------------------------------------------------
//
dcl-proc fetch_this_customer_info;

  wk_fromdate   = %date(S_FROMDATE: *mdy);
  wk_todate     = %date(S_TODATE: *mdy);

  Exec Sql Prepare QRYC From :wk_sqlstmt;
  Exec Sql Declare cuscursor Sensitive Scroll Cursor For QRYC;
  Exec Sql Open cuscursor Using :S_CUS ,:wk_fromdate, :wk_todate;
  Exec Sql Fetch First From cuscursor Into :order;

end-proc;


//
// -------------------------------------------------------------------------------------------------
// Procedure to write this customer's order details.
// -------------------------------------------------------------------------------------------------
//
dcl-proc write_report;
    dcl-pi *n ;
    end-pi;

  Dow SQLSTATE = '00000';
    RORDNO     = order.number;
    RLINNO     = order.lineNo;
    RCUSNO     = order.customer;
    RITNUM     = order.item;
    RITQTY     = order.quantity;
    RLINTOT    = order.total;
    p_Cusno    = order.customer;
    p_ItNum    = order.item;
    get_Cust_info(p_Cusno: p_Cusnam: p_Cuscity);
    get_Item_info(p_ItNum: p_ItDesc: p_ItPrice);
    RCUSNAM    = p_CusNam;
    RITDESC   = p_ITDesc;
    RITPRICE    = p_ItPrice;
    C_Total  += order.total;
    If OverflowInd = TRUE;
      OverflowInd = FALSE;
      Write Title;
      Write Header;
    EndIf;
    Write Detail;
    Exec Sql Fetch next From cuscursor Into :order;
  Enddo;

  Write Footer;
  Exec Sql Close cuscursor;
end-proc;

//
// -------------------------------------------------------------------------------------------------
// Procedure to fetch this customer info
// -------------------------------------------------------------------------------------------------
//
dcl-proc fetch_customer_number;

  Exec Sql Prepare QRY_Cusno From :wk_sqlstmt_c;
  Exec Sql Declare cusnocursor Scroll Cursor For QRY_Cusno;
  Exec Sql Open cusnocursor;
  Exec Sql Fetch First From cusnocursor Into :S_CUS;

end-proc;
