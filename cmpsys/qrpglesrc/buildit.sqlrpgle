**free

// ================================================================
// program: buildit
// purpose: Generic build program for a single library.
//          Takes a library name as parameter and compiles
//          all source members in the correct phase order.
//          Source and object library are the same.
// author:  Programmers.io
// ================================================================
// usage:
//   call pgm(buildit) parm('MYLIB')
// ================================================================
// compilation phases:
//   1. QDDSSRC   - physical files, display files
//   2. QSQLSRC   - sql tables, views, procedures
//   3. QMODSRC   - rpg modules
//   4. QBNDSRC   - service programs (module name = srvpgm name)
//   5. QRPGLESRC - rpg/sqlrpg programs
//   6. QCLLESRC  - cl programs
//   7. QPNLSRC   - panel groups
//   8. QCMDSRC   - command objects
// ================================================================

ctl-opt dftactgrp(*no) actgrp(*new) option(*nodebugio:*srcstmt);

// ----------------------------------------------------------------
// program interface - single parameter: library name
// ----------------------------------------------------------------
dcl-pi *n;
  pLibrary char(10);
end-pi;

// ----------------------------------------------------------------
// external prototypes
// ----------------------------------------------------------------

// write message to job log using ibm api
dcl-pr qp0zlprintf int(10) extproc('Qp0zLprintf');
  message pointer value options(*string: *nopass);
end-pr;

// execute cl command
dcl-pr qcmdexc extpgm('QCMDEXC');
  command char(2000) const options(*varsize);
  commandLen packed(15:5) const;
end-pr;

// ----------------------------------------------------------------
// internal procedure prototypes - phase compilation
// ----------------------------------------------------------------
dcl-pr compilePhysicalFiles int(10);
end-pr;

dcl-pr compileSqlScripts int(10);
end-pr;

dcl-pr compileModules int(10);
end-pr;

dcl-pr compileServicePrograms int(10);
end-pr;

dcl-pr compileRpglePrograms int(10);
end-pr;

dcl-pr compileClPrograms int(10);
end-pr;

dcl-pr compilePanelGroups int(10);
end-pr;

dcl-pr compileCommands int(10);
end-pr;

// ----------------------------------------------------------------
// internal procedure prototypes - utility
// ----------------------------------------------------------------
dcl-pr executeCompile ind;
  cmd varchar(2000) const;
  member char(10) const;
  phase varchar(20) const;
end-pr;

dcl-pr logMsg;
  message varchar(256) const;
end-pr;

dcl-pr logPhaseHeader;
  phaseNum int(10) const;
  phaseName varchar(50) const;
end-pr;

dcl-pr logPhaseSummary;
  processed int(10) const;
  successful int(10) const;
end-pr;

dcl-pr objectExists ind;
  lib char(10) const;
  obj char(10) const;
  objType char(10) const;
end-pr;

dcl-pr sourceFileExists ind;
  lib char(10) const;
  srcFile char(10) const;
end-pr;

dcl-pr trackFailedObject;
  member char(10) const;
  phase varchar(20) const;
end-pr;

dcl-pr displayFinalSummary;
end-pr;

// ----------------------------------------------------------------
// source file name constants
// ----------------------------------------------------------------
dcl-c QDDSSRC   const('QDDSSRC');
dcl-c QSQLSRC   const('QSQLSRC');
dcl-c QMODSRC   const('QMODSRC');
dcl-c QBNDSRC   const('QBNDSRC');
dcl-c QRPGLESRC const('QRPGLESRC');
dcl-c QCLLESRC  const('QCLLESRC');
dcl-c QPNLSRC   const('QPNLSRC');
dcl-c QCMDSRC   const('QCMDSRC');

// ----------------------------------------------------------------
// global variables
// ----------------------------------------------------------------

// resolved library name (trimmed from parameter)
dcl-s gLibrary char(10);

// overall summary counters
dcl-s totalProcessed int(10) inz(0);
dcl-s totalSuccess int(10) inz(0);
dcl-s totalFailed int(10) inz(0);

// failed objects tracking (max 100 failures)
dcl-s failedObjects char(50) dim(100);
dcl-s failedCount int(10) inz(0);

