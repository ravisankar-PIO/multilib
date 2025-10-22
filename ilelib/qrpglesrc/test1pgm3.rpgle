**free

ctl-opt dftactgrp(*no) bnddir('TEST1BND3');

dcl-pr AddNumbers zoned(3:0);
  num1 zoned(2:0);
  num2 zoned(2:0);
end-pr;

dcl-pr DiffNumbers zoned(3:0);
  num1 zoned(2:0);
  num2 zoned(2:0);
end-pr;

dcl-s result zoned(3:0);
dcl-s num1   zoned(2:0) inz(50);
dcl-s num2   zoned(2:0) inz(10);

result = AddNumbers(num1 : num2);
dsply ('Sum is ' + %char(result));

result = DiffNumbers(num1 : num2);
dsply ('Difference is ' + %char(result));
*inlr = *on;
