module Admin
  class PropertiesController < BaseController
    VIEWS = {
      "review" => "To review",
      "approved" => "Approved",
      "rejected" => "Rejected",
      "excluded" => "Not waterfront",
      "conflicts" => "OTA claim conflicts",
      "mismatch" => "Position mismatch",
      "missing" => "Not in OSM",
      "all" => "All"
    }.freeze

    before_action :set_property, only: %i[show edit update destroy approve reject reclassify]

    def index
      @view = params[:view].presence_in(VIEWS.keys) || "review"
      @destinations = Destination.ordered
      # Remembered so a property page can step through this list.
      session[:admin_property_list] = { "view" => @view, "destination_id" => params[:destination_id].presence,
                                        "q" => params[:q].presence }.compact
      scope = list_scope(session[:admin_property_list]).preload(:destination, :listings, :waterfront)
      @pagy, @properties = pagy(scope.by_waterfront, limit: 50)
      return if redirect_past_last_page(@pagy)

      @untracked_providers = Affiliate::Provider.all.values.reject(&:tracking_configured?)
    end

    def show
      @list = session[:admin_property_list].presence || { "view" => "all" }
      @list_nav = @property.neighbors_in(list_scope(@list))
    end

    def new
      @property = Property.new(destination_id: params[:destination_id], kind: "hotel")
    end

    def create
      @property = Property.new(property_params)
      if @property.save
        Waterfront::Classification.new(@property).call
        redirect_to admin_property_path(@property), notice: "Property created and measured."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @property.update(property_params)
        Waterfront::Classification.new(@property).call if @property.saved_change_to_lonlat?
        redirect_to admin_property_path(@property), notice: "Property updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @property.destroy!
      redirect_to admin_properties_path, notice: "#{@property.name} deleted."
    end

    def approve
      review("approved")
    end

    def reject
      review("rejected")
    end

    def reclassify
      Waterfront::Classification.new(@property).call
      redirect_to admin_property_path(@property),
                  notice: "Measured again: #{t("waterfront.categories.#{@property.reload.waterfront.category}")}."
    end

    private

    def set_property
      @property = Property.find_by!(slug: params[:id])
    end

    def property_params
      params.expect(property: %i[destination_id name slug kind stars address website latitude longitude])
    end

    # Approves or rejects the waterfront result, with an optional note.
    def review(status)
      verification = @property.waterfront
      unless verification
        return redirect_to admin_property_path(@property), alert: "#{@property.name} has not been measured yet."
      end

      verification.update!(qa_status: status, qa_note: params[:qa_note].presence || verification.qa_note)
      redirect_back_or_to admin_property_path(@property), notice: "#{@property.name} #{status}."
    end

    # The properties of an index view with its filters, unordered.
    def list_scope(list)
      scope = scoped_by_view(Property.left_joins(:waterfront), list["view"])
      scope = scope.where(destination_id: list["destination_id"]) if list["destination_id"].present?
      scope = scope.where("properties.name ILIKE ?", "%#{Property.sanitize_sql_like(list['q'])}%") if list["q"].present?
      scope
    end

    def scoped_by_view(scope, view)
      case view
      when "review"
        scope.where(verifications: { qa_status: "pending", category: Verifications::Waterfront::LISTED_CATEGORIES })
      when "approved" then scope.where(verifications: { qa_status: "approved" })
      when "rejected" then scope.where(verifications: { qa_status: "rejected" })
      when "excluded"
        scope.where(verifications: { category: %w[not_waterfront unknown] }).or(scope.where(verifications: { id: nil }))
      when "conflicts" then scope.beachfront_claim_conflicts
      when "mismatch" then scope.with_coordinate_mismatch
      when "missing" then scope.missing_from_osm
      else scope
      end
    end
  end
end
