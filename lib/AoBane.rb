#
# AoBane - Extended Markdown Converter
#
# Author of Original BlueFeather: Dice <tetradice@gmail.com>
# Remaker: set.minami <set.minami@gmail.com>
# Website: https://github.com/setminami/AoBane/blob/master/README.md
# License: GPL version 2 or later
#
#  If you want to know better about AoBane, See the Website.
#
#
#
#-- Copyrights & License -------------------------------------------------------
#
# Original Markdown:
#   Copyright (c) 2003-2004 John Gruber
#   <http://daringfireball.net/>  
#   All rights reserved.
#
# Orignal BlueCloth:
#   Copyright (c) 2004 The FaerieMUD Consortium.
#
# AoBane:
#   Copyright (c) 2013 Set.Minami
#
# AoBane is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
# 
# AoBane is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.


require 'digest/md5'
require 'logger'
require 'strscan'
require 'stringio'
require 'uri'


module AoBane
	VERSION = '0.01'
	VERSION_NUMBER = 0.01
	RELEASE_DATE = '2013-03-30'
	VERSION_LABEL = "#{VERSION} (#{RELEASE_DATE})"
	
	UTF8_BOM = "\xef\xbb\xbf"
	UTF8_BOM_PATTERN = /^#{UTF8_BOM}/


	# Fancy methods
	class << self
		def parse_text(src)
			Parser.new.parse_text(src)
		end
		
		alias parse parse_text
		
		def parse_document(src, default_enc = EncodingType::UTF8)
			Parser.new.parse_document(src, default_enc)
		end


		def parse_text_file(path)
			Parser.new.parse_text_file(path)
		end
		
		alias parse_file parse_text_file
		
		def parse_document_file(path, default_enc = EncodingType::UTF8)
			Parser.new.parse_document_file(path, default_enc)
		end
	end
	
	### Exception class on AoBane running.
	class Error < ::RuntimeError
	end
	
	class EncodingError < Error
	end
	
	### Exception class for formatting errors.
	class FormatError < Error

		### Create a new FormatError with the given source +str+ and an optional
		### message about the +specific+ error.
		def initialize( str, specific=nil )
			if specific
				msg = "Bad markdown format near %p: %s" % [ str, specific ]
			else
				msg = "Bad markdown format near %p" % str
			end

			super( msg )
		end
	end
	
	module HeaderIDType
		MD5 = 'md5'
		ESCAPE = 'escape'
	end
	
	module EncodingType
		EUC = 'euc-jp'
		EUCJP = EUC_JP = EUC
		
		SJIS = 'shift_jis'
		SHIFT_JIS = SJIS
		
		UTF8 = 'utf-8'
		UTF_8 = UTF8
		
		ASCII = 'ascii'
		US_ASCII = ASCII
		
		def self.regulate(str_value)
			case str_value.downcase
			when 'shift-jis', 'shift_jis'
				SJIS
			when 'euc-jp'
				EUC
			when 'utf-8'
				UTF8
			when 'ascii'
				ASCII
			else
				raise EncodingError, "not adapted encoding type - #{str_value} (shift[-_]jis, euc-jp, utf-8, or ascii)"
			end
		end
		
		def self.convert_to_kcode(str_value)
			type = self.regulate(str_value)
			case type
			when EUC, SJIS, UTF8
				type
			when ASCII
				'none'
			end
		end

		
		def self.convert_to_charset(str_value)
			type = self.regulate(str_value)
			case type
			when EUC
				'euc-jp'
			when SJIS
				'shift_jis'
			when UTF8
				'utf-8'
			when ASCII
				nil
			end
		end

	end
	
	module Util
		HTML_ESC = {
			'&' => '&amp;',
			'"' => '&quot;',
			'<' => '&lt;',
			'>' => '&gt;'
		}
		
		module_function
		
	  # from http://jp.rubyist.net/magazine/?0010-CodeReview#l28
		# (Author: Minero Aoki)
		def escape_html(str)
			#table = HTML_ESC   # optimize
			#str.gsub(/[&"<>]/) {|s| table[s] }
			return str
		end
		
		def generate_blank_string_io(encoding_base)
			io = StringIO.new
			
			if io.respond_to?(:set_encoding) then
				io.set_encoding(encoding_base.encoding)
			end
			
			return io
		end
		
		def change_kcode(kcode = nil)
			if defined?(Encoding) then
				# ruby 1.9 later
				yield
			else
				# ruby 1.8 earlier
				original_kcode = $KCODE
			
				begin
					$KCODE = kcode if kcode
					yield
					
				ensure
					# recover
					$KCODE = original_kcode
				end
			end # if defined?
		end # def
		
		
		def utf8_bom?(str)
			if str.respond_to?(:getbyte) and str.respond_to?(:bytesize) then
				if str.bytesize >= 3 and
				str.getbyte(0) == UTF8_BOM.getbyte(0) and
				str.getbyte(1) == UTF8_BOM.getbyte(1) and
				str.getbyte(2) == UTF8_BOM.getbyte(2) then
					return true
				else
					return false
				end
				
			else
				return(str =~ UTF8_BOM_PATTERN ? true : false)
			end
		end
	end
	
	class Document
		HEADER_PATTERN = /^([a-zA-Z0-9-]+?)\s*\:\s*(.+?)\s*(?:\n|\Z)/
		BLANK_LINE_PATTERN = /^\n/
		HEADER_SEQUEL_PATTERN = /^\s+(.+)$/
		
		attr_accessor :headers, :body
		alias text body
		alias text= body=
		
		class << self
			def parse_io(input, default_enc = EncodingType::UTF8)
				headers = {}
				body = nil
				first_pos = input.pos
				default_enc = EncodingType.regulate(default_enc)
				
				Util.change_kcode(EncodingType.convert_to_kcode(default_enc)){
					# default encoding
					if defined?(Encoding) then
						input.set_encoding(Encoding.find(default_enc))
					end
					
					
					
					# get headers
					pos_before_gets = nil
					first_line = true

					loop do
						pos_before_gets = input.pos
						line = input.gets
						
						# cut UTF-8 BOM
						if first_line and Util.utf8_bom?(line) then
							line.slice!(UTF8_BOM_PATTERN)
						end	
						first_line = false
						
						if line and line.chomp =~ HEADER_PATTERN then
							key = $1.downcase; value = $2
							
							if key == 'encoding' and not headers.include?('encoding') then
								kc = EncodingType.convert_to_kcode(value.downcase)
								if input.respond_to?(:set_encoding) then
									input.set_encoding(EncodingType.regulate(value))
									
									# rewind (reason => [ruby-list:45988])
									input.pos = first_pos
									first_line = true
								else
									$KCODE = kc
								end
							end
							
							headers[key] = value
						else
							# EOF or Metadata end
							break
						end
					end
					
					# back
					input.pos = pos_before_gets
					
					
					
					# skip blank lines
					loop do
						pos_before_gets = input.pos

						line = input.gets
						if line.nil? or not line =~ BLANK_LINE_PATTERN then
							break
						end
					end
					
					# back
					input.pos = pos_before_gets
					
					
					
					# get body
					body = input.read

				}
				
				
				return self.new(headers, body)
			end
			
			def parse(str, default_enc = EncodingType::UTF8)
				parse_io(StringIO.new(str), default_enc)
			end
	
		end
		
		
		def initialize(headers = {}, body = '')
			@headers = {}
			headers.each do |k, v|
				self[k] = v
			end
			@body = body
		end
		
		def [](key)
			@headers[key.to_s.downcase]
		end
		
		def []=(key, value)
			@headers[key.to_s.downcase] = value.to_s
		end
		
		def title
			@headers['title']
		end
		
		def css
			@headers['css']
		end
		
		def numbering
			case @headers['numbering']
			when 'yes', '1', 'true', 'on'
				true
			else
				false
			end
		end
		
		alias numbering? numbering
		
		def numbering_start_level
			level = (@headers['numbering-start-level'] || 2).to_i
			if level >= 1 and level <= 6 then
				return level
			else
				return 2
			end
		end
		
		def encoding_type
			@headers['encoding'] || EncodingType::UTF8
		end
		
		def header_id_type
			(@headers['header-id-type'] || HeaderIDType::MD5).downcase
		end
		
		def kcode
			self.encoding_type && EncodingType.convert_to_kcode(self.encoding_type)
		end
		
		def to_html
			Parser.new.document_to_html(self)
		end
	end

	
	class Parser
		# Rendering state class Keeps track of URLs, titles, and HTML blocks
		# midway through a render. I prefer this to the globals of the Perl version
		# because globals make me break out in hives. Or something.
		class RenderState
			# Headers struct.
			Header = Struct.new(:id, :level, :content, :content_html)
		
			# from Original BlueCloth
			attr_accessor :urls, :titles, :html_blocks, :log
			
			# AoBane Extension
			attr_accessor :footnotes, :found_footnote_ids, :warnings
			attr_accessor :headers, :block_transform_depth
			attr_accessor :header_id_type # option switch
			attr_accessor :numbering, :numbering_start_level # option switch
			alias numbering? numbering
			
			def initialize
				@urls, @titles, @html_blocks = {}, {}, {}
				@log = nil
				@footnotes, @found_footnote_ids, @warnings = {}, [], []
				@headers = []
				@block_transform_depth = 0
				@header_id_type = HeaderIDType::MD5
				@numbering = false
				@numbering_start_level = 2
			end
			
		end
	
		# Tab width for #detab! if none is specified
		TabWidth = 4
	
		# The tag-closing string -- set to '>' for HTML
		EmptyElementSuffix = " />";
	
		# Table of MD5 sums for escaped characters
		EscapeTable = {}
		'\\`*_{}[]()#.!|:~'.split(//).each {|char|
			hash = Digest::MD5::hexdigest( char )
	
			EscapeTable[ char ] = {
	 			:md5 => hash,
				:md5re => Regexp::new( hash ),
				:re  => Regexp::new( '\\\\' + Regexp::escape(char) ),
				:unescape => char,
			}
			
			escaped = "\\#{char}"
			hash = Digest::MD5::hexdigest(escaped)
			EscapeTable[escaped] = {
				:md5 => hash,
				:md5re => Regexp::new( hash ),
				:re  => Regexp::new( '\\\\' + Regexp::escape(char) ),
				:unescape => char,
			}
		}
	
	
		#################################################################
		###	I N S T A N C E   M E T H O D S
		#################################################################
	
		### Create a new AoBane parser.
		def initialize(*restrictions)
			@log = Logger::new( $deferr )
			@log.level = $DEBUG ?
				Logger::DEBUG :
				($VERBOSE ? Logger::INFO : Logger::WARN)
			@scanner = nil
	
			# Add any restrictions, and set the line-folding attribute to reflect
			# what happens by default.
			@filter_html = nil
			@filter_styles = nil
			restrictions.flatten.each {|r| __send__("#{r}=", true) }
			@fold_lines = true
			
			@use_header_id = true
			@display_warnings = true
	
			@log.debug "String is: %p" % self
		end
	
	
		######
		public
		######
	
		# Filters for controlling what gets output for untrusted input. (But really,
		# you're filtering bad stuff out of untrusted input at submission-time via
		# untainting, aren't you?)
		attr_accessor :filter_html, :filter_styles
	
		# RedCloth-compatibility accessor. Line-folding is part of Markdown syntax,
		# so this isn't used by anything.
		attr_accessor :fold_lines
		
		# AoBane Extension: display warnings on the top of output html (default: true)
		attr_accessor :display_warnings
	
		# AoBane Extension: add id to each header, for toc and anchors. (default: true)
		attr_accessor :use_header_id
		
		### Render Markdown-formatted text in this string object as HTML and return
		### it. The parameter is for compatibility with RedCloth, and is currently
		### unused, though that may change in the future.
		def parse_text(source, rs = nil)
			rs ||= RenderState.new
			
			# check
			case rs.header_id_type
			when HeaderIDType::MD5, HeaderIDType::ESCAPE
			else
				rs.warnings << "illegal header id type - #{rs.header_id_type}"
			end
	
			# Create a StringScanner we can reuse for various lexing tasks
			@scanner = StringScanner::new( '' )
	
			# Make a copy of the string with normalized line endings, tabs turned to
			# spaces, and a couple of guaranteed newlines at the end
			
			text = detab(source.gsub( /\r\n?/, "\n" ))
			text += "\n\n"
			@log.debug "Normalized line-endings: %p" % text
	
			#Insert by set.minami 2013-03-30
			text.gsub!(/\*\[(.*?)\]\((.*?)(\|.*?)*(#.*?)*\)/){
			|match|
			'<font color="' + 
			if $2.nil? then '' else $2 end  +'" ' +
			'face="' + 
			if $3.nil? then '' else $3.delete('|') end + '" ' +
			'size="' +
			if $4.nil? then '' else $4.delete('#') end + '">' +
			$1 + '</font>'
			}
			#Insert by set.minami
			
			# Filter HTML if we're asked to do so
			if self.filter_html
				#text.gsub!( "<", "&lt;" )
				#text.gsub!( ">", "&gt;" )
				@log.debug "Filtered HTML: %p" % text
			end
			
			# Simplify blank lines
			text.gsub!( /^ +$/, '' )
			@log.debug "Tabs -> spaces/blank lines stripped: %p" % text
			
	
			# Replace HTML blocks with placeholders
			text = hide_html_blocks( text, rs )
			@log.debug "Hid HTML blocks: %p" % text
			@log.debug "Render state: %p" % rs
			
			
			# Strip footnote definitions, store in render state
			text = strip_footnote_definitions( text, rs )
			@log.debug "Stripped footnote definitions: %p" % text
			@log.debug "Render state: %p" % rs

	
			# Strip link definitions, store in render state
			text = strip_link_definitions( text, rs )
			@log.debug "Stripped link definitions: %p" % text
			@log.debug "Render state: %p" % rs
			
			# Escape meta-characters
			text = escape_special_chars( text )
			@log.debug "Escaped special characters: %p" % text
	
			# Transform block-level constructs
			text = apply_block_transforms( text, rs )
			@log.debug "After block-level transforms: %p" % text
	
			# Now swap back in all the escaped characters
			text = unescape_special_chars( text )
			@log.debug "After unescaping special characters: %p" % text
			
			# Extend footnotes
			unless rs.footnotes.empty? then
				text << %Q|<div class="footnotes"><hr#{EmptyElementSuffix}\n<ol>\n|
				rs.found_footnote_ids.each do |id|
					content = rs.footnotes[id]
					html = apply_block_transforms(content.sub(/\n+\Z/, '') + %Q| <a href="#footnote-ref:#{id}" rev="footnote">&#8617;</a>|, rs)
					text << %Q|<li id="footnote:#{id}">\n#{html}\n</li>|
				end
				text << %Q|</ol>\n</div>\n|
			end
			
			# Display warnings
			if @display_warnings then
				unless rs.warnings.empty? then
					html = %Q|<pre><strong>[WARNINGS]\n|
					html << rs.warnings.map{|x| Util.escape_html(x)}.join("\n")
					html << %Q|</strong></pre>|
					
					text = html + text
				end
			end
	
			#Insert by set.minami 2013-03-30
			output = []
			text.lines {|line|
			  if /<pre><code>/ =~ line
			    output << line
			    next
			    until /<\/code><\/pre>/ =~ line
			      output << line
			      next
			    end
			  else
			  line.gsub!(/\-\-|<=>|<\->|\->|<\-|=>|<=|\|\^|\|\|\/|\|\/|\^|>>|<<|\+_|!=|~~|~=|>_|<_|\|FA|\|EX|\|=|\(+\)|\(x\)|\\&|\(c\)|\(R\)|\(SS\)|\(TM\)/, 
				"\-\-" => "&mdash;",
				"<=" => "&hArr;",
				"<\->" => "&harr;",
				"\->" =>"&rarr;",
				"<\-" =>"&larr;",
				"=>" => "&rArr;",
				"<=" => "&lArr;",
				"\|\|\^" => "&uArr;",
				"\|\|\/" => "&dArr;",
				"\|\/" => "&darr;",
				"\|\^" => "&uarr;",
				">>" => "&raquo;",
				"<<" => "&laquo;",
				"+_" => "&plusmn;",
				"!=" => "&ne;",
				"~~" => "&asymp;",
				"~=" => "&cong;",
				"<_" => "&le;",
				">_" => "&ge",
				"\|FA" => "&forall;",
				"\|EX" => "&exist;",
				"\|=" => "&equiv;",
				"\(+\)" => "&oplus",
				"\(x\)" => "&otimes;",
				"\\&" =>"&amp;",
				"\(c\)" => "&copy;",
				"\(R\)" =>"&reg;",
				"\(SS\)" => "&sect;",
				"\(TM\)" => "&trade;" #29
				)
			output << line
			end
			}
			return output
			#Insert by set.minami
			#return text
			
		end
		
		alias parse parse_text
		
		# return values are extended. (mainly for testing)
		def parse_text_with_render_state(str, rs = nil)
			rs ||= RenderState.new
			html = parse_text(str, rs)
			
			return [html, rs]
		end
		
		def parse_text_file(path)
			parse_text(File.read(path))
		end
		
		alias parse_file parse_text_file
		
		
		def parse_document(source, default_enc = EncodingType::UTF8)
			doc = Document.parse(source, default_enc)
			
			return document_to_html(doc)
		end
		
		def parse_document_file(path, default_enc = EncodingType::UTF8)
			doc = nil
			open(path){|f|
				doc = Document.parse_io(f, default_enc)
			}
			
			return document_to_html(doc)
		end
		
		
		def document_to_html(doc)
			rs = RenderState.new
			if doc.numbering? then
				rs.numbering = true
			end
			rs.numbering_start_level = doc.numbering_start_level
			rs.header_id_type = doc.header_id_type
			
			body_html = nil
			
			if doc.encoding_type then
				Util.change_kcode(doc.kcode){
					body_html = parse_text(doc.body, rs)
				}
			else
				body_html = parse_text(doc.body, rs)
			end
			
			out = Util.generate_blank_string_io(doc.body)
			
			# XHTML decleration
			out.puts %Q|<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">|
			
			# html start
			out.puts %Q|<html>|
			
			# head
			out.puts %Q|<head>|
			
			if doc.encoding_type and (charset = EncodingType.convert_to_charset(doc.encoding_type)) then
				out.puts %Q|<meta http-equiv="Content-Type" content="text/html; charset=#{charset}" />|
			end
			
			h1 = rs.headers.find{|x| x.level == 1}
			h1_content = (h1 ? h1.content : nil)
			title = Util.escape_html(doc.title || h1_content || 'no title (Generated by AoBane)')
			out.puts %Q|<title>#{title}</title>|

			%w(description keywords).each do |name|
				if doc[name] then
					content = Util.escape_html(doc[name])
					out.puts %Q|<meta name="#{name}" content="#{content}" />|
				end
			end


			if doc['css'] then
				href = Util.escape_html(doc.css)
				out.puts %Q|<link rel="stylesheet" type="text/css" href="#{href}" />|
				
			end
			
			if doc['rdf-feed'] then
				href = Util.escape_html(doc['rdf-feed'])
				out.puts %Q|<link rel="alternate" type="application/rdf+xml" href="#{href}" />|
			end

			
			
			if doc['rss-feed'] then
				href = Util.escape_html(doc['rss-feed'])
				out.puts %Q|<link rel="alternate" type="application/rss+xml" href="#{href}" />|
			end
			
			if doc['atom-feed'] then
				href = Util.escape_html(doc['atom-feed'])
				out.puts %Q|<link rel="alternate" type="application/atom+xml" href="#{href}" />|
			end
						
			out.puts %Q|</head>|
			
			# body
			out.puts %Q|<body>|
			out.puts
			out.puts body_html
			out.puts
			out.puts %Q|</body>|
			
			# html end
			out.puts %Q|</html>|

			
			return out.string
		end
		
		alias doc2html document_to_html
		
	
	
	
		#######
		#private
		#######
		
		### Convert tabs in +str+ to spaces.
		### (this method is reformed to function-like method from original BlueCloth)
		def detab( str, tabwidth=TabWidth )
			re = str.split( /\n/ ).collect {|line|
				line.gsub( /(.*?)\t/ ) do
					$1 + ' ' * (tabwidth - $1.length % tabwidth)
				end
			}.join("\n")
			
			re
		end
	
	

	
		### Do block-level transforms on a copy of +str+ using the specified render
		### state +rs+ and return the results.
		def apply_block_transforms( str, rs )
			rs.block_transform_depth += 1
		
			# Port: This was called '_runBlockGamut' in the original
	
			@log.debug "Applying block transforms to:\n  %p" % str
			text = str
			text = pretransform_fenced_code_blocks( text, rs )
			text = pretransform_block_separators(text, rs)
			
			text = transform_headers( text, rs )
			text = transform_toc(text, rs)
			
			text = transform_hrules( text, rs )
			text = transform_lists( text, rs )
			text = transform_definition_lists( text, rs ) # AoBane Extension
			text = transform_code_blocks( text, rs )
			text = transform_block_quotes( text, rs )
			text = transform_tables(text, rs)
			text = hide_html_blocks( text, rs )
	
			text = form_paragraphs( text, rs )
	
			rs.block_transform_depth -= 1
			@log.debug "Done with block transforms:\n  %p" % text
			return text
		end
	
	
		### Apply Markdown span transforms to a copy of the specified +str+ with the
		### given render state +rs+ and return it.
		def apply_span_transforms( str, rs )
			@log.debug "Applying span transforms to:\n  %p" % str
	
			str = transform_code_spans( str, rs )
			str = transform_auto_links( str, rs )
			str = encode_html( str )
			str = transform_images( str, rs )
			str = transform_anchors( str, rs )
			str = transform_italic_and_bold( str, rs )
	
			# Hard breaks
			str.gsub!( / {2,}\n/, "<br#{EmptyElementSuffix}\n" )
	
			@log.debug "Done with span transforms:\n  %p" % str
			return str
		end
	
	
		# The list of tags which are considered block-level constructs and an
		# alternation pattern suitable for use in regexps made from the list
		StrictBlockTags = %w[ p div h[1-6] blockquote pre table dl ol ul script noscript
			form fieldset iframe math ins del ]
		StrictTagPattern = StrictBlockTags.join('|')
	
		LooseBlockTags = StrictBlockTags - %w[ins del]
		LooseTagPattern = LooseBlockTags.join('|')
	
		# Nested blocks:
		# 	<div>
		# 		<div>
		# 		tags for inner block must be indented.
		# 		</div>
		# 	</div>
		StrictBlockRegexp = %r{
			^						# Start of line
			<(#{StrictTagPattern})	# Start tag: \2
			\b						# word break
			(.*\n)*?				# Any number of lines, minimal match
			</\1>					# Matching end tag
			[ ]*					# trailing spaces
			$						# End of line or document
		  }ix
	
		# More-liberal block-matching
		LooseBlockRegexp = %r{
			^						# Start of line
			<(#{LooseTagPattern})	# start tag: \2
			\b						# word break
			(.*\n)*?				# Any number of lines, minimal match
			.*</\1>					# Anything + Matching end tag
			[ ]*					# trailing spaces
			$						# End of line or document
		  }ix
	
		# Special case for <hr />.
		HruleBlockRegexp = %r{
			(						# $1
				\A\n?				# Start of doc + optional \n
				|					# or
				.*\n\n				# anything + blank line
			)
			(						# save in $2
				            # AoBane fix: Not allow any space on line top
				<hr         # Tag open
				\b          # Word break
				([^<>])*?   # Attributes
				/?>         # Tag close
				$           # followed by a blank line or end of document
			)
		  }ix
	
		### Replace all blocks of HTML in +str+ that start in the left margin with
		### tokens.
		def hide_html_blocks( str, rs )
			@log.debug "Hiding HTML blocks in %p" % str
			
			# Tokenizer proc to pass to gsub
			tokenize = lambda {|match|
				key = Digest::MD5::hexdigest( match )
				rs.html_blocks[ key ] = match
				@log.debug "Replacing %p with %p" % [ match, key ]
				"\n\n#{key}\n\n"
			}
	
			rval = str.dup
	
			@log.debug "Finding blocks with the strict regex..."
			rval.gsub!( StrictBlockRegexp, &tokenize )
	
			@log.debug "Finding blocks with the loose regex..."
			rval.gsub!( LooseBlockRegexp, &tokenize )
	
			@log.debug "Finding hrules..."
			rval.gsub!( HruleBlockRegexp ) {|match| $1 + tokenize[$2] }
	
			return rval
		end
	
	
		# Link defs are in the form: ^[id]: url "optional title"
		LinkRegexp = %r{
			^[ ]{0,#{TabWidth - 1}} # AoBane fix: indent < tab width
			\[(.+)\]:		# id = $1
			  [ ]*
			  \n?				# maybe *one* newline
			  [ ]*
			<?(\S+?)>?				# url = $2
			  [ ]*
			  \n?				# maybe one newline
			  [ ]*
			(?:
				# Titles are delimited by "quotes" or (parens).
				["(]
				(.+?)			# title = $3
				[")]			# Matching ) or "
				[ ]*
			)?	# title is optional
			(?:\n+|\Z)
		  }x
	
		### Strip link definitions from +str+, storing them in the given RenderState
		### +rs+.
		def strip_link_definitions( str, rs )
			str.gsub( LinkRegexp ) {|match|
				id, url, title = $1, $2, $3
				
				rs.urls[ id.downcase ] = encode_html( url )
				unless title.nil?
					rs.titles[ id.downcase ] = title.gsub( /"/, "&quot;" )
				end

				""
			}
		end

		# Footnotes defs are in the form: [^id]: footnote contents.
		FootnoteDefinitionRegexp = %r{
			^[ ]{0,#{TabWidth - 1}}
			\[\^(.+?)\]\:		# id = $1
			[ ]*
			(.*)				# first line content = $2
			(?:\n|\Z)
			
			( # second or more lines content = $3
				(?: 
					[ ]{#{TabWidth},} # indented
					.*
					(?:\n|\Z)
				|
					\n # blank line
				)*
			)?
			
		}x
		
		FootnoteIdRegexp = /^[a-zA-Z0-9\:\._-]+$/

		def strip_footnote_definitions(str, rs)
			str.gsub( FootnoteDefinitionRegexp ) {|match|
				id = $1; content1 = $2; content2 = $3
				
				unless id =~ FootnoteIdRegexp then
					rs.warnings << "illegal footnote id - #{id} (legal chars: a-zA-Z0-9_-.:)"
				end
				
				if content2 then
					@log.debug "   Stripping multi-line definition %p, %p" % [$2, $3]
					content = content1 + "\n" + outdent(content2.chomp)
					@log.debug "   Stripped multi-line definition %p, %p" % [id, content]
					rs.footnotes[id] = content
				else
					content = content1 || ''
					@log.debug "   Stripped single-line definition %p, %p" % [id, content]
					rs.footnotes[id] = content
				end
				
				

				""
			}
		end
	
	
		### Escape special characters in the given +str+
		def escape_special_chars( str )
			@log.debug "  Escaping special characters"
			text = ''
	
			# The original Markdown source has something called '$tags_to_skip'
			# declared here, but it's never used, so I don't define it.
	
			tokenize_html( str ) {|token, str|
				@log.debug "   Adding %p token %p" % [ token, str ]
				case token
	
				# Within tags, encode * and _
				when :tag
					text += str.
						gsub( /\*/, EscapeTable['*'][:md5] ).
						gsub( /_/, EscapeTable['_'][:md5] )
	
				# Encode backslashed stuff in regular text
				when :text
					text += encode_backslash_escapes( str )
				else
					raise TypeError, "Unknown token type %p" % token
				end
			}
	
			@log.debug "  Text with escapes is now: %p" % text
			return text
		end
	
	
		### Swap escaped special characters in a copy of the given +str+ and return
		### it.
		def unescape_special_chars( str )
			EscapeTable.each {|char, hash|
				@log.debug "Unescaping escaped %p with %p" % [ char, hash[:md5re] ]
				str.gsub!( hash[:md5re], hash[:unescape] )
			}
	
			return str
		end
	
	
		### Return a copy of the given +str+ with any backslashed special character
		### in it replaced with MD5 placeholders.
		def encode_backslash_escapes( str )
			# Make a copy with any double-escaped backslashes encoded
			text = str.gsub( /\\\\/, EscapeTable['\\\\'][:md5] )
			
			EscapeTable.each_pair {|char, esc|
				next if char == '\\\\'
				next unless char =~ /\\./
				text.gsub!( esc[:re], esc[:md5] )
			}
	
			return text
		end
		
		
		def pretransform_block_separators(str, rs)
			str.gsub(/^[ ]{0,#{TabWidth - 1}}[~][ ]*\n/){
				"\n~\n\n"
			}
		end


		TOCRegexp = %r{
			^\{    # bracket on line-head 
			[ ]*    # optional inner space 
			toc
			
			(?:
				(?:
					[:]    # colon
					|      # or
					[ ]+   # 1 or more space
				)
				(.+?)    # $1 = parameter
			)?
			
			[ ]*    # optional inner space
			\}     # closer
			[ ]*$   # optional space on line-foot
		}ix
		
		TOCStartLevelRegexp = %r{
			^
			(?:              # optional start
				h 
				([1-6])        # $1 = start level
			)?
			
			(?:              # range symbol
				[.]{2,}|[-]    # .. or -
			)
			
			(?:              # optional end
				h?             # optional 'h'
				([1-6])        # $2 = end level
			)?$
		}ix       

		### Transform any Markdown-style horizontal rules in a copy of the specified
		### +str+ and return it.
		def transform_toc( str, rs )
			@log.debug " Transforming tables of contents"
			str.gsub(TOCRegexp){
				start_level = 2 # default
				end_level = 6
			
				param = $1
				if param then
					if param =~ TOCStartLevelRegexp then
						if !($1) and !($2) then
							rs.warnings << "illegal TOC parameter - #{param} (valid example: 'h2..h4')"
						else
							start_level = ($1 ? $1.to_i : 2)
							end_level = ($2 ? $2.to_i : 6)
						end
					else
						rs.warnings << "illegal TOC parameter - #{param} (valid example: 'h2..h4')"
					end
				end
				
				if rs.headers.first and rs.headers.first.level >= (start_level + 1) then
					rs.warnings << "illegal structure of headers - h#{start_level} should be set before h#{rs.headers.first.level}"
				end
				
				
				ul_text = "\n\n"
				rs.headers.each do |header|
					if header.level >= start_level and header.level <= end_level then
						ul_text << ' ' * TabWidth * (header.level - start_level)
						ul_text << '* '
						ul_text << %Q|<a href="##{header.id}" rel="toc">#{header.content_html}</a>|
						ul_text << "\n"
					end
				end
				ul_text << "\n"
				
				ul_text # output
			
			}
		end
		
		TableRegexp = %r{
			(?:
				^([ ]{0,#{TabWidth - 1}}) # not indented
				(?:[|][ ]*)   # NOT optional border
				
				\S.*?  # 1st cell content
					
				(?:    # 2nd cell or later
					[|]    # cell splitter
					.+?    # content
				)+     # 1 or more..

				[|]?   # optional border
				(?:\n|\Z)  # line end
			)+
		}x
	
		# Transform tables.
		def transform_tables(str, rs)
			str.gsub(TableRegexp){
				transform_table_rows($~[0], rs)
			}
		end
		
		TableSeparatorCellRegexp = %r{
			^
			[ ]*
			([:])?  # $1 = left-align symbol
			[ ]*
			[-]+    # border
			[ ]*
			([:])?  # $2 = right-align symbol
			[ ]*
			$
		}x
		
		def transform_table_rows(str, rs)
		
			# split cells to 2-d array
			data = str.split("\n").map{|x| x.split('|')}
			
			
			data.each do |row|
				# cut left space
				row.first.lstrip!
				
				# cut when optional side-borders is included
				row.shift if row.first.empty?
			end
			
			column_attrs = []
			
			re = ''
			re << "<table>\n"
			
			# head is exist?
			if data.size >= 3 and data[1].all?{|x| x =~ TableSeparatorCellRegexp} then
				head_row = data.shift
				separator_row = data.shift
				
				separator_row.each do |cell|
					cell.match TableSeparatorCellRegexp
					left = $1; right = $2

					if left and right then
						column_attrs << ' style="text-align: center"'
					elsif right then
						column_attrs << ' style="text-align: right"'
					elsif left then
						column_attrs << ' style="text-align: left"'
					else
						column_attrs << ''
					end
				end

				re << "\t<thead><tr>\n"
				head_row.each_with_index do |cell, i|
					re << "\t\t<th#{column_attrs[i]}>#{apply_span_transforms(cell.strip, rs)}</th>\n"
				end
				re << "\t</tr></thead>\n"
			end
			
			# data row
			re << "\t<tbody>\n"
			data.each do |row|
				re << "\t\t<tr>\n"
				row.each_with_index do |cell, i|
					re << "\t\t\t<td#{column_attrs[i]}>#{apply_span_transforms(cell.strip, rs)}</td>\n"
				end
				re << "\t\t</tr>\n"
			end
			re << "\t</tbody>\n"
			
			re << "</table>\n"

			re
		end

	
		### Transform any Markdown-style horizontal rules in a copy of the specified
		### +str+ and return it.
		def transform_hrules( str, rs )
			@log.debug " Transforming horizontal rules"
			str.gsub( /^( ?[\-\*_] ?){3,}$/, "\n<hr#{EmptyElementSuffix}\n" )
		end
	
	
	
		# Patterns to match and transform lists
		ListMarkerOl = %r{\d+\.}
		ListMarkerUl = %r{[*+-]}
		ListMarkerAny = Regexp::union( ListMarkerOl, ListMarkerUl )
	
		ListRegexp = %r{
			  (?:
				^[ ]{0,#{TabWidth - 1}}		# Indent < tab width
				(#{ListMarkerAny})			# unordered or ordered ($1)
				[ ]+						# At least one space
			  )
			  (?m:.+?)						# item content (include newlines)
			  (?:
				  \z						# Either EOF
				|							#  or
				  \n{2,}					# Blank line...
				  (?=\S)					# ...followed by non-space
				  (?![ ]*					# ...but not another item
					(#{ListMarkerAny})
				   [ ]+)
			  )
		  }x
	
		### Transform Markdown-style lists in a copy of the specified +str+ and
		### return it.
		def transform_lists( str, rs )
			@log.debug " Transforming lists at %p" % (str[0,100] + '...')
	
			str.gsub( ListRegexp ) {|list|
				@log.debug "  Found list %p" % list
				bullet = $1
				list_type = (ListMarkerUl.match(bullet) ? "ul" : "ol")
	
				%{<%s>\n%s</%s>\n} % [
					list_type,
					transform_list_items( list, rs ),
					list_type,
				]
			}
		end
		
		# Pattern for transforming list items
		ListItemRegexp = %r{
			(\n)?							# leading line = $1
			(^[ ]*)							# leading whitespace = $2
			(#{ListMarkerAny}) [ ]+			# list marker = $3
			((?m:.+?)						# list item text   = $4
			\n)
			(?= (\n*) (\z | \2 (#{ListMarkerAny}) [ ]+))
		  }x
	
		### Transform list items in a copy of the given +str+ and return it.
		def transform_list_items( str, rs )
			@log.debug " Transforming list items"
	
			# Trim trailing blank lines
			str = str.sub( /\n{2,}\z/, "\n" )
			str.gsub( ListItemRegexp ) {|line|
				@log.debug "  Found item line %p" % line
				leading_line, item = $1, $4
				separating_lines = $5 
	
				if leading_line or /\n{2,}/.match(item) or not separating_lines.empty? then
					@log.debug "   Found leading line or item has a blank"
					item = apply_block_transforms( outdent(item), rs )
				else
					# Recursion for sub-lists
					@log.debug "   Recursing for sublist"
					item = transform_lists( outdent(item), rs ).chomp
					item = apply_span_transforms( item, rs )
				end
	
				%{<li>%s</li>\n} % item
			}
		end

		DefinitionListRegexp = %r{
			(?:
				(?:^.+\n)+ # dt
				\n*
				(?:
					^[ ]{0,#{TabWidth - 1}} # Indent < tab width
					\: # dd marker (line head)
					[ ]* # space
					((?m:.+?)) # dd content
					(?:
						\s*\z # end of string
						| # or
						\n{2,} # blank line
						(?=[ ]{0,#{TabWidth - 1}}\S) # ...followed by
					)
				)+
			)+
		}x

		def transform_definition_lists(str, rs)
			@log.debug " Transforming definition lists at %p" % (str[0,100] + '...')
			str.gsub( DefinitionListRegexp ) {|list|
				@log.debug "  Found definition list %p (captures=%p)" % [list, $~.captures]
				transform_definition_list_items(list, rs)
			}
		end
		
		DDLineRegexp = /^\:[ ]{0,#{TabWidth - 1}}(.*)/
		
			
		def transform_definition_list_items(str, rs)
			buf = Util.generate_blank_string_io(str)
			buf.puts %Q|<dl>|

			lines = str.split("\n")
			until lines.empty? do
			
				dts = []
				
				# get dt items
				while lines.first =~ /^(?!\:).+$/ do
					dts << lines.shift
				end
				
				
				dd_as_block = false
				
				# skip blank lines
				while not lines.empty? and lines.first.empty? do
					lines.shift
					dd_as_block = true
				end
				
				
				dds = []
				while lines.first =~ DDLineRegexp do
					dd_buf = []
					
					# dd first line
					unless (line = lines.shift).empty? then
						dd_buf << $1 << "\n"
					end
					
					# dd second and more lines (sequential with 1st-line)
					until lines.empty? or                      # stop if read all
					lines.first =~ /^[ ]{0,#{TabWidth - 1}}$/ or # stop if blank line
					lines.first =~ DDLineRegexp do             # stop if new dd found
						dd_buf << outdent(lines.shift) << "\n"
					end
					
					# dd second and more lines (separated with 1st-line)
					until lines.empty? do  # stop if all was read
						if lines.first.empty? then
							# blank line (skip)
							lines.shift
							dd_buf << "\n" 
						elsif lines.first =~ /^[ ]{#{TabWidth},}/ then
							# indented body
							dd_buf << outdent(lines.shift) << "\n"
						else
							# not indented body
							break
						end
						
					end
					
					
					dds << dd_buf.join
					
					# skip blank lines
					unless lines.empty? then
						while lines.first.empty? do
							lines.shift
						end
					end
				end
				
				# html output
				dts.each do |dt|
					buf.puts %Q|  <dt>#{apply_span_transforms(dt, rs)}</dt>|
				end
				
				dds.each do |dd|
					if dd_as_block then
						buf.puts %Q|  <dd>#{apply_block_transforms(dd, rs)}</dd>|
					else
						dd.gsub!(/\n+\z/, '') # chomp linefeeds
						buf.puts %Q|  <dd>#{apply_span_transforms(dd.chomp, rs)}</dd>|
					end
				end
			end
			
			buf.puts %Q|</dl>|

			return(buf.string)
		end
		
		# old
	
	
		# Pattern for matching codeblocks
		CodeBlockRegexp = %r{
			(?:\n\n|\A|\A\n)
			(									# $1 = the code block
			  (?:
				(?:[ ]{#{TabWidth}} | \t)		# a tab or tab-width of spaces
				.*\n+
			  )+
			)
			(^[ ]{0,#{TabWidth - 1}}\S|\Z)		# Lookahead for non-space at
												# line-start, or end of doc
		  }x
			
	
		### Transform Markdown-style codeblocks in a copy of the specified +str+ and
		### return it.
		def transform_code_blocks( str, rs )
			@log.debug " Transforming code blocks"
	
			str.gsub( CodeBlockRegexp ) {|block|
				codeblock = $1
				remainder = $2
				
				
				tmpl = %{\n\n<pre><code>%s\n</code></pre>\n\n%s}
				
				# patch for ruby 1.9.1 bug
				if tmpl.respond_to?(:force_encoding) then
					tmpl.force_encoding(str.encoding)
				end
				args = [ encode_code( outdent(codeblock), rs ).rstrip, remainder ]
				
				# recover all backslash escaped to original form
				EscapeTable.each {|char, hash|
					args[0].gsub!( hash[:md5re]){char}
				}
				
				# Generate the codeblock
				tmpl % args
			}
		end
		
		
		FencedCodeBlockRegexp = /^(\~{3,})\n((?m:.+?)\n)\1\n/
		
		def pretransform_fenced_code_blocks( str, rs )
			@log.debug " Transforming fenced code blocks => standard code blocks"
	
			str.gsub( FencedCodeBlockRegexp ) {|block|
				"\n~\n\n" + indent($2) + "\n~\n\n"
			}
		end

	
	
		# Pattern for matching Markdown blockquote blocks
		BlockQuoteRegexp = %r{
			  (?:
				^[ ]*>[ ]?		# '>' at the start of a line
				  .+\n			# rest of the first line
				(?:.+\n)*		# subsequent consecutive lines
				\n*				# blanks
			  )+
		  }x
		PreChunk = %r{ ( ^ \s* <pre> .+? </pre> ) }xm
	
		### Transform Markdown-style blockquotes in a copy of the specified +str+
		### and return it.
		def transform_block_quotes( str, rs )
			@log.debug " Transforming block quotes"
	
			str.gsub( BlockQuoteRegexp ) {|quote|
				@log.debug "Making blockquote from %p" % quote
	
				quote.gsub!( /^ *> ?/, '' ) # Trim one level of quoting 
				quote.gsub!( /^ +$/, '' )	# Trim whitespace-only lines
	
				indent = " " * TabWidth
				quoted = %{<blockquote>\n%s\n</blockquote>\n\n} %
					apply_block_transforms( quote, rs ).
					gsub( /^/, indent ).
					gsub( PreChunk ) {|m| m.gsub(/^#{indent}/o, '') }
				@log.debug "Blockquoted chunk is: %p" % quoted
				quoted
			}
		end
	
	
		# AoBane change:
		#   allow loosely urls and addresses (BlueCloth is very strict)
		# 
		# loose examples:
		#  <skype:tetra-dice>       (other protocol)
		#  <ema+il@example.com>     (ex: gmail alias)
		#
		# not adapted addresses: 
		#  <"Abc@def"@example.com>  (refer to quoted-string of RFC 5321)
		
		
		AutoAnchorURLRegexp = /<(#{URI.regexp})>/ # $1 = url

		AutoAnchorEmailRegexp = /<([^'">\s]+?\@[^'">\s]+[.][a-zA-Z]+)>/ # $2 = address
	
		### Transform URLs in a copy of the specified +str+ into links and return
		### it.
		def transform_auto_links( str, rs )
			@log.debug " Transforming auto-links"
			str.gsub(AutoAnchorURLRegexp){
				%|<a href="#{Util.escape_html($1)}">#{Util.escape_html($1)}</a>|
			}.gsub( AutoAnchorEmailRegexp ) {|addr|
				encode_email_address( unescape_special_chars($1) )
			}
		end
	
	
		# Encoder functions to turn characters of an email address into encoded
		# entities.
		Encoders = [
			lambda {|char| "&#%03d;" % char},
			lambda {|char| "&#x%X;" % char},
			lambda {|char| char.chr },
		]
	
		### Transform a copy of the given email +addr+ into an escaped version safer
		### for posting publicly.
		def encode_email_address( addr )
	
			rval = ''
			("mailto:" + addr).each_byte {|b|
				case b
				when ?:
					rval += ":"
				when ?@
					rval += Encoders[ rand(2) ][ b ]
				else
					r = rand(100)
					rval += (
						r > 90 ? Encoders[2][ b ] :
						r < 45 ? Encoders[1][ b ] :
								 Encoders[0][ b ]
					)
				end
			}
	
			return %{<a href="%s">%s</a>} % [ rval, rval.sub(/.+?:/, '') ]
		end
	
	
		# Regexp for matching Setext-style headers
		SetextHeaderRegexp = %r{
			(.+?)			# The title text ($1)
			
			(?: # Markdown Extra: Header Id Attribute (optional)
				[ ]* # space after closing #'s
				\{\#
					(\S+?) # $2 = Id
				\}
				[ \t]* # allowed lazy spaces
			)?
			\n
			([\-=])+		# Match a line of = or -. Save only one in $3.
			[ ]*\n+
		   }x
	
		# Regexp for matching ATX-style headers
		AtxHeaderRegexp = %r{
			^(\#+)	# $1 = string of #'s
			[ ]*
			(.+?)		# $2 = Header text
			[ ]*
			\#*			# optional closing #'s (not counted)
			
			(?: # Markdown Extra: Header Id Attribute (optional)
				[ ]* # space after closing #'s
				\{\#
					(\S+?) # $3 = Id
				\}
				[ \t]* # allowed lazy spaces
			)?
			
			\n+
		  }x
			
		HeaderRegexp = Regexp.union(SetextHeaderRegexp, AtxHeaderRegexp)
	
		IdRegexp = /^[a-zA-Z][a-zA-Z0-9\:\._-]*$/
				
		### Apply Markdown header transforms to a copy of the given +str+ amd render
		### state +rs+ and return the result.
		def transform_headers( str, rs )
			@log.debug " Transforming headers"
			
			# Setext-style headers:
			#	  Header 1
			#	  ========
			#  
			#	  Header 2
			#	  --------
			#
			
			section_numbers = [nil, nil, nil, nil, nil]
			
			str.
				gsub( HeaderRegexp ) {|m|
					if $1 then
						@log.debug "Found setext-style header"
						title, id, hdrchar = $1, $2, $3
						
						case hdrchar
						when '='
							level = 1
						when '-'
							level = 2
						end
					else
						@log.debug "Found ATX-style header"
						hdrchars, title, id = $4, $5, $6
						level = hdrchars.length
						
						if level >= 7 then
							rs.warnings << "illegal header level - h#{level} ('#' symbols are too many)"
						end
					end
					
					prefix = ''
					if rs.numbering? then
						if level >= rs.numbering_start_level and level <= 6 then
							depth = level - rs.numbering_start_level
							
							section_numbers.each_index do |i|
								if i == depth and section_numbers[depth] then
									# increment a deepest number if current header's level equals last header's
									section_numbers[i] += 1
								elsif i <= depth then
									# set default number if nil
									section_numbers[i] ||= 1
								else
									# clear discardeds
									section_numbers[i] = nil
								end
							end
							
							no = ''
							(0..depth).each do |i|
								no << "#{section_numbers[i]}."
							end
	
							prefix = "#{no} "
						end
					end
					
					title_html = apply_span_transforms( title, rs )
					
					unless id then
						case rs.header_id_type
						when HeaderIDType::ESCAPE
							id = escape_to_header_id(title_html)
							if rs.headers.find{|h| h.id == id} then
								rs.warnings << "header id collision - #{id}"
								id = "bfheader-#{Digest::MD5.hexdigest(title)}"
							end
						else 
							id = "bfheader-#{Digest::MD5.hexdigest(title)}"
						end
					end

					title = "#{prefix}#{title}"
					title_html = "#{prefix}#{title_html}"

					
					unless id =~ IdRegexp then
						rs.warnings << "illegal header id - #{id} (legal chars: [a-zA-Z0-9_-.] | 1st: [a-zA-Z])"
					end
					
					if rs.block_transform_depth == 1 then
						rs.headers << RenderState::Header.new(id, level, title, title_html)
					end
				
					if @use_header_id then
						%{<h%d id="%s">%s</h%d>\n\n} % [ level, id, title_html, level ]
					else
						%{<h%d>%s</h%d>\n\n} % [ level, title_html, level ]
					end
				}
		end
	
	
		### Wrap all remaining paragraph-looking text in a copy of +str+ inside <p>
		### tags and return it.
		def form_paragraphs( str, rs )
			@log.debug " Forming paragraphs"
			grafs = str.
				sub( /\A\n+/, '' ).
				sub( /\n+\z/, '' ).
				split( /\n{2,}/ )
	
			rval = grafs.collect {|graf|
	
				# Unhashify HTML blocks if this is a placeholder
				if rs.html_blocks.key?( graf )
					rs.html_blocks[ graf ]
				
				# no output if this is block separater
				elsif graf == '~' then
					''
	
				# Otherwise, wrap in <p> tags
				else
					apply_span_transforms(graf, rs).
						sub( /^[ ]*/, '<p>' ) + '</p>'
				end
			}.join( "\n\n" )
	
			@log.debug " Formed paragraphs: %p" % rval
			return rval
		end
	
	
		# Pattern to match the linkid part of an anchor tag for reference-style
		# links.
		RefLinkIdRegexp = %r{
			[ ]?					# Optional leading space
			(?:\n[ ]*)?				# Optional newline + spaces
			\[
				(.*?)				# Id = $1
			\]
		  }x
	
		InlineLinkRegexp = %r{
			\(						# Literal paren
				[ ]*				# Zero or more spaces
				<?(.+?)>?			# URI = $1
				[ ]*				# Zero or more spaces
				(?:					# 
					([\"\'])		# Opening quote char = $2
					(.*?)			# Title = $3
					\2				# Matching quote char
				)?					# Title is optional
			\)
		  }x
	
		### Apply Markdown anchor transforms to a copy of the specified +str+ with
		### the given render state +rs+ and return it.
		def transform_anchors( str, rs )
			@log.debug " Transforming anchors"
			@scanner.string = str.dup
			text = ''
	
			# Scan the whole string
			until @scanner.empty?
			
				if @scanner.scan( /\[/ )
					link = ''; linkid = ''
					depth = 1
					startpos = @scanner.pos
					@log.debug " Found a bracket-open at %d" % startpos
	
					# Scan the rest of the tag, allowing unlimited nested []s. If
					# the scanner runs out of text before the opening bracket is
					# closed, append the text and return (wasn't a valid anchor).
					while depth.nonzero?
						linktext = @scanner.scan_until( /\]|\[/ )
	
						if linktext
							@log.debug "  Found a bracket at depth %d: %p" % [ depth, linktext ]
							link += linktext
	
							# Decrement depth for each closing bracket
							depth += ( linktext[-1, 1] == ']' ? -1 : 1 )
							@log.debug "  Depth is now #{depth}"
	
						# If there's no more brackets, it must not be an anchor, so
						# just abort.
						else
							@log.debug "  Missing closing brace, assuming non-link."
							link += @scanner.rest
							@scanner.terminate
							return text + '[' + link
						end
					end
					link.slice!( -1 ) # Trim final ']'
					@log.debug " Found leading link %p" % link
					
					
	
					# Markdown Extra: Footnote
					if link =~ /^\^(.+)/ then
						id = $1
						if rs.footnotes[id] then
							rs.found_footnote_ids << id
							label = "[#{rs.found_footnote_ids.size}]"
						else
							rs.warnings << "undefined footnote id - #{id}"
							label = '[?]'
						end
						
						text += %Q|<sup id="footnote-ref:#{id}"><a href="#footnote:#{id}" rel="footnote">#{label}</a></sup>|
						
					# Look for a reference-style second part
					elsif @scanner.scan( RefLinkIdRegexp )
						linkid = @scanner[1]
						linkid = link.dup if linkid.empty?
						linkid.downcase!
						@log.debug "  Found a linkid: %p" % linkid
	
						# If there's a matching link in the link table, build an
						# anchor tag for it.
						if rs.urls.key?( linkid )
							@log.debug "   Found link key in the link table: %p" % rs.urls[linkid]
							url = escape_md( rs.urls[linkid] )
	
							text += %{<a href="#{url}"}
							if rs.titles.key?(linkid)
								text += %{ title="%s"} % escape_md( rs.titles[linkid] )
							end
							text += %{>#{link}</a>}
	
						# If the link referred to doesn't exist, just append the raw
						# source to the result
						else
							@log.debug "  Linkid %p not found in link table" % linkid
							@log.debug "  Appending original string instead: "
							@log.debug "%p" % @scanner.string[ startpos-1 .. @scanner.pos-1 ]
							
							rs.warnings << "link-id not found - #{linkid}"
							text += @scanner.string[ startpos-1 .. @scanner.pos-1 ]
						end
	
					# ...or for an inline style second part
					elsif @scanner.scan( InlineLinkRegexp )
						url = @scanner[1]
						title = @scanner[3]
						@log.debug "  Found an inline link to %p" % url
						
						url = "##{link}" if url == '#' # target anchor briefing (since AoBane 0.40)
	
						text += %{<a href="%s"} % escape_md( url )
						if title
							title.gsub!( /"/, "&quot;" )
							text += %{ title="%s"} % escape_md( title )
						end
						text += %{>#{link}</a>}
	
					# No linkid part: just append the first part as-is.
					else
						@log.debug "No linkid, so no anchor. Appending literal text."
						text += @scanner.string[ startpos-1 .. @scanner.pos-1 ]
					end # if linkid
	
				# Plain text
				else
					@log.debug " Scanning to the next link from %p" % @scanner.rest
					text += @scanner.scan( /[^\[]+/ )
				end
	
			end # until @scanner.empty?
	
			return text
		end
	
	
		# Pattern to match strong emphasis in Markdown text
		BoldRegexp = %r{ (\*\*|__) (\S|\S.*?\S) \1 }x
	
		# Pattern to match normal emphasis in Markdown text
		ItalicRegexp = %r{ (\*|_) (\S|\S.*?\S) \1 }x
	
		### Transform italic- and bold-encoded text in a copy of the specified +str+
		### and return it.
		def transform_italic_and_bold( str, rs )
			@log.debug " Transforming italic and bold"
	
			str.
				gsub( BoldRegexp, %{<strong>\\2</strong>} ).
				gsub( ItalicRegexp, %{<em>\\2</em>} )
		end
	
		
		### Transform backticked spans into <code> spans.
		def transform_code_spans( str, rs )
			@log.debug " Transforming code spans"
	
			# Set up the string scanner and just return the string unless there's at
			# least one backtick.
			@scanner.string = str.dup
			unless @scanner.exist?( /`/ )
				@scanner.terminate
				@log.debug "No backticks found for code span in %p" % str
				return str
			end
	
			@log.debug "Transforming code spans in %p" % str
	
			# Build the transformed text anew
			text = ''
	
			# Scan to the end of the string
			until @scanner.empty?
	
				# Scan up to an opening backtick
				if pre = @scanner.scan_until( /.??(?=`)/m )
					text += pre
					@log.debug "Found backtick at %d after '...%s'" % [ @scanner.pos, text[-10, 10] ]
	
					# Make a pattern to find the end of the span
					opener = @scanner.scan( /`+/ )
					len = opener.length
					closer = Regexp::new( opener )
					@log.debug "Scanning for end of code span with %p" % closer
	
					# Scan until the end of the closing backtick sequence. Chop the
					# backticks off the resultant string, strip leading and trailing
					# whitespace, and encode any enitites contained in it.
					codespan = @scanner.scan_until( closer ) or
						raise FormatError::new( @scanner.rest[0,20],
							"No %p found before end" % opener )
	
					@log.debug "Found close of code span at %d: %p" % [ @scanner.pos - len, codespan ]
					codespan.slice!( -len, len )
					text += "<code>%s</code>" %
						encode_code( codespan.strip, rs )
	
				# If there's no more backticks, just append the rest of the string
				# and move the scan pointer to the end
				else
					text += @scanner.rest
					@scanner.terminate
				end
			end
	
			return text
		end
	
	
		# Next, handle inline images:  ![alt text](url "optional title")
		# Don't forget: encode * and _
		InlineImageRegexp = %r{
			(					# Whole match = $1
				!\[ (.*?) \]	# alt text = $2
			  \([ ]*
				<?(\S+?)>?		# source url = $3
			    [ ]*
				(?:				# 
				  (["'])		# quote char = $4
				  (.*?)			# title = $5
				  \4			# matching quote
				  [ ]*
				)?				# title is optional
			  \)
			)
		  }x #"
	
	
		# Reference-style images
		ReferenceImageRegexp = %r{
			(					# Whole match = $1
				!\[ (.*?) \]	# Alt text = $2
				[ ]?			# Optional space
				(?:\n[ ]*)?		# One optional newline + spaces
				\[ (.*?) \]		# id = $3
			)
		  }x
	
		### Turn image markup into image tags.
		def transform_images( str, rs )
			@log.debug " Transforming images %p" % str
	
			# Handle reference-style labeled images: ![alt text][id]
			str.
				gsub( ReferenceImageRegexp ) {|match|
					whole, alt, linkid = $1, $2, $3.downcase
					@log.debug "Matched %p" % match
					res = nil
					alt.gsub!( /"/, '&quot;' )
	
					# for shortcut links like ![this][].
					linkid = alt.downcase if linkid.empty?
	
					if rs.urls.key?( linkid )
						url = escape_md( rs.urls[linkid] )
						@log.debug "Found url '%s' for linkid '%s' " % [ url, linkid ]
	
						# Build the tag
						result = %{<img src="%s" alt="%s"} % [ url, alt ]
						if rs.titles.key?( linkid )
							result += %{ title="%s"} % escape_md( rs.titles[linkid] )
						end
						result += EmptyElementSuffix
	
					else
						result = whole
					end
	
					@log.debug "Replacing %p with %p" % [ match, result ]
					result
				}.
	
				# Inline image style
				gsub( InlineImageRegexp ) {|match|
					@log.debug "Found inline image %p" % match
					whole, alt, title = $1, $2, $5
					url = escape_md( $3 )
					alt.gsub!( /"/, '&quot;' )
	
					# Build the tag
					result = %{<img src="%s" alt="%s"} % [ url, alt ]
					unless title.nil?
						title.gsub!( /"/, '&quot;' )
						result += %{ title="%s"} % escape_md( title )
					end
					result += EmptyElementSuffix

					@log.debug "Replacing %p with %p" % [ match, result ]
					result
				}
		end
	
	
		# Regexp to match special characters in a code block
		CodeEscapeRegexp = %r{( \* | _ | \{ | \} | \[ | \] | \\ )}x
	
		### Escape any characters special to HTML and encode any characters special
		### to Markdown in a copy of the given +str+ and return it.
		def encode_code( str, rs )
			#str.gsub( %r{&}, '&amp;' ).
				#gsub( %r{<}, '&lt;' ).
				#gsub( %r{>}, '&gt;' ).
				#gsub( CodeEscapeRegexp ) {|match| EscapeTable[match][:md5]}
		end
	
		def escape_to_header_id(str)
			URI.escape(escape_md(str.gsub(/<\/?[^>]*>/, "").gsub(/\s/, "_")).gsub("/", ".2F")).gsub("%", ".")
		end
	
		#################################################################
		###	U T I L I T Y   F U N C T I O N S
		#################################################################
	
		### Escape any markdown characters in a copy of the given +str+ and return
		### it.
		def escape_md( str )
			str.
				gsub( /\*|_/ ){|symbol| EscapeTable[symbol][:md5]}
		end
	
	
		# Matching constructs for tokenizing X/HTML
		HTMLCommentRegexp  = %r{ <! ( -- .*? -- \s* )+ > }mx
		XMLProcInstRegexp  = %r{ <\? .*? \?> }mx
		MetaTag = Regexp::union( HTMLCommentRegexp, XMLProcInstRegexp )
	
		HTMLTagOpenRegexp  = %r{ < [a-z/!$] [^<>]* }imx
		HTMLTagCloseRegexp = %r{ > }x
		HTMLTagPart = Regexp::union( HTMLTagOpenRegexp, HTMLTagCloseRegexp )
	
		### Break the HTML source in +str+ into a series of tokens and return
		### them. The tokens are just 2-element Array tuples with a type and the
		### actual content. If this function is called with a block, the type and
		### text parts of each token will be yielded to it one at a time as they are
		### extracted.
		def tokenize_html( str )
			depth = 0
			tokens = []
			@scanner.string = str.dup
			type, token = nil, nil
	
			until @scanner.empty?
				@log.debug "Scanning from %p" % @scanner.rest
	
				# Match comments and PIs without nesting
				if (( token = @scanner.scan(MetaTag) ))
					type = :tag
	
				# Do nested matching for HTML tags
				elsif (( token = @scanner.scan(HTMLTagOpenRegexp) ))
					tagstart = @scanner.pos
					@log.debug " Found the start of a plain tag at %d" % tagstart
	
					# Start the token with the opening angle
					depth = 1
					type = :tag
	
					# Scan the rest of the tag, allowing unlimited nested <>s. If
					# the scanner runs out of text before the tag is closed, raise
					# an error.
					while depth.nonzero?
	
						# Scan either an opener or a closer
						chunk = @scanner.scan( HTMLTagPart ) or
							break # AoBane Fix (refer to spec/code-block.rb)
							
						@log.debug "  Found another part of the tag at depth %d: %p" % [ depth, chunk ]
	
						token += chunk
	
						# If the last character of the token so far is a closing
						# angle bracket, decrement the depth. Otherwise increment
						# it for a nested tag.
						depth += ( token[-1, 1] == '>' ? -1 : 1 )
						@log.debug "  Depth is now #{depth}"
					end
	
				# Match text segments
				else
					@log.debug " Looking for a chunk of text"
					type = :text
	
					# Scan forward, always matching at least one character to move
					# the pointer beyond any non-tag '<'.
					token = @scanner.scan_until( /[^<]+/m )
				end
	
				@log.debug " type: %p, token: %p" % [ type, token ]
	
				# If a block is given, feed it one token at a time. Add the token to
				# the token list to be returned regardless.
				if block_given?
					yield( type, token )
				end
				tokens << [ type, token ]
			end
	
			return tokens
		end
	
	
		### Return a copy of +str+ with angle brackets and ampersands HTML-encoded.
		def encode_html( str )
			#str.gsub( /&(?!#?[x]?(?:[0-9a-f]+|\w+);)/i, "&amp;" ).
				#gsub( %r{<(?![a-z/?\$!])}i, "&lt;" )
				return str
		end
	
		
		### Return one level of line-leading tabs or spaces from a copy of +str+ and
		### return it.
		def outdent( str )
			str.gsub( /^(\t|[ ]{1,#{TabWidth}})/, '')
		end
		
		def indent(str)
			str.gsub( /^/, ' ' * TabWidth)
		end

	end
end