# AoBane Original classes and functions, and data structures.
# Copyright set.minami (c) 2013
# MIT License

require 'logger'
require 'singleton'

S_SLOT = 0
N_SLOT = 1
C_SLOT = 2
module Utilities

### Return a caluculated section number and string.############################
MAX_H = 6
@@log = Logger.new(STDOUT)
@@log.level = Logger::DEBUG
  def calcSectionNo(startNo, range, size, dep=1, str)
    i = dep.to_i
    counter = 0
    numberStr = [["%",i,counter],["%%",i,counter],["%%%",i,counter],
                 ["%%%%",i,counter],["%%%%%",i,counter],["%%%%%%",i,counter]]
    line = ""
    number = ""
    headNo = startNo.to_i + size -1
    stack = Stack.instance
    if (headNo > MAX_H) || (headNo <= 0) then 
      @@log.error("AoBane Syntax Error: Headder shortage!") 
      raise SyntaxError,"Headder shortage!"
    else
      (1..size).each_with_index{|k| #h1 to h6
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

         #p "### #{stack.evalStackTop[S_SLOT].size} #{numberStr[k-1][S_SLOT].size}"
         if p (stack.evalStackTop[S_SLOT].size < numberStr[k-1][S_SLOT].size) then
           p "==="
           stack.push(numberStr[k])
         elsif p (stack.evalStackTop[S_SLOT].size > numberStr[k-1][S_SLOT].size) then
           p "!!!!"
           stack.pop
           #stack.incSectionNo
         elsif p (stack.evalStackTop[S_SLOT].size == numberStr[k-1][S_SLOT].size) then
           p "----"
           #stack.incSectionNo
         end
         #break
       else
         p "~~~~"
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
    p "$$$$"
    number = stack.insertNumber
    h = "#"
    line = h*headNo.to_i + number + str
    stack.evalStackTop[C_SLOT] += 1
    p stack.dump
    p ">> #{line}"
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
    @sp = 0
  end

  def push(pair)
    @@log.debug("#{__LINE__} push #{pair}")
    if p (@stack.size + 1) < MAX_STACK then
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
    #range = 0..@stack.size 
    @stack.each { |item|
      if item == @stack.last then
        str << (item[N_SLOT] + item[C_SLOT]).to_s + '.'
      else
        str << (item[N_SLOT]).to_s + '.'
      end
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

  def dump
    @@log.debug("Stack DUMP :#{@stack}")
  end

end
