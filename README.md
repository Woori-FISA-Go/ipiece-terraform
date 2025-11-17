# 1. 🏗️ 프로젝트 배경 및 목표 
## 1.1. 프로젝트 배경 (Context)

<br>

FISA 교육장의 **공용 온프레미스 서버(GSC 01, 04, 05)** 를 기반으로 온프레미스를 구축했으며, **5개 팀이 3대의 물리 서버를 공유**하는 환경이었습니다.

---

### 📸 공용 인프라 구성

<p float="left">
  <img src="https://github.com/user-attachments/assets/ab084db4-2739-4198-8f68-41b3d86f82bb" width="48%" />
  <img src="https://github.com/user-attachments/assets/d27fc3bf-1c74-4748-8dbf-86876a82aecb" width="48%" />
</p>

---

<details>
<summary><strong>① 네트워크 분리 (물리/논리)</strong></summary>

3대의 ESXi 호스트는 모두 **2개 이상의 물리 NIC(vmnic)** 를 사용했습니다.

- 하나의 NIC는 **ESXi 호스트 관리·vCenter** 용도의  
  **‘관리 대역’(Management SWITCH)** 에 연결  
- 다른 NIC는 VM들의 실제 서비스 트래픽을 위한  
  **‘인터넷 대역’(Internet SWITCH)** 에 연결  

vCenter의 중앙 관리 기능(vMotion, 호스트 모니터링, 팀별 리소스 분배 등) 활용하여 5개 팀이 한정된 자원을 격리된 상태로 사용할 수 있게 하였습니다.
</details>

<details>
<summary><strong>② 팀별 가상 네트워크 격리</strong></summary>


5개 팀이 동일한 자원을 사용하더라도 **IP 충돌 없이 독립적인 환경**을 갖도록, 각 팀별로 **가상 방화벽(pfSense)** 를 활용하였습니다.

각 팀은 pfSense를 통해 **독립된 사설 IP 대역**을 부여받았습니다.

- 예: `172.16.1.x`, `172.16.2.x` 등

이를 통해 각 팀은 **다른 팀의 영향을 받지 않는 완전한 네트워크 격리(Isolation)** 환경에서 개발 및 테스트를 수행할 수 있었습니다.

</details>

---

## 1.2. Goal: 하이브리드 환경 구축 및 운영 최적화

온프레미스 인프라 운영 경험을 바탕으로, AWS 클라우드를 연결한 **하이브리드 환경**을 구축하는 것을 다음 목표로 설정했습니다.  
이 아키텍처는 단순히 두 환경을 연결하는 것을 넘어, 아래의 핵심 비즈니스 및 기술적 요구사항을 만족시키도록 설계되었습니다.

---

### 🎯 1) 비용 최적화 (Cost Optimization)

**목표:** 월 AWS 비용 **$450 이내**로 전체 인프라 운영  
**전략:**

