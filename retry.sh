#!/bin/bash

# OCI Free Tier 용량 부족 시 terraform apply 재시도 스크립트
# 사용법: ./retry.sh [ad_index]
# 예시: ./retry.sh        (기본 ad_index=0)
#       ./retry.sh 1      (ad_index=1)

AD_INDEX=${1:-0}
INTERVAL=60  # 1분

echo "terraform apply 재시도 시작 (ad_index=$AD_INDEX, 간격 ${INTERVAL}초)"

until terraform apply -auto-approve -var="ad_index=$AD_INDEX"; do
  echo ""
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 용량 부족. ${INTERVAL}초 후 재시도..."
  sleep $INTERVAL
done

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 성공!"
