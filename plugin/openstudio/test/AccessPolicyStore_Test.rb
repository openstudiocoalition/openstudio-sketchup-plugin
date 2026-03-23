########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

# Run with the OpenStudio CLI (which bundles the SDK and minitest):
#   c:\openstudio-3.10.0\bin\openstudio.exe C:\repos\openstudio-sketchup-plugin\plugin\openstudio\test\AccessPolicyStore_Test.rb

require 'openstudio'
require 'minitest/autorun'
require_relative '../lib/dialogs/InspectorDialog/access_policy_store'

module OpenStudio

  class AccessPolicyStore_Test < Minitest::Test

    APS = OpenStudio::Inspector::AccessPolicyStore

    # Load the real SketchUpPluginPolicy.xml before each test and clear after.
    def setup
      APS.load_policy
    end

    def teardown
      APS.clear
    end

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    # Returns the IddObject for the given type string (e.g. 'OS:Space').
    def idd_object_for(type_str)
      idd_file =  OpenStudio::IddFileAndFactoryWrapper.new("OpenStudio".to_IddFileType).iddFile
      idd_obj_opt = idd_file.getObject(OpenStudio::IddObjectType.new(type_str))
      assert !idd_obj_opt.empty?, "Could not find IddObject for '#{type_str}' in the OpenStudio IDD"
      idd_obj_opt.get
    end

    # -----------------------------------------------------------------------
    # OS:Space
    #
    # normalize_type_str maps "OS:Space" -> "OS_Space" before the XML lookup.
    # SketchUpPluginPolicy.xml currently has no OS_Space section, so every
    # field returns :free.  If a policy section is added to the XML, the
    # assertions below will need to be updated to reflect those rules.
    #
    # Fields (from OpenStudio.idd):
    #   A1  Handle                                        (HandleType)
    #   A2  Name                                          => :free
    #   A3  Space Type Name                               => :free
    #   A4  Default Construction Set Name                 => :free
    #   A5  Default Schedule Set Name                     => :free
    #   N1  Direction of Relative North                   => :free
    #   N2  X Origin                                      => :free
    #   N3  Y Origin                                      => :free
    #   N4  Z Origin                                      => :free
    #   A6  Building Story Name                           => :free
    #   A7  Thermal Zone Name                             => :free
    #   A8  Part of Total Floor Area                      => :free
    #   A9  Design Specification Outdoor Air Object Name  => :free
    #   A10 Building Unit Name                            => :free
    #   N5  Volume                                        => :free
    #   N6  Ceiling Height                                => :free
    #   N7  Floor Area                                    => :free
    # -----------------------------------------------------------------------

    # Iterate every IDD field and assert :free using the SDK-provided field names.
    def test_os_space_all_sdk_fields_are_free
      idd_obj = idd_object_for('OS:Space')
      idd_obj.nonextensibleFields.each_with_index do |field, idx|
        name = field.name
        next if name.empty?   # skip un-named extensible sentinels
        assert_equal :free, APS.get_access('OS:Space', name),
          "Field [#{idx}] '#{name}' in OS:Space should be :free (no policy entry in XML)"
      end
      idd_obj.extensibleGroup.each_with_index do |field, idx|
        name = field.name
        next if name.empty?   # skip un-named extensible sentinels
        assert_equal :free, APS.get_access('OS:Space', name),
          "Field [#{idx}] '#{name}' in OS:Space should be :free (no policy entry in XML)"
      end
    end

    # Per-field assertions so a failure points directly at the offending field.
    def test_os_space_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Name')
    end

    def test_os_space_space_type_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Space Type Name')
    end

    def test_os_space_default_construction_set_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Default Construction Set Name')
    end

    def test_os_space_default_schedule_set_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Default Schedule Set Name')
    end

    def test_os_space_direction_of_relative_north_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Direction of Relative North')
    end

    def test_os_space_x_origin_is_free
      assert_equal :free, APS.get_access('OS:Space', 'X Origin')
    end

    def test_os_space_y_origin_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Y Origin')
    end

    def test_os_space_z_origin_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Z Origin')
    end

    def test_os_space_building_story_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Building Story Name')
    end

    def test_os_space_thermal_zone_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Thermal Zone Name')
    end

    def test_os_space_part_of_total_floor_area_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Part of Total Floor Area')
    end

    def test_os_space_design_specification_outdoor_air_is_free
      assert_equal :free,
        APS.get_access('OS:Space', 'Design Specification Outdoor Air Object Name')
    end

    def test_os_space_building_unit_name_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Building Unit Name')
    end

    def test_os_space_volume_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Volume')
    end

    def test_os_space_ceiling_height_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Ceiling Height')
    end

    def test_os_space_floor_area_is_free
      assert_equal :free, APS.get_access('OS:Space', 'Floor Area')
    end

    # Colon-style and underscore-style type strings must be equivalent
    def test_os_space_colon_and_underscore_style_equivalent
      assert_equal APS.get_access('OS:Space', 'Name'),
                   APS.get_access('OS_Space', 'Name'),
        "Both 'OS:Space' and 'OS_Space' should resolve to the same policy"
    end

    # -----------------------------------------------------------------------
    # OS:Surface — spot-check that the SDL field names match the policy XML.
    # (Uses SDK to confirm the canonical field names are exactly as written.)
    # -----------------------------------------------------------------------

    def test_os_surface_space_name_field_exists_in_idd_and_is_locked
      idd_obj = idd_object_for('OS:Surface')
      names = idd_obj.nonextensibleFields.map(&:name)
      assert names.include?('Space Name'),
        "Expected 'Space Name' to be a field in the OS:Surface IDD (found: #{names.inspect})"
      assert_equal :locked, APS.get_access('OS:Surface', 'Space Name')
      assert names.include?('Number of Vertices'),
        "Expected 'Number of Vertices' to be a field in the OS:Surface IDD (found: #{names.inspect})"
      assert_equal :hidden, APS.get_access('OS:Surface', 'Number of Vertices')
    end

    def test_os_surface_vertex_fields_exist_in_idd_and_are_hidden
      idd_obj = idd_object_for('OS:Surface')
      names = idd_obj.extensibleGroup.map(&:name)
      ['Vertex X-coordinate', 'Vertex Y-coordinate', 'Vertex Z-coordinate'].each do |field_name|
        assert names.include?(field_name),
          "Expected '#{field_name}' to be a field in the OS:Surface IDD"
        assert_equal :hidden, APS.get_access('OS:Surface', field_name)
      end
    end

  end

end
