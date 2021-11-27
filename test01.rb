require 'time'

# ログファイル読み込み
file = File.open("./sample.log", "r").read

# ファイルを改行でsplit
logs = file.split("\n")

# ログをKey-Valueに細分化
log_details = logs.map.with_index do |log, index|
  datetime, ip, ping_response = log.split(",")
  datetime = Time.parse(datetime)
  { datetime: datetime, ip: ip, ping_response: ping_response }
end


# タイムアウトしたログとレスポンスが復活したログのインデックス番号を取得
timeout_indexes_sets = log_details.map.with_index do |log_detail, index|
  if (log_detail[:ping_response] == "-")
    next if (log_details[index-1][:ping_response] == "-")
    start_index = index
    ok_log_index = log_details[index..-1].find_index{|v| v[:ping_response] != "-"}

    # 最終ログのステータスがタイムアウトの場合で条件分岐
    if ok_log_index.nil?
      end_index = nil
    else
      end_index = index + ok_log_index
    end
    {start_index: start_index, end_index: end_index}
  end
end.compact


# タイムアウト期間中のサーバーIP、タイムアウト開始時間・復旧時間・タイムアウト期間をKey-Value型に整形
timeouts = timeout_indexes_sets.map do |set|
  start_index, end_index = set[:start_index], set[:end_index]
  ip = log_details[start_index][:ip]
  timeout_start = log_details[start_index][:datetime]
  if end_index.nil?
    timeout_end = nil
    period = "タイムアウト中。まだ復旧していない。"
  else
    timeout_end = log_details[end_index][:datetime]
    minites, seconds = (timeout_end - timeout_start).divmod(60).map(&:to_i)
    hour, minites = minites.divmod(60).map(&:to_i)
    period = "#{hour}時間#{minites}分#{seconds}秒"
  end
  {ip: ip, start: timeout_start, end: timeout_end, period: period}
end


# 故障状態のサーバアドレスとそのサーバの故障期間を標準出力
timeouts.each do |timeout|
  mes = <<~EOS
  タイムアウト発生
  IPアドレス: #{timeout[:ip]}
  期間: #{timeout[:start]} ~ #{timeout[:end]} ( #{timeout[:period]} )
  EOS
  puts mes
  puts "="*100
end
