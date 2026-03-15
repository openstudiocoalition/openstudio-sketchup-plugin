########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require 'json'

module OpenStudio

  # Pure-Ruby update checker.  Replaced the former dependency on
  # Modeleditor::GithubReleases (C++ Qt HTTP) with Sketchup::Http::Request.
  #
  # On construction the class fires an async HTTP GET to the GitHub Releases API.
  # The callback parses the JSON response, compares versions, and shows a
  # messagebox if a newer release is available.
  class PluginUpdateManager

    ORG          = 'openstudiocoalition'
    REPO         = 'openstudio-sketchup-plugin'
    API_URL      = "https://api.github.com/repos/#{ORG}/#{REPO}/releases"
    RELEASES_URL = "https://github.com/#{ORG}/#{REPO}/releases"

    def initialize(verbose)
      @verbose = verbose
      Sketchup.set_status_text('OpenStudio checking for update', SB_PROMPT)
      fetch_releases
    end

    private

    def fetch_releases
      req = Sketchup::Http::Request.new(API_URL, Sketchup::Http::GET)
      # GitHub API requires a User-Agent header
      req.headers = { 'User-Agent' => "openstudio-sketchup-plugin/#{Plugin.version}" }

      req.start do |_req, response|
        if response.status_code == 200
          process_response(response.body)
        else
          puts "UpdateManager: HTTP #{response.status_code}"
          on_finished(error: true)
        end
      end
    rescue => e
      puts "UpdateManager: fetch error: #{e.message}"
      on_finished(error: true)
    end

    def process_response(body)
      releases = JSON.parse(body)

      current_version = Gem::Version.new(Plugin.version)

      new_release = releases.any? do |r|
        next false if r['prerelease']
        tag = r['tag_name'].to_s.sub(/\Av/, '')
        begin
          Gem::Version.new(tag) > current_version
        rescue ArgumentError
          false
        end
      end

      on_finished(error: false, new_release_available: new_release)
    rescue => e
      puts "UpdateManager: parse error: #{e.message}"
      on_finished(error: true)
    end

    def on_finished(error: false, new_release_available: false)
      Sketchup.set_status_text('', SB_PROMPT)

      if !error
        if new_release_available
          button = UI.messagebox(
            "A newer version of the OpenStudio SketchUp Plug-in is ready for download.\n" \
            "Do you want to update to the newer version?\n\n" \
            "Click YES to visit the OpenStudio SketchUp Plug-in website.\n" \
            "Click NO to skip this version and not ask you again.\n" \
            "Click CANCEL to remind you again next time.", MB_YESNOCANCEL
          )
          if button == 6      # YES
            UI.openURL(RELEASES_URL)
          elsif button == 7   # NO
            Plugin.write_pref("Check For Update #{Plugin.version}", false)
          end
        elsif @verbose
          UI.messagebox('You currently have the most recent version of the OpenStudio SketchUp Plug-in.')
        else
          puts 'UpdateManager: already up to date.'
        end
      elsif @verbose
        UI.messagebox('Error occurred while checking for update.')
      else
        puts 'UpdateManager: error checking for update.'
      end

      Plugin.update_manager = nil
    end

  end

end