// work variable for building commands
dcl-s gCmd varchar(500) inz;

// ----------------------------------------------------------------
// step 1: validate parameter
// ----------------------------------------------------------------
gLibrary = %trim(pLibrary);

if (gLibrary = '');
  logMsg('error: library name parameter is required');
  logMsg('usage: call buildit parm(''MYLIB'')');
  *inlr = *on;
  return;
endif;

// ----------------------------------------------------------------
// step 2: add library to library list
// ----------------------------------------------------------------
monitor;
  gCmd = ('addlible ' + gLibrary + ' *last');
  qcmdexc(gCmd : %len(gCmd));
on-error;
  // library may already be in the list - continue
  logMsg('note: library ' + gLibrary +
         ' may already be in library list');
endmon;

// ----------------------------------------------------------------
// step 3: log startup information
// ----------------------------------------------------------------
logMsg('========================================');
logMsg('build library: ' + gLibrary);
logMsg('========================================');
logMsg('starting compilation phases...');
logMsg(' ');

// ----------------------------------------------------------------
// step 4: execute compilation phases in order
// ----------------------------------------------------------------

// phase 1: compile physical files and display files
totalProcessed += compilePhysicalFiles();

// phase 2: compile sql scripts
totalProcessed += compileSqlScripts();

// phase 3: compile rpg modules
totalProcessed += compileModules();

// phase 4: compile service programs
totalProcessed += compileServicePrograms();

// phase 5: compile rpgle programs
totalProcessed += compileRpglePrograms();

// phase 6: compile cl programs
totalProcessed += compileClPrograms();

// phase 7: compile panel groups
totalProcessed += compilePanelGroups();

// phase 8: compile command objects
totalProcessed += compileCommands();

// ----------------------------------------------------------------
// step 5: display final summary
// ----------------------------------------------------------------
displayFinalSummary();

*inlr = *on;
return;


