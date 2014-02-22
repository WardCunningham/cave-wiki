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


# adventure data file

def segment file
  puts "doing segment #{file.gets}"
  while line = file.gets
    break if line =~ /^-1\s/
    yield line
  end
end

def room file
  num = nil
  txt = ''
  segment(file) do |line|
    if fields = /^(\d+)\s+(.*)$/.match(line)
      if fields[1] == num
        txt += " #{fields[2]}"
      else
        yield num, txt if num
        num = fields[1]
        txt = fields[2]
      end
    end
  end
  yield num, txt
end

def travel file
  segment(file) do |line|
    tk = line.split /\s+/
    num = tk.shift
    dest = tk.shift
    yield num, dest, tk
  end
end

def read
  File.open('advdat.77-03-31.txt','r') do |file|
    room(file) {|num,line| @rooms << num;  @room[num] = line}
    room(file) {|num,line| @short[num] = line}
    travel(file) {|num,to,tk| @dest[num][to] = tk}
    room(file) {|num,line| @words[num] = line.split /\s+/}
    room(file) {|num,line| @reply[num] = line}
    room(file) {|num,line| @help[num] = line}
  end
end

def shorten text
  return $1 if text=~/ AN? (.*?) PARALLEL/
  return $1 if text=~/ IN (.*?) WHICH/
  return $1 if text=~/ IN AN? (.*?)[.,]/
  return $1 if text=~/ ON THE (.*?)[.,]/
  return $1 if text=~/ IN THE (.*?)[.,]/
  return $1 if text=~/ AN? (.*?)[.,!]/
  return $1 if text=~/(THE [A-Z]+) /
  return $1 if text=~/^([A-Z' ]{5,35}?)\.?$/
  "no short"
end

def depersonalize text
  return $1 if text=~/MAZE OF (.*)$/
  return $1 if text=~/YOU'RE AT (.*)$/
  return $1 if text=~/YOU'RE IN (.*)$/
  return $1 if text=~/YOU'RE ON (.*)$/
  return $1 if text=~/YOU'RE (.*)$/
  text
end

def uniq num, text
  return "#{text} (#{num})" if @dup[text]
  return text if @dup[text] = true
end

def beTitle num
  return if num.to_i>80
  text = @short[num] || shorten(@room[num])
  uniq(num, titalize(depersonalize(text)))
end

def beDescription num
  capitalize @room[num]
end

def beChoice num, keys
  action = "Action ##{num}"
  list = keys.map do |key|
    @words[key].map(&:downcase).join ' '
  end
  "#{list.join ', '}<br>[[#{@title[num] || action}]]"
end

def dump num
  puts "\n== #{num} =================================="
  puts beDescription num
  puts @title[num]
  @dest[num].each do |num,keys|
    puts beChoice num,keys
  end
end

def emitStory num
  page @title[num] do
    paragraph beDescription num
    if @short[num]
      pagefold 'short'
      paragraph capitalize @short[num]
    end
    pagefold 'travel'
    # json @dest[num]
    @dest[num].each do |num,keys|
      paragraph beChoice num,keys
    end
  end
end

def emitDump title, hash
  page "#{title} (dump)" do
    paragraph "Debugging dump of the #{title} data structure."
    hash.keys.sort{|a,b|a.to_i <=> b.to_i}.each do |key|
      yield key, hash[key]
    end
  end
end

@dup ={}
@rooms = []
@room = {}
@short = {}
@title = {}

@dest = Hash.new {|h,k| h[k]={}}
@words = Hash.new {|h,k| h[k]=[]}
@words['1'] = ['(auto)']

@help = {}
@reply = {}

read
# exit

@rooms.each do |num|
  @title[num] = beTitle num
end

emitDump('Dest', @dest) {|k,v| paragraph "#{k}: #{@title[k]}"; json v}
emitDump('Words', @words) {|k,v| paragraph "#{k}: #{v.map(&:downcase).join ', '}"}
emitDump('Help', @help) {|k,v| paragraph "#{k}: #{capitalize v}"}
emitDump('Reply', @reply) {|k,v| paragraph "#{k}: #{capitalize v}"}

@@date -= 60

@rooms.each do |num|
  # dump num
  emitStory num
  @@date -= 1
end

puts 'end'
