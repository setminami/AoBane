AoBane The MarkDown Core Engine
======

Powered By BlueFeather 

##What's This and What You Can...
This codes are extended from BlueFeather.<br>
The points of difference are
* You can use font TAG like this-> `*[blablabla](color|font faces#font size)`
  * *e.g.,* `*[blablabla](red|Times,Arial#5) -expand-> <font color="red" face="Times,Arial" size="5">blablabla</font>`
    - And I know that font TAG was duplicated in HTML5...
* You can use MathML by to code LaTeX string surrounding `\{` and `\}`. Use firefox renderer because of MathML specification.
  * like this. `\{x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}\} -expand-> <math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mi>x</mi><mo>=</mo><mfrac><mrow><mo>-</mo><mi>b</mi><mo>&pm;</mo><msqrt><mrow><msup><mi>b</mi><mn>2</mn></msup><mo>-</mo><mn>4</mn><mi>a</mi><mi>c</mi></mrow></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math>`
  
* You can use HTML special character by simple way.

like this
> -- &mdash;

> <=> &hArr;

> => &rArr;

> <= &lArr;

> ||^ &uArr;

> ||/ &dArr;

> <-> &harr;

> -> &rarr;

> <- &larr;

> |^ &uarr;

> |/ &darr;

> `>> &raquo;`

> `<< &laquo;`

> +_ &plusmn;

> != &ne;

> ~~ &asymp;

> ~= &cong;

> <_ &le;

> `>_` &ge;

> |FA &forall;

> |EX &exist;

> (+) &oplus;

> (x) &otimes;

> `\&` &amp;

> (c) &copy;

> (R) &reg;

> (SS) &sect;

> (TM) &trade;

##How to Install
Just try 
`sudo gem install AoBane`
