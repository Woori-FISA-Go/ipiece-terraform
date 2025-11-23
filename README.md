# 1. 🏗️ 프로젝트 배경 및 목표

## 1.1. 프로젝트 배경 (Context)

FISA 교육장의 **공용 온프레미스 서버(GSC 01, 04, 05)** 를 기반으로 온프레미스를 구축했으며,

**5개 팀이 3대의 물리 서버를 공유하는 환경**이었습니다.

---

### 📸 공용 인프라 구성

<table>
  <tr>
    <td width="55%" valign="top">
      <img src="https://github.com/user-attachments/assets/ab084db4-2739-4198-8f68-41b3d86f82bb" width="100%" />
    </td>
    <td width="1%">
      </td>
    <td width="55%" valign="top">
      <img src="https://github.com/user-attachments/assets/d27fc3bf-1c74-4748-8dbf-86876a82aecb" width="100%" />
    </td>
  </tr>
</table>

<details>
<summary><strong>① 네트워크 분리 (물리/논리)</strong></summary>
<br>

3대의 ESXi 호스트는 모두 **2개 이상의 물리 NIC(vmnic)** 를 사용했습니다.

- NIC 1 → **ESXi 관리 / vCenter** 용도의 *Management Switch*
- NIC 2 → **VM 서비스 트래픽**을 위한 *Internet Switch*

vCenter의 중앙 관리 기능(vMotion·호스트 모니터링·리소스 분배)을 활용해
5개 팀이 한정된 자원을 **논리적으로 격리된 환경**에서 사용할 수 있도록 구성했습니다.

</details>
<details>
<summary><strong>② 팀별 가상 네트워크 격리</strong></summary>
<br>

서로 다른 팀끼리 **IP 충돌 없이 네트워크를 격리**하기 위해  
각 팀별로 **pfSense 기반 가상 방화벽**을 구축하고, 서로 다른 사설 IP 대역을 할당했습니다.

- 예: `172.16.1.x`, `172.16.2.x` …

</details>

<br>

---
## 1.2. 개발 환경 구성 (네트워크 / VPN 인프라)

먼저 **온프레미스와 AWS가 서로 프라이빗 IP로 통신**할 수 있도록 네트워크 인프라를 구축했습니다.

<div align="center">
  <img src="https://github.com/user-attachments/assets/2cafc7e0-1a59-457a-9fca-99dea6a062a9"
       alt="온프레–AWS 하이브리드 네트워크 개요"
       width="70%" />
</div>

- 온프레미스 내부망: `172.16.4.0/24`
- 개발자 VPN 대역(노트북): `172.16.60.0/24`
- AWS VPC: `10.0.0.0/16`

> 결과적으로 **온프레(172.16.4.x)와 AWS VPC(10.0.x.x)는  
> 모두 VPN 터널을 통해서만 서로 통신**하도록 설계했습니다.

---

<details>
<summary><strong>① 주소 설계 & 방화벽 승인</strong></summary>

- 온프레미스, 개발자 VPN, AWS VPC 세 영역이 **서로 겹치지 않도록** IP 대역을 분리했습니다.
- 온프레에서 `10.0.0.0/16` 으로 향하는 트래픽은 모두 VPN으로 라우팅되도록 설계했습니다.
  
<br>

<div align="center">
  <img src="https://github.com/user-attachments/assets/ad06e924-2588-4169-8ab2-5d54148a169c"
       alt="IP 대역 및 라우팅 설계"
       width="55%" />
</div>

- 네트워크 관리자에게 AWS와의 IPsec 통신을 위해  
  **UDP 500, UDP 4500, ESP(프로토콜 50)** 개방을 공식 요청했습니다.
- 이후 pfSense를 IPsec 게이트웨이로 구성하여  
  `172.16.4.0/24` ↔ `10.0.0.0/16` 구간을 **Site-to-Site VPN** 으로 연결했습니다.

<br>
  
</details>

<details>
<summary><strong>② 개발자 노트북 WireGuard 구성</strong></summary>
<br>

<div align="center">
  <img src="https://github.com/user-attachments/assets/102d5038-c412-4742-88ba-6747a6896d5e"
       alt="개발자 노트북 WireGuard 설정"
       width="60%" />
