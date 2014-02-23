require 'rubygems'
require 'json'
require 'time'
require 'pp'

@@date = Time.now.to_i

# wiki utilities

def random
  (1..16).collect {(rand*16).floor.to_s(16)}.join ''
end

def slug title
  title.gsub(/\s/, '-').gsub(/[^A-Za-z0-9-]/, '').downcase()
end

def clean text
  text.gsub(/’/,"'")
end

def url text
  text.gsub(/(http:\/\/)?([a-zA-Z0-9._-]+?\.(net|com|org|edu)(\/[^ )]+)?)/,'[http:\/\/\2 \2]')
end

def domain text
  text.gsub(/((https?:\/\/)(www\.)?([a-zA-Z0-9._-]+?\.(net|com|org|edu|us|cn|dk|au))(\/[^ );]*)?)/,'[\1 \4]')
end

def titalize text
  excluded = %w(the this that if and or not may any all in of by for at to be)
  text.capitalize!
  text.gsub! /[\[\]]/, ''
  text.gsub! /[.!]$/, ''
  text.gsub(/[\w']+/m) do |word|
      excluded.include?(word) ? word : word.capitalize
  end
end

def capitalize text
  sentences = text.downcase.split '. '
  sentences.map(&:capitalize).join '. '
end


# journal actions

def create title
  @journal << {'type' => 'create', 'id' => random, 'item' => {'title' => title}, 'date' => @@date*1000}
end

def add item
  @story << item
  @journal << {'type' => 'add', 'id' => item['id'], 'item' => item, 'date' => @@date*1000}
end


# story emiters

def paragraph text
  return if text =~ /^\s*$/
  text.gsub! /\r\n/, "\n"
  add({'type' => 'paragraph', 'text' => text, 'id' => random()})
end

def pagefold text, id = random()
  text.gsub! /\r\n/, ""
  add({'type' => 'pagefold', 'text' => text, 'id' => id})
end

def page title
  @story = []
  @journal = []
  create title
  yield
  page = {'title' => title, 'story' => @story, 'journal' => @journal}
  path = "../pages/#{slug(title)}"
  File.open(path, 'w') do |file|
    file.write JSON.pretty_generate(page)
  end
  File.utime Time.at(@@date), Time.at(@@date), path
end

def json obj
  text = JSON.pretty_generate(obj)
  add({'type' => 'code', 'text' => text, 'id' => random()})
end


# find basic blocks

@lines = File.read('advf4.77-03-31.txt').split /\n/
@blocks = []
@blocks << @block = []
@lines.each do |line|
  @block << line
  @blocks << @block = [] if line =~ /\tGOTO\s\d+/
  break if line =~ /\tEND/
end
@blocks.pop

# find major sections, color labels

@dot = []
@labelColor = {}

@sections = [
  "READ THE PARAMETERS    ",
  "TRAVEL                 ",
  "DWARF STUFF            ",
  "PLACE DESCRIPTOR       ",
  "GO GET A NEW LOCATION  ",
  "DO NEXT INPUT          ",
  "CARRY                  "]

@sections.each_with_index do |label, index|
  @dot << "\"#{label}\" [fillcolor=#{index+1} shape=box];"
  @dot << "\"#{@sections[index-1]}\" -> \"#{label}\" [color=lightGray]" if index > 0
end

@blocks.each do |block|
  block.each do |line|
    @color = '1' if line =~ /^C READ THE PARAMETERS/
    @color = '2' if line =~ /^C TRAVEL/
    @color = '3' if line =~ /^C DWARF STUFF/
    @color = '4' if line =~ /^C PLACE DESCRIPTOR/
    @color = '5' if line =~ /^C GO GET A NEW LOCATION/
    @color = '6' if line =~ /^C DO NEXT INPUT/
    @color = '7' if line =~ /^C CARRY/
  end
  block.each do |line|
    @labelColor[$1]=@color if line =~ /^(\d+)\t/
  end
end

# define iterators over blocks

def blocks
  @blocks.each do |block|
    label = color = nil
    block.each do |line|
      if line =~ /^(\d+)/
        label = $1
        color = @labelColor[label]
        break
      end
    end
    yield block, label, color
  end
end

def lines
  blocks do |block, label, color|
    block.each do |line|
      yield line, label, color
    end
  end
end

def labels
  lines do |line, label, color|
    if line =~ /^(\d+)\t/
      yield line, $1, color, label
    end
  end
end

def gotos
  lines do |line, me, color|
    if line =~ /\t(.*)GOTO\s+(\d+)$/
      if $1 == ''
        # @dot << "#{me} -> #{$2};"
        yield me, $2
      else
        # @dot << "#{me} -> #{$2} [color=blue];"
        yield me, $2, :conditional
      end
    end
    if line =~ /\tGOTO\((.*?)\)/
      $1.scan(/(\d+)/) do |match|
        # @dot << "#{me} -> #{match} [color=red]"
        yield me, "#{match}", :computed
      end
    end
  end
end


# find gotos, create nodes and arcs

@blockColor = {}
blocks do |block, label, color|
  @blockColor[label] = color
  @dot << "#{label} [shape=box fillcolor=#{color}];"
end

@lableUses = Hash.new(0)
@labelCallColors = Hash.new {|h,k| h[k]=Hash.new(0)}
gotos do |from, to, type|
  @lableUses[to] += 1
  @labelCallColors[to][@labelColor[from]] += 1
end
pp @labelCallColors

gotos do |from, to, type|
  aka = to
  next unless @blockColor[to] or (@labelColor[from] != @labelColor[to])
  if @labelColor[from] != @labelColor[to] and @labelCallColors[to].keys.length > 1
    aka = "\"#{to} #{@labelColor[from]}\""
    @dot << "#{aka} [shape=oval fillcolor=#{@labelColor[to]} label=#{to}]"
    puts @dot.last
  end
  case type
  when :conditional
    @dot << "#{from} -> #{aka} [color=blue];"
  when :computed
    @dot << "#{from} -> #{aka} [color=red];"
  else
    @dot << "#{from} -> #{aka} [color=gray];"
  end
end

File.open('block.dot','w') {|file| file.puts "strict digraph {node[style=filled colorscheme=set27 shape=circle]; #{@dot.join "\n"}}\n"}

puts 'end'
