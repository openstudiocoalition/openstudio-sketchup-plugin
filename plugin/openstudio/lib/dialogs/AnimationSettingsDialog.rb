########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/Dialogs")
require("openstudio/lib/dialogs/DialogContainers")


module OpenStudio

  class AnimationSettingsDialog < PropertiesDialog

    def initialize(container, interface, hash)
      super
      w = Plugin.platform_select(373, 430)
      h = Plugin.platform_select(369, 394)
      @container = WindowContainer.new("Animation Settings", w, h, 150, 150)
      @container.set_file(Plugin.dir + "/lib/dialogs/html/AnimationSettings.html")

      add_callbacks
    end


    def add_callbacks
      super
      @container.web_dialog.add_action_callback("on_match_time_period") { on_match_time_period }
      @container.web_dialog.add_action_callback("on_match_time_step") { on_match_time_step }
    end


    def on_load
      super

      # Manually trigger onChange for start and end months to set the day popup options
      @container.execute_function("setDateOptions()")

      # Manually set the date values
      @container.execute_function("setElementValue('START_DATE', '" + @hash['START_DATE'].to_s + "')")
      @container.execute_function("setElementValue('END_DATE', '" + @hash['END_DATE'].to_s + "')")
    end


    def on_match_time_period

      run_period = Plugin.model_manager.model_interface.openstudio_model.getRunPeriod

      @hash['START_MONTH'] = run_period.getString(1,true).to_s
      set_element_value("START_MONTH", run_period.getString(1,true).to_s)

      @hash['START_DATE'] = run_period.getString(2,true).to_s
      set_element_value("START_DATE", run_period.getString(2,true).to_s)

      @hash['START_HOUR'] = "0"
      set_element_value("START_HOUR", "0")

      @hash['END_MONTH'] = run_period.getString(3,true).to_s
      set_element_value("END_MONTH", run_period.getString(3,true).to_s)

      @hash['END_DATE'] = run_period.getString(4,true).to_s
      set_element_value("END_DATE", run_period.getString(4,true).to_s)

      @hash['END_HOUR'] = "23"
      set_element_value("END_HOUR", "23")

      report

    end


    def on_match_time_step

      # THIS IS USING WRONG IDD???
      time_step_objects = Plugin.model_manager.model_interface.openstudio_model.getObjectsByType("TimeStep".to_IddObjectType)

      if (not time_step_objects.empty?)
        time_step_per_hour = time_step_objects[0].getInt(0,true)

        if (not time_step_per_hour.empty? and time_step_per_hour.get > 0)
          time_step = (60 / time_step_per_hour.get).to_s
        else
          time_step = "60"
        end
      else
        time_step = "60"
      end

      @hash['TIME_STEP'] = time_step
      set_element_value("TIME_STEP", time_step)

      report
    end

  end

end
