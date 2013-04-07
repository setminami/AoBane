# AoBane Original classes and functions, and data structures.
# Copyright set.minami (c) 2013
# MIT License

require 'logger'
require 'singleton'

S_SLOT = 0
N_SLOT = 1
module Utilities

### Return a caluculated section number.############################
MAX_H = 6
@@log = Logger.new(STDOUT)
@@log.level = Logger::DEBUG
  def calcSectionNo(startNo, range, size, dep=1, str)
    i = dep.to_i
    numberStr = [["%",i],["%%",i],["%%%",i],["%%%%",i],["%%%%%",i],["%%%%%%",i]]
    line = ""
    number = ""
    headNo = startNo.to_i + size -1
    stack = Stack.instance
    if (headNo > MAX_H) || (headNo <= 0) then 
      @@log.error("AoBane Syntax Error: Headder shortage!") 
      raise SyntaxError,"Headder shortage!"
    else
     #k = 0 #??? cannot use each.with_index here?
      numberStr.each_with_index{|item,k| #h1 to h6
        @@log.debug "k #{k},hn #{headNo},s #{size},sN #{startNo},sos #{stack.sizeofStack}"
       if p (k < headNo) then
         p "+++ #{k},#{stack.sizeofStack}"
         if k >= stack.sizeofStack  then
           stack.push(numberStr[k])
         end
       elsif p (k == headNo) then 
         if stack.sizeofStack == 0 then
           stack.push(numberStr[k-1])
         end
         p "### #{stack.evalStackTop[S_SLOT].size} #{numberStr[k-1][S_SLOT].size}"
         if stack.evalStackTop[S_SLOT].size < numberStr[k-1][S_SLOT].size then
           p "==="
           stack.push(numberStr[k])
         elsif stack.evalStackTop[S_SLOT].size > numberStr[k-1][S_SLOT].size then
           p "!!!!"
           stack.pop
           stack.incSectionNo
         elsif stack.evalStackTop[S_SLOT].size == numberStr[k-1][S_SLOT].size then
           p "----"
           number = stack.insertNumber
           #stack.incSectionNo
         end
         break
       else
         p "~~~~"
         stack.push(numberStr[k])
       end #if
      stack.dump
     }
=begin
    else
      @@log.error("AoBane Syntax Error: Header Number Overflow!")
      raise SyntaxError,"Header Number Overflow!"
    end #case
=end
      p ">> #{number}"
      h = "#"
      line = h*size.to_i + number + str
  end #if...else
  return line
end #def
 
module_function :calcSectionNo
end

MAX_STACK = 1024 * 2
class Stack
  include Singleton
  @@log = Logger.new(STDOUT)
  @@log.level = Logger::DEBUG

  def initialize
    @stack = []
  end

  def push(pair)
    @@log.debug("#{__LINE__} push #{pair}")
    if (@stack.size + 1) < MAX_STACK then
      @stack.push(pair)
      @@log.debug "#{@stack}"
    else
      raise SyntaxError,"Stack Over Flow!"
    end
  end
  
  def pop
    @@log.debug("#{__LINE__} pop")
    if (@stack.size - 1) >= 0 then return @stack.pop
    else
      raise SyntaxError,"Stack Under Flow!"
    end
    @@log.debug "#{@stack}"
  end

  def addSectNo(elem)
    loop do
      item = pop
      if elem[S_SLOT] == item[S_SLOT] then
        item[N_SLOT] += 1
        @@log.debug item
        push(item)
        break
      end
    end
  end  


  def insertNumber
    str = ""
    p "$$$$#{@stack.size}"
    #range = 0..@stack.size 
    @stack.each { |item|
      str << item[N_SLOT].to_s + '.' 
      @@log.debug str
    }
    return str
  end
  
  def incSectionNo
    item = @stack.pop
    item[N_SLOT] += 1
    @stack.push(item)
  end

  def evalStackTop
    return @stack.last
  end
  
  def sizeofStack
    return @stack.size
  end

  def dump
    puts("Stack DUMP :#{@stack}")
  end

end
