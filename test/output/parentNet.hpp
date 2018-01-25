namespace tgim {
struct parentNet {
  /*******************************************************
   * we can always use                                   *
   ******************************************************/
  // enum node name
  enum NodeName {
    gateway,
    node_0,
    node_1,
    subnet_0_gateway,
  };
  
  /*******************************************************
   * config this if you need before build                *
   ******************************************************/
  // helper
  // Channel : csma
  CsmaHelper csma;
  // subnet
  struct Subnet0 subnet_0;
  
  /*******************************************************
   * we can after build use this                         *
   ******************************************************/
  // nodes
  NodeContainer nodes;
  NetDeviceContainer ndc_csma;
  
  /*******************************************************
   * build function                                      *
   ******************************************************/
  void build() {
    // config channel
    csma.SetChannelAttribute("DataRate",StringValue("100Mbps"));
    csma.SetChannelAttribute("Delay",StringValue("1ms"));
    // build all subnets
    subnet_0.build();
    // create all nodes
    // - gateway
    nodes.Add(CreateObject<Node>());
    // - node_0
    nodes.Add(CreateObject<Node>());
    // - node_1
    nodes.Add(CreateObject<Node>());
    // - subnet_0_gateway
    nodes.Add(subnet_0.nodes.Get(Subnet0::gateway));
    // connect link
    {
      NodeContainer nc_local;
      nc_local.Add(nodes.Get(gateway));
      nc_local.Add(nodes.Get(node_0));
      nc_local.Add(nodes.Get(node_1));
      nc_local.Add(nodes.Get(subnet_0_gateway));
      ndc_csma = csma.Install(nc_local);
    }
    // install internet stack
    InternetStackHelper stack;
    stack.Install(nodes.Get(gateway));
    stack.Install(nodes.Get(node_0));
    stack.Install(nodes.Get(node_1));
    // 
    NS_LOG_INFO ("Assign ip addresses.");
    { Ipv4AddressHelper ip;
      // ndc_csma
      // auto set address
      ip.SetBase ("192.168.1.0","255.255.255.0");
      ip.Assign (ndc_csma);
    }
    NS_LOG_INFO ("Initialize Global Routing.");
    Ipv4GlobalRoutingHelper::PopulateRoutingTables ();
    Ipv4GlobalRoutingHelper::RecomputeRoutingTables ();
  }
  
  /*******************************************************
   * application build function                          *
   ******************************************************/
  void app() {
    {
      tgim::app::ping __tgim_app_ping;
      __tgim_app_ping.Set_dhost(nodes.Get(node_1));
      __tgim_app_ping.Set_dport(8080);
      __tgim_app_ping.Set_rate("1Mbps");
      __tgim_app_ping.Set_shost(nodes.Get(node_0));
      __tgim_app_ping.Set_sport(60000);
      __tgim_app_ping.Set_start(1);
      __tgim_app_ping.Set_stop(10);
      __tgim_app_ping.install();
    }
  }
};
}
