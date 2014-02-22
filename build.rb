require 'rubygems'
require 'json'
require 'time'
require 'pp'


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
  text.gsub(/[\w']+/m) do |word|
      excluded.include?(word) ? word : word.capitalize
  end
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

def markdown text
  lines = text.split /(\r?\n)+/m
  lines.each do |line|
    line.gsub! /```(.+?)```/, '<b>\1</b>'
    line.gsub! /`(.+?)`/, '<b>\1</b>'
    line.gsub! /https?:\/\/\S+/, '[\0 \0]'
    line.gsub! /WardCunningham\/\S+?#\d+/, '[https://github.com/\0 \0]'
    line.gsub! /([0-9a-f]{7})[0-9a-f]{9,}/, '[https://github.com/wardcunningham/wiki/commit/\0 \1]'
    line.gsub! /##+/, '<h3>'
    paragraph line unless line[0,1] == '>'
  end
end

def page title
  @story = []
  @journal = []
  create title
  yield
  page = {'title' => title, 'story' => @story, 'journal' => @journal}
  path = "repo/#{@@repo}/pages/#{slug(title)}"
  File.open(path, 'w') do |file|
    file.write JSON.pretty_generate(page)
  end
  File.utime Time.at(@@date), Time.at(@@date), path
end


# github api json

def fetch resource, path
  puts "fetch #{path}"
  return if File.exist? path
  puts "fetching #{resource}"
  puts `curl -i -s 'https://api.github.com/repos/WardCunningham/#{resource}' > #{path}`
  puts `grep 'X-RateLimit-Remaining:' #{path}`
end

def comments issue
  return if issue['comments'] == 0
  path = "repo/#{@@repo}/comments-#{issue['number']}"
  fetch "#{@@repo}/issues/#{issue['number']}/comments", path
  head, json =  File.read(path).split(/\r\n\r\n/m)
  body = JSON.parse json
  body.each do |comment|
    @@date = Time.parse(comment['created_at']).to_i
    pagefold comment['user']['login'], comment['id'].to_s
    markdown comment['body']
    puts "#{comment['created_at']} #{comment['id']} #{comment['user']['login']}"
  end
end

def issues path
  puts "issues #{path}"
  head, json =  File.read(path).split(/\r\n\r\n/m)
  body = JSON.parse json
  result = []
  body.each do |issue|
    next if issue['pull_request']['patch_url']
    @@date = Time.parse(issue['created_at']).to_i
    puts "##{issue['number']} #{issue['title']}"
    title = titalize issue['title']
    result << "[[#{title}]]<br>##{issue['number']} by #{issue['user']['login']} with #{issue['comments']} comments"
    page title do
      pagefold "#{issue['state']} issue ##{issue['number']} by #{issue['user']['login']}"
      markdown issue['body']
      paragraph "See issue in [#{issue['html_url']} github]"
      comments issue
    end
  end
  result
end

def summary path, open, closed
  puts "summary #{path}"
  head, json =  File.read(path).split(/\r\n\r\n/m)
  body = JSON.parse json
  @@date = Time.parse(body['pushed_at']).to_i
  page titalize "#{body['name']} Issues" do
    paragraph "#{body['description']} [#{body['html_url']}/issues github]"
    paragraph "<h3> Open Issues" if open.length
    open.each {|issue| paragraph issue}
    paragraph "<h3> Closed Issues" if closed.length
    closed.each {|issue| paragraph issue}
  end
end

def repository name
  @@repo = name
  @@date = Time.now.to_i

  puts "repo #{@@repo}"

  fetch "#{@@repo}/issues?state=open&per_page=100", "repo/#{@@repo}/issues-open"
  open = issues "repo/#{@@repo}/issues-open"

  fetch "#{@@repo}/issues?state=closed&per_page=100", "repo/#{@@repo}/issues-closed"
  closed = issues "repo/#{@@repo}/issues-closed"

  fetch "#{@@repo}", "repo/#{@@repo}/repo"
  summary "repo/#{@@repo}/repo", open, closed
end

repository 'wiki'
repository 'wiki-client'
repository 'smallest-federated-wiki'
