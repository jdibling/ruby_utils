require 'optparse'
require 'ostruct'
require 'rexml/document'
require 'pp'

class Optparse
	def self.parse(args)	
		options = OpenStruct.new
		options.config_file = nil
		options.ifc = nil
		options.template = nil
		options.mode = :sips
		options.whitelist = nil
		
		opts = OptionParser.new do |opts|			
			opts.banner = "Usage: parse_cme_sfg.rb config-file interface template-file [options]"
			opts.separator ""
			opts.separator "Specific options:"
			
			# Mode [optional]
			opts.on("-m", "--mode MODE", [:sips, :mdumps]) do |mode|
				options.mode =  mode
			end
		   
		  # Whitelist [optional]
		  opts.on("-w", "--whitelist WHITELIST") do |whitelist|
		  	options.whitelist = whitelist.scan(/\d+/).map(&:to_i)
		  end
		  
		  # Help 
			opts.on_tail("-h", "--help", "Show this message") do
			  puts opts
			  exit
			end			
			
			opts.parse!(args)
			
			# now pull out the positional arguments
			if args.empty?
				$stderr.puts "Congfig File Not Specified\n\n#{opts}"
				exit;
			end
			if !File.exist?(args[0])
				$stderr.puts "Config File Not Found: #{args[0]}"
				exit
			end
			options.config_file = File.open(args.delete_at(0),"rb")
			
			if args.empty? 
				$stderr.puts "Interface Not Specified\n\n#{opts}"
				exit
			end
			options.ifc = args.delete_at(0)
			
			if args.empty?
				$stderr.puts "FAST Template Not Specified\n\n#{opts}"
				exit
			end
			options.template = args.delete_at(0)
			
			return options
		end
		
	end
end

options = Optparse.parse(ARGV)

$stderr.puts "Parsing CME Config File Found At '#{options.config_file.path}'..."

config = options.config_file.read
doc = REXML::Document.new(config)

feeds = Hash.new  # feeds[chan-id][type][side] = conn-element

doc.elements.each("configuration/channel") { |ch|
  chan_id = ch.attributes["id"].to_s
  #chan_name = ch.attributes["label"].to_s

  next if !options.whitelist.nil? and !options.whitelist.include?(chan_id.to_i)

  ch.elements.each("connections/connection") { |conn|
    f_type =  conn.elements["type"].attributes["feed-type"].to_s.upcase
    f_id =    conn.attributes["id"].to_s
    f_proto = conn.elements["protocol"].text.to_s.upcase

    next if f_proto.nil? or f_proto != "UDP/IP"   # we don't care about non-multicast

    f_side =  conn.elements["feed"].text.to_s.upcase
    f_port =  conn.elements["port"].text.to_s.upcase
    f_ip =    conn.elements["ip"].text.to_s.upcase

    #puts "f_type = #{f_type}"

    feeds[chan_id]                  = Hash.new if feeds[chan_id].nil?
    type =
        case f_type
          when "H"  then :historical
          when "N"  then :instrument_replay
          when "S"  then :snapshot
          when "I"  then :incremental
          else      :invalid
        end
    feeds[chan_id][type]          = Hash.new("#{f_type}") if feeds[chan_id][type].nil?

#   when "H"  then  :historical
#   when "N"  then  :replay
#   when "S"  then  :snapshot

    side =
        case f_side
          when "A"  then  :primary
          when "B"  then  :backup
          else            :invalid
        end

    feeds[chan_id][type][side]  = Hash.new

    #puts "#{f_type}/#{side}"

    feeds[chan_id][type][side][:ip] = f_ip
    feeds[chan_id][type][side][:port] = f_port
    feeds[chan_id][type][side][:id] = f_id
  }
}

feeds.each {|chan_id,chan_types|

  if options.mode == :sips
    sip_name = "CMEFAST_#{chan_id}"
    puts  "<#{sip_name}>"
    puts    "\t<DllName>cmefast</DllName>"
    puts    "\t<DisconnectWhenDown>true</DisconnectWhenDown>"
    puts    "\t<Channel>ProcessedFuturePrice</Channel>"
    puts    "\t<ContentData>ProcessedFuturePrice</ContentData>"
  end

  chan_types.reject{|chan_type, chan_sides|
    case chan_type
      when :historical  then true
      else            false
    end
    }.each {|chan_type, chan_sides|

      # put the primary & backups
      chan_sides.reject {|chan_side,conn| chan_side == :invalid || chan_side == :historical }.each {|chan_side,conn|
        next if case chan_type
                  when :instrument_replay, :snapshot then chan_side != :primary
                  else false
                end
        line_name = case chan_type
                      when :incremental then chan_side.to_s.capitalize
                      when :instrument_replay then  "Recovery1"
                      when :snapshot then "Recovery2"
                    end
        if options.mode == :mdumps
          puts "start \"#{conn[:id]}\" mdump #{conn[:ip]} #{conn[:port]} #{ifc}"
        elsif options.mode == :sips
          puts    "\t<#{line_name}>"
          puts      "\t\t<!-- #{chan_type.to_s}/#{chan_side.to_s} -->"
          puts      "\t\t<Interface>#{options.ifc}</Interface>"
          puts      "\t\t<TemplateName>#{options.fast_template}</TemplateName>"
          puts      "\t\t<SipType>MultiCast</SipType>"
          puts      "\t\t<TargetName>#{conn[:ip]}</TargetName>"
          puts      "\t\t<Port>#{conn[:port]}</Port>"
          puts      "\t\t<MaxLen>1048536</MaxLen>"
          puts    "\t</#{line_name}>"
        end
    }
  }

  puts "</#{sip_name}>"  if options.mode == :sips

}


