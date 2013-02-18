# Short Distance Runner (Local Bug Tracking System)
# Short Distance Runner i a simple bug tracking system for use in the terminal application.
# The main goal is to simplify bug tracking tasks by only using requireing the most basic
# data in order to create a ticket.
#
# Author: Muthaias

require "yaml"


############################################################
# Definitions
############################################################
$cfg_speak = false 


# Use inline style for hash
class Hash
	def to_yaml_style
		:inline
	end
end

module AppBase
	# Print commands
	def self.print_cmds(cmds)
		cmds.each do |cmd, act|
			(name,argc) = cmd.split(":")
			puts "\e[31m#{name}\e[0m: Takes #{argc} parameter(s)."
			if(act[:desc] != nil)
				puts "  \e[33m#{act[:desc]}\e[0m"
			end
		end
	end

	# Parse options from command line
	def self.parse_opts(opts, argv)
		was_found = false
		opts.each do |cmd, act|
			(name,argc) = cmd.split(":")
			argc = argc.to_i
			if(nil != i = argv.index(name))
				argend = i + argc
				if(argv.size > argend)
					act[:func].call(*argv[(i+1)..argend])
					(i..argend).each{|e| argv.delete_at(i)}
				else
					puts "Argument error: option \"#{argv[0]}\", requires #{argc} arguments."
				end
			end
		end
	end

	# Parse commands from command line
	def self.parse_cmds(commands, argv)
		if(argv[0] == nil)
			return
		end

		was_found = false
		commands.each do |cmd, act|
			(name,argc) = cmd.split(":")
			if(name.casecmp(argv[0]) == 0)
				was_found = true
				if(argv.size > argc.to_i)
					act[:func].call(*argv[1..argc.to_i])
					return
				end
			end
		end

		if(was_found)
			puts "Argument error: command #{argv[0]}"
		end
	end
end # AppBase

# Creates a new local user
def make_user(username)
	File.open(".sdr_usr", "w") do |f|
		f.write(username)
	end
end

# Search for a database, traversing the file hierachy upwards
def get_db_path(db_base)
	# Look for database file in previous directories
	pwd = Dir.pwd
	pwd_last = ""
	until pwd.casecmp(pwd_last) == 0
		db_path = File.join(pwd, db_base)
		if(File.exist?(db_path))
			return db_path
		end
		pwd_last = pwd
		pwd = File.dirname(pwd)
	end

	# If no database is found, search for user file
	pwd = Dir.pwd
	until pwd.casecmp(pwd_last) == 0
		usr_path = File.join(pwd, ".sdr_usr")
		if(File.exist?(usr_path))
			return File.join(pwd, db_base)
		end
		pwd_last = pwd
		pwd = File.dirname(pwd)
	end

	# Return base path
	return db_base
end

# Standard way to print a bug
def bug_print(bug)
	if(bug == nil)
		puts "Error: No bug found"
		return
	end

	puts "#{bug[:priority].to_i}. bug[\e[31m#{bug[:id]}\e[0m|\e[31m#{bug[:status]}\e[0m]: \e[33m#{bug[:description]}\e[0m"
	system("say \"bug, priority #{bug[:priority].to_i}, #{bug[:description]}, status #{bug[:status]}\"") if($cfg_speak)
	if(bug[:notes] != nil)
		bug[:notes].each do |note|
			puts "  \e[31m*note:\e[0m \e[33m#{note}\e[0m"
			system("say \"note, #{note}\"") if($cfg_speak)
		end
	end
end

# Make a safe string comparision
def safecmp(str1, str2)
	if(str1 == nil or str2 == nil)
		return false
	elsif(str1.casecmp(str2) == 0)
		return true;
	end
end

# Gets the current user using information from svn
def get_svn_user()
	return "svn user"
end

# Gets the current user using information from git
def get_git_user()
	user = `git config user.name`
	return user
end

