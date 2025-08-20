**free
// -------------------------------------------------------------------------------------------------
// Program Name : ITMMASTR
// Description  : Program to Maintain the Item Master file records.
// Parameters   : None.
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
  dcl-f itmmastd workstn Indds(subfile) sfile(ITSFL:S_RRN);
  dcl-f itmmastf usage(*update) keyed;

// -------------------------------------------------------------------------------------------------
// External procedures/programs definition.
// -------------------------------------------------------------------------------------------------
dcl-pr goDetail extpgm('ITMDTLR');
  *n   char(7);
  *n   packed(5);
  *n   char(1);
  *n   char(1);
end-pr;

// -------------------------------------------------------------------------------------------------
// Definition of Standalone Variables
// -------------------------------------------------------------------------------------------------

dcl-s position like(S_POSTO);
dcl-s refreshFlag char(1) inz;
dcl-s prevSearch like(S_SEARCH) inz;

dcl-s S2_flag      char(1);
dcl-s s2_exit_flag char(1);

// Array DS to store the subfile options.
dcl-ds sf_array qualified dim(9999) inz;
  item      packed(5);
  option    char(1);
end-ds;

dcl-s array_counter packed(7) inz;

// -------------------------------------------------------------------------------------------------
// Definition of Data Structures
// -------------------------------------------------------------------------------------------------
  dcl-s p_Indicators pointer inz(%addr(*in));
  dcl-ds subfile qualified based(p_Indicators);
    exit        ind pos(03);
    refresh     ind pos(05);
    addIt       ind pos(06);
    cancel      ind pos(12);
    pageup      ind pos(25);
    pagedown    ind pos(26);
    dsp         ind pos(31);
    ctl         ind pos(32);
    clr         ind pos(33);
    isEnd       ind pos(34);
    option_RI   ind pos(61);
    posto_RI    ind pos(62);
    search_RI   ind pos(63);
    nextchange  ind pos(67);
  end-ds;

  dcl-ds PgmDs psds qualified;
    PgmName *proc;
  end-ds;


// -------------------------------------------------------------------------------------------------
// Definition of Global Constants
// -------------------------------------------------------------------------------------------------
  dcl-c TRUE const('1');
  dcl-c FALSE const('0');
  dcl-c PageSize const(5);



// -------------------------------------------------------------------------------------------------
// Start of the Main logic
// -------------------------------------------------------------------------------------------------
*inlr = TRUE;
S_PGMNAM = PgmDs.PgmName;
// Initialize, load and display the Maintenance screen for the first time.
  Initialize();


  dow subfile.exit = FALSE; // Exit the loop if the user takes F3=Exit.

     checkFKey(); // Check any other F-Key is pressed.


    if validate_sf() = TRUE; // Validate the user entered options.
      process_sf(); // and process it.
    endif;

    if refreshFlag = TRUE; // If the record is updated, then force a refresh
      refreshFlag = FALSE;
      refresh();
    endif;
    Display_sf(); // Display the subfile and continue with the loop.

  enddo;


return;

// -------------------------------------------------------------------------------------------------
// Initialize for the first run.
// -------------------------------------------------------------------------------------------------
dcl-proc Initialize;
  Clear_sf();
  clear position;
  SetPointer();
  Load_sf();
  Display_sf();
end-proc;

// -------------------------------------------------------------------------------------------------
// Clear subfile before loading
// -------------------------------------------------------------------------------------------------
dcl-proc Clear_sf;
  subfile.isEnd = FALSE;
  subfile.clr = TRUE;
  write ITCTL;
  subfile.clr = FALSE;
end-proc;

///
// -------------------------------------------------------------------------------------------------
// Process the f-Key first
// -------------------------------------------------------------------------------------------------
///

dcl-proc checkFKey;
  if subfile.refresh = TRUE;
    S_POSTO = *zeros;
    S_ERROR = *blanks;
    S_SEARCH = *blanks;
    clear prevSearch;
    Clear_sf();
    clear position;
    SetPointer();
    Load_sf();
  endif;
end-proc;



