class Project

  include Tripod::Resource
  include ConceptFields

  rdf_type 'http://data.digitalsocial.eu/def/ontology/Activity'
  graph_uri 'http://data.digitalsoclal.eu/graph/data'

  field :name, 'http://www.w3.org/2000/01/rdf-schema#label'
  field :webpage, 'http://xmlns.com/foaf/0.1/page', is_uri: true

  field :duration, 'http://purl.org/NET/c4dm/event.owl#time'
  field :creator, 'http://data.digitalsocial.eu/def/ontology/recordedBy', is_uri: true

  concept_field :activity_type, 'http://data.digitalsocial.eu/def/ontology/activityType', Concepts::ActivityType
  concept_field :areas_of_society, 'http://data.digitalsocial.eu/def/ontology/areaOfSociety', Concepts::AreaOfSociety, multivalued: true
  concept_field :technology_focus, 'http://data.digitalsocial.eu/def/ontology/technologyFocus', Concepts::TechnologyFocus, multivalued: true
  concept_field :technology_method, 'http://data.digitalsocial.eu/def/ontology/technologyMethod', Concepts::TechnologyMethod, multivalued: true

  attr_accessor :start_date, :end_date, :scoped_organisation

  validates :name, :activity_type, presence: true
  validates :organisation_natures, presence: { if: :new_record? }

  # override initialise
  def initialize(uri=nil, graph_uri=nil)
    super(uri || "http://data.digitalsocial.eu/id/activity/#{Guid.new}")
  end

  def guid
    self.uri.to_s.split("/").last
  end

  def to_param
    guid
  end

  def create_time_interval!
    new_time_interval = TimeInterval.new
    new_time_interval.start_date = start_date
    new_time_interval.end_date   = end_date
    new_time_interval.save

    self.duration = new_time_interval.uri.to_s
    save
  end

  def duration_resource
    TimeInterval.find(self.duration)
  end

  # def start_date
  #   duration_resource.start_date if duration.present?
  # end

  # def end_date
  #   duration_resource.end_date if duration.present?
  # end

  def creator_resource
    Organisation.find(self.creator)
  end

  def add_creator_memberships!
    creator_natures.reject(&:blank?).each do |nature|
      creator_membership = ProjectMembership.new
      creator_membership.project      = self.uri.to_s
      creator_membership.organisation = self.creator_resource.uri.to_s
      creator_membership.nature       = nature
      creator_membership.save

      self.save
    end
  end

  def organisation_natures
    return unless scoped_organisation.present?

    scoped_project_membership_resources.collect { |pm| pm.nature.to_s }
  end

  def scoped_project_membership_resources
    return unless scoped_organisation.present?

    scoped_organisation.project_memberships_for_project(self).resources
  end

  def organisation_natures=(natures)
    scoped_project_membership_resources.each(&:destroy)

    natures.reject(&:blank?).each do |nature|
      pm = ProjectMembership.new
      pm.project      = self.uri.to_s
      pm.organisation = self.creator_resource.uri.to_s
      pm.nature       = nature
      pm.save

      self.save
    end
  end

  def organisations
    project_membership_project_predicate = ProjectMembership.fields[:project].predicate.to_s
    project_membership_org_predicate = ProjectMembership.fields[:organisation].predicate.to_s
    Organisation
      .where("?pm_uri <#{project_membership_project_predicate}> <#{self.uri}>")
      .where("?pm_uri <#{project_membership_org_predicate}> ?uri")
  end

  def organisation_resources
    organisations.resources
  end

  def any_organisations?
    organisations.count > 0
  end

  def image_url
    # TODO use a relevant image for project avatar
    "/assets/asteroids/#{rand(5)+1}_70x70.png"
  end

  def organisation_names
    organisation_resources.collect(&:name).join(", ")
  end

  def as_json(options = nil)
    json = {
      name: self.name,
      guid: self.guid,
      image_url: self.image_url,
      organisation_names: self.organisation_names
    }
    json
  end

  def self.search_by_name(search)
    name_predicate = self.fields[:name].predicate.to_s
    self.where("?uri <#{name_predicate}> ?name").where("FILTER regex(?name, \"#{search}\", \"i\")").resources
  end

  def activity_type_label_other=(other)
    self.activity_type_label = other if other.present?
  end

  def activity_type_label_other
    if activity_type_resource.present? && !activity_type_resource.top_level?
      self.activity_type_label
    end
  end

  def activity_type_resource
    Concepts::ActivityType.find(self.activity_type) if self.activity_type.present?
  end

end