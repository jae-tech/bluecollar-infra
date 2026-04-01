# bluecollar-infra

Oracle Cloud Infrastructure (OCI) Free Tier Terraform 인프라 코드.

## 아키텍처

```
Internet
   │
   ▼
[Load Balancer] (OCI Flex 10Mbps, 무료)
   │  HTTP:80 → HTTPS 리다이렉트
   │  HTTPS:443 → prod 인스턴스
   ▼
[Prod Instance] (A1 Flex, 2 OCPU / 12GB, Ubuntu 24.04)
   │  Docker Compose — 백엔드 앱
   │
   │  내부 통신 (PostgreSQL 5432, Redis 6379)
   ▼
[Dev/DB Instance] (A1 Flex, 2 OCPU / 12GB, Ubuntu 24.04)
   │  Docker Compose — PostgreSQL 16 + Redis 7
   │
   ▼
[Block Volume] 106GB — DB 데이터 영구 저장

[Bastion Service] — SSH 접근 (외부 SSH 차단, Bastion만 허용)
```

## Free Tier 비용

| 리소스 | 비용 |
|--------|------|
| A1 Flex 인스턴스 × 2 (총 4 OCPU / 24GB) | 무료 |
| Boot Volume × 2 (50GB × 2 = 100GB) | 무료 |
| Block Volume (106GB) | 무료 |
| Load Balancer (10Mbps Flex) | 무료 |
| Bastion Service | 무료 |
| VCN / 서브넷 / IGW | 무료 |
| **합계** | **$0/월** |

> 아웃바운드 데이터 10GB/월 무료. 초과 시 과금 주의.

## 사전 준비

- OCI 계정 (Free Tier 활성화)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) 설치 및 설정
- SSH 키페어 (`ssh-keygen`)

## 사용법

### 1. 변수 설정

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 열어서 아래 값 입력:

| 변수 | 설명 | 확인 방법 |
|------|------|-----------|
| `tenancy_ocid` | 테넌시 OCID | OCI 콘솔 → 우상단 프로필 → Tenancy |
| `user_ocid` | 사용자 OCID | OCI 콘솔 → 우상단 프로필 → User Settings |
| `fingerprint` | API 키 핑거프린트 | User Settings → API Keys |
| `private_key_path` | API 키 PEM 파일 경로 | 로컬 경로 (절대경로 사용) |
| `region` | OCI 리전 | 예: `ap-chuncheon-1` |
| `compartment_id` | 컴파트먼트 OCID | OCI 콘솔 → Identity → Compartments |
| `ssh_public_key` | SSH 공개키 | `cat ~/.ssh/id_ed25519.pub` |

### 2. Terraform 실행

```bash
terraform init
terraform plan
terraform apply
```

> **Out of capacity 에러** 발생 시 — OCI A1 Flex는 Free Tier 인기가 높아 용량 부족이 흔함.
> `retry.sh`로 자동 재시도:
> ```bash
> bash retry.sh
> # 또는 백그라운드 실행
> nohup bash retry.sh > retry.log 2>&1 &
> ```

### 3. 배포 후 SSH 접속 (Bastion)

```bash
# Bastion 세션 생성 (outputs에서 명령어 복사)
terraform output bastion_session_cmd_prod
terraform output bastion_session_cmd_devdb
```

출력된 명령어 실행 → OCI CLI가 SSH 프록시 명령어를 돌려줌.

### 4. Dev/DB 인스턴스 — DB 시작

```bash
# Bastion으로 접속 후
cd /app
# PostgreSQL 패스워드 변경 (기본값: changeme)
echo "your_password" > secrets/postgres_password.txt
docker compose up -d
```

## 파일 구조

```
├── main.tf              # Provider, 이미지 데이터소스
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값 (IP, Bastion 명령어)
├── networking.tf        # VCN, 서브넷, IGW, Security List
├── compute.tf           # 인스턴스 2개
├── storage.tf           # Block Volume
├── bastion.tf           # Bastion Service
├── loadbalancer.tf      # LB, Backend Set, Listener, Rule Set
├── cloud-init/
│   ├── prod.yaml        # Prod 인스턴스 초기화 (Docker 설치)
│   └── devdb.yaml       # Dev/DB 인스턴스 초기화 (Docker + 볼륨 마운트)
├── terraform.tfvars.example  # 변수 템플릿
└── retry.sh             # Out of capacity 자동 재시도 스크립트
```

## 주의사항

- `terraform.tfvars` — 시크릿 포함, **절대 커밋 금지** (gitignore 처리됨)
- `backend.tf` — Customer Secret Key 포함, **절대 커밋 금지** (gitignore 처리됨)
- Block Volume은 `prevent_destroy = true` 설정 — `terraform destroy`로도 삭제 안 됨 (데이터 보호)
- HTTPS 리스너는 `loadbalancer.tf` 하단 주석 처리 — 도메인 + 인증서 준비 후 활성화