// -------------------------------------------------------------------------------------------------
// Load the subfile
// -------------------------------------------------------------------------------------------------
dcl-proc Load_sf;
  subfile.isEnd = FALSE;
  S_RRN = 0;

  read itmmastr;

  dow not %eof(itmmastf);

    if S_SEARCH <> *blanks;
      if %scan(%Upper(%Trim(S_Search)) : %Upper(ITDESC)) > 0;
        moveFields();
      else;
        read itmmastr;
        iter;
      endif;
    else;
      moveFields();
    endif;

    write ITSFL;

    if S_RRN = PageSize;
      // Find whether this is the end-of-file by reading one more record.
      check_eof();

      leave;
    endif;

    read itmmastr;

  enddo;

  // If End of File, then set the subfile is ended.
  if %eof(itmmastf) = TRUE;
    subfile.isEnd = TRUE;
  endif;

end-proc;

// -------------------------------------------------------------------------------------------------
// Move the fields to the screen fields
// -------------------------------------------------------------------------------------------------
dcl-proc moveFields;

dcl-s n packed(7) inz;

  S_RRN           += 1;
  S_ITNUM         = ITNUM;
  S_ITDESC        = ITDESC;
  S_ITPRICE       = ITPRICE;
  S_ITQTY         = ITQTY;

  // Check if we previously saved any options for this item.
  n = %lookup(S_ITNUM: sf_array(*).item : 1);

  if n >= 1;
    S_OPT = sf_array(n).option;
  else;
    clear S_OPT;
  endif;

end-proc;

// -------------------------------------------------------------------------------------------------
// Set the pointer for the record access.
// -------------------------------------------------------------------------------------------------
dcl-proc SetPointer;
  setll (position) itmmastr;
  clear position;
end-proc;

// -------------------------------------------------------------------------------------------------
// Display the subfile.
// -------------------------------------------------------------------------------------------------
dcl-proc Display_sf;

  if S_RRN > 0;
    subfile.dsp = TRUE;
  else;
    subfile.dsp = FALSE;
    write itempty;
    S_ERROR = 'No records found';
  endif;

  write ITFOOTER;
  subfile.ctl = TRUE;
  exfmt ITCTL;
  S_ERROR = *blanks;

end-proc;


// -------------------------------------------------------------------------------------------------
// Validate the Main Subfile
// -------------------------------------------------------------------------------------------------
dcl-proc validate_sf;
  dcl-pi *n char(1);
  end-pi;


  dcl-s isError char(1) inz('0');
  dcl-s savePageUp char(1) inz('0');
  dcl-s savePageDown char(1) inz('0');

  dcl-c TRUE const('1');
  dcl-c FALSE const('0');

  savePageDown = subfile.pagedown;
  savePageUp   = subfile.pageup;


  //clear_subfile_errors();
  subfile.posto_RI  = FALSE;
  subfile.search_RI = FALSE;
  clear_subfile_option_RI();

  // If both position to and search are entered.
  if S_POSTO  <> *zeros and
     S_SEARCH <> *blanks;

    S_ERROR = 'Enter either Position-to or Search field';
    subfile.posto_RI  = TRUE;
    subfile.search_RI = TRUE;
    return FALSE;
    isError = TRUE;
  endif;

  // Validate the subfile options.

  if S_RRN >0;
    readc ITSFL;



    dow %eof(itmmastd) = FALSE;
        subfile.nextchange = TRUE;

        if S_OPT <> '2' and
          S_OPT <> '3' and
          S_OPT <> '4' and
          S_OPT <> '5' and
          S_OPT <> ' ';
          subfile.option_RI = TRUE;
          isError = TRUE;
        endif;

          update ITSFL;
          subfile.nextchange = FALSE;
        readc ITSFL;
      enddo;

  endif;
  subfile.pagedown = savePageDown;
  subfile.pageup   = savePageUp;
  if isError = FALSE;
    return TRUE;
  else;
    return FALSE;
  endif;
end-proc;

