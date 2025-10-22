**Free
ctl-opt nomain;

dcl-proc MultNumbers export;
  dcl-pi *n zoned(3:0);
    num1 zoned(2:0);
    num2 zoned(2:0);
  end-pi;

  dcl-pr addnumbers zoned(3:0);
    num1 zoned(2:0);
    num2 zoned(2:0);
  end-pr;

  dcl-s num3 zoned(3:0);

  num3   = addnumbers(num1 : num2);
  num3 = num3 * 2;

  return num3;

end-proc;

dcl-proc DiffNumbers export;
  dcl-pi *n zoned(3:0);
    num1 zoned(2:0);
    num2 zoned(2:0);
  end-pi;

  dcl-s num3 zoned(3:0);

  num3   = num1 - num2;
  return num3;

end-proc;
