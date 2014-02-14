#!/usr/bin/env ruby

class String
  def colorize(code)
    "\x1B[#{code}m" + self + "\x1B[0m"
  end
  
  def red; colorize(31); end
  def green; colorize(32); end
  def blue; colorize(34); end

  def key?
    self[0]=='-'
  end
end

module YoutubeSubtitler

	### PARSER ###
	class Parser
		require 'rexml/document'
		require 'cgi'
		include REXML

		def parse(raw_text)
			# getting <transcript> element of input raw xml file
			transcript = Document.new(raw_text).root

			# initializing output variable
			text = ""

			# parsing
			transcript.each do |doc|
				text << CGI::unescapeHTML(doc.text).gsub(/^\s*/, '') << " " if doc.text != nil
			end

			text
		end
	end

	### DOWNLOADER ###
	# Downloads raw xml subtitle file, if video link is correct
	# and specified language file exists for this video
	class Downloader
		require 'open-uri'
		require 'rexml/document'
		include REXML

		def initialize(lang)
			@lang = lang
		end

		# will return [nil, nil] if link is incorrect
		def download(link)
			match = /^(?:(?:http:\/\/)?(?:www)?youtu\.be\/)(.+)$/.match(link)
			if !match
				match = /^(?:(?:http:\/\/)?(?:www\.)?youtube\.com\/watch\?v=)(.+)&.*$/.match(link)
			end
			video_id = match[1] if match

			(return ["'#{link}', wrong link", nil]) if video_id.nil?

			# check for language avalability
			languages = get_languages(video_id)
			unless languages.include?(@lang)
				error = "'#{link}', no such language (available: #{languages.join(', ')})"
			  return [error, nil]
			end

			text = open("http://video.google.com/timedtext?lang=#{@lang}&v=#{video_id}").read
			text.gsub!(/\n/, ' ')

			[text, video_id]
		end

	private

		def get_languages(video_id)
			langs = []
			raw_langs = open("http://www.youtube.com/api/timedtext?type=list&v=#{video_id}")
			Document.new(raw_langs).elements.each('*/track') do |track|
				langs << track.attributes['lang_code']
			end

			langs
		end
	end

	### SAVER ###
	# Saves subtitles array content to output_dir/subtitles_TIMESTAMP
	# If collect is true, saves all of it in one file, else
	# creates a new file for each string (colled ###_video_VIDEO_ID)
	class Saver
		def initialize(output_dir)
			@dir = output_dir
		end

		# Raises RuntimeError exception if smth wrong with output file
		def save(subtitles=[], collect=false)
			begin
				subtitles.each.with_index do |entry, index|
					filename = if collect then "#{@dir}/all_subtitles.txt"
					else "#{@dir}/#{(index+1).to_s.rjust(3,'0')}_video_#{entry[:id]}.txt"
					end
					File.open(filename, 'a+') do |file|
						file.write("\n\n\n") if collect and index > 0
						file.write("Video ##{index+1}: #{entry[:id]}\n\n")
						file.write("#{entry[:text]}")
					end
				end
			rescue => e
				raise RuntimeError.new("Failed creating output file.")
			end
		end
	end

	### LOGGER ###
	# creates file output_dir/filename and simply logs to it
	class Logger
		def initialize(output_dir, filename)
			@log = nil
			@dir = output_dir
			@filename = filename
		end

		def log(text)
			@log ||= File.new("#{@dir}/#{@filename}", 'w')
			@log.puts(text)
		end
	end

	### SUBTITLER ###
	# Gets subtitles from specified list of youtube video links,
	# creates dir 'subtitles_TIMESTAMP' in specified directory
	# and saves subtitle file(s) there
	class Subtitler
		def initialize(output_dir, language='en')
			dir_path = output_dir+"/subtitles_#{Time.now.to_i.to_s}"
			create_dir(dir_path)

			@downloader = Downloader.new(language)
			@parser = Parser.new
			@saver = Saver.new(dir_path)
			@logger = Logger.new(dir_path, 'errors.log')
		end

		# if _collect == true all subtitles would be saved in one file
		def get_subtitles(list_of_links=[], _collect=false)
			collect = (_collect==true ? true : false)
			subtitles = []
			loaded = skipped = 0
			list_of_links.each do |link|
				raw_text, video_id = @downloader.download(link)
				if video_id
					subtitles << {id: video_id, text: @parser.parse(raw_text)}
					puts "Loaded".green + ": #{video_id}"
					loaded += 1
				else
					puts "Skipped".red + ": #{raw_text}"
					skipped += 1
					@logger.log(link)
				end
			end
			puts "Total: #{loaded} loaded, #{skipped} skipped"
			puts "Saving..."
			@saver.save(subtitles, collect)
			puts "Done"
		end

	private

		def create_dir(path)
			begin
				Dir.mkdir(path)
			rescue => e
				raise RuntimeError.new("Output directory couldn't be created.")
			end
		end
	end
