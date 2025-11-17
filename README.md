# 1. 🏗️ 프로젝트 배경 및 목표

## 1.1. 프로젝트 배경 (Context)

FISA 교육장의 **공용 온프레미스 서버(GSC 01, 04, 05)** 를 기반으로 온프레미스를 구축했으며,

**5개 팀이 3대의 물리 서버를 공유하는 환경**이었습니다.

---

### 📸 공용 인프라 구성

<p float="left">
  <img src="https://github.com/user-attachments/assets/ab084db4-2739-4198-8f68-41b3d86f82bb" width="48%" />
  <img src="https://github.com/user-attachments/assets/d27fc3bf-1c74-4748-8dbf-86876a82aecb" width="48%" />
</p>

---

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

서로 다른 팀끼리 **IP 충돌 없이 완전한 네트워크 격리(Isolation)** 를 제공하기 위해

각 팀별로 **pfSense 기반 가상 방화벽**을 구축했습니다.

각 팀은 서로 다른 사설 IP 대역을 부여받았습니다.

- 예: `172.16.1.x`, `172.16.2.x` …

이를 통해 각 팀은 **독립된 실험 환경**에서 안전하게 개발·테스트를 수행할 수 있었습니다.

</details>

---

## 1.2. Goal: 하이브리드 환경 구축 및 운영 최적화

온프레미스 인프라 운영 경험을 바탕으로, AWS 클라우드와 연동한 **하이브리드 인프라** 구축을 목표로 했습니다.

아래의 다섯 가지 핵심 요구사항을 충족하도록 설계했습니다.

---

### 🎯 1) 비용 최적화 (Cost Optimization)

**목표:** 월 AWS 비용 **$450 이하**로 운영

**전략:**

- Lambda의 콜드 스타트·무상태 아키텍처 한계를 고려해 **EKS 기반 서버 구조 선택**
    
    → 참고: [서버리스를 버리자, 성능 향상 및 아키텍처 단순화 (GeekNews)](https://news.hada.io/topic?id=23695)
    
- Auto Scaling 적극 활용
- Spot / Graviton 기반으로 비용 절감

---

### 🔁 2) 고가용성 및 내결함성 (High Availability)

- **Multi-AZ 구성:** VPC, EKS, RDS 등 주요 자원 AZ 다중화
- **Health Checks:** ALB + Route53 기반 장애 자동 감지
- **Managed Control Plane:** EKS·RDS의 고가용성을 AWS에 위임

---

### 🔐 3) 보안 및 연결성 (Security & Connectivity)

- 온프레미스(Vault/DB) ↔ AWS(EKS/RDS)를 **IPsec 기반 Site-to-Site VPN으로 암호화**
- 모든 주요 자원을 **Private Subnet** 에 배치
- ALB 앞단에 WAF 적용 → SQL Injection, XSS 방어

---

### ⚡ 4) 성능 및 확장성 (Performance & Scalability)

- **ElastiCache(Redis)** 로 캐싱 → DB 부하 감소·응답속도 향상
- **HPA + Cluster Autoscaler** 로 트래픽 증가 시 자동 확장

---

### 📊 5) 통합 관측 가능성 (Unified Observability)

- OpenTelemetry Collector로 vSphere + EKS 메트릭 통합
- EKS 내 **PLG Stack(Prometheus / Loki / Grafana)** 로 중앙화

---

# 2. 🗺️ 아키텍처 다이어그램 (AWS)

<img width="748" height="1232" alt="AWS Architecture" src="https://github.com/user-attachments/assets/462126ff-181e-4244-bbac-7580e1505cf0" />

---

# 3. ✍️ 주요 아키텍처 결정 (ADR)

AWS 인프라를 설계하며 내린 핵심 기술 결정(Architectural Decision Record)입니다.

---

## **3.1. 비용 최적화: 표준 아키텍처 → 경량 아키텍처**

- 초기: Multi-AZ NAT Gateway, Multi-AZ RDS 등 **표준 엔터프라이즈 구성** 고려
- 문제: 학습/개발 규모에 비해 **비용 과다**
- 결정: 네트워크·DB HA 학습 목표는 유지하되, 비용이 드는 리소스는 최소화
- 결과: Terraform destroy 전략으로 **연속 비용 제로화** 가능

---

## **3.2. 데이터베이스: RDS 대신 EC2 + 수동 구성**

- 고민: RDS Multi-AZ는 편리하지만 → 비용 높음 + 내부 원리 학습 어려움
- 결정: EC2에 직접 PostgreSQL 설치 후 Patroni / Pacemaker / etcd로 **수동 HA 구성**
- 이유:
    - 비용 절감
    - Failover / Replication / Quorum 등 **DB HA 메커니즘** 완전 이해 목적

---

## **3.3. 접근 제어: Bastion Host 제거 → WireGuard VPN 통일**

- 온프레미스에서 이미 pfSense + WireGuard 경험 보유
- Bastion Host는 관리 포인트 증가 + 추가비용 + 환경 불일치
- 결정: **WireGuard VPN 하나로 온프레미스·AWS 모두 접속 통일**
- 결과: 개발자는 **“VPN만 연결하면 모든 Private EC2에 접근”** 가능

---

## **3.4. 관리 범위 분리: Terraform(Provisioning) vs. 수동(Configuration)**

### Terraform이 담당 (Provisioning)

- VPC/Subnet/Route/Security Group
- EC2 ‘빈 서버’ 생성
- 공통 네트워크 인프라 자동화
    
    → 목적: **언제든 동일한 구조를 반복 생성/삭제 가능**
    

### 수동 구성 (Configuration)

- PostgreSQL 설치
- etcd / Patroni / Pacemaker 설정
- Failover 테스트
    
    → 이유: 자동화 대신 **HA 내부 동작을 직접 체득하기 위한 교육 목적**
    

---

## **3.5. Secrets 관리: Vault 도입 검토 → 제외**

- 고민: Vault는 강력하지만 자체 HA + 운영 부담 큼
- 결정: 프로젝트 규모 대비 관리 오버헤드 과다 → **도입하지 않음**
- 대안: `.tfvars`(Git 제외) 또는 AWS Parameter Store 활용

---

# 4. 🚀 사용 방법 (How to Use)

이 프로젝트는 다음 **2단계 + 종료 1단계**로 진행됩니다.

---

## **1단계: 인프라 구축 (Terraform)**

```bash
cd live/dev/
terraform init
terraform apply

```

---

## **2단계: 서비스 구성 (수동 작업)**

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
