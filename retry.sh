#!/bin/bash
# 1시간마다 terraform apply 재시도 — 인스턴스 생성 성공하면 자동 종료

cd "$(dirname "$0")"

while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] terraform apply 시도..."
  terraform apply -auto-approve 2>&1

  if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 성공! 모든 리소스 생성 완료."
    break
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 실패. 10분 후 재시도..."
  sleep 600
done
