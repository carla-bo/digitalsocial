class OrganisationsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :set_organisation
  before_filter :ensure_user_is_organisation_owner, only: [:invite_user]

  # issue a request for the current user to join the org passed in the id.
  def request_to_join
    user_request = UserRequest.build_user_request(current_user, @organisation)

    if user_request.save
      # don't need to send an email. This will just appear in the digest.
      redirect_to user_url, :notice => "You have requested to join #{@organisation.name}. Members of #{@organisation.name} have be notified and we'll let you know when your request is accepted"
    else
      error_message = user_request.errors.messages.values.join(', ')
      redirect_to user_url, :notice => "Your request failed. #{error_message}"
    end
  end

  def edit
    @organisation = current_organisation
  end

  def update
    @organisation = current_organisation

    if @organisation.update_attributes(params[:organisation])
      redirect_to :user, notice: 'Organisation details updated.'
    else
      render :edit
    end
  end

  def edit_location
    @organisation = SignupPresenter.new(current_organisation)
  end

  def update_location
    @organisation = SignupPresenter.new(current_organisation)
    @organisation.attributes = params[:signup_presenter]

    if @organisation.save
      redirect_to :user, notice: 'Organisation location updated.'
    else
      render :edit_location
    end
  end

  def invite_users
    @organisation = current_organisation
    @organisation.build_user_invites
  end

  def create_user_invites
    @organisation = current_organisation
    @organisation.invited_users = params[:invited_users]

    if @organisation.can_send_user_invites?
      @organisation.send_user_invites
      redirect_to :user, notice: "Team members invited"
    else
      render :invite_users
    end
  end

  def index
    if params[:q].present? # used for auto complete suggestions.
      @organisations = Organisation.search_by_name(params[:q]).to_a

      # current_organisations = current_user.organisation_resources
      # requested_orgs = current_user.pending_join_org_requests.map &:requestable

      # @organisations.reject!{ |o| current_organisations.map(&:uri).include?(o.uri) } # don't include ones already a member of
      # @organisations.reject!{ |o| requested_orgs.map(&:uri).include?(o.uri) } # don't include ones already requested to join
    else
      @organisations = Organisation.all.resources.to_a
    end

    respond_to do |format|
      format.json { render json: @organisations }
    end
  end

  private

  def set_organisation
    if params[:id].present?
      @organisation = Organisation.find("http://data.digitalsocial.eu/id/organization/#{params[:id]}")
    else
      @organisation = current_organisation
    end
  end

  def update_organisation
    transaction = Tripod::Persistence::Transaction.new

    @site = @organisation.primary_site_resource
    @site.lat = params[:lat]
    @site.lng = params[:lng]

    if @organisation.update_attributes(params[:organisation], transaction: transaction) && @site.save(transaction: transaction)
      transaction.commit
      true
    else
      transaction.abort
      false
    end
  end

  def ensure_user_is_organisation_owner
    redirect_to :projects unless current_organisation_membership.owner?
  end

end