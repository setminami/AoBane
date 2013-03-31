#! ruby
# AoBane Command-line Interface
#
require 'optparse'
require 'benchmark'
require 'stringio'
require 'pathname'

require 'AoBane'

module AoBane
	class CUI
		module FormatType
			TEXT = 'text'
			DOCUMENT = 'document'
		end
		
		include FormatType
	
		FORMAT_TYPE_TABLE = {
			'document' => DOCUMENT,
			'bfdoc' => DOCUMENT,
			'text' => TEXT,
			'bftext' => TEXT,
		}
		
		HELP = <<-EOS
AoBane - Extended Markdown Converter

Usage: AoBane [options] file1 [file2 file3 ..]

Options:
  -e, --encoding NAME   parse input files as encoding of NAME.
                        (s[hift(_-)jis] / e[uc-jp] / u[tf-8] / a[scii]
                         default: 'utf-8')
  -f, --format TYPE     specify format.
                        (t[ext]      => text mode
                         d[ocument]  => document mode)
      --force           write even if target files have not changed.
                        (default: only if target files have changed)
  -h, --help            show this help.
  -o, --output DIR      output files to DIR. (default: same as input file)
  -q, --quiet           no output to stderr.
      --suffix .SUF     specify suffix of output files. (default: '.html')
  -v, --verbose         verbose mode - output detail of operation.
      --version         show AoBane version.

Advanced Usage:
  * If specify files only '-', AoBane read from stdin and write to stdout.


Example:
  AoBane *.bftext *.bfdoc
  AoBane -v --sufix .xhtml -o ../ sample.markdown
  AoBane -

More info:
  see <https://github.com/setminami/AoBane/>
		EOS
	
		def self.run(*args)
			self.new.run(*args)
		end
		
		
		
		attr_reader :stdout, :stderr, :stdin
	
		def initialize(stdout = $stdout, stderr = $stderr, stdin = $stdin)
			@stdout, @stderr, @stdin = stdout, stderr, stdin
		end
		
		def run(argv)
			op = OptionParser.new
			
			verbose = false
			quiet = false
			force = false
			suffix = '.html'
			format = nil
			output_dir_path = nil
			encoding = EncodingType::UTF_8
			
			
			message_out = @stderr
			
			
			op.on('-e', '--encoding NAME') do |v|
				case v.downcase
				when /^sh?i?f?t?[-_]?j?i?s?$/
					encoding = EncodingType::SHIFT_JIS
				when /^eu?c?-?j?p?$/
					encoding = EncodingType::EUC_JP
				when /^ut?f?-?8?$/
					encoding = EncodingType::UTF_8
				when /^as?c?i?i?$/
					encoding = EncodingType::ASCII
				else
					message_out.puts "ERROR: invalid encoding - #{v}"
					message_out.puts "Expected: s[hift(-_)jis] / e[uc-jp] / u[tf-8] / a[scii]"
					return false
				end
			end
			op.on('-f', '--format TYPE', FORMAT_TYPE_TABLE){|x| format = x}
			op.on('--force'){|x| force = true}
			op.on('-v', '--verbose'){ verbose = true }
			op.on('-o', '--output DIR', String){|x| output_dir_path = Pathname.new(x)}
			op.on('-q', '--quiet'){ message_out = StringIO.new }
			op.on('--suffix .SUF', String){|x| suffix = x}
			op.on('--version'){
				@stdout.puts "AoBane #{VERSION_LABEL}"
				return false
			}
			op.on('-h', '--help'){
				@stdout.puts HELP
				return false
			}
			
			args = op.parse(argv)
			
			if args.empty? then
				message_out.puts "ERROR: please text file paths, patterns, or '-' (stdin-mode).\nEx) AoBane *.bfdoc"
				return false
			end
			
			message_out.puts "default encoding: #{encoding}" if verbose
			
			unless defined?(Encoding) then
				# ruby 1.8 or earlier
				original_kcode = $KCODE
				$KCODE = EncodingType.convert_to_kcode(encoding)
			end
			
			begin
				if args == ['-'] then
					if verbose then
						message_out.puts "AoBane: stdin -> stdout mode." 
						message_out.puts "----"
					end
					src = @stdin.read
					if defined?(Encoding) then
						# ruby 1.9 or later
						src.force_encoding(EncodingType.regulate(encoding))
					end
					
					# default: text
					if format == DOCUMENT then
						@stdout.write(AoBane.parse_document(src, encoding))
					else
						@stdout.write(AoBane.parse_text(src))
					end
				else
					targets = []
					
					args.each do |pattern|
						targets.concat(Pathname.glob(pattern.gsub('\\', '/')))
					end
					
					if targets.empty? then
						message_out.puts "ERROR: targets not found.\n(patterns: #{args.join(' ')})"
						return false
					end
					
					targets.each do |src|
						ext = src.extname
						
						if output_dir_path then
							filename = src.basename.to_s.sub(/#{Regexp.escape(ext)}$/, suffix)
							dest = (output_dir_path + filename).cleanpath
						else
							dest = Pathname.new(src.to_s.sub(/#{Regexp.escape(ext)}$/, suffix)).cleanpath
						end
						
						html = nil
						current_format = format
						
						if ext == suffix then
							message_out.puts "#{src} skipped. (suffix = #{suffix})" if verbose
						elsif not force and dest.exist? and (dest.mtime > src.mtime) then
							message_out.puts "#{src} skipped. (not changed)" if verbose
						else
							# judge by extname if format is not specified
							unless current_format then
								case ext
								when '.bfdoc', '.md'
									current_format = DOCUMENT
								else
									current_format = TEXT
								end
							end
							
							# parse
							parser = AoBane::Parser.new
							this_encoding = nil
							parsing_sec = Benchmark.realtime{
								case current_format
								when DOCUMENT
									doc = nil
									open(src, 'r'){|f|
										doc = AoBane::Document.parse_io(f, encoding)
									}
									html = parser.document_to_html(doc)
									this_encoding = doc.encoding_type
								when TEXT
									open_mode = (defined?(Encoding) ? "r:#{encoding}" : 'r')
									text = src.open(open_mode){|x| x.read}
									html = parser.parse_text(text)
									this_encoding = encoding
								end
							}
						
							if html then
								open(dest, 'w'){|f|
									f.write(html)
								}
								message_out.puts "#{src} => #{dest} (#{File.size(dest)} byte)"
						
								if verbose then
									message_out.puts "    Format: #{current_format}"
									message_out.puts "    Encoding: #{this_encoding}"
									message_out.puts sprintf('    Parsing Time: %g sec', parsing_sec)
									message_out.puts
								end
							end # if html
						end # if ext == suffix
						
					end # targets.each
				end # if stdin-mode
				
			ensure
				unless defined?(Encoding) then
					# recover original $KCODE
					$KCODE = original_kcode
				end
			
			end # begin
			
			
			return true
		end # def run
	end # class CUI
end # module AoBane