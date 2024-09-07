########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  # This patch allows all file separators to be accepted and prints an error message if path does not exist.
  # Decided that the normal behavior of UI.openpanel should not be changed (even for the better).
  # New alternative method is:  OpenStudio.open_panel
  def OpenStudio.open_panel(*args)
    if (args[1])
      dir = args[1]

      if (not dir.empty?)

        if (RUBY_PLATFORM =~ /mswin/ or RUBY_PLATFORM =~ /mingw/)  # Windows
          # Replace / with \\ for the file separator
          dir = dir.split("/").join("\\")

          # Check for and append required final \\
          if (dir[dir.length - 1].chr != "\\")
            dir += "\\"
          end

        else  # Mac
          # Check for and append required final /
          if (dir[dir.length - 1].chr != "/")
            dir += "/"
          end
        end

        if (not File.directory?(dir))
          puts "OpenStudio.open_panel received bad directory: " + dir
          args[1] = ""
        else
          args[1] = dir
        end
      end
    end

    # Allow empty file name to be passed in as a valid argument
    if (args[2])
      if (args[2].strip.empty?)
        args[2] = "*.*"
      end
    else
      args[2] = "*.*"
    end

    #if (path = _openpanel(*args))
    if (path = UI.openpanel(*args))  # call the original method
      # Replace \\ with / for the file separator (works better for saving the path in a registry default)
      path = path.split("\\").join("/")
    end

    return(path)
  end


  # Decided that the normal behavior of UI.savepanel should not be changed (even for the better).
  # New alternative method is:  OpenStudio.save_panel
  def OpenStudio.save_panel(*args)
    if (args[1])
      dir = args[1]

      if (not dir.empty?)

        if (RUBY_PLATFORM =~ /mswin/ or RUBY_PLATFORM =~ /mingw/)  # Windows
          # Replace / with \\ for the file separator
          dir = dir.split("/").join("\\")

          # Check for and append required final \\
          if (dir[dir.length - 1].chr != "\\")
            dir += "\\"
          end

        else  # Mac
          # Check for and append required final /
          if (dir[dir.length - 1].chr != "/")
            dir += "/"
          end
        end

        if (not File.directory?(dir))
          puts "OpenStudio.save_panel received bad directory: " + dir
          args[1] = ""
        else
          args[1] = dir
        end
      end
    end

    # Allow empty file name to be passed in as a valid argument
    if (args[2])
      if (args[2].strip.empty?)
        args[2] = "*.*"
      end
    else
      args[2] = "*.*"
    end

    #if (path = _savepanel(*args))
    if (path = UI.savepanel(*args))  # call the original method
      # Replace \\ with / for the file separator (works better for saving the path in a registry default)
      path = path.split("\\").join("/")
    end

    return(path)
  end


end
