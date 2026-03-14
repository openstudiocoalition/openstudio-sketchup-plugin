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

    # TODO: refactor AccessPolicyStore as a class instead of a module

    module AccessPolicyStore
      @policies = {}  # { "OS_Building" => { 0 => :hidden, 1 => :locked, ... } }

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

    # TODO: refactor InspectorDialog as a class instead of a module

    # TODO: group types by IDD groups (collapsible), use code from InspectorDialog.cpp for reference:
    #   for (const std::string& group : m_iddFile.groups())

    # TODO: show object count next to each type in the list like "Surfaces (10)" when there are 10 surfaces

    module InspectorDialog

      # ------------------------------------------------------------------
      # Configuration – ported from InspectorDialog::init(SketchUpPlugin)
      # ------------------------------------------------------------------
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
      ].freeze unless defined?(TYPES_TO_DISPLAY)

      DISABLE_ADD = %w[
        OS_ShadingControl
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_Surface
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
        OS_ThermalZone
      ].freeze unless defined?(DISABLE_ADD)

      DISABLE_COPY = %w[
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_Surface
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
        OS_ThermalZone
      ].freeze unless defined?(DISABLE_COPY)

      DISABLE_REMOVE = %w[
        OS_InteriorPartitionSurface
        OS_InteriorPartitionSurfaceGroup
        OS_ShadingSurface
        OS_ShadingSurfaceGroup
        OS_Space
        OS_Surface
        OS_SubSurface
        OS_Daylighting_Control
        OS_IlluminanceMap
        OS_Glare_Sensor
      ].freeze unless defined?(DISABLE_REMOVE)

      # Resource objects that support purge
      ENABLE_PURGE = %w[
        OS_DefaultConstructionSet
        OS_DefaultScheduleSet
        OS_DefaultSurfaceConstructions
        OS_DefaultSubSurfaceConstructions
        OS_Rendering_Color
        OS_SpaceType
        OS_WindowProperty_FrameAndDivider
      ].freeze unless defined?(ENABLE_PURGE)

      # ------------------------------------------------------------------
      # State
      # ------------------------------------------------------------------
      @dialog = nil
      @unit_system = :ip  # :si or :ip
      @current_type = nil
      @current_handle = nil

      # ------------------------------------------------------------------
      # Dialog lifecycle
      # ------------------------------------------------------------------

      def self.create_dialog
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
        dlg = UI::HtmlDialog.new(options)
        dlg.set_file(html_file)
        dlg.center
        dlg
      end

      def self.show_dialog
        @dialog ||= create_dialog

        # Remove existing callbacks to avoid duplicates on reload
        # (UI::HtmlDialog doesn't provide a remove-callback API; simply re-create if needed)

        @dialog.add_action_callback('ready') do |_ctx|
          load_policy
          send_initial_data
          nil
        end

        # TODO: remove this callback, the backend sends the unit system in the initial data
        @dialog.add_action_callback('set_unit_system') do |_ctx, system|
          @unit_system = system == 'si' ? :si : :ip
          refresh_fields if @current_handle
          nil
        end

        @dialog.add_action_callback('set_type') do |_ctx, type_str|
          @current_type = type_str
          @current_handle = nil
          send_objects_for_type(type_str)
          nil
        end

        @dialog.add_action_callback('set_object') do |_ctx, handle_str|
          @current_handle = handle_str
          send_fields_for_object(handle_str)
          nil
        end

        @dialog.add_action_callback('update_field') do |_ctx, data|
          begin
            payload = JSON.parse(data)
            update_field(payload['handle'], payload['index'], payload['value'])
          rescue => e
            puts "Inspector update_field error: #{e.message}"
          end
          nil
        end

        @dialog.add_action_callback('add_object') do |_ctx, type_str|
          add_object(type_str)
          nil
        end

        @dialog.add_action_callback('copy_object') do |_ctx, handle_str|
          copy_object(handle_str)
          nil
        end

        @dialog.add_action_callback('delete_object') do |_ctx, handle_str|
          delete_object(handle_str)
          nil
        end

        @dialog.add_action_callback('purge_objects') do |_ctx, type_str|
          purge_objects(type_str)
          nil
        end

        @dialog.show
      end

      def self.set_unit_system(system)
        @unit_system = system == 'si' ? :si : :ip
        refresh_fields if @current_handle
      end

      # TODO: implement the following method which is called by DialogManager to hide the dialog
      def self.hide
        # TODO: implement
      end

      # TODO: implement the following method which is called by DialogManager to test if the dialog is visible
      def self.is_visible
        # TODO: implement
      end

      # TODO: implement the following method which is called by DialogManager to enable the dialog
      def self.enable
        # TODO: implement, return true if the dialog was previously disabled, false otherwise
      end

      # TODO: implement the following method which is called by DialogManager to disable the dialog
      def self.disable
        # TODO: implement, return true if the dialog was previously enabled, false otherwise
      end

      # TODO: implement the following method which is called by DialogManager to check if the dialog is enabled
      def self.is_enabled
        # TODO: implement, return true if the dialog is enabled, false otherwise
      end

      # TODO: implement the following method which is called by DialogManager to save the state of the dialog
      def self.save_state
        # TODO: implement
      end

      # TODO: implement the following method which is called by DialogManager to restore the state of the dialog
      def self.restore_state
        # TODO: implement
      end

      # ------------------------------------------------------------------
      # Policy loading
      # ------------------------------------------------------------------

      def self.load_policy
        policy_file = File.join(File.dirname(__FILE__), 'existing_cpp_to_port', 'SketchUpPluginPolicy.xml')
        AccessPolicyStore.clear
        AccessPolicyStore.load_file(policy_file)
      end

      # ------------------------------------------------------------------
      # Interaction with SketchUp
      # ------------------------------------------------------------------
      # TODO: when selecting objects in the inspector, call this method so that the objects are selected in the SketchUp model
      def self.select_drawing_interfaces(handles)
        model_interface =  Plugin.model_manager.model_interface
        if model_interface
          had_observers = model_interface.selection_interface.remove_observers
          model_interface.selection_interface.select_drawing_interfaces(handles)
          model_interface.selection_interface.add_observers if had_observers
        end
      end

      # TODO: implement the following method which is called by DialogManager when the model is updated
      def self.update
        # TODO: implement, refresh the data in the dialog
      end

      # TODO: implement the following method which is called by DialogManager when the SketchUp selection changes
      def self.set_idd_object_type(idd_object_type)
        # TODO: implement
      end

      # TODO: implement the following method which is called by DialogManager when the SketchUp selection changes
      def self.set_selected_object_handles(handles)
        # TODO: implement, note handles may be empty in case of no selection
      end

      # ------------------------------------------------------------------
      # Data senders (Ruby → JavaScript via execute_script)
      # ------------------------------------------------------------------

      def self.send_initial_data
        # Send types list
        types_data = TYPES_TO_DISPLAY.map do |t|
          label = t.gsub(/^OS_/, '').gsub('_', ' ')
          { key: t, label: label }
        end
        safe_execute("setTypes(#{JSON.generate(types_data)})")

        # Send unit system
        safe_execute("setUnitSystem('#{@unit_system}')")

        # Pre-select first type
        first_type = TYPES_TO_DISPLAY.first
        @current_type = first_type
        send_objects_for_type(first_type)
      end

      def self.send_objects_for_type(type_str)
        return unless @dialog
        objects = get_objects_for_type(type_str)
        button_state = {
          enable_add:    !DISABLE_ADD.include?(type_str),
          enable_copy:   !DISABLE_COPY.include?(type_str),
          enable_remove: !DISABLE_REMOVE.include?(type_str),
          enable_purge:  ENABLE_PURGE.include?(type_str)
        }
        payload = { objects: objects, buttons: button_state, type: type_str }
        safe_execute("setObjects(#{JSON.generate(payload)})")
        # Clear the fields panel
        safe_execute("setFields(null)")
        @current_handle = nil
      end

      def self.send_fields_for_object(handle_str)
        return unless @dialog
        fields = get_fields_for_object(handle_str)
        if fields
          safe_execute("setFields(#{JSON.generate(fields)})")
        else
          safe_execute("setFields(null)")
        end
      end

      def self.refresh_fields
        return unless @current_handle
        send_fields_for_object(@current_handle)
      end

      # ------------------------------------------------------------------
      # Model queries
      # ------------------------------------------------------------------

      def self.get_model
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

      def self.get_objects_for_type(type_str)
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

      def self.get_fields_for_object(handle_str)
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

      def self.build_field_data(ws_obj, idd_field, index, cur_val, access, type_str)
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

      def self.build_real_field_data(ws_obj, idd_field, index, cur_val, prop)
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

      def self.update_field(handle_str, index, value)
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

      def self.add_object(type_str)
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

      def self.copy_object(handle_str)
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

      def self.delete_object(handle_str)
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

      def self.purge_objects(type_str)
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

      def self.safe_execute(script)
        return unless @dialog
        @dialog.execute_script(script)
      rescue => e
        puts "Inspector: execute_script error: #{e.message}"
      end

    end # module InspectorDialog
  end # module Inspector
end # module OpenStudio