</div>

- `Address = 172.16.60.3/32` : 개발자 노트북에 VPN용 가상 IP 할당  
- `AllowedIPs = 172.16.60.0/24, 172.16.4.0/24, 10.0.0.0/16`  
  → 세 대역으로 나가는 트래픽을 모두 WireGuard 터널로 전달
- `Endpoint = 192.168.0.9:51821` : pfSense(WireGuard 서버)의 사설 IP/포트

VPN만 연결하면, 온프레(`172.16.4.x`)와 AWS(`10.0.x.x`)의 프라이빗 리소스를  
로컬 네트워크처럼 바로 접근할 수 있도록 맞춰두었습니다.

<br>

</details>

<details>
<summary><strong>③ 라우터 / pfSense 설정 스크린샷 모음</strong></summary>
<br>

<table>
  <tr>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/8978659b-f5fc-4eb7-bd95-2ef438572351"
           alt="공유기 포트 포워딩 설정"
           width="100%" />
    </td>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/5f9fefac-2782-4ab3-92e4-98a2e48b3ac0"
           alt="pfSense WireGuard / IPsec 상태"
           width="100%" />
    </td>
  </tr>
</table>

- 공유기에서 WireGuard·IPsec 관련 포트를 pfSense로 포워딩해  
  외부에서 들어오는 VPN 트래픽이 모두 pfSense로 도달하도록 설정했습니다.
- pfSense에서는
  - AWS VPN 게이트웨이와 IPsec 터널 두 개를 구성하고,
  - `172.16.4.0/24`, `172.16.60.0/24` ↔ `10.0.0.0/16` 을 Phase2에 등록했습니다.
- WireGuard 상태 화면에서는 각 팀원 노트북(`172.16.60.x/32`)의 접속 여부를 확인했습니다.

<br>

</details>

## 1.3. 하이브리드 환경 구축 및 운영 최적화

vSphere와 AWS 클라우드를 연동한 **하이브리드 인프라** 구축을 목표로 했습니다.

아래의 다섯 가지 핵심 요구사항을 충족하도록 설계했습니다.

---
<details>
<summary><strong>🎯 1) 비용 최적화 (AWS 비용 $450 이하로 운영 및 개발)</strong></summary>


### EKS 선택 이유? (vs. EC2에 Kubernetes 자체 구축)

프로젝트 초기 단계에서 관리형 서비스(EKS)와 EC2 인스턴스에 직접 Kubernetes를 설치하는 방안을 비교했습니다.

**결론: TCO(총소유비용)와 운영 안정성을 고려할 때 EKS가 $450 예산 내에서 더 합리적인 선택이라는 결론을 내렸습니다.**

| 비교 항목 | Amazon EKS (관리형) | EC2에 자체 구축 (Self-Hosted) |
| :--- | :--- | :--- |
| **Control Plane** | **AWS가 완전 관리** (HA, 자동 패치/업그레이드) | **직접 구축 및 운영** (ETCD, API 서버 등) |
| **초기 구축** | 빠름 (CLI/Terraform으로 몇 분 내 생성) | 복잡하고 시간이 오래 소요됨 |
| **월간 Control Plane 비용**<br>(최소 사양: t4g.small 기준) | • 클러스터 관리비 (시간당 $0.10)<br> • **예상 : $73.00**<br>(관리비, NLB, EC2, EBS **모두 포함**) | **예상 : $69.21**<br>(Multi-AZ 비용, EC2 3대 + EBS 3개 + NLB 1대) |
| **선택 이유** | 1. **비용이 비슷함** (NLB, Multi-AZ 비용 고려 시)<br>2. **운영 완전 자동화** (마스터 HA, 장애 복구, 패치 등)<br>3. **시간 단축** (짧은 프로젝트 기한 내 빠른 구축) | 1. **HA 구성 복잡성** (etcd 3 Masters, Multi-AZ 배치)<br>2. **수동 인프라 작업** (API 서버용 NLB 수동 구성)<br>3. **총 비용 불리** (마스터 EC2 + NLB + 통신 비용) |

<br>

---

<br>

### 데이터베이스 구축 방식 (EC2 직접 구축 vs. Amazon RDS)

