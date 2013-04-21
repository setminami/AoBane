AoBane The MarkDown Core Engine
======

Powered By BlueFeather<br> 
See also [AoBane Syntax](https://github.com/setminami/AoBane/wiki/Details-of-AoBane-Syntax).

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

> (c) &copy;

> (R) &reg;

> (SS) &sect;

> (TM) &trade;

> !in &notin;

<h2> 2.6 Table Caption</h2>
Do you want to insert a caption to &lt;table&gt;? You can insert in AoBane. <br>
Like this:<br>
<pre><code>
[foo]{#bar}
|fruits|price
|------|-----
|Apple|$0.5
|Orange|$0.3
</code></pre>
the first line [foo]{#bar} and this table, expands HTML as below:<br>
<pre><code>
&lt;table id="#bar"&gt;
&lt;caption&gt;foo&lt;/caption&gt;
	&lt;thead&gt;&lt;tr&gt;
		&lt;th&gt;fruits&lt;/th&gt;
		&lt;th&gt;price&lt;/th&gt;
	&lt;/tr&gt;&lt;/thead&gt;
	&lt;tbody&gt;
		&lt;tr&gt;
			&lt;td&gt;Apple&lt;/td&gt;
			&lt;td&gt;$0.5&lt;/td&gt;
		&lt;/tr&gt;
		&lt;tr&gt;
			&lt;td&gt;Orange&lt;/td&gt;
			&lt;td&gt;$0.3&lt;/td&gt;
		&lt;/tr&gt;
	&lt;/tbody&gt;
&lt;/table&gt;
</code></pre>
The "#bar" is adapted to table id, and "foo" is surrounded by &lt;captin&gt; and &lt;/caption&gt; as elements in following table. When you put caption to a table, you should write `[Table 1](#Table1)` somewhere in your Markdown. So, you can jump to a table from the link. <br>
Of course, you can omit this.

<h2> 2.7 Abbreviation </h2>
Especially for not ASCII languagers, I need to study some more, perhaps about morphorogical analysis. So, if you use this function, you have to be careful.

This function is implementation of [Abbreviations](http://michelf.ca/projects/php-markdown/extra/#abbr) specifies in PHP Markdown Extra. And my some Idea which can make a UTF-8 textfile as other file definitions of abbreviation is implemented. In this case, Markdown is wrote like this:
<pre><code>
{abbrnote:./dicSample.txt}
......
</code></pre>
And dicSample.txt in same directory with Markdown&mdash;you can name as you like&mdash;is like below:
<pre><code>
*[foo1]:bar
*[foo2]:barbar
*[foo3]:barbarbar
......
</code></pre>
Because I set as this, you can create individual word set about your each Markdown files.And you may write like as:  
<pre><code>
{abbrnote:../share/dicSample.txt}
......
*[foo0]:foo
</code></pre>
And ../share/dicSample.txt is
<pre><code>
*[foo1]:bar
*[foo2]:barbar
*[foo3]:barbarbar
......
</code></pre>
If You created files like this, you can controll a word set. For instance, foo0 is adapted only the above Markdown file, and foo1, foo2, foo3,...is adopted all Markdown files which is wrote <code>{abbrnote:../share/dicSample.txt}</code>. 

Of course, you can use like PHP Markdown Extra. Incidentally,this function is not implemented on BlueFeather.

##How to Install
Just try 
`sudo gem install AoBane`

## How to use minimum
If you want to write forcely, neglect your .md file's timestamp.
`AoBane --force yourfile.md`
This way is inheritated from BlueFeather.

