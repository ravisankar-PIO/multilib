-- --------------------------------------------------------------------------//
-- Created By.......: Programmers.io @ 2023                                  //
-- Create Date......: 2023/09/05                                             //
-- Developer........: Ravisankar Pandian                                     //
-- Description......: Update ITMMASTF table                                  //
-- -----------------------------------------------------------------------------
-- MODIFICATION LOG:
-- -----------------------------------------------------------------------------
-- Date    | Mod_ID | Developer  | Case and Description
-- --------|--------|------------|----------------------------------------------
--         |        |            |
-- -----------------------------------------------------------------------------
-- Compilation Instruction
-- -----------------------------------------------------------------------------
-- RUNSQLSTM SRCFILE(RAVISANKAR/QSQLSRC) SRCMBR(ITMDTL)
-- COMMIT(*NONE) DFTRDBCOL(RAVISANKAR)
-- -----------------------------------------------------------------------------
Create Or Replace Procedure Itmdtl
(

    In  Item_Num    int,
    In  Item_Des    char(50),
    In  Item_Qty    numeric(5),
    In  Item_Prc    numeric(6),
    In  User_Nam    char(10),
    In  Prog_Nam    char(10),
    In  Mode        numeric(1),
    Out Opr_Flag    char(1)  

)



Language SQL
Result Sets 0
Modifies SQL Data
Specific Itmdtl
-- Program type sub



--  ------------------------------------------------------------------
--  * SQL COMPILE OPTIONS                                            *
--  ------------------------------------------------------------------

 SET OPTION  DATFMT = *ISO,
  DLYPRP = *YES,
  DBGVIEW = *SOURCE,
  USRPRF = *OWNER,
  DYNUSRPRF = *OWNER,
  COMMIT = *NONE

Begin
-- -----------------------------------------------------------------
-- *DECLATATIONS                                                   *
-- -----------------------------------------------------------------
    Declare w_sql       varchar(2000) default ' ';
    Declare w_Error     varchar(1000) default ' ';
    Declare success condition for sqlstate '38001';

    Declare Exit Handler for SqlException 
    Begin
        case Mode
            when 1 then
            set w_Error = 'Error During Add';
    
            When 3 then
            set w_Error = 'Error During Copy';
            
            When 4 then
            set w_Error = 'Error During Delete';

            else
            set w_error = 'Unknown';
    
        end case;
        Insert into SQLERRLOG Values(Prog_Nam, User_Nam, w_sql, current_timestamp);
    End;


    Declare Continue Handler for success 
    Begin
        Insert into SQLERRLOG Values(Prog_Nam, User_Nam, w_sql, current_timestamp);
    End;
    -------------------------------------------------------------------
    -- *MAIN LOGIC OF PROGRAM                                          *
    ------------------------------------------------------------------- 

    Case Mode
        When 1 then
            set w_sql =       'Insert into ITMMASTF Values ('
                        ||          trim(char(Item_Num))     || ', '''
                        ||   Item_Des || ''' , '
                        ||          trim(char(Item_Qty))      || ', '
                        ||          trim(char(Item_prc))      || ', '''
                        ||   User_Nam || ''' , '  
                        ||          'current_Timestamp'      || ', '''
                        ||   Prog_Nam || ''' , ''' 
                        ||   User_Nam || ''' , '  
                        ||          'current_Timestamp'      || ', '''
                        ||   Prog_Nam || ''' )' ; 
            signal sqlstate '38001';


        When 3 then
            set w_sql =       'Insert into ITMMASTF Values ('
                        ||          trim(char(Item_Num))     || ', '''
                        ||   Item_Des || ''' , '
                        ||          trim(char(Item_Qty))      || ', '
                        ||          trim(char(Item_prc))      || ', '''
                        ||   User_Nam || ''' , '  
                        ||          'current_Timestamp'      || ', '''
                        ||   Prog_Nam || ''' , ''' 
                        ||   User_Nam || ''' , '  
                        ||          'current_Timestamp'      || ', '''
                        ||   Prog_Nam || ''' )' ; 
            signal sqlstate '38001';           

        When 2 then 
            set w_sql =       'Update ITMMASTF Set'
                        || 'ITDESC = ''' || Item_Des         || ''' , ' 
                        || 'ITQTY = '       ||          trim(char(Item_Qty))      || ', '
                        || 'ITPRICE = '     ||          trim(char(Item_prc))      || ', '
                        || 'UPUSR = '''  || User_Nam         || ''' , '  
                        || 'UPDAT = '       ||          'current_Timestamp'      || ', '
                        || 'UPPGM = '''  || Prog_Nam         || ''' '
                        || 'Where ITNUM = ' ||          trim(char(Item_Num))     || ')';
            signal sqlstate '38001';
    
        When 4 then
            set w_sql =       'Delete from ITMMASTF ' 
                        || 'Where ITNUM = ' ||          trim(char(Item_Num))     || ')';
            signal sqlstate '38001';
        else 
            set Opr_Flag = '0'; 
    End Case;


   
End; 