**결론:** EKS의 비용을 고려해서 RDS보다 **EC2 직접 구축**하는 방식으로 선택했습니다.

| 비교 항목 | Amazon RDS (관리형) | EC2에 PostgreSQL 직접 구축 **(선정)** |
| :--- | :--- | :--- |
| **구성 (HA)** | Multi-AZ (Primary + Standby) | 3-Node Cluster (Quorum 기반) |
| **인스턴스** | db.t3.medium (2vCPU, 4GB) | t2.medium (2vCPU, 4GB) × 3대 |
| **월간 비용 (24h 기준)** | **약 $163.52** (예산 부담 큼) | **약 $131.61** (약 20% 절감) |
| **선택 이유** | 관리 편의성은 높으나 예산 초과 | 예산 내 운영 가능 및 HA 원리 학습 |
| **비고** | 상세 비용 근거는 3.1 ADR 참조 | OOM 방지를 위해 4GB 메모리 모델 선정 |

<details>
<summary><strong>💰 AWS Pricing Calculator 기준 </strong></summary>
<br>

<table>
  <tr>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/17d9a2a1-d2bf-40fb-a871-35ae0e0b83e3" width="100%" />
    </td>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/336812f6-ec58-4166-b78b-4d18ed4379f1" width="100%" />
    </td>
  </tr>
</table>

</details>

<br>

</details>

<details>
<summary><strong>🔁 2) 고가용성 및 내결함성</strong></summary>

- **Multi-AZ 아키텍처**
    - VPC 및 Subnet을 여러 가용 영역(AZ)에 걸쳐 이중화하여 설계했습니다.
    - EKS 워커 노드와 DB용 EC2 인스턴스를 서로 다른 AZ에 분산 배치하여 인프라 레벨의 장애에 대비합니다.

- **EKS (Compute) 고가용성**
    - **Managed Control Plane:** EKS 관리형 서비스를 통해 Control Plane(마스터 노드)의 HA 및 장애 복구를 AWS에 위임합니다.
    - **Worker Nodes:** Auto Scaling Group(ASG)을 Multi-AZ로 구성하여, 특정 AZ 장애 또는 노드 장애 시 워커 노드가 자동으로 복구 및 재배포되도록 설정합니다.

- **데이터베이스 (Self-Hosted) 고가용성**
    - **RDS 대신 EC2 클러스터링:** 비용 문제로 RDS 대신 EC2 인스턴스를 Multi-AZ에 배포하고, **Patroni**를 사용하여 PostgreSQL DB 클러스터(Active-Standby-Standby)를 자체 구성했습니다.
    
    <br>

    <div align="center">
    <img width="651" height="311" alt="Patroni 3-Node Cluster Architecture" src="https://github.com/user-attachments/assets/0a081da8-c5fb-4102-a8b9-bb040c32579b" />
    </div>

    <br>

    - **Patroni 클러스터 아키텍처 (3-Node):**
        - **etcd (DCS):** 3대의 노드가 `etcd` 클러스터를 구성하여(녹색 화살표) 클러스터의 'Leader'가 누구인지와 같은 상태 정보를 합의하고 공유합니다.
        - **Patroni Agent:** 각 노드의 `patroni` 에이전트(노란색)는 `etcd`와 통신(빨간색 화살표)하여 Leader 정보를 읽고 자신의 상태를 보고하며, 로컬 PostgreSQL 인스턴스를 직접 제어합니다(검은색 수직 화살표).
        - **PostgreSQL:** 다이어그램은 `vm-db02`가 현재 'Leader(Primary)'이며, `vm-db01`, `vm-db03`은 'Replica'로 동작하는 상태를 보여줍니다. 데이터는 Primary에서 Replica로 '물리 복제'(검은색 수평 화살표)됩니다.
    - **Leader 트래픽 보장 (AWS-native):** 온프레미스의 VIP(가상 IP) 이동 방식과 달리, AWS 환경에 최적화된 **NLB**를 사용합니다. NLB가 Patroni API (8008 포트) 헬스체크를 수행하여 DB 도메인이 항상 'Leader' 노드로만 연결되도록 보장합니다.
    - *참고: 본 구성은 [patroni로 구현하는 PostgreSQL 고가용성 (postgresql.kr)](https://postgresql.kr/blog/patroni.html) 문서를 기반으로 구현되었습니다.*

- **애플리케이션 트래픽 및 장애 감지**
    - **ALB (Ingress):** Kubernetes Ingress(ALB)가 Pod 레벨의 Health Check를 수행하여 비정상 Pod로는 트래픽을 라우팅하지 않습니다.
    - **Route 53:** (필요시) Route 53 Health Check를 구성하여 엔드포인트 장애 시 DNS 레벨에서 트래픽을 차단하거나 다른 리전으로 전환할 수 있습니다.

<br>


</details>

<details>
<summary><strong>🔐 3) 보안 및 연결성</strong></summary>

