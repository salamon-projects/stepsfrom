module Admin
  class DestinationsController < BaseController
    before_action :set_destination, only: %i[edit update destroy import]

    def index
      @destinations = Destination.ordered
      @property_counts = Property.group(:destination_id).count
      @listed_counts = Property.published.group(:destination_id).count
      @latest_imports = ImportRun.latest_by_destination
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
      if @destination.import_runs.active.exists?
        return redirect_to admin_destinations_path, alert: "An import for #{@destination.name} is already running."
      end

      run = @destination.import_runs.create!(source: "osm")
      OsmImportJob.perform_later(@destination.id, run.id)
      redirect_to admin_destinations_path, notice: "OSM import for #{@destination.name} started. Progress shows below."
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
