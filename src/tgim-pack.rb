# tgim'packager
#
# resolve files to load from entry file
# 
# run generator, and get output files(.hpp)
#
# generate main file
# * including file
#   - ns-3 libraries
#   - UDA libraries
#   - outputed files from TGIM
# * define main function
#   - parse command line arguments (optional)
#   - decleare network
#   - build network
#   - install application of network
#   - set logging (optional)
#   - simulator ready
#   - simulator start
#   - simulator destroy

require 'config'
require 'packager'
require 'json'

require 'thor'
class TgimPackCli < Thor
  desc 'init', 'Create package config file'

  def init
    if File.exist?(DEFAULT_CONFIG_FILE_NAME) then
      puts "Package config file already exists."
      exit(0)
    end
    #STDERR.puts('Could not create new file.')
    # TODO: Add interrupt mode
    File.open(DEFAULT_CONFIG_FILE_NAME, "w") do |f|
      f.puts <<~JSON
        {
          "entry": "",
          "output": "",
          "loader": "",
          "target": ""
        }
      JSON
    end
    puts("Writing new package config file to ./#{DEFAULT_CONFIG_FILE_NAME}.")
    exit(0)
  end

  desc 'pack [<config.json>]', 'Package according to the configuration file'
  def pack(file=false)
    package file
  end

  # configure
  desc 'config <key> [<value>]', 'Update config'
  def config(key, value=nil)
    if !File.exist?(DEFAULT_CONFIG_FILE_NAME) then
      puts "Package config file not exists."
      exit(0)
    end

    if (value) then
      jconf = nil
      File.open(DEFAULT_CONFIG_FILE_NAME, "r") { |f|
        jconf = JSON.load(f)
      }

      c = jconf

      a = key.split('.')
      a.each {|key|
        if !c[key].is_a? Hash then
          c[key] = {}
        end
        c = c[key]
      }

      eval('jconf'+ '["'+a.join('"]["')+'"]' + " = '#{value}'")

      File.open(DEFAULT_CONFIG_FILE_NAME, "w") { |f|
        f.puts JSON.pretty_generate(jconf)
      }
    else
      File.open(DEFAULT_CONFIG_FILE_NAME, "r") { |f|
        jconf = JSON.load(f)
        puts jconf[key]
      }
    end

    exit(0)
  end

end

TgimPackCli.start(ARGV)
