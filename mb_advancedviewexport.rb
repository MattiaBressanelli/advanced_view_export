require 'sketchup.rb'
require 'extensions.rb'

module MattiaBressanelli
  module AdvancedViewExport

    unless file_loaded?(__FILE__)
    
      ex = SketchupExtension.new('Advanced View Export', 'mb_advanced_view_export/main')

      ex.description = 'Extension to export the current view as image with style.'
      ex.version     = '1.0.0'
      ex.copyright   = 'Mattia Bressanelli © 2020'
      ex.creator     = 'Mattia Bressanelli'

      Sketchup.register_extension(ex, true)

      file_loaded(__FILE__)
    end

  end # module AdvancedViewExport
end # module MattiaBressanelli
