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
require 'util'

require 'thor'
class TgimPackCli < Thor
  desc 'version', 'display tgim-pack version'
  def version
    puts TGIM_PACK_VERSION
  end

  desc 'new <path>', 'Create new projcet into path, and current directory set to ns-3 root directory'
  method_option :ns3dir, :type => :string, :desc => "ns-3 directory root", :default => Dir.pwd
  def new(path)
    waff='waff'
    ns3dir=options[:ns3dir]

    if File.exist?(path) then
      puts "Already exists file to the path, failed!"
      exit(1)
    end

    # create tempdir
    orgdir = Dir.pwd
    require "tmpdir"
    tmpdir = Dir.mktmpdir
    puts "temporary: #{tmpdir}"
    Dir.chdir(tmpdir)

    puts "Create project"

    puts "==> Generate: #{path}/#{waff}"
    File.open(waff, 'w') do |f|
      f.puts <<~SHELL
        #!/bin/sh

        NS3DIR="#{ns3dir}"

        CWD="$PWD/build"
        cd $NS3DIR > /dev/null
        ./waf --cwd="$CWD" $*
        cd - > /dev/null
      SHELL
    end
    FileUtils.chmod('u+x', waff)

    puts "==> Generate: #{path}/src/"
    Dir.mkdir('src')

    puts "==> Generate: #{path}/src/main.py"
    begin
      Dir.chdir('src')

      # create sample box
      File.open('main.py', 'w') do |f|
        f.puts <<~PYTHON
          from tgimbox import *

          # Topology:
          #
          # term0      sw                term0  
          #┌──────┐   ┌─────────────┐   ┌──────┐
          #│  port┠───┨port0   port1┠───┨  port│
          #└──────┘   └─────────────┘   └──────┘
          #
          # Application schedule:
          # 
          # term0:
          #   SimReady -> Aft At 1-second -> Ping to term1
          #
          # term1:
          #   SimReady -> Sink

          ## create box
          term0 = BasicTerminal.Fork("term0").SetPoint(Point(0,0))
          term1 = BasicTerminal.Fork("term1").SetPoint(Point(10,0))
          sw = GenSwitch(2).Fork("sw").SetPoint(Point(5,0))

          ## connect
          term0.ConnectPort("port", sw, "port0")
          term1.ConnectPort("port", sw, "port1")

          ## schedule
          (term0.Sdl()
            .At(Sig("SimReady")).Aft().At(1)
            .Do("Ping", {"dhost": "${_Bterm1_Nn0}", "dport": 8080})
            )
          (term1.Sdl()
            .At(Sig("SimReady"))
            .Do("Sink", {"port": 8080})
            )

          ## build
          Builder.AddBox([term0, term1, sw])
          result = Builder.Build()
          with open('tgim-main.json', 'w') as f:
            f.write(Builder.Build())
        PYTHON
      end
      

      Dir.chdir('../')
    end

    puts "==> Generate: #{path}/build/"
    Dir.mkdir('build')

    puts "==> tgim-pack init"
    self.init

    puts "==> tgim-pack config"
    self.config 'project', path
    self.config 'entry',  'tgim-main.json'
    self.config 'output', 'build'
    self.config 'loader', 'tgim-generator'
    self.config 'target', 'ns-3'
    self.config 'target-dir', ns3dir

    puts "==> move file"
    Dir.chdir(orgdir)
    puts "#{tmpdir} -> #{path}"
    FileUtils.mv(tmpdir, path)

    puts "\nFinish!"
  end

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

  desc 'build', 'Build ns-3 script'
  def build
    puts "===> python3 src/main.py"
    o,e,s = Open3.capture3("python3 src/main.py")
    puts o,e
    if (not s.success?) then
      puts "ERROR: src/main.py execution failed!"
      exit(1)
    end
    puts "===> tgim-pack pack"
    self.pack
  end

  desc 'run', 'Run ns-3 script'
  def run_
    puts "===> build"
    self.build
    project = self.config('project')
    ns3dir = self.config('target-dir')
    ns3scratch = ns3dir + '/scratch'

    puts "===> files copy"
    FileUtils.mkdir_p("#{ns3scratch}/#{project}")
    files = Dir.glob("build/*")
    p files ,"#{ns3scratch}/#{project}"
    FileUtils.cp(files, "#{ns3scratch}/#{project}")
    
    puts "===> waff"
    o,e,s = Open3.capture3("./waff --run \"#{project}\" --vis")
    puts o,e
    if (not s.success?) then
      puts "ERROR!"
      exit(1)
    end
  end
  map "run" => "run_" #refer to: http://secret-garden.hatenablog.com/entry/2015/05/27/193313

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
    ret = ""
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
        ret = jconf[key]
        puts ret
      }
    end

    return ret
  end

  desc 'clean', 'clean output directory'
  def clean()
    if !File.exist?(DEFAULT_CONFIG_FILE_NAME) then
      puts "Package config file not exists."
      exit(1)
    end
    
    # get output field from DEFAULT_CONFIG_FILE
    PackUtil.getValue(DEFAULT_CONFIG_FILE_NAME, 'output').bind {|val|
      if !File.exist?(val) then
        puts "no exists output: #{val}"
        next false
      end
      puts "clean: #{val}"
      FileUtils.rm_rf(val)
      next true
    }
  end

end

TgimPackCli.start(ARGV)
