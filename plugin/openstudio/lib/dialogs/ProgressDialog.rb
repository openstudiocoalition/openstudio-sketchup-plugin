########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################


module OpenStudio

  if defined?(OpenStudio::Modeleditor::OSProgressBar)
    OpenStudioProgressBarClass = OpenStudio::Modeleditor::OSProgressBar
  else
    OpenStudioProgressBarClass = OpenStudio::ProgressBar
  end

  ProgressDialog = Class.new(OpenStudio::OpenStudioProgressBarClass) do

    def initialize(message)
      super(false)
      setWindowTitle(message)
      @last_num_chars = -1
    end

    def onPercentageUpdated(percentage)
      super

      if percentage < 0 or percentage > 100
        # Plugin.do_bug
        return false
      end

      fraction = percentage / 100.0
      max_chars = 100
      num_chars = (fraction*max_chars).to_i

      if @last_num_chars != num_chars
        @last_num_chars = num_chars
        Sketchup.status_text = windowTitle + "  " + "|"*num_chars
      end

      return true
    end

    def destroy
      Sketchup.status_text = ""
      return true
    end

  end

end
