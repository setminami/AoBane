# AoBane Original classes and functions, and data structures.
# Copyright set.minami (c) 2013
# MIT License

require 'logger'
require 'singleton'
require 'date'

$S_SLOT = 0
$N_SLOT = 1
$C_SLOT = 2
$MAX_STACK = 1024 * 2

module Utilities
$MAX_H = 6
@@log = Logger.new(STDOUT)
@@log.level = Logger::WARN

def transformSpecialChar(text)
  #output = text.split("\n")
  specialChar =  {
    "\-\-" => "&mdash;",
    "<=" => "&hArr;",
    "<\->" => "&harr;",
    "\->" =>"&rarr;",
    "<\-" =>"&larr;",
    "=>" => "&rArr;",
    "<=" => "&lArr;",
    "\|\|\^" => "&uArr;",
    "\|\|\/" => "&dArr;",
    "\|\/" => "&darr;",
    "\|\^" => "&uarr;",
    ">>" => "&raquo;",
    "\<\<" => "&laquo;",
    "+_" => "&plusmn;",
    "!=" => "&ne;",
    "~~" => "&asymp;",
    "~=" => "&cong;",
    "<_" => "&le;",
    ">_" => "&ge",
    "\|FA" => "&forall;",
    "\|EX" => "&exist;",
    "\|=" => "&equiv;",
    "\(\+\)" => "&oplus;",
    "\(\-\)" => "&ominus;",
    "\(X\)" => "&otimes;",
    "\(c\)" => "&copy;",
    "\(R\)" =>"&reg;",
    "\(SS\)" => "&sect;",
    "\(TM\)" => "&trade;",
    "!in" => "&notin;"}
  
  entry = '(?!\-+\|)\-\-|<=>|<\->|\->|<\-|=>|<=|\|\^|\|\|\/|\|\/|\^|\>\>|\<\<|' +
    '\+_|!=|~~|~=|>_|<_|\|FA|\|EX|\|=|\(\+\)|\(\-\)|\(X\)|\(c\)|\(R\)|\(SS\)|\(TM\)|!in'
  
  
  
  zoneofPre = ["<pre>","<\/pre>"] 
  dup = []
  doc = text.split("\n")
  index = 0
  doc.each{
    if doc[index] =~ /#{zoneofPre[0]}/i
      until doc[index] =~ /#{zoneofPre[1]}/i
        dup[index] = doc[index]
        index += 1
      end
      dup[index] = doc[index]
    else
      dup[index] = if !doc[index].nil? then doc[index].gsub(/#{entry}/,specialChar) end
      index += 1
    end
  }
  
  #Insert by set.minami
  return dup.join("\n")
end
###Insert Timestamp#################################################################
def insertTimeStamp(text)
  if /\$date/i =~ text then
    text.gsub!(/\$date/i){
      getNowTime
    }
  else text 
  end
end
###get Now Timestamp#################################################################
def getNowTime
  return Time.now.to_s
end

###Abbreviation proccessing##########################################################
  AbbrHashTable = Hash::new
  AbbrPattern = '\*\[(.+?)\]:(.*)\s*$'
def abbrPreProcess(text)
  output = ''
  if text.nil? then return '' end 
  text.lines{ |line|
    if line =~ /\{abbrnote:(.+?)\}/i then #1
      if $1.nil? then '' #1.5
      else 
        File::open($1){|file| #2
          file.each{|line| #3
            if /^#.*\n/ =~ line then
              next
            elsif /#{AbbrPattern}/ =~ line 
              storeAbbr($1,$2)
            end
          } #3
        }
        
      end #1.5
    elsif line =~ /#{AbbrPattern}/ then
      @@log.debug $~
      storeAbbr($1,$2)
    else output << line
    end #
  }
  
  @@log.debug AbbrHashTable
  return output
end #def

def storeAbbr(key,val)
  val = if val.nil? then '' else val end
  AbbrHashTable.store(key,val)
end

def abbrPostProcess(text)
  if AbbrHashTable.size == 0 then return text 
  else
    keywords = AbbrHashTable.keys.join('|')
    text.gsub!(/(#{keywords})/){
      word = if $1.nil? then '' else $1 end
      '<abbr title="' + AbbrHashTable[word] +'">' + word + '</abbr>' 
    }
    return text
  end
end
###paling proccessing##########################################################
StartDivMark = 
  '[\/\|]\-:b=(\d+?)\s(\w+?\s\w+?\s)' + # $1 $2
  '(w=(\w+?)\s)??' +  # $3 $4
  '(h=(\w+?)\s)??' +  # $5 $6
  '(bg=((#)??\w+?)\s)??' + # $7 $8 $9
  '(lh=([\w%]+?)\s)??' + # $10 $11
  '(mg=(\d+?)\s)??' + # $12 $13
  '(al=(\w+?)\s)??' + # $14 $15
  '(rad=(\d+?))\-+[\|\/]' + # $16 $17
  '({(.+?)})??' # $18 $19 
EndDivMark =  '\|\_+\|'
AllChar = '\w\s\!@\#\$%\^&\*\(\)\-\+=\[\{\}\];:\'"<>\,\.\/\?\\|'
InnerRepresent = ["@","/"]

def preProcFence(text,startPoint)
  output = []
  dup = []
  isInFence = [false]
  isInPre = false
  exclude = '(?!^\|_+|\|\-:)^\||^[#]{1,6}\s|^\s+\*|^\s+\-'
  if !text.instance_of?(Array) then output = text.split("\n") else output = text end

  output.each_with_index{|line,index|
    if index < startPoint then next
    elsif /#{StartDivMark}/ =~ line then
      start = line.split("|")
      dup <<  "/" + start[1] + "/" 
      if start.size >= 2 then dup << start[2..-1] end 
      isInFence.push(true)
      next
    elsif /#{EndDivMark}/ =~ line then
      dup << '/@/'
      next
    else 
      if isInFence.last then
        if dup.last.nil? then 
          dup << compressWSpaces(line)
        else 
          if dup.last =~ /#{exclude}/i || line =~ /#{exclude}/i then
            if line =~ /#{exclude}/i then dup << line
            else dup << compressWSpaces(line) end
           else
            if line == "" then 
              dup << '<br />'
            else
              if line =~ /<pre>|<\/pre>/ || isInPre then
                isInPre = true
                dup <<  line
                if line =~ /<\/pre>/ then isInPre = false end
              else
                dup.last << compressWSpaces(line)
              end
              next
            end
          end
        end
      else
        dup << if !line.nil? then line else "" end
      end     
    end
  }
  return dup
end

def compressWSpaces(line)
  dup = if line =~ /\s+$/ then line.strip + " " else line end
  return dup
end


# Pattern to match strong emphasis in Markdown text
BoldRegexp = %r{ (\*\*) (\S|\S.*?\S) \1 }x

# Pattern to match normal emphasis in Markdown text
ItalicRegexp = %r{ (\*) (\S|\S.*?\S) \1 }x

def italic_and_bold(str)
  str.
    gsub( BoldRegexp, %{<strong>\\2</strong>} ).
    gsub( ItalicRegexp, %{<em>\\2</em>} )
end

def isDigit(str)
  if /\d+/ =~ str then 
    return true
  else
    return false
  end
end

def postProcFence(text)
  output = text.split("\n")
  output.each_with_index{|line,index|
    if /#{StartDivMark}/ =~ line then
      output[index] = '<div style="border:' + $1 + 'px ' + $2 + ';' +
        if $4.nil? then '' else 'width:' + if Utilities::isDigit($4) then $4 + 'px;' else $4 + ';'  end end  + 
        if $6.nil? then '' else 'height:' + if Utilities::isDigit($6) then $6 + 'px;' else $6 + ';' end end + 
        if $8.nil? then '' else 'background-color:' + $8 + ';' end + 
        if $11.nil? then 'line-height:100%;' else 'line-height:' + $11 + ';' end +
        if $13.nil? then '' else 'margin:' + $13 + 'px;' end +
        if $15.nil? then '' else 'text-align:' + $15 + ';' end +
        'border-radius:' + 
        if $17.nil? then '' else $17 end + 'px;"' + 
        if $19.nil? then '' else 'class="#{$19}"' end + 
        '>'
      output.each_with_index{|l,i = index|
        if /\/@\// =~ l then
          output[i] = '</div>'
          index = i
          break
        end
        i += 1
      }
    end
  }
  return output.join("\n")
end #def postProcFence

### Initialize a Stack class ############################
  def initNumberStack
    Stack.destroy
  end

### Return a caluculated section number and string.############################
  def calcSectionNo(startNo=1, range=0, size=0, dep=1, str='', outerStack)
    stack = outerStack #Stack.instance
    i = dep.to_i
    counter = 0
    numberStr = [["%",i,counter],["%%",i,counter],["%%%",i,counter],
                 ["%%%%",i,counter],["%%%%%",i,counter],["%%%%%%",i,counter]]
    number = ""
    headNo = size.to_i

    if (headNo > $MAX_H) || (headNo <= 0) then 
      @@log.error("AoBane Syntax Error: Header shortage!") 
      raise SyntaxError,"Headder shortage!"
    else
      (1..headNo).each_with_index{|k| #h1 to h6
        p k
       if (k < headNo) then
         p "+++" # #{k},#{stack.sizeofStack}"
         if k >= stack.size  then
           stack.push(numberStr[k])
         end
       elsif k == headNo then
         p "---"
         if stack.size == 0 then
           stack.push(numberStr[k-1])
         end
         if stack.last[$S_SLOT].size > numberStr[k-1][$S_SLOT].size then
           loop do
             stack.pop
             if stack.last[$S_SLOT].size == numberStr[k-1][$S_SLOT].size then
               break
             end
           end
         end
       else
         p "~~~~"
         stack.push(numberStr[k])
       end #if...elsif 
     }
=begin
    else
      @@log.error("AoBane Syntax Error: Header Number Overflow!")
      raise SyntaxError,"Header Number Overflow!"
    end #case
=end
  end #if...else
    p "$$$$" 
    number = ""
    stack.each { |item|
      if item == stack.last then
        item[$N_SLOT] += item[$C_SLOT]
        item[$C_SLOT] = 1
      end
      number << (item[$N_SLOT]).to_s + '.'
      @@log.debug number
    }
 
    h = "#"
    times = startNo.to_i + size.to_i - 1
  return  h*times + number + str
end #def

module_function:compressWSpaces
module_function:italic_and_bold
module_function:transformSpecialChar
module_function:getNowTime
module_function:insertTimeStamp
module_function:abbrPreProcess
module_function:abbrPostProcess
module_function:storeAbbr
module_function:initNumberStack
module_function:calcSectionNo
module_function:preProcFence
module_function:isDigit
module_function:postProcFence
#############################################################################
end


#####################CLAZ declare############################################
class Stack
  include Singleton

  @@log = Logger.new(STDOUT)
  @@log.level = Logger::WARN

  def initialize
    @stack = []
    @sp = 0
  end

  def push(pair)
    @@log.debug("#{__LINE__} push #{pair}")
    if (@stack.size + 1) < $MAX_STACK then
      @stack.push(pair)
      @sp += 1
      @@log.debug @stack
    else
      raise SyntaxError,"Stack Over Flow!"
    end
  end
  
  def pop
    @@log.debug("#{__LINE__} pop")
    if (@stack.size - 1) >= 0 then @sp -= 1;return @stack.pop
    else
      raise SyntaxError,"Stack Under Flow!"
    end
    @@log.debug "#{@stack}"
  end

  def insertNumber
 #   return str
  end
  
  def evalStackTop
    return @stack.last
  end

  def getSp
    if @sp >= 0 then return @sp
    else raise FatalError,"SP is negative!"
    end
  end

  def sizeofStack
    return @stack.size
  end

  def isTopofStack(item)
    if item == @stack.last then
      return true
    else
      return false
    end
  end

  def self.dump
    @@log.debug("Stack DUMP:#{@stack}")
  end

  def self.destroy
    if @stack.nil? then @stack = [] else @stack.clear end
    p @stack
    @sp = 0
  end

end

