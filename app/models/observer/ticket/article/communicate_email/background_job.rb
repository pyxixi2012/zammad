class Observer::Ticket::Article::CommunicateEmail::BackgroundJob
  def initialize(id)
    @article_id = id
  end

  def perform
    record = Ticket::Article.find(@article_id)

    # build subject
    ticket = Ticket.lookup(id: record.ticket_id)
    article_count = Ticket::Article.where(ticket_id: ticket.id).count
    subject = if article_count > 1
                ticket.subject_build(record.subject, true)
              else
                ticket.subject_build(record.subject)
              end

    # set retry count
    if !record.preferences['delivery_retry']
      record.preferences['delivery_retry'] = 0
    end
    record.preferences['delivery_retry'] += 1

    # send email
    if !ticket.group.email_address_id
      log_error(record, "No email address defined for group id '#{ticket.group.id}'!")
    elsif !ticket.group.email_address.channel_id
      log_error(record, "No channel defined for email_address id '#{ticket.group.email_address_id}'!")
    end

    channel = ticket.group.email_address.channel

    notification = false
    sender = Ticket::Article::Sender.lookup(id: record.sender_id)
    if sender['name'] == 'System'
      notification = true
    end

    # get linked channel and send
    begin
      message = channel.deliver(
        {
          message_id: record.message_id,
          in_reply_to: record.in_reply_to,
          references: ticket.get_references([record.message_id]),
          from: record.from,
          to: record.to,
          cc: record.cc,
          subject: subject,
          content_type: record.content_type,
          body: record.body,
          attachments: record.attachments
        },
        notification
      )
    rescue => e
      log_error(record, e.message)
      return
    end
    if !message
      log_error(record, 'Unable to get sent email')
      return
    end

    # set delivery status
    record.preferences['delivery_status_message'] = nil
    record.preferences['delivery_status'] = 'success'
    record.preferences['delivery_status_date'] = Time.zone.now
    record.save!

    # store mail plain
    record.save_as_raw(message.to_s)

    # add history record
    recipient_list = ''
    [:to, :cc].each { |key|

      next if !record[key]
      next if record[key] == ''

      if recipient_list != ''
        recipient_list += ','
      end
      recipient_list += record[key]
    }

    Rails.logger.info "Send email to: '#{recipient_list}' (from #{record.from})"

    return if recipient_list == ''

    History.add(
      o_id: record.id,
      history_type: 'email',
      history_object: 'Ticket::Article',
      related_o_id: ticket.id,
      related_history_object: 'Ticket',
      value_from: record.subject,
      value_to: recipient_list,
      created_by_id: record.created_by_id,
    )
  end

  def log_error(local_record, message)
    local_record.preferences['delivery_status'] = 'fail'
    local_record.preferences['delivery_status_message'] = message
    local_record.preferences['delivery_status_date'] = Time.zone.now
    local_record.save
    Rails.logger.error message

    if local_record.preferences['delivery_retry'] > 3

      recipient_list = ''
      [:to, :cc].each { |key|

        next if !local_record[key]
        next if local_record[key] == ''

        if recipient_list != ''
          recipient_list += ','
        end
        recipient_list += local_record[key]
      }

      Ticket::Article.create(
        ticket_id: local_record.ticket_id,
        content_type: 'text/plain',
        body: "Unable to send email to '#{recipient_list}': #{message}",
        internal: true,
        sender: Ticket::Article::Sender.find_by(name: 'System'),
        type: Ticket::Article::Type.find_by(name: 'note'),
        preferences: {
          delivery_article_id_related: local_record.id,
          delivery_message: true,
        },
        updated_by_id: 1,
        created_by_id: 1,
      )
    end

    raise message
  end

  def max_attempts
    4
  end

  def reschedule_at(current_time, attempts)
    if Rails.env.production?
      return current_time + attempts * 20.seconds
    end
    current_time + 5.seconds
  end
end
