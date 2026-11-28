module Admin
  class ListingsController < BaseController
    before_action :set_property
    before_action :set_listing, only: %i[edit update destroy confirm]

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

    # Editing the URL of an automatic listing makes it the admin's, so it is
    # no longer regenerated, and confirmed (Listing#confirm_entered_listing).
    def update
      @listing.assign_attributes(listing_params)
      @listing.generator = nil if @listing.url_changed?
      if @listing.save
        redirect_to params[:return_to].presence_in([ admin_booking_links_path ]) || admin_property_path(@property),
                    notice: "#{@listing.provider_name} listing for #{@property.name} updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    # The admin opened the automatic link and it landed on this property.
    def confirm
      @listing.confirm!
      redirect_back_or_to admin_property_path(@property), notice: "#{@listing.provider_name} link for #{@property.name} confirmed."
    end

    def destroy
      if @listing.automatic?
        # Deleting it would only bring it back on the next run.
        @listing.update!(active: false)
        return redirect_to admin_property_path(@property), notice: "#{@listing.provider_name} automatic listing switched off."
      end

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
