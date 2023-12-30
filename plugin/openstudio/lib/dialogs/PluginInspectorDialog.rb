########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2022, OpenStudio Coalition and other contributors. All rights reserved.
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

  class PluginInspectorDialog

    def create_dialog
      html_file = File.join(__dir__, 'html', 'step4.html') # Use external HTML
      options = {
        :dialog_title => "Material",
        :preferences_key => "example.htmldialog.materialinspector",
        :style => UI::HtmlDialog::STYLE_DIALOG
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_file(html_file) # Can be set here.
      dialog.center

      dialog.add_action_callback('idd_object_type_ready') { |action_context|
        puts "idd_object_type_ready"
        puts "action_context = #{action_context}"
        self.idd_object_type_ready()
        nil
      }
      dialog.add_action_callback('select_idd_object_type') { |action_context, json|
        puts "select_idd_object_type"
        puts "action_context = #{action_context}"
        self.select_idd_object_type(json)
        nil
      }

      dialog
    end

    def initialize
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @ignore = false
    end

    def enabled?
      return (not @ignore)
    end

    def enable
      @ignore = false
    end

    def disable
      watcher_enabled = enabled?
      @ignore = true
      return watcher_enabled
    end

    def displayIP(display)
    end

    def idd_object_type_ready()
      puts "idd_object_type_ready"
      update
    end

    def select_idd_object_type(args)
      puts "select_idd_object_type:"
      puts "#{args}"
    end

    def setIddObjectType(iddObjectType)
    end

    def setSelectedObjectHandles(handles)
    end

    def saveState
    end

    def restoreState
    end

    def isVisible
      return true
    end

    #def onIddObjectTypeChanged(iddObjectType)
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, enabled? = #{enabled?}")
    #  super
    #end

    def onSelectedObjectHandlesChanged(handles)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, enabled? = #{enabled?}, handles = #{handles}")
      #super

      if enabled?
        model_interface =  Plugin.model_manager.model_interface
        if model_interface
          had_observers = model_interface.selection_interface.remove_observers
          model_interface.selection_interface.select_drawing_interfaces(handles)
          model_interface.selection_interface.add_observers if had_observers
        end
      end

    end

    #def onModelChanged(model)
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, enabled? = #{enabled?}")
    #  super
    #end

    def show_error
      msg  = "An error occurred in the OpenStudio SketchUp plug-in.\n\n"
      msg += "It is advised that you save a backup of your current OpenStudio model and restart SketchUp."
      UI.messagebox(msg)
    end

    def onPushButtonNew(checked)
      model_interface =  Plugin.model_manager.model_interface
      if model_interface.model_watcher.enabled
      #  super(checked)
      else
      #  show_error
      end
    end

    def onPushButtonCopy(checked)
      model_interface =  Plugin.model_manager.model_interface
      if model_interface.model_watcher.enabled
      #  super(checked)
      else
      #  show_error
      end
    end

    def onPushButtonDelete(checked)
      model_interface =  Plugin.model_manager.model_interface
      if model_interface.model_watcher.enabled
      #  super(checked)
      else
      #  show_error
      end
    end

    def onPushButtonPurge(checked)
      model_interface =  Plugin.model_manager.model_interface
      if model_interface.model_watcher.enabled
      #  super(checked)
      else
      #  show_error
      end
    end

    def show
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, enabled? = #{enabled?}")

      @dialog = create_dialog if !@dialog

      update
      #super
      #activateWindow

      @dialog.show
      @dialog.bring_to_front

      #OpenStudio::ApplicationClass.instance.processEvents
    end

    def hide
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, enabled? = #{enabled?}")

      @dialog.close if @dialog
      #OpenStudio::ApplicationClass.instance.processEvents
    end


    def update
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, enabled? = #{enabled?}")

      model_interface = Plugin.model_manager.model_interface
      if model_interface
      #  setModel(model_interface.openstudio_model)
      #  setEnabled(true)
      else
        openstudio_model = OpenStudio::Model::Model.new
      #  setModel(openstudio_model)
      #  setEnabled(false)
      end

      @dialog.execute_script("table.setData([{id:1, iddobjecttype:'Dan'}, {id:1, iddobjecttype:'More Dan'}]);") if @dialog
    end

  end

end
