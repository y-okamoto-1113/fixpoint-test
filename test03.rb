require 'time'

# タイムアウトかどうかの閾値を取得
frequency_threshold = ARGV[0].to_i
timeout_threshold = ARGV[1].to_i

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

# IPアドレス毎の最新ステータス
overflowed_servers = log_details_per_ip.map do |ip, log_details|
  from = (log_details.length - frequency_threshold).negative? ? -log_details.length : -frequency_threshold
  to = -1
  period = log_details[from..to]
  avg = (period.map{|ld| ld[:ping_response].to_i}.sum)/period.length.to_f
  is_overflow = (avg >= timeout_threshold)
  if is_overflow
    { ip: ip, start: period.first[:datetime], end: period.last[:datetime] }
  end
end.compact

# 過負荷状態のサーバアドレスとそのサーバの故障期間を標準出力
overflowed_servers.each do |server|
  mes = <<~EOS
  過負荷状態
  IPアドレス: #{server[:ip]}
  期間: #{server[:start]} ~ #{server[:end]}
  EOS
  puts mes
  puts "="*100
end
