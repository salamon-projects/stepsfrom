module Admin
  class PropertiesController < BaseController
    VIEWS = {
      "review" => "To review",
      "approved" => "Approved",
      "rejected" => "Rejected",
      "excluded" => "Not waterfront",
      "conflicts" => "OTA claim conflicts",
      "mismatch" => "Position mismatch",
      "all" => "All"
    }.freeze

    before_action :set_property, only: %i[show edit update destroy approve reject reclassify]

    def index
      @view = params[:view].presence_in(VIEWS.keys) || "review"
      @destinations = Destination.ordered
      scope = scoped_by_view(Property.includes(:destination, :listings))
      scope = scope.where(destination_id: params[:destination_id]) if params[:destination_id].present?
      scope = scope.where("properties.name ILIKE ?", "%#{Property.sanitize_sql_like(params[:q])}%") if params[:q].present?
      @pagy, @properties = pagy(scope.by_waterfront, limit: 50)
      return if redirect_past_last_page(@pagy)

      @untracked_providers = Affiliate::Provider.all.values.reject(&:tracking_configured?)
    end

    def show; end

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
      @property.update!(qa_status: "approved", qa_note: params[:qa_note].presence || @property.qa_note)
      redirect_back_or_to admin_property_path(@property), notice: "#{@property.name} approved."
    end

    def reject
      @property.update!(qa_status: "rejected", qa_note: params[:qa_note].presence || @property.qa_note)
      redirect_back_or_to admin_property_path(@property), notice: "#{@property.name} rejected."
    end

    def reclassify
      Waterfront::Classification.new(@property).call
      redirect_to admin_property_path(@property),
                  notice: "Measured again: #{t("waterfront.categories.#{@property.reload.waterfront_category}")}."
    end

    private

    def set_property
      @property = Property.find_by!(slug: params[:id])
    end

    def property_params
      params.expect(property: %i[destination_id name slug kind stars address website latitude longitude qa_note])
    end

    def scoped_by_view(scope)
      case @view
      when "review" then scope.qa_pending.where(waterfront_category: Property::LISTED_CATEGORIES)
      when "approved" then scope.qa_approved
      when "rejected" then scope.qa_rejected
      when "excluded" then scope.where(waterfront_category: %w[not_waterfront unknown])
      when "conflicts" then scope.beachfront_claim_conflicts
      when "mismatch" then scope.with_coordinate_mismatch
      else scope
      end
    end
  end
end
