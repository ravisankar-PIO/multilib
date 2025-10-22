**FREE

dcl-pr AddNumbers extproc('ADDNUMBERS');
  Num1 int(10);
  Num2 int(10);
  Result int(10);
end-pr;

dcl-s Num1 int(10) inz(25);
dcl-s Num2 int(10) inz(75);
dcl-s Result int(10);

AddNumbers(Num1:Num2:Result);
dsply ('The result is: ' + %char(Result));

*Inlr = *On;
