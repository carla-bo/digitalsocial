class User

  include Mongoid::Document

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable,
         :trackable, :validatable, :token_authenticatable

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""
  
  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String

  ## Token authenticatable
  field :authentication_token, type: String

  field :first_name, type: String

  has_many :organisation_memberships
  
  validates :first_name, :email, presence: true

  before_save :ensure_authentication_token

  def organisation_resources
    organisation_memberships.collect(&:organisation_resource)
  end

  def send_request_digest(organisation)
    RequestMailer.request_digest(self, organisation).deliver
  end

  def self.send_request_digests
    User.all.each do |user|
      user.organisation_resources.each do |organisation|
        user.send_request_digest(organisation) if organisation.has_respondables?
      end
    end
  end

end