# Gets the current user using the SDR user file
def get_sdr_user()
	pwd = Dir.pwd
	pwd_last = ""
	until pwd.casecmp(pwd_last) == 0
		usr_path = File.join(pwd, ".sdr_usr")
		if(File.exist?(usr_path))
			return File.read(usr_path)
		end
		pwd_last = pwd
		pwd = File.dirname(pwd)
	end
	return nil
end

# Get the current user from the system, using posix
def get_sys_user()
	user = `echo $LOGNAME`
	return user.to_s.strip
end

# Detects a user name from different setups
def detect_user()
	user = "default user"

	if(nil != m = get_sdr_user())
		user = m

	elsif(File.exist?(".svn"))
		user = get_svn_user()

	elsif(File.exist?(".git"))
		user = get_git_user()

	else
		user = get_sys_user()
	end

	return user
end

# The actual bug tracker class
class BugTracker
	attr_reader :bugs, :user

	# Initializes the bug tracker with a location for the database and a user name
	def initialize(location, user)
		@location = location
		@user = user
		load_data()
	end

	# Takes a description and adds a bug to the database.
	# Returns the id of the bug.
	def add_bug(description, status = "new")
		id = get_new_bug_id()
		bug = new_bug(@user, description, id, status)
		@bugs.push(bug)
		bug_print(bug)
		store_data()
		return id
	end

	# Returns a new unused bug id
	def get_new_bug_id()
		id = 0
		@bugs.each do |bug|
			if(id < bug[:id])
				id = bug[:id]
			end
		end
		return id + 1
	end

	# Sets the status of a bug
	def set_bug_status(id, status)
		set_bug_item(id, :status, status)
	end

	# Sets the item of a bug to value 
	def set_bug_item(id, item, value)
		i = bugs.index{|bug| bug[:id] == id}
		if(i != nil)
			bugs[i][item] = value
			store_data()
			return bugs[i]
		else
			return nil
		end
	end

	# Sets the item of a bug to value 
	def push_bug_item(id, item, value)
		i = bugs.index{|bug| bug[:id] == id}
		if(i != nil)
			if(bugs[i][item] == nil)
				bugs[i][item] = Array.new()
			end
			bugs[i][item].push(value)
			store_data()
			return bugs[i]
		else
			return nil
		end
	end

	# Returns a hash map with the users as keys and arrays of bugs as values
	def users
		users = Hash.new()
		@bugs.each do |bug|
			if(users[bug[:user]] == nil)
				users[bug[:user]] = Array.new()
			end
			users[bug[:user]].push(bug)
		end
		return users
	end

	# Explicitly reloads data from the database
	def load_data()
		if(File.exist?(@location))
			@bugs = YAML::load(File.read(@location))
			verify()
		else
			@bugs = Array.new()
		end
	end

	# Explicitly stores the runtime data in the database
	def store_data()
		File.open(@location, 'w') do |f|
			f.write(@bugs.to_yaml)
		end
	end

	# Check for consistency in the bug database
	def verify()
		lookup = Hash.new()
		doubles = Array.new()
		@bugs.each do |bug|
			if(lookup[bug[:id]] != nil)
				doubles.push(bug)
			end
			lookup[bug[:id]] = bug
		end

		if(doubles.size > 0)
			puts "Warning: Found duplicate bug IDs, new IDs were assigned"
			base_id = get_new_bug_id()
			doubles.each_index do |i|
				doubles[i][:id] = base_id + i
				bug_print(doubles[i])
			end
			store_data()
		end
	end

	def new_bug(user, description, id, status)
		{
			:user => user,
			:description => description,
			:id => id,
			:status => status
		}
	end
end #BugTracker


############################################################
# Main application execution
############################################################

# Setup default values
usr = detect_user()
db_path = get_db_path("sdr_db.yaml")