- **네트워크 격리 (Private Subnet):**
    - EKS 워커 노드, PostgreSQL DB 서버(EC2) 등 모든 핵심 애플리케이션 및 데이터 자원은 **Private Subnet**에 배치하여 외부 인터넷에서의 직접적인 접근을 원천 차단합니다.
    - Public Subnet에는 ALB, NLB, VPN Gateway 등 외부 통신에 필요한 최소한의 리소스만 배치합니다.

- **하이브리드 연결 (Site-to-Site VPN):**
    - 온프레미스 환경(예: Vault, 사내 DB)과 AWS VPC(EKS, EC2-DB) 간의 모든 트래픽을 **IPsec 기반 Site-to-Site VPN**으로 암호화하여 안전한 하이브리드 아키텍처를 구성합니다.

- **웹 방화벽 (AWS WAF):**
    - Public 트래픽의 진입점인 ALB(Application Load Balancer) 앞단에 **AWS WAF**를 적용합니다.
    - 이를 통해 SQL Injection, XSS(Cross-Site Scripting) 등 알려진 웹 취약점 공격을 L7 레벨에서 방어합니다.

<br>


</details>

<details>
<summary><strong>⚡ 4) 성능 및 확장성</strong></summary>

- **인메모리 캐싱 (ElastiCache for Redis):**
    
    - 자주 조회되지만 자주 변경되지 않는 데이터를 ElastiCache(Redis)에 캐싱합니다.
    - 이를 통해 PostgreSQL DB 클러스터의 부하를 획기적으로 감소시키고, 애플리케이션의 응답 속도를 향상시킵니다.

- **탄력적 자동 확장 (Autoscaling):**
    
    - **HPA (Horizontal Pod Autoscaler):** CPU, 메모리 사용량 등 지정된 메트릭에 따라 애플리케이션 Pod의 수를 자동으로 늘리거나 줄여 트래픽 변동에 대응합니다.
    - **CA (Cluster Autoscaler):** HPA에 의해 생성된 Pod가 배치될 노드(EC2)가 부족할 경우, EKS 워커 노드의 수를 자동으로 늘려 클러스터 용량 자체를 확장합니다.

<br>

</details>

<details>
<summary><strong>📊 5) 통합 관측 가능성 (Observability)</strong></summary>

- **하이브리드 메트릭 통합 (OpenTelemetry):**
    - **OpenTelemetry(OTel) Collector**를 사용하여 온프레미스 환경(예: vSphere)의 메트릭과 AWS EKS의 메트릭/로그를 수집하여 통합된 관측 환경을 구축합니다.

- **중앙화된 모니터링 (PLG Stack):**
    - 수집된 모든 데이터는 EKS 내에 구축된 **PLG Stack**으로 중앙화하여 관리합니다.
    - **Prometheus:** EKS 및 애플리케이션의 모든 *메트릭*을 수집 및 저장합니다.
    - **Loki:** 모든 Pod 및 시스템의 *로그*를 수집 및 저장합니다.
    - **Grafana:** Prometheus(메트릭)와 Loki(로그)를 단일 데이터 소스로 사용하여, 시스템 전반의 상태를 한눈에 파악할 수 있는 통합 대시보드를 제공합니다.

<br>

</details>

# 2. 🗺️ 아키텍처 다이어그램 (AWS)

<img width="748" height="1232" alt="AWS Architecture" src="https://github.com/user-attachments/assets/462126ff-181e-4244-bbac-7580e1505cf0" />

---

## 3. ✍️ 주요 아키텍처 결정 (ADR)
### 3.1. 비용 최적화: 표준 아키텍처 ($1,054) → 경량 아키텍처 (70%+ 절감)
#### 🧩 문제 상황 – 초기 표준 아키텍처 비용

Terraform Plan을 Infracost로 분석한 결과, **초기 표준 아키텍처의 월 예상 비용은 약 $1,054**였습니다.
<div align="center"> <img width="880" height="105" alt="Image" src="https://github.com/user-attachments/assets/a2fdc02d-b443-449c-a7e5-c87f4f931239" /> </div>

- 주요 구성
  - **RDS PostgreSQL Multi-AZ**
  - **EKS 노드 그룹 (멀티 AZ)**
  - **Multi-AZ NAT Gateway**
- 목적은 “엔터프라이즈 표준에 가까운 구조”였지만,
  - **주어진 예산 $450 안으로 구성**해야 했습니다.

---

#### ✅ 1차 절감 – 아키텍처 구조 변경 (DB Managed → Self-Hosted)

가장 먼저, 전체 비용에서 비중이 컸던 **RDS PostgreSQL Multi-AZ**를 제거하고,  
동일한 “DB 고가용성(HA)” 기능을 **Self-Hosted PostgreSQL 클러스터**로 대체했습니다.
### 🔍 [상세 비용 비교 분석 – AWS Pricing Calculator 기준]

| 비교 항목 | Option A: Amazon RDS (Multi-AZ) | Option B: EC2 Self-Hosted (최종 선정) |
| :--- | :--- | :--- |
| **타겟 모델** | db.t3.medium (Multi-AZ) | t2.medium × 3대 (Quorum Cluster) |
| **사양** | 2vCPU / 4GB RAM / 20GB SSD | 2vCPU / 4GB RAM / 20GB SSD (대당) |
| **월간 비용** | **$163.52** | **$131.61** |
| **절감 효과** | - | **월 약 $32 절감 (약 20%)** |

---

## 💡 기술적 의사결정 근거 1: 인스턴스 패밀리 선정 (Why T2 Family?)

| 비교 모델 | 아키텍처 | 특징 | 선정 여부 |
| :--- | :--- | :--- | :--- |
| **t4g.medium** | ARM(Graviton2) | 성능/가격 최상 | ❌ 기각: Patroni, etcd, Exporter 등 ARM 호환성 리스크 |
| **t3.medium** | x86 | 최신/고성능 | ❌ 기각: Unlimited 모드 → 크레딧 과금 리스크 |
| **t2.medium** | x86 | 안정적/예측 가능한 비용 | ✅ 최종 선정: Standard 모드 → 비용 확정성 |

---

## 💡 기술적 의사결정 근거 2: 사이즈 선정 (Why medium? 4GB RAM)

단순히 “저렴한 스펙”이 아니라, **HA 구성(Patroni + etcd + PostgreSQL)** 이 안정적으로 동작하기 위한  
**메모리 Footprint와 비용 구조를 동시에 고려**하여 최적 사양을 결정했습니다.

### 🔍 메모리 안정성 비교 (t2.micro → t2.medium → t2.large)

| 프로세스 / 영역 | t2.micro (1GB) | t2.medium (4GB) | t2.large (8GB) |
| :--- | :--- | :--- | :--- |
| PostgreSQL + Connection | ❌ OOM 발생 | ✅ 안정적 | ✅ 안정적 |
| etcd (HA State) | ❌ Swap → Heartbeat 지연 | ✅ 메모리 안착 | ✅ 메모리 여유 |
| Failover 안정성 | ❌ Split-brain 빈발 | ✅ 정상 Failover | ✅ 정상 Failover |
| 비용 효율 | ⭐ 매우 저렴 | ⭐ 균형 | ❌ 고비용 |

<details>
<summary><strong>💰 AWS Pricing Calculator 기준 </strong></summary>
<br>

<table>
  <tr>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/17d9a2a1-d2bf-40fb-a871-35ae0e0b83e3" width="100%" />
    </td>
    <td align="center" width="50%">
      <img src="https://github.com/user-attachments/assets/2f4a4f98-2e6c-4910-a313-3e00b1c0c8c3" width="100%" />
    </td>
  </tr>
