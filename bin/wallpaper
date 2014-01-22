#!/usr/bin/env ruby

require "sqlite3"

unless ARGV.length == 1
  puts "Usage: wallpaper <filename>"
  exit
end


DB_LOC = File.join(ENV["HOME"], "Library/Application Support/Dock/desktoppicture.db")
DB = SQLite3::Database.new(DB_LOC)

DB.execute("SELECT ROWID,value FROM data").each do |(rowid,path)|
  DB.execute("UPDATE data SET value=? WHERE ROWID=?",[ARGV[0],rowid])  
end

`killall Dock`