# Parse options
opts = Hash.new()
opts["--username:1"] = {
	:func => lambda do |username|
		usr = username
	end,
	:desc => "Temporarily sets the username. '--username [username]'"
}
opts["--dbpath:1"] = {
	:func => lambda do |path|
		db_path = path
	end,
	:desc => "Temporarily sets the database path. '--dbpath [path]'"
}
opts["-speak:0"] = {
	:func => lambda do
		$cfg_speak = true
	end,
	:desc => "Makes SDR speak its bugs. '-speak'"
}
AppBase.parse_opts(opts, ARGV)

# Setup the tracker
tracker = BugTracker.new(db_path, usr)

# Parse commands
cmds = Hash.new()
cmds["list:1"] = {
	:func => lambda do |type|
		if(safecmp(type, "bugs"))
			tracker.bugs.sort{|a,b| a[:priority].to_i <=> b[:priority].to_i}.each() do |bug|
				bug_print(bug)
			end

		elsif(safecmp(type, "users"))
			tracker.users.each() do |user, bugs|
				puts "#{user}"
			end

		elsif(safecmp(type, "mine"))
			if(tracker.users[usr] != nil)
				tracker.users[usr].sort{|a,b| a[:priority].to_i <=> b[:priority].to_i}.each do |bug|
					bug_print(bug)
				end
			end
		end
	end,
	:desc => "Lists a number of properties in database. 'list [bugs|users|mine]'"
}
cmds["find:1"] = {
	:func => lambda do |filter|
		bug_list = tracker.bugs.select{|bug| bug[:description].match(/.*#{filter}.*/) != nil}
		bug_list.sort{|a,b| a[:priority].to_i <=> b[:priority].to_i}.each do |bug|
			bug_print(bug)
		end
	end,
	:desc => "Finds and lists bugs using a filter on their description. 'find [filter]'"
}
cmds["fstat:1"] = {
	:func => lambda do |filter|
		bug_list = tracker.bugs.select{|bug| bug[:status].match(/.*#{filter}.*/) != nil}
		bug_list.sort{|a,b| a[:priority].to_i <=> b[:priority].to_i}.each do |bug|
			bug_print(bug)
		end
	end,
	:desc => "Finds and lists bugs using a filter on their status. 'fstat [filter]'"
}
cmds["add:2"] = {
	:func => lambda do |desc, stat|
		tracker.add_bug(desc, stat)
	end,
	:desc => "Adds a new bug. 'add [description] [status]'"
}
cmds["stat:2"] = {
	:func => lambda do |id, stat|
		bug = tracker.set_bug_status(id.to_i, stat)
		bug_print(bug)
	end,
	:desc => "Sets status of a specified bug. 'stat [bug_id] [status]'"
}
cmds["mkusr:1"] = {
	:func => lambda do |usr|
		make_user(usr)
	end,
	:desc => "Adds a local SDR user file. 'mkusr [username]'"
}
cmds["user:0"] = {
	:func => lambda do
		puts usr
	end,
	:desc => "Show the current username. 'user'"
}
cmds["update:0"] = {
	:func => lambda do
		tracker.store_data()
	end,
	:desc => "Update the database. 'update'"
}
cmds["help:0"] = {
	:func => lambda do
		puts "Usage: [command] [arguments] [options]"
		puts "Command description:"
		AppBase.print_cmds(cmds)
		puts ""
		puts "Option description:"
		AppBase.print_cmds(opts)
	end,
	:desc => "Displays this message. 'help'"
}
cmds["prio:2"] = {
	:func => lambda do |id, prio|
		bug = tracker.set_bug_item(id.to_i, :priority, prio.to_i)
		bug_print(bug)
	end,
	:desc => "Sets bug priority. 'prio [id] [priority]'"
}
cmds["note:2"] = {
	:func => lambda do |id, note|
		bug = tracker.push_bug_item(id.to_i, :notes, note)
		bug_print(bug)
	end,
	:desc => "Adds a note to a bug. 'note [id] [note]'"
}
AppBase.parse_cmds(cmds, ARGV)
