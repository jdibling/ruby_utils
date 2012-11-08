num_top = 5

start_time = nil
scan_period = 
	if $*[0].nil?
		5
	else
		$*[0].to_f
	end

puts "Scanning for #{scan_period} Seconds..."
cont = true

syms = Hash.new(Hash.new(Hash.new(0)))	# sym[level][exchange][symbol] = count


pipe = IO.popen('realtimemp -h:MIS34 2>&0', 'r+' ) 
printf "   "
while cont
	pipe.gets =~ 	/TransactionType=(Order.*?|Quote),.*?Ticker=(([\w|\/]+)\.(\w+?\.\w+))/
	next if $0.nil?

	level = case $1.to_s
		when "Quote" then :level_1
		else :level_2
		end

	exch = $4.to_s
	sym = $3.to_s
	syms[level][exch][sym] += 1
#	puts "syms[#{level}][#{exch}][#{sym}] = #{syms[level][exch][sym]} (#{syms.keys.size})"

	start_time = Time.now.to_f if start_time.nil?
	printf "%s%3.0f", 8.chr * 3, start_time + scan_period - Time.now.to_f
	cont = false if Time.now.to_f >= start_time + scan_period
end

puts "#{8.chr * 3}#{"*"*3} Sorting Results..."

[:level_1, :level_2].each do |level|
	puts "#{"="*3} #{level} #{"="*3}\n"
	syms[level].each_key do |exch |
		puts "Top #{num_top} Quotes For Exchange '#{exch}' :"
#		syms[level][exch].each do {|sym, num| 
#			syms[level[exch][sym].sort_by {|k,v| v}
#			top = syms[level][exch][sym].reverse
			
	end
	
	
end