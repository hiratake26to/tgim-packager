require './src/config'
require './src/gen-main.rb'
require 'json'

def package(file)
  config_file = file ? file : DEFAULT_CONFIG_FILE_NAME

  # load config
  if !File.exist?(config_file) then
    STDERR.puts "No #{config_file} found."
    exit(0)
  end

  # json format check
  File.open(config_file) do |f|
    hash = JSON.load(f)
    $hash = hash
    if !File.exist?($hash["entry"]) then
      STDERR.puts 'entry error'
      exit(1)
    end
    if !File.exist?($hash["output"]) then
      STDERR.puts 'output error'
      exit(1)
    end
    if !File.exist?($hash["loader"]) then
      STDERR.puts 'loader error'
      exit(1)
    end
    if $hash["target"] != 'ns-3' then
      STDERR.puts 'target error'
      exit(1)
    end
  end

  # resolve files to load from entry file
  File.open($hash["entry"]) do |f|
    hash = JSON.load(f)
  end

  # run generator, and get output files(.hpp)
  # generator --output-dir dir --template-path ... --appmodel-path ... in_files ...

  flags = '--template-path "/home/ubuntu-zioi/local/src/tgim-generator/resource/ns3template-cxx.json"' +
          ' --appmodel-path "/home/ubuntu-zioi/local/src/tgim-generator/src/model/application.json"'
  loader = $hash["loader"]
  files = $hash["entry"]
  output = $hash["output"]

  puts '[Pack] Run generator'

  if ( !system("#{loader} #{flags} --output-dir #{output} #{files}")) then
      print 'Load Error!'
      exit(1)
  end

  puts '[Pack] Bundle UDA files'
  #
  # list ./module/uda/
  uda_list = Dir.glob("./module/uda/*")
  # cp it to output directory
  require 'fileutils'
  headers = []
  uda_list.each{|f|
    FileUtils.cp f, $hash["output"]
    headers.push File.basename(f)
  }
  # include UDA in main.cxx

  puts "[Pack] Generate #{TGIM_PACK_MAIN_FILE_NAME}"

  efg = EntryFileGenerator.new
  puts '==> Configure'
  efg.parse(:SIMOPT, $hash['simulator'])
  puts 'OK'
  puts '==> Generating'
  efg.gen($hash['output'] + TGIM_PACK_MAIN_FILE_NAME,
          File.basename($hash['entry'], '.json'),
          headers: headers)
  puts 'OK'

  puts '[Pack] Success!'
end
