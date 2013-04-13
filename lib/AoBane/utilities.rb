# AoBane Original classes and functions, and data structures.
# Copyright set.minami (c) 2013
# MIT License

require 'logger'
require 'singleton'

$S_SLOT = 0
$N_SLOT = 1
$C_SLOT = 2
$MAX_STACK = 1024 * 2

module Utilities
$MAX_H = 6
@@log = Logger.new(STDOUT)
@@log.level = Logger::WARN

###paling proccessing##########################################################
$startDivMark = '\|\-:b=(\d+?)\s(\w+?\s\w+?\s)w=(\d+?)\srad=(\d+?)\-+\|'
$endDivMark =  '\|\-+\|'

def prePaling(text)
  output = text.split("\n")
  output.each_with_index{|line,index|
    if /#{$startDivMark}/ =~ line then
    loop do
        index += 1
        if /#{$endDivMark}/ =~ output[index] then
          break
        elsif /^\|(\#{1,6})\s*(.*)\|/ =~ output[index] then
          output[index] = '#'*$1.size + '$2'
        elsif /^\|(.*)\s*\|/ =~ output[index] then
          output[index] = '<p>' + $1 + '</p>'
        end
    end
  end #if
  }
  return output.join("\n")
end #def prePaling

def postPaling(text)
  output = text.split("\n")
  output.each_with_index{|line,index|
    if /#{$startDivMark}/ =~ line then
      output[index] = '<div style="border:' + $1 + 'px ' + $2 + 
                             '; width:' + $3 + 'px;border-radius:' + $4 + 'px;">'
      loop do
        index += 1
        if /#{$endDivMark}/ =~ output[index] then
          output[index] = '</div>'
          break
        end
      end
    end
  }
  return output.join("\n")
end #def postPailing
### Return a caluculated section number and string.############################
  def calcSectionNo(startNo=1, range=0, size=0, dep=1, str='')
    stack = Stack.instance
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
      (1..size).each_with_index{|k| #h1 to h6
        @@log.debug "k #{k},hn #{headNo},s #{size},sN #{startNo},sos #{stack.sizeofStack}"
       if (k < headNo) then
         @@log.debug "+++ #{k},#{stack.sizeofStack}"
         if k >= stack.sizeofStack  then
           stack.push(numberStr[k])
         end
       elsif (k == headNo) then 
         if stack.sizeofStack == 0 then
           stack.push(numberStr[k-1])
         end
         if (stack.evalStackTop[$S_SLOT].size > numberStr[k-1][$S_SLOT].size) then
            stack.pop
         end
       else
         @@log.debug "~~~~"
         stack.push(numberStr[k])
       end #if...elsif 
      stack.dump
     }
=begin
    else
      @@log.error("AoBane Syntax Error: Header Number Overflow!")
      raise SyntaxError,"Header Number Overflow!"
    end #case
=end
  end #if...else
    @@log.debug "$$$$"
    number = stack.insertNumber
    h = "#"
    times = startNo.to_i + size.to_i - 1
  return  h*times + number + str
end #def
 
module_function :calcSectionNo
module_function :prePaling
module_function :postPaling
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
    str = ""
    @stack.each { |item|
      if isTopofStack(item) then
        item[$N_SLOT] += item[$C_SLOT]
        item[$C_SLOT] = 1
      end
      str << (item[$N_SLOT]).to_s + '.'
      @@log.debug str
    }
    return str
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

  def dump
    @@log.debug("Stack DUMP:#{@stack}")
  end

end