// -------------------------------------------------------------------------------------------------
// Process the user input
// -------------------------------------------------------------------------------------------------
dcl-proc process_sf;

  select;

  when subfile.refresh = TRUE;
    S_POSTO = *zeros;
    S_ERROR = *blanks;
    S_SEARCH = *blanks;
    clear prevSearch;
    clear sf_array;
    Clear_sf();
    clear position;
    SetPointer();
    Load_sf();

  when subfile.pagedown = TRUE and
       subfile.isEnd = TRUE;
    return;

  when subfile.pagedown = TRUE;
    backup_options(); // backup the options to the array to process later
    Clear_sf();
    Load_sf();

  when subfile.pageup = TRUE;
    backup_options(); // backup the options to the array to process later
    Determine_pos();
    Clear_sf();
    SetPointer();
    Load_sf();

  when S_POSTO > 0;
    position = S_POSTO;
    clear S_POSTO;
    Clear_sf();
    SetPointer();
    Load_sf();

  when S_SEARCH <> *blanks and
  S_SEARCH <> prevSearch;
    prevSearch = S_SEARCH;
    Clear_sf();
    clear position;
    SetPointer();
    Load_sf();

  other;
    backup_options(); // backup the options to the array to process later
    process_option(); // and finally, process those options from the array.
  endsl;
end-proc;

// -------------------------------------------------------------------------------------------------
// Determine the position of the pointer
// -------------------------------------------------------------------------------------------------
dcl-proc Determine_pos;
  dcl-s n packed(2) inz;
  dcl-s endpoint packed(2) inz;
  dcl-s filterCounter packed(2) inz;

    // If the current page is full, then the previous page must also be full.
    // So place the pointer to the previous page's 1st record.
    if S_RRN = PageSize;
      endpoint = 2 * pagesize;

    // If the current page is not full, i.e. then place the pointer accordingly
    // to the previous page.
    else;
      endpoint = PageSize + S_RRN;
    endif;

  select;

  when S_SEARCH <> *blanks;
    // If search filter is applied, then display only the filtered page.
    setgt (itnum) itmmastr;

    dou filterCounter = endpoint;
      readp itmmastr;
      if %scan(%Upper(%Trim(S_Search)) : %Upper(ITDESC)) > 0;
        filterCounter += 1;
      endif;

      if %eof(itmmastf) = TRUE;
        leave;
      endif;
    enddo;

  when S_SEARCH = *blanks;
    // If no search filter is applied, simply display the previous page.
    setgt (itnum) itmmastr;
    for n = 1 to endpoint;
      readp itmmastr;
    endfor;
  endsl;

  position = ITNUM;
end-proc;


dcl-proc clear_subfile_errors;

  subfile.posto_RI  = FALSE;
  subfile.search_RI = FALSE;


  if S_RRN >0;
    readc ITSFL;
  endif;

  dow %eof(itmmastd) = FALSE;
    subfile.nextchange = TRUE;
    subfile.option_RI = FALSE;
    update ITSFL;
    subfile.nextchange = FALSE;
    readc ITSFL;
  enddo;
end-proc;


// -------------------------------------------------------------------------------------------------
// Reload the current page.
// -------------------------------------------------------------------------------------------------
dcl-proc refresh;
    clear S_POSTO;
    clear S_SEARCH;
    clear sf_array;
    clear_sf();
    clear position;
    SetPointer();
    Load_sf();
end-proc;

