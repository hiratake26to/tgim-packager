#pragma once

namespace {
  class MyApp : public Application
  {
  public:
    MyApp ();
    virtual ~MyApp ();

    void Setup (Ptr<Socket> socket, Address address, uint32_t packetSize, DataRate dataRate);

  private:
    virtual void StartApplication (void);
    virtual void StopApplication (void);

    void ScheduleTx (void);
    void SendPacket (void);

    Ptr<Socket>     m_socket;
    Address         m_peer;
    uint32_t        m_packetSize;
    DataRate        m_dataRate;
    EventId         m_sendEvent;
    bool            m_running;
    uint32_t        m_packetsSent;
  };

  MyApp::MyApp ()
    : m_socket (0),
      m_peer (),
      m_packetSize (0),
      m_dataRate (0),
      m_sendEvent (),
      m_running (false),
      m_packetsSent (0)
  {
  }

  MyApp::~MyApp ()
  {
    m_socket = 0;
  }

  void
  MyApp::StartApplication (void)
  {
    m_running = true;
    m_packetsSent = 0;
    m_socket->Bind();
    m_socket->Connect(m_peer);
    SendPacket ();
  }

  void
  MyApp::StopApplication (void)
  {
    m_running = false;

    if (m_sendEvent.IsRunning ())
      {
        Simulator::Cancel (m_sendEvent);
      }

    if (m_socket)
      {
        m_socket->Close ();
      }
  }

  void
  MyApp::SendPacket (void)
  {
    Ptr<Packet> packet = Create<Packet> (m_packetSize);
    m_socket->Send (packet);
    ++m_packetsSent;
    ScheduleTx ();
  }

  void
  MyApp::ScheduleTx (void)
  {
    if (m_running)
      {
        Time tNext (Seconds (m_packetSize * 8 / static_cast<double> (m_dataRate.GetBitRate ())));
        m_sendEvent = Simulator::Schedule (tNext, &MyApp::SendPacket, this);
      }
  }

  void
  MyApp::Setup (Ptr<Socket> socket, Address address, uint32_t packetSize, DataRate dataRate)
  {
    m_socket = socket;
    m_peer = address;
    m_packetSize = packetSize;
    m_dataRate = dataRate;
  }
}

//
// tgim interface
//

namespace tgim {
namespace app {
//#include "ns3/config-store-module.h"

using std::string;

class Ping
{
  Ptr<Node> m_dhost;
  int m_dport;
  int m_start_time;
  int m_time;
  string m_rate;
public:
  Ping(string name)
  {
    // initialize
    // set default
    m_dport = 8080;
    m_rate = "1Mbps";
    m_time = 1;
  }
  void Set_start(int time) {
    m_start_time = (time);
  }
  // [[MUST]]
  // host is distination box's root node.
  void Set_dhost(Ptr<Node> host) {
    m_dhost = host;
  }
  void Set_dport(int port) {
    m_dport = port;
  }
  // [OPTION]
  void Set_time(int time) {
    m_time = time;
  }
  void Set_rate(string rate) {
    m_rate = rate;
  }

  void Install(Ptr<Node> host) {
    ////Ipv4InterfaceAddress madr = m->GetObject<Ipv4>()->GetAddress(1,0);
    //Ipv4InterfaceAddress madr;
    //madr = m->GetObject<Ipv4>()->GetAddress(1,0);
    //NS_LOG_INFO (madr.GetLocal());
    ////madr = m->GetObject<Ipv4>()->GetAddress(2,0);
    ////NS_LOG_INFO (madr.GetLocal());

    //Address remoteAddr (InetSocketAddress (madr.GetLocal(), mport));

    //Ptr<Socket> socket = Socket::CreateSocket (n,
    //    TcpSocketFactory::GetTypeId() );
    //Ptr<MyApp> app = CreateObject<MyApp> ();
    //app->Setup (socket, remoteAddr, 1040, DataRate ("1Mbps"));
    //n->AddApplication (app);
    //app->SetStartTime (Seconds (sim_start));
    //app->SetStopTime (Seconds (sim_stop));

    //PacketSinkHelper sinkHelper ("ns3::TcpSocketFactory",
    //    Address (InetSocketAddress (Ipv4Address::GetAny(), mport)));
    //ApplicationContainer sink = sinkHelper.Install (m);
    //sink.Start (Seconds (sim_start));
    //sink.Stop (Seconds (sim_stop));

    Ipv4InterfaceAddress dst_adr= m_dhost->GetObject<Ipv4>()->GetAddress(1,0);
    NS_LOG_INFO (dst_adr.GetLocal());
    //madr = m->GetObject<Ipv4>()->GetAddress(2,0);
    //NS_LOG_INFO (madr.GetLocal());

    Address remoteAddr (InetSocketAddress (dst_adr.GetLocal(), m_dport));

    Ptr<Socket> socket = Socket::CreateSocket (host, TcpSocketFactory::GetTypeId() );
    Ptr<MyApp> app = CreateObject<MyApp> ();
    app->Setup (socket, remoteAddr, 1040, DataRate (m_rate));
    host->AddApplication (app);
    app->SetStartTime (Seconds (m_start_time));
    app->SetStopTime (Seconds (m_start_time + m_time));
  }
};

class Sink
{
  int m_port;
  int m_start_time;
  int m_time;
public:
  Sink(string name) {
    // initialize
    // set default
    m_port = 8080;
  }
  // [MUST]
  void Set_start(int time) {
    m_start_time = (time);
  }
  void Set_time(int time) {
    m_time = (time);
  }
  // [OPTION]
  void Set_port(int port) {
    m_port = port;
  }

  void Install(Ptr<Node> host) {
    PacketSinkHelper sinkHelper ("ns3::TcpSocketFactory",
        Address (InetSocketAddress (Ipv4Address::GetAny(), m_port)));
    ApplicationContainer sink = sinkHelper.Install (host);
    sink.Start (Seconds (m_start_time));
    sink.Stop (Seconds (m_start_time + m_time));
  }
};

class NicCtl
{
  int m_start_time;
  uint32_t m_nic_index;
  bool m_enable;
public:
  NicCtl(string name) {
    // set default
  }
  // [MUST]
  void Set_start(int time) {
    m_start_time = (time);
  }
  void Set_idx(uint32_t i) {
    m_nic_index = i;
  }
  void Set_enable(bool e) {
    m_enable = e;
  }

  void Install(Ptr<Node> host) {
    // TODO implement
    // handle only ipv4
    Ptr<Ipv4> ipv4 = host->GetObject<Ipv4>();
    if (0 == ipv4) {
      throw std::runtime_error("the host has not a ipv4 object!");
    }
    //Ptr<Ipv6> ipv6 = host->GetObject<Ipv6>();
    //if (0 == ipv6) {
    //  throw std::runtime_error("the host has not a ipv6 object!");
    //}

    if (m_enable) {
      Simulator::Schedule (Seconds (m_start_time),&Ipv4::SetUp,ipv4, m_nic_index);
    } else {
      Simulator::Schedule (Seconds (m_start_time),&Ipv4::SetDown,ipv4, m_nic_index);
    }
  }
};

}} // tgim::app
