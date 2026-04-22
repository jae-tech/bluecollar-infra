# 서버 수동 복구 가이드

서버가 초기화되거나 재생성된 경우 이 가이드를 참고하세요.
cloud-init이 자동으로 처리하지만, 수동 복구가 필요한 경우를 위한 문서입니다.

---

## 구성 개요

| 서버 | 역할 | subnet |
|------|------|--------|
| prod | API 백엔드 (Docker) | 10.0.0.0/24 |
| db | PostgreSQL + Redis + NFS | 10.0.1.0/24 |

---

## DB 서버 복구

### 1. 필수 패키지 설치

```bash
sudo apt-get update -y
sudo apt-get install -y \
  apt-transport-https ca-certificates curl gnupg \
  vim git htop unzip wget tmux \
  net-tools dnsutils iputils-ping telnet nmap \
  sysstat iotop \
  ufw fail2ban \
  nfs-kernel-server
```

### 2. Docker 설치

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  > /etc/apt/sources.list.d/docker.list
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu
# 그룹 반영을 위해 재로그인 또는:
newgrp docker
```

### 3. Block Volume 마운트

> Block Volume에 데이터(PostgreSQL, Redis)가 보존되어 있습니다.
> 새 인스턴스에 OCI 콘솔에서 먼저 볼륨을 attach한 후 진행하세요.

```bash
DEVICE=/dev/sdb
# 새 볼륨이면 포맷 (기존 데이터가 있으면 절대 실행하지 마세요)
# sudo mkfs.ext4 $DEVICE

sudo mkdir -p /data
UUID=$(sudo blkid -s UUID -o value $DEVICE)
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mount -a
```

마운트 확인:

```bash
df -h /data
ls /data  # postgres  redis  uploads 디렉토리가 보여야 함
```

### 4. 디렉토리 및 권한 설정

```bash
sudo mkdir -p /data/postgres /data/redis /data/uploads
sudo chown -R 999:999 /data/postgres /data/redis
sudo chown -R ubuntu:ubuntu /data/uploads
sudo chmod 775 /data/uploads
```

### 5. docker-compose 설정

```bash
sudo mkdir -p /app /app/secrets
sudo chown ubuntu:ubuntu /app /app/secrets
sudo chmod 700 /app/secrets
```

`/app/docker-compose.yml` 작성:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_password
    volumes:
      - /data/postgres:/var/lib/postgresql/data
    ports:
      - "55432:5432"

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - /data/redis:/data
    ports:
      - "6379:6379"

secrets:
  postgres_password:
    file: /app/secrets/postgres_password.txt
```

비밀번호 파일 설정 (기존 비밀번호 입력):

```bash
echo "실제비밀번호" > /app/secrets/postgres_password.txt
chmod 600 /app/secrets/postgres_password.txt
chown ubuntu:ubuntu /app/secrets/postgres_password.txt
```

### 6. DB 스택 시작

```bash
cd /app && docker compose up -d
docker compose ps  # postgres, redis 모두 Up 확인
```

### 7. systemd 서비스 등록 (재부팅 시 자동 시작)

```bash
sudo tee /etc/systemd/system/db-stack.service <<'EOF'
[Unit]
Description=DB Stack (PostgreSQL + Redis)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/app
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable db-stack.service
```

### 8. NFS 설정

```bash
# /etc/exports에 이미 있는지 확인 후 추가
grep -q "/data/uploads" /etc/exports || \
  echo "/data/uploads 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl enable nfs-kernel-server
sudo systemctl start nfs-kernel-server
```

### 9. 방화벽 설정

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 55432/tcp
sudo ufw allow 6379/tcp
sudo ufw allow 2049/tcp
sudo ufw --force enable
sudo ufw status
```

### 10. fail2ban 시작

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## Prod 서버 복구

### 1. 필수 패키지 설치

```bash
sudo apt-get update -y
sudo apt-get install -y \
  apt-transport-https ca-certificates curl gnupg \
  nfs-common \
  vim git htop unzip wget tmux \
  net-tools dnsutils iputils-ping telnet nmap \
  sysstat iotop \
  ufw fail2ban
```

### 2. Docker 설치

DB 서버와 동일 (위 참고)

### 3. 앱 디렉토리 및 NFS 마운트

```bash
sudo mkdir -p /app/uploads
sudo chown ubuntu:ubuntu /app

# DB 서버 private IP 확인 후 입력 (terraform output db_private_ip)
DB_PRIVATE_IP="10.0.1.x"
grep -q "uploads" /etc/fstab || \
  echo "${DB_PRIVATE_IP}:/data/uploads /app/uploads nfs defaults,nofail,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a || true
```

### 4. 방화벽 설정

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

### 5. fail2ban 시작

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## 추천 패키지 (선택)

| 패키지 | 용도 |
|--------|------|
| `ncdu` | 디스크 사용량 시각화 |
| `jq` | JSON 파싱 (API 디버깅) |
| `rsync` | 파일 동기화/백업 |
| `logrotate` | 로그 자동 정리 |
| `auditd` | 시스템 감사 로그 |
| `chrony` | NTP 시간 동기화 |
| `lsof` | 열린 파일/포트 확인 |
| `strace` | 시스템 콜 디버깅 |

```bash
sudo apt-get install -y ncdu jq rsync logrotate auditd chrony lsof strace
```

---

## 복구 후 확인 체크리스트

### DB 서버
- [ ] `df -h /data` — Block Volume 마운트 확인
- [ ] `docker compose ps` — postgres, redis 모두 Up
- [ ] `sudo systemctl status db-stack` — 서비스 등록 확인
- [ ] `sudo systemctl status nfs-kernel-server` — NFS 실행 확인
- [ ] `sudo ufw status` — 포트 55432, 6379, 2049, 22 허용 확인

### Prod 서버
- [ ] `mount | grep uploads` — NFS 마운트 확인
- [ ] `sudo ufw status` — 포트 22, 80, 443 허용 확인
- [ ] `docker compose ps` — 앱 컨테이너 실행 확인

---

## 포트 정리

| 포트 | 서비스 | 허용 대상 |
|------|--------|----------|
| 22 | SSH | 0.0.0.0/0 |
| 55432 | PostgreSQL | prod subnet (10.0.0.0/24), 관리자 IP |
| 6379 | Redis | prod subnet (10.0.0.0/24) |
| 2049 | NFS | prod subnet (10.0.0.0/24) |
