class Chat
  Vue.util.defineReactive @@log, []
  Vue.util.defineReactive @@topic, {}

  Chat.fetch_requested = false
  Chat.backlog_fetched = false

  # as it says: fetch backlog of chat messages from the server
  def self.fetch_backlog()
    return if Chat.fetch_requested

    retrieve "chat/#{Agenda.file[/\d[\d_]+/]}", :json do |messages|
      messages.each {|message| Chat.add message}
      Chat.backlog_fetched = true
    end

    Chat.fetch_requested = true

    self.countdown()
    setInterval self.countdown, 30_000
  end

  # set topic to meeting status
  def self.countdown()
    status = Chat.status
    Chat.setTopic subtype: 'status', user: 'whimsy', text: status if status
  end

  # replace topic locally
  def self.setTopic(entry)
    return if @@topic.text == entry.text
    @@log = @@log.filter {|item| return item.type != :topic}
    entry.type = :topic
    @@topic = entry
    Chat.add entry
    Main.refresh() if entry.subtype == :status
  end

  # change topic globally
  def self.changeTopic(entry)
    return if @@topic.text == entry.text

    entry.type = :topic
    entry.agenda = Agenda.file
    post 'message', entry do |message|
      Chat.setTopic entry
    end
  end

  # return the chat log
  def self.log
    @@log
  end

  # add an entry to the chat log
  def self.add(entry)
    entry.timestamp ||= Date.new().getTime()

    if @@log.empty? or @@log.last.timestamp < entry.timestamp
      @@log << entry
    else
      for i in 0...@@log.length
        if entry.timestamp <= @@log[i].timestamp
          if entry.timestamp!=@@log[i].timestamp or entry.text!=@@log[i].text
            @@log.splice(i, 0, entry)
          end
          break
        end
      end
    end
  end

  # meeting status for countdown
  def self.status
    diff = Agenda.find('Call-to-order').timestamp - Date.new().getTime()

    if Minutes.complete
      "meeting has completed"
    elsif Minutes.started
      if @@topic.subtype == :status
        @@topic.text
      else
        "meeting has started"
      end
    elsif diff > 86_400_000 * 3/2
      "meeting will start in about #{Math.floor(diff/86_400_000+0.5)} days"
    elsif diff > 3_600_000 * 3/2
      "meeting will start in about #{Math.floor(diff/3_600_000+0.5)} hours"
    elsif diff > 300_000
      "meeting will start in about #{Math.floor(diff/300_000+0.5)*5} minutes"
    elsif diff > 90_000
      "meeting will start in about #{Math.floor(diff/60_000+0.5)} minutes"
    else
      "meeting will start shortly"
    end
  end
end

# subscriptions

Events.subscribe :chat do |message|
  if message.agenda == Agenda.file
    message.delete agenda
    Chat.add message
  end
end

Events.subscribe :info do |message|
  if message.agenda == Agenda.file
    message.delete agenda
    Chat.add message
  end
end

Events.subscribe :topic do |message|
  if message.agenda == Agenda.file
    Chat.setTopic message
  end
end

Events.subscribe :arrive do |message|
  Server.online = message.present
  Chat.add type: :info, user: message.user, timestamp: message.timestamp,
    text: 'joined the chat'
end

Events.subscribe :depart do |message|
  Server.online = message.present
  Chat.add type: :info, user: message.user, timestamp: message.timestamp,
    text: 'left the chat'
end
