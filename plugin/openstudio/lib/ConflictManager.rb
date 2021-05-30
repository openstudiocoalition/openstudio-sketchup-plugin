########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2021, OpenStudio Coalition and other contributors. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#  following conditions are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#  disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
#  disclaimer in the documentation and/or other materials provided with the distribution.
#
#  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote products
#  derived from this software without specific prior written permission from the respective party.
#
#  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative works
#  may not use the "OpenStudio" trademark, "OS", "os", or any other confusingly similar designation without specific prior
#  written permission from Alliance for Sustainable Energy, LLC.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED
#  STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################################################################

module OpenStudio

  class ConflictManager

    def initialize
      @ignore = false
    end

    def check_for_conflicts

      # timer keeps repeating when messagebox is open, use this to disable new message boxes when one is open
      if @ignore
        return
      end
      @ignore = true

      if Module.constants.include?("IESVE")

      text = <<IESWARNING
The IES-VE Plug-in has been detected.

The OpenStudio Plug-in may experience issues due to interactions with the IES-VE Plug-in.

To temporarily disable the IES-VE Plug-in, rename the file IESLink.rbs in the SketchUp Plugins directory to IESLink.__rbs__.

The OpenStudio Plug-in can be enabled or disabled through SketchUp's Preferences->Extension menu item.

Do you want to show this warning in the future?
IESWARNING

        show_ies_warning = Sketchup.read_default("OpenStudio", "Show IES Warning", true)

        if show_ies_warning
          result = UI.messagebox(text, MB_YESNO)
          if result == 6 # Yes
            Sketchup.write_default("OpenStudio", "Show IES Warning", true)
          else # No
            Sketchup.write_default("OpenStudio", "Show IES Warning", false)
          end
        end

      end

      # re-enable
      @ignore = false

    end

  end

end
