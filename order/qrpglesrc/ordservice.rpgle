**free
// -------------------------------------------------------------------------------------------------
// Program Name : ORDSERVICE
// Description  : Service Program for customer order related operations.
// Parameters   : Refer each procedures below.
// Written By   : Ravisankar Pandian
// Company      : Programmers.IO
// Date         : 19-07-2023
// -------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------
// Definition of program control statements.
// -------------------------------------------------------------------------------------------------
    Ctl-opt Nomain;
    ctl-opt option(*nodebugio:*srcstmt:*nounref); //dftactgrp(*no);

// -------------------------------------------------------------------------------------------------
// Definition of files.
// -------------------------------------------------------------------------------------------------
    dcl-f ORDCUSF   Disk Keyed Usage(*INPUT) Usropn;
    dcl-f itmmastf  Disk Keyed Usage(*INPUT) Usropn;

// -------------------------------------------------------------------------------------------------
// Get_Cust_Info
// -------------------------------------------------------------------------------------------------
    dcl-proc get_Cust_info export;
        dcl-pi get_Cust_info;
            In_Cusno     packed(5);
            Out_Cusnam   Char(30);
            Out_Cuscity  Char(30);
        end-pi;

        Open ORDCUSF;
        Chain (In_Cusno) ORDCUSF;

        If %Found(ORDCUSF);
            Out_Cusnam   = Cusnam;
            Out_Cuscity  = CUSCITY;
        EndIf;

        Close ORDCUSF;
        Return;
    end-proc;

// -------------------------------------------------------------------------------------------------
// Get_Item_Info
// -------------------------------------------------------------------------------------------------
    dcl-proc get_Item_info export;
        dcl-pi get_Item_info;
            In_ItNum     packed(5);
            Out_ItDesc   Char(30);
            Out_ItPrice  packed(5);
        end-pi;

        Open itmmastf;
        Chain (In_ItNum) itmmastf;

        If %Found(itmmastf);
            Out_ITDesc   = ITDESC;
            Out_ItPrice  = ITPRICE;
        EndIf;

        Close itmmastf;
        Return;
    end-proc;
