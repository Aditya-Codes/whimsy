# Back sections:
# * Discussion Items
# * Review Outstanding Action Items
# * Unfinished Business
# * New Business
# * Announcements
# * Adjournment

class ASF::Board::Agenda
  parse do
    pattern = /
      ^(?<attach>(?:\s[89]|\s9|1\d)\.)
      \s(?<title>.*?)\n
      (?<text>.*?)
      (?=\n[\s1]\d\.|\n===)
    /mx

    scan @file, pattern do |attrs|
      attrs['attach'].strip!
      attrs['title'].sub! /^Review Outstanding /, ''

      if attrs['title'] =~ /Discussion|Action|Business|Announcements/
        attrs['prior_reports'] = minutes(attrs['title'])
      elsif attrs['title'] == 'Adjournment'
        attrs['timestamp'] = timestamp(attrs['text'][/\d+:\d+([ap]m)?/])
      end

      if attrs['title'] =~ /Action Items/

        # extract action items associated with projects
        text = attrs['text'].sub(/\A\s*\n/, '').sub(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min || 1
        text.gsub! /^ {#{unindent-1}}/, ''

        attrs['missing'] = text.empty?

        attrs['actions'] = text.sub(/^\* /, '').split(/^\n\* /).map do |text|
          match1 = /(.*?)(\n\s*Status:(.*))/m.match(text)
          match2 = /(.*?)(\[ ([^\]]+) \])?\s*\Z/m.match(match1[1])
          match3 = /(.*?): (.*)\Z/m.match(match2[1])
          match4 = /(.*?)( (\d+-\d+-\d+))?$/.match(match2[3])

          { 
            owner: match3[1],
            text: match3[2].strip,
            status: match1[3].to_s.strip,
            pmc: (match4[1] if match4), 
            date: (match4[3] if match4)
          }
        end
      end
    end
  end
end
