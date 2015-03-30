# $Id: //sysadmin/projects/nagios/server_config/usr/local/nagios/bin/rf.rb#5 $
# $DateTime: 2014/09/22 14:32:38 $
# $Author: britcey $

module RF
  require 'rubygems'
  require 'restforce'
  require 'time'

  # probably want to remove this once we move to production;  will default to production host
  # ENV['SALESFORCE_HOST']           ||= 'akamai--p2rdev.cs10.my.salesforce.com'
  # ENV['SALESFORCE_HOST']           ||= 'test.salesforce.com'
  # ENV['SALESFORCE_HOST']         ||= 'https://login.salesforce.com'

  # ENV['SALESFORCE_CLIENT_ID']      ||= '3MVG9_7ddP9KqTze8qPExMfr0r9NpCeApoYlj1QYl2TIIOEoe8IcdLGc2FSNiyEVEkYFyl9B4bPc21S2NnJKn'
  # ENV['SALESFORCE_CLIENT_SECRET']  ||= '8525019726246010973'
  # ENV['SALESFORCE_USERNAME']       ||= 'nasyst@akamai.com.qa'
  # ENV['SALESFORCE_SECURITY_TOKEN'] ||= 'by3NdvMJ4WmMbCT0ejP3LnQqx'

  # in general these should be overridden via environment variables, but we'll set these here as a fallback
  # (and an indication of what needs to be set)
  ENV['SALESFORCE_CLIENT_ID']      ||= '3MVG9yZ.WNe6byQB.HwkBep96EOTd4epN7laQXhcvDw01hMorT8kl6EDndPjqTLDJuleUnN7n97ejAoEainzn'
  ENV['SALESFORCE_CLIENT_SECRET']  ||= '8574230680184466621'
  ENV['SALESFORCE_USERNAME']       ||= 'nagios@akamai.com'
  ENV['SALESFORCE_SECURITY_TOKEN'] ||= 'F21Vgk3S7381GO8R0lHPyewhK'

  ENV['SALESFORCE_PASSWORD']       ||= '** changeme **'

  @client = Restforce.new

  # Create a RF Incident with the given description
  #
  # @param descr [String] a description of the incident
  # @param opts [Hash] options that can be overridden
  # @option opts [Symbol] :short_descr The short description - by default it will be descr, up to the first carriage-return
  # @option opts [Symbol] :category (Nagios) RF category
  # @option opts [Symbol] :urgency (Severity 3) RF severity - 1..4 are currently defined
  # @option opts [Symbol] :status (UNASSIGNED) RF status
  # @option opts [Symbol] :client (calling RF client) Incident client
  # @option opts [Symbol] :date (now) Start time of the incident, in xsd:dateTime format
  # @return [Array<String>] the RF Name and RF Id
  #
  # @note This returns the RF 'Name' field (e.g., '00031402') along with the Id (e.g., a5UJ000000000xhMAA), since
  #       the former is what humans will use to look up incidents
  #
  # @todo - need to set BMCServiceDesk__FKAccount__c too?
  #
  def self.create_incident(descr, opts = {})
    opts = { :short_descr => nil,
             :category    => 'Nagios',
             :urgency     => 'Severity 3',
             :status      => 'UNASSIGNED',
             :client      => @client.options[:username],
             :date        => Time.now.iso8601
           }.merge(opts)

    opts[:short_descr] ||= descr.split(/\n/).first

    id = @client.create!('BMCServiceDesk__Incident__c',
                         'RecordTypeId'                           => get_id('RecordType', 'Helpdesk'),
                         'BMCServiceDesk__FKUrgency__c'           => get_id('BMCServiceDesk__Urgency__c', opts[:urgency]),
                         'BMCServiceDesk__FKCategory__c'          => get_id('BMCServiceDesk__Category__c', opts[:category]),
                         'BMCServiceDesk__FKStatus__c'            => get_id('BMCServiceDesk__Status__c', opts[:status]),
                         'BMCServiceDesk__FKClient__c'            => get_id('User', opts[:client], 'Username'),
                         'OwnerId'                                => get_id('User', opts[:client], 'Username'),
                         'Exclude_Client_Notifications__c'        => true,
                         'BMCServiceDesk__state__c'               => true, # 'Open'
                         'BMCServiceDesk__openDateTime__c'        => opts[:date],
                         'BMCServiceDesk__shortDescription__c'    => opts[:short_descr],
                         'BMCServiceDesk__incidentDescription__c' => descr + "\n\n-"
                        )

    [@client.find('BMCServiceDesk__Incident__c', id).Name, id]
  end


  # Add a note to an existing Incident
  #
  # @param name [String] The name of the incident (e.g., '00031402')
  # @param note [String] The text of the note to add to the incident
  # @param opts [Hash] options that can be overridden
  # @option opts [Symbol] :date (now) Start time of the incident, in xsd:dateTime format
  #
  # @return [String] The Salesforce Id of the note
  #
  # @note Aliased to #add_incident_note
  #
  def self.add_incident_note(name, note, opts = {})
    opts = { :date => Time.now.iso8601 }.merge(opts)

    begin
      @client.create!('BMCServiceDesk__IncidentHistory__c',
                      'BMCServiceDesk__note__c'       => note + "\n\n-",
                      'BMCServiceDesk__date__c'       => opts[:date],
                      'BMCServiceDesk__FKAction__c'   => get_id('BMCServiceDesk__Action__c', 'Notes'),
                      'BMCServiceDesk__FKIncident__c' => get_id('BMCServiceDesk__Incident__c', name)

                   )
    rescue Faraday::Error::ClientError => e
      if e.message =~ /This incident is closed. Reopen the incident to modify it./
        raise RuntimeError, "#{name} was already closed"
      else
        raise
      end
    end
  end
  class << RF
    alias_method :create_incident_note, :add_incident_note
  end

  # Create a RF Incident with the given description
  #
  # @param name [String] The name of the incident (e.g., '00031402')
  # @param resolution [String] The text for the resolution field of the incident
  #
  def self.close_incident(name, resolution)
    # id = get_id('BMCServiceDesk__Incident__c', name)
    # TODO - testme
    # could use #upsert to update by Name, but would create it if Name didn't exist, which might
    # lead to confusion;  but would update fail in that case because required fields are unset?
    # @client.update!('BMCServiceDesk__Incident__c', 'Id' => id,
    #                                                'BMCServiceDesk__incidentResolution__c' => resolution,
    #                                                'BMCServiceDesk__FKStatus__c' => get_id('BMCServiceDesk__Status__c', 'CLOSED')
    #                                                )

    # 2014-09-15 - working around an issue where RF won't accept PATCH calls, but wants a fake PATCH via POST+argument
    # see http://salesforce.stackexchange.com/questions/13294/patch-request-using-apex-httprequest
    incident = get_incident(name)
    url = incident.attributes.url + '?_HttpMethod=PATCH'
    @client.post url, { 'BMCServiceDesk__incidentResolution__c' => resolution,
                        'BMCServiceDesk__FKStatus__c' => get_id('BMCServiceDesk__Status__c', 'CLOSED')
                      }
  end

  # Fetch an incident
  #
  # @param name [String] The name of the incident (e.g., '00031402')
  # @return [Restforce::SObject] The matching BMCServiceDesk__Incident__c
  #
  # @note this is just used for debugging, normally don't need to call this directly
  #
  def self.get_incident(name)
    # id = get_id('BMCServiceDesk__Incident__c', name)
    # @client.find('BMCServiceDesk__Incident__c', id)
    # slightly faster like this
    @client.find('BMCServiceDesk__Incident__c', name, 'Name')
  end

  # Fetch an incident's status
  #
  # @param name [String] The name of the incident (e.g., '00031402')
  # @return [String] The status of the incident
  #
  def self.get_status(name)
    begin
      @client.select('BMCServiceDesk__Incident__c', name, ['BMCServiceDesk__Status_ID__c'], 'Name').BMCServiceDesk__Status_ID__c
    rescue Faraday::Error::ResourceNotFound
      nil
    end
  end

  # Find the first incident matching the short description
  #
  # @param descr [String] The short description of the incident (e.g., 'SSH on prod-nbudal-m2s3.dfw01.corp.akamai.com is CRITICAL')
  # @return [Array<String>] The RF Name (e.g., '00033123') and ID, or nil if no matching Incident
  #
  def self.find_open_incident_by_short_descr(descr, wildcard=false)
    operator = wildcard ? 'like' : '='
    query = "select Id, Name from BMCServiceDesk__Incident__c where BMCServiceDesk__state__c = true \
             and BMCServiceDesk__shortDescription__c #{operator} '#{descr}'"
    incidents = @client.query(query)
    if incidents.size > 0
      if wildcard
        return incidents.map{|i| [i.Name, i.Id] }
      else
        return [incidents.first.Name, incidents.first.Id]
      end
    else
      return []
    end
  end

  # Find all incidents matching the short description (wildcards-supported)
  #
  # @param descr [String] The short description of the incident, with optional wildcards (e.g., 'SSH on prod-nbudal-m2s3.dfw01.corp.akamai.com %)
  # @return [Array<Array<String>>] The RF Names (e.g., '00033123') and IDs, or nil if no matching Incidents
  #
  def self.find_open_incidents_by_short_descr_like(descr)
    find_open_incident_by_short_descr(descr, true)
  end

  # Find the RF Id for given sobject, based on the Name
  #
  # @param sobject [String] Salesforce sobject type
  # @param name [String] the record name
  # @param lookup_field [String] the name of the field to do the lookup on - 'Name' by default
  # @return [String] Id of the record
  #
  # @note this is primarily used internally, but leaving it exposed for debugging
  #
  def self.get_id(sobject, name, lookup_field='Name')
    records = @client.query("select Id from #{sobject} where #{lookup_field} = '#{name}'")
    if records.size > 0
      return records.first.Id
    else
      return nil
    end
    # begin
    #   @client.select(sobject, name, ['Id'], lookup_field).Id
    # rescue Faraday::Error::ResourceNotFound
    #   nil
    # end
  end

  # Get all the open RF incidents created by this client
  #
  # @param opts [Hash] options that can be overridden
  # @option opts [Symbol] :client The name of the client who created the incidents (defaults to SALESFORCE_USERNAME)
  #
  # @return [Restforce::Collection] A list of Incidents, including Id, Name and BMCServiceDesk__shortDescription__c
  #
  def self.get_open_incidents(opts = {})
    opts = { :client => @client.options[:username] }.merge(opts)

    @client.query("select Id, Name, BMCServiceDesk__shortDescription__c from BMCServiceDesk__Incident__c
                   where BMCServiceDesk__clientId__c = '#{opts[:client]}'
                   and BMCServiceDesk__state__c = true ")

                   # and BMCServiceDesk__Status_ID__c = 'UNASSIGNED' " )
  end

  def self.client
    @client
  end

  # Assign the RF incident with Name name to the user with id assignee_id
  #
  # @param name [String] the record name
  # @param assignee_id [String] assignee id
  #
  def self.assign_incident(name, assignee_id)
    incident = get_incident(name)
    user_id = get_id('User', "#{assignee_id}@akamai.com", 'Username')

    if user_id.nil?
      raise RuntimeError, "#{assignee_id} not found in RemedyForce"
    end

    @client.post incident.attributes.url + '?_HttpMethod=PATCH', { 'OwnerId' => user_id }
  end