**free

ctl-opt dftactgrp(*no) bnddir('TEST1BND1');

dcl-pi TEST1PGM1;
  num1  zoned(2:0);
  num2  zoned(2:0);
end-pi;

dcl-pr addnumbers zoned(3:0);
  num1 zoned(2:0);
  num2 zoned(2:0);
end-pr;

dcl-s result zoned(3:0);

result = addnumbers(num1 : num2);

dsply ('sum is ' + %char(result));

*inlr = *on;