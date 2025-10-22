**FREE
ctl-opt Nomain;

dcl-proc AddNumbers export;
  dcl-pi *n;
    Num1 int(10);
    Num2 int(10);
    Result int(10);
  end-pi;

  Result = Num1 + Num2;

end-proc;
