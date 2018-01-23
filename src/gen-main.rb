class EntryFileGenerator
  def initialize
    @sim_stop = 30.0
  end

  def setSimStop(time)
    @sim_stop = time.to_f
  end

  def parse(type, hash)
    case type
    when :SIMOPT
      puts "simulator stop time to #{hash['stop']}"
      self.setSimStop(hash['stop'])
    else
      STDERR.puts "[ERR] Could not parse #{type} object!"
    end
  end

  def gen(path, net_root, headers: [])
    # generate main file
    # * including file
    #   - ns-3 libraries
    ns3_libs = <<~CXX
      /* This file is generated from tgim-pack */
      #include <iostream>
      #include <fstream>
      #include <string>
      #include <cassert>
      #include "ns3/core-module.h"
      #include "ns3/network-module.h"
      #include "ns3/point-to-point-module.h"
      #include "ns3/csma-module.h"
      #include "ns3/applications-module.h"
      #include "ns3/internet-apps-module.h"
      #include "ns3/internet-module.h"
      using namespace ns3;
      NS_LOG_COMPONENT_DEFINE ("#{"TgimExample"}");
    CXX

    #   - UDA libraries
    #   TODO

    #   - outputed files from TGIM and UDA
    tgim_outputs = <<~CXX
      #{headers.map{|f|
        '#include "' + f + '"'
        }.join("\n")
      }
      #include "#{File.basename($hash['entry'], '.json')}.hpp"
    CXX

    # * define main function
    main_func = ''
    main_func += <<~CXX
      int main (int argc, char *argv[])
      {
    CXX

    #   - parse command line arguments (optional)
    main_func += <<~CXX
      CommandLine cmd;
      cmd.Parse (argc, argv);
    CXX

    #   - decleare network
    main_func += <<~CXX
      using namespace tgim;
      #{net_root} net;
    CXX

    #   - build network
    main_func += <<~CXX
      net.build();
    CXX
    #   - install application of network
    main_func += <<~CXX
      net.app();
    CXX
    #   - set logging (optional)
    main_func += <<~CXX
      // logging here
    CXX
    #   - simulator ready
    main_func += <<~CXX
      Simulator::Stop (Seconds (#{@sim_stop}));
    CXX
    #   - simulator start
    main_func += <<~CXX
      NS_LOG_INFO ("Run Simulation.");
      Simulator::Run ();
    CXX
    #   - sumulator destroy
    main_func += <<~CXX
      Simulator::Destroy ();
      NS_LOG_INFO ("Done.");
    CXX

    main_func += '}'

    File.open(path, "w") do |f|
      # include
      f.puts ns3_libs
      f.puts tgim_outputs 
      # main func
      f.puts main_func
    end

    system("#{CXX_FORMATTER} #{path}")
  end #gen

end
