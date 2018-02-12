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
require 'fileutils'

require 'thor'
class TgimPackCli < Thor
  desc 'init [options]', 'Create package config file'
  method_option :i, :type => :boolean, :desc => "interact mode"
  def init
    if File.exist?(DEFAULT_CONFIG_FILE_NAME) then
      puts "Package config file already exists."
      exit(1)
    end
    #STDERR.puts('Could not create new file.')
    # TODO: Add interrupt mode
    puts("Writing new package config file to ./#{DEFAULT_CONFIG_FILE_NAME}.")
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

    # interact mode
    self.interact if options[:i]

    puts("Copying module files to ./module.")
    FileUtils.cp_r(MODULE_PATH, "./module")

    puts("Success!")
  end

  desc 'interact', 'Interact mode, create package config file'
  def interact
    require 'readline'
    stty_save = `stty -g`.chomp
    while true
      buf = Readline.readline("Entry: ").strip
      if buf.empty? then 
        puts "Error, Entry must be specified."
      else
        break
      end
    end
    self.config("entry", buf.empty?? "./output" : buf)

    buf = Readline.readline("Output (default=\"./output\"): ").strip
    self.config("output", buf.empty?? "./output" : buf)
    buf = Readline.readline("Loader (default=\"tgim-generator\"): ").strip
    self.config("loader", buf.empty?? "tgim-generator" : buf)
    buf = Readline.readline("Target (default=\"ns-3\"): ").strip
    self.config("target", buf.empty?? "ns-3" : buf)
  rescue Interrupt
    system("stty", stty_save)
    exit
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
      exit(1)
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
  end

end

TgimPackCli.start(ARGV)
