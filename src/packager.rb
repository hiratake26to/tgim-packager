require 'config'
require 'gen-main.rb'
require 'json'

def loadConf(filepath)
  File.open(filepath) { |f|
    hash = JSON.load(f)

    # json format check
    if !File.exist?(hash["entry"]) then
      STDERR.puts 'entry error'
      exit(1)
    end
    if !File.exist?(hash["output"]) then
      STDERR.puts 'No output directory'
      begin
        Dir.mkdir(hash["output"])
      rescue
        STDERR.puts 'Could not create new directory'
        exit(1)
      end
      STDERR.puts 'Created new directory'
    end
    if !File.exist?(hash["loader"]) then
      STDERR.puts 'loader error'
      exit(1)
    end
    if hash["target"] != 'ns-3' then
      STDERR.puts 'target error'
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


  puts '[Pack] Run generator'

  generator_wd = File.dirname(entry)
  generator_cmd = lambda {|file, outname=file|
    flags = '--template-path "/home/ubuntu-zioi/local/src/tgim-generator/resource/ns3template-cxx.json"' +
            ' --appmodel-path "/home/ubuntu-zioi/local/src/tgim-generator/src/model/application.json"'
    return <<~SH
      cd #{generator_wd} && \
      #{loader} #{flags} \
      -o \"#{File.absolute_path(File.join(output,File.basename(outname, ".json")+".hpp"))}\" \
      #{File.basename(file)}
    SH
  }

  puts '[Pack] Search entry-net to find subnet'
  # resolve subnet files from entry file
  File.open(hash["entry"]) { |f|
    jsubnet = JSON.load(f)['subnet']
    jsubnet.each{|subnet_name,val|
      puts 'Find subnet: ' + subnet_name
      # generate subnet
      if ( !system( generator_cmd.call(val['load'], subnet_name) )) then
          STDERR.puts '[ERR] Load Error!'
          exit(1)
      end
      headers.push "#{subnet_name}.hpp"
    }
  }

  puts '[Pack] Generate entry-net'
  if ( !system( generator_cmd.call(entry) )) then
      STDERR.puts '[ERR] Load Error!'
      exit(1)
  end

  puts "[Pack] Generate #{TGIM_PACK_MAIN_FILE_NAME}"

  efg = EntryFileGenerator.new
  puts '==> Configure'
  if ( !!hash['simulator'] ) then
    efg.parse(:SIMOPT, hash['simulator'])
  end
  puts 'OK'
  puts '==> Generating'
  efg.gen(hash['output'] + TGIM_PACK_MAIN_FILE_NAME,
          hash['entry'],
          File.basename(hash['entry'], '.json'),
          headers: headers)
  puts 'OK'

  puts '[Pack] Success!'
end
