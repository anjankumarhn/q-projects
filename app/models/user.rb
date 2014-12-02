class User < ActiveRecord::Base

  rolify

  # Associations
  belongs_to :client

  def self.find_by_email_or_username(query)
    self.where("LOWER(email) = LOWER('#{query}') OR LOWER(username) = LOWER('#{query}')").first
  end

  # Exclude some attributes info from json output.
  def as_json(options={})
    exclusion_list = []
    exclusion_list += ConfigCenter::Defaults::EXCLUDED_JSON_ATTRIBUTES
    exclusion_list += ConfigCenter::User::EXCLUDED_JSON_ATTRIBUTES
    options[:except] ||= exclusion_list
    super(options)
  end

  # Instance variables
  #
  # Exclude some attributes info from json output.
  def to_json(options={})
    options[:except] ||= ConfigCenter::User::ExcludedJsonAttributes
    super(options)
  end

  # * Return address which includes city, state & country
  # == Examples
  #   >>> user.display_address
  #   => "Mysore, Karnataka, India"
  def display_address
    address_list = []
    address_list << city unless city.blank?
    address_list << state unless state.blank?
    address_list << country unless country.blank?
    address_list.join(", ")
  end

  # * Return true if the user is either a Q-Auth Super Admin or Q-Auth Admin
  # == Examples
  #   >>> user.is_admin?
  #   => true
  def is_admin?
    user_type == 'super_admin' || user_type == 'admin'
  end

  # * Return true if the user is either a Q-Auth Admin
  # == Examples
  #   >>> user.is_super_admin?
  #   => true
  def is_super_admin?
    user_type == 'super_admin'
  end

  # * Return true if the user is not approved, else false.
  # * pending status will be there only for users who are not approved by user
  # == Examples
  #   >>> user.pending?
  #   => true
  def pending?
    (status == ConfigCenter::User::PENDING)
  end

  # * Return true if the user is approved, else false.
  # == Examples
  #   >>> user.pending?
  #   => true
  def approved?
    (status == ConfigCenter::User::APPROVED)
  end

  # * Return true if the user is blocked, else false.
  # == Examples
  #   >>> user.blocked?
  #   => true
  def blocked?
    (status == ConfigCenter::User::BLOCKED)
  end

  # change the status to :pending
  # Return the status
  # == Examples
  #   >>> user.pending!
  #   => "pending"
  def pending!
    self.update_attribute(:status, ConfigCenter::User::PENDING)
  end

  # change the status to :approve
  # Return the status
  # == Examples
  #   >>> user.approve!
  #   => "approved"
  def approve!
    self.update_attribute(:status, ConfigCenter::User::APPROVED)
  end

  # change the status to :approve
  # Return the status
  # == Examples
  #   >>> user.block!
  #   => "blocked"
  def block!
    self.update_attribute(:status, ConfigCenter::User::BLOCKED)
  end

  def self.authenticate(login_handle, password)
    url = ConfigCenter::Authentication::SIGN_IN_URL
    Rails.logger.info "Logging to #{url} in as #{login_handle}"

    request = Typhoeus::Request.new(
      url,
      method: :post,
      params: {login_handle: login_handle, password: password},
      verbose: false
    )
    response = request.run

    raise CouldntConnectError if response.return_code == :couldnt_connect

    response_json = JSON.parse(response.body)

    if response_json["success"]

      username = response_json["data"]["username"]
      user = User.find_by_username(username) || User.new(response_json["data"])

      # Updating the Q-Auth User id
      user.q_auth_uid = response_json["data"]["id"]

      # Saving the user
      user.save

      return [true, user]
    else
      return [false, response_json["data"]["errors"]]
    end
  end


end
