module Admin
  class ListingsController < BaseController
    before_action :set_property
    before_action :set_listing, only: %i[edit update destroy]

    def new
      @listing = @property.listings.build(provider: (Affiliate::Provider.keys - @property.listings.map(&:provider)).first)
    end

    def create
      @listing = @property.listings.build(listing_params)
      if @listing.save
        redirect_to admin_property_path(@property), notice: "#{@listing.provider_name} listing added."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @listing.update(listing_params)
        redirect_to admin_property_path(@property), notice: "#{@listing.provider_name} listing updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @listing.destroy!
      redirect_to admin_property_path(@property), notice: "#{@listing.provider_name} listing removed."
    end

    private

    def set_property
      @property = Property.find_by!(slug: params[:property_id])
    end

    def set_listing
      @listing = @property.listings.find(params[:id])
    end

    def listing_params
      permitted = params.expect(listing: %i[provider url external_id reported_latitude reported_longitude claims_beachfront active])
      permitted[:claims_beachfront] = nil if permitted[:claims_beachfront] == ""
      permitted
    end
  end
end
