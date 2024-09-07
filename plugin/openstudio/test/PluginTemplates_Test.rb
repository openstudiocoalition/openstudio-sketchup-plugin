########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require 'openstudio'

require 'minitest/autorun'

module OpenStudio

class PluginTemplates_Test < MiniTest::Unit::TestCase

  def test_Templates
    templates_path = "#{OpenStudio::SKETCHUPPLUGIN_DIR}/../resources/templates/"
    assert(File.exist?(templates_path))
    assert(File.directory?(templates_path))
    templates = Dir.glob(templates_path + "/*.osm")
    assert((not templates.empty?))
    templates.each do |template|
      path = OpenStudio::Path.new(template)

      vt = OpenStudio::OSVersion::VersionTranslator.new
      vt.setAllowNewerVersions(false)

      model = vt.loadModel(path)
      assert((not model.empty?))
      model = model.get

      # check that all space load instances are associated with a space type
      spaceLoads = model.getSpaceLoads
      spaceLoads.each do |spaceLoad|
        assert((not spaceLoad.spaceType.empty?))
      end

      # uncomment this to save the version translated file to the original path
      # DO NOT leave this in the test execution when you commit!
      #model.save(path, true)
    end
  end

end

end
