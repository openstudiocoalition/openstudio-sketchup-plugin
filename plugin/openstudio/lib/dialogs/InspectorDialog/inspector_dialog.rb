# frozen_string_literal: true

# OpenStudio InspectorDialog – SketchUp WebDialog implementation
# Ported from C++ InspectorDialog / InspectorGadget / AccessPolicyStore
#
# Architecture:
#   - Ruby backend: queries the OpenStudio model, enforces AccessPolicy, handles CRUD
#   - HTML/Vue.js frontend: renders the three-panel inspector UI
#   - Communication: SketchUp WebDialog API (sketchup.* JS → Ruby callbacks, execute_script Ruby→JS)

require 'sketchup.rb'
require 'json'
require 'rexml/document'
require 'set'
require_relative 'access_policy_store'

# Note: OpenStudio Ruby Optional types use `empty?`/`get`, NOT `is_initialized`/`get`.
# the exception is `empty`/`get` for `OpenStudio::OptionalQuantity`, patch that here
if not OpenStudio::OSOptionalQuantity.public_method_defined?(:empty?)
  OpenStudio::OSOptionalQuantity.alias_method :empty?, :empty
end


module OpenStudio

  # ---------------------------------------------------------------------------
  # InspectorObjectWatcher
  # Watches a single WorkspaceObject and calls back when it changes or is removed.
  # Must live in the OpenStudio module (not a sub-module) so that SWIG can
  # resolve the type against openstudio::WorkspaceObjectWatcher correctly.
  # ---------------------------------------------------------------------------
  class InspectorObjectWatcher < WorkspaceObjectWatcher
    def initialize(idf_object, change_proc, remove_proc)
      super(idf_object)
      @change_proc = change_proc
      @remove_proc = remove_proc
    end

    def onChangeIdfObject
      super()
      @change_proc.call()
    end

    def onRemoveFromWorkspace(handle)
      super(handle)
      @remove_proc.call(handle)
    end
  end

  # ---------------------------------------------------------------------------
  # InspectorModelWatcher
  # Watches the whole model (WorkspaceWatcher) for object additions/removals.
  # Must live in the OpenStudio module so SWIG resolves it against
  # openstudio::WorkspaceWatcher correctly.
  # onChangeWorkspace is overridden to accept (and ignore) the watcher argument
  # that C++ passes during workspace-mutating calls like setVertices, preventing
  # the SWIG type-mismatch error that occurs if the C++ default dispatch fires.
  # ---------------------------------------------------------------------------
  class InspectorModelWatcher < WorkspaceWatcher
    def initialize(model, add_proc, remove_proc)
      super(model)
      @add_proc    = add_proc
      @remove_proc = remove_proc
    end

    def onChangeWorkspace
      super()
    end

    def onObjectAdd(object)
      super(object)
      @add_proc.call(object)
    end

    def onObjectRemove(object)
      super(object)
      @remove_proc.call(object)
    end
  end

  module Inspector

    # -------------------------------------------------------------------------
    # InspectorDialog main class
    # -------------------------------------------------------------------------
    class InspectorDialog

      # ------------------------------------------------------------------
      # Configuration – ported from InspectorDialog::init(SketchUpPlugin)
      # ------------------------------------------------------------------

      TYPES_TO_DISPLAY = %w[
        OS_Building
        OS_BuildingStory
        OS_BuildingUnit
        OS_Daylighting_Control
        OS_DefaultConstructionSet
        OS_DefaultScheduleSet
        OS_DefaultSubSurfaceConstructions
        OS_DefaultSurfaceConstructions
        OS_Facility
        OS_Glare_Sensor
        OS_IlluminanceMap
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_Luminaire
        OS_Rendering_Color
        OS_ShadingControl
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_SpaceType
        OS_SubSurface
        OS_Surface
        OS_ThermalZone
        OS_WindowProperty_FrameAndDivider
      ].freeze unless const_defined?(:TYPES_TO_DISPLAY)

      DISABLE_ADD = %w[
        OS_Building
        OS_Daylighting_Control
        OS_Facility
        OS_Glare_Sensor
        OS_IlluminanceMap
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_Luminaire
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_SubSurface
        OS_Surface
      ].freeze unless const_defined?(:DISABLE_ADD)

      DISABLE_COPY = %w[
        OS_Building
        OS_Daylighting_Control
        OS_Facility
        OS_Glare_Sensor
        OS_IlluminanceMap
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_Luminaire
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_SubSurface
        OS_Surface
        OS_ThermalZone
      ].freeze unless const_defined?(:DISABLE_COPY)

      DISABLE_REMOVE = %w[
        OS_Building
        OS_Daylighting_Control
        OS_Facility
        OS_Glare_Sensor
        OS_IlluminanceMap
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_Luminaire
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_SubSurface
        OS_Surface
      ].freeze unless const_defined?(:DISABLE_REMOVE)

      # Resource objects that support purge
      ENABLE_PURGE = %w[
        OS_DefaultConstructionSet
        OS_DefaultScheduleSet
        OS_DefaultSubSurfaceConstructions
        OS_DefaultSurfaceConstructions
        OS_Rendering_Color
        OS_ShadingControl
        OS_SpaceType
        OS_WindowProperty_FrameAndDivider
      ].freeze unless const_defined?(:ENABLE_PURGE)

      # Object types that display additionalProperties in the inspector
      DISPLAY_ADDITIONAL_PROPERTIES = %w[
        OS_Building
        OS_SpaceType
      ].freeze unless const_defined?(:DISPLAY_ADDITIONAL_PROPERTIES)

      # Object types that allow adding a new additionalProperty
      ADD_ADDITIONAL_PROPERTIES = %w[
        OS_Building
        OS_SpaceType
      ].freeze unless const_defined?(:ADD_ADDITIONAL_PROPERTIES)

      # Object types that allow removing an additionalProperty
      REMOVE_ADDITIONAL_PROPERTIES = %w[
        OS_Building
        OS_SpaceType
      ].freeze unless const_defined?(:REMOVE_ADDITIONAL_PROPERTIES)

      # Preferences key used for save_state / restore_state
      PREFS_KEY = 'OpenStudio.InspectorDialog'.freeze unless const_defined?(:PREFS_KEY)

      # ------------------------------------------------------------------
      # Instance initialization
      # ------------------------------------------------------------------

      def initialize
        @dialog              = nil
        @unit_system         = :ip  # :si or :ip
        @current_type        = nil
        @current_handle      = nil
        @current_object      = nil
        @current_object_name = nil
        @enabled             = true
        @model               = nil
        @object_watcher      = nil
        @model_watcher       = nil
        @update_name         = false
        @refresh_timer       = nil

        @access_policy_store = AccessPolicyStore.new
        @access_policy_store.load_policy
      end

      # ------------------------------------------------------------------
      # Dialog lifecycle
      # ------------------------------------------------------------------
      def reset_model
        @model = get_model
        @model_watcher&.disable
        @model_watcher = nil
        @model_watcher = InspectorModelWatcher.new(@model, self.method(:object_added), self.method(:object_removed)) if @model
      end

      def reset_current_object
        @object_watcher&.disable
        @object_watcher = nil
        @current_handle = nil
        @current_object = nil
        @current_object_name = nil
        @update_name = false
        UI.stop_timer(@refresh_timer) if @refresh_timer
        @refresh_timer = nil
      end

      def set_current_object(obj)
        @object_watcher&.disable
        @object_watcher = nil
        @object_watcher = InspectorObjectWatcher.new(obj, self.method(:refresh_fields), self.method(:current_object_removed))
        @current_handle = obj.handle
        @current_object = obj
        @current_object_name = obj.nameString
        @update_name = false
        UI.stop_timer(@refresh_timer) if @refresh_timer
        @refresh_timer = nil        
      end

      def create_dialog
        reset_model
        reset_current_object

        html_file = File.join(File.dirname(__FILE__), 'html', 'inspector_dialog.html')
        options = {
          dialog_title:    'OpenStudio Inspector',
          preferences_key: 'com.openstudiocoalition.inspector',
          style:           UI::HtmlDialog::STYLE_DIALOG,
          resizable:       true,
          width:           900,
          height:          650,
          min_width:       700,
          min_height:      500
        }
        result = UI::HtmlDialog.new(options)
        result.set_file(html_file)
        result.center

        result.add_action_callback('ready') do |_ctx|
          #puts "ready callback"
          send_initial_data
          nil
        end

        result.add_action_callback('set_type') do |_ctx, type_str|
          #puts "set_type callback"
          @current_type = type_str
          reset_current_object
          send_objects_for_type(type_str)
          nil
        end

        result.add_action_callback('set_object') do |_ctx, handle_str|
          #puts "set_object callback"
          obj = @model.getObject(OpenStudio::toUUID(handle_str))
          unless obj.empty?
            set_current_object(obj.get)
            send_fields_for_current_object
            # Sync SketchUp model selection to match the inspector selection
            select_drawing_interfaces([@current_handle]) unless @current_handle.isNull
          end
          nil
        end

        result.add_action_callback('update_field') do |_ctx, data|
          #puts "update_field callback"
          begin
            payload = JSON.parse(data)
            update_field(payload['handle'], payload['index'], payload['value'])
          rescue => e
            puts "Inspector update_field error: #{e.message}"
          end
          nil
        end

        result.add_action_callback('add_object') do |_ctx, type_str|
          #puts "add_object callback"
          add_object(type_str)
          nil
        end

        result.add_action_callback('copy_object') do |_ctx, handle_str|
          #puts "copy_object callback"
          copy_object(handle_str)
          nil
        end

        result.add_action_callback('delete_object') do |_ctx, handle_str|
          #puts "delete_object callback"
          delete_object(handle_str)
          nil
        end

        result.add_action_callback('purge_objects') do |_ctx, type_str|
          #puts "purge_objects callback"
          purge_objects(type_str)
          nil
        end

        result.set_on_closed  do
          #puts "set_on_closed callback"
          @dialog = nil
          reset_model
          reset_current_object
          nil
        end

        result
      end

      def set_unit_system(system)
        @unit_system = system == 'SI' ? :si : :ip
        refresh_fields if @current_handle && !@current_handle.isNull
      end

      def show
        @dialog ||= create_dialog
        @dialog.show
      end

      # Called by DialogManager to hide the dialog
      def hide
        @dialog&.close
        @dialog = nil
      end

      # Called by DialogManager to test if the dialog is visible
      def is_visible
        @dialog ? @dialog.visible? : false
      end

      # Called by DialogManager to enable the dialog.
      # Returns true if the dialog was previously disabled.
      def enable
        was_disabled = !@enabled
        @enabled = true
        was_disabled
      end

      # Called by DialogManager to disable the dialog.
      # Returns true if the dialog was previously enabled.
      def disable
        was_enabled = @enabled
        @enabled = false
        was_enabled
      end

      # Called by DialogManager to check if the dialog is enabled.
      def is_enabled
        @enabled
      end

      # Called by DialogManager to save the state of the dialog.
      def save_state
        Sketchup.write_default(PREFS_KEY, 'UnitSystem', @unit_system.to_s)
        Sketchup.write_default(PREFS_KEY, 'CurrentType', @current_type.to_s)
      rescue => e
        puts "Inspector: save_state error: #{e.message}"
      end

      # Called by DialogManager to restore the state of the dialog.
      def restore_state
        unit_str = Sketchup.read_default(PREFS_KEY, 'UnitSystem', 'ip')
        @unit_system = unit_str == 'si' ? :si : :ip

        saved_type = Sketchup.read_default(PREFS_KEY, 'CurrentType', '')
        if saved_type && !saved_type.empty? && TYPES_TO_DISPLAY.include?(saved_type)
          @current_type = saved_type
        end
      rescue => e
        puts "Inspector: restore_state error: #{e.message}"
      end

      # ------------------------------------------------------------------
      # Interaction with SketchUp
      # ------------------------------------------------------------------

      # When selecting objects in the inspector, call this method so that
      # the objects are also selected in the SketchUp model.
      def select_drawing_interfaces(handles)
        model_interface = Plugin.model_manager.model_interface
        if model_interface
          had_observers = model_interface.selection_interface.remove_observers
          model_interface.selection_interface.select_drawing_interfaces(handles)
          model_interface.selection_interface.add_observers if had_observers
        end
      rescue => e
        puts "Inspector: select_drawing_interfaces error: #{e.message}"
      end

      # Called by DialogManager when the OpenStudio model is updated.
      def update
        return unless @dialog && is_visible
        #puts "update"
        send_objects_for_type(@current_type) if @current_type
        # Note: do NOT call refresh_fields here. The InspectorObjectWatcher fires
        # independently when the current object changes, and send_objects_for_type
        # already calls send_fields_for_current_object via its auto-selection path.
        # Calling refresh_fields here would cause a double (or triple) refresh on
        # every field write.
      end

      # Called when a new OpenStudio model is attached (model load, import, new).
      # Re-wires the model watcher and refreshes all dialog panels.
      def on_model_attached
        reset_model
        reset_current_object
        return unless @dialog
        send_initial_data
      end

      # Called by DialogManager when the SketchUp selection changes.
      # Navigates the type panel to the IDD object type of the selected object.
      def set_idd_object_type(idd_object_type)
        return unless @dialog && is_visible
        # IddObjectType#valueDescription returns colon-style ("OS:SubSurface");
        # our TYPES_TO_DISPLAY uses underscore-style ("OS_SubSurface").
        type_str = idd_object_type.valueDescription.tr(':', '_')
        return unless TYPES_TO_DISPLAY.include?(type_str)
        return if type_str == @current_type

        @current_type = type_str
        reset_current_object
        send_objects_for_type(@current_type)
        safe_execute("selectType(#{JSON.generate(@current_type)})")
      rescue => e
        puts "Inspector: set_idd_object_type error: #{e.message}"
      end

      # Called by DialogManager when the SketchUp selection changes.
      # Selects the corresponding object row in the object panel.
      # handles may be an empty collection when there is no selection.
      def set_selected_object_handles(handles)
        return unless @dialog && is_visible

        handle_arr = handles.to_a
        if handle_arr.empty?
          reset_current_object
          safe_execute("setFields(null)")
          safe_execute("selectObject(null)")
          return
        end

        # Single-selection only (matching C++ behaviour)
        # handles may contain OpenStudio::UUID objects or plain strings — normalise to UUID.
        raw = handle_arr.first
        uuid = raw.is_a?(OpenStudio::UUID) ? raw : OpenStudio::toUUID(raw)
        obj = @model.getObject(uuid)
        unless obj.empty?
          set_current_object(obj.get)
          safe_execute("selectObject(#{JSON.generate(@current_handle.to_s)})")
          send_fields_for_current_object
        end
      rescue => e
        puts "Inspector: set_selected_object_handles error: #{e.message}"
      end

      # ------------------------------------------------------------------
      # Data senders (Ruby → JavaScript via execute_script)
      # ------------------------------------------------------------------

      def send_initial_data
        # Build the IDD-grouped type list with live object counts.
        # IddFactory always returns a valid IddFile for the OpenStudio IDD.
        grouped_types = build_grouped_types

        safe_execute("setTypes(#{JSON.generate(grouped_types)})")

        # Send unit system
        safe_execute("setUnitSystem(#{JSON.generate(@unit_system)})")

        # Pre-select first type (or restored type)
        first_type = @current_type || TYPES_TO_DISPLAY.first
        @current_type = first_type
        send_objects_for_type(first_type)
      end

      # Build the type list grouped by IDD group, with object counts.
      # Returns an array of group objects, each with a :children array of type entries.
      # Port of C++ loadListWidgetData.
      def build_grouped_types
        return [] unless @model

        idd_file = OpenStudio::IddFactory::instance.getIddFile(
          OpenStudio::IddFileType.new('OpenStudio')
        )

        # Build a set of underscore-style keys for fast lookup
        display_set = TYPES_TO_DISPLAY.to_set

        result = []

        idd_file.groups.each do |group_name|
          # Collect displayable objects in this group as children
          children = []
          idd_file.getObjectsInGroup(group_name).each do |idd_obj|
            # IDD type is colon-style; convert to underscore for TYPES_TO_DISPLAY lookup
            type_key = idd_obj.type.valueDescription.tr(':', '_')
            next unless display_set.include?(type_key)

            count = @model.numObjectsOfType(idd_obj.type)

            label = type_key.gsub(/^OS_/, '').gsub('_', ' ')
            children << {
              key:      type_key,
              label:    label,
              count:    count,
              is_group: false
            }
          end

          next if children.empty?

          # Group header with nested children – allows collapsible UI
          result << { label: group_name, is_group: true, children: children }
        end

        result
      rescue => e
        puts "Inspector: build_grouped_types error: #{e.message}"
        # Fallback: single group containing all types without counts
        children = TYPES_TO_DISPLAY.map do |t|
          { key: t, label: t.gsub(/^OS_/, '').gsub('_', ' '), count: 0, is_group: false }
        end
        [{ label: 'All Types', is_group: true, children: children }]
      end

      def send_objects_for_type(type_str)
        return unless @dialog
        objects = get_objects_for_type(type_str)

        # Determine unique/required from IDD (mirrors C++ InspectorDialog lines 223-243)
        is_unique   = false
        is_required = false
        begin
          idd_obj     = OpenStudio::IddFactory::instance.getObject(OpenStudio::IddObjectType.new(type_str))
          unless idd_obj.empty?
            props       = idd_obj.get.properties
            is_unique   = props.unique
            is_required = props.required
          end
        rescue => e
          puts "Inspector: IDD lookup error for #{type_str}: #{e.message}"
        end

        # Button enable/disable logic (mirrors C++)
        enable_add    = !DISABLE_ADD.include?(type_str)
        enable_copy   = !DISABLE_COPY.include?(type_str)
        enable_remove = !DISABLE_REMOVE.include?(type_str)
        enable_purge  = ENABLE_PURGE.include?(type_str)

        if is_unique
          enable_copy  = false
          enable_purge = false
          if objects.empty?
            enable_remove = false
          else
            enable_add = false
            enable_remove = false if is_required
          end
        else
          # non-unique: copy/remove also require a current selection
          if @current_handle.nil?
            enable_copy   = false
            enable_remove = false
          end
        end

        # Disable purge when there is nothing to purge
        enable_purge = false if enable_purge && objects.empty?

        button_state = {
          enable_add:    enable_add,
          enable_copy:   enable_copy,
          enable_remove: enable_remove,
          enable_purge:  enable_purge
        }

        # Include updated count so the type list badge stays current
        count = @model ? begin
          idd_type = OpenStudio::IddObjectType.new(type_str)
          @model.numObjectsOfType(idd_type)
        rescue
          objects.size
        end : objects.size

        payload = { objects: objects, buttons: button_state, type: type_str, count: count, unique: is_unique }
        safe_execute("setObjects(#{JSON.generate(payload)})")

        # Auto-select: preserve current selection if it exists in this type's list,
        # otherwise fall back to the first object.
        if objects.size > 0
          current_still_valid = @current_handle && objects.any? { |o| o[:handle] == @current_handle.to_s }
          unless current_still_valid
            obj = @model.getObject(OpenStudio::toUUID(objects.first[:handle]))
            unless obj.empty?
              set_current_object(obj.get)
              # Re-enable copy/remove now that we have a confirmed selection
              button_state[:enable_copy]   = !DISABLE_COPY.include?(type_str)
              button_state[:enable_remove] = !DISABLE_REMOVE.include?(type_str)
              safe_execute("updateButtons(#{JSON.generate(button_state)})")
              safe_execute("selectObject(#{JSON.generate(@current_handle.to_s)})")
              send_fields_for_current_object
            end
          end
        else
          # Clear the fields panel when no auto-selection is possible
          reset_current_object
          safe_execute("setFields(null)")
        end
      end

      def send_fields_for_current_object
        return unless @dialog
        fields = get_fields_for_current_object
        if fields
          safe_execute("setFields(#{JSON.generate(fields)})")
        else
          safe_execute("setFields(null)")
        end
      end

      # Pushes an updated count for a single type key to the JS type list badge.
      # Much cheaper than a full send_initial_data rebuild.
      def send_type_count_update(type_key)
        return unless @dialog && @model
        begin
          idd_type = OpenStudio::IddObjectType.new(type_key)
          count = @model.numObjectsOfType(idd_type)
          safe_execute("updateTypeCount(#{JSON.generate(type_key)}, #{JSON.generate(count)})")
        rescue => e
          puts "Inspector: send_type_count_update error: #{e.message}"
        end
      end

      def object_added(object)
        return unless @dialog
        #puts "object_added"
        type_key = object.iddObject.type.valueDescription.tr(':', '_')
        send_type_count_update(type_key)
        send_objects_for_type(@current_type) if @current_type == type_key
      end

      def object_removed(object)
        return unless @dialog
        #puts "object_removed"
        type_key = object.iddObject.type.valueDescription.tr(':', '_')
        send_type_count_update(type_key)
        send_objects_for_type(@current_type) if @current_type == type_key
      end

      def refresh_fields
        return unless @current_handle && !@current_handle.isNull
        # Debounce: the OpenStudio SDK can fire onChangeIdfObject multiple times for
        # a single write (e.g. once to clear the old reference, once to set the new
        # one for ObjectListType fields). UI.start_timer(0) defers the actual refresh
        # until the current call stack unwinds, coalescing rapid-fire callbacks into
        # a single redraw.
        UI.stop_timer(@refresh_timer) if @refresh_timer
        @refresh_timer = UI.start_timer(0, false) do
          @refresh_timer = nil
          #puts "refresh_fields"
          send_fields_for_current_object
          if @update_name
            @update_name = false
            safe_execute("updateObjectName(#{JSON.generate(@current_handle.to_s)}, #{JSON.generate(@current_object_name)})")
          end
        end
      end

      def current_object_removed(handle)
        # handle is an OpenStudio::UUID; compare directly
        return unless @current_handle && handle == @current_handle
        #puts "current_object_removed"
        reset_current_object
        safe_execute("setFields(null)")
      end

      # ------------------------------------------------------------------
      # Model queries
      # ------------------------------------------------------------------

      def get_model
        # Access the OpenStudio model via the standard SketchUp plugin pattern.
        # The singleton Plugin object (OpenStudio::Plugin, a PluginManager) holds a
        # ModelManager, which tracks ModelInterface objects for each open SketchUp model.
        # Pattern from existing plugin code: Plugin.model_manager.model_interface.openstudio_model
        begin
          # Primary path: use the Plugin singleton from the loaded SketchUp plugin
          if defined?(OpenStudio::Plugin) && OpenStudio::Plugin.respond_to?(:model_manager)
            mm = OpenStudio::Plugin.model_manager
            if mm
              mi = mm.model_interface  # returns model_interface for Sketchup.active_model
              return mi.openstudio_model if mi && mi.respond_to?(:openstudio_model)
            end
          end
        rescue => e
          puts "Inspector: Could not get OpenStudio model: #{e.message}"
        end
        nil
      end

      def get_objects_for_type(type_str)
        return [] unless @model
        begin
          idd_type = OpenStudio::IddObjectType.new(type_str)
          ws_objects = @model.getObjectsByType(idd_type)
          ws_objects.map do |obj|
            {
              handle:  obj.handle.to_s,
              name:    obj.nameString,
              comment: obj.comment.gsub(/^!\s*/, '').strip
            }
          end.sort_by { |o| natural_sort_key(o[:name]) }
        rescue => e
          puts "Inspector: get_objects_for_type(#{type_str}) error: #{e.message}"
          []
        end
      end

      # Natural-sort key: alphabetical, using numeric suffix only to break ties.
      # "Surface 2" < "Surface 10" < "Surface A"
      def natural_sort_key(name)
        m = name.downcase.match(/\A(.*?)(\d+)\z/)
        m ? [m[1], m[2].to_i] : [name.downcase, 0]
      end

      def get_fields_for_current_object
        return nil unless @model && @current_handle && @current_object
        begin
          ws_obj = @current_object
          type_str = ws_obj.iddObject.type.valueDescription
          type_key = type_str.tr(':', '_')
          idd_obj  = ws_obj.iddObject

          fields = []

          non_ext_fields  = idd_obj.nonextensibleFields
          ext_group_fields = idd_obj.extensibleGroup
          n = non_ext_fields.size
          g = ext_group_fields.size

          # Fixed (non-extensible) fields — appear exactly once
          non_ext_fields.each_with_index do |idd_field, i|
            field_name = idd_field.name

            # Always hide Handle, Node, and URL fields (internal references)
            field_type_name = idd_field.properties.type.valueName
            next if %w[HandleType NodeType URLType].include?(field_type_name)

            access = @access_policy_store.get_access(type_key, field_name)
            next if access == :hidden

            val_opt = ws_obj.getString(i, true)
            cur_val = val_opt.empty? ? '' : val_opt.get

            fields << build_field_data(ws_obj, idd_field, i, cur_val, access, type_str)
          end

          # Extensible group fields — the template group repeats N times
          if g > 0
            num_groups = (ws_obj.numFields - n) / g
            num_groups.times do |k|
              ext_group_fields.each_with_index do |idd_field, j|
                i = n + k * g + j
                field_name = idd_field.name

                field_type_name = idd_field.properties.type.valueName
                next if %w[HandleType NodeType URLType].include?(field_type_name)

                access = @access_policy_store.get_access(type_key, field_name)
                #puts "type_key #{type_key} field #{field_name} access: #{access}"
                next if access == :hidden

                val_opt = ws_obj.getString(i, true)
                cur_val = val_opt.empty? ? '' : val_opt.get

                fields << build_field_data(ws_obj, idd_field, i, cur_val, access, type_str)
              end
            end
          end

          current_name = ws_obj.nameString
          display_name = current_name.empty? ? ws_obj.iddObject.type.valueDescription : current_name
          if display_name != @current_object_name
            @current_object_name = display_name
            @update_name = true
          end

          result = {
            handle: @current_handle.to_s,
            type:   type_str,
            name:   display_name,
            fields: fields
          }

          # Rendering:Color swatch — append R/G/B swatch field
          color_swatch = build_color_swatch_field(ws_obj, type_str)
          result[:fields] << color_swatch if color_swatch

          # Item 5: additionalProperties — display as a subsection if applicable.
          # type_str is colon-style (e.g. 'OS:Building'); convert to underscore-style
          # for comparison against the underscore-style constant lists.
          type_key = type_str.tr(':', '_')
          if DISPLAY_ADDITIONAL_PROPERTIES.include?(type_key)
            mo_opt = ws_obj.to_ModelObject
            if !mo_opt.empty? && mo_opt.get.hasAdditionalProperties
              add_props = mo_opt.get.additionalProperties
              result[:fields] << { type: 'SectionHeader', name: 'Additional Properties', value: '', access: 'locked' }
              add_props.featureNames.each do |feat_name|
                feat_type  = add_props.getFeatureDataType(feat_name).get rescue 'String'
                feat_value = case feat_type
                             when 'Double'  then add_props.getFeatureAsDouble(feat_name).get.to_s   rescue ''
                             when 'Integer' then add_props.getFeatureAsInteger(feat_name).get.to_s  rescue ''
                             when 'Boolean' then add_props.getFeatureAsBoolean(feat_name).get.to_s  rescue ''
                             else                add_props.getFeatureAsString(feat_name).get.to_s   rescue ''
                             end
                can_remove = REMOVE_ADDITIONAL_PROPERTIES.include?(type_key)
                result[:fields] << {
                  type:       'AdditionalProperty',
                  name:       feat_name,
                  feat_type:  feat_type,
                  value:      feat_value,
                  access:     'free',
                  can_remove: can_remove
                }
              end
              if ADD_ADDITIONAL_PROPERTIES.include?(type_key)
                result[:fields] << { type: 'AddAdditionalProperty', name: '', value: '', access: 'free' }
              end
            end
          end

          result
        rescue => e
          puts "Inspector: get_fields_for_current_object error: #{e.message}"
          nil
        end
      end

      def build_field_data(ws_obj, idd_field, index, cur_val, access, type_str)
        prop      = idd_field.properties
        field_type = prop.type.valueName  # IntegerType, RealType, AlphaType, ChoiceType, ObjectListType, etc.

        data = {
          index:   index,
          name:    idd_field.name,
          access:  access.to_s,
          type:    field_type,
          value:   cur_val,
          units:   '',
          min:     nil,
          max:     nil,
          default: nil,
          autosizable:      prop.autosizable,
          autocalculatable: prop.autocalculatable,
          required:         prop.required,
          choices:          []
        }

        case field_type
        when 'RealType'
          # Unit handling: convert between SI and IP
          data.merge!(build_real_field_data(ws_obj, idd_field, index, cur_val, prop))

        when 'AlphaType'
          # Some fields in the IDD are declared with an 'A' designator (AlphaType) but
          # still carry a \units annotation (e.g. OS:InteriorPartitionSurface/Surface Area).
          # Show the SI unit string beside the text input so the user knows the expected unit.
          begin
            raw_units = idd_field.units
            data[:units] = raw_units.empty? ? '' : raw_units.get.to_s
          rescue
            # ignore — units label is optional
          end

        when 'IntegerType'
          data[:min] = prop.minBoundValue.empty? ? nil : prop.minBoundValue.get
          data[:max] = prop.maxBoundValue.empty? ? nil : prop.maxBoundValue.get

        when 'ChoiceType'
          data[:choices] = idd_field.keys.map(&:name)
          data[:choices].unshift('') unless prop.required

        when 'ObjectListType'
          # Populate with names of objects matching the reference list
          names = []
          prop.objectLists.each do |ref_list|
            ws_obj.workspace.getObjectsByReference(ref_list).each do |ref_obj|
              names << ref_obj.nameString
            end
          end
          names.sort!
          names.unshift('') unless prop.required
          data[:choices] = names
          data[:type]    = 'ObjectListType'
        end

        #puts "Inspector: build_field_data data: #{data}"
        data
      end

      def build_real_field_data(ws_obj, idd_field, index, cur_val, prop)
        result = { units: '', min: nil, max: nil, default: nil, value: cur_val }

        return result if idd_field.unitsBasedOnOtherField

        begin
          # Use idd_field.getUnits as the source of truth for SI and IP unit strings.
          # These come from the IDD schema, so they are always available regardless of
          # whether the field currently holds a numeric value or 'autocalculate'.
          si_unit_opt = idd_field.getUnits(false)  # SI
          ip_unit_opt = idd_field.getUnits(true)   # IP (auto-selected if not explicit)
          si_units = si_unit_opt.empty? ? '' : si_unit_opt.get.to_s
          ip_units = ip_unit_opt.empty? ? '' : ip_unit_opt.get.to_s

          # Set the display unit label
          result[:units] = @unit_system == :ip ? ip_units : si_units

          # Convert the current SI value to IP for display, if applicable.
          # Only attempt this for actual numeric values; skip autosize/autocalculate.
          val_si_opt = ws_obj.getDouble(index, true)  # true = use default value if unset
          unless val_si_opt.empty?
            val_si = val_si_opt.get
            if @unit_system == :ip && !si_units.empty? && !ip_units.empty?
              converted = OpenStudio.convert(val_si, si_units, ip_units)
              result[:value] = converted.empty? ? val_si.to_s : converted.get.to_s
            else
              result[:value] = val_si.to_s
            end
          end
          # If val_si_opt is empty the field value is a string ('autocalculate', etc.)
          # and cur_val is already correct — leave result[:value] as-is.

          # Convert numeric bounds (always stored in SI) to the display unit
          if prop.minBoundType != OpenStudio::IddFieldProperties::Unbounded && !prop.minBoundValue.empty?
            min_si = prop.minBoundValue.get
            if @unit_system == :ip && !si_units.empty? && !ip_units.empty?
              converted = OpenStudio.convert(min_si, si_units, ip_units)
              result[:min] = converted.empty? ? min_si : converted.get
            else
              result[:min] = min_si
            end
          end

          if prop.maxBoundType != OpenStudio::IddFieldProperties::Unbounded && !prop.maxBoundValue.empty?
            max_si = prop.maxBoundValue.get
            if @unit_system == :ip && !si_units.empty? && !ip_units.empty?
              converted = OpenStudio.convert(max_si, si_units, ip_units)
              result[:max] = converted.empty? ? max_si : converted.get
            else
              result[:max] = max_si
            end
          end

          result[:default] = 0
          unless prop.numericDefault.empty?
            def_si = prop.numericDefault.get
            if def_si == -9999
              result[:default] = 0.0
            elsif @unit_system == :ip && !si_units.empty? && !ip_units.empty?
              converted = OpenStudio.convert(def_si, si_units, ip_units)
              result[:default] = converted.empty? ? def_si : converted.get
            else
              result[:default] = def_si
            end
          end
        rescue => e
          puts "Inspector: build_real_field_data error: #{e.message}"
        end
        
        result
      end

      # Builds the ColorSwatch field entry for OS:Rendering:Color objects.
      # Returns nil for all other object types.
      def build_color_swatch_field(ws_obj, type_str)
        return nil unless type_str == 'OS:Rendering:Color'
        r_idx = ws_obj.numFields > 2 ? 2 : nil
        g_idx = ws_obj.numFields > 3 ? 3 : nil
        b_idx = ws_obj.numFields > 4 ? 4 : nil
        return nil unless r_idx && g_idx && b_idx
        r_val = ws_obj.getDouble(r_idx, true).get.clamp(0, 255)
        g_val = ws_obj.getDouble(g_idx, true).get.clamp(0, 255)
        b_val = ws_obj.getDouble(b_idx, true).get.clamp(0, 255)
        hex = '#%02x%02x%02x' % [r_val, g_val, b_val]
        {
          type:    'ColorSwatch',
          name:    'Color Preview',
          hex:     hex,
          index_r: r_idx,
          index_g: g_idx,
          index_b: b_idx,
          value:   hex,
          access:  'locked'
        }
      rescue => e
        puts "Inspector: build_color_swatch_field error: #{e.message}"
        nil
      end

      # ------------------------------------------------------------------
      # CRUD operations
      # ------------------------------------------------------------------

      def update_field(handle_str, index, value)
        return unless @model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj    = @model.getObject(handle)
          return if obj.empty?
          ws_obj = obj.get

          # If the value is in IP, convert back to SI before storing.
          # Special strings ('autosize', 'autocalculate') must bypass this path:
          # value.to_f on them returns 0.0, which OpenStudio.convert would happily convert
          # to a valid SI double, storing 0.0 and preventing return to the auto state.
          is_auto_str = %w[autosize autocalculate].any? { |s| value.to_s.strip.casecmp(s).zero? }

          unless is_auto_str || value.to_s.strip.empty? 
            idd_field_opt = ws_obj.iddObject.getField(index)
            unless idd_field_opt.empty?
              idd_field = idd_field_opt.get
              if idd_field.name.downcase == 'name'
                @current_object_name = value.to_s
                ws_obj.setName(value.to_s)
                @update_name = true
                return
              end
              prop = idd_field.properties
              if prop.type.valueName == 'RealType' && @unit_system == :ip && !idd_field.unitsBasedOnOtherField
                # Use idd_field.getUnits as the source of truth — always available from
                # the IDD schema regardless of the field's current value.
                ip_unit_opt = idd_field.getUnits(true)
                si_unit_opt = idd_field.getUnits(false)
                unless ip_unit_opt.empty? || si_unit_opt.empty?
                  ip_units = ip_unit_opt.get.to_s
                  si_units = si_unit_opt.get.to_s
                  unless ip_units.empty? || si_units.empty?
                    val_f     = value.to_f
                    converted = OpenStudio.convert(val_f, ip_units, si_units)
                    unless converted.empty?
                      ws_obj.setDouble(index, converted.get)
                      return
                    end
                  end
                end
              end
            end
          end

          # Autosize / autocalculate special strings, and any RealType values for which
          # unit conversion was not possible, fall through to a plain string write.
          # Note: setting an empty string also returns an autocalculatable field to its
          # autocalculate state (OpenStudio treats empty and autocalculate identically).
          ws_obj.setString(index, value.to_s)
        rescue => e
          puts "Inspector: update_field error: #{e.message}"
        end
      end

      def add_object(type_str)
        return unless @model
        begin
          idd_type   = OpenStudio::IddObjectType.new(type_str)
          idf_object = OpenStudio::IdfObject.new(idd_type)
          new_obj = @model.addObject(idf_object)
          unless new_obj.empty?
            set_current_object(new_obj.get)
            send_objects_for_type(type_str)
            safe_execute("selectObject(#{JSON.generate(@current_handle.to_s)})")
            send_fields_for_current_object
          end
        rescue => e
          puts "Inspector: add_object error: #{e.message}"
        end
      end

      def copy_object(handle_str)
        return unless @model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj = @model.getObject(handle)
          return if obj.empty?
          mo = obj.get.to_ModelObject
          return if mo.empty?
          cloned     = mo.get.clone(@model)
          set_current_object(cloned)
          send_objects_for_type(@current_type)
          safe_execute("selectObject(#{JSON.generate(@current_handle.to_s)})")
          send_fields_for_current_object
        rescue => e
          puts "Inspector: copy_object error: #{e.message}"
        end
      end

      def delete_object(handle_str)
        return unless @model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj = @model.getObject(handle)
          obj.get.remove unless obj.empty?
          reset_current_object
          send_objects_for_type(@current_type)
        rescue => e
          puts "Inspector: delete_object error: #{e.message}"
        end
      end

      def purge_objects(type_str)
        return unless @model
        begin
          idd_type = OpenStudio::IddObjectType.new(type_str)
          @model.purgeUnusedResourceObjects(idd_type)
          reset_current_object
          send_objects_for_type(@current_type)
        rescue => e
          puts "Inspector: purge_objects error: #{e.message}"
        end
      end

      # ------------------------------------------------------------------
      # Utility
      # ------------------------------------------------------------------

      def safe_execute(script)
        return unless @dialog
        @dialog.execute_script(script)
      rescue => e
        puts "Inspector: execute_script error: #{e.message}"
      end

    end # module InspectorDialog
  end # module Inspector
end # module OpenStudio