- Lambda의 콜드 스타트 및 무상태 아키텍처 특성을 고려해 **EKS 기반 서버 구조 선택**  
  → 관련 참고: [서버리스를 버리자, 성능이 향상되고 아키텍처가 간소화됨 (GeekNews)](https://news.hada.io/topic?id=23695)
- Auto Scaling 활용  
- 적절한 인스턴스 타입 조합(Spot / Graviton 등)으로 비용 절감

---

### 🔁 2) 고가용성 및 내결함성 (High Availability)

**목표:** 특정 컴포넌트 또는 단일 AZ 장애에도 서비스 중단 없이 운영  
**전략:**

- **Multi-AZ 구성:**  
  VPC, EKS 클러스터, RDS 등 모든 핵심 요소를 2개 이상의 AZ에 배포  
- **Health Checks:**  
  Route 53 & ALB를 통해 비정상 엔드포인트 자동 제외  
- **Managed Services:**  
  EKS(Control Plane), RDS(Multi-AZ) 등 관리형 서비스를 활용하여 고가용성을 AWS에 위임

---

### 🔐 3) 보안 및 연결성 (Security & Connectivity)

**목표:**  
온프레미스의 민감 자원(Vault, DB)과 AWS의 애플리케이션(EKS, RDS 등)을  
**Private Subnet에 배치하여 외부 접근을 완전히 차단**

**전략:**

- **Secure Hybrid Link:**  
  AWS Site-to-Site VPN(IPsec)을 활용해 온프레미스 pfSense ↔ AWS VPC 간 통신을 암호화  
- **Web Security:**  
  ALB 앞단에 WAF 배치하여 SQL Injection, XSS 등 공격 방어

---

### ⚡ 4) 성능 및 확장성 (Performance & Scalability)

**목표:** 증가하는 사용자 트래픽을 유연하게 처리하고 빠른 응답 속도 유지  
**전략:**

- **In-Memory Caching:**  
  ElastiCache(Redis) 로 자주 조회되는 데이터/세션을 캐싱 → DB 부하 감소 및 응답 속도 향상  
- **Auto Scaling:**  
  EKS Cluster Autoscaler / HPA를 통해  
  Worker Node & Pod 수를 트래픽에 따라 자동 확장/축소

---

### 📊 5) 통합 관측 가능성 (Unified Observability)

**목표:**  
온프레미스와 AWS에 분산된 로그·메트릭을 **단일 대시보드**에서 모니터링

**전략:**

- OpenTelemetry(OTel) Collector로 vSphere + EKS 환경의 데이터를 통합 수집  
- 수집된 데이터를 AWS EKS 내부의 **PLG 스택 (Prometheus, Loki, Grafana)** 으로 Push  
- 이를 통해 전체 하이브리드 환경의 관측 가능성 확보

# 2. 🗺️ 아키텍처 다이어그램 (AWS)
<img width="748" height="1232" alt="Image" src="https://github.com/user-attachments/assets/462126ff-181e-4244-bbac-7580e1505cf0" />

## 3. ✍️ 주요 아키텍처 결정 (ADR)

이 AWS 인프라를 설계하면서 내린 주요 결정과 그 이유는 다음과 같습니다.

---

### **3.1. 비용 최적화: 표준 아키텍처에서 경량 아키텍처로**

**초기 설계:** Multi-AZ, 다수의 NAT Gateway, Multi-AZ RDS 등 표준 구성 고려  
**문제:** 학습 및 개발 목적의 프로젝트 예산을 크게 초과하는 비용 발생  

**최종 결정:**  
핵심 학습 목표(네트워킹, DB HA)는 유지하되, 리소스를 최소화하고 Terraform destroy 전략을 통해 **비용 제로화** 가능하도록 구성.

---

### **3.2. 데이터베이스: RDS 대신 EC2 + 수동 구성**

**고민:**  
RDS Multi-AZ는 편리하지만 비용이 비싸고 내부 동작 원리 학습이 어려움.

**최종 결정:**  
EC2 인스턴스에 직접 PostgreSQL을 설치하고, Patroni / Pacemaker 등을 이용해 **DB HA 클러스터를 수동 구성**.

**선택 이유:**  
- 비용 절감  
- Failover / Replication / Quorum 등 **DB 이중화·고가용성의 내부 원리**를 깊이 있게 학습하기 위함

---

### **3.3. 접근 제어: Bastion Host 대신 WireGuard VPN 도입**

**배경:**  
- 온프레미스에서도 pfSense 기반의 WireGuard/IPsec VPN으로 협업 환경을 구성했던 경험 존재  
- AWS에서는 Private Subnet 접근을 위해 Bastion Host를 두는 것이 일반적이지만  
  → 관리 포인트 증가  
  → 추가 비용 발생  
  → 온프레미스와 다른 접속 방식으로 운영 복잡도 증가  

**최종 결정:**  
Bastion Host를 제거하고, **WireGuard VPN**을 AWS 환경에 동일하게 구축.

**결과:**  
개발자는 **"VPN 접속" 단 하나의 방식**으로 모든 Private EC2 리소스에 안전하게 접근할 수 있음.

---

### **3.4. 관리 범위 분리: Terraform(Provisioning) vs. 수동(Configuration)**

이 프로젝트는 의도적으로 Terraform의 역할과 수동 구성을 분리했습니다.

#### Terraform이 담당하는 역할 (Provisioning)

- VPC / Subnet / Route Table / Security Group
- EC2 인스턴스 (OS만 설치된 ‘깡통 서버’)
- 기본 네트워킹 인프라 전부

**목표:**  
언제든 동일한 뼈대(네트워크 + 빈 서버)를 빠르게 올리고 지울 수 있도록 설계

#### 수동으로 수행하는 역할 (Configuration)

- EC2 접속 후 PostgreSQL 설치
- Patroni / Pacemaker / etcd 구성
- Failover 및 Replication 직접 설정

**선택 이유:**  
Terraform/Ansible로 자동화가 가능하지만,  
**DB 고가용성 클러스터의 내부 동작을 직접 경험하며 학습하기 위해 의도적으로 수동 구성을 채택**.

---

### **3.5. 보안 (Secrets Management): Vault 도입 검토 및 제외**

**고민:**  
DB 접속 정보, API 키 등 민감 정보를 안전하게 관리하기 위해 Vault 도입 검토.

**최종 결정:** Vault 미도입.

**이유:**  
Vault 자체를 운영하고 HA 구성까지 고려하면 프로젝트 규모 대비 과도한 관리 오버헤드 발생.

**대안:**  
`.tfvars`(Git 제외) 또는 AWS SSM Parameter Store 등 경량 방식 활용.

---

## 4. 🚀 사용 방법 (How to Use)

이 프로젝트는 다음 **2단계 + 삭제 1단계**로 구성됩니다.

---

### **1단계: 인프라 구축 (Terraform)**

Terraform을 통해 실습에 필요한 네트워크(VPC)와 빈 서버(EC2)를 자동으로 생성합니다.

```bash
cd live/dev/
terraform init
terraform apply
### **2단계: 서비스 구성 (수동 작업)**

VPN을 통해 각 EC2 서버에 접속한 뒤, DB HA 클러스터를 직접 구성합니다.

**예시 수동 구성 절차(추가 예정):**

- 
    1. DB 서버 접속
- 
    1. PostgreSQL 설치
- 
    1. etcd 구성
- 
    1. Patroni 설치
- 
    1. Pacemaker 설정
- 
    1. Failover 테스트

➡️ `[TODO]`: 자세한 수동 구성 가이드를 링크하거나 추가할 예정

---

### **3단계: 인프라 삭제 (Terraform)**

실습 후 비용 절감을 위해 모든 리소스를 삭제합니다.

```bash
cd live/dev/
terraform destroy

```

---

## 5. 📦 모듈 구성 (Modules)

```
modules/
  ├─ vpc/              # 네트워크 구성 (VPC, Subnet, Route 등)
  ├─ ec2/              # EC2 인스턴스 생성
  ├─ security_group/   # 공통 SG 모듈
  └─ vpn/              # WireGuard VPN 서버 구성

live/
  └─ dev/
       ├─ vpc/
       ├─ ec2/
       ├─ vpn/
       └─ ...

```

