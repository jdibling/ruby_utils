version = "0.1"
$stderr.puts "DeStreamer v#{version}"

# cols = %w(TransactionType TransactionSequence Ticker Bid BidSize Ask AskSize BidDepth AskDepth)
cols = %w(OrderTime TransactionType OrderSku OrderPrice OrderSize ReviseType LastSize MarketParticipantID TransactionSequence)

out = nil
cols.each do |cid|
  if out.nil? then out = String.new else out += '|' end
  out += cid
end
$stdout.puts out

rx_list = Array.new()
cols.each { |col_id|
  rx_list.push /\b(#{col_id})\b=(.*?)(?=$|,\w+=)/i
}

$stdin.each_line { |line|

  out = nil

  rx_list.each { |rx|
    if out.nil? then out = String.new else out += "|" unless out.nil? end
    line.scan(rx).each do |cid, val|
      out += val
    end
  }

  $stdout.puts out unless out.nil?
}