end

### APP ###
class App
	require 'uri'
	include YoutubeSubtitler

	def initialize
		@link_list = []
		@collect = false
		@dir = nil

		parse_args()

		begin
			subtitler = Subtitler.new(@dir, @language)
			subtitler.get_subtitles(@link_list, @collect)
		rescue => e
			error("(#{e.class}) #{e}")
		end
	end

private

	def parse_args
    ARGV.each do |arg|
    	if ['h','-h','\\h','help','-help','\\help','?','-?','/?'].include?(arg)
    		info()
    		usage()
    		exit
    	elsif arg.key?
				if ['-c', '--collect'].include?(arg) then @collect = true 
    		elsif /^-l(.+)$/ =~ arg then @language = $1
    		else error("Wrong key: #{arg}", :usage)
    		end
    	elsif File.directory?(arg) and @dir.nil?
    		@dir = arg.sub(/\/$/, '')
    	elsif arg =~ URI::regexp
    		@link_list << arg
    	else
    		error("Wrong parameter: #{arg}", :usage)
    	end

    	@language ||= 'en'
    end

    if $stdin.stat.size > 0
    	$stdin.each do |line|
    		@link_list << line.chomp if line =~ URI::regexp
    	end
    end

    @dir = Dir.pwd if @dir.nil?
  end

  def info
  	print <<-INFO.gsub(/(^\s+)|(@@\s)/, '').gsub(/@n/, "\n")
  		@n\t\t\t\t#{'YOUTUBE SUBTITLER'.green}@n
  		Youtube subtitler is a script that could help @@
  		you to download subtitles for single or many youtube videos @@
  		at once.@n
  		All subtitles files would be saved in a new directory named @@
  		subtitles_TIMESTAMP, where TIMESTAMP is a sequence of digits. @@
  		You can specify a path where this directory would be created.@n
  		Script allows you to choose prefered language of subtitles @@
  		(yet youtube could not have this language) using the -l key.@n
  		You can also specify the key -c (or --collect) in order to tell @@
  		the script to save all subtitles in one file.@n
  		If an error occures with any of given links, script will @@
  		log these links to file 'subtitles_TIMESTAMP/errors.log' so @@
  		you can correct your links or perhaps choose another language @@
  		and give this links to the script again using '< errors.log'@n
		INFO
  end
  
  def usage
    print "USAGE".green
    puts ": youtube_subtitler.rb [OUTPUT_DIR, -c, -lLANG] LINKS\n\n"
    puts "  LINKS\n\tWhitespace-separated list of youtube links\n\n"
    puts "  OUTPUT_DIR\n\tDirectory where to create output files\n\n"
    puts "  -lLANG\n\tAllows to specify desired subtitles language (LANG)\n\n"
    puts "  -c, --collect\n\tCollect all subtitles in one file 'all_subtitles.txt'"
    puts "\nMade for you by Vizvamitra (#{"vizvamitra@gmail.com".blue}, Russia)"
    puts "Special thanks to Dmitry aka Blackbird~"
  end

  def error(message, show_usage=nil)
    puts "ERROR".red + ": " + message
    usage() if show_usage == :usage
    exit
  end
end

app = App.new()