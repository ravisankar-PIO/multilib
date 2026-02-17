**Free
ctl-opt nomain;

dcl-proc addnumbers export;
  dcl-pi addnumbers zoned(3:0);
    num1 zoned(2:0);
    num2 zoned(2:0);
  end-pi;

  dcl-s num3 zoned(3:0);

  num3 = num1 + num2;
  return num3;

end-proc;