</table>

</details>

---

### ❗ 최종 결론
1GB·2GB(micro/small) 사양은 HA 환경에서 OOM 및 Split-brain 발생 위험으로 인해 적합하지 않았으며, 8GB(large) 사양은 예산을 초과하였습니다. 따라서 4GB(medium) 사양이 비용과 안정성의 균형을 만족하여 선택하였습니다.


<details>
  
<summary><strong> 🎯 학습 포인트 </strong></summary>

1) **HA 메커니즘 직접 체득**  
- Primary/Replica 전환 조건  
- etcd Quorum 손실 시 동작  
- Patroni 기반 자동 Failover 구조 이해  

2) **클라우드 종속성 감소 (Vendor Lock-in 방지)**  
- RDS 없이도 동일한 HA 구조를 EC2/온프레미스에서 재현 가능  
- PostgreSQL HA 전 과정을 직접 경험하여 운영 역량 강화

</details>

---

## ✅ 2차 절감 – 운영 전략(On-Demand Scheduling)

EC2 기반 DB 구조만으로도 **월 $131.61 → 약 $60~70 수준**까지 추가 절감 가능했습니다.  
"**사용하지 않을 때는 과금하지 않는다**"는 클라우드의 기본 원칙을 지켰습니다.

### 1) 인프라 수명주기 제어 (terraform destroy)

**대상:** 상태 보존 불필요 리소스  
- EKS Worker Nodes  
- NAT Gateway  
- NLB 등

**전략:**
- 개발 시간: 평일 09:00 ~ 02:00 → 인프라 유지  
- 야간/주말: `terraform destroy` 실행 → 비용 0원 처리  
- 시간 기반 과금 리소스 비용 **약 50% 절감**

---

### 2) DB 서버 최적화 (Stop → Start 전략)

**대상:** 데이터 보존 필수 리소스 (EC2 DB 클러스터)

**전략:**
- 매일 퇴근 시 EC2 Stop  
- 실행 중이 아닐 때는 Compute 비용 0원  
- EBS 비용만 유지  

**효과:**  
- 실질 DB 비용: **131.61 → 60~70달러 수준**

---

## 📌 최종 절감 효과

- **설계 최적화:**  
  RDS 대비 약 20% 비용 절감할 수 있었습니다. ($163 → $131)

- **2차 절감 (운영 전략: `terraform destroy` + Hibernation)**
  - EKS / NAT GW / NLB 등 시간 기반 과금 리소스 비용을 50% 이상 절감할 수 있었습니다.

---

### 3.3. 접근 제어: Bastion Host 제거 → WireGuard VPN 단일화
#### 🧩 고민 – 접속 방식 선택

- 후보
  - Bastion Host + SSH ProxyJump
  - AWS SSM Session Manager
  - VPN (pfSense, WireGuard 등)
- 이미 온프레미스에서는 **pfSense + WireGuard**로 내부망에 접속하고 있었고,
- Bastion Host를 추가하면
  - EC2 비용, 키 관리 등 **추가 운영 포인트**가 생기는 문제가 있었습니다.

#### ✅ 결정 – VPN 기반 단일 진입

- 공통 정책
  - 개발자는 **WireGuard VPN만 연결**
  - 이후 모든 Private Subnet의 EC2에 **직접 SSH/DB 접속**
- 효과
  - 온프레미스와 AWS 모두  
    **“VPN 연결 → 내부 IP 접속”이라는 동일한 패턴**으로 단순화
  - SSH 포트를 Public으로 열지 않고,  
    **VPN 단일 진입점만 관리**하여 보안·운영 부담을 줄임

> 정리하면, “VPN만 켜면 로컬 서버 다루듯이 접속할 수 있는 구조”를 목표로 한 접근 제어입니다.

---

### 3.4. 관리 범위 분리: Terraform(Provisioning) vs 수동(Configuration)
#### 🧩 고민 – 어디까지 자동화할 것인가

