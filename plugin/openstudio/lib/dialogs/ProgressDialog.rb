########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################


module OpenStudio

  class ProgressDialog < OpenStudio::ProgressBar

    def initialize(message)
      super()
      @title = message
      @min = 0
      @max = 100
      @value = 0
      @percentage = 0
      @last_num_chars = -1
    end

    def minimum
      @min
    end

    def setMinimum(min)
      @min = min
      updatePercentage
    end

    def maximum
      @max
    end

    def setMaximum(max)
      @max = max
      updatePercentage
    end

    def value
      @value
    end

    def windowTitle
      @title
    end

    def setWindowTitle(title)
      @title = title
    end

    def text
      "#{@value}%"
    end

    def isVisible
      false
    end

    def setVisible(visible)
    end

    def setRange(min, max)
      @min = min
      @max = max
      updatePercentage
    end

    def setValue(val)
      @value = val
      updatePercentage
    end

    def updatePercentage
      range = @max - @min
      new_percentage = 0.0
      if (range > 0.0)
        new_percentage = 100.0 * (@value - @min) / range
      end
      if (new_percentage-@percentage) >= 1.0
        onPercentageUpdated(new_percentage)
      end
    end

    def onPercentageUpdated(percentage)
      super

      if percentage < 0 or percentage > 100
        # Plugin.do_bug
        return
      end

      @percentage = percentage

      num_chars = ((percentage / 100.0) * 100).to_i
      if @last_num_chars != num_chars
        @last_num_chars = num_chars
        Sketchup.status_text = @title + "  " + "|" * num_chars
        #Sketchup.active_model.active_view.invalidate_view
      end
    end

    def destroy
      Sketchup.status_text = ""
    end

  end

end
