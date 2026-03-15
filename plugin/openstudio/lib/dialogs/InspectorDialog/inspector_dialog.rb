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


# Note: OpenStudio Ruby Optional types use `empty`/`get`, NOT `is_initialized`/`get`.

module OpenStudio
  module Inspector

    # -------------------------------------------------------------------------
    # AccessPolicyStore
    # Parses SketchUpPluginPolicy.xml and answers field-access queries.
    # Access levels: :free (editable), :locked (read-only), :hidden (not shown)
    #
    # The XML key format is underscore-style ("OS_SubSurface") but the OpenStudio
    # Ruby API's valueDescription returns colon-style ("OS:SubSurface"). The helper
    # normalize_type_str converts to underscore before lookup.
    # -------------------------------------------------------------------------

    class AccessPolicyStore
      @policies = {}  # { "OS_Building" => { 0 => :hidden, 1 => :locked, ... } }

      def self.load_policy
        policy_file = File.join(File.dirname(__FILE__), 'SketchUpPluginPolicy.xml')
        self.clear
        self.load_file(policy_file)
      end

      def self.load_file(xml_path)
        return false unless File.exist?(xml_path)
        doc = REXML::Document.new(File.read(xml_path))
        doc.elements.each('ROOT/POLICY') do |policy_el|
          type_str = policy_el.attributes['IddObjectType']
          next unless type_str
          rules = {}
          policy_el.elements.each('rule') do |rule_el|
            field_name = rule_el.attributes['IddField']
            access_str = rule_el.attributes['Access']&.downcase
            rules[field_name] = case access_str
                                 when 'locked' then :locked
                                 when 'hidden' then :hidden
                                 else :free
                                 end
          end
          @policies[type_str] = rules
        end
        true
      rescue => e
        puts "AccessPolicyStore: Failed to parse XML: #{e.message}"
        false
      end

      # Normalize an IDD object type string to the underscore format used in the XML.
      # "OS:SubSurface" => "OS_SubSurface",  "OS_SubSurface" => "OS_SubSurface"
      def self.normalize_type_str(type_str)
        type_str.to_s.tr(':', '_')
      end

      # Returns the access level for a field by name within an IDD object type.
      # type_str may be in either "OS:SubSurface" or "OS_SubSurface" format.
      def self.get_access(type_str, field_name)
        key   = normalize_type_str(type_str)
        rules = @policies[key]
        return :free unless rules
        # Match case-insensitively
        rules.each do |rule_field, level|
          return level if rule_field.casecmp(field_name) == 0
        end
        :free
      end

      def self.clear
        @policies = {}
      end
    end

    # -------------------------------------------------------------------------
    # InspectorDialog main class
    # -------------------------------------------------------------------------

    class InspectorDialog

      # ------------------------------------------------------------------
      # Configuration – ported from InspectorDialog::init(SketchUpPlugin)
      # ------------------------------------------------------------------

      # TODO: sort TYPES_TO_DISPLAY alphabetically
      TYPES_TO_DISPLAY = %w[
        OS_BuildingStory
        OS_DefaultConstructionSet
        OS_DefaultScheduleSet
        OS_DefaultSurfaceConstructions
        OS_DefaultSubSurfaceConstructions
        OS_Rendering_Color
        OS_SpaceType
        OS_ShadingControl
        OS_WindowProperty_FrameAndDivider
        OS_Building
        OS_Facility
        OS_InteriorPartitionSurfaceGroup
        OS_InteriorPartitionSurface
        OS_ShadingSurfaceGroup
        OS_ShadingSurface
        OS_Space
        OS_Surface
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
        OS_ThermalZone
      ].freeze unless const_defined?(:TYPES_TO_DISPLAY)

      # TODO: sort DISABLE_ADD alphabetically
      DISABLE_ADD = %w[
        OS_ShadingControl
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_Surface
        OS_Building
        OS_Facility
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
        OS_ThermalZone
      ].freeze unless const_defined?(:DISABLE_ADD)

      # TODO: sort DISABLE_COPY alphabetically
      DISABLE_COPY = %w[
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Building
        OS_Facility
        OS_Space
        OS_Surface
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
        OS_ThermalZone
      ].freeze unless const_defined?(:DISABLE_COPY)

      # TODO: sort DISABLE_REMOVE alphabetically
      DISABLE_REMOVE = %w[
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_Building
        OS_Facility
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_Surface
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
      ].freeze unless const_defined?(:DISABLE_REMOVE)

      # Resource objects that support purge

      # TODO: sort ENABLE_PURGE alphabetically
      ENABLE_PURGE = %w[
        OS_DefaultConstructionSet
        OS_DefaultScheduleSet
        OS_DefaultSurfaceConstructions
        OS_DefaultSubSurfaceConstructions
        OS_Rendering_Color
        OS_SpaceType
        OS_WindowProperty_FrameAndDivider
      ].freeze unless const_defined?(:ENABLE_PURGE)

      # Preferences key used for save_state / restore_state
      PREFS_KEY = 'OpenStudio.InspectorDialog'.freeze unless const_defined?(:PREFS_KEY)

      # ------------------------------------------------------------------
      # State
      # ------------------------------------------------------------------
      @dialog        = nil
      @unit_system   = :ip  # :si or :ip
      @current_type  = nil
      @current_handle = nil
      @enabled       = true
      @accessPolicyStore = nil

      # ------------------------------------------------------------------
      # Dialog lifecycle
      # ------------------------------------------------------------------

      def create_dialog
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
          puts "ready callback"
          send_initial_data
          nil
        end

        result.add_action_callback('set_type') do |_ctx, type_str|
          puts "set_type callback"
          @current_type = type_str
          @current_handle = nil
          send_objects_for_type(type_str)
          nil
        end

        result.add_action_callback('set_object') do |_ctx, handle_str|
          puts "set_object callback"
          @current_handle = handle_str
          send_fields_for_object(handle_str)
          # Sync SketchUp model selection to match the inspector selection
          select_drawing_interfaces([handle_str]) if handle_str && !handle_str.empty?
          nil
        end

        result.add_action_callback('update_field') do |_ctx, data|
          puts "update_field callback"
          begin
            payload = JSON.parse(data)
            update_field(payload['handle'], payload['index'], payload['value'])
          rescue => e
            puts "Inspector update_field error: #{e.message}"
          end
          nil
        end

        result.add_action_callback('add_object') do |_ctx, type_str|
          add_object(type_str)
          nil
        end

        result.add_action_callback('copy_object') do |_ctx, handle_str|
          copy_object(handle_str)
          nil
        end

        result.add_action_callback('delete_object') do |_ctx, handle_str|
          delete_object(handle_str)
          nil
        end

        result.add_action_callback('purge_objects') do |_ctx, type_str|
          purge_objects(type_str)
          nil
        end

        result.set_on_closed  do
          puts "set_on_closed  callback"
          @dialog = nil
          true
        end

        result
      end

      def set_unit_system(system)
        @unit_system = system == 'SI' ? :si : :ip
        refresh_fields if @current_handle
      end

      def show_dialog
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
        send_objects_for_type(@current_type) if @current_type
        refresh_fields
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

        @current_type   = type_str
        @current_handle = nil
        send_objects_for_type(type_str)
        safe_execute("selectType(#{JSON.generate(type_str)})")
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
          @current_handle = nil
          safe_execute("setFields(null)")
          safe_execute("selectObject(null)")
          return
        end

        # Single-selection only (matching C++ behaviour)
        handle_str      = handle_arr.first.to_s
        @current_handle = handle_str
        safe_execute("selectObject(#{JSON.generate(handle_str)})")
        send_fields_for_object(handle_str)
      rescue => e
        puts "Inspector: set_selected_object_handles error: #{e.message}"
      end

      # ------------------------------------------------------------------
      # Data senders (Ruby → JavaScript via execute_script)
      # ------------------------------------------------------------------

      def send_initial_data
        model = get_model

        # Build the IDD-grouped type list with live object counts.
        # IddFactory always returns a valid IddFile for the OpenStudio IDD.
        grouped_types = build_grouped_types(model)

        safe_execute("setTypes(#{JSON.generate(grouped_types)})")

        # Send unit system
        safe_execute("setUnitSystem('#{@unit_system}')")

        # Pre-select first type (or restored type)
        first_type = @current_type || TYPES_TO_DISPLAY.first
        @current_type = first_type
        send_objects_for_type(first_type)
      end

      # Build the type list grouped by IDD group, with object counts.
      # Returns an array of entries; group headers have is_group: true.
      # Porto of C++ loadListWidgetData.
      def build_grouped_types(model)
        idd_file = OpenStudio::IddFactory::instance.getIddFile(
          OpenStudio::IddFileType.new('OpenStudio')
        )

        # Build a set of underscore-style keys for fast lookup
        display_set = TYPES_TO_DISPLAY.to_set

        result = []

        idd_file.groups.each do |group_name|
          # Collect displayable objects in this group
          group_entries = []
          idd_file.getObjectsInGroup(group_name).each do |idd_obj|
            # IDD type is colon-style; convert to underscore for TYPES_TO_DISPLAY lookup
            type_key = idd_obj.type.valueDescription.tr(':', '_')
            next unless display_set.include?(type_key)

            count = model ? model.numObjectsOfType(idd_obj.type) : 0

            label = type_key.gsub(/^OS_/, '').gsub('_', ' ')
            group_entries << {
              key:      type_key,
              label:    label,
              count:    count,
              is_group: false
            }
          end

          next if group_entries.empty?

          # TODO: the group_entries should be a child array of the group
          # this way the group can be collapsed and expanded

          # Emit group header then entries
          result << { label: group_name, is_group: true }
          result.concat(group_entries)
        end

        result
      rescue => e
        puts "Inspector: build_grouped_types error: #{e.message}"
        # Fallback: flat list without counts
        TYPES_TO_DISPLAY.map do |t|
          { key: t, label: t.gsub(/^OS_/, '').gsub('_', ' '), count: 0, is_group: false }
        end
      end

      def send_objects_for_type(type_str)
        return unless @dialog
        model  = get_model
        objects = get_objects_for_type(type_str)
        button_state = {
          enable_add:    !DISABLE_ADD.include?(type_str),
          enable_copy:   !DISABLE_COPY.include?(type_str),
          enable_remove: !DISABLE_REMOVE.include?(type_str),
          enable_purge:  ENABLE_PURGE.include?(type_str)
        }
        # Include updated count so the type list badge stays current
        count = model ? begin
          idd_type = OpenStudio::IddObjectType.new(type_str)
          model.numObjectsOfType(idd_type)
        rescue
          objects.size
        end : objects.size

        payload = { objects: objects, buttons: button_state, type: type_str, count: count }
        safe_execute("setObjects(#{JSON.generate(payload)})")
        # Clear the fields panel
        safe_execute("setFields(null)")
        @current_handle = nil
      end

      def send_fields_for_object(handle_str)
        return unless @dialog
        fields = get_fields_for_object(handle_str)
        if fields
          safe_execute("setFields(#{JSON.generate(fields)})")
        else
          safe_execute("setFields(null)")
        end
      end

      def refresh_fields
        return unless @current_handle
        send_fields_for_object(@current_handle)
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
        model = get_model
        return [] unless model
        begin
          idd_type = OpenStudio::IddObjectType.new(type_str)
          ws_objects = model.getObjectsByType(idd_type)
          ws_objects.map do |obj|
            {
              handle:  obj.handle.to_s,
              name:    obj.nameString,
              comment: obj.comment.gsub(/^!\s*/, '').strip
            }
          end.sort_by { |o| o[:name].downcase }
        rescue => e
          puts "Inspector: get_objects_for_type(#{type_str}) error: #{e.message}"
          []
        end
      end

      def get_fields_for_object(handle_str)
        model = get_model
        return nil unless model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj = model.getObject(handle)
          return nil if obj.empty?
          ws_obj = obj.get
          type_str = ws_obj.iddObject.type.valueDescription
          idd_obj  = ws_obj.iddObject

          fields = []

          # Non-extensible fields
          (0...ws_obj.numFields).each do |i|
            idd_field_opt = idd_obj.getField(i)
            next if idd_field_opt.empty?
            idd_field  = idd_field_opt.get
            field_name = idd_field.name

            # Always hide Handle, Node, and URL fields (internal references)
            field_type_name = idd_field.properties.type.valueName
            next if %w[HandleType NodeType URLType].include?(field_type_name)

            access = AccessPolicyStore.get_access(type_str, field_name)
            next if access == :hidden

            val_opt = ws_obj.getString(i, true)
            cur_val = val_opt.empty? ? '' : val_opt.get

            field_data = build_field_data(ws_obj, idd_field, i, cur_val, access, type_str)
            fields << field_data
          end

          {
            handle:   handle_str,
            type:     type_str,
            name:     ws_obj.nameString,
            fields:   fields
          }
        rescue => e
          puts "Inspector: get_fields_for_object error: #{e.message}"
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

        data
      end

      def build_real_field_data(ws_obj, idd_field, index, cur_val, prop)
        result = { units: '', min: nil, max: nil, default: nil, value: cur_val }

        return result if idd_field.unitsBasedOnOtherField

        begin
          q = ws_obj.getQuantity(index, true, @unit_system == :ip)  # true=IP, false=SI

          unless q.empty
            q = q.get
            result[:value] = q.value.to_s
            result[:units] = q.units.to_s
          end

          # Fetch same field in SI for converting bounds/default
          q_si = ws_obj.getQuantity(index, true, false)
          si_units = q_si.empty ? '' : q_si.get.units.to_s

          if prop.minBoundType != OpenStudio::IddFieldProperties::Unbounded && !prop.minBoundValue.empty?
            min_si = prop.minBoundValue.get
            if @unit_system == :ip && !result[:units].empty? && !si_units.empty?
              converted = OpenStudio.convert(min_si, si_units, result[:units])
              result[:min] = converted.empty? ? min_si : converted.get
            else
              result[:min] = min_si
            end
          end

          if prop.maxBoundType != OpenStudio::IddFieldProperties::Unbounded && !prop.maxBoundValue.empty?
            max_si = prop.maxBoundValue.get
            if @unit_system == :ip && !result[:units].empty? && !si_units.empty?
              converted = OpenStudio.convert(max_si, si_units, result[:units])
              result[:max] = converted.empty? ? max_si : converted.get
            else
              result[:max] = max_si
            end
          end

          unless prop.numericDefault.empty?
            def_si = prop.numericDefault.get
            if @unit_system == :ip && !result[:units].empty? && !si_units.empty?
              converted = OpenStudio.convert(def_si, si_units, result[:units])
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

      # ------------------------------------------------------------------
      # CRUD operations
      # ------------------------------------------------------------------

      def update_field(handle_str, index, value)
        model = get_model
        return unless model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj    = model.getObject(handle)
          return if obj.empty?
          ws_obj = obj.get

          # If the value is in IP, convert back to SI before storing
          idd_field_opt = ws_obj.iddObject.getField(index)
          unless idd_field_opt.empty?
            idd_field = idd_field_opt.get
            prop = idd_field.properties
            if prop.type.valueName == 'RealType' && @unit_system == :ip && !idd_field.unitsBasedOnOtherField
              q_ip = ws_obj.getQuantity(index, true, true)
              unless q_ip.empty?
                ip_units = q_ip.get.units.to_s
                q_si     = ws_obj.getQuantity(index, true, false)
                unless q_si.empty?
                  si_units  = q_si.get.units.to_s
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

          # Autosize / autocalculate special strings
          ws_obj.setString(index, value.to_s)
        rescue => e
          puts "Inspector: update_field error: #{e.message}"
        end
      end

      def add_object(type_str)
        model = get_model
        return unless model
        begin
          idd_type   = OpenStudio::IddObjectType.new(type_str)
          idf_object = OpenStudio::IdfObject.new(idd_type)
          new_obj = model.addObject(idf_object)
          unless new_obj.empty?
            new_handle = new_obj.get.handle.to_s
            @current_handle = new_handle
            send_objects_for_type(type_str)
            safe_execute("selectObject('#{new_handle}')")
            send_fields_for_object(new_handle)
          end
        rescue => e
          puts "Inspector: add_object error: #{e.message}"
        end
      end

      def copy_object(handle_str)
        model = get_model
        return unless model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj = model.getObject(handle)
          return if obj.empty?
          mo = obj.get.to_ModelObject
          return if mo.empty?
          cloned     = mo.get.clone(model)
          new_handle = cloned.handle.to_s
          @current_handle = new_handle
          send_objects_for_type(@current_type)
          safe_execute("selectObject('#{new_handle}')")
          send_fields_for_object(new_handle)
        rescue => e
          puts "Inspector: copy_object error: #{e.message}"
        end
      end

      def delete_object(handle_str)
        model = get_model
        return unless model
        begin
          handle = OpenStudio::toUUID(handle_str)
          obj = model.getObject(handle)
          obj.get.remove unless obj.empty?
          @current_handle = nil
          send_objects_for_type(@current_type)
          safe_execute("setFields(null)")
        rescue => e
          puts "Inspector: delete_object error: #{e.message}"
        end
      end

      def purge_objects(type_str)
        model = get_model
        return unless model
        begin
          idd_type = OpenStudio::IddObjectType.new(type_str)
          model.purgeUnusedResourceObjects(idd_type)
          send_objects_for_type(type_str)
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
