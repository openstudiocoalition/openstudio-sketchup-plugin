########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################


module OpenStudio

  class ProgressDialog < OpenStudio::ProgressBar

    HTML_FILE = File.join(File.dirname(__FILE__), 'html', 'ProgressDialog.html')

    # ------------------------------------------------------------------
    # Singleton dialog — created once at class load, re-used across all
    # progress calls. Not shown until the first ProgressDialog.new.
    # ------------------------------------------------------------------
    @shared_dialog  = nil
    @startup_skip   = 2  # ignore the first 2 dialogs (load model + attach model at startup)

    class << self
      attr_accessor :shared_dialog, :startup_skip

      def create_dialog(dialog_title: 'OpenStudio Progress')
        options = {
          dialog_title:,
          preferences_key: 'com.openstudiocoalition.progress',
          style:           UI::HtmlDialog::STYLE_DIALOG,
          resizable:       false,
          width:           400,
          height:          100
        }
        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(HTML_FILE)
        dialog.center

        dialog
      end


      def ensure_dialog
        @shared_dialog ||= create_dialog
      end
    end

    # Create the dialog at class load so CEF starts warming up immediately.
    ensure_dialog

    # ------------------------------------------------------------------
    # Instance — each ProgressDialog.new shows the shared dialog.
    # ------------------------------------------------------------------

    def initialize(message)
      @skip = false
      super()
      @title = message
      @min = 0
      @max = 100
      @value = 0
      @percentage = 0

      dlg = self.class.shared_dialog
      if self.class.startup_skip > 0
        self.class.startup_skip -= 1
        @skip = true
      else
        if dlg.visible?
          dlg.bring_to_front
        else
          dlg.show
        end
        dlg.execute_script("setProgress('#{escape_js(@title)}', 0)") rescue nil
      end
    end

    def minimum
      @min
    end

    def setMinimum(min)
      setRange(min, @max)
    end

    def maximum
      @max
    end

    def setMaximum(max)
      setRange(@min, max)
    end

    def value
      @value
    end

    def windowTitle
      @title
    end

    def setWindowTitle(title)
      @title = title
      onPercentageUpdated(0)
    end

    def text
      @title + " #{@percentage.round(1)}%"
    end

    def isVisible
      false
    end

    def setVisible(visible)
    end

    def escape_js(str)
      str.to_s.gsub('\\', '\\\\').gsub("'", "\\'")
    end
    private :escape_js

    def setRange(min, max)
      @min = min
      @max = max
      @percentage = 0
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
      if (new_percentage-@percentage) >= 5.0
        onPercentageUpdated(new_percentage)
      end
    end

    def onPercentageUpdated(percentage)
      super
      return if @skip

      if percentage < 0 or percentage > 100
        # Plugin.do_bug
        return
      end

      @percentage = percentage

      dlg = self.class.shared_dialog
      if dlg
        dlg.execute_script("setProgress('#{escape_js(@title)}', #{@percentage.round(1)})") rescue nil
      end
    end

    def destroy(success: true)
      return if @skip
      dlg = self.class.shared_dialog
      return unless dlg
      dlg.execute_script("setFinalCondition(#{success})") rescue nil
      # Hide: Added in Sketchup 2026.1
      if dlg.respond_to?(:hide)
        UI.start_timer(1.0, false) { dlg.hide }
      end
    end

  end

end
