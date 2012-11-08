require 'getoptlong'

puts "mostactive.rb : Displays the most active symbols on a MIS"

opts = GetoptLong.new(
	["--host", "-h", GetoptLong::REQUIRED_ARGUMENT],
	["--number-to-show", "-n", GetoptLong::OPTIONAL_ARGUMENT],
	["--scan-time", "-t", GetoptLong::OPTIONAL_ARGUMENT]
)

num_top = 10
scan_period = 30
host_mis = nil
parsing_error = false

opts.each do |opt, arg|
	arg = arg[1,arg.length] if arg[0,1].to_s == ":"
	
	case opt
	when "--host" then host_mis = arg.to_s
	when "--scan-time" then
		scan_period = arg.to_i
		if scan_period.nil? then
			puts "Ivalid '-t' Argument '#{arg}': Must Be An Integer > 0"
		end
	when "--number-to-show" then
		num_top = arg.to_i
		if num_top.nil? then
			puts "Ivalid '-n' Argument '#{arg}': Must Be An Integer > 0"
		end
	else
		puts "Unrecognized Option: '#{opt}'"
		parsing_error = true
	end
end

if parsing_error || num_top.nil? || host_mis.nil? then
	puts "usage:"
	puts "  mostactive -h (mis) [-n (number to show)]"
	exit 1
end

start_time = nil
scan_period = scan_period.to_f

puts "Scanning #{host_mis} for #{scan_period} Seconds..."
cont = true

# syms = Hash.new(Hash.new(Hash.new(0)))
syms = Hash.new{|h1,k1| h1[k1]=Hash.new{|h2,k2| h2[k2]=Hash.new(0)}}

STDOUT.sync = true
pipe = IO.popen('c:\\c\\spryware\\bin\\realtimemp 2>&1', 'r+' )
printf "open"
while cont
	if pipe.nil? 
		cont = false
		continue
	end
	line = pipe.gets
	next if line.nil?
	next if line =~ /TransactionType=SystemMessage/
	line.scan(/TransactionType=(Order.*?|Quote|Trade),.*?Ticker=(([\w|\/]+)\.(\w+?\.\w+))/).each do |action, full_tick, und, xchg|
		level = case action.to_s
			when "Quote" then :level_1
			else :level_2
			end
#		syms[level] = Hash.new if !syms.has_key?(level)
#		syms[level][xchg] = Hash.new(0) if !syms[level].has_key?(xchg)
		
		syms[level][xchg][und] += 1
#		puts "syms[#{level}][#{xchg}][#{und}] = #{syms[level][xchg][und]} (#{syms.keys.size})"
	end
	
	if start_time.nil? 
		start_time = Time.now.to_f 
		printf "Started at #{start_time}\n"
	end
	time_remain = (start_time + scan_period) - Time.now.to_f
	printf "%s%3.0f", 8.chr * 3, start_time + scan_period - Time.now.to_f

	cont = false if Time.now.to_f >= start_time + scan_period
	
end

puts "#{8.chr * 3}#{"*"*3} Sorting Results..."

[:level_1, :level_2].each { |level|
	puts "#{"="*3} #{level} #{"="*3}\n"
	syms[level].each_key do |exch|
		puts "Top #{num_top} Quotes For Exchange '#{exch}' :"
		top_syms = (syms[level][exch].sort{|lhs,rhs| rhs[1] <=> lhs[1] })[0,num_top]
		top_syms.each_with_index { |e, i|
			puts "  [#{i}]: #{e[0]} = #{e[1]}"
		}
		

#		syms[level][exch].each do {|sym, num|
#			syms[level[exch][sym].sort_by {|k,v| v}
#			top = syms[level][exch][sym].reverse

	end


}
