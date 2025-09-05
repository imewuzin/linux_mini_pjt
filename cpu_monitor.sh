PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOGDIR=/home/ubuntu/01.awk/01-1.cron_awk_pjt
LOGFILE=$LOGDIR/cpu_usage.log
ALERT=$LOGDIR/cpu_alert.log
THRESHOLD=80   # 기준치 (%)

RESULT=$(/usr/bin/sar -u 1 1 | /usr/bin/awk '/^Average:/ {
  printf("[%s] CPU:%.2f%% user:%.2f%% sys:%.2f%% idle:%.2f%%",
  strftime("%Y-%m-%d %H:%M:%S"), $3+$5, $3, $5, $8)
}')

echo "$RESULT" >> $LOGFILE

USAGE=$(echo $RESULT | /usr/bin/awk -F'CPU:' '{print $2}' | /usr/bin/awk '{print $1}' | sed 's/%//')

if (( $(echo "$USAGE > $THRESHOLD" | /usr/bin/bc -l) )); then
  echo "$RESULT ⚠️ CPU High (기준치 ${THRESHOLD}%)" >> $ALERT
  TOPPROC=$(/usr/bin/ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6)

  GRAPH=$(tail -n 10 $LOGFILE | \
    awk -F'[][]' '{time=$2; match($0,/CPU:([0-9.]+)%/,a); usage=a[1]; \
    printf("%s | %5.1f%% | ", time, usage); for(i=0;i<usage/2;i++) printf("#"); print ""}')

  {
    echo "Subject: ⚠️ CPU 사용량 초과 알림 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Content-Type: text/html; charset=UTF-8"
    echo
    echo "<html><body>"
    echo "<h2 style='color:red;'>⚠️ CPU 사용량 초과 경고</h2>"
    echo "<p><b>시간:</b> $(date '+%Y-%m-%d %H:%M:%S')</p>"
    echo "<p><b>현재 CPU 사용량:</b> ${USAGE}% (기준치: ${THRESHOLD}%)</p>"
    echo "<hr>"
    echo "<h3>Top 5 프로세스</h3>"
    echo "<pre style='background:#f4f4f4; padding:10px; border:1px solid #ccc;'>"
    echo "$TOPPROC"
    echo "</pre>"
    echo "<hr>"
    echo "<h3>📊 최근 CPU 사용량 추세 (최근 10분)</h3>"
    echo "<pre style='background:#eef; padding:10px; border:1px solid #99c;'>"
    echo "$GRAPH"
    echo "</pre>"
    echo "<hr>"
    echo "<h3>💡 CPU 사용량 낮추는 방법</h3>"
    echo "<ul>"
    echo "<li>불필요한 프로세스 종료: <code>kill -9 [PID]</code></li>"
    echo "<li>과부하 작업(예: stress 테스트, 대용량 빌드) 중지</li>"
    echo "<li>실행 중 서비스 최적화 (Nginx, DB 등 설정 튜닝)</li>"
    echo "<li>VM/서버라면 vCPU 추가 할당 고려</li>"
    echo "<li>정기적으로 <code>top</code>, <code>htop</code> 모니터링</li>"
    echo "</ul>"
    echo "</body></html>"
  } | msmtp -a naver erin90523@naver.com
fi
