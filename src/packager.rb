require 'config'
require 'gen-main.rb'
require 'json'
require 'open3'

# nil safety, for read file or JSON object.
def nil.method_missing(*_); nil; end

def getNetName(filepath)
  File.open(filepath) { |f|
    hash = JSON.load(f)

    # json format check
    if !hash["name"] then
      STDERR.puts '[ERR] entry network name is empty'
      exit(1)
    end

    return hash["name"]
  }
end

def loadConf(filepath)
  File.open(filepath) { |f|
    hash = JSON.load(f)

    # json format check
    if !File.exist?(hash["entry"]) then
      STDERR.puts '[ERR] entry not found'
      exit(1)
    end
    if !File.exist?(hash["output"]) then
      STDERR.puts 'No output directory'
      begin
        Dir.mkdir(hash["output"])
      rescue
        STDERR.puts '[ERR] Could not create new directory'
        exit(1)
      end
      STDERR.puts 'Created new directory'
    end
    `type #{hash["loader"]} 2>/dev/null`
    if $?.exitstatus != 0 then
      STDERR.puts '[ERR] loader not found'
      exit(1)
    end
    if hash["target"] != 'ns-3' then
      STDERR.puts '[ERR] target error'
      exit(1)
    end

    return hash
  }
end

def package(conf_file_path)
  conf_file_path = conf_file_path ? conf_file_path : DEFAULT_CONFIG_FILE_NAME

  if !File.exist?(conf_file_path) then
    STDERR.puts "No #{conf_file_path} found."
    exit(1)
  end

  Dir.chdir(File.dirname(conf_file_path)) {
    puts "[Pack] Enter to '#{Dir.pwd}'"
    process(File.basename(conf_file_path))
    puts "[Pack] Exit from '#{Dir.pwd}'"
  }
end

def process(config_file)
  # additional CXX headers
  headers = []

  # load config
  if !File.exist?(config_file) then
    STDERR.puts "No #{config_file} found."
    exit(0)
  end
  
  begin
    hash = loadConf(config_file)
  rescue
    STDERR.puts "[ERR] Could not parse from config file to JSON!"
    exit(1)
  end

  # run generator, and get output files(.hpp)
  # generator --output-dir dir --template-path ... --appmodel-path ... in_files ...

  loader = hash["loader"]
  entry  = hash["entry"]
  output = hash["output"]

  puts '[Pack] Searching UDA files'
  #
  # list ./module/uda/
  uda_list = Dir.glob("./module/uda/*")
  # cp it to output directory
  require 'fileutils'
  # include UDA header in main.cxx
  puts "==> Searching..."
  uda_list.each{|f|
    puts "Find in #{f}"
    FileUtils.cp f, hash["output"]
    headers.push File.basename(f)
  }
  puts "OK"

  # [NOTE] module/mod is pilot implementation
  puts '[Pack] Searching mod files'
  #
  # list ./module/uda/
  mod_list = Dir.glob("./module/mod/*")
  # cp it to output directory
  #require 'fileutils'
  # include include header in main.cxx
  puts "==> Searching..."
  mod_list.each{|f|
    puts "Find in #{f}"
    FileUtils.cp f, hash["output"]
    headers.push File.basename(f)
  }
  puts "OK"


  puts '[Pack] Run generator'

  generator_wd = File.dirname(entry)
  generator_cmd = lambda {|file, outname=file|
    flags = '--template-path "/home/ubuntu-zioi/local/src/tgim-generator/resource/ns3template-cxx.json"' +
            ' --appmodel-path "/home/ubuntu-zioi/local/src/tgim-generator/src/model/application.json"'
    return %W(
      cd #{generator_wd} &&
      #{loader} #{flags}
      -o \"#{File.absolute_path(File.join(output,File.basename(outname, ".json")+".hpp"))}\"
      #{File.basename(file)}
    ).join(' ')
  }

  cmdEval = lambda{|cmd|
    puts cmd
    return Open3.capture2e(cmd)
  }

  puts '[Pack] Search entry-net to find subnet'
  # resolve subnet files from entry file
  File.open(hash["entry"]) { |f|
    jsubnet = p JSON.load(f)['subnet']
    puts "if subnet is nil, skip parse subnet"
    jsubnet.each{|subnet_name,val|
      puts 'Find subnet: ' + subnet_name
      # generate subnet
      out, stat = cmdEval.call(generator_cmd.call(val['load'], subnet_name))
      puts out
      if ( stat != 0 ) then
          STDERR.puts '[ERR] Load Error!'
          exit(1)
      end
      headers.push "#{subnet_name}.hpp"
    }
  }

  puts '[Pack] Generate entry-net'
  begin
    out, stat = cmdEval.call(generator_cmd.call(entry))
    puts out
    if ( stat != 0 ) then
        STDERR.puts '[ERR] Load Error!'
        exit(1)
    end
  end

  puts "[Pack] Generate #{TGIM_PACK_MAIN_FILE_NAME}"

  efg = EntryFileGenerator.new
  puts '==> Configure'
  if ( !!hash['simulator'] ) then
    efg.parse(:SIMOPT, hash['simulator'])
  end
  puts 'OK'
  puts '==> Generating'
  efg.gen(hash['output'] + '/' + TGIM_PACK_MAIN_FILE_NAME,
          hash['entry'],
          getNetName(hash['entry']),
          headers: headers)
  puts 'OK'

  puts '[Pack] Success!'
end
