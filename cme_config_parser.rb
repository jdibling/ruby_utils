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
		options.additional_tags = Array.new
		
		opts = OptionParser.new do |opts|			
			opts.separator ""

			opts.banner = 	"Sips Usage:    \tparse_cme_sfg.rb config-file interface template-file [--mode sips] [options]\n"
			opts.banner += 	"Capdata Usage: \tparse_cme_sfg.rb config-file [interface] [template-file] --mode capdata [options]\n"
			opts.banner +=	"List Usage:    \tparse_cme_sfg.rb config-file [interface] [template-file] --mode list [options]\n"
			opts.banner +=	"mdump Usage:   \tparse_cme_sfg.rb config-file [interface] [template-file] --mode mdump [options]\n"
			
			opts.separator ""
			opts.separator "Specific options:"			
			
			# Mode [optional]
			opts.on("-m", "--mode MODE", [:sips, :mdumps, :capdata, :list]) do |mode|
				options.mode =  mode
			end
		   
		  # Whitelist [optional]
		  opts.on("-w", "--whitelist WHITELIST") do |whitelist|
		  	options.whitelist = whitelist.scan(/\d+/).map(&:to_i)
		  end
		  
		  # Additional Tags [optional]
		  opts.on("-t", "--additional-tag TAG") do |add_tag|
		  	options.additional_tags.push add_tag.to_s
		  end
		  
		  # Help 
			opts.on_tail("-h", "--help", "Show this message") do
			  puts opts
			  exit
			end			
			
			# Version
			opts.on_tail("--version", "Show version") do
				$stderr.puts "0.91"
				exit
			end
			
			opts.parse!(args)
			
			# now pull out the positional arguments required by all modes
			if args.empty?
				$stderr.puts "Congfig File Not Specified\n\n#{opts}"
				exit;
			end
			if !File.exist?(args[0])
				$stderr.puts "Config File Not Found: #{args[0]}"
				exit
			end
			options.config_file = File.open(args.delete_at(0),"rb")
			
			# pull out positional arguments needed in :sips mode
			if options.mode == :sips
				
				if args.empty? 
					$stderr.puts "Interface Not Specified.  Required in sips mode\n\n#{opts}"
					exit
				end
				options.ifc = args.delete_at(0)
				
				if args.empty?
					$stderr.puts "FAST Template Not Specified.  Required in sips mode\n\n#{opts}"
					exit
				end
				options.template = args.delete_at(0)
				
				return options
			end
		end
	end
end

options = Optparse.parse(ARGV)

$stderr.puts
$stderr.puts "Config File: \t#{options.config_file.path}"
$stderr.puts "Interface: \t#{options.ifc}"
$stderr.puts "Template: \t#{options.template}"
$stderr.puts "Whitelist: \t(#{options.whitelist.size}) [#{options.whitelist.inject(""){|r,e| r += ", " if !r.empty?; r + e.to_s}}]" if !options.whitelist.nil?
if !options.whilelist.nil?
	$stderr.puts "Channel Whitelist: #{options.whitelist}\n"
end
if !options.additional_tags.empty?
	$stderr.puts "Additional Tags: (#{options.additional_tags.size})"
	options.additional_tags.each do |tag|
		$stderr.puts "\t#{tag}"
	end
end

$stderr.puts "\nProcessing.  Patience...\n\n"

config = options.config_file.read
doc = REXML::Document.new(config)

feeds = Hash.new  # feeds[chan-id][type][side] = conn-element
names = Hash.new	# names[chan-id] = chan-name

doc.elements.each("configuration/channel") { |ch|
  chan_id = ch.attributes["id"].to_s
  chan_name = ch.attributes["label"].to_s
  
  names[chan_id] = chan_name

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
    puts 		"\t<xName>#{names[chan_id].gsub(" ","_")}</xName>"
    options.additional_tags.each do |tag|
    	puts	"\t#{tag}"
    end
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
          puts "start \"#{conn[:id]}\" mdump #{conn[:ip]} #{conn[:port]} #{options.ifc}"
        elsif options.mode == :list
        	longest = names.values.inject { |acc,x|  if x.length > acc.length then x else acc end }
        	 puts "#{sprintf("(%3d) %-*s", chan_id, longest.length ,names[chan_id])}\t#{sprintf("%-20s",chan_type.to_s)}\t#{chan_side.to_s}\t#{conn[:ip]}\t#{conn[:port]}"
        elsif options.mode == :capdata
        	puts "start \"#{conn[:id]}\" capdata #{conn[:ip]} #{conn[:port]} #{options.ifc} #{conn[:id]}.cap"
        elsif options.mode == :sips
          puts    "\t<#{line_name}>"
          puts      "\t\t<!-- #{chan_type.to_s}/#{chan_side.to_s} -->"
          puts      "\t\t<Interface>#{options.ifc}</Interface>"
          puts      "\t\t<TemplateName>#{options.template}</TemplateName>"
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

$stderr.puts "Done."