// -------------------------------------------------------------------------------------------------
// Process Option
// -------------------------------------------------------------------------------------------------
dcl-proc process_option;

  dcl-s s2_mode char(7) inz;
  dcl-s S2_ITNUM packed (5) inz;
  dcl-s counter int(5) inz;

  clear S2_flag;
  clear s2_exit_flag;

  if subfile.addIt  = TRUE;
    subfile.addIt   = FALSE;
    s2_mode = 'Add';
    goDetail(S2_mode:S2_ITnum:s2_flag:S2_exit_Flag);
    if S2_flag = TRUE; // If any record is updated, then we need to reload the subfile.
      refreshFlag = TRUE;
    else;
      refreshFlag = FALSE;
    endif;

  else;
    sorta %subarr(sf_array(*).item:1:9999);

    for counter = 1 to 9999;
      if sf_array(counter).item > 0;

        select;
        when sf_array(counter).option = '2';
          S2_ITNum = sf_array(counter).item;
          s2_mode = 'Update';
          goDetail(S2_mode:S2_ITnum:s2_flag:S2_exit_Flag);
          exsr clear_this_subfile_option;

        when sf_array(counter).option = '3';
          S2_ITNum = sf_array(counter).item;
          s2_mode = 'Copy';
          goDetail(S2_mode:S2_ITnum:s2_flag:S2_exit_Flag);
          exsr clear_this_subfile_option;

        when sf_array(counter).option = '4';
          S2_ITNum = sf_array(counter).item;
          s2_mode = 'Delete';
          goDetail(S2_mode:S2_ITnum:s2_flag:S2_exit_Flag);
          exsr clear_this_subfile_option;

        when sf_array(counter).option = '5';
          S2_ITNum = sf_array(counter).item;
          s2_mode = 'Display';
          goDetail(S2_mode:S2_ITnum:s2_flag:S2_exit_Flag);
          exsr clear_this_subfile_option;

        endsl;

      else;
        //leave;

      endif;

    endfor;


  endif;

// Clear the current subfile option, if record processed successfully

  begsr clear_this_subfile_option;

    if s2_exit_flag <> TRUE or
    sf_array(counter).option = '5';
      clear sf_array(counter);
    endif;

    if S2_flag = TRUE; // If any record is updated, then we need to reload the subfile.
      refreshFlag = TRUE;
    else;
      refreshFlag = FALSE;
    endif;

  endsr;

end-proc;




// -------------------------------------------------------------------------------------------------
// Clear all the RI of subfile options before performing validation.
// -------------------------------------------------------------------------------------------------
dcl-proc clear_subfile_option_RI;

  if S_RRN > 0;
    readc ITSFL;
    dow %eof(itmmastd) = FALSE;

      subfile.nextchange = TRUE;
      clear subfile.option_RI;
      update ITSFL;
      subfile.nextchange = FALSE;
      readc ITSFL;

    enddo;
  endif;


end-proc;

// -------------------------------------------------------------------------------------------------
// When pressed PAGEUP/PAGEDOWN, save the subfile options in an array for later use.
// -------------------------------------------------------------------------------------------------
dcl-proc backup_options;
dcl-s n packed(7) inz;

  if S_RRN > 0;
    readc ITSFL;
    dow %eof(itmmastd) = FALSE;

      subfile.nextchange = TRUE;

      // Check if we previously saved the option against this item.
      n = %lookup(S_ITNUM: sf_array(*).item : 1);

      select;
        when n > 0 and S_OPT = *blanks; // If the user cleared the option, then remove it from array
          clear sf_array(n);

        when n > 0 and S_OPT <> *blanks; // If previously saved and the option has been edited, then
          if S_OPT <> sf_array(n).option;
            sf_array(n).option = S_OPT;
          endif;

        when n = 0;
        array_counter += 1;
        sf_array(array_counter).item    = S_ITNUM;
        sf_array(array_counter).option  = S_OPT;

      endsl;

      clear S_OPT;
      update ITSFL;
      subfile.nextchange = FALSE;
      readc ITSFL;

    enddo;
  endif;

end-proc;


// -------------------------------------------------------------------------------------------------
// Find whether this is the actual EOF or not.
// -------------------------------------------------------------------------------------------------
dcl-proc check_eof;
  dcl-s wk_ItNum like(ITNUM) inz;

  wk_ItNum = ITNUM;
  read itmmastr;

  // If we have a search filter applied.
  if S_SEARCH <> *blanks;

    dow not %eof(itmmastf);
      if %scan(%Upper(%Trim(S_Search)) : %Upper(ITDESC)) > 0;
        setgt (wk_ItNum) itmmastr;
        return;
      endif;
      read itmmastr;
    enddo;

  // If we don't have a search filter applied.
  else;

    read itmmastr;
    if %eof(itmmastf) = TRUE;
      return;
    else;
      setll (wk_ItNum) itmmastr;
    endif;

  endif;

end-proc;
