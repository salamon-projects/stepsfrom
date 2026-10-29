module Admin
  class DestinationsController < BaseController
    before_action :set_destination, only: %i[edit update destroy import]

    def index
      @destinations = Destination.ordered
      @property_counts = Property.group(:destination_id).count
      @listed_counts = Property.published.group(:destination_id).count
    end

    def new
      @destination = Destination.new(zoom: 12)
    end

    def create
      @destination = Destination.new(destination_params)
      if @destination.save
        redirect_to admin_destinations_path, notice: "#{@destination.name} created. Import OSM data next."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @destination.update(destination_params)
        redirect_to admin_destinations_path, notice: "#{@destination.name} updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @destination.destroy
        redirect_to admin_destinations_path, notice: "#{@destination.name} deleted."
      else
        redirect_to admin_destinations_path, alert: @destination.errors.full_messages.to_sentence
      end
    end

    def import
      OsmImportJob.perform_later(@destination.id)
      redirect_to admin_destinations_path,
                  notice: "OSM import for #{@destination.name} queued. Properties appear in the review queue when it finishes."
    end

    private

    def set_destination
      @destination = Destination.find_by!(slug: params[:id])
    end

    def destination_params
      params.expect(destination: %i[name slug country_code sea_name summary south west north east zoom position published])
    end
  end
end
