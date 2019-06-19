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

class ping
{
  Ptr<Node> n;
  int nport;
  Ptr<Node> m;
  int mport;
  int sim_start;
  int sim_stop;
public:
  void Set_dhost(Ptr<Node> m) {
    this->m = m;
  }
  void Set_dport(int port) {
    this->mport = port;
  }
  void Set_dport(std::string port) {
    Set_dport(std::stoi(port));
  }
  void Set_rate(std::string) {
    // nothing
  }
  void Set_shost(Ptr<Node> n) {
    this->n = n;
  }
  void Set_sport(int port) {
    this->nport = port;
  }
  void Set_sport(std::string port) {
    Set_sport(std::stoi(port));
  }
  void Set_start(int t) {
    this->sim_start = t;
  }
  void Set_start(std::string t) {
    Set_start(std::stoi(t));
  }
  void Set_stop(int t) {
    this->sim_stop = t;
  }
  void Set_stop(std::string t) {
    Set_stop(std::stoi(t));
  }
  void install() {
    //Ipv4InterfaceAddress madr = m->GetObject<Ipv4>()->GetAddress(1,0);
    Ipv4InterfaceAddress madr;
    madr = m->GetObject<Ipv4>()->GetAddress(1,0);
    NS_LOG_INFO (madr.GetLocal());
    //madr = m->GetObject<Ipv4>()->GetAddress(2,0);
    //NS_LOG_INFO (madr.GetLocal());

    Address remoteAddr (InetSocketAddress (madr.GetLocal(), mport));

    Ptr<Socket> socket = Socket::CreateSocket (n,
        TcpSocketFactory::GetTypeId() );
    Ptr<MyApp> app = CreateObject<MyApp> ();
    app->Setup (socket, remoteAddr, 1040, DataRate ("1Mbps"));
    n->AddApplication (app);
    app->SetStartTime (Seconds (sim_start));
    app->SetStopTime (Seconds (sim_stop));

    PacketSinkHelper sinkHelper ("ns3::TcpSocketFactory",
        Address (InetSocketAddress (Ipv4Address::GetAny(), mport)));
    ApplicationContainer sink = sinkHelper.Install (m);
    sink.Start (Seconds (sim_start));
    sink.Stop (Seconds (sim_stop));
  }
};

}} // tgim::app
