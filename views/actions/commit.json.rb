#
# Bulk apply comments and pre-approvals to agenda file
#

user = env.user
user = user.dup.untaint if user =~ /\A\w+\Z/
updates = YAML.load_file("#{AGENDA_WORK}/#{user}.yml")

agenda = updates['agenda']
agenda = agenda.dup.untaint if agenda =~ /\Aboard_agenda_[\d_]+\.txt\Z/
agenda_file = "#{FOUNDATION_BOARD}/#{agenda}"

File.open(agenda_file, 'r') do |file|
  file.flock(File::LOCK_EX)
  `svn cleanup #{File.dirname(agenda_file)}`
  `svn up #{agenda_file}`
  `svn revert #{agenda_file}`

  agenda = File.read(agenda_file)
  approved = updates['approved']
  comments = updates['comments']
  initials = @initials

  patterns = {
   '' => /
     ^\s{7}See\sAttachment\s\s?(\w+)[^\n]*?\s+
     \[\s[^\n]*\s*approved:\s*?(.*?)
     \s*comments:(.*?)\n\s{9}\]
     /mx,

   '3' => /
     ^\s{4}(\w)\.\sThe\smeeting\sof.*?
     \[\s[^\n]*\s*approved:\s*?(.*?)
     \s*comments:(.*?)\n\s{9}\]
     /mx,

   '4' => /
     ^\s{4}(\w)\.\sPresident\s\[.*?
     \[\s*comments:()(.*?)\n\s{9}\]
     /mx,
  }

  patterns.each do |prefix, pattern|
    agenda.gsub!(pattern) do |match|
      attachment, approvals = prefix + $1, $2

      if approved.include? attachment
        approvals = approvals.strip.split(/(?:,\s*|\s+)/)
        if approvals.include? initials
          # do nothing
        elsif approvals.empty?
          match[/approved:(\s*)\n/, 1] = " #{initials}"
        else
          match[/approved:.*?()\n/, 1] = ", #{initials}"
        end
      end

      if comments.include? attachment
        width = 79-13-initials.length
        text = comments[attachment].reflow(13+initials.length, width)
        text[/ *(#{' '*(initials.length+2)})/,1] = "#{initials}: "
        match[/\n()\s{9}\]/,1] = "#{text}\n"
      end

      match
    end
  end

  File.open(agenda_file, 'w') {|file| file.write(agenda)}

  commit = ['svn', 'commit', '-m', @message, agenda_file,
    '--no-auth-cache', '--non-interactive']

  if env.password
    commit += ['--username', env.user, '--password', env.password]
  end

  require 'shellwords'
  output = `#{Shellwords.join(commit).untaint} 2>&1`
  if $?.exitstatus != 0
    _.error (output.empty? ? 'svn commit failed' : output)
    raise Exception.new('svn commit failed')
  end

  pending = Pending.get(env.user)
  File.rename "#{AGENDA_WORK}/#{user}.yml", "#{AGENDA_WORK}/#{user}.bak"
  pending['approved'].clear
  pending['comments'].clear
  Pending.put(env.user, pending)

  _pending pending
  _agenda ASF::Board::Agenda.parse(File.read(agenda_file))
end
