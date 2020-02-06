# Copyright (c) 2019 hiratake26to. All rights reserved.
# 
# This work is licensed under the terms of the MIT license.  
# For a copy, see <https://opensource.org/licenses/MIT>.
require 'json'
require 'fileutils'

# util
Result = Struct.new("Result", :result, :value) do
  def bind
    return self unless block_given?
    if (self[:result]) then
        value = yield(self[:value])
        return Result.new(!!value, value)
    else
        return self
    end
  end
end

class PackUtil
  class << self
    def getValue(file, key)
      result=false
      value=nil
      if !File.exist?(file) then
        return Result.new(result, value)
      end
      File.open(file, "r") { |f|
        jconf = JSON.load(f)
        value=jconf[key]
      }
      if (value) then result = true end
      return Result.new(result, value)
    end
  end
end

# test
=begin
p PackUtil.getValue('', 'entry')
p PackUtil.getValue('./test/tgim-pack.config.json', 'dummy')
p PackUtil.getValue('./test/tgim-pack.config.json', 'entry')
=end

# test bind
=begin
  res = PackUtil.getValue('./test/tgim-pack.config.json', 'entry')
  res = res.bind {|val|
    puts "call1 val:#{val}"
    next val+"1"
  }.bind {|val|
    puts "call2 val:#{val}"
    next val+"2"
  }.bind {|val|
    puts "call3 val:#{val}"
    # dont next
    #next val+"3"
  }.bind {|val|
    puts "call4 val:#{val}"
    next val+"4"
  }
  puts "result: #{res}"
=end
