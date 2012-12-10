version = "0.1"
$stderr.puts "DeStreamer v#{version}"

# cols = %w(TransactionType TransactionSequence Ticker Bid BidSize Ask AskSize BidDepth AskDepth)
# cols = %w(OrderTime TransactionType OrderSku OrderPrice OrderSize ReviseType LastSize MarketParticipantID TransactionSequence)
cols = %w(Ticker TransactionSequence Ask)

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

prev_val = nil

$stdin.each_line { |line|

  out = nil

  has_ask = false;

  rx_list.each { |rx|
    if out.nil? then out = String.new else out += "|" unless out.nil? end
    line.scan(rx).each do |cid, val|
      out += val
      if cid == "Ask" then has_ask = true end
    end
  }

  $stdout.puts out unless (out.nil? || !has_ask)
}


