AoBane The MarkDown Core Engine
======

Powered By BlueFeather<br> 
See also [AoBane development memo](https://github.com/setminami/AoBane/wiki/development-memo).

##What's This and What You Can...
This codes are extended from BlueFeather.<br>
The points of difference are
* You can use font TAG like this-> `*[blablabla](color|font faces/font size)`
  * *e.g.,* `*[blablabla](red|Times,Arial/5) -expand-> <font color="red" face="Times,Arial" size="5">blablabla</font>`
    - And I know that font TAG was duplicated in HTML5...
* You can use MathML by to code LaTeX string surrounding `\TeX{` and `\TeX}`. Use firefox renderer because of MathML specification.
  * like this. `\TeX{x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}\TeX} -expand-> <math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mi>x</mi><mo>=</mo><mfrac><mrow><mo>-</mo><mi>b</mi><mo>&pm;</mo><msqrt><mrow><msup><mi>b</mi><mn>2</mn></msup><mo>-</mo><mn>4</mn><mi>a</mi><mi>c</mi></mrow></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math>`

* You can use Auto Numbering Title by seaquential '%' anotation.
  * *e.g.*,like below
<pre><code>
{nrange:h2-h5} <- this means header number range is h2-h5.
% foo1 -> <h2 id=xxx>1. foo1</h2>
%% foo1.1 -> <h3 id=xxx>1.1. foo1.1</h3>
%% foo1.2 -> <h3 id=xxx>1.2. foo1.2</h3>
%%% foo1.2.1 -> <h4 id=xxx>1.2.1 foo1.2.1</h4>
% foo2 -> <h2 id=xxx>2. foo2</h2>
......................
</code></pre>

* You can use <div> paling.
  * Write like below:

<pre><code>
|-:b=2 solid gray w=300 rad=10-----------------|
|### foo                                       |
|bar                                           |
|----------------------------------------------|
</code></pre>
This syntax expand like below:
<pre><code>
&lt;div style="border:2px solid gray ; width:300px;border-radius:10px;"&gt;
&lt;h3 id="xxx"&gt;foo&lt;/h3&gt;
bar
&lt;/div&gt;
</code></pre>
  * You have to start with
    - first line |-: and b=[widthof borde line(px)] [Type of line] [Color of line] w=[width(px)] rad=[border radius ratio]--...|
    - second and later lines surround with | and spaces
  * And end with
    - last of border is to write |-...-|
  * Header elements in the box can be hashed and joined as one of Table of Contents 
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

> !in &notin;


##How to Install
Just try 
`sudo gem install AoBane`

## How to use minimum
If you want to write forcely, neglect your .md file's timestamp.
`AoBane --force yourfile.md`
This way is inheritated from BlueFeather.

