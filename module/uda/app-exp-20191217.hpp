#pragma once

#include "ns3/internet-module.h"

//////////////////////////////////////////////////
/// tgim interface
namespace tgim {
namespace app {

using std::string;

#if 0
class App {
  int m_start_time;
public:
  App(string name)
  {
    // initialization and set default value
  }
  /// necessary property
  void Set_start(int time) {
    m_start_time = time;
  }
  /// optional property
  void Set_xxx(Ptr<Node> host) {
  }
  /// install
  void Install(Ptr<Node> host) {
  }
};
#endif

//////////////////////////////////////////////////
/// On Off Application
class ExpOnOff {
  uint16_t port = 9;   // Discard port (RFC 863)
  int m_start_time;
  int m_end_time;
  Ptr<Node> m_dhost;
  int m_dhost_nic_idx = 1;
public:
  ExpOnOff(string name)
  {
    // initialization and set default value
  }
  /// necessary property
  void Set_start(int time) {
    m_start_time = time;
  }
  void Set_time(int time) {
    m_end_time = time;
  }
  void Set_dhost(Ptr<Node> host) {
    m_dhost = host;
  }
  void Set_dhost_idx(int idx) {
    m_dhost_nic_idx = idx;
  }
  /// install
  void Install(Ptr<Node> host) {
    // Create the OnOff application to send UDP datagrams of size
    // 210 bytes at a rate of 448 Kb/s
    NS_LOG_INFO ("Create OnOff Applications.");
    
    //OnOffHelper onoff ("ns3::UdpSocketFactory",
    //                  InetSocketAddress (i5i6.GetAddress (1), port));

    /////TODO////////
    // show dhost all device address , compare with PyViz Device list and its index
    NS_LOG_INFO ("DEBUG<<");
    for (uint32_t i = 0; i < m_dhost->GetObject<Ipv4>()->GetNInterfaces(); ++i) {
      NS_LOG_INFO ("iface" << i);
      for (uint32_t j = 0; j < m_dhost->GetObject<Ipv4>()->GetNAddresses(i); ++j) {
        Ipv4InterfaceAddress adr= m_dhost->GetObject<Ipv4>()->GetAddress(i, j);
        NS_LOG_INFO ("[" << j << "]" << adr.GetLocal());
      }
      NS_LOG_INFO ("--");
    }
    NS_LOG_INFO (">>");

    Ipv4InterfaceAddress adr= m_dhost->GetObject<Ipv4>()->GetAddress(m_dhost_nic_idx,0); // FIXME select address
    NS_LOG_INFO ("dhost addr: " << adr.GetLocal());
    OnOffHelper onoff ("ns3::UdpSocketFactory",
                      InetSocketAddress (adr.GetLocal(), port));
    
    onoff.SetConstantRate (DataRate ("2kbps"));
    onoff.SetAttribute ("PacketSize", UintegerValue (50));

    ApplicationContainer apps = onoff.Install (host);
    apps.Start (Seconds (m_start_time));
    apps.Stop (Seconds (m_start_time + m_end_time));
  }
};

//////////////////////////////////////////////////
/// Sink Application
class ExpSink {
  uint16_t port = 9;   // Discard port (RFC 863)
  int m_start_time;
  int m_end_time;
public:
  ExpSink(string name)
  {
    // initialization and set default value
  }
  /// necessary property
  void Set_start(int time) {
    m_start_time = time;
  }
  void Set_time(int time) {
    m_end_time = time;
  }
  /// install
  void Install(Ptr<Node> host) {
    // Create an optional packet sink to receive these packets
    NS_LOG_INFO ("Create Sink Applications.");
    PacketSinkHelper sink ("ns3::UdpSocketFactory",
                            Address (InetSocketAddress (Ipv4Address::GetAny (), port)));
    ApplicationContainer apps = sink.Install (host);
    apps.Start (Seconds (m_start_time));
    apps.Stop (Seconds (m_start_time + m_end_time));
  }
};

//////////////////////////////////////////////////
/// NIC Control Application
class ExpNicCtl {
  int m_start_time;
  uint32_t m_if_idx;
  bool m_enable;
public:
  ExpNicCtl(string name)
  {
    // initialization and set default value
  }
  /// necessary property
  void Set_start(int time) {
    m_start_time = time;
  }
  void Set_idx(uint32_t idx) {
    m_if_idx = idx;
  }
  void Set_enable(bool enable) {
    m_enable = enable;
  }
  /// install
  void Install(Ptr<Node> host) {
    Ptr<Ipv4> ipv41 = host->GetObject<Ipv4> ();
    // The first ifIndex is 0 for loopback, then the first p2p is numbered 1,
    // then the next p2p is numbered 2
    //
    NS_LOG_INFO ("idx: " << m_if_idx << " enable: " << m_enable
        << " addr: " << ipv41->GetAddress(m_if_idx, 0).GetLocal());

    if (m_enable) {
      Simulator::Schedule (Seconds (m_start_time),&Ipv4::SetUp,ipv41, m_if_idx);
    } else {
      Simulator::Schedule (Seconds (m_start_time),&Ipv4::SetDown,ipv41, m_if_idx);
    }
  }
};

}} // tgim::app