- 모든 구성을 Terraform + Ansible로 자동화할 수도 있었지만,
- 이 프로젝트의 핵심 목표는
  - **PostgreSQL HA와 클러스터링 내부 동작을 이해하는 것**이었고,
- 처음부터 끝까지 자동화하면  
  “무엇이 어떻게 돌아가는지”를 체감하기 어렵다는 문제가 있었습니다.

#### ✅ 역할 분리

- Terraform이 담당하는 범위 (Provisioning)
  - **VPC / Subnet / Route / Internet/NAT Gateway / Security Group**
  - **EC2 인스턴스 생성 (OS까지 올라온 ‘빈 서버’ 상태)**
  - 공통 네트워크 인프라 및 기본 컴퓨팅 리소스 자동화
  - → `terraform apply/destroy`로 **동일한 랩 환경을 반복 생성/삭제** 가능

- 수동으로 처리하는 범위 (Configuration)
  - EC2 내부에서:
    - PostgreSQL 설치 및 기본 설정
    - etcd / Patroni 설치 및 클러스터 구성
    - NLB 헬스 체크 및 Failover 동작 확인

#### 🎯 의도한 학습 포인트
1. **Provisioning vs Configuration 경계 명확화**
   - Terraform은 “틀(리소스)” 까지,
   - 그 위에 올라가는 “동작(서비스 구성)”은 직접 다뤄봄.
2. **향후 확장 여지 확보**
   - 나중에 Ansible, Packer, cloud-init, GitOps 등을 도입하더라도  
     Terraform 구조는 그대로 유지하고, Configuration만 자연스럽게 자동화로 교체 가능.

---

### 3.5. Secrets 관리: Vault 도입 검토 → 제외
#### 🧩 고민 – Vault 도입 vs 온프레미스 자원 제약

- 계획
  - 온프레미스에 **Vault 3노드 클러스터**를 구성하고,
  - 온프레미스 **민감 DB(블록체인 관련 DB 포함)** 접속 정보를 Vault로 관리하려 했습니다.
- 실제 제약
  - 온프레미스 스토리지 1TB를 여러 팀이 공유하는 환경
  - 실제로 사용 가능한 공간은 **약 430GB 수준**
  - 같은 장비에서 **블록체인 노드/DB**까지 구동하면서 디스크 여유 공간이 빠르게 감소
  - 여기에 Vault(raft 데이터 + audit log)를 3노드로 운영하면  
    **스토리지·운영 부담에 비해 얻는 이점이 크지 않다고 판단**했습니다.

#### ✅ 최종 선택 – Vault 제거

- Vault는
  - 실제로 **3노드 클러스터를 구성해 본 뒤, 자원·효용을 검토하고 제거**했습니다.
- 본 프로젝트 범위에서는
  - 별도의 전용 Secrets 관리 솔루션을 두지 않고,
  - **PostgreSQL HA 실습과 AWS 비용 최적화라는 핵심 목표**에 집중하기로 했습니다.

> 이번 프로젝트에서는 **“과도한 보안 인프라 추가”보다,  
> 한정된 자원 안에서 핵심 학습 목표를 달성하는 것**을 우선했습니다.

<br>

# 4. 🚀 사용 방법
## **1단계: 인프라 구축 (Terraform)**

```bash
cd live/dev/
terraform init
terraform apply

```

---

## **2단계: 서비스 구성**

VPN 접속 후 각 EC2 서버에 직접 HA 구성을 수행합니다.

예시 절차:

1. DB 서버 접속
2. PostgreSQL 설치
3. etcd 구성
4. Patroni 구성
5. Failover 테스트 (Patroni 기반 자동 Failover 확인)
---

## **3단계: 인프라 삭제 (Terraform)**

비용 절감을 위해 실습 후 모든 리소스를 삭제합니다.

```bash
cd live/dev/
terraform destroy

```

---

# 5. 📦 모듈 구성 (Modules)

```
modules/
  ├─ vpc/              # 네트워크 구성
  ├─ ec2/              # EC2 인스턴스 프로비저닝
  ├─ security_group/   # 공통 SG 모듈
  └─ vpn/              # WireGuard VPN 서버 구성

live/
  └─ dev/
       ├─ vpc/
       ├─ ec2/
       ├─ vpn/
       └─ ...

```
