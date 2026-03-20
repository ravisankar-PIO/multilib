**free
// -------------------------------------------------------------------------------------------------
// Program Name : ITMDTLR
// Description  : Program to Add/Delete/Update/Display the Item Master file records.
// Parameters   : S2_Mode            Input    Mandatory. Determines if the mode is Add/Delete/Update
//                S2_ItNum           Input    Mandatory. Blanks for Add operation.
//                S2_Operation_Flag  Output   Determines if the operation completed successfully.
//                S2_Exit_Flag       Output   Determines whether user canceled the operation.
// Written By   : Ravisankar Pandian
// Company.     : Programmers.IO
// Date         : 19-07-2023
// -------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------
// Definition of program control statements.
// -------------------------------------------------------------------------------------------------
  ctl-opt option(*nodebugio:*srcstmt:*nounref) dftactgrp(*no);

// -------------------------------------------------------------------------------------------------
// Definition of display file.
// -------------------------------------------------------------------------------------------------
  dcl-f itmdtld workstn Indds(screen);

// -------------------------------------------------------------------------------------------------
// Definition of Procedure Interface a.k.a input parameters
// -------------------------------------------------------------------------------------------------
dcl-pi ITMDTLR;
  S2_mode              char(7);
  S2_Itnum             packed(5);
  S2_operation_flag    char(1);
  S2_exit_flag         char(1);
end-pi;

// -------------------------------------------------------------------------------------------------
// Definition of Standalone Variables
// -------------------------------------------------------------------------------------------------

  dcl-ds PgmDs psds qualified;
    PgmName   *proc;
    UserName  char(10) pos(254);
  end-ds;

  dcl-s D1_ITNUM like(D_ITNUM);
  dcl-s exit_flag char (1) inz('0');

  dcl-s  S2_Itdesc   char(30) inz;
  dcl-s  S2_ItPrice  packed(5) inz;
  dcl-s  S2_ITQty    packed(5) inz;

// -------------------------------------------------------------------------------------------------
// Data Structures
// -------------------------------------------------------------------------------------------------
  dcl-s p_Indicators pointer inz(%addr(*in));
  dcl-ds screen qualified based(p_Indicators);
    exit        ind pos(03);
    cancel      ind pos(12);
    protect     ind pos(70);
    desc_RI     ind pos(71);
    qty_RI      ind pos(72);
    price_RI    ind pos(73);
    error_blink ind pos(74);
  end-ds;
// -------------------------------------------------------------------------------------------------
// Definition of Global Constants
// -------------------------------------------------------------------------------------------------
  dcl-c TRUE const('1');
  dcl-c FALSE const('0');
// -------------------------------------------------------------------------------------------------
// Start of the Main logic
// -------------------------------------------------------------------------------------------------
*inlr = TRUE;
exec sql SET OPTION COMMIT = *NONE, CLOSQLCSR = *ENDMOD ;

move_fields();

exfmt ITDETAIL;

dow screen.cancel = FALSE and
    screen.exit   = FALSE and
    exit_flag     = FALSE;

  if validate_detail() = TRUE;
    exit_flag = process_detail();
  else;
    exfmt ITDETAIL;
  endif;

enddo;

if screen.cancel = TRUE;
  S2_operation_flag = FALSE;
endif;

if screen.exit = TRUE;
  s2_operation_flag = FALSE;
  s2_exit_flag = TRUE;
endif;


return;


// -------------------------------------------------------------------------------------------------
// Validate the detail screen
// -------------------------------------------------------------------------------------------------
dcl-proc validate_detail;
  dcl-pi *n char(1);
  end-pi;

  dcl-c TRUE const('1');
  dcl-c FALSE const('0');

  clear screen; // clear all the indicators and error messages.
  clear D_ERROR;


  if %Trim(s2_mode)   = 'Add' or
     %trim(s2_mode)   = 'Update' or
     %trim(s2_mode)   = 'Copy';

    if D_ITDESC = *blanks;
      screen.desc_RI = TRUE;
      D_ERROR = 'Item Description cannot be blanks';
      return FALSE;
    endif;

    if D_ITPRICE = *zeros;
      screen.price_RI = TRUE;
      D_ERROR = 'Item price cannot be zeros';
      return FALSE;
    endif;

    if D_ITQTY = *zeros;
      screen.qty_RI = TRUE;
      D_ERROR = 'Item quantity cannot be zeros';
      return FALSE;
    endif;

  endif;

  if D_ERROR = *blanks;
    return TRUE;
  endif;

end-proc;


// -------------------------------------------------------------------------------------------------
// Process the detail screen
// -------------------------------------------------------------------------------------------------
dcl-proc process_detail;
  dcl-pi *n char(1);
  end-pi;

  dcl-s date_and_time timestamp;
  dcl-s exitFlag char(1) inz('1');

  date_and_time = %timestamp;

  select;
    when S2_mode = 'Delete';
      D_Error = 'You are about to delete the record. Hit enter to confirm delete.';
      screen.error_blink = TRUE;
      exfmt ITDETAIL;

      if screen.exit or screen.cancel = TRUE;
        S2_operation_flag = FALSE;
        S2_exit_flag = TRUE;

      else;
        exec sql 
          call itmdtl(:D_ITNUM, :D_ITDESC, :D_ITQTY, D_ITPRICE, 
          :PgmDs.UserName, PgmDs.PgmName, :mode, S2_operation_flag);
        
      endif;

    other;
    exec sql 
      call itmdtl(:D_ITNUM, :D_ITDESC, :D_ITQTY, D_ITPRICE, 
      :PgmDs.UserName, PgmDs.PgmName, :mode, S2_operation_flag);

    endsl;


  return (exitFlag);
end-proc;


// -------------------------------------------------------------------------------------------------
// Move values to the Detail Screen
// -------------------------------------------------------------------------------------------------
dcl-proc move_fields;

  D_PGMNAM = PgmDs.PgmName;

  if S2_mode = 'Add';
    Mode = 1;
    exec sql
      select max(itnum)+1 into :D_ITNUM from itmmastf;
    if D_ITNUM = *zeros;
      D_ITNUM = 1;
    endif;

    clear D_ITDESC;
    clear D_ITPRICE;
    clear D_ITQTY;

  else;
    exec sql
      select ITDESC, ITPRICE, ITQTY into :D_ITDESC, :D_ITPRICE, :D_ITQTY
      from ITMMASTF where ITNUM = :S2_ITNum;

    select;
    when S2_mode = 'Copy';
    Mode = 3;
      exec sql
        select max(itnum)+1 into :D_ITNUM from itmmastf;
      if D_ITNUM = *zeros;
        D_ITNUM = 1;
      endif;

    when S2_mode = 'Update';
    Mode = 2; 
      D_ITNUM    = S2_Itnum;

    when S2_mode = 'Delete';
    Mode = 4;
      D_ITNUM    = S2_Itnum;

    when S2_mode = 'Display';
    Mode = 5;
      D_ITNUM    = S2_Itnum;
      screen.protect = TRUE;

    endsl;
  endif;

  evalr d_mode = %trim(S2_mode);

end-proc;
