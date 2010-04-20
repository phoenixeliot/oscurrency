class Transact < Exchange
  extend PreferencesHelper
  attr_accessor :to, :memo, :callback_url, :redirect_url
  attr_accessible :callback_url, :redirect_url

  after_create :perform_callback

  def create_req(memo)
    req = Req.new
    req.name = memo.blank? ? 'miscellaneous' : memo 
    req.person = customer
    req.estimated_hours = amount
    req.due_date = Time.now
    req.active = false
    req.save!
    req
  end

  def results
    if new_record?
    {
      :status => 'decline',
      :description => errors.full_messages.join(" ")
    }
    else
    {
      :to => worker.email,
      :from => customer.email,
      :amount => amount.to_s,
      :txn_date => created_at.iso8601,
      :memo => metadata.name,
      :txn_id => "http://" + Transact.global_prefs.server_name + "/transacts/#{id}",
      :status => 'ok'
    }
    end
  end

  def to_xml(options={})
    results.to_xml(options.merge(:root => "txn"))
  end

  def to_json(options={})
    results.to_json
  end

  protected

  def callback_uri
    @callback_uri ||= URI.parse(callback_url) if callback_url
  end

  def http
    unless @http
      @http = Net::HTTP.new(callback_uri.host, callback_uri.port)
      @http.use_ssl = true if callback_uri.scheme == "https"
    end
    @http
  end

  def perform_callback
    if callback_url
      request = Net::HTTP::Post.new(callback_uri.path+(callback_uri.query || '' ))
      request.set_form_data(results)
      response = http.request(request)
    end
  end
end