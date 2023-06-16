//Copyright 2023 South Arm Technology Services Ltd.
//Minghui Yu myu@southarm.ca
//Use at your own risk. No support.

event inq:1

var logPath: A30
//only setting to change, depending on your micros res 3700 installation path
logPath = "\micros\res\pos\etc\"

//that's it. no need to change codes below.

var h_sql : N12 = 0
var chk_num: N5
var chk_seq: N12
var queryReturn[4] : a15

call load_sql
call connect_sql

Input chk_num, "Enter Check Number"


call verify_chk(chk_num)
call force_close_chk (chk_num)

var msgstring : A200
Format msgstring as "Force close check number is ", queryReturn[1],"; amount is ", queryReturn[4]
//Format msgstring as "this is a test"
call WriteLog(msgstring)

endevent

sub load_sql
   if h_sql = 0
      DLLLoad h_sql, "MDSSysUtilsProxy.dll"
   endif
   if h_sql = 0
      exitwitherror "Unable to Load MDSSysUtilsProxy.dll"
   endif
endsub

sub connect_sql
   var constatus : N9
   // Connect to micros 3700 database
   DLLCALL_CDECL h_sql, sqlIsConnectionOpen(ref constatus)
   if constatus = 0
      DLLCALL_CDECL h_sql, sqlInitConnection("micros","ODBC;UID=custom;PWD=custom", "")
   endif
endsub

sub sql_exec_cmd(ref sql_cmd )
   var logPath_local: A125

   // intended for single selects from the db where one row is expected
   // of course you could always do a sqlGetNext and keep going

   var fn : N12 = 0
   // pass by value. if pass by ref, the delete function will generate [SAP][ODBC Driver]Invalid cursor state error
   DLLCALL_CDECL h_sql, sqlGetRecordSet(sql_cmd)
   sql_cmd = ""
   DLLCALL_CDECL h_sql, sqlGetLastErrorString(sql_cmd)

      if (sql_cmd <> "")
         call show_error(sql_cmd)
         errormessage "SQL Exec Error:", sql_cmd
         format logPath_local as logPath,"sqlerror.txt"
         fopen fn, logPath_local,append
         fwrite fn, sql_cmd
         fclose fn
      endif

   DLLCALL_CDECL h_sql, sqlGetNext(ref sql_cmd)

endsub


sub verify_chk (var chk_num_local : N5)
   var sql_cmd : A1024
   format sql_cmd as "select micros.chk_dtl.chk_num as chk_num, micros.emp_def.last_name as last_name, micros.emp_def.first_name as first_name, micros.chk_dtl.amt_due_ttl as amt_due_ttl from micros.chk_dtl join micros.emp_def on micros.chk_dtl.emp_seq = micros.emp_def.emp_seq where chk_open='T' and chk_num =",chk_num_local

   call sql_exec_cmd(sql_cmd)
   if (sql_cmd = "" OR sql_cmd = 0)
     InfoMessage "Check Verify Error", "Cannot find the check"
     return
   endif

   split sql_cmd, ";", queryReturn[1],queryReturn[2],queryReturn[3],queryReturn[4]

   window 7,60
   display 1, 20, "Verify check information below"
   display 2,10, "Check number:",queryReturn[1]
   display 3,10, "Check employee last name:",queryReturn[2]
   display 4,10, "Check employee first name:",queryReturn[3]
   display 5,10, "Check dollar amount:",queryReturn[4]
   display 6,20, "Press ENTER to close the check"
   display 7,20, "Press CLEAR to exit"
   windowedit
   waitforconfirm

endsub

sub force_close_chk (var chk_num_local : N5)

   var filehandle : N12 = 0
   var sql_cmd : A512
   var logPath_local: A125

   format sql_cmd as "select chk_seq from micros.chk_dtl where chk_open = 'T' and chk_num= ",chk_num_local

   call sql_exec_cmd(sql_cmd )
   chk_seq = sql_cmd

   var sql_cmd2 : A512
   var filehandle2 : N12 = 0

   format sql_cmd2 as "call micros.sp_ForceChkClose(",chk_seq,")"

   format logPath_local as logPath,"sql_forceclosecheck_log.txt"
   fopen filehandle2, logPath_local,append

   fwrite filehandle2 , @tremp,@Year, @Month,@Day,@Hour,@Minute,chk_num_local,sql_cmd2 
   fclose filehandle2 

   call sql_exec_cmd(sql_cmd2)
endsub

sub show_error( var sql_cmd : A780 )

var i : N10
var error_line[10] : A78
window 12, 78

for i = 1 to 10
   format error_line[i] as mid(sql_cmd, (i - 1) * 78 + 1, (( i - 1) * 78) + 77)
   display i, 1, error_line[i]
endfor

waitforclear

endsub

Sub WriteLog(ref message)
  DLLCALL_CDECL h_sql, SU_Log_Init(ref message)
  DLLCALL_CDECL h_sql, SU_Log(ref message, "Force Close", 0)
  DLLFree h_sql

EndSub

