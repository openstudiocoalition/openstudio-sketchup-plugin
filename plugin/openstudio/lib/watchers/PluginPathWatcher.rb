########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

# frozen_string_literal: true

module OpenStudio

  # Pure-Ruby file watcher. Polls the watched file's mtime every POLL_INTERVAL
  # seconds using SketchUp's UI.start_timer, replacing the C++ Qt-backed
  # OpenStudio::Modeleditor::PathWatcher / OpenStudio::PathWatcher.
  #
  # Public API (matches the C++ PathWatcher interface used by ModelInterface):
  #   initialize(model_interface, path)  – path is an OpenStudio::Path
  #   enable                             – start polling
  #   disable                            – stop polling
  #   clearState                         – re-baseline mtime; suppress false positives
  #   path                               – returns the OpenStudio::Path
  #   onPathChanged                      – called internally when a change is detected
  #
  class PluginPathWatcher

    # Seconds between mtime polls. 1 s gives responsive detection without
    # hammering the filesystem.
    POLL_INTERVAL = 1.0

    def initialize(model_interface, path)
      @model_interface = model_interface
      @path     = path          # OpenStudio::Path – kept for API compatibility
      @path_str = path.to_s    # plain String for File.* calls

      @enabled  = false
      @changed  = false
      @timer_id = nil

      # Establish a clean mtime baseline so the first poll never fires spuriously.
      @last_mtime = mtime_now

      enable
    end

    # Return the watched path (OpenStudio::Path).
    # Callers use path.to_s, matching the C++ PathWatcher#path contract.
    def path
      @path
    end

    # Start polling the file for changes.
    def enable
      return if @enabled
      @enabled  = true
      @timer_id = UI.start_timer(POLL_INTERVAL, true) { check_path }
    end

    # Stop polling.
    def disable
      @enabled = false
      if @timer_id
        UI.stop_timer(@timer_id)
        @timer_id = nil
      end
    end

    # Reset the dirty flag and re-baseline the mtime.
    # Called by ModelInterface#export_openstudio after it writes the file so
    # that our next poll does not trigger a false-positive reload dialog.
    def clearState
      @changed    = false
      @last_mtime = mtime_now
    end

    # ------------------------------------------------------------------
    # Change handler – ported from the original PluginPathWatcher subclass
    # ------------------------------------------------------------------

    def onPathChanged
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # Ignore any further signals until we finish processing
      disable

      skp_model = @model_interface.skp_model

      if !skp_model.valid?

        Plugin.log(OpenStudio::Debug, "skp_model #{skp_model} is not valid, active model is #{Sketchup.active_model}")

        # skp_model is no longer valid (e.g. closed on Mac)
        proc = Proc.new { Plugin.model_manager.purge_invalid_model_interfaces }
        Plugin.add_event(proc)

        # continue ignoring; new model will have its own watcher

      elsif skp_model != Sketchup.active_model

        Plugin.log(OpenStudio::Debug, "skp_model #{skp_model} is not active_model, active model is #{Sketchup.active_model}")

        # no-op to avoid a crash when updating a model that is not active
        enable

      else

        success = false
        result  = UI.messagebox(
          "Another application has updated #{self.path.to_s}, do you want to reload it?",
          MB_YESNO
        )
        if result == 6  # Yes
          success = Plugin.model_manager.open_openstudio(self.path.to_s, Sketchup.active_model)
        end

        if success
          # continue ignoring; the newly opened model creates a fresh watcher
        else
          enable
        end

      end
    end

    private

    # Poll: compare current mtime against baseline; fire onPathChanged if different.
    def check_path
      return unless @enabled
      return if @changed  # already notified; wait for clearState

      current = mtime_now
      return if current.nil?  # file does not exist yet

      if @last_mtime.nil? || current != @last_mtime
        @changed    = true
        @last_mtime = current
        onPathChanged
      end
    rescue => e
      Plugin.log(OpenStudio::Error, "PluginPathWatcher#check_path: #{e.message}")
    end

    def mtime_now
      File.exist?(@path_str) ? File.mtime(@path_str) : nil
    rescue => e
      Plugin.log(OpenStudio::Error, "PluginPathWatcher#mtime_now: #{e.message}")
      nil
    end

  end  # class PluginPathWatcher

end  # module OpenStudio
