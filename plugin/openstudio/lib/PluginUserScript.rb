########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio
module Ruleset

# extend/modify the existing OpenStudio classes.

class ModelUserScript
  def registerWithSketchUp
    Plugin.user_script_runner.add_user_script(self)
  end
  def registerWithApplication
    Plugin.user_script_runner.add_user_script(self)
  end
end

class WorkspaceUserScript
  def registerWithSketchUp
    Plugin.user_script_runner.add_user_script(self)
  end
  def registerWithApplication
    Plugin.user_script_runner.add_user_script(self)
  end
end

class ReportingUserScript
  def registerWithSketchUp
    Plugin.user_script_runner.add_user_script(self)
  end
  def registerWithApplication
    Plugin.user_script_runner.add_user_script(self)
  end
end

end #Ruleset
module Measure

class ModelMeasure
  def registerWithApplication
    Plugin.user_script_runner.add_user_script(self)
  end
end

class EnergyPlusMeasure
  def registerWithApplication
    Plugin.user_script_runner.add_user_script(self)
  end
end

class ReportingMeasure
  def registerWithApplication
    Plugin.user_script_runner.add_user_script(self)
  end
end

end #Measure
end
