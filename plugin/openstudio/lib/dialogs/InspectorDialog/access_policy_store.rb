# frozen_string_literal: true

require 'rexml/document'

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
      @policies = {}  # { "OS_Building" => { "Field Name" => :hidden/:locked/:free } }

      def load_policy
        policy_file = File.join(File.dirname(__FILE__), 'SketchUpPluginPolicy.xml')
        clear
        load_file(policy_file)
      end

      def load_file(xml_path)
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
      def normalize_type_str(type_str)
        type_str.to_s.tr(':', '_')
      end

      # Returns the access level for a field by name within an IDD object type.
      # type_str may be in either "OS:SubSurface" or "OS_SubSurface" format.
      def get_access(type_str, field_name)
        key   = normalize_type_str(type_str)
        rules = @policies[key]
        return :free unless rules
        # Match case-insensitively
        rules.each do |rule_field, level|
          return level if rule_field.casecmp(field_name) == 0
        end
        :free
      end

      def clear
        @policies = {}
      end
    end

  end
end
