#!/usr/bin/env ruby

require 'asciidoctor'
require 'asciidoctor/extensions'
require 'libxml'
require 'libxslt'


# Convert inline DocBook passthroughs to HTMLBook
class InlineDocBook2HTMLBookprocessor < Asciidoctor::Extensions::Preprocessor

  def process reader, lines
    return reader if lines.empty?
    lines = []
    while reader.has_more_lines?
      lines << reader.read_line
    end
    lines.each do |line|
      passfull = 'pass:\[(.*?)\]'
      regexmatch = /#{passfull}/.match(line)
      if regexmatch.class == MatchData
        passcaptured = regexmatch.captures
        passcaptured.each do |inlinepass|
          convertedpass = convert_to_htmlbook inlinepass
          line.gsub!(/#{Regexp.escape(inlinepass)}/, convertedpass.chomp)
        end
      end
    end
    use_push_include = true
    if use_push_include
      reader.push_include lines, '<stdin>', '<stdin>'
      nil
    else
      Asciidoctor::Reader.new lines
    end
  end

end


# Convert block DocBook passthroughs to HTMLBook
class BlockDocBook2HTMLBookprocessor < Asciidoctor::Extensions::Treeprocessor

  def process
    process_blocks @document if @document.blocks?
  end
   
  def process_blocks node
    node.blocks.each_with_index do |block, i|
      if block.respond_to? :context
        if block.context == :pass
          block_text = convert_to_htmlbook block.content
          node.blocks[i] = Asciidoctor::Block.new @document, :pass, :content_model => :raw, :subs => [], :source => block_text
        else
          process_blocks block if block.blocks?
        end
      end
    end
  end

end


def convert_to_htmlbook text
  # set up xslt
  stylesheet_file = LibXML::XML::Document.file('/usr/local/app/docbook2htmlbook/db2htmlbook.xsl')
  xslt = LibXSLT::XSLT::Stylesheet.new(stylesheet_file)

  # set up xml and apply xslt
  xml = LibXML::XML::Parser.string(text, :options => LibXML::XML::Parser::Options::RECOVER).parse
  result = xslt.apply(xml)

  # strip off encoding line
  result = result.to_s.gsub(/<\?xml version="1.0" encoding="UTF-8"\?>\n/, '')

end


Asciidoctor::Extensions.register do |document|
  treeprocessor BlockDocBook2HTMLBookprocessor
  preprocessor InlineDocBook2HTMLBookprocessor
end


Asciidoctor.render_file 'book.asciidoc', :safe => :safe, :in_place => true, :template_dir => "/usr/local/app/asciidoctor-htmlbook/htmlbook"