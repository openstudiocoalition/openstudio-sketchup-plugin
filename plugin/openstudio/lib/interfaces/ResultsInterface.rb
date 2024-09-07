########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class ResultsInterface

    attr_accessor :output_file_path, :run_period, :variable_type, :rendering_appearance
    attr_accessor :match_range, :range_minimum, :range_maximum, :range_units, :normalize
    attr_accessor :outside_variable_name, :inside_variable_name, :out_of_range_value


    def initialize(model_interface)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @model_interface = model_interface
      @output_file_path = ""
      @run_period = ""
      @variable_type = "SURFACE"
      @rendering_appearance = "COLOR"
      @out_of_range_value = Float::MIN
      @normalize = false
    end

    def destroy
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @model_interface = nil
    end

    def update
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # update variables on all surfaces
      @model_interface.update_surface_variables
    end

    # attach an output file
    def attach_output_file(output_file_path)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      openstudio_model = @model_interface.openstudio_model
      old_sql_file = openstudio_model.sqlFile

      if File.exist?(output_file_path)
        begin
          new_sql_file = OpenStudio::SqlFile.new(OpenStudio::Path.new(output_file_path))
          openstudio_model.setSqlFile(new_sql_file)
        rescue
          puts "Failed to load SqlFile from path '#{output_file_path}'"
        end
      end
    end

  end
end
