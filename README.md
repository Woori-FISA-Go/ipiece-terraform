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

서로 다른 팀끼리 **IP 충돌 없이 네트워크 격리**를 제공하기 위해

각 팀별로 **pfSense 기반 가상 방화벽**을 구축했으며, 서로 다른 사설 IP 대역을 부여받았습니다.

- 예: `172.16.1.x`, `172.16.2.x` …

이를 통해 각 팀은 **독립된 실험 환경**에서 안전하게 개발·테스트를 수행할 수 있었습니다.

</details>

<br>

---

## 1.2. 하이브리드 환경 구축 및 운영 최적화

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
### 데이터베이스 구축 방식 (EC2 직접 구축 vs. Amazon RDS)

**결론: EKS를 사용함으로써 $450 안에서 RDS(특히 HA 구성)는 비용 부담이 너무 커, EC2에 PostgreSQL 클러스터를 직접 구축하기로 결정하였습니다..**

| 비교 항목 | Amazon RDS (관리형) | EC2에 PostgreSQL 직접 구축 |
| :--- | :--- | :--- |
| **주요 특징** | **완전 관리형 서비스** | **IaaS 기반 수동 구축** |
| **월간 비용 (HA 기준)** | **높음** (Multi-AZ 인스턴스 2대 + 스토리지 비용) | **낮음** (Multi-AZ 비용, EC2 인스턴스 3대 + EBS 비용) |
| **운영 오버헤드** | **낮음** (AWS가 패치, 백업, HA 관리) | **높음** (Patroni 등 HA 솔루션, 관리) |
| **선택 이유** | 안정적이나, Multi-AZ 구성 시 **예산을 초과**하여 선택지에서 제외. | HA DB 클러스터를 구축할 수 있는 **현실적 대안.** (Patroni 등 활용) |

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

AWS 인프라를 설계·운영하면서 내린 핵심 기술 결정을 **ADR(Architectural Decision Record)** 형식으로 정리했습니다.  
각 결정은 “왜 이렇게 설계했는지?”를 설명하기 위한 기록입니다.

---

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

- **[ADR 3.2] RDS Multi-AZ ($372.16/월) → EC2 + Patroni HA (약 $49.81/월)**
  - RDS Multi-AZ: **약 $372.16 / 월**
  - Self-Hosted PostgreSQL:
    - `t4g.small` EC2 3대: **약 $41.17 / 월**
    - EBS 스토리지: **약 $8.64 / 월**
    - → 합계 **약 $49.81 / 월**
- **절감 효과**
  - DB 영역만 놓고 보면, **월 약 $322.35** 절감 (약 86% 절감)
  - 기능 측면에서는 여전히 **Multi-AZ + 자동 Failover 구조**를 유지

> 즉, “RDS의 편의성” 대신 “직접 구성한 HA 클러스터”를 선택함으로써  
> **예산 내에서 엔터프라이즈급 아키텍처 학습**이 가능하도록 구조를 조정했습니다.

#### 🎯 의도한 학습 포인트

1. **HA 메커니즘을 직접 체득**
   - Failover가 언제, 어떤 조건에서 일어나는지
   - Primary/Replica 전환 시 클라이언트(애플리케이션) 측 영향
   - 현재는 **Patroni + etcd 기반 자동 Failover**까지 구현했고,  
     Pacemaker/STONITH를 연동한 고가용성은 **향후 실습 과제로 남겨둠**
2. **클라우드 종속성 감소**
   - RDS에만 익숙해지면,  
     온프레미스/다른 클라우드에서 동일 수준의 HA를 설계하기 어려움
   - 온프레미스/PostgreSQL HA 구성경험을 바탕으로 EC2 + Patroni로 AWS에서 HA 구축

> 결과적으로, RDS에 의존하지 않고  
> “Patroni 기반 PostgreSQL HA를 직접 구성할 수 있는 역량”을 목표로 하는 설계이며,  
> 이후 Pacemaker/STONITH까지 확장해보는 것을 장기 학습 계획으로 두고 있습니다.


---

### ✅ 2차 절감 – 운영 전략(운영 시간/리소스 관리)

구조를 바꾼 뒤에도 **NAT Gateway, EKS 노드, NLB** 등은  
**“켜져 있는 시간만큼 계속 과금”**되는 리소스였습니다.  
그래서 아키텍처 자체뿐 아니라 **“운영 방식”**도 함께 설계했습니다.

#### 1) `terraform destroy` 전략 (핵심)

- 개발/실습 시간: **평일 09:00 ~ 21:00 (약 12시간/일)** 만 인프라 유지
- 나머지 시간(야간/주말 등):
  - 프로젝트 초기에 `terraform destroy`를 통해
    - **EKS 노드 그룹**
    - **Multi-AZ NAT Gateway**
    - **DB용 NLB**
  - 등 **비용이 큰 리소스를 전부 삭제**
- 월 730시간 중 **약 360시간(12h × 30일)만 실제 운영**
  - → 해당 리소스들의 **운영비를 약 50.7% 추가 절감**

#### 2) 완전 destroy가 어려운 경우 – 유지보수 모드(Hibernation)

실습 데이터나 환경을 유지해야 하는 경우에는, 완전 삭제 대신 **최소 비용 모드**를 사용했습니다.

- **EKS 노드 그룹**
  - Auto Scaling Group의 `Desired/Min/Max = 0/0/0`으로 설정해 **워커 노드 비용 0**으로 유지
- **NAT Gateway, NLB**
  - 외부 트래픽이 필요 없을 때는 **리소스 자체를 삭제**
- **남는 비용**
  - EKS Control Plane(약 $73/월) + EBS 스토리지 등 **최소한의 비용만 유지**

---

### 📌 최종 효과 – 예산 $450 내에서의 운영

- **1차 절감 (구조 변경: RDS → EC2 Self-Hosted)**
  - DB 비용만 놓고 **약 $322.35/월 절감**
- **2차 절감 (운영 전략: `terraform destroy` + Hibernation)**
  - EKS / NAT GW / NLB 등 **시간 기반 과금 리소스 비용을 50% 이상 절감**

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

> 정리하면, **“VPN만 켜면 로컬 서버 다루듯이 접속할 수 있는 구조”**를 목표로 한 접근 제어입니다.

---

### 3.4. 관리 범위 분리: Terraform(Provisioning) vs 수동(Configuration)
#### 🧩 고민 – 어디까지 자동화할 것인가

- 모든 구성을 Terraform + Ansible로 자동화할 수도 있었지만,
- 이 프로젝트의 핵심 목표는
  - **PostgreSQL HA와 클러스터링 내부 동작을 이해하는 것**이었고,
- 처음부터 끝까지 자동화하면  
  **“무엇이 어떻게 돌아가는지”를 체감하기 어렵다는 문제가 있었습니다.

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
5. Pacemaker 설정
6. Failover 테스트

➡️ `[TODO]` 수동 구성 가이드를 링크 또는 추가 예정

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