// ================================================================
// phase 1: compile QDDSSRC (physical files and display files)
// ================================================================
dcl-proc compilePhysicalFiles;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s srctype char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QDDSSRC));
    return 0;
  endif;

  logPhaseHeader(1 : 'compiling QDDSSRC (physical/display files)');

  // declare cursor to get all members from QDDSSRC
  exec sql declare c_dds cursor for
    select system_table_member, source_type
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QDDSSRC'
      and source_type in ('PF', 'DSPF')
    order by
      case source_type
        when 'PF' then 1
        when 'DSPF' then 2
        else 3
      end,
      system_table_member;

  exec sql open c_dds;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_dds into :member, :srctype;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    srctype = %trim(srctype);
    processed += 1;

    // build compile command based on source type
    if (srctype = 'PF');
      cmd = ('crtpf file(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QDDSSRC +
            ') replace(*yes)');

    elseif (srctype = 'DSPF');
      cmd = ('crtdspf file(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QDDSSRC +
            ') replace(*yes)');
    endif;

    // execute compilation and track result
    if (executeCompile(cmd : member : QDDSSRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_dds;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 2: compile QSQLSRC (sql scripts)
// ================================================================
dcl-proc compileSqlScripts;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QSQLSRC));
    return 0;
  endif;

  logPhaseHeader(2 : 'compiling QSQLSRC (sql scripts)');

  // declare cursor to get all members from QSQLSRC
  exec sql declare c_sql cursor for
    select system_table_member
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QSQLSRC'
    order by system_table_member;

  exec sql open c_sql;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_sql into :member;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    processed += 1;

    // build sql script execution command
    cmd = ('runsqlstm srcfile(' + gLibrary + '/' + QSQLSRC +
          ') srcmbr(' + member +
          ') commit(*none) margins(145) ' +
          'dftrdbcol(' + gLibrary +
          ') dbgview(*source)');

    // execute compilation and track result
    if (executeCompile(cmd : member : QSQLSRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_sql;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 3: compile QMODSRC (rpg modules)
// ================================================================
dcl-proc compileModules;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s srctype char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QMODSRC));
    return 0;
  endif;

  logPhaseHeader(3 : 'compiling QMODSRC (rpg modules)');

  // declare cursor to get all members from QMODSRC
  exec sql declare c_mod cursor for
    select system_table_member, source_type
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QMODSRC'
    order by system_table_member;

  exec sql open c_mod;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_mod into :member, :srctype;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    srctype = %trim(srctype);
    processed += 1;

    // build module creation command based on source type
    if (srctype = 'SQLRPGLE');
      cmd = ('crtsqlrpgi obj(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QMODSRC +
            ') srcmbr(' + member +
            ') objtype(*module) dbgview(*source) replace(*yes)');

    elseif (srctype = 'RPGLE');
      cmd = ('crtrpgmod module(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QMODSRC +
            ') srcmbr(' + member +
            ') dbgview(*source) replace(*yes)');
    else;
      // default to sqlrpgle for unrecognized types
      cmd = ('crtsqlrpgi obj(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QMODSRC +
            ') srcmbr(' + member +
            ') objtype(*module) dbgview(*source) replace(*yes)');
    endif;

    // execute compilation and track result
    if (executeCompile(cmd : member : QMODSRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_mod;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 4: compile QBNDSRC (service programs)
// module name = service program name
// ================================================================
dcl-proc compileServicePrograms;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QBNDSRC));
    return 0;
  endif;

  logPhaseHeader(4 : 'compiling QBNDSRC (service programs)');

  // declare cursor to get all members from QBNDSRC
  exec sql declare c_bnd cursor for
    select system_table_member
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QBNDSRC'
    order by system_table_member;

  exec sql open c_bnd;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_bnd into :member;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    processed += 1;

    // build service program creation command
    // module name is the same as the service program name
    cmd = ('crtsrvpgm srvpgm(' + gLibrary + '/' + member +
          ') module(' + gLibrary + '/' + member +
          ') srcfile(' + gLibrary + '/' + QBNDSRC +
          ') srcmbr(' + member +
          ') replace(*yes)');

    // execute compilation and track result
    if (executeCompile(cmd : member : QBNDSRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_bnd;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 5: compile QRPGLESRC (rpg and sqlrpg programs)
// ================================================================
dcl-proc compileRpglePrograms;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s srctype char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QRPGLESRC));
    return 0;
  endif;

  logPhaseHeader(5 : 'compiling QRPGLESRC (rpg/sqlrpg programs)');

  // declare cursor to get all members from QRPGLESRC
  exec sql declare c_rpgle cursor for
    select system_table_member, source_type
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QRPGLESRC'
      and source_type in ('RPGLE', 'SQLRPGLE')
    order by system_table_member;

  exec sql open c_rpgle;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_rpgle into :member, :srctype;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    srctype = %trim(srctype);
    processed += 1;

    // build compile command based on source type
    if (srctype = 'RPGLE');
      // create bound rpg program
      cmd = ('crtbndrpg pgm(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QRPGLESRC +
            ') dftactgrp(*no) dbgview(*source) replace(*yes)');

    elseif (srctype = 'SQLRPGLE');
      // create sql rpg program
      cmd = ('crtsqlrpgi obj(' + gLibrary + '/' + member +
            ') srcfile(' + gLibrary + '/' + QRPGLESRC +
            ') commit(*none) dbgview(*source) replace(*yes)');
    endif;

    // execute compilation and track result
    if (executeCompile(cmd : member : QRPGLESRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_rpgle;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 6: compile QCLLESRC (cl programs)
// ================================================================
dcl-proc compileClPrograms;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QCLLESRC));
    return 0;
  endif;

  logPhaseHeader(6 : 'compiling QCLLESRC (cl programs)');

  // declare cursor to get all members from QCLLESRC
  exec sql declare c_cl cursor for
    select system_table_member
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QCLLESRC'
    order by system_table_member;

  exec sql open c_cl;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_cl into :member;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    processed += 1;

    // build cl program creation command
    cmd = ('crtbndcl pgm(' + gLibrary + '/' + member +
          ') srcfile(' + gLibrary + '/' + QCLLESRC +
          ') dftactgrp(*no) actgrp(*caller) dbgview(*source)' +
          ' replace(*yes)');

    // execute compilation and track result
    if (executeCompile(cmd : member : QCLLESRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_cl;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 7: compile QPNLSRC (panel groups)
// ================================================================
dcl-proc compilePanelGroups;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s cmd varchar(2000);
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QPNLSRC));
    return 0;
  endif;

  logPhaseHeader(7 : 'compiling QPNLSRC (panel groups)');

  // declare cursor to get all members from QPNLSRC
  exec sql declare c_pnl cursor for
    select system_table_member
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QPNLSRC'
    order by system_table_member;

  exec sql open c_pnl;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_pnl into :member;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    processed += 1;

    // build panel group creation command
    cmd = ('crtpnlgrp pnlgrp(' + gLibrary + '/' + member +
          ') srcfile(' + gLibrary + '/' + QPNLSRC +
          ') replace(*yes)');

    // execute compilation and track result
    if (executeCompile(cmd : member : QPNLSRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_pnl;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// phase 8: compile QCMDSRC (command objects)
// cpp naming convention: member name + 'C'
// if member is 10 chars, replace last char with 'C'
// ================================================================
dcl-proc compileCommands;
  dcl-pi *n int(10) end-pi;

  dcl-s member char(10);
  dcl-s cppProgram char(10);
  dcl-s cmd varchar(2000);
  dcl-s pnlgrpExists ind;
  dcl-s processed int(10) inz(0);
  dcl-s successful int(10) inz(0);

  // skip if source file does not exist in this library
  if (not sourceFileExists(gLibrary : QCMDSRC));
    return 0;
  endif;

  logPhaseHeader(8 : 'compiling QCMDSRC (command objects)');

  // declare cursor to get all members from QCMDSRC
  exec sql declare c_cmd cursor for
    select system_table_member
    from qsys2.syspartitionstat
    where system_table_schema = :gLibrary
      and system_table_name = 'QCMDSRC'
    order by system_table_member;

  exec sql open c_cmd;

  // loop through all members
  dow (1 = 1);
    exec sql fetch c_cmd into :member;
    if (sqlcode <> 0);
      leave;
    endif;

    member = %trim(member);
    processed += 1;

    // derive cpp (command processing program) name
    if (%len(%trim(member)) < 10);
      // append 'C' to the end (e.g., GITINIT -> GITINITC)
      cppProgram = (%trim(member) + 'C');
    else;
      // replace last character with 'C' (e.g., GITCOMMAND -> GITCOMMANC)
      cppProgram = (%subst(member : 1 : 9) + 'C');
    endif;

    // check if a matching panel group exists for help text
    pnlgrpExists = objectExists(gLibrary : member : '*PNLGRP');

    // build command creation command
    if (pnlgrpExists);
      // create command with help panel group
      cmd = ('crtcmd cmd(' + gLibrary + '/' + member +
            ') pgm(' + gLibrary + '/' + %trim(cppProgram) +
            ') srcfile(' + gLibrary + '/' + QCMDSRC +
            ') hlppnlgrp(' + gLibrary + '/' + member +
            ') hlpid(*cmd) replace(*yes)');
    else;
      // create command without help panel group
      cmd = ('crtcmd cmd(' + gLibrary + '/' + member +
            ') pgm(' + gLibrary + '/' + %trim(cppProgram) +
            ') srcfile(' + gLibrary + '/' + QCMDSRC +
            ') replace(*yes)');
    endif;

    // execute compilation and track result
    if (executeCompile(cmd : member : QCMDSRC));
      successful += 1;
      totalSuccess += 1;
    else;
      totalFailed += 1;
    endif;
  enddo;

  exec sql close c_cmd;

  logPhaseSummary(processed : successful);
  return processed;
end-proc;


// ================================================================
// execute a compilation command with error handling
// ================================================================
dcl-proc executeCompile;
  dcl-pi *n ind;
    pCmd varchar(2000) const;
    pMember char(10) const;
    pPhase varchar(20) const;
  end-pi;

  dcl-s success ind inz(*on);

  // execute command with error handling
  monitor;
    qcmdexc(pCmd : %len(pCmd));
    logMsg('  [ok] ' + %trim(pMember) + ' (' + %trim(pPhase) + ')');

  on-error;
    success = *off;
    logMsg('  [failed] ' + %trim(pMember) + ' (' + %trim(pPhase) + ')');

    // track failed object for summary
    trackFailedObject(pMember : pPhase);
  endmon;

  return success;
end-proc;


// ================================================================
// write message to job log
// ================================================================
dcl-proc logMsg;
  dcl-pi *n;
    pMessage varchar(256) const;
  end-pi;

  dcl-c crlf const(x'25');

  qp0zlprintf((pMessage + crlf));
end-proc;


// ================================================================
// log phase header
// ================================================================
dcl-proc logPhaseHeader;
  dcl-pi *n;
    pPhaseNum int(10) const;
    pPhaseName varchar(50) const;
  end-pi;

  logMsg(' ');
  logMsg('----------------------------------------');
  logMsg('phase ' + %char(pPhaseNum) + ': ' + %trim(pPhaseName));
  logMsg('----------------------------------------');
end-proc;


// ================================================================
// log phase summary
// ================================================================
dcl-proc logPhaseSummary;
  dcl-pi *n;
    pProcessed int(10) const;
    pSuccessful int(10) const;
  end-pi;

  dcl-s failed int(10);

  failed = (pProcessed - pSuccessful);

  logMsg('phase complete: ' + %char(pSuccessful) + '/' +
         %char(pProcessed) + ' successful');

  if (failed > 0);
    logMsg('  (' + %char(failed) + ' failed)');
  endif;
end-proc;


// ================================================================
// check if an object exists in the given library
// ================================================================
dcl-proc objectExists;
  dcl-pi *n ind;
    pLib char(10) const;
    pObj char(10) const;
    pObjType char(10) const;
  end-pi;

  dcl-s count int(10);
  dcl-s lib char(10);
  dcl-s obj char(10);
  dcl-s objType char(10);

  lib = pLib;
  obj = pObj;
  objType = pObjType;

  // query system catalog for object existence
  exec sql select count(*)
    into :count
    from table(qsys2.object_statistics(:lib, :objType, :obj));

  if (count > 0);
    return *on;
  else;
    return *off;
  endif;
end-proc;


// ================================================================
// check if a source physical file exists in the library.
// used to skip phases when the source file is not present.
// ================================================================
dcl-proc sourceFileExists;
  dcl-pi *n ind;
    pLib char(10) const;
    pSrcFile char(10) const;
  end-pi;

  dcl-s count int(10);
  dcl-s lib char(10);
  dcl-s srcFile char(10);

  lib = pLib;
  srcFile = pSrcFile;

  // check if the source file object exists
  exec sql select count(*)
    into :count
    from table(qsys2.object_statistics(:lib, '*FILE', :srcFile));

  if (count > 0);
    return *on;
  else;
    return *off;
  endif;
end-proc;


// ================================================================
// track a failed object for the final summary
// ================================================================
dcl-proc trackFailedObject;
  dcl-pi *n;
    pMember char(10) const;
    pPhase varchar(20) const;
  end-pi;

  // add to failed objects array if not full
  if (failedCount < 100);
    failedCount += 1;
    failedObjects(failedCount) = (%trim(pMember) + ' (' +
                                  %trim(pPhase) + ')');
  endif;
end-proc;


// ================================================================
// display final summary of the entire build process
// ================================================================
dcl-proc displayFinalSummary;
  dcl-pi *n end-pi;

  dcl-s i int(10);

  logMsg(' ');
  logMsg('========================================');
  logMsg('compilation process complete');
  logMsg('========================================');
  logMsg('library: ' + gLibrary);
  logMsg('total objects processed: ' + %char(totalProcessed));
  logMsg('successful compilations: ' + %char(totalSuccess));
  logMsg('failed compilations: ' + %char(totalFailed));

  // display failed objects if any
  if (totalFailed > 0);
    logMsg(' ');
    logMsg('failed objects:');
    logMsg('----------------------------------------');

    for i = 1 to failedCount;
      if (%trim(failedObjects(i)) <> '');
        logMsg('  - ' + %trim(failedObjects(i)));
      endif;
    endfor;
  endif;

  logMsg('========================================');

  // set appropriate return status
  if (totalFailed > 0);
    logMsg('status: completed with errors');
  else;
    logMsg('status: all compilations successful');
  endif;

  logMsg('========================================');
end-proc;
