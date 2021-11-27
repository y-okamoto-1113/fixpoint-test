require 'time'

# タイムアウトかどうかの閾値を取得
threshold = ARGV[0].to_i

# ログファイル読み込み
file = File.open("./sample.log", "r").read

# ファイルを改行でsplit
logs = file.split("\n")

# ログをKey-Valueに細分化
log_details = logs.map do |log|
  datetime, ip, ping_response = log.split(",")
  datetime = Time.parse(datetime)
  { datetime: datetime, ip: ip, ping_response: ping_response }
end


# IPアドレスごとにログを分割
log_details_per_ip = log_details.group_by{|ld| ld[:ip]}

# IPアドレス毎に、タイムアウトになった時間・復旧した時間のインデックスを取得
timeouts_per_ip = {}
log_details_per_ip.keys.each{ |ip| timeouts_per_ip[ip] = [] }
log_details_per_ip.map do |ip, lds|
  lds.map.with_index do |ld, i|
    if (ld[:ping_response] == "-")
      next if (lds[i-1][:ping_response] == "-") # 連続してタイムアウトした場合はタイムアウト時間を1つにまとめるので
      start_index = i
      ok_log_index = lds[i..-1].find_index{|v| v[:ping_response] != "-"}

      # 最終ログのステータスがタイムアウトの場合で条件分岐
      if ok_log_index.nil?
        end_index = nil
      else
        # タイムアウトの連続回数が`threshold`未満の場合は、タイムアウトと判断しない
        next if ok_log_index < threshold
        end_index = i + ok_log_index
      end
      timeouts_per_ip[ip] << { start_index: start_index, end_index: end_index }
    end
  end
end



# IPアドレス毎に、タイムアウト開始時間・復旧時間・タイムアウト期間をKey-Value型に整形
results = timeouts_per_ip.map{ |ip, timeouts|
  timeouts.map do |timeout|
    start_index, end_index = timeout[:start_index], timeout[:end_index]
    lds = log_details_per_ip[ip]
    timeout_start = lds[start_index][:datetime]
    if end_index.nil?
      timeout_end = nil
      period = "タイムアウト中。まだ復旧していない。"
    else
      timeout_end = lds[end_index][:datetime]
      minites, seconds = (timeout_end - timeout_start).divmod(60).map(&:to_i)
      hour, minites = minites.divmod(60).map(&:to_i)
      period = "#{hour}時間#{minites}分#{seconds}秒"
    end
    { ip: ip, start: timeout_start, end: timeout_end, period: period }
  end
}.flatten


# 故障状態のサーバアドレスとそのサーバの故障期間を標準出力
results.each do |res|
  mes = <<~EOS
  タイムアウト発生
  IPアドレス: #{res[:ip]}
  期間: #{res[:start]} ~ #{res[:end]} ( #{res[:period]} )
  EOS
  puts mes
  puts "="*100
end
