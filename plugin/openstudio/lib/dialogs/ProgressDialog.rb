########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################


module OpenStudio

  class ProgressDialog < OpenStudio::ProgressBar

    attr_reader :title, :min, :max, :value, :percentage, :dialog

    HTML_FILE = File.join(File.dirname(__FILE__), 'html', 'ProgressDialog.html')

    # ------------------------------------------------------------------
    # Singleton dialog — created once at class load, re-used across all
    # progress calls. Not shown until the first ProgressDialog.new.
    # ------------------------------------------------------------------
    @shared_dialog  = nil
    @startup_skip   = 2  # ignore the first 2 dialogs (load model + attach model at startup)

    class << self
      attr_accessor :shared_dialog, :startup_skip

      # Close the previous dialog if it exists, then create a new one.
      def create_dialog(dialog_title: 'OpenStudio Progress')
        @shared_dialog&.close

        options = {
          dialog_title:,
          preferences_key: 'com.openstudiocoalition.progressdlg5', # TODO: I need to find where to delete the stored value...
          style:           UI::HtmlDialog::STYLE_DIALOG,
          resizable:       false,
          width:           400,
          height:          150,
        }
        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(HTML_FILE)
        dialog.center
        dialog.add_action_callback('closeProgressDialog') do |_ctx|
          # dialog.hide if dialog.respond_to?(:hide)
          dialog.close
        end

        @shared_dialog = dialog

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
      @ready = false
      @pending_scripts = []
      super()
      @title = message
      @min = 0
      @max = 100
      @value = 0
      @percentage = 0
      @dialog = nil

      if self.class.startup_skip > 0
        self.class.startup_skip -= 1
        @skip = true
      else
        @dialog = self.class.create_dialog(dialog_title: message)
        @dialog.add_action_callback('dialogReady') do |_ctx|
          @ready = true
          @pending_scripts.each { |script| @dialog.execute_script(script) rescue nil }
          @pending_scripts.clear
        end
        @dialog.show
        setWindowTitle(message)
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
      return if @skip
      exec_script("setTitle('#{escape_js(@title)}')")
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

    def exec_script(code)
      return unless @dialog
      if @ready
        @dialog.execute_script(code) rescue nil
      else
        @pending_scripts << code
      end
    end
    private :exec_script

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

      exec_script("setProgress(#{@percentage.round(1)})")
    end

    def destroy(success: true)
      return if @skip
      return unless @dialog
      dialog = @dialog
      UI.start_timer(0.1, false) { dialog.execute_script("setFinalCondition(#{success})") rescue nil }
    end

  end

end
