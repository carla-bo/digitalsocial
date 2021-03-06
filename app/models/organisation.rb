# -*- coding: utf-8 -*-
class Organisation

  include Tripod::Resource
  include ConceptFields
  include TripodCache

  rdf_type 'http://www.w3.org/ns/org#Organization'
  graph_uri Digitalsocial::DATA_GRAPH

  field :name, 'http://www.w3.org/2000/01/rdf-schema#label'
  field :primary_site, 'http://www.w3.org/ns/org#hasPrimarySite', is_uri: true

  field :twitter, 'http://data.digitalsocial.eu/def/ontology/twitterAccount', is_uri: true # this should be the full URL http://twitter.com/blah
  field :webpage, 'http://xmlns.com/foaf/0.1/page', is_uri: true
  field :logo, 'http://xmlns.com/foaf/0.1/logo', is_uri: true

  concept_field :organisation_type, 'http://data.digitalsocial.eu/def/ontology/organizationType', Concepts::OrganisationType
  concept_field :fte_range, 'http://data.digitalsocial.eu/def/ontology/numberOfFTEStaff', Concepts::FTERange

  validates :name, presence: true
  validate :organisation_name_is_unique

  before_save :strip_whitespace
  before_destroy :destroy_solely_associated_projects
  before_destroy :destroy_project_memberships
  before_destroy :destroy_organisation_memberships

  attr_accessor :invited_users, :invites_to_send

  # override initialise
  def initialize(uri=nil, graph_uri=nil)
    super(uri || Organisation.slug_to_uri(Guid.new))
  end

  def self.slug_to_uri(slug)
    "http://data.digitalsocial.eu/id/organization/#{slug}"
  end

  def self.uri_to_slug(uri)
    uri = uri.to_s # in case it's an RDF URI
    uri.present? ? uri.split("/").last : nil
  end

  def guid
    self.uri.to_s.split("/").last
  end

  def to_param
    guid
  end

  def primary_site_resource
    Site.find(self.primary_site) if self.primary_site
  end

  def projects
    project_membership_org_predicate = ProjectMembership.fields[:organisation].predicate.to_s
    project_membership_project_predicate = ProjectMembership.fields[:project].predicate.to_s
    Project
      .where("?pm_uri <#{project_membership_org_predicate}> <#{self.uri}>")
      .where("?pm_uri <#{project_membership_project_predicate}> ?uri")
  end

  def project_resources
    projects.resources
  end

  def project_resource_uris
    projects.resources.collect { |p| p.uri.to_s }
  end

  def any_projects?
    projects.count > 0
  end

  def project_memberships_for_project(project)
    project_membership_org_predicate = ProjectMembership.fields[:organisation].predicate.to_s
    project_membership_project_predicate = ProjectMembership.fields[:project].predicate.to_s
    ProjectMembership
      .where("?uri <#{project_membership_org_predicate}> <#{self.uri}>")
      .where("?uri <#{project_membership_project_predicate}> <#{project.uri}>")
  end

  def is_member_of_project?(project)
    project_memberships_for_project(project).count > 0
  end

  def can_edit_project?(project)
    is_member_of_project?(project)
  end

  # projects I've been invited to
  def pending_project_invites
    ProjectInvite.where(invited_organisation_uri: self.uri, open: true)
  end

  # projects where the invitor has suggested I invite someone to join
  # my organisation.
  def pending_suggested_invites
    ProjectInvite.where(invited_organisation_uri: self.uri, handled_suggested_invite: false)
  end

  # projects I've requested to join
  def pending_project_requests_by_self
    ProjectRequest.where(requestor_organisation_uri: self.uri, open: true)
  end

  # Our projects that others have requested to join
  def pending_project_requests_by_others
    ProjectRequest.where(open: true).in(project_uri: project_resource_uris)
  end

  # People who've requested to join this org
  def respondable_user_requests
    UserRequest.where(organisation_uri: self.uri.to_s, open: true)
  end

  def has_respondables?
    respondables.any?
  end

  def respondables
    pending_project_invites +
      pending_suggested_invites +
      pending_project_requests_by_others +
      respondable_user_requests
  end

  def as_json(options = nil)
    if options[:map_index]
      {
        guid: self.guid,
        lat: primary_site_resource.lat,
        lng: primary_site_resource.lng
      }
    elsif options[:map_show]
      {
        guid: self.guid,
        name: self.name,
        address: self.address_str,
        projects: project_resources.collect { |p| { name: p.name, guid: p.guid } }
      }
    elsif options[:map_cluster]
      {
        guid: self.guid,
        name: self.name
      }
    else
      {
        name: self.name,
        guid: self.guid,
        image_url: self.image_url,
        uri: self.uri.to_s,
        address: self.address_str
      }
    end
  end

  def image_url
    # TODO allow logo upload
    if logo_resource.present?
      logo_resource.file.url(:thumb)
    else
      "/assets/asteroids/#{rand(5)+1}_70x70.png"
    end
  end

  def self.organisations_for_map
    Tripod::SparqlClient::Query.select("
      SELECT ?org ?lat ?lng ?name WHERE {
        GRAPH <#{Digitalsocial::DATA_GRAPH}> {
          ?org a <http://www.w3.org/ns/org#Organization> .
          ?org <http://www.w3.org/ns/org#hasPrimarySite> ?site .
          ?org <http://www.w3.org/2000/01/rdf-schema#label> ?name .
          ?site <http://www.w3.org/2003/01/geo/wgs84_pos#lat> ?lat .
          ?site <http://www.w3.org/2003/01/geo/wgs84_pos#long> ?lng .
        }
      }
    ")
  end

  def self.search_by_name(search)
    name_predicate = self.fields[:name].predicate.to_s
    self.order_by_name.where("?uri <#{name_predicate}> ?name").where("FILTER regex(?name, \"\"\"#{search}\"\"\", \"i\")")
  end

  def twitter_username=(username)
    username.strip!
    username.gsub!(/^@/, "")
    self.twitter = username.present? ? "http://twitter.com/#{username}" : nil
  end

  def twitter_username
    username = self.twitter.to_s.split("/")[3] # Do cleaner way
    "@#{username}" if username.present?
  end

  def webpage_label=(domain)
    domain.strip!
    domain.gsub!(/^http:\/\//, "")
    domain.gsub!(/^https:\/\//,"")
    self.webpage = domain.present? ? "http://#{domain}" : nil
  end

  def webpage_label
    self.webpage.to_s.gsub(/^http:\/\//, "").gsub(/^https:\/\//,"") if self.webpage.present?
  end

  def users
    OrganisationMembership.all.select{ |om| om.organisation_uri == self.uri  }.map { |om| User.find(om.user_id) rescue nil }.reject { |u| u.nil? }
  end

  def add_user(user)
    OrganisationMembership.create(user: user, organisation_uri: self.uri.to_s)
  end

  def invited_users=(ary)
    @invited_users   = ary
    @invites_to_send = []

    ary.each do |n, u|
      if u[:first_name].present? || u[:email].present?
        uip = UserInvitePresenter.new
        uip.user_first_name = u[:first_name]
        uip.user_email      = u[:email]
        uip.organisation    = self

        if uip.invalid?
          @invited_users[n][:error] = uip.errors.full_messages.first
        else
          @invites_to_send << uip
        end
      end
    end
  end

  def can_send_user_invites?
    @invited_users.each { |_, u| return false if u[:error].present? }
    true
  end

  def send_user_invites
    @invites_to_send.each(&:save)
  end

  def build_user_invites
    @invited_users = {}
    50.times { |n| @invited_users[n.to_s] ||= {} }
  end

  def logo_resource
    Logo.where(organisation_uri: self.uri.to_s).first
  end

  def logo_resource=(new_logo_resource)
    new_logo = logo_resource || Logo.new(organisation_uri: self.uri.to_s)
    new_logo.file = new_logo_resource
    new_logo.save

    self.logo = new_logo.file.url
  end

  #### expose some useful data for this object, to avoid law of demeter type probs

  def address_str(connector=', ')
    self.primary_site_resource.address_resource.to_s(connector) if self.primary_site
  end

  def self.order_by_name
    name_predicate = self.fields[:name].predicate.to_s
    where("?uri <#{name_predicate}> ?name").order("lcase(str(?name))")
  end

  def pending_count
    return @pending_count if @pending_count

    @pending_count = 0
    @pending_count += 1 if !primary_site
    @pending_count += respondables.count
    @pending_count
  end

  def partner_organisations_with_count
    return @powc if @powc

    @powc = {}
    project_resources.each do |project|
      project.organisation_resources.each do |org|
        if org.guid != self.guid
          if @powc[org.guid]
            @powc[org.guid][:count] += 1
          else
            @powc[org.guid] = { name: org.name, count: 1 }
          end
        end
      end
    end

    @powc# = @powc.sort_by{ |_, v| v[:count] }.reverse
  end

  def missing_site?
    !primary_site
  end

  def destroy_solely_associated_projects
    project_resources.each do |project|
      project.destroy if project.only_organisation?(self)
    end
  end

  def destroy_project_memberships
    organisation_predicate = ProjectMembership.fields[:organisation].predicate.to_s
    ProjectMembership.where("?uri <#{organisation_predicate}> <#{self.uri}>").resources.each do |pm|
      pm.destroy
    end
  end

  def destroy_organisation_memberships
    OrganisationMembership.where(organisation_uri: self.uri.to_s).destroy_all
  end

  def only_user?(user)
    users.count == 1 && users.first == user
  end

  def unjoin(user)
    user.organisation_memberships.where(organisation_uri: self.uri.to_s).destroy_all
  end

  def child_nodes
    self.project_resources
  end

  def more_details
    hash = {
            'No of Projects' => self.project_resources.count
           }
    hash['No of Staff'] = self.fte_range_resource.label if self.fte_range.present?
    hash
  end

  def uri_slug
    Organisation.uri_to_slug self.uri
  end

  def fte_range_resource
    self.fte_range.present? ? Concepts::FTERange.find(self.fte_range) : nil
  end

  private

  def organisation_name_is_unique
    name_predicate = Organisation.fields[:name].predicate.to_s
    if Organisation.where("?uri <#{name_predicate}> \"\"\"#{name}\"\"\"").where("FILTER(?uri != <#{self.uri}>)").count > 0
      errors.add(:name, "Organisation already exists")
    end
  end

  def strip_whitespace
    self.name = self.name.strip unless self.name.nil?
  end
end
