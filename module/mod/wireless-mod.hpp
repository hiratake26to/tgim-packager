#include "ns3/yans-wifi-helper.h"
#include "ns3/ssid.h"
#include "ns3/propagation-loss-model.h"
#include "ns3/propagation-delay-model.h"
#include "ns3/rng-seed-manager.h"
#include "ns3/mobility-helper.h"
#include "ns3/wifi-net-device.h"
#include "ns3/constant-position-mobility-model.h"

// install mobility to node
void installMobility(Ptr<Node> node) {
  node->AggregateObject (CreateObject<ConstantPositionMobilityModel> ());
}

void allocateFixedPos(NodeContainer nc, double x, double y, double z) {
  MobilityHelper mobility;
  Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator> ();
    positionAlloc->Add (Vector (x, y, z)); // ni's position
  mobility.SetPositionAllocator (positionAlloc);
  mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");
  mobility.Install (nc);
}

#if MEMO
void allocateWaypoint(Node &node, double sec, double x, double y, double z) {
  // Allocate waypoint to mobility node
  Ptr<WaypointMobilityModel> m_mob;
  m_mob = CreateObject<WaypointMobilityModel> ();
  mn->AggregateObject (m_mob);

  Waypoint wpt_start  (Seconds (0.0), Vector (0.0, dist, 0.0));
  m_mob->AddWaypoint  (wpt_start);
  Waypoint wpt_stop   (Seconds (SIM_STOP), Vector (nWifiNodes*100.0, dist, 0.0));
  m_mob->AddWaypoint  (wpt_stop);
}
#endif

NetDeviceContainer WifiApStaInstall(WifiHelper wifi, NodeContainer ap, NodeContainer stas) {
  NetDeviceContainer netDevs;

  WifiMacHelper wifiMac;
  YansWifiPhyHelper wifiPhy = YansWifiPhyHelper::Default();
  YansWifiChannelHelper wifiChannel = YansWifiChannelHelper::Default();
  wifiPhy.SetChannel (wifiChannel.Create ());
  // [FIXME] Assign uniq SSID
  Ssid ssid = Ssid ("wifi-stap-default");
  wifi.SetRemoteStationManager ("ns3::ArfWifiManager");

  // setup AP
  wifiMac.SetType ("ns3::ApWifiMac",
      "Ssid", SsidValue (ssid));
  netDevs.Add(wifi.Install (wifiPhy, wifiMac, ap));
  
  // setup STAs
  wifiMac.SetType ("ns3::StaWifiMac",
      "ActiveProbing", BooleanValue (true),
      "Ssid", SsidValue (ssid));
  netDevs.Add(wifi.Install (wifiPhy, wifiMac, stas));

  return netDevs;
}

// configuration
// RateControl: ConstantRateWifiManager, DataMode: phyMode, ControlMode: phyMode
//              where phyMode: DsssRate1Mbps
// Exponent: 3.0
// ReferenceDistance: 1.0
// ReferenceLoss: 46.6777
// wifiPhy: YansWifiPhyHelper::Default()
// wifiMac: SetType(AdhocWifiMac, Ssid: MySSID)

NetDeviceContainer WifiAdhocInstall(WifiHelper wifi, NodeContainer nc) {
  StringValue phyMode("DsssRate1Mbps");
  // create wifi channel
  wifi.SetStandard (WIFI_PHY_STANDARD_80211b);
  wifi.SetRemoteStationManager ("ns3::ConstantRateWifiManager",
      "DataMode"   , phyMode,
      "ControlMode", phyMode);

  // wifi chennel
  YansWifiChannelHelper wifiChannel;
  // set delay model
  wifiChannel.SetPropagationDelay ("ns3::ConstantSpeedPropagationDelayModel");
  // set loss model
  wifiChannel.AddPropagationLoss  ("ns3::LogDistancePropagationLossModel",
      "Exponent", DoubleValue(3.0),
      "ReferenceDistance", DoubleValue(1.0),
      "ReferenceLoss", DoubleValue(46.6777));

  YansWifiPhyHelper wifiPhy =  YansWifiPhyHelper::Default ();
  wifiPhy.SetPcapDataLinkType (YansWifiPhyHelper::DLT_IEEE802_11_RADIO); 
  wifiPhy.SetChannel (wifiChannel.Create ());

  // Add a non-QoS upper mac, and disable rate control
  WifiMacHelper wifiMac;
  Ssid ssid = Ssid ("MySSID");
  wifiMac.SetType  ("ns3::AdhocWifiMac", "Ssid", SsidValue (ssid));

  // install wifi to node
  return wifi.Install (wifiPhy, wifiMac, nc);
}

#if MEMO
void build() {
  {
    NodeContainer nc_local;
    nc_local.Add(nodes.Get(N0));
    nc_local.Add(nodes.Get(N1));
    WifiInstall(nc_local);
  }
}
#